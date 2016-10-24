library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity range_select_96s_to_25s_testbench is
end range_select_96s_to_25s_testbench;

architecture behavior of range_select_96s_to_25s_testbench is
	component range_select_96s_to_25s is
	port (
	    clk          : in  std_logic;
	    ce           : in  std_logic;
	    range_input  : in  std_logic_vector(2 downto 0);
	    data_input   : in  std_logic_vector(95 downto 0);
	    railed_hi    : out std_logic;
	    railed_lo    : out std_logic;
	    range_output : out std_logic_vector(2 downto 0);
	    data_output  : out std_logic_vector(24 downto 0)
	);
	end component;


	-- Inputs
	signal clk :  std_logic := '0';
	signal ce :  std_logic := '1';
	signal range_input :  std_logic_vector(2 downto 0) := "000";
	--                                                    x"                        "
	signal data_input :  std_logic_vector(95 downto 0) := x"FFFFFFFFFFF4534435435534";
	
	-- Outputs
	signal railed_hi : std_logic;
	signal railed_lo : std_logic;
	signal data_output : std_logic_vector(24 downto 0);
	signal range_output :  std_logic_vector(2 downto 0);
	
	-- Clock period definition
	constant clk_period : time := 5 ns;
begin

	-- Unit under test
	range_select_96s_to_25s_inst : range_select_96s_to_25s
	port map (
		clk => clk,
		ce => ce,
		range_input => range_input,
		data_input => data_input,
		railed_hi => railed_hi,
		railed_lo => railed_lo,
		range_output => range_output,
		data_output => data_output
	);

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
		range_input <= "000";
		wait until rising_edge(clk);
		range_input <= "001";
		wait until rising_edge(clk);
		range_input <= "010";
		wait until rising_edge(clk);
		range_input <= "011";
		wait until rising_edge(clk);
		range_input <= "100";
		wait until rising_edge(clk);
		range_input <= "101";
		wait until rising_edge(clk);
		range_input <= "110";
		wait until rising_edge(clk);
		range_input <= "111";
		wait;
	end process;
	
end architecture;
