library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity integrator_96s_dsp is
end entity;

architecture behavior of integrator_96s_dsp is

	--signal CARRYOUT0	:std_logic_vector(3 downto 0);
	signal CARRYOUT0	:std_logic;
	signal RESULT0		:std_logic_vector(47 downto 0);
	signal A0			:std_logic_vector(47 downto 0);
	signal ADD_SUB0		:std_logic := '1';
	signal B0			:std_logic_vector(47 downto 0);
	signal CARRYIN0		:std_logic;
	signal CE0			:std_logic := '1';
	signal CLK0			:std_logic;
	signal RST0			:std_logic;

	signal CARRYOUT1	:std_logic;
	signal RESULT1		:std_logic_vector(47 downto 0);
	signal A1			:std_logic_vector(47 downto 0);
	signal ADD_SUB1		:std_logic := '1';
	signal B1			:std_logic_vector(47 downto 0);
	signal CARRYIN1		:std_logic;
	signal CE1			:std_logic := '1';
	signal CLK1			:std_logic;
	signal RST1			:std_logic;

	signal A			:std_logic_vector(95 downto 0) := (others => '0');
	signal RESULT		:std_logic_vector(95 downto 0) := (others => '0');
	signal REGA			:std_logic_vector(47 downto 0) := (others => '0');
	signal REGR			:std_logic_vector(47 downto 0) := (others => '0');

	
	signal clk : std_logic := '0';
	-- Clock period definition
	constant clk_period : time := 10 ns;
begin



	CLK0 <= clk;
	RST0 <= '0';
	CE0 <= '1';
	CARRYIN0 <= '0';
	A0 <= A(47 downto 0);
	B0 <= RESULT0;

	ADDSUB_MACRO_inst0 : ADDSUB_MACRO
	generic map (
		DEVICE   => "7SERIES", -- Target Device: "VIRTEX5", "7SERIES", "SPARTAN6"
		LATENCY  => 1, -- Desired clock cycle latency, 0-2
		WIDTH    => 48 -- Input / Output bus width, 1-48
	) port map (
		CARRYOUT => CARRYOUT0, -- 1-bit carry-out output signal
		RESULT   => RESULT0, -- Add/sub result output, width defined by WIDTH generic
		A        => A0, -- Input A bus, width defined by WIDTH generic
		ADD_SUB  => ADD_SUB0, -- 1-bit add/sub input, high selects add, low selects subtract
		B        => B0, -- Input B bus, width defined by WIDTH generic
		CARRYIN  => CARRYIN0, -- 1-bit carry-in input
		CE       => CE0, -- 1-bit clock enable input
		CLK      => CLK0, -- 1-bit clock input
		RST      => RST0 -- 1-bit active high synchronous reset
	);

      --DSP48_2: DSP48E1 
      --  generic map (
      --    ACASCREG => 0,       
      --    AREG => 0,   
      --    ADREG => 0,
      --    ALUMODEREG => 0,   
      --    BCASCREG => 0,       
      --    BREG => 0,           
      --    CREG => 0,      
      --    DREG => 0,
      --    MREG => 0,
      --    PREG => 1,           
      --    USE_MULT => "NONE") 
      -- port map (
      --    ACOUT => open,   
      --    BCOUT => open,  
      --    CARRYCASCOUT => open, 
      --    CARRYOUT => CARRYOUT0, 
      --    MULTSIGNOUT => open, 
      --    OVERFLOW => open, 
      --    P => RESULT0,          
      --    PATTERNBDETECT => open, 
      --    PATTERNDETECT => open, 
      --    PCOUT => open,  
      --    UNDERFLOW => open, 
      --    A => B0(47 downto 18),          
      --    ACIN => "000000000000000000000000000000",    
      --    ALUMODE => "0000", 
      --    B => B0(17 downto 0),          
      --    BCIN => "000000000000000000",    
      --    C => A0,           
      --    CARRYCASCIN => '0', 
      --    CARRYIN => CARRYIN0, 
      --    CARRYINSEL => "000", 
      --    CEA1 => CE0,      
      --    CEA2 => CE0,      
      --    CEAD => '0',
      --    CEALUMODE => CE0, 
      --    CEB1 => CE0,      
      --    CEB2 => CE0,      
      --    CEC => CE0,      
      --    CECARRYIN => CE0, 
      --    CECTRL => CE0,
      --    CED => '0',
      --    CEINMODE => '0', 
      --    CEM => '0',       
      --    CEP => CE0,       
      --    CLK => CLK,       
      --    D => "0000000000000000000000000",
      --    INMODE => "00000", 
      --    MULTSIGNIN => '0', 
      --    OPMODE => "0110011", 
      --    PCIN => "000000000000000000000000000000000000000000000000",      
      --    RSTA => RST0,     
      --    RSTALLCARRYIN => RST0, 
      --    RSTALUMODE => RST0, 
      --    RSTB => RST0,     
      --    RSTC => RST0,     
      --    RSTCTRL => RST0, 
      --    RSTD => RST0,
      --    RSTINMODE => RST0,
      --    RSTM => RST0, 
      --    RSTP => RST0 
      -- );

	process (clk) is
	begin
		if rising_edge (clk) then
			REGA <= A(95 downto 48);
		end if;
	end process;

	CLK1 <= clk;
	RST1 <= '0';
	CE1 <= '1';
	--CARRYIN1 <= CARRYOUT0(0);
	CARRYIN1 <= CARRYOUT0;
	A1 <= REGA;
	B1 <= RESULT1;

	ADDSUB_MACRO_inst1 : ADDSUB_MACRO
	generic map (
		DEVICE   => "7SERIES", -- Target Device: "VIRTEX5", "7SERIES", "SPARTAN6"
		LATENCY  => 1, -- Desired clock cycle latency, 0-2
		WIDTH    => 48 -- Input / Output bus width, 1-48
	) port map (
		CARRYOUT => CARRYOUT1, -- 1-bit carry-out output signal
		RESULT   => RESULT1, -- Add/sub result output, width defined by WIDTH generic
		A        => A1, -- Input A bus, width defined by WIDTH generic
		ADD_SUB  => ADD_SUB1, -- 1-bit add/sub input, high selects add, low selects subtract
		B        => B1, -- Input B bus, width defined by WIDTH generic
		CARRYIN  => CARRYIN1, -- 1-bit carry-in input
		CE       => CE1, -- 1-bit clock enable input
		CLK      => CLK1, -- 1-bit clock input
		RST      => RST1 -- 1-bit active high synchronous reset
	);

	process (clk) is
	begin
		if rising_edge (clk) then
			REGR <= RESULT0;
		end if;
	end process;


	RESULT <= RESULT1 & REGR;

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
		A <= x"FFFFFFFFFFFF" & std_logic_vector(to_signed(-1,48));
		wait;
	end process;

	process (clk) is
	begin
		if rising_edge (clk) then
		end if;
	end process;

end architecture;
