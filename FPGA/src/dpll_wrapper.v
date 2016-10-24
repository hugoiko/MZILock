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

reg signed [15:0] counter = 16'h0000;
always @(posedge clk) begin
    counter <= counter + 1;
end
assign DACout0 = {2'b00, counter[14], 13'b0000000000000};
assign DACout1 = ADCraw0;



////////////////////////////////////////////////////////////////////////////////////////////////
// Input registers

reg signed [15:0] IQ_i_real = 16'h0000;
reg signed [15:0] IQ_i_imag = 16'h0000;

always @(posedge clk) begin
    IQ_i_real <= $signed(ADCraw0);
    IQ_i_imag <= $signed(ADCraw1);
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


////////////////////////////////////////////////////////////////////////////////////////////////
// Synthesis tests

// reg [95:0] int_in = 96'h000000000000000000000001;
// wire [95:0] int_out;

// integrator_96s_dsp48
// #(
//     .DATA_WIDTH(96)
// ) integrator_inst (
//     .clk(clk),
//     .ce(1'b1),
//     .clr(1'b0),
//     .limit_incr(1'b0),
//     .limit_decr(1'b0),
//     .data_input(int_in),
//     .railed_hi(),
//     .railed_lo(),
//     .data_output(int_out)
// );


wire signed [31:0] quant_in;
wire signed [31:0] quant_tmp0;
wire signed [31:0] quant_tmp1;
wire signed [31:0] quant_tmp2;
wire signed [31:0] quant_out;

assign quant_in = $signed(ADCraw0);

switchable_lossless_quantifier
#(
	.DATA_WIDTH(32),
	.RIGHT_SHIFT(1),
	.QUANT_TYPE(2),
	.REG_OUTPUT(0)
) switchable_lossless_quantifier_inst0 (
    .clk(clk),
    .ce(1'b1),
	.quantify(1'b1),
	.rightshift(1'b1),
	.data_input(quant_in),
	.data_output(quant_tmp0)
);

switchable_lossless_quantifier
#(
	.DATA_WIDTH(32),
	.RIGHT_SHIFT(1),
	.QUANT_TYPE(2),
	.REG_OUTPUT(0)
) switchable_lossless_quantifier_inst1 (
    .clk(clk),
    .ce(1'b1),
	.quantify(1'b1),
	.rightshift(1'b1),
	.data_input(quant_tmp0),
	.data_output(quant_tmp1)
);

switchable_lossless_quantifier
#(
	.DATA_WIDTH(32),
	.RIGHT_SHIFT(1),
	.QUANT_TYPE(2),
	.REG_OUTPUT(0)
) switchable_lossless_quantifier_inst2 (
    .clk(clk),
    .ce(1'b1),
	.quantify(1'b1),
	.rightshift(1'b1),
	.data_input(quant_tmp1),
	.data_output(quant_out)
);


////////////////////////////////////////////////////////////////////////////////////////////////
// ADC RAM

localparam IQ_RAM_ADDR_W = 10;

reg rawiq_acq_start   = 1'b0;
reg rawiq_acq_started = 1'b0;

reg [IQ_RAM_ADDR_W-1:0] iqram_addr  = {IQ_RAM_ADDR_W{1'b0}};
reg                     iqram_wren  = 1'b0;
reg [31:0]              iqram_wdata = 32'h00000000;


always @(posedge clk) begin

    iqram_wdata <= {IQ_o_real, IQ_o_imag};

    if ( rawiq_acq_started == 1'b0 ) begin
        iqram_addr  <= {IQ_RAM_ADDR_W{1'b0}};
        if (rawiq_acq_start) begin
            rawiq_acq_started <= 1'b1;
            iqram_wren  <= 1'b1;
        end else begin
            rawiq_acq_started <= 1'b0;
            iqram_wren  <= 1'b0;
        end
    end else begin
        if (iqram_addr < {IQ_RAM_ADDR_W{1'b1}}) begin
            rawiq_acq_started <= 1'b1;
            iqram_addr <= iqram_addr + 1;
            iqram_wren  <= 1'b1;
        end else begin
            rawiq_acq_started <= 1'b0;
            iqram_addr  <= {IQ_RAM_ADDR_W{1'b0}};
            iqram_wren  <= 1'b0;
        end
    end
end


wire        iqram_clken;
wire        iqram_ack;
wire [31:0] iqram_rdata;

assign iqram_clken    = (sys_ren || sys_wen) && (sys_addr[19:12] == 8'h01);

RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (IQ_RAM_ADDR_W ),
    .DATA_BITS  (32                 )
) iq_ram (
    .clk        (clk                ),
    .addr_a     (iqram_addr         ),
    .clken_a    (iqram_wren         ),
    .wren_a     (iqram_wren         ),
    .data_i_a   (iqram_wdata        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr[11:2]     ),
    .clken_b    (iqram_clken        ),
    .data_o_b   (iqram_rdata        ),
    .uflag_b    (iqram_ack          )
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
    rawiq_acq_start <= 1'b0;
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

        if (sys_addr[19:0]==20'h0007C) rawiq_acq_start <= sys_wdata[0];

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
        20'h0307C: begin sta_ack <= sta_en;  sta_rdata <= {{31{1'b0}}, rawiq_acq_started}; end
        20'h03100: begin sta_ack <= sta_en;  sta_rdata <= quant_out[31:0];                 end
        default:   begin sta_ack <= sta_en;  sta_rdata <= 32'h0;                           end
    endcase

end

////////////////////////////////////////////////////////////////////////////////////////////////
// System Bus

assign sys_err      = 1'b0;
assign sys_rdata    = sta_rdata | rbram_rdata | iqram_rdata;
assign sys_ack      = sta_ack   | rbram_ack   | iqram_ack;

endmodule

`default_nettype wire   // 
