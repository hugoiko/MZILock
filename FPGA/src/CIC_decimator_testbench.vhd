
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

ENTITY CIC_decimator_testbench IS
END CIC_decimator_testbench;

ARCHITECTURE behavior OF CIC_decimator_testbench IS 

-- Component Declaration for the Unit Under Test (UUT)
    component CIC_decimator
    generic (
        INPUT_WIDTH : integer := 32;
        LOG2_DECIM  : integer := 0;
        LOG2_FILT   : integer := 2
    );
    port (
        clk     : in  std_logic;
        ce      : in  std_logic;
        din     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
        dout    : out std_logic_vector(INPUT_WIDTH-1 downto 0);
        flag    : out std_logic
    );
    end component;

    constant INPUT_WIDTH : integer := 16;
    constant LOG2_DECIM  : integer := 4;
    constant LOG2_FILT   : integer := 2;

    --Inputs
    signal clk : std_logic := '0';
    signal ce  : std_logic := '0';
    signal din : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');

    --Outputs
    signal dout : std_logic_vector(INPUT_WIDTH-1 downto 0);
    signal flag : std_logic;

    -- Clock period definitions
    constant clk_period : time := 10 ns;


    signal rand_num : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');
    signal ramp : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');

BEGIN

    -- Instantiate the Unit Under Test (UUT)
    uut: CIC_decimator
    GENERIC MAP (
        INPUT_WIDTH => INPUT_WIDTH,
        LOG2_DECIM => LOG2_DECIM,
        LOG2_FILT => LOG2_FILT
    )
    PORT MAP (
        clk => clk,
        ce => ce,
        din => din,
        dout => dout,
        flag => flag
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
            -- rand_num <= std_logic_vector(to_signed(integer(rand*32767.0*2.0-32767.0), INPUT_WIDTH));
            rand_num <= std_logic_vector(to_signed(integer(rand*400.0*2.0-400.0), INPUT_WIDTH));
            ramp <= std_logic_vector(signed(ramp) + 1);
        end if;
    end process;

    din <= rand_num;


    -- Stimulus process
    stim_proc: process
    begin    
        -- hold reset state for 100 ns.
        wait for 100 ns;  

        wait for clk_period*10;

        wait until rising_edge(clk);
        

        -- insert stimulus here 

        wait;
    end process;

END;
