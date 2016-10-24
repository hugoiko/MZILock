library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity switchable_lossless_quantifier_testbench is
end switchable_lossless_quantifier_testbench;

architecture behavior of switchable_lossless_quantifier_testbench is


	component safe_signed_bit_shift is
	generic (
	    DATA_WIDTH  : positive := 32;
	    BIT_SHIFT   : positive := 64;
	    QUANT_TYPE  : natural  := 1
	);
	port (
	    clk      : in  std_logic;
	    ce       : in  std_logic;
	    opmode   : in  std_logic_vector(1 downto 0);
	    data_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
	    data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
	end component;

	constant DATA_WIDTH : integer := 24;
	constant BIT_SHIFT : integer := 16;

	-- Inputs
	signal clk :  std_logic := '0';
	signal ce :  std_logic := '1';
	signal data_input :  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
	
	-- Outputs
	signal data_output : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	-- Clock period definition
	constant clk_period : time := 5 ns;

	-- random numbers

    signal rand_num : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');



	signal integral1 :  std_logic_vector(32-1 downto 0) := (others => '0');
	signal integral2 :  std_logic_vector(32-1 downto 0) := (others => '0');

	signal dbl_integral1 :  std_logic_vector(32-1 downto 0) := (others => '0');
	signal dbl_integral2 :  std_logic_vector(32-1 downto 0) := (others => '0');

begin

	-- Unit under test
	safe_signed_bit_shift_inst : safe_signed_bit_shift
	generic map (
	    DATA_WIDTH  => DATA_WIDTH,
	    BIT_SHIFT   => BIT_SHIFT,
	    QUANT_TYPE  => 2
	)
	port map (
	    clk      => clk,
	    ce       => ce,
	    opmode   => "01",
	    data_in  => data_input,
	    data_out => data_output
	);

	-- Clock process definition for "clk"
	process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	process (clk) is
	    variable seed1: positive := 1;
	    variable seed2: positive := 1;
	    variable rand: real := 0.0;
	begin
		if rising_edge(clk) then
			uniform(seed1, seed2, rand);
			-- rand_num <= std_logic_vector(to_signed(integer(rand*32767.0*2.0-32767.0), DATA_WIDTH));
			rand_num <= std_logic_vector(to_signed(integer(rand*400.0*2.0-400.0), DATA_WIDTH));
		end if;
	end process;


	data_input <= rand_num;

	process (clk) is
	begin
		if rising_edge(clk) then
			integral1 <= std_logic_vector(signed(integral1) + resize(signed(data_input),32));
			integral2 <= std_logic_vector(signed(integral2) + resize(signed(data_output),32));
			
			dbl_integral1 <= std_logic_vector(signed(dbl_integral1) + signed(integral1));
			dbl_integral2 <= std_logic_vector(signed(dbl_integral2) + signed(integral2));
		end if;
	end process;


	-- Stimulus process
	process
	begin
		
		wait for clk_period*10;
		wait until rising_edge(clk);


		wait;
	end process;
end;
