library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

-- No wrap-arounds possible if data_input is limited to [-2**(DATA_WIDTH-2), 2**(DATA_WIDTH-2)-1]

entity switchable_lossless_quantifier is
generic (
    DATA_WIDTH  : integer := 32;
    RIGHT_SHIFT : integer := 16;
    QUANT_TYPE  : integer := 1;
    REG_OUTPUT  : integer := 1
);
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    quantify    : in  std_logic;
    rightshift  : in  std_logic;
    data_input  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    data_output : out std_logic_vector(DATA_WIDTH-1 downto 0)
);
end entity;

architecture Behavioral of switchable_lossless_quantifier is
    
    signal sum_output : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal qerr_z_0 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal qerr_z_1 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal qout : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal qout_rs : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal feedback : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_output_int : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    feedback_regs_type0: if (QUANT_TYPE = 0) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    feedback <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    feedback_regs_type1: if (QUANT_TYPE = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    feedback <= qerr_z_0;
                end if;
            end if;
        end process;
    end generate;

    feedback_regs_type2: if (QUANT_TYPE = 2) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    qerr_z_1 <= qerr_z_0;
                    feedback <= std_logic_vector(shift_left(signed(qerr_z_0), 1) - signed(qerr_z_1));
                end if;
            end if;
        end process;
    end generate;


    main_adder : process(data_input, feedback) is 
    begin
        sum_output <= std_logic_vector(signed(feedback) + signed(data_input));
    end process;


    sum_output_select : process (sum_output, quantify) is
    begin
        if quantify = '1' then
            qout(DATA_WIDTH-1 downto RIGHT_SHIFT) <= sum_output(DATA_WIDTH-1 downto RIGHT_SHIFT);
            qout(RIGHT_SHIFT-1 downto 0) <= (others => '0');
            qerr_z_0(RIGHT_SHIFT-1 downto 0) <= sum_output(RIGHT_SHIFT-1 downto 0);
            qerr_z_0(DATA_WIDTH-1 downto RIGHT_SHIFT) <= (others => '0');
        else
            qout <= sum_output;
            qerr_z_0 <= (others => '0');
        end if;
    end process;

    qout_rs <= std_logic_vector(shift_right(signed(qout), RIGHT_SHIFT));

    register_output_yes: if (REG_OUTPUT = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    if rightshift = '0' then
                        data_output_int <= qout;
                    else
                        data_output_int <= qout_rs;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    register_output_no: if (REG_OUTPUT = 0) generate
    begin
        process (rightshift, qout, qout_rs) is
        begin
            if rightshift = '0' then
                data_output_int <= qout;
            else
                data_output_int <= qout_rs;
            end if;
        end process;
    end generate;

    -- Assign output
    data_output <= data_output_int;
    
end architecture;
