

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 
-- Using MATLAB's notation:
-- dout = filter([0, coef/(2^COEF_WIDTH), -coef/(2^COEF_WIDTH)],[1, -1+coef/(2^COEF_WIDTH)], din);
-- 

entity derivative_with_filter is
generic (
    DATA_WIDTH : integer := 16;
    COEF_WIDTH : integer := 16
);
port (
    clk       : in  std_logic;
    ce        : in  std_logic;
    coef      : in  std_logic_vector(COEF_WIDTH-1 downto 0);
    din       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    dout      : out std_logic_vector(DATA_WIDTH-1 downto 0);
    railed_hi : out std_logic;
    railed_lo : out std_logic
);
end entity;

architecture behavioral of derivative_with_filter is
    
    signal coef_reg : std_logic_vector(COEF_WIDTH+1-1 downto 0) := (others => '0');
    
    signal din_int : std_logic_vector(DATA_WIDTH+2-1 downto 0);
	signal din_dly : std_logic_vector(DATA_WIDTH+2-1 downto 0) := (others => '0');
    signal din_deriv : std_logic_vector(DATA_WIDTH+2-1 downto 0);
    
    signal internal_sum : std_logic_vector(DATA_WIDTH+2+COEF_WIDTH+1-1 downto 0) := (others => '0');
    signal internal_sum_rs : std_logic_vector(DATA_WIDTH+2-1 downto 0) := (others => '0');
    
    signal delta : std_logic_vector(DATA_WIDTH+2-1 downto 0) := (others => '0');

    signal dout_int : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal railed_hi_int : std_logic := '0';
    signal railed_lo_int : std_logic := '0';
    
    attribute use_dsp48 : string;
    attribute use_dsp48 of internal_sum : signal is "yes";

begin
    
    -- Input stage
    din_int <= std_logic_vector(resize(signed(din), DATA_WIDTH+2));
    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                coef_reg <= std_logic_vector(resize(unsigned(coef), COEF_WIDTH+1));
                din_dly <= din_int;
            end if;
        end if;
    end process;
    
    -- Derivative stage
    din_deriv <= std_logic_vector(signed(din_int) - signed(din_dly));
	
    -- Filter stage
    delta <= std_logic_vector(signed(din_deriv) - signed(internal_sum_rs));
    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                internal_sum <= std_logic_vector(signed(internal_sum) + signed(delta)*signed(coef_reg));
            end if;
        end if;
    end process;
    internal_sum_rs <= std_logic_vector(resize(shift_right(signed(internal_sum), COEF_WIDTH), DATA_WIDTH+2));
    
    process (internal_sum_rs) is
    begin
        if (internal_sum_rs(DATA_WIDTH+1) = '0' and internal_sum_rs(DATA_WIDTH downto DATA_WIDTH-1) /= "00") then
            dout_int <= (DATA_WIDTH-1 => '0', others => '1');
            railed_hi_int <= '1';
            railed_lo_int <= '0';
        elsif (internal_sum_rs(DATA_WIDTH+1) = '1' and internal_sum_rs(DATA_WIDTH downto DATA_WIDTH-1) /= "11") then
            dout_int <= (DATA_WIDTH-1 => '1', others => '0');
            railed_hi_int <= '0';
            railed_lo_int <= '1';
        else
            dout_int <= internal_sum_rs(DATA_WIDTH-1 downto 0);
            railed_hi_int <= '0';
            railed_lo_int <= '0';
        end if;
    end process;

    -- Output stage
    dout <= dout_int;
    railed_hi <= railed_hi_int;
    railed_lo <= railed_lo_int;

end architecture;
