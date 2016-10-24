library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity integrator_96s_dsp48 is
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    clr         : in  std_logic;
    limit_incr  : in  std_logic;
    limit_decr  : in  std_logic;
    data_input  : in  std_logic_vector(95 downto 0);
    railed_hi   : out std_logic;
    railed_lo   : out std_logic;
    data_output : out std_logic_vector(95 downto 0)
);
end entity;

architecture Behavioral of integrator_96s_dsp48 is

    constant DATA_WIDTH             : integer := 96;
    constant STAGE_WIDTH            : integer := 48;

    signal clr_reg                  : std_logic := '0';
    signal clr_s1                   : std_logic := '0';
    signal clr_s0                   : std_logic := '0';

    signal input_msb                : std_logic_vector(0 downto 0) := (others => '0');

    signal switchable_input         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal switchable_input_s0      : std_logic_vector(STAGE_WIDTH-1 downto 0);
    signal switchable_input_s1      : std_logic_vector(STAGE_WIDTH-1 downto 0);

    signal integ_input_s0           : std_logic_vector(STAGE_WIDTH-1 downto 0);
    signal integ_input_s1           : std_logic_vector(STAGE_WIDTH-1 downto 0) := (others => '0');

    signal integ_out_with_carry_s0  : std_logic_vector(STAGE_WIDTH+1-1 downto 0) := (others => '0');
    signal integ_out_with_carry_s1  : std_logic_vector(STAGE_WIDTH+1-1 downto 0) := (others => '0');

    signal top_carry                : std_logic_vector(1 downto 0);
    signal top_carry_last           : std_logic_vector(1 downto 0) := (others => '0');

    signal result_out_s0            : std_logic_vector(STAGE_WIDTH-1 downto 0) := (others => '0');
    signal result_out_s1            : std_logic_vector(STAGE_WIDTH-1 downto 0);

    signal unlimited_output         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal limited_output           : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal railed_hi_reg            : std_logic := '0';
    signal railed_lo_reg            : std_logic := '0';
    signal railed_hi_int            : std_logic;
    signal railed_lo_int            : std_logic;

    signal CARRYOUT_DSP0            : std_logic_vector(3 downto 0);
    signal CARRYOUT_DSP1            : std_logic_vector(3 downto 0);
begin

    reset_delay : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                clr_reg <= clr;
                clr_s1 <= clr_reg;
                clr_s0 <= clr;
            end if;
        end if;
    end process;

    input_limiter : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_reg = '1' then
                    switchable_input <= (others => '0');
                else
                    if ((limit_incr = '1' or railed_hi_int = '1') and data_input(DATA_WIDTH-1) = '0') or 
                       ((limit_decr = '1' or railed_lo_int = '1') and data_input(DATA_WIDTH-1) = '1') then

                        switchable_input <= (others => '0');
                    else
                        switchable_input <= data_input;
                    end if;
                end if;
            end if;
        end if;
    end process;

    switchable_input_s1 <= switchable_input(STAGE_WIDTH*2-1 downto STAGE_WIDTH*1);
    switchable_input_s0 <= switchable_input(STAGE_WIDTH*1-1 downto STAGE_WIDTH*0);
    
    pipeline_reg_s1 : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_s1 = '1' then
                    integ_input_s1 <= (others => '0');
                else
                    integ_input_s1 <= switchable_input_s1;
                end if;
            end if;
        end if;
    end process;
    integ_input_s0 <= switchable_input_s0;

    --integ_s1 : process (clk) is
    --begin
    --    if rising_edge(clk) then
    --        if ce = '1' then
    --            if clr_s1 = '1' then
    --                integ_out_with_carry_s1 <= (others => '0');
    --            else
    --                integ_out_with_carry_s1 <= std_logic_vector(
    --                    resize(unsigned(integ_out_with_carry_s1(STAGE_WIDTH-1 downto 0))        , STAGE_WIDTH+1) + 
    --                    resize(unsigned(integ_input_s1)                                         , STAGE_WIDTH+1) + 
    --                    resize(unsigned(integ_out_with_carry_s0(STAGE_WIDTH downto STAGE_WIDTH)), STAGE_WIDTH+1)
    --                );
    --            end if;
    --        end if;
    --    end if;
    --end process;

    integ_out_with_carry_s1(STAGE_WIDTH) <= CARRYOUT_DSP1(3);
    DSP48E1_inst1: DSP48E1 
    generic map (
        ACASCREG       => 0,       
        AREG           => 0,   
        ADREG          => 0,
        ALUMODEREG     => 0,   
        BCASCREG       => 0,       
        BREG           => 0,    
        CARRYINREG     => 0, -- Xilinx's macro has a bug where an extra register is used for the carry logic. I had to add this line to override the default behavior.
        CREG           => 0,      
        DREG           => 0,
        MREG           => 0,
        PREG           => 1,           
        USE_MULT       => "NONE"
    ) port map (
        ACOUT          => open,   
        BCOUT          => open,  
        CARRYCASCOUT   => open, 
        CARRYOUT       => CARRYOUT_DSP1,
        MULTSIGNOUT    => open, 
        OVERFLOW       => open, 
        P              => integ_out_with_carry_s1(STAGE_WIDTH-1 downto 0),          
        PATTERNBDETECT => open, 
        PATTERNDETECT  => open, 
        PCOUT          => open,  
        UNDERFLOW      => open, 
        A              => integ_input_s1(47 downto 18),          
        ACIN           => "000000000000000000000000000000",    
        ALUMODE        => "0000", 
        B              => integ_input_s1(17 downto 0),          
        BCIN           => "000000000000000000",    
        C              => "000000000000000000000000000000000000000000000000",-- No longer used since we are using the internal feedback path. Initially: integ_out_with_carry_s1(STAGE_WIDTH-1 downto 0),           
        CARRYCASCIN    => integ_out_with_carry_s0(STAGE_WIDTH), 
        CARRYIN        => '0', 
        CARRYINSEL     => "010", -- "000" for CARRYIN and "010" for CARRYCASCIN
        CEA1           => ce,      
        CEA2           => ce,      
        CEAD           => '0',
        CEALUMODE      => ce, 
        CEB1           => ce,      
        CEB2           => ce,      
        CEC            => ce,      
        CECARRYIN      => ce, 
        CECTRL         => ce,
        CED            => '0',
        CEINMODE       => '0', 
        CEM            => '0',       
        CEP            => ce,       
        CLK            => clk,       
        D              => "0000000000000000000000000",
        INMODE         => "00000", 
        MULTSIGNIN     => '0', 
        OPMODE         => "0100011", -- Now using P for the Z multiplexer. Initially, we were using C: "0110011", 
        PCIN           => "000000000000000000000000000000000000000000000000",      
        RSTA           => clr_s1,     
        RSTALLCARRYIN  => clr_s1, 
        RSTALUMODE     => clr_s1, 
        RSTB           => clr_s1,     
        RSTC           => clr_s1,     
        RSTCTRL        => clr_s1, 
        RSTD           => clr_s1,
        RSTINMODE      => clr_s1,
        RSTM           => clr_s1, 
        RSTP           => clr_s1 
    );


    carry_regs : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_s1 = '1' then
                    input_msb <= (others => '0');
                    top_carry_last <= (others => '0');
                else
                    input_msb <= integ_input_s1(STAGE_WIDTH-1 downto STAGE_WIDTH-1);
                    top_carry_last <= top_carry;
                end if;
            end if;
        end if;
    end process;
    top_carry <= std_logic_vector(
        unsigned(top_carry_last) + 
        unsigned(input_msb & input_msb) + 
        unsigned("0" & integ_out_with_carry_s1(STAGE_WIDTH downto STAGE_WIDTH))
    );


    --integ_s0 : process (clk) is
    --begin
    --    if rising_edge(clk) then
    --        if ce = '1' then
    --            if clr_s0 = '1' then
    --                integ_out_with_carry_s0 <= (others => '0');
    --            else
    --                integ_out_with_carry_s0 <= std_logic_vector(
    --                    resize(unsigned(integ_out_with_carry_s0(STAGE_WIDTH-1 downto 0)), STAGE_WIDTH+1) + 
    --                    resize(unsigned(integ_input_s0)                                 , STAGE_WIDTH+1)
    --                );
    --            end if;
    --        end if;
    --    end if;
    --end process;

    integ_out_with_carry_s0(STAGE_WIDTH) <= CARRYOUT_DSP0(3);
    DSP48E1_inst0: DSP48E1 
    generic map (
        ACASCREG       => 0,       
        AREG           => 0,   
        ADREG          => 0,
        ALUMODEREG     => 0,   
        BCASCREG       => 0,       
        BREG           => 0,    
        CARRYINREG     => 0, -- Xilinx's macro has a bug where an extra register is used for the carry logic. I had to add this line to override the default behavior.
        CREG           => 0,      
        DREG           => 0,
        MREG           => 0,
        PREG           => 1,           
        USE_MULT       => "NONE"
    ) port map (
        ACOUT          => open,   
        BCOUT          => open,  
        CARRYCASCOUT   => CARRYOUT_DSP0(3), 
        CARRYOUT       => open, -- This one was used initially with "CARRYOUT_DSP0,"
        MULTSIGNOUT    => open, 
        OVERFLOW       => open, 
        P              => integ_out_with_carry_s0(STAGE_WIDTH-1 downto 0),          
        PATTERNBDETECT => open, 
        PATTERNDETECT  => open, 
        PCOUT          => open,  
        UNDERFLOW      => open, 
        A              => integ_input_s0(47 downto 18),          
        ACIN           => "000000000000000000000000000000",    
        ALUMODE        => "0000", 
        B              => integ_input_s0(17 downto 0),          
        BCIN           => "000000000000000000",    
        C              => "000000000000000000000000000000000000000000000000",-- No longer used since we are using the internal feedback path. Initially: integ_out_with_carry_s0(STAGE_WIDTH-1 downto 0),           
        CARRYCASCIN    => '0', 
        CARRYIN        => '0', 
        CARRYINSEL     => "000", 
        CEA1           => ce,      
        CEA2           => ce,      
        CEAD           => '0',
        CEALUMODE      => ce, 
        CEB1           => ce,      
        CEB2           => ce,      
        CEC            => ce,      
        CECARRYIN      => ce, 
        CECTRL         => ce,
        CED            => '0',
        CEINMODE       => '0', 
        CEM            => '0',       
        CEP            => ce,       
        CLK            => clk,       
        D              => "0000000000000000000000000",
        INMODE         => "00000", 
        MULTSIGNIN     => '0', 
        OPMODE         => "0100011", -- Now using P for the Z multiplexer. Initially, we were using C: "0110011", 
        PCIN           => "000000000000000000000000000000000000000000000000",      
        RSTA           => clr_s0,     
        RSTALLCARRYIN  => clr_s0, 
        RSTALUMODE     => clr_s0, 
        RSTB           => clr_s0,     
        RSTC           => clr_s0,     
        RSTCTRL        => clr_s0, 
        RSTD           => clr_s0,
        RSTINMODE      => clr_s0,
        RSTM           => clr_s0, 
        RSTP           => clr_s0 
    );


    result_out_s1 <= integ_out_with_carry_s1(STAGE_WIDTH-1 downto 0);
    pipeline_reg_s0 : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_s0 = '1' then
                    result_out_s0 <= (others => '0');
                else
                    result_out_s0 <= integ_out_with_carry_s0(STAGE_WIDTH-1 downto 0);
                end if;
            end if;
        end if;
    end process;

    unlimited_output <= result_out_s1 & result_out_s0;

    railed_hi_int <= ((    unlimited_output(DATA_WIDTH-1)) or (    top_carry(0))) and (not top_carry(1));
    railed_lo_int <= ((not unlimited_output(DATA_WIDTH-1)) or (not top_carry(0))) and (    top_carry(1));

    output_limiter : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if clr_s1 = '1' then
                    limited_output <= (others => '0');
                    railed_hi_reg <= '0';
                    railed_lo_reg <= '0';
                else
                    if railed_hi_int = '1' then
                        limited_output <= ((DATA_WIDTH-1) => '0', others => '1');
                    elsif railed_lo_int = '1' then
                        limited_output <= ((DATA_WIDTH-1) => '1', others => '0');
                    else
                        limited_output <= unlimited_output;
                    end if;
                    railed_hi_reg <= railed_hi_int;
                    railed_lo_reg <= railed_lo_int;
                end if;
            end if;
        end if;
    end process;

    data_output <= limited_output;
    railed_hi   <= railed_hi_reg;
    railed_lo   <= railed_lo_reg;

end architecture;
