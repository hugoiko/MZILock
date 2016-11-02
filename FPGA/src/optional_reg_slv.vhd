library ieee;
use ieee.std_logic_1164.all;

entity optional_reg_slv is
generic (
    DWIDTH : integer := 32;
    USEREG : integer := 0
);
port (
    clk : in  std_logic;
    ce  : in  std_logic;
    rst : in  std_logic;
    di  : in  std_logic_vector(DWIDTH-1 downto 0);
    do  : out std_logic_vector(DWIDTH-1 downto 0)
);
end entity;

architecture Behavioral of optional_reg_slv is
    
    signal di_reg : std_logic_vector(DWIDTH-1 downto 0) := (others => '0');
    signal do_int : std_logic_vector(DWIDTH-1 downto 0);
    
begin
    
    the_register : process (clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                di_reg <= (others => '0');
            else
                if ce = '1' then
                    di_reg <= di;
                end if;
            end if;
        end if;
    end process;

    the_multiplexer : process (USEREG, di_reg, di) is
    begin
        if USEREG = 1 then
            do_int <= di_reg;
        else
            di_reg <= di;
        end if;
    end process;

    do <= do_int;

end architecture;
