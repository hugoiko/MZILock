library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity switchable_limiter is
generic (
    DATA_WIDTH  : integer := 32;
    LEFT_SHIFT  : integer := 16;
    GUARD_BITS  : integer := 0;
    REG_OUTPUT  : integer := 1
);
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    limit       : in  std_logic;
    leftshift   : in  std_logic;
    data_input  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    data_output : out std_logic_vector(DATA_WIDTH-1 downto 0);
    railed_hi   : out std_logic;
    railed_lo   : out std_logic
);
end entity;

architecture Behavioral of switchable_limiter is
    
    signal railed_hi_int : std_logic;
    signal railed_lo_int : std_logic;

    signal data_limited : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_limited_ls : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    railed_hi_int <= '1' when ( data_input(DATA_WIDTH-1 downto DATA_WIDTH-LEFT_SHIFT-GUARD_BITS-1) /= (others => '0') and data_input(DATA_WIDTH-1) = '0' ) else '0';
    railed_lo_int <= '1' when ( data_input(DATA_WIDTH-1 downto DATA_WIDTH-LEFT_SHIFT-GUARD_BITS-1) /= (others => '1') and data_input(DATA_WIDTH-1) = '1' ) else '0';


    process (data_input, railed_hi_int, railed_lo_int) is
    begin
        if railed_hi_int = '1' and limit = '1' then
            data_limited <= (DATA_WIDTH-1 => '0', others => '1');
        elsif railed_lo_int = '1' and limit = '1' then
            data_limited <= (DATA_WIDTH-1 => '1', others => '0');
        else
            data_limited <= data_input;
        end if;
    end process;

    data_limited_ls <= std_logic_vector(shift_left(signed(data_limited), LEFT_SHIFT));

    register_output_yes: if (REG_OUTPUT = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    if leftshift = '0' then
                        data_output_int <= data_limited_ls;
                    else
                        data_output_int <= data_limited;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    register_output_no: if (REG_OUTPUT = 0) generate
    begin
        process () is
        begin
            if leftshift = '0' then
                data_output_int <= data_limited_ls;
            else
                data_output_int <= data_limited;
            end if;
        end process;
    end generate;

    -- Assign output
    data_output <= data_output_int;
    
end architecture;
