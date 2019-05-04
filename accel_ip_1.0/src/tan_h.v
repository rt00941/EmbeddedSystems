module tan_h#(
parameter [31:0] INT_WIDTH=16,
parameter [31:0] FRAC_WIDTH=16,
parameter [31:0] CONST_INT_WIDTH=16,
parameter [31:0] CONST_FRAC_WIDTH=16)
(
input clk,
input input_valid,
input [INT_WIDTH-1:-FRAC_WIDTH] x,
output reg output_valid,
output reg y
);

localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] m1 = 0.54324*0.5; 
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] m2 = 0.16957*0.5;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] c1 = 1;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] c2 = 0.42654;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] d1 = 0.016;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] d2 = 0.4519;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] a = 1.52;
localparam [CONST_INT_WIDTH-1 : -CONST_FRAC_WIDTH] b = 2.57;
// cx = cycle x.
wire [INT_WIDTH-1:-FRAC_WIDTH] abs_x;
reg [INT_WIDTH-1:-FRAC_WIDTH] abs_x_c1;
wire [INT_WIDTH-1:-FRAC_WIDTH] abs_x_c2;
reg [INT_WIDTH-1:-FRAC_WIDTH] pow_x_c1;
wire [INT_WIDTH-1:-FRAC_WIDTH] pow_x_c2;
reg signed_bit_c1;
reg signed_bit_c2;
reg signed_bit_c3;
reg input_valid_c1;
reg input_valid_c2;
reg input_valid_c3;
reg [INT_WIDTH-1:-FRAC_WIDTH] tanh_x_c3;
reg [INT_WIDTH-1:-FRAC_WIDTH] term1_c2;
reg [INT_WIDTH-1:-FRAC_WIDTH] term2_c2;
reg [INT_WIDTH-1:-FRAC_WIDTH] term3_c2;

  assign abs_x = x; //need to invert based on sign
  // Absolute value of x
  always @(posedge clk) begin
    abs_x_c1 <= abs_x;
    pow_x_c1 <= (abs_x * abs_x);
    signed_bit_c1 <= x[INT_WIDTH - 1];
    input_valid_c1 <= input_valid;
  end

  always @(posedge clk) begin
    signed_bit_c2 <= signed_bit_c1;
    input_valid_c2 <= input_valid_c1;
    if(abs_x_c1 <= a && abs_x_c1 >= 0) begin
      term1_c2 <= (m1 * pow_x_c1);
      term2_c2 <= (c1 * abs_x_c1);
      term3_c2 <= d1;
    end
    else if(abs_x_c1 <= b && abs_x_c1 > a) begin
      term1_c2 <= (m2 * pow_x_c1);
      term2_c2 <= (c2 * abs_x_c1);
      term3_c2 <= d2;
    end
    else begin
      term1_c2 <= {1{1'b0}};
      term2_c2 <= {1{1'b0}};
      term3_c2 <= 1;
    end
  end

  always @(posedge clk) begin
    signed_bit_c3 <= signed_bit_c2;
    input_valid_c3 <= input_valid_c2;
    tanh_x_c3 <= (term1_c2 + term2_c2 + term3_c2);
  end

  always @(posedge clk) begin
    if(signed_bit_c3 == 1'b 1) begin
      y <= ( -tanh_x_c3);
    end
    else begin
      y <= tanh_x_c3;
    end
    output_valid <= input_valid_c3;
  end


endmodule
