library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity mult_int32_float32_int16 is
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    integer_in  : in  std_logic_vector(31 downto 0);
    float_in    : in  std_logic_vector(31 downto 0);
    integer_out : out std_logic_vector(15 downto 0)
);
end entity;

architecture Behavioral of mult_int32_float32_int16 is
    

    signal data_input64 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input32 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input16 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input8 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input4 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input2 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input1 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_input0 : std_logic_vector(31 downto 0) := (others => '0');

    signal data_output64 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output32 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output16 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output8 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output4 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output2 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output1 : std_logic_vector(31 downto 0) := (others => '0');
    signal data_output0 : std_logic_vector(31 downto 0) := (others => '0');

begin
                data_input64 <= integer_in;
    
                data_input8  <= data_output16;
                data_input1  <= data_output2;

    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                data_input32 <= data_output64;
                data_input16 <= data_output32;
                data_input4  <= data_output8;
                data_input2  <= data_output4;
            end if;
        end if;
    end process;

                data_input0  <= data_output1;

    data_output0 <= data_input0;

    integer_out <= data_output0(15 downto 0);

    safe_signed_bit_shift_inst64 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(13 downto 12),
        data_in  => data_input64,
        data_out => data_output64
    );



    safe_signed_bit_shift_inst32 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(11 downto 10),
        data_in  => data_input32,
        data_out => data_output32
    );

    safe_signed_bit_shift_inst16 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(9 downto 8),
        data_in  => data_input16,
        data_out => data_output16
    );

    safe_signed_bit_shift_inst8 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(7 downto 6),
        data_in  => data_input8,
        data_out => data_output8
    );

    safe_signed_bit_shift_inst4 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(5 downto 4),
        data_in  => data_input4,
        data_out => data_output4
    );

    safe_signed_bit_shift_inst2 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(3 downto 2),
        data_in  => data_input2,
        data_out => data_output2
    );

    safe_signed_bit_shift_inst1 : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH  => 32,
        BIT_SHIFT   => 64,
        QUANT_TYPE  => 2
    )
    port map (
        clk      => clk,
        ce       => ce,
        opmode   => float_in(1 downto 0),
        data_in  => data_input1,
        data_out => data_output1
    );



end architecture;
