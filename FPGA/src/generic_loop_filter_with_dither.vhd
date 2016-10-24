library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity generic_loop_filter_with_dither is
generic (
    INPUT_WIDTH      : integer := 16;
    OUTPUT_WIDTH     : integer := 16;
    GAIN_WIDTH       : integer := 24;
    MULT_SIZE        : integer := 18;
    RIGHTSHIFTS      : integer := 12;
    N_RIGHTSHIFTS_D  : integer := 1;
    N_RIGHTSHIFTS_P  : integer := 2;
    N_RIGHTSHIFTS_I  : integer := 4;
    N_RIGHTSHIFTS_II : integer := 8
);
port (
    clk            : in  std_logic;
    ce             : in  std_logic;
    
    clr            : in  std_logic;
    lock           : in  std_logic;
    
    gain_d         : in  std_logic(GAIN_WIDTH-1 downto 0);
    gain_d_fb      : in  std_logic(GAIN_WIDTH-1 downto 0);
    gain_p         : in  std_logic(GAIN_WIDTH-1 downto 0);
    gain_i         : in  std_logic(GAIN_WIDTH-1 downto 0);
    gain_ii        : in  std_logic(GAIN_WIDTH-1 downto 0);

    rightshifts_d  : in  std_logic_vector(N_RIGHTSHIFTS_D-1 downto 0);
    rightshifts_p  : in  std_logic_vector(N_RIGHTSHIFTS_P-1 downto 0);
    rightshifts_i  : in  std_logic_vector(N_RIGHTSHIFTS_I-1 downto 0);
    rightshifts_ii : in  std_logic_vector(N_RIGHTSHIFTS_II-1 downto 0);
    
    data_input     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
    data_output    : out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
);
end entity;

architecture Behavioral of generic_loop_filter_with_dither is
    

begin

    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- P Branch
    ----------------------------------------------------------------



    
end architecture;
