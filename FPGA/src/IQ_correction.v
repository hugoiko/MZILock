
`default_nettype none

module IQ_correction #(

    parameter INPUT_WIDTH     = 14,
    parameter OUTPUT_WIDTH    = 16,
    parameter GAIN_WIDTH      = 24,
    parameter GAIN_WIDTH_FRAC = 12
    
)(
    
    input  wire                           clk,

    input  wire signed [INPUT_WIDTH-1:0]  IQ_i_real,
    input  wire signed [INPUT_WIDTH-1:0]  IQ_i_imag,

    input  wire signed [INPUT_WIDTH-1:0]  Bvect1,
    input  wire signed [INPUT_WIDTH-1:0]  Bvect2,

    input  wire signed [GAIN_WIDTH-1:0]   Amat11,
    input  wire signed [GAIN_WIDTH-1:0]   Amat21,
    input  wire signed [GAIN_WIDTH-1:0]   Amat12,
    input  wire signed [GAIN_WIDTH-1:0]   Amat22,

    output reg  signed [OUTPUT_WIDTH-1:0] IQ_o_real,
    output reg  signed [OUTPUT_WIDTH-1:0] IQ_o_imag
    
);



////////////////////////////////////////////////////////////////////////////////////////////////
// IQ Correction

localparam SLICE_FROM = OUTPUT_WIDTH+GAIN_WIDTH_FRAC-1;
localparam SLICE_TO   = GAIN_WIDTH_FRAC;

reg signed [INPUT_WIDTH-1:0]  Bvect1_reg;
reg signed [INPUT_WIDTH-1:0]  Bvect2_reg;
reg signed [GAIN_WIDTH-1:0]   Amat11_reg;
reg signed [GAIN_WIDTH-1:0]   Amat21_reg;
reg signed [GAIN_WIDTH-1:0]   Amat12_reg;
reg signed [GAIN_WIDTH-1:0]   Amat22_reg;

reg signed [INPUT_WIDTH-1:0]  IQ_i_real_reg;
reg signed [INPUT_WIDTH-1:0]  IQ_i_imag_reg;

reg signed [INPUT_WIDTH-1:0]  IQ_i_real_cent;
reg signed [INPUT_WIDTH-1:0]  IQ_i_imag_cent;

(* use_dsp48 = "yes" *)
reg signed [INPUT_WIDTH+GAIN_WIDTH-1:0] Amat11_real;
(* use_dsp48 = "yes" *)
reg signed [INPUT_WIDTH+GAIN_WIDTH-1:0] Amat12_imag;
(* use_dsp48 = "yes" *)
reg signed [INPUT_WIDTH+GAIN_WIDTH-1:0] Amat21_real;
(* use_dsp48 = "yes" *)
reg signed [INPUT_WIDTH+GAIN_WIDTH-1:0] Amat22_imag;

always @(posedge clk) begin

    Bvect1_reg <= Bvect1;
    Bvect2_reg <= Bvect2;
    Amat11_reg <= Amat11;
    Amat21_reg <= Amat21;
    Amat12_reg <= Amat12;
    Amat22_reg <= Amat22;



    Amat11_real <= Amat11_reg * IQ_i_real_cent;
    Amat12_imag <= Amat12_reg * IQ_i_imag_cent;
    Amat21_real <= Amat21_reg * IQ_i_real_cent;
    Amat22_imag <= Amat22_reg * IQ_i_imag_cent;


end


always @(*) begin
    IQ_i_real_reg <= IQ_i_real;
    IQ_i_imag_reg <= IQ_i_imag;
    
    IQ_i_real_cent <= IQ_i_real_reg + Bvect1_reg;
    IQ_i_imag_cent <= IQ_i_imag_reg + Bvect2_reg;

    IQ_o_real <= Amat11_real[SLICE_FROM:SLICE_TO] + Amat21_real[SLICE_FROM:SLICE_TO];
    IQ_o_imag <= Amat12_imag[SLICE_FROM:SLICE_TO] + Amat22_imag[SLICE_FROM:SLICE_TO];
end

endmodule

`default_nettype wire
