library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity hdr_gain_96s is
generic (
    OUTPUT_WIDTH : integer := 16;
);
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    clr         : in  std_logic;
    data_input  : in  std_logic_vector(95 downto 0);
    gain_expon  : in  std_logic_vector(2 downto 0);
    gain_mant   : in  std_logic_vector(17 downto 0);
    data_output : out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
);
end entity;

architecture Behavioral of hdr_gain_96s is

    constant EXTRA_LSBS : integer := 25-12;

    signal clr_reg : std_logic := '0';

    signal data_input_reg0 : std_logic_vector(96-1+EXTRA_LSBS downto 0);
    signal data_input_reg1 : std_logic_vector(48-1+EXTRA_LSBS downto 0);
    signal data_input_reg2 : std_logic_vector(24-1+EXTRA_LSBS downto 0);
    signal data_input_reg3 : std_logic_vector(12-1+EXTRA_LSBS downto 0);

    signal gain_expon_reg0 : std_logic_vector(2 downto 0) := (others => '0');
    signal gain_expon_reg1 : std_logic_vector(2 downto 0) := (others => '0');
    signal gain_expon_reg2 : std_logic_vector(2 downto 0) := (others => '0');
    signal gain_expon_reg3 : std_logic_vector(2 downto 0) := (others => '0');

    signal gain_mant_reg0 : std_logic_vector(17 downto 0) := (others => '0');
    signal gain_mant_reg1 : std_logic_vector(17 downto 0) := (others => '0');
    signal gain_mant_reg2 : std_logic_vector(17 downto 0) := (others => '0');
    signal gain_mant_reg3 : std_logic_vector(17 downto 0) := (others => '0');

    signal mult_out : std_logic_vector(42 downto 0) := (others => '0');
begin

    reset_delay : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                clr_reg <= clr;
            end if;
        end if;
    end process;

    input_registers : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                if clr_reg = '1' then
                    data_input_reg0 <= (others => '0');
                    gain_expon_reg0 <= (others => '0');
                    gain_expon_reg1 <= (others => '0');
                    gain_expon_reg2 <= (others => '0');
                    gain_expon_reg3 <= (others => '0');
                    gain_mant_reg0  <= (others => '0');
                    gain_mant_reg1  <= (others => '0');
                    gain_mant_reg2  <= (others => '0');
                    gain_mant_reg3  <= (others => '0');
                else

                    data_input_reg0 <= data_input & (EXTRA_LSBS-1 downto 0 => '0');
                    gain_expon_reg0 <= gain_expon;
                    gain_expon_reg1 <= gain_expon_reg0;
                    gain_expon_reg2 <= gain_expon_reg1;
                    gain_expon_reg3 <= gain_expon_reg2;
                    gain_mant_reg0  <= gain_mant;
                    gain_mant_reg1  <= gain_mant_reg0;
                    gain_mant_reg2  <= gain_mant_reg1;
                    gain_mant_reg3  <= gain_mant_reg2;
                    
                end if;


            end if;
        end if;
    end process;

    exponent_mux : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                if clr_reg = '1' then
                    data_input_reg1 <= (others => '0');
                    data_input_reg2 <= (others => '0');
                    data_input_reg3 <= (others => '0');
                else
                    if gain_expon_reg0(2) = '1'
                        data_input_reg1 <= data_input_reg0(96-1+EXTRA_LSBS downto 48);
                    else
                        data_input_reg1 <= data_input_reg0(48-1+EXTRA_LSBS downto  0);
                    end if;

                    if gain_expon_reg1(1) = '1'
                        data_input_reg2 <= data_input_reg1(48-1+EXTRA_LSBS downto 24);
                    else
                        data_input_reg2 <= data_input_reg1(24-1+EXTRA_LSBS downto  0);
                    end if;

                    if gain_expon_reg2(0) = '1'
                        data_input_reg3 <= data_input_reg2(24-1+EXTRA_LSBS downto 12);
                    else
                        data_input_reg3 <= data_input_reg2(12-1+EXTRA_LSBS downto  0);
                    end if;
                end if;

            end if;
        end if;
    end process;

    multiplier : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_reg = '1' then
                    mult_out <= (others => '0');
                else
                    mult_out <= std_logic_vector(signed(data_input_reg3) * signed(gain_mant_reg3));
                end if;
            end if;
        end if;
    end process;

    data_output <= mult_out(43-1 downto 43-OUTPUT_WIDTH);
   

end architecture;
