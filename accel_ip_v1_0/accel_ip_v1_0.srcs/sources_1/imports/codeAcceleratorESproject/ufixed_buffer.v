module sfixed_buffer#(
parameter [31:0] INT_WIDTH=8,
parameter [31:0] FRAC_WIDTH=8)
(
input clk,
input reset,
input we,
input [15:0] data_in,
output [15:0] data_out
);

reg [15:0] stored_value;

  assign data_out = stored_value;
  always @(posedge clk) begin
    if((reset == 1'b 0)) begin
      stored_value <= {16{1'b0}};
    end
    else if((we == 1'b 1)) begin
      stored_value <= data_in;
    end
  end


endmodule
