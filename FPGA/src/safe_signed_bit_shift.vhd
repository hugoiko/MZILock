library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;


entity safe_signed_bit_shift is
generic (
    DATA_WIDTH  : positive := 32;
    BIT_SHIFT   : positive := 64;
    QUANT_TYPE  : natural  := 1
);
port (
    clk      : in  std_logic;
    ce       : in  std_logic;
    opmode   : in  std_logic_vector(1 downto 0);
    data_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
);
end entity;

architecture Behavioral of safe_signed_bit_shift is

    function MAX(LEFT, RIGHT: INTEGER) return INTEGER is
    begin
        if LEFT > RIGHT then return LEFT; else return RIGHT; end if;
    end;

    function MIN(LEFT, RIGHT: INTEGER) return INTEGER is
    begin
        if LEFT < RIGHT then return LEFT; else return RIGHT; end if;
    end;
    
    constant QUANT_GUARD_BITS : integer := QUANT_TYPE+1;
    constant QUANT_WIDTH : integer := MAX(DATA_WIDTH+QUANT_GUARD_BITS, BIT_SHIFT+QUANT_GUARD_BITS);
    
    signal quant_sum : std_logic_vector(QUANT_WIDTH-1 downto 0) := (others => '0');
    signal quant_err_z_0 : std_logic_vector(QUANT_WIDTH-1 downto 0) := (others => '0');
    signal quant_err_z_1 : std_logic_vector(QUANT_WIDTH-1 downto 0) := (others => '0');
    signal quant_feedback : std_logic_vector(QUANT_WIDTH-1 downto 0) := (others => '0');
    signal quant_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');


    constant LIM_GUARD_BITS : integer := 1;
    constant LIM_GUARD_BITS_CONST : std_logic_vector(LIM_GUARD_BITS-1 downto 0) := (others => '0');
    constant LIM_TEST_RANGE : integer := MIN(DATA_WIDTH+LIM_GUARD_BITS, BIT_SHIFT+LIM_GUARD_BITS);
    constant LIM_ALL_ZEROS : std_logic_vector(LIM_TEST_RANGE-1 downto 0) := (others => '0');
    constant LIM_ALL_ONES  : std_logic_vector(LIM_TEST_RANGE-1 downto 0) := (others => '1');
    constant LIM_WIDTH : integer := DATA_WIDTH+LIM_GUARD_BITS;

    signal lim_in : std_logic_vector(LIM_WIDTH-1 downto 0) := (others => '0');
    signal lim_railed_hi_int : std_logic;
    signal lim_railed_lo_int : std_logic;
    signal lim_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal data_out_int : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    quantizer_feedback_regs_type0: if (QUANT_TYPE = 0) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    quant_feedback <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    quantizer_feedback_regs_type1: if (QUANT_TYPE = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    quant_feedback <= quant_err_z_0;
                end if;
            end if;
        end process;
    end generate;

    quantizer_feedback_regs_type2: if (QUANT_TYPE = 2) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    quant_err_z_1 <= quant_err_z_0;
                    quant_feedback <= std_logic_vector(shift_left(signed(quant_err_z_0), 1) - signed(quant_err_z_1));
                end if;
            end if;
        end process;
    end generate;


    quantizer_main_process : process(data_in, quant_feedback, quant_sum) is 
    begin
        quant_sum <= std_logic_vector(signed(quant_feedback) + resize(signed(data_in), QUANT_WIDTH));
        quant_out <= std_logic_vector(resize(signed(quant_sum(QUANT_WIDTH-1 downto BIT_SHIFT)), DATA_WIDTH));
        quant_err_z_0(BIT_SHIFT-1 downto 0) <= quant_sum(BIT_SHIFT-1 downto 0);
        quant_err_z_0(QUANT_WIDTH-1 downto BIT_SHIFT) <= (others => '0');
    end process;


    lim_in <= data_in & LIM_GUARD_BITS_CONST;
    lim_railed_hi_int <= '1' when ( lim_in(LIM_WIDTH-1 downto LIM_WIDTH-LIM_TEST_RANGE) /= LIM_ALL_ZEROS and lim_in(LIM_WIDTH-1) = '0' ) else '0';
    lim_railed_lo_int <= '1' when ( lim_in(LIM_WIDTH-1 downto LIM_WIDTH-LIM_TEST_RANGE) /= LIM_ALL_ONES  and lim_in(LIM_WIDTH-1) = '1' ) else '0';


    process (data_in, lim_railed_hi_int, lim_railed_lo_int) is
    begin
        if lim_railed_hi_int = '1' then
            lim_out <= (DATA_WIDTH-1 => '0', others => '1');
        elsif lim_railed_lo_int = '1' then
            lim_out <= (DATA_WIDTH-1 => '1', others => '0');
        else
            lim_out <= std_logic_vector(shift_left(signed(data_in), BIT_SHIFT));
        end if;
    end process;

    process (quant_out, lim_out, data_in, opmode) is
    begin
        case opmode is
            when "00" =>   data_out_int <= data_in;
            when "01" =>   data_out_int <= quant_out;
            when "10" =>   data_out_int <= lim_out;
            when others => data_out_int <= data_in;
        end case;
    end process;


    -- Assign output
    data_out <= data_out_int;
    
end architecture;
