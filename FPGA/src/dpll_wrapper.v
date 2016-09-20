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
assign clk = clk1;

wire clk_mult;
assign clk_mult = clk1_timesN;




////////////////////////////////////////////////////////////////////////////////////////////////
// ADC RAM

reg rawiq_acq_start = 1'b0;
reg rawiq_acq_started = 1'b0;

reg [9:0] addr_rawiq = 10'd0;
reg clken_rawiq = 1'b0;
reg wren_rawiq = 1'b0;
reg [31:0] wdata_rawiq = 32'h00000000;

wire        sys_clken_rawiq;
wire        sys_ack_rawiq;
wire [31:0] sys_rdata_rawiq;
wire [9:0]  sys_addr_rawiq;

assign sys_clken_rawiq    = (sys_ren || sys_wen) && (sys_addr[12+2-1:10+2] == 4'b0001);
assign sys_addr_rawiq     = sys_addr[10-1+2:2];

RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (10                 ),
    .DATA_BITS  (32                 )
) rawiq_ram (
    .clk        (clk                ),
    .addr_a     (addr_rawiq         ),
    .clken_a    (clken_rawiq        ),
    .wren_a     (wren_rawiq         ),
    .data_i_a   (wdata_rawiq        ),
    .data_o_a   (                   ),
    .uflag_a    (                   ),
    .addr_b     (sys_addr_rawiq     ),
    .clken_b    (sys_clken_rawiq    ),
    .data_o_b   (sys_rdata_rawiq    ),
    .uflag_b    (sys_ack_rawiq      )
);



always @(posedge clk) begin

    wdata_rawiq <= {ADCraw1, ADCraw0};

    if ( rawiq_acq_started == 1'b0 ) begin
        addr_rawiq  <= 10'd0;
        if (rawiq_acq_start) begin
            rawiq_acq_started <= 1'b1;
            clken_rawiq <= 1'b1;
            wren_rawiq  <= 1'b1;
        end else begin
            rawiq_acq_started <= 1'b0;
            clken_rawiq <= 1'b0;
            wren_rawiq  <= 1'b0;
        end
    end else begin
        if (addr_rawiq < 10'b1111111111) begin
            rawiq_acq_started <= 1'b1;
            addr_rawiq <= addr_rawiq + 1;
            clken_rawiq <= 1'b1;
            wren_rawiq  <= 1'b1;
        end else begin
            rawiq_acq_started <= 1'b0;
            addr_rawiq  <= 10'd0;
            clken_rawiq <= 1'b0;
            wren_rawiq  <= 1'b0;
        end
    end
    
end


////////////////////////////////////////////////////////////////////////////////////////////////
// Control registers + Readback RAM

wire        sys_clken_rrr;
wire        sys_ack_rrr;
wire [31:0] sys_rdata_rrr;
wire [9:0]  sys_addr_rrr;
wire        sys_wen_rrr;
wire [31:0] sys_wdata_rrr;

assign sys_clken_rrr    = (sys_ren || sys_wen) && (sys_addr[12+2-1:10+2] == 4'b0000);
assign sys_addr_rrr     = sys_addr[10-1+2:2];
assign sys_wen_rrr      = sys_wen;
assign sys_wdata_rrr    = sys_wdata;

RAM_1W2R #(
    .INIT_FILE  (""                 ),
    .ADDR_BITS  (10                 ),
    .DATA_BITS  (32                 )
) register_readback_ram (
    .clk        (clk                ),
    .addr_a     (sys_addr_rrr       ),
    .clken_a    (sys_clken_rrr      ),
    .data_o_a   (sys_rdata_rrr      ),
    .uflag_a    (sys_ack_rrr        ),
    .wren_a     (sys_wen_rrr        ),
    .data_i_a   (sys_wdata_rrr      ),
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
    if (sys_clken_rrr && sys_wen_rrr) begin
        // Write
        if (sys_addr_rrr[9:0]==10'h0c) rawiq_acq_start <= sys_wdata_rrr[0];
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////
// System Bus

assign sys_err      = 1'b0;
assign sys_rdata    = sys_rdata_rrr |  sys_rdata_rawiq;
assign sys_ack      = sys_ack_rrr   || sys_ack_rawiq   || sys_wen;

endmodule

`default_nettype wire   // 
