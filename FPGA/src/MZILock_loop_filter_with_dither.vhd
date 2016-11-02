library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library unimacro;
use unimacro.vcomponents.all;

entity MZILock_loop_filter_with_dither is
generic (
    INPUT_WIDTH  : integer := 24;
    OUTPUT_WIDTH : integer := 16;
    IREG         : integer := 0
);
port (
    clk             : in  std_logic;
    ce              : in  std_logic;
    
    clr             : in  std_logic;
    lock            : in  std_logic;

    branch_en_d     : in  std_logic;
    branch_en_p     : in  std_logic;
    branch_en_i     : in  std_logic;
    branch_en_ii    : in  std_logic;
    
    coef_d_filt     : in  std_logic_vector(23 downto 0);
    cmd_in_d        : in  std_logic_vector(31 downto 0);
    cmd_in_p        : in  std_logic_vector(31 downto 0);
    cmd_in_i        : in  std_logic_vector(31 downto 0);
    cmd_in_ii       : in  std_logic_vector(31 downto 0);

    dither_en       : in  std_logic;
    dither_ampli    : in  std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    dither_period   : in  std_logic_vector(31 downto 0);

    --vna_start       : in  std_logic;
    --vna_period      : in  std_logic_vector(31 downto 0);
    --vna_done        : out std_logic;
    --vna_integral_I  : out std_logic_vector(INPUT_WIDTH-1 downto 0);
    --vna_integral_Q  : out std_logic_vector(INPUT_WIDTH-1 downto 0);
    
    data_in         : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
    data_out        : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    railed_hi       : out std_logic;
    railed_lo       : out std_logic
);
end entity;

architecture Behavioral of MZILock_loop_filter_with_dither is

    -- Input register
    signal data_in_int : std_logic_vector(INPUT_WIDTH-1 downto 0)  := (others => '0');

    signal clr_reg              : std_logic := '0';
    signal lock_reg             : std_logic := '0';
    signal coef_d_filt_reg      : std_logic_vector(23 downto 0) := (others => '0');
    signal branch_en_d_reg      : std_logic := '0';
    signal branch_en_p_reg      : std_logic := '0';
    signal branch_en_i_reg      : std_logic := '0';
    signal branch_en_ii_reg     : std_logic := '0';
    signal cmd_in_d_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_p_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_i_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_ii_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal dither_en_reg        : std_logic := '0';
    signal dither_ampli_reg     : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
    signal dither_period_reg    : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Lock control
    signal cmd_in_d_ctrl         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_p_ctrl         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_i_ctrl         : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_in_ii_ctrl        : std_logic_vector(31 downto 0) := (others => '0');

    -- D Branch
    signal data_tmp_d  : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal data_out_d  : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal railed_hi_d : std_logic;
    signal railed_lo_d : std_logic;
    signal railed_hi_d2 : std_logic;
    signal railed_lo_d2 : std_logic;

    signal data_out_d_TO_BE_FIXED : std_logic_vector(18-1 downto 0);

    -- P Branch
    signal data_out_p  : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
    signal railed_hi_p : std_logic;
    signal railed_lo_p : std_logic;

    -- I Branch
    signal data_times_gain_i          : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal data_out_i          : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal data_out_i_switched : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal current_sum_i       : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal railed_hi_i         : std_logic;
    signal railed_lo_i         : std_logic;
    signal railed_hi_i2        : std_logic;
    signal railed_lo_i2        : std_logic;

    -- II Branch
    signal data_times_gain_ii           : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal data_times_gain_ii_lim       : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
    signal first_int_output          : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal first_int_output_switched : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal data_out_ii           : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal current_sum_ii_A : std_logic_vector(data_times_gain_ii'range) := (others => '0');
    signal current_sum_ii_B : std_logic_vector(data_times_gain_ii'range) := (others => '0');
    signal railed_hi_ii          : std_logic;
    signal railed_lo_ii          : std_logic;
    signal railed_hi_ii2         : std_logic;
    signal railed_lo_ii2         : std_logic;

    -- Dither

    signal dither_counter        : std_logic_vector(31 downto 0) := (others => '0');
    signal dither_half_period    : std_logic_vector(31 downto 0) := (others => '0');
    signal dither_quarter_period : std_logic_vector(31 downto 0) := (others => '0');
    signal dither_I_is_positive  : std_logic := '0';
    signal dither_Q_is_positive  : std_logic := '0';
    signal dither_out            : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');


    -- Output sum
    signal sum_dith             : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');
    signal sum_dith_ii          : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');
    signal sum_dith_ii_i        : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');
    signal sum_dith_ii_i_p      : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');
    signal sum_dith_ii_i_p_d    : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');

    signal sum_railed_hi_ii         : std_logic := '0';
    signal sum_railed_hi_ii_i       : std_logic := '0';
    signal sum_railed_hi_ii_i_p     : std_logic := '0';
    signal sum_railed_hi_ii_i_p_d   : std_logic := '0';

    signal sum_railed_lo_ii         : std_logic := '0';
    signal sum_railed_lo_ii_i       : std_logic := '0';
    signal sum_railed_lo_ii_i_p     : std_logic := '0';
    signal sum_railed_lo_ii_i_p_d   : std_logic := '0';

    signal sum_dith_ii_i_p_d_ls : std_logic_vector(OUTPUT_WIDTH+3-1 downto 0) := (others => '0');
    signal sum_railed_hi        : std_logic := '0';
    signal sum_railed_lo        : std_logic := '0';

    signal data_out_int         : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
    signal railed_hi_int        : std_logic := '0';
    signal railed_lo_int        : std_logic := '0';


    procedure safe_signed_add2 (din0, din1: in  std_logic_vector; dout: out std_logic_vector; railed_hi, railed_lo : out std_logic) is
        variable sum_internal : std_logic_vector(dout'range);
        constant max_value : std_logic_vector(dout'range) := (dout'left => '0', others => '1');
        constant min_value : std_logic_vector(dout'range) := (dout'left => '1', others => '0');
    begin
        sum_internal := std_logic_vector(signed(din0) + signed(din1));
        if (din0(din0'left) = '0' and din1(din1'left) = '0' and sum_internal(sum_internal'left) = '1') then
            dout := max_value;
            railed_hi := '1';
            railed_lo := '0';
        elsif (din0(din0'left) = '1' and din1(din1'left) = '1' and sum_internal(sum_internal'left) = '0') then
            dout := min_value;
            railed_hi := '0';
            railed_lo := '1';
        else
            dout := sum_internal; 
            railed_hi := '0';
            railed_lo := '0';
        end if;
    end;

begin

    oreg_0: if (IREG = 0) generate
    begin
        process (data_in) is
        begin
            data_in_int <= data_in;
        end process;
    end generate;
    oreg_1: if (IREG = 1) generate
    begin
        process (clk) is
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    data_in_int <= data_in;
                end if;
            end if;
        end process;
    end generate;

    -- Input regs for the parameters
    input_registers_for_parameters : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                clr_reg             <= clr;
                lock_reg            <= lock;

                branch_en_d_reg     <= branch_en_d;
                branch_en_p_reg     <= branch_en_p;
                branch_en_i_reg     <= branch_en_i;
                branch_en_ii_reg    <= branch_en_ii;

                coef_d_filt_reg     <= coef_d_filt;
                cmd_in_d_reg        <= cmd_in_d;
                cmd_in_p_reg        <= cmd_in_p;
                cmd_in_i_reg        <= cmd_in_i;
                cmd_in_ii_reg       <= cmd_in_ii;

                dither_en_reg       <= dither_en;
                dither_ampli_reg    <= dither_ampli;
                dither_period_reg   <= dither_period;

            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Lock control
    ----------------------------------------------------------------
    lock_control : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                if lock_reg = '1' and branch_en_d_reg = '1' then
                    cmd_in_d_ctrl  <= cmd_in_d_reg;
                else
                    cmd_in_d_ctrl  <= (others => '0');
                end if;

                if lock_reg = '1' and branch_en_p_reg = '1' then
                    cmd_in_p_ctrl  <= cmd_in_p_reg;
                else
                    cmd_in_p_ctrl  <= (others => '0');
                end if;

                if lock_reg = '1' and branch_en_i_reg = '1' then
                    cmd_in_i_ctrl  <= cmd_in_i_reg;
                else
                    cmd_in_i_ctrl  <= (others => '0');
                end if;

                if lock_reg = '1' and branch_en_ii_reg = '1' then
                    cmd_in_ii_ctrl  <= cmd_in_ii_reg;
                else
                    cmd_in_ii_ctrl  <= (others => '0');
                end if;


            end if;
        end if;
    end process;


    ----------------------------------------------------------------
    -- D Branch
    ----------------------------------------------------------------

    hdr_gain_inst_d : entity work.hdr_gain
    generic map (
        INPUT_WIDTH  => INPUT_WIDTH,
        OUTPUT_WIDTH => OUTPUT_WIDTH,
        N_SHIFTERS   => 0,
        QUANT_TYPE   => 0,
        IREG         => 0,
        SREG1        => 0,
        SREG2        => 0,
        SREG3        => 0,
        SREG4        => 0,
        SREG5        => 0,
        SREG6        => 0,
        MREG         => 1,
        OREG         => 0
    ) port map (
        clk        => clk,
        ce         => '1',
        data_in    => data_in_int,
        cmd_in     => cmd_in_d_ctrl,
        data_out   => data_tmp_d,
        railed_hi  => railed_hi_d,
        railed_lo  => railed_lo_d
    );

    derivative_inst : entity work.derivative_with_filter
    generic map (
        DATA_WIDTH => data_tmp_d'length,
        COEF_WIDTH => coef_d_filt_reg'length
    ) port map (
        clk       => clk,
        ce        => '1',
        coef      => coef_d_filt_reg,
        din       => data_tmp_d,
        dout      => data_out_d,
        railed_hi => railed_hi_d2,
        railed_lo => railed_lo_d2
    );

    ----------------------------------------------------------------
    -- P Branch
    ----------------------------------------------------------------

    hdr_gain_inst_p : entity work.hdr_gain
    generic map (
        INPUT_WIDTH  => INPUT_WIDTH,
        OUTPUT_WIDTH => OUTPUT_WIDTH,
        N_SHIFTERS   => 0,
        QUANT_TYPE   => 0,
        IREG         => 0,
        SREG1        => 0,
        SREG2        => 0,
        SREG3        => 0,
        SREG4        => 0,
        SREG5        => 0,
        SREG6        => 0,
        MREG         => 1,
        OREG         => 0
    ) port map (
        clk        => clk,
        ce         => '1',
        data_in    => data_in_int,
        cmd_in     => cmd_in_p_ctrl,
        data_out   => data_out_p,
        railed_hi  => railed_hi_p,
        railed_lo  => railed_lo_p
    );

    ----------------------------------------------------------------
    -- I Branch
    ----------------------------------------------------------------

    hdr_gain_inst_i : entity work.hdr_gain
    generic map (
        INPUT_WIDTH  => INPUT_WIDTH,
        OUTPUT_WIDTH => OUTPUT_WIDTH,
        N_SHIFTERS   => 3,
        QUANT_TYPE   => 1,
        IREG         => 0,
        SREG1        => 1,
        SREG2        => 1,
        SREG3        => 1,
        SREG4        => 0,
        SREG5        => 0,
        SREG6        => 0,
        MREG         => 1,
        OREG         => 1
    ) port map (
        clk        => clk,
        ce         => '1',
        data_in    => data_in_int,
        cmd_in     => cmd_in_i_ctrl,
        data_out   => data_times_gain_i,
        railed_hi  => railed_hi_i,
        railed_lo  => railed_lo_i
    );

    single_integrator : process (clk) is

        variable var_integ_input : std_logic_vector(data_times_gain_i'range) := (others => '0');
        variable var_integ_value : std_logic_vector(data_times_gain_i'range) := (others => '0');
        variable var_railed_hi : std_logic := '0';
        variable var_railed_lo : std_logic := '0';
        variable var_integ_next : std_logic_vector(data_times_gain_i'range) := (others => '0');

        --variable var_railed_lo : std_logic := '0';
        --variable var_railed_hi : std_logic := '0';
        --variable var_next_sum_i : std_logic_vector(data_times_gain_i'range);
    begin
        if rising_edge(clk) then
            if ce = '1' then

                if (clr_reg = '1' or branch_en_i_reg = '0') then
                    var_integ_input := (others => '0');
                    var_integ_value := (others => '0');
                else
                    if (lock_reg = '1') then
                        var_integ_input := data_times_gain_i; 
                    else
                        var_integ_input := (others => '0');
                    end if;
                    var_integ_value := current_sum_i;
                end if;

                safe_signed_add2(var_integ_input, var_integ_value, var_integ_next, var_railed_hi, var_railed_lo);

                current_sum_i <= var_integ_next;

                railed_hi_i2 <= var_railed_hi;
                railed_lo_i2 <= var_railed_lo;

                --safe_signed_add2(data_times_gain_i, current_sum_i, var_next_sum_i, var_railed_hi, var_railed_lo);
                --if (clr_reg = '1' or branch_en_i_reg = '0') then
                --    current_sum_i <= (others => '0');
                --else
                --    current_sum_i <= var_next_sum_i;
                --end if;
                --railed_hi_i2 <= var_railed_hi;
                --railed_lo_i2 <= var_railed_lo;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- II Branch
    ----------------------------------------------------------------
    
    hdr_gain_inst_ii : entity work.hdr_gain
    generic map (
        INPUT_WIDTH  => INPUT_WIDTH,
        OUTPUT_WIDTH => OUTPUT_WIDTH,
        N_SHIFTERS   => 6,
        QUANT_TYPE   => 2,
        IREG         => 0,
        SREG1        => 1,
        SREG2        => 1,
        SREG3        => 1,
        SREG4        => 1,
        SREG5        => 1,
        SREG6        => 1,
        MREG         => 1,
        OREG         => 1
    ) port map (
        clk        => clk,
        ce         => '1',
        data_in    => data_in_int,
        cmd_in     => cmd_in_ii_ctrl,
        data_out   => data_times_gain_ii,
        railed_hi  => railed_hi_ii,
        railed_lo  => railed_lo_ii
    );


    double_integrator : process (clk) is
        variable var_integ_input_A : std_logic_vector(data_times_gain_ii'range) := (others => '0');
        variable var_integ_value_A : std_logic_vector(data_times_gain_ii'range) := (others => '0');
        variable var_railed_hi_A : std_logic := '0';
        variable var_railed_lo_A : std_logic := '0';
        variable var_integ_next_A : std_logic_vector(data_times_gain_ii'range) := (others => '0');

        variable var_integ_input_B : std_logic_vector(data_times_gain_ii'range) := (others => '0');
        variable var_integ_value_B : std_logic_vector(data_times_gain_ii'range) := (others => '0');
        variable var_railed_hi_B : std_logic := '0';
        variable var_railed_lo_B : std_logic := '0';
        variable var_integ_next_B : std_logic_vector(data_times_gain_ii'range) := (others => '0');
    begin
        if rising_edge(clk) then
            if ce = '1' then


                if (clr_reg = '1' or branch_en_ii_reg = '0') then
                    var_integ_input_A := (others => '0');
                    var_integ_value_A := (others => '0');
                    var_integ_input_B := (others => '0');
                    var_integ_value_B := (others => '0');
                else
                    if  (var_railed_hi_B = '1' and data_times_gain_ii(data_times_gain_ii'left) = '0') or 
                        (var_railed_lo_B = '1' and data_times_gain_ii(data_times_gain_ii'left) = '1') then
                        var_integ_input_A := (others => '0');
                        var_integ_value_A := (others => '0');
                    else
                        if (lock_reg = '1') then
                            var_integ_input_A := data_times_gain_ii;
                        else
                            var_integ_input_A := (others => '0');
                        end if;
                        var_integ_value_A := current_sum_ii_A;
                    end if;
                    if (lock_reg = '1') then
                        var_integ_input_B := current_sum_ii_A;
                    else
                        var_integ_input_B := (others => '0');
                    end if;
                    var_integ_value_B := current_sum_ii_B;
                end if;

                safe_signed_add2(var_integ_input_A, var_integ_value_A, var_integ_next_A, var_railed_hi_A, var_railed_lo_A);
                safe_signed_add2(var_integ_input_B, var_integ_value_B, var_integ_next_B, var_railed_hi_B, var_railed_lo_B);

                current_sum_ii_A <= var_integ_next_A;
                current_sum_ii_B <= var_integ_next_B;

                railed_hi_ii2 <= var_railed_hi_A or var_railed_hi_B;
                railed_lo_ii2 <= var_railed_lo_A or var_railed_lo_B;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Dither & "VNA"
    ----------------------------------------------------------------


    dither_gen : process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                dither_half_period    <= std_logic_vector(shift_right(unsigned(dither_period_reg), 1));
                dither_quarter_period <= std_logic_vector(shift_right(unsigned(dither_period_reg), 2));

                if unsigned(dither_counter) > 1 then
                    dither_counter <= std_logic_vector(unsigned(dither_counter) - 1);
                else
                    dither_counter <= dither_half_period;
                end if;

                if dither_counter = dither_half_period then
                    dither_Q_is_positive <= dither_I_is_positive;
                    dither_I_is_positive <= not dither_I_is_positive;
                end if;

                if dither_counter = dither_quarter_period then
                    dither_Q_is_positive <= not dither_Q_is_positive;
                end if;

                if dither_en_reg = '1' then
                    if dither_I_is_positive = '1' then
                        dither_out <= std_logic_vector( signed(dither_ampli_reg));
                    else 
                        dither_out <= std_logic_vector(-signed(dither_ampli_reg));
                    end if;
                else
                    dither_out <= (others => '0');
                end if;

            end if;
        end if;
    end process;


    ----------------------------------------------------------------
    -- Output sum
    ----------------------------------------------------------------

    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then

                sum_dith                <= std_logic_vector( resize(signed(dither_out), OUTPUT_WIDTH+3) );
                sum_dith_ii             <= std_logic_vector( signed(sum_dith) + resize(signed(current_sum_ii_B), OUTPUT_WIDTH+3) );
                sum_dith_ii_i           <= std_logic_vector( signed(sum_dith_ii) + resize(signed(current_sum_i), OUTPUT_WIDTH+3) );
                sum_dith_ii_i_p_d       <= std_logic_vector( signed(sum_dith_ii_i) + resize(signed(data_out_p), OUTPUT_WIDTH+3) + resize(signed(data_out_d), OUTPUT_WIDTH+3) );

                sum_railed_hi_ii        <= railed_hi_ii or railed_hi_ii2;
                sum_railed_hi_ii_i      <= sum_railed_hi_ii or railed_hi_i or railed_hi_i2;
                sum_railed_hi_ii_i_p_d  <= sum_railed_hi_ii_i_p or railed_hi_p or railed_hi_d or railed_hi_d2;

                sum_railed_lo_ii        <= railed_lo_ii or railed_lo_ii2;
                sum_railed_lo_ii_i      <= sum_railed_lo_ii or railed_lo_i or railed_lo_i2;
                sum_railed_lo_ii_i_p_d  <= sum_railed_lo_ii_i_p or railed_lo_p or railed_lo_d or railed_lo_d2;

            end if;
        end if;
    end process;


    output_bit_shifter_left : entity work.safe_signed_bit_shift
    generic map (
        DATA_WIDTH => OUTPUT_WIDTH+3,
        BIT_SHIFT  => 3,
        QUANT_TYPE => 0
    ) port map (
        clk       => clk,
        ce        => ce,
        opmode    => "10", -- Left Shifter & Limiter
        data_in   => sum_dith_ii_i_p_d,
        data_out  => sum_dith_ii_i_p_d_ls,
        railed_hi => sum_railed_hi,  
        railed_lo => sum_railed_lo
    );

    process (clk) is
    begin
        if rising_edge(clk) then
            if ce = '1' then
                data_out_int <= sum_dith_ii_i_p_d_ls(OUTPUT_WIDTH+3-1 downto 3);
                railed_hi_int <= sum_railed_hi_ii_i_p_d or sum_railed_hi;
                railed_lo_int <= sum_railed_lo_ii_i_p_d or sum_railed_lo;
            end if;
        end if;
    end process;

    data_out  <= data_out_int;
    railed_hi <= railed_hi_int;
    railed_lo <= railed_lo_int;

end architecture;
