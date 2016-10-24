library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity integrator_testbench is
end integrator_testbench;

architecture behavior of integrator_testbench is

	constant DATA_WIDTH : integer := 96;

	component integrator_96s_dsp48 is
	port (
	    clk         : in  std_logic;
	    ce          : in  std_logic;
	    clr         : in  std_logic;
	    limit_incr  : in  std_logic;
	    limit_decr  : in  std_logic;
	    data_input  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
	    railed_hi   : out std_logic;
	    railed_lo   : out std_logic;
	    data_output : out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
	end component;


	-- Inputs
	signal clk :  std_logic := '0';
	signal ce :  std_logic := '1';
	signal clr :  std_logic := '0';
	signal limit_incr :  std_logic := '0';
	signal limit_decr :  std_logic := '0';
	signal data_input :  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
	
	-- Outputs
	signal railed_hi : std_logic;
	signal railed_lo : std_logic;
	signal data_output : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	-- Clock period definition
	constant clk_period : time := 5 ns;
begin

	-- Unit under test
	integrator_inst : integrator_96s_dsp48
	port map (
		clk => clk,
		ce => ce,
		clr => clr,
		limit_incr => limit_incr,
		limit_decr => limit_decr,
		data_input => data_input,
		railed_hi => railed_hi,
		railed_lo => railed_lo,
		data_output => data_output
	);

	process (clk) is
	begin
		if rising_edge(clk) then

			limit_incr <= railed_hi;
			limit_decr <= railed_lo;

		end if;
	end process;

	-- Clock process definition for "clk"
	process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	-- Stimulus process
	process
	begin
		wait for clk_period*10;
		wait until rising_edge(clk);
		data_input <= x"010000000000_000000000000";
		--data_input <= x"010000000000";
		wait until rising_edge(clk);
		wait for clk_period*140;
		wait until rising_edge(clk);
		data_input <= x"FF0000000000_000000000000";
		--data_input <= x"FF0000000000";

		wait for clk_period*400;
		wait until rising_edge(clk);
		clr <= '1';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		clr <= '0';


		wait;
	end process;
end;
