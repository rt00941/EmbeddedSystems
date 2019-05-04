module mac#(
parameter [31:0] INT_WIDTH=8,
parameter [31:0] FRAC_WIDTH=8)
(
input clk,
input reset,
input weight_we,
input weight_in,
input multi_value,
input acc_value,
output weight_out,
output reg result
);

reg weight_reg;
reg sum;
reg product;

  assign weight_out = weight_reg;
  always @(posedge clk) begin
    if((reset == 1'b0)) begin
      weight_reg <= {1{1'b0}};
    end
    else if((weight_we == 1'b 1)) begin
      weight_reg <= weight_in;
    end
  end

  always @(posedge clk) begin
    result <= (sum);
  end

  always @(product or weight_reg or acc_value or multi_value) begin
    product <= weight_reg * multi_value;
    sum <= product + acc_value;
  end


endmodule
