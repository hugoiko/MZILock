library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity signed_sum_with_saturation is
generic (
    DATA_WIDTH : integer := 16;
    REGISTER_OUTPUT : integer := 0
);
port (
    clk       : in  std_logic;
    ce        : in  std_logic;
    a         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    b         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    c         : out std_logic_vector(DATA_WIDTH-1 downto 0);
    railed_hi : out std_logic;
    railed_lo : out std_logic
);
end entity;

architecture Behavioral of signed_sum_with_saturation is

    signal sum: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    constant max_value : std_logic_vector(DATA_WIDTH-1 downto 0) := (DATA_WIDTH-1 => '0', others => '1');
    constant min_value : std_logic_vector(DATA_WIDTH-1 downto 0) := (DATA_WIDTH-1 => '1', others => '0');
 

    signal c_int         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal railed_hi_int : std_logic := '0';
    signal railed_lo_int : std_logic := '0';

begin

    process (a, b, sum) is
    begin
        sum <= std_logic_vector(signed(a) + signed(b));
        if (a(a'left) = '0' and b(b'left) = '0' and sum(sum'left) = '1') then
            c_int <= max_value;
            railed_hi_int <= '1';
            railed_lo_int <= '0';
        elsif (a(a'left) = '1' and b(b'left) = '1' and sum(sum'left) = '0') then
            c_int <= min_value;
            railed_hi_int <= '0';
            railed_lo_int <= '1';
        else
            c_int <= sum; 
            railed_hi_int <= '0';
            railed_lo_int <= '0';
        end if;
    end process;

    oreg_0: if (REGISTER_OUTPUT = 0) generate
    begin
        process (c_int, railed_hi_int, railed_lo_int) is
        begin
            c         <= c_int;
            railed_hi <= railed_hi_int;
            railed_lo <= railed_lo_int;
        end process;
    end generate;
    oreg_1: if (REGISTER_OUTPUT = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    c         <= c_int;
                    railed_hi <= railed_hi_int;
                    railed_lo <= railed_lo_int;
                end if;
            end if;
        end process;
    end generate;

end architecture;
