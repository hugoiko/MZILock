library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity switchable_lossless_quantifier_testbench is
end switchable_lossless_quantifier_testbench;

architecture behavior of switchable_lossless_quantifier_testbench is


	component hdr_gain is
	generic (
	    INPUT_WIDTH : integer := 32;
	    OUTPUT_WIDTH : integer := 16;
	    N_SHIFTERS : integer := 6;
	    QUANT_TYPE : integer := 2
	);
	port (
	    clk         : in  std_logic;
	    ce          : in  std_logic;
	    data_in     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
	    cmd_in      : in  std_logic_vector(31 downto 0);
	    data_out    : out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
	);
	end component;

	constant INPUT_WIDTH : integer := 12;
	constant OUTPUT_WIDTH : integer := 8;

	-- Inputs
	signal clk :  std_logic := '0';
	signal ce :  std_logic := '1';
	signal data_in :  std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');
	signal cmd_in :  std_logic_vector(32-1 downto 0) := (others => '0');

	signal enable_data : std_logic := '0';
	
	-- Outputs
	signal data_out : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
	
	-- Clock period definition
	constant clk_period : time := 5 ns;

	-- random numbers

    signal rand_num : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');
    signal ramp : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');



	signal integral1 :  std_logic_vector(32-1 downto 0) := (others => '0');
	signal integral2 :  std_logic_vector(32-1 downto 0) := (others => '0');

	signal dbl_integral1 :  std_logic_vector(32-1 downto 0) := (others => '0');
	signal dbl_integral2 :  std_logic_vector(32-1 downto 0) := (others => '0');

begin

	-- Unit under test
	hdr_gain_inst : hdr_gain
	generic map (
	    INPUT_WIDTH => INPUT_WIDTH,
	    OUTPUT_WIDTH => OUTPUT_WIDTH,
	    N_SHIFTERS => 6,
	    QUANT_TYPE => 2
	) port map (
	    clk        => clk,
	    ce         => '1',
	    data_in    => data_in,
	    cmd_in     => cmd_in,
	    data_out   => data_out
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
			-- rand_num <= std_logic_vector(to_signed(integer(rand*32767.0*2.0-32767.0), INPUT_WIDTH));
			rand_num <= std_logic_vector(to_signed(integer(rand*400.0*2.0-400.0), INPUT_WIDTH));
			ramp <= std_logic_vector(signed(ramp) + 1);
		end if;
	end process;


	--data_input <= rand_num;
	data_in <= rand_num when (enable_data = '1') else (others => '0');

	process (clk) is
	begin
		if rising_edge(clk) then
			integral1 <= std_logic_vector(signed(integral1) + resize(signed(data_in),32));
			integral2 <= std_logic_vector(signed(integral2) + resize(signed(data_out),32));
			
			dbl_integral1 <= std_logic_vector(signed(dbl_integral1) + signed(integral1));
			dbl_integral2 <= std_logic_vector(signed(dbl_integral2) + signed(integral2));
		end if;
	end process;


	-- Stimulus process
	process
	begin
		
		wait for clk_period*10;
		wait until rising_edge(clk);

		-- cmd_in <= "1" & "010010" & std_logic_vector(resize(signed(ramp), 25));
		cmd_in <= "0" & "100000" & std_logic_vector(to_signed(65536, 25));
		enable_data <= '1';


		wait;
	end process;
end;
