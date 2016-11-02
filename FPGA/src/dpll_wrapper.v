// Digital-PLL wrapper
// JDD 2016

`default_nettype none   // JDD: This disables implicit variable declaration, which I really don't like as a feature as it lets bugs go unreported

module dpll_wrapper (
    
    input  wire               clk1,         // global clock, designed for 100 MHz clock rate
    input  wire               clk1_timesN,  // this should be N times the clock, phase-locked to clk1, N matching what was input in the FIR compiler for fir_compiler_minimumphase_N_times_clk
    input  wire               rst,

    // analog data input/output interface
    input  wire signed [15:0] ADCraw0,
    input  wire signed [15:0] ADCraw1,
    output wire signed [15:0] DACout0,
    output wire signed [15:0] DACout1,

    // System bus
    input  wire [ 32-1:0]     sys_addr   ,  // bus address
    input  wire [ 32-1:0]     sys_wdata  ,  // bus write data
    input  wire [  4-1:0]     sys_sel    ,  // bus write byte select
    input  wire               sys_wen    ,  // bus write enable
    input  wire               sys_ren    ,  // bus read enable
    output wire [ 32-1:0]     sys_rdata  ,  // bus read data
    output wire               sys_err    ,  // bus error indicator
    output wire               sys_ack       // bus acknowledge signal
);

////////////////////////////////////////////////////////////////////////////////////////////////
// Clock assigments

wire clk;
wire clk_mult;
assign clk      = clk1;
assign clk_mult = clk1_timesN;

////////////////////////////////////////////////////////////////////////////////////////////////
// Simple latency test

// reg signed [15:0] counter = 16'h0000;
// always @(posedge clk) begin
//     counter <= counter + 1;
// end
// assign DACout0 = {2'b00, counter[14], 13'b0000000000000};
// assign DACout1 = ADCraw0;



////////////////////////////////////////////////////////////////////////////////////////////////
// Input registers

// reg signed [15:0] IQ_i_real = 16'h0000;
// reg signed [15:0] IQ_i_imag = 16'h0000;

// always @(posedge clk) begin
//     IQ_i_real <= $signed(ADCraw0);
//     IQ_i_imag <= $signed(ADCraw1);
// end

wire signed [15:0] IQ_i_real;
wire signed [15:0] IQ_i_imag;

assign IQ_i_real = $signed(ADCraw0);
assign IQ_i_imag = $signed(ADCraw1);

reg signed [15:0] IQ_i_real_reg = 16'h0000;
reg signed [15:0] IQ_i_imag_reg = 16'h0000;
always @(posedge clk) begin
    IQ_i_real_reg <= IQ_i_real;
    IQ_i_imag_reg <= IQ_i_imag;
end

////////////////////////////////////////////////////////////////////////////////////////////////
// IQ Correction

wire signed [15:0] IQ_o_real;
wire signed [15:0] IQ_o_imag;

reg signed [31:0] Bvect1 = 32'h00000000; // 0
reg signed [31:0] Bvect2 = 32'h00000000; // 0
reg signed [31:0] Amat11 = 32'h00004000; // 1
reg signed [31:0] Amat21 = 32'h00000000; // 0
reg signed [31:0] Amat12 = 32'h00000000; // 0
reg signed [31:0] Amat22 = 32'h00004000; // 1

IQ_correction #(
    .INPUT_WIDTH    (16             ),
    .OUTPUT_WIDTH   (16             ),
    .GAIN_WIDTH     (24             ),
    .GAIN_WIDTH_FRAC(12             )
) IQ_correction_instance (
    .clk            (clk            ),
    .IQ_i_real      (IQ_i_real      ),
    .IQ_i_imag      (IQ_i_imag      ),
    .Bvect1         (Bvect1[15:0]   ),
    .Bvect2         (Bvect2[15:0]   ),
    .Amat11         (Amat11[23:0]   ),
    .Amat21         (Amat21[23:0]   ),
    .Amat12         (Amat12[23:0]   ),
    .Amat22         (Amat22[23:0]   ),
    .IQ_o_real      (IQ_o_real      ),
    .IQ_o_imag      (IQ_o_imag      )
);

reg signed [15:0] IQ_o_real_reg = 16'h0000;
reg signed [15:0] IQ_o_imag_reg = 16'h0000;
always @(posedge clk) begin
    IQ_o_real_reg <= IQ_o_real;
    IQ_o_imag_reg <= IQ_o_imag;
end

////////////////////////////////////////////////////////////////////////////////////////////////
// Fast Arctan

wire signed [19:0] IQ_o_angle;

fast_arctan fast_arctan_inst (
    .clk        (clk),
    .ce         (1'b1),
    .input_x    (IQ_o_real_reg),
    .input_y    (IQ_o_imag_reg),
    .angle      (IQ_o_angle)
);

reg signed [19:0] IQ_o_angle_reg = 20'h00000;
always @(posedge clk) begin
    IQ_o_angle_reg <= IQ_o_angle;
end

////////////////////////////////////////////////////////////////////////////////////////////////
// Loop filter

reg         lf_clr              = 1'b0;
reg         lf_lock             = 1'b0;
reg         lf_branch_en_d      = 1'b1;
reg         lf_branch_en_p      = 1'b1;
reg         lf_branch_en_i      = 1'b1;
reg         lf_branch_en_ii     = 1'b1;
reg  [17:0] lf_coef_d_filt      = 18'd0;
reg  [31:0] lf_cmd_in_d         = 32'h00000000;
reg  [31:0] lf_cmd_in_p         = 32'h00000000;
reg  [31:0] lf_cmd_in_i         = 32'h00000000;
reg  [31:0] lf_cmd_in_ii        = 32'h00000000;
reg         lf_dither_en        = 1'b0;
reg  [15:0] lf_dither_ampli     = 16'h0000;
reg  [31:0] lf_dither_period    = 32'h00000000;

// reg  [19:0] data_in;
wire [19:0] lf_data_in = IQ_o_angle_reg;

wire [15:0] lf_data_out;
wire        lf_railed_hi;
wire        lf_railed_lo;

MZILock_loop_filter_with_dither #(
    .INPUT_WIDTH    (20                 ),
    .OUTPUT_WIDTH   (16                 ),
    .IREG           (1                  )
) loop_filter_inst (
    .clk            (clk                ),
    .ce             (1'b1               ),
    .clr            (lf_clr             ),
    .lock           (lf_lock            ),
    .branch_en_d    (lf_branch_en_d     ),
    .branch_en_p    (lf_branch_en_p     ),
    .branch_en_i    (lf_branch_en_i     ),
    .branch_en_ii   (lf_branch_en_ii    ),
    .coef_d_filt    (lf_coef_d_filt     ),
    .cmd_in_d       (lf_cmd_in_d        ),
    .cmd_in_p       (lf_cmd_in_p        ),
    .cmd_in_i       (lf_cmd_in_i        ),
    .cmd_in_ii      (lf_cmd_in_ii       ),
    .dither_en      (lf_dither_en       ),
    .dither_ampli   (lf_dither_ampli    ),
    .dither_period  (lf_dither_period   ),
    .data_in        (lf_data_in         ),
    .data_out       (lf_data_out        ),
    .railed_hi      (lf_railed_hi       ),
    .railed_lo      (lf_railed_lo       )
);

reg signed [15:0] lf_data_out_reg = 16'h0000;
always @(posedge clk) begin
    lf_data_out_reg <= lf_data_out;
end

////////////////////////////////////////////////////////////////////////////////////////////////
// DAC assignment
assign DACout0 = lf_data_out;
assign DACout1 = 16'h0000;

////////////////////////////////////////////////////////////////////////////////////////////////
// Synthesis tests


// wire signed [31:0] quant_out;

// hdr_gain #(
//     .DATA_WIDTH(32),
//     .QUANT_TYPE(2),
//     // .N_SHIFTERS(0),
//     // .IREG      (0),
//     // .MREG      (1),
//     // .OREG      (1)
//     .N_SHIFTERS(6),
//     .IREG      (1),
//     .SREG1     (1),
//     .SREG2     (1),
//     .SREG3     (1),
//     .SREG4     (1),
//     .SREG5     (1),
//     .SREG6     (1),
//     .MREG      (1),
//     .OREG      (1)
// ) hdr_gain_inst (
//     .clk      (clk),
//     .ce       (1'b1),
//     .data_in  (Bvect1),
//     .cmd_in   (Bvect2),
//     .data_out (quant_out)
// );

// wire signed [31:0] quant_out;



// reg signed [31:0] quant_out_reg;
// always @(posedge clk) begin
//     quant_out_reg <= quant_out;
// end


////////////////////////////////////////////////////////////////////////////////////////////////
// CIC decimators

wire [15:0] IQ_i_real_reg_CIC_dout;
wire        IQ_i_real_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (16),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_IQ_i_real (
    .clk    (clk),
    .ce     (1'b1),
    .din    (IQ_i_real_reg),
    .dout   (IQ_i_real_reg_CIC_dout),
    .flag   (IQ_i_real_reg_CIC_flag)
);

wire [15:0] IQ_i_imag_reg_CIC_dout;
wire        IQ_i_imag_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (16),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_IQ_i_imag (
    .clk    (clk),
    .ce     (1'b1),
    .din    (IQ_i_imag_reg),
    .dout   (IQ_i_imag_reg_CIC_dout),
    .flag   (IQ_i_imag_reg_CIC_flag)
);

wire [15:0] IQ_o_real_reg_CIC_dout;
wire        IQ_o_real_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (16),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_IQ_o_real (
    .clk    (clk),
    .ce     (1'b1),
    .din    (IQ_o_real_reg),
    .dout   (IQ_o_real_reg_CIC_dout),
    .flag   (IQ_o_real_reg_CIC_flag)
);

wire [15:0] IQ_o_imag_reg_CIC_dout;
wire        IQ_o_imag_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (16),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_IQ_o_imag (
    .clk    (clk),
    .ce     (1'b1),
    .din    (IQ_o_imag_reg),
    .dout   (IQ_o_imag_reg_CIC_dout),
    .flag   (IQ_o_imag_reg_CIC_flag)
);

wire [23:0] IQ_o_angle_reg_CIC_dout;
wire        IQ_o_angle_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (24),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_IQ_o_angle (
    .clk    (clk),
    .ce     (1'b1),
    .din    (IQ_o_angle_reg),
    .dout   (IQ_o_angle_reg_CIC_dout),
    .flag   (IQ_o_angle_reg_CIC_flag)
);

wire [15:0] lf_data_out_reg_CIC_dout;
wire        lf_data_out_reg_CIC_flag;
CIC_decimator #(
    .INPUT_WIDTH (16),
    .LOG2_DECIM  (4),
    .LOG2_FILT   (2)
) CIC_decimator_lf_data_out (
    .clk    (clk),
    .ce     (1'b1),
    .din    (lf_data_out_reg),
    .dout   (lf_data_out_reg_CIC_dout),
    .flag   (lf_data_out_reg_CIC_flag)
);

////////////////////////////////////////////////////////////////////////////////////////////////
// ADC RAM


reg [31:0] acqram0_wdata = 32'h00000000;
reg [31:0] acqram1_wdata = 32'h00000000;
reg [31:0] acqram2_wdata = 32'h00000000;
reg [31:0] acqram3_wdata = 32'h00000000;

reg acqramX_flag_tmp = 1'b0;

always @(posedge clk) begin
    acqram0_wdata <= {IQ_i_real_reg_CIC_dout, IQ_i_imag_reg_CIC_dout};
    acqram1_wdata <= {IQ_o_real_reg_CIC_dout, IQ_o_imag_reg_CIC_dout};
    acqram2_wdata <= {IQ_o_angle_reg_CIC_dout, {12'h000}};
    acqram3_wdata <= {lf_data_out_reg_CIC_dout, 16'h0000};

    acqramX_flag_tmp <= lf_data_out_reg_CIC_flag;
end




localparam IQ_RAM_ADDR_W = 10;
reg acq_start   = 1'b0;
reg acq_started = 1'b0;
reg [IQ_RAM_ADDR_W-1:0] acqramX_addr  = {IQ_RAM_ADDR_W{1'b0}};
reg                     acqramX_wren  = 1'b0;
always @(posedge clk) begin

    if (acqramX_flag_tmp) begin
        if ( acq_started == 1'b0 ) begin
            acqramX_addr  <= {IQ_RAM_ADDR_W{1'b0}};
            if (acq_start) begin
                acq_started <= 1'b1;
                acqramX_wren  <= 1'b1;
            end else begin
                acq_started <= 1'b0;
                acqramX_wren  <= 1'b0;
            end
        end else begin
            if (acqramX_addr < {IQ_RAM_ADDR_W{1'b1}}) begin
                acq_started <= 1'b1;
                acqramX_addr <= acqramX_addr + 1;
                acqramX_wren  <= 1'b1;
            end else begin
                acq_started <= 1'b0;
                acqramX_addr  <= {IQ_RAM_ADDR_W{1'b0}};
                acqramX_wren  <= 1'b0;
            end
        end
    end else begin
        acqramX_wren  <= 1'b0;
    end

end


wire        acqram0_clken;
wire        acqram0_ack;
wire [31:0] acqram0_rdata;
assign acqram0_clken    = (sys_ren || sys_wen) && (sys_addr[19:12] == 8'h04);
RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (IQ_RAM_ADDR_W ),
    .DATA_BITS  (32                 )
) acqram0 (
    .clk        (clk                ),
    .addr_a     (acqramX_addr         ),
    .clken_a    (acqramX_wren         ),
    .wren_a     (acqramX_wren         ),
    .data_i_a   (acqram0_wdata        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr[11:2]     ),
    .clken_b    (acqram0_clken        ),
    .data_o_b   (acqram0_rdata        ),
    .uflag_b    (acqram0_ack          )
);

wire        acqram1_clken;
wire        acqram1_ack;
wire [31:0] acqram1_rdata;
assign acqram1_clken    = (sys_ren || sys_wen) && (sys_addr[19:12] == 8'h05);
RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (IQ_RAM_ADDR_W ),
    .DATA_BITS  (32                 )
) acqram1 (
    .clk        (clk                ),
    .addr_a     (acqramX_addr         ),
    .clken_a    (acqramX_wren         ),
    .wren_a     (acqramX_wren         ),
    .data_i_a   (acqram1_wdata        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr[11:2]     ),
    .clken_b    (acqram1_clken        ),
    .data_o_b   (acqram1_rdata        ),
    .uflag_b    (acqram1_ack          )
);

wire        acqram2_clken;
wire        acqram2_ack;
wire [31:0] acqram2_rdata;
assign acqram2_clken    = (sys_ren || sys_wen) && (sys_addr[19:12] == 8'h06);
RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (IQ_RAM_ADDR_W ),
    .DATA_BITS  (32                 )
) acqram2 (
    .clk        (clk                ),
    .addr_a     (acqramX_addr         ),
    .clken_a    (acqramX_wren         ),
    .wren_a     (acqramX_wren         ),
    .data_i_a   (acqram2_wdata        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr[11:2]     ),
    .clken_b    (acqram2_clken        ),
    .data_o_b   (acqram2_rdata        ),
    .uflag_b    (acqram2_ack          )
);

wire        acqram3_clken;
wire        acqram3_ack;
wire [31:0] acqram3_rdata;
assign acqram3_clken    = (sys_ren || sys_wen) && (sys_addr[19:12] == 8'h07);
RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (IQ_RAM_ADDR_W ),
    .DATA_BITS  (32                 )
) acqram3 (
    .clk        (clk                ),
    .addr_a     (acqramX_addr         ),
    .clken_a    (acqramX_wren         ),
    .wren_a     (acqramX_wren         ),
    .data_i_a   (acqram3_wdata        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr[11:2]     ),
    .clken_b    (acqram3_clken        ),
    .data_o_b   (acqram3_rdata        ),
    .uflag_b    (acqram3_ack          )
);

////////////////////////////////////////////////////////////////////////////////////////////////
// Control registers with write and read access. Write access is implemented with a process
// while read access uses a RAM.

wire        rbram_clken;
wire        rbram_ack;
wire [31:0] rbram_rdata;


assign rbram_clken    = (sys_ren | sys_wen) & (sys_addr[19:12] == 8'h00);

RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (10                 ),
    .DATA_BITS  (32                 )
) readback_ram (
    .clk        (clk                ),
    .addr_a     (sys_addr[11:2]     ),
    .clken_a    (rbram_clken        ),
    .data_o_a   (rbram_rdata        ),
    .uflag_a    (rbram_ack          ),
    .wren_a     (sys_wen            ),
    .data_i_a   (sys_wdata          ),
    .addr_b     (10'b0000000000     ),
    .clken_b    (1'b0               ),
    .data_o_b   (                   ),
    .uflag_b    (                   )
);
 

always @(posedge clk) begin

    // Signals that always come back to zero
    acq_start <= 1'b0;
    // if (rst) begin
    //     // Reset values
    // end 
    if (sys_wen) begin
        // Write

        if (sys_addr[19:0]==20'h00040) Bvect1 <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00044) Bvect2 <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00048) Amat11 <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h0004C) Amat21 <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00050) Amat12 <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00054) Amat22 <= sys_wdata[31:0];

        if (sys_addr[19:0]==20'h0007C) acq_start <= sys_wdata[0];

        if (sys_addr[19:0]==20'h00080) lf_clr              <= sys_wdata[0];
        if (sys_addr[19:0]==20'h00084) lf_lock             <= sys_wdata[0];
        if (sys_addr[19:0]==20'h00088) lf_coef_d_filt      <= sys_wdata[17:0];
        if (sys_addr[19:0]==20'h0008C) lf_cmd_in_d         <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00090) lf_cmd_in_p         <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00094) lf_cmd_in_i         <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h00098) lf_cmd_in_ii        <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h0009C) lf_dither_en        <= sys_wdata[0];
        if (sys_addr[19:0]==20'h000A0) lf_dither_ampli     <= sys_wdata[15:0];
        if (sys_addr[19:0]==20'h000A4) lf_dither_period    <= sys_wdata[31:0];
        if (sys_addr[19:0]==20'h000A8) lf_branch_en_d      <= sys_wdata[0];
        if (sys_addr[19:0]==20'h000AC) lf_branch_en_p      <= sys_wdata[0];
        if (sys_addr[19:0]==20'h000B0) lf_branch_en_i      <= sys_wdata[0];
        if (sys_addr[19:0]==20'h000B4) lf_branch_en_ii     <= sys_wdata[0];

        //if (sys_addr[19:0]==20'h00100) int_in[31:0] <= sys_wdata[31:0];
    end
end


////////////////////////////////////////////////////////////////////////////////////////////////
// Status registers

reg sta_ack;
reg [31:0] sta_rdata;
wire sta_en;

assign sta_en = sys_wen | sys_ren;

always @(posedge clk) begin

    casez (sys_addr[19:0])
        20'h0307C: begin sta_ack <= sta_en;  sta_rdata <= {{31{1'b0}}, acq_started}; end
        default:   begin sta_ack <= sta_en;  sta_rdata <= 32'h0;                     end
    endcase

end

////////////////////////////////////////////////////////////////////////////////////////////////
// System Bus

always @(*) begin

end

assign sys_err      =   1'b0;

assign sys_rdata    =   (sta_rdata     & {32{sta_ack}})     | 
                        (rbram_rdata   & {32{rbram_ack}})   | 
                        (acqram0_rdata & {32{acqram0_ack}}) | 
                        (acqram1_rdata & {32{acqram1_ack}}) | 
                        (acqram2_rdata & {32{acqram2_ack}}) | 
                        (acqram3_rdata & {32{acqram3_ack}});

assign sys_ack      =   sta_ack     | 
                        rbram_ack   | 
                        acqram0_ack | 
                        acqram1_ack | 
                        acqram2_ack | 
                        acqram3_ack;

endmodule

`default_nettype wire   // 
