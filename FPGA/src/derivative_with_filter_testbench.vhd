
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

entity derivative_with_filter_testbench is
end entity;

architecture behavior OF derivative_with_filter_testbench is 

-- Component Declaration for the Unit Under Test (UUT)

    component derivative_with_filter is
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
    end component;

    constant COEF_WIDTH   : integer := 24;
    constant DATA_WIDTH  : integer := 16;

    --Inputs
    signal clk : std_logic := '0';
    signal coef : std_logic_vector(COEF_WIDTH-1 downto 0) := (others => '0');
    signal din : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    --Outputs
    signal dout : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal railed_hi : std_logic;
    signal railed_lo : std_logic;

    -- Clock period definitions
    constant clk_period : time := 10 ns;


    signal rand_num : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ramp : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: derivative_with_filter
    GENERIC MAP (
        DATA_WIDTH => DATA_WIDTH,
        COEF_WIDTH => COEF_WIDTH
    )
    PORT MAP (
        clk       => clk,
        ce        => '1',
        coef      => coef,
        din       => din,
        dout      => dout,
        railed_hi => railed_hi,
        railed_lo => railed_lo
    );

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;


    -- Random numbers and ramp
    process (clk) is
        variable seed1: positive := 1;
        variable seed2: positive := 1;
        variable rand: real := 0.0;
    begin
        if rising_edge(clk) then
            uniform(seed1, seed2, rand);
            rand_num <= std_logic_vector(to_signed(integer(rand*400.0*2.0-400.0), DATA_WIDTH));
            ramp <= std_logic_vector(signed(ramp) + 1);
        end if;
    end process;

    -- din <= rand_num;

    -- Stimulus process
    stim_proc: process
    begin        
        -- hold reset state for 100 ns.
        wait for 100 ns;  

        wait for clk_period*10;

        wait until rising_edge(clk);
        coef <= std_logic_vector(to_signed(3777216, COEF_WIDTH));

        wait for clk_period*10;
        wait until rising_edge(clk);
        din <= std_logic_vector(to_signed(-32768, DATA_WIDTH));

        wait for clk_period*10;
        wait until rising_edge(clk);
        din <= std_logic_vector(to_signed(32767, DATA_WIDTH));



        --wait until rising_edge(clk);
        --din <= std_logic_vector(to_signed(10000, DATA_WIDTH));
        --wait until rising_edge(clk);
        --din <= std_logic_vector(to_signed(0, DATA_WIDTH));

        -- insert stimulus here 

    wait;
    end process;

end;
