`timescale 1ns / 1ps
`default_nettype none
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company:        NIST
// Engineer:       Hugo Bergeron
// 
// Create Date:    3/2/2016 
// Design Name: 
// Module Name:    RAM_1W2R
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:    
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// module declaration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module RAM_1W2R

    #(
        parameter INIT_FILE = "",               // Initialization file. "" for zeroes.
        parameter ADDR_BITS = 8,                // Number of bits for the addresses
        parameter DATA_BITS = 8                 // Number of bits for the data
    )(
        input  wire                 	clk,        // The single clock
        
        input  wire [ADDR_BITS-1:0] 	addr_a,     // Port A address
        input  wire                 	clken_a,    // Port A clock enable
        output wire [DATA_BITS-1:0] 	data_o_a,   // Port A data output
        output wire                 	uflag_a,    // Port A update flag
        input  wire                 	wren_a,     // Port A write enable
        input  wire [DATA_BITS-1:0] 	data_i_a,   // Port A data input
        
        input  wire [ADDR_BITS-1:0] 	addr_b,     // Port B address
        input  wire                 	clken_b,    // Port B clock enable
        output wire [DATA_BITS-1:0] 	data_o_b,   // Port B data output
        output wire                 	uflag_b     // Port B update flag
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // RAM signals
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    (* RAM_STYLE="BLOCK" *)
    reg [DATA_BITS-1:0] ram [(2**ADDR_BITS)-1:0];
    reg [DATA_BITS-1:0] data_o_a_int    = {DATA_BITS{1'b0}};
    reg [DATA_BITS-1:0] data_o_b_int    = {DATA_BITS{1'b0}};
    reg                 uflag_a_int     = 1'b0;
    reg                 uflag_b_int     = 1'b0;
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Intialization
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    generate
        if (INIT_FILE != "") begin: use_init_file
            initial begin
                $readmemh(INIT_FILE, ram);
            end
        end else begin: init_bram_to_zero
            integer i;
            initial begin
                for (i = 0; i < (2**ADDR_BITS); i = i+1) begin
                    ram[i] = {DATA_BITS{1'b0}};
                end
            end
        end
    endgenerate

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The RAM process
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        uflag_a_int <= 1'b0;
        uflag_b_int <= 1'b0;
        if (clken_a == 1'b1) begin
            if (wren_a == 1'b1) begin
                ram[addr_a] <= data_i_a;
            end
            data_o_a_int <= ram[addr_a];
            uflag_a_int <= 1'b1;
        end
        if (clken_b == 1'b1) begin
            data_o_b_int <= ram[addr_b];
            uflag_b_int <= 1'b1;
        end
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output assignements
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign data_o_a = data_o_a_int;
    assign data_o_b = data_o_b_int;
    assign uflag_a  = uflag_a_int;
    assign uflag_b  = uflag_b_int;
    
endmodule

`default_nettype wire
