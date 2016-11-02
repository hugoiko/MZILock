library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity hdr_gain is
generic (
    INPUT_WIDTH  : integer := 32;
    OUTPUT_WIDTH : integer := 16;
    N_SHIFTERS   : integer := 6;
    QUANT_TYPE   : integer := 2;
    IREG         : integer := 1;
    SREG1        : integer := 1;
    SREG2        : integer := 1;
    SREG3        : integer := 1;
    SREG4        : integer := 1;
    SREG5        : integer := 1;
    SREG6        : integer := 1;
    MREG         : integer := 1;
    OREG         : integer := 1
);
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    data_in     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
    cmd_in      : in  std_logic_vector(31 downto 0);
    data_out    : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    railed_hi   : out std_logic;
    railed_lo   : out std_logic
);
end entity;

architecture Behavioral of hdr_gain is

    type SREGs_type is array (1 to 6) of integer;
    constant SREGs : SREGs_type := (1=>SREG1, 2=>SREG2, 3=>SREG3, 4=>SREG4, 5=>SREG5, 6=>SREG6);

    constant LOG2_GAIN_OF_ONE : integer := 16;
    constant MANTISSA_WIDTH : integer := 25;

    constant MULT_OUT_WIDTH : integer := MANTISSA_WIDTH + INPUT_WIDTH;

    type array_type1 is array (N_SHIFTERS downto 0) of std_logic_vector(INPUT_WIDTH-1 downto 0); 
    signal bit_shift_stages : array_type1 := (others => (others => '0'));

    type array_type2 is array (N_SHIFTERS downto 0) of std_logic_vector(31 downto 0); 
    signal cmd_stages : array_type2 := (others => (others => '0'));

    signal railed_hi_stages : std_logic_vector(N_SHIFTERS downto 0) := (others => '0');
    signal railed_lo_stages : std_logic_vector(N_SHIFTERS downto 0) := (others => '0');
    signal railed_hi_pipelined : std_logic := '0';
    signal railed_lo_pipelined : std_logic := '0';
    signal railed_hi_synch0 : std_logic := '0';
    signal railed_lo_synch0 : std_logic := '0';
    signal limiter_railed_hi : std_logic := '0';
    signal limiter_railed_lo : std_logic := '0';
    signal railed_hi_int : std_logic := '0';
    signal railed_lo_int : std_logic := '0';

    signal data_shifted : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');

    signal cmd_pipelined : std_logic_vector(31 downto 0) := (others => '0');


    signal data_mult : std_logic_vector(MULT_OUT_WIDTH-1 downto 0) := (others => '0');
    signal data_mult_rs : std_logic_vector(MULT_OUT_WIDTH-1 downto 0) := (others => '0');
    signal data_mult_ls : std_logic_vector(MULT_OUT_WIDTH-1 downto 0) := (others => '0');
    
    signal data_out_int : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
begin


    --optional_reg_slv_regi : entity work.optional_reg_slv generic map (DWIDTH=>data_in'length, USEREG=IREG) port map(clk => clk, ce => '1', rst => '0', 
    --    di => data_in, 
    --    do => bit_shift_stages(0)
    --);

    ireg_0: if (IREG = 0) generate
    begin
        bit_shift_stages(0) <= data_in;
        cmd_stages(0) <= cmd_in;
    end generate;
    ireg_1: if (IREG = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    bit_shift_stages(0) <= data_in;
                    cmd_stages(0) <= cmd_in;
                end if;
            end if;
        end process;
    end generate;

    railed_hi_stages(0) <= '0';
    railed_lo_stages(0) <= '0';

    bit_shifters : for igen in 1 to N_SHIFTERS generate

        signal opmode : std_logic_vector(1 downto 0) := (others => '0');
        signal shifter_output : std_logic_vector(INPUT_WIDTH-1 downto 0);
        signal shifter_railed_hi : std_logic;
        signal shifter_railed_lo : std_logic;

    begin

        process ( cmd_stages(igen-1) ) is
        begin
            if cmd_stages(igen-1)(31) = '1' then
                opmode(0) <= '0';
                opmode(1) <= cmd_stages(igen-1)(24+igen);
            else
                opmode(0) <= cmd_stages(igen-1)(24+igen);
                opmode(1) <= '0';
            end if;
        end process;

        bit_shifter : entity work.safe_signed_bit_shift
        generic map (
            DATA_WIDTH => INPUT_WIDTH,
            BIT_SHIFT  => 8,
            QUANT_TYPE => QUANT_TYPE
        ) port map (
            clk       => clk,
            ce        => ce,
            opmode    => opmode,
            data_in   => bit_shift_stages(igen-1),
            data_out  => shifter_output,
            railed_hi => shifter_railed_hi,
            railed_lo => shifter_railed_lo
        );

        sregs_0: if (SREGs(igen) = 0) generate
        begin
            bit_shift_stages(igen) <= shifter_output;
            cmd_stages(igen) <= cmd_stages(igen-1);
            railed_hi_stages(igen) <= railed_hi_stages(igen-1) or shifter_railed_hi;
            railed_lo_stages(igen) <= railed_lo_stages(igen-1) or shifter_railed_lo;
        end generate;
        sregs_1: if (SREGs(igen) = 1) generate
        begin
            process (clk) is
            begin
                if rising_edge(clk) then
                    if ce = '1' then
                        bit_shift_stages(igen) <= shifter_output;
                        cmd_stages(igen) <= cmd_stages(igen-1);
                        railed_hi_stages(igen) <= railed_hi_stages(igen-1) or shifter_railed_hi;
                        railed_lo_stages(igen) <= railed_lo_stages(igen-1) or shifter_railed_lo;
                    end if;
                end if;
            end process;
        end generate;


    end generate;

    data_shifted <= bit_shift_stages(N_SHIFTERS);
    cmd_pipelined <= cmd_stages(N_SHIFTERS);
    railed_hi_pipelined <= railed_hi_stages(N_SHIFTERS);
    railed_lo_pipelined <= railed_lo_stages(N_SHIFTERS);


    mreg_0: if (MREG = 0) generate
    begin
        data_mult <= std_logic_vector(signed(data_shifted) * signed(cmd_pipelined(MANTISSA_WIDTH-1 downto 0)));
        railed_hi_synch0 <= railed_hi_pipelined;
        railed_lo_synch0 <= railed_lo_pipelined;
    end generate;
    mreg_1: if (MREG = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    data_mult <= std_logic_vector(signed(data_shifted) * signed(cmd_pipelined(MANTISSA_WIDTH-1 downto 0)));
                    railed_hi_synch0 <= railed_hi_pipelined;
                    railed_lo_synch0 <= railed_lo_pipelined;
                end if;
            end if;
        end process;
    end generate;



    output_bit_shifter_right : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH => INPUT_WIDTH+MANTISSA_WIDTH,
        BIT_SHIFT  => LOG2_GAIN_OF_ONE,
        QUANT_TYPE => QUANT_TYPE
    ) port map (
        clk      => clk,
        ce       => ce,
        opmode   => "01", -- quantizer (right shift)
        data_in  => data_mult,
        data_out => data_mult_rs
    );

    output_bit_shifter_left : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH => MULT_OUT_WIDTH,
        BIT_SHIFT  => MULT_OUT_WIDTH-OUTPUT_WIDTH,
        QUANT_TYPE => QUANT_TYPE
    ) port map (
        clk      => clk,
        ce       => ce,
        opmode   => "10", -- limiter (left shift)
        data_in  => data_mult_rs,
        data_out => data_mult_ls,
        railed_hi => limiter_railed_hi,
        railed_lo => limiter_railed_lo
    );


    oreg_0: if (OREG = 0) generate
    begin
        data_out_int <= data_mult_ls(MULT_OUT_WIDTH-1 downto MULT_OUT_WIDTH-OUTPUT_WIDTH);
        railed_hi_int <= railed_hi_synch0 or limiter_railed_hi;
        railed_lo_int <= railed_lo_synch0 or limiter_railed_lo;
    end generate;
    oreg_1: if (OREG = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    data_out_int <= data_mult_ls(MULT_OUT_WIDTH-1 downto MULT_OUT_WIDTH-OUTPUT_WIDTH);
                    railed_hi_int <= railed_hi_synch0 or limiter_railed_hi;
                    railed_lo_int <= railed_lo_synch0 or limiter_railed_lo;
                end if;
            end if;
        end process;
    end generate;


    data_out <= data_out_int;
    railed_hi <= railed_hi_int;
    railed_lo <= railed_lo_int;

end architecture;
