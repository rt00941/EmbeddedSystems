module convolution#(
parameter [31:0] IMG_DIM=6,
parameter [31:0] KERNEL_DIM=3,
parameter [31:0] INT_WIDTH=8,
parameter [31:0] FRAC_WIDTH=8)
(
input clk,
input reset,
input conv_en,
input [31:0] layer_nr,
input weight_we,
input [15:0] weight_data,
input [15:0] pixel_in,
output reg conv_en_out,
output output_valid,
output [15:0] pixel_out,
output reg [15:0] bias
);

wire [15:0] weight_values[KERNEL_DIM - 1:0];
wire [15:0] acc_values[KERNEL_DIM - 1:0];
wire [15:0] shift_reg_output[KERNEL_DIM - 2:0];
reg [31:0] output_shift_reg_nr;

  assign pixel_out = acc_values[KERNEL_DIM - 1][KERNEL_DIM - 1];
  conv_controller controller(
      .clk(clk),
    .conv_en(conv_en),
    .layer_nr(layer_nr),
    .output_valid(output_valid));

  genvar row, col;
  generate for (row=0; row <= KERNEL_DIM - 1; row = row + 1) begin: gen_mac_rows
      genvar col;
      for (col=0; col <= KERNEL_DIM - 1; col = col + 1) begin: gen_mac_columns
          if (row == 0 && col == 0) begin: mac_first_leftmost
              mac mac1(
                  .clk(clk),
          .reset(reset),
          .weight_we(weight_we),
          .weight_in(weight_data),
          .multi_value(pixel_in),
          .acc_value({0}),
          .weight_out(weight_values[row][col]),
          .result(acc_values[row][col]));

      end
      if (row > 0 && col == 0) begin: mac_other_leftmost
              mac mac1(
                  .clk(clk),
          .reset(reset),
          .weight_we(weight_we),
          .weight_in(weight_values[row - 1][KERNEL_DIM - 1]),
          .multi_value(pixel_in),
          .acc_value(shift_reg_output[row - 1]),
          .weight_out(weight_values[row][col]),
          .result(acc_values[row][col]));

      end
      if ((col > 0 && col < (KERNEL_DIM - 1))) begin: mac_others
              mac mac3(
                  .clk(clk),
          .reset(reset),
          .weight_we(weight_we),
          .weight_in(weight_values[row][col - 1]),
          .multi_value(pixel_in),
          .acc_value(acc_values[row][col - 1]),
          .weight_out(weight_values[row][col]),
          .result(acc_values[row][col]));

      end
      if (col == (KERNEL_DIM - 1)) begin: mac_rightmost
              mac mac4(
                  .clk(clk),
          .reset(reset),
          .weight_we(weight_we),
          .weight_in(weight_values[row][col - 1]),
          .multi_value(pixel_in),
          .acc_value(acc_values[row][col - 1]),
          .weight_out(weight_values[row][col]),
          .result(acc_values[row][col]));

      end
      if (row < (KERNEL_DIM - 1) && col == (KERNEL_DIM - 1)) begin: shift_regs
              sfixed_shift_registers sr(
                  .clk(clk),
          .reset(reset),
          .we(conv_en),
          .output_reg(output_shift_reg_nr),
          .data_in(acc_values[row][col]),
          .data_out(shift_reg_output[row]));

      end
    end
  end
  endgenerate
  always @(layer_nr) begin
    if(layer_nr == 0) begin
      output_shift_reg_nr <= IMG_DIM - KERNEL_DIM - 1;
    end
    else if(layer_nr == 1) begin
      output_shift_reg_nr <= ((((IMG_DIM - KERNEL_DIM + 1)) / 2)) - KERNEL_DIM - 1;
    end
    else begin
      output_shift_reg_nr <= 0;
    end
  end

  always @(posedge clk or posedge reset) begin
    if(reset == 1'b 0) begin
      bias <= {16{1'b0}};
    end
    else if(weight_we == 1'b 1) begin
      bias <= weight_values[KERNEL_DIM - 1][KERNEL_DIM - 1];
    end
  end

  always @(posedge clk) begin
    conv_en_out <= conv_en;
  end


endmodule
