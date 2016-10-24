library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity mult_int32_float32_int16 is
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    integer_in  : in  std_logic_vector(31 downto 0);
    float_in    : in  std_logic_vector(31 downto 0);
    integer_out : out std_logic_vector(15 downto 0)
);
end entity;

architecture Behavioral of mult_int32_32float_16s is
    
    constant QUANTIZER_TYPE : integer := 2;

    signal quantizer_selected : std_logic_vector(6 downto 0) := (others => '0');
    signal through_selected   : std_logic_vector(6 downto 0) := (others => '1');
    signal limiter_selected   : std_logic_vector(6 downto 0) := (others => '0');

    signal stage7 : std_logic_vector(31+1 downto 0);
    signal stage7a_q : std_logic_vector(31+1 downto 0);
    signal stage7a_l : std_logic_vector(31+1 downto 0);
    signal stage7a_t : std_logic_vector(31+1 downto 0);

begin
    
    process (ieee_exponent) is
        variable : signed_exponent : std_logic_vector(7 downto 0);
        variable : abs_exponent : std_logic_vector(7 downto 0);
    begin
        signed_exponent := std_logic_vector( signed(ieee_exponent) - to_signed(127, 8) );
        abs_exponent := std_logic_vector( abs(signed(signed_exponent)) );
        if signed_exponent(7) = '1' then
            -- Negative exponent
            quantizer_selected <= abs_exponent(6 downto 0);
            limiter_selected   <= (others => '0');
        else
            -- Positive exponent
            quantizer_selected <= (others => '0');
            limiter_selected   <= abs_exponent(6 downto 0);
        end if;
    end process;


    process (ieee_sign_bit, ieee_mantissa) is
        variable abs_gain : std_logic_vector(24 downto 0);
    begin
        abs_gain := "01" & ieee_mantissa;
        if ieee_sign_bit = '1' then
            mult_b <= std_logic_vector(-signed(abs_gain));
        else
            mult_b <= std_logic_vector(signed(abs_gain));
        end if;
    end process;


    stage7 <= integer_in(31 downto 31) & integer_in(31 downto 0);

    switchable_lossless_quantifier_inst7a : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 32,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage7,
        data_output => stage7a_q
    );
    switchable_lossless_quantifier_inst7b : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 32,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage7a_q,
        data_output => stage7b_q
    );

    switchable_limiter_inst7a : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 32,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage7,
        data_output => stage7a_l
        railed_hi   => open,
        railed_lo   => open
    );
    switchable_limiter_inst7b : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 32,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage7a_l,
        data_output => stage7b_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage7a_t <= stage7;
    stage7b_t <= stage7b_t;


    process (stage7b_t, stage7b_l, stage7b_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(6) = '1' then
            stage6 <= stage7b_q;
        elsif limiter_selected(6) = '1' then
            stage6 <= stage7b_l;
        else
            stage6 <= stage7b_t;
        end if;
    end process;

    switchable_lossless_quantifier_inst6 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 32,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage6,
        data_output => stage6_q
    );

    switchable_limiter_inst6 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 32,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage6,
        data_output => stage6_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage6_t <= stage6;

    process (stage6_t, stage6_l, stage6_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(5) = '1' then
            stage5 <= stage6_q;
        elsif limiter_selected(5) = '1' then
            stage5 <= stage6_l;
        else
            stage5 <= stage6_t;
        end if;
    end process;

    switchable_lossless_quantifier_inst5 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 16,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage5,
        data_output => stage5_q
    );

    switchable_limiter_inst5 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 16,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage5,
        data_output => stage5_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage5_t <= stage5;

    process (stage5_t, stage5_l, stage5_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(4) = '1' then
            stage4 <= stage5_q;
        elsif limiter_selected(4) = '1' then
            stage4 <= stage5_l;
        else
            stage4 <= stage5_t;
        end if;
    end process;
    
    switchable_lossless_quantifier_inst4 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 8,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage4,
        data_output => stage4_q
    );

    switchable_limiter_inst4 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 8,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage4,
        data_output => stage4_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage4_t <= stage4;

    process (stage4_t, stage4_l, stage4_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(3) = '1' then
            stage3 <= stage4_q;
        elsif limiter_selected(3) = '1' then
            stage3 <= stage4_l;
        else
            stage3 <= stage4_t;
        end if;
    end process;

    switchable_lossless_quantifier_inst3 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 4,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage3,
        data_output => stage3_q
    );

    switchable_limiter_inst3 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 4,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage3,
        data_output => stage3_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage3_t <= stage3;

    process (stage3_t, stage3_l, stage3_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(2) = '1' then
            stage2 <= stage3_q;
        elsif limiter_selected(2) = '1' then
            stage2 <= stage3_l;
        else
            stage2 <= stage3_t;
        end if;
    end process;

    switchable_lossless_quantifier_inst2 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 2,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage2,
        data_output => stage2_q
    );

    switchable_limiter_inst2 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 2,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage2,
        data_output => stage2_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage2_t <= stage2;

    process (stage2_t, stage2_l, stage2_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(1) = '1' then
            stage1 <= stage2_q;
        elsif limiter_selected(1) = '1' then
            stage1 <= stage2_l;
        else
            stage1 <= stage2_t;
        end if;
    end process;

    switchable_lossless_quantifier_inst1 : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => 32+1,
        RIGHT_SHIFT => 1,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => stage1,
        data_output => stage1_q
    );

    switchable_limiter_inst1 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 1,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => stage1,
        data_output => stage1_l
        railed_hi   => open,
        railed_lo   => open
    );

    stage1_t <= stage1;

    process (stage1_t, stage1_l, stage1_q, quantizer_selected, limiter_selected) is
    begin
        if quantizer_selected(0) = '1' then
            stage0 <= stage1_q;
        elsif limiter_selected(0) = '1' then
            stage0 <= stage1_l;
        else
            stage0 <= stage1_t;
        end if;
    end process;


    switchable_limiter_inst0 : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => 32+1,
        LEFT_SHIFT  => 32+1-MULT_A_SIZE,
        GUARD_BITS  => 0,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '0',
        data_input  => stage0,
        data_output => mult_a,
        railed_hi   => open,
        railed_lo   => open
    );

    mult_p <= mult_a * mult_b;


    switchable_lossless_quantifier_instf : entity work.switchable_lossless_quantifier
    generic map (
        DATA_WIDTH  => MULT_A_SIZE+MULT_B_SIZE,
        RIGHT_SHIFT => 4,
        QUANT_TYPE  => QUANTIZER_TYPE,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        quantify    => '1',
        rightshift  => '1',
        data_input  => mult_p,
        data_output => mult_p_q
    );

    switchable_limiter_instf : entity work.switchable_limiter
    generic map (
        DATA_WIDTH  => MULT_A_SIZE+MULT_B_SIZE,
        LEFT_SHIFT  => 4,
        GUARD_BITS  => 1,
        REG_OUTPUT  => 0
    ) port map (
        clk         => clk,
        ce          => ce,
        limit       => '1',
        leftshift   => '1',
        data_input  => mult_p_q,
        data_output => mult_p_l
        railed_hi   => open,
        railed_lo   => open
    );


end architecture;
