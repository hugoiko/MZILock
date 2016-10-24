library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity range_select_96s_to_25s is
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
end entity;

architecture Behavioral of range_select_96s_to_25s is
	signal stage_2				: std_logic_vector(95 downto 0) 	:= (others => '0');
	signal range_select_2		: std_logic_vector(2 downto 0) 		:= (others => '0');
	signal lsb_would_rail_hi_2	: std_logic;
	signal lsb_would_rail_lo_2	: std_logic;
	signal stage_1				: std_logic_vector(95 downto 0) 	:= (others => '0');
	signal range_select_1		: std_logic_vector(2 downto 0) 		:= (others => '0');
	signal lsb_would_rail_hi_1	: std_logic;
	signal lsb_would_rail_lo_1	: std_logic;
	signal stage_0				: std_logic_vector(95 downto 0) 	:= (others => '0');
	signal range_select_0		: std_logic_vector(2 downto 0) 		:= (others => '0');
	signal lsb_would_rail_hi_0	: std_logic;
	signal lsb_would_rail_lo_0	: std_logic;
	signal data_output_int		: std_logic_vector(95 downto 0) 	:= (others => '0');
	signal railed_hi_int		: std_logic;
	signal railed_lo_int		: std_logic;
	signal range_output_int		: std_logic_vector(2 downto 0) 		:= (others => '0');
begin

	-- Input stage
	process (clk) is
	begin
		if rising_edge(clk) then
			if ce = '1' then
				stage_2 <= data_input;
				range_select_2 <= range_input;
			end if;
		end if;
	end process;
	lsb_would_rail_hi_2 <= '1' when ( stage_2(95-1 downto 96-64-1) /= x"0000000000000000" and stage_2(95) = '0' ) else '0';
	lsb_would_rail_lo_2 <= '1' when ( stage_2(95-1 downto 96-64-1) /= x"FFFFFFFFFFFFFFFF" and stage_2(95) = '1' ) else '0';

	-- First internal stage (multiply by 2**64 or not)
	process (clk) is
	begin
		if rising_edge(clk) then
			if ce = '1' then

				if range_select_2(2) = '1' then
					if lsb_would_rail_hi_2 = '1' then
						stage_1 <= x"7FFFFFFFFFFFFFFFFFFFFFFF";
					elsif lsb_would_rail_lo_2 = '1' then
						stage_1 <= x"800000000000000000000000";
					else
						stage_1 <= stage_2(95-64 downto 0) & x"0000000000000000";
					end if;
				else
					stage_1 <= stage_2;
				end if;
				range_select_1 <= range_select_2;

			end if;
		end if;
	end process;
	lsb_would_rail_hi_1 <= '1' when ( stage_1(95-1 downto 96-32-1) /= x"00000000" and stage_1(95) = '0' ) else '0';
	lsb_would_rail_lo_1 <= '1' when ( stage_1(95-1 downto 96-32-1) /= x"FFFFFFFF" and stage_1(95) = '1' ) else '0';

	-- Second internal stage (multiply by 2**32 or not)
	process (clk) is
	begin
		if rising_edge(clk) then
			if ce = '1' then

				if range_select_1(1) = '1' then
					if lsb_would_rail_hi_1 = '1' then
						stage_0 <= x"7FFFFFFFFFFFFFFFFFFFFFFF";
					elsif lsb_would_rail_lo_1 = '1' then
						stage_0 <= x"800000000000000000000000";
					else
						stage_0 <= stage_1(95-32 downto 0) & x"00000000";
					end if;
				else
					stage_0 <= stage_1;
				end if;
				range_select_0 <= range_select_1;

			end if;
		end if;
	end process;
	lsb_would_rail_hi_0 <= '1' when ( stage_0(95-1 downto 96-16-1) /= x"0000" and stage_0(95) = '0' ) else '0';
	lsb_would_rail_lo_0 <= '1' when ( stage_0(95-1 downto 96-16-1) /= x"FFFF" and stage_0(95) = '1' ) else '0';

	-- Last stage (multiply by 2**16 or not, then keep 25 bits)
	-- depends on: range_select_0, lsb_would_rail_hi_0, lsb_would_rail_lo_0, stage_0
	process (clk) is
	begin
		if rising_edge(clk) then
			if ce = '1' then

				if range_select_0(0) = '1' then
					if lsb_would_rail_hi_0 = '1' then
						data_output_int <= x"7FFFFFFFFFFFFFFFFFFFFFFF";
					elsif lsb_would_rail_lo_0 = '1' then
						data_output_int <= x"800000000000000000000000";
					else
						data_output_int <= stage_0(95-16 downto 0) & x"0000";
					end if;
				else
					data_output_int <= stage_0;
				end if;
				range_output_int <= range_select_0;

			end if;
		end if;
	end process;
	railed_hi_int <= '1' when ( data_output_int(95 downto 96-25) = "0111111111111111111111111" ) else '0';
	railed_lo_int <= '1' when ( data_output_int(95 downto 96-25) = "1000000000000000000000000" ) else '0';

	-- Output assignments
	railed_hi <= railed_hi_int;
	railed_lo <= railed_lo_int;
	data_output <= data_output_int(95 downto 96-25);
	range_output <= range_output_int;
	
end architecture;
