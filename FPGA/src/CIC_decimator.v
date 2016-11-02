
`default_nettype none

module CIC_decimator #(
    parameter INPUT_WIDTH = 32,
    parameter LOG2_DECIM  = 0,
    parameter LOG2_FILT   = 2
)(
    input  wire                				clk,
    input  wire                				ce,

    input  wire signed [INPUT_WIDTH-1:0]  	din,

    output wire signed [INPUT_WIDTH-1:0]  	dout,
    output wire                				flag
);

localparam EXTRA_BITS = LOG2_DECIM+LOG2_FILT;
localparam N_FILT = 2**LOG2_FILT;

reg [EXTRA_BITS-1:0] counter = {EXTRA_BITS{1'b0}};


always @(posedge clk) begin
	counter <= counter + 1;
end

reg signed [EXTRA_BITS+INPUT_WIDTH-1:0] integrators[N_FILT-1:0];

reg signed [INPUT_WIDTH-1:0] dumps[N_FILT-1:0];

reg [N_FILT-1:0] flags;

integer i;
initial begin
    for (i=0; i<N_FILT; i=i+1) begin
        integrators[i] = {(EXTRA_BITS+INPUT_WIDTH){1'b0}};
        dumps[i] = {(INPUT_WIDTH){1'b0}};
        flags[i] = 1'b0;
    end
end

wire [1:0] counter_msbs      = counter[EXTRA_BITS-1:EXTRA_BITS-LOG2_FILT];
reg  [1:0] counter_msbs_last = {(LOG2_FILT){1'b0}};

reg signed [EXTRA_BITS+INPUT_WIDTH-1:0] din_reg = {(EXTRA_BITS+INPUT_WIDTH){1'b0}};

always @(posedge clk) begin
	din_reg <= din;
end



always @(posedge clk) begin

	for (i=0; i<N_FILT; i=i+1) begin

		if (counter_msbs == i && counter_msbs_last != i) begin
			integrators[i] <= {{INPUT_WIDTH{1'b0}}, integrators[i][EXTRA_BITS-1:0]} + din_reg;
			dumps[i] <= integrators[i][EXTRA_BITS+INPUT_WIDTH-1:EXTRA_BITS];
			flags[i] <= 1'b1;
		end else begin
			integrators[i] <= integrators[i] + din_reg;
			dumps[i] <= {(INPUT_WIDTH){1'b0}};
			flags[i] <= 1'b0;
		end

    end

    counter_msbs_last <= counter_msbs;

end

reg signed [INPUT_WIDTH-1:0] dout_reg0 = {(INPUT_WIDTH){1'b0}};
reg flag_reg0 = 1'b0;

reg signed [INPUT_WIDTH-1:0] dout_reg1 = {(INPUT_WIDTH){1'b0}};
reg flag_reg1 = 1'b0;

always @(posedge clk) begin

	dout_reg0 = {(INPUT_WIDTH){1'b0}};
	flag_reg0 = 1'b0;
	for (i=0; i<N_FILT; i=i+1) begin
		dout_reg0 = dout_reg0 | dumps[i];
		flag_reg0 = flag_reg0 | flags[i];
    end

    flag_reg1 <= flag_reg0;
    if (flag_reg0) begin
    	dout_reg1 <= dout_reg0;
    end

end

assign dout = dout_reg1;
assign flag = flag_reg1;


endmodule

`default_nettype wire

