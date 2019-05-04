module sfixed_shift_registers#(
parameter [31:0] NOF_REGS=8,
parameter [31:0] INT_WIDTH=8,
parameter [31:0] FRAC_WIDTH=8)
(
input clk,
input reset,
input we,
input [31:0] output_reg,
input [15:0] data_in,
output reg [15:0] data_out
);

wire [15:0] shift_reg_values[NOF_REGS - 1:0];

  always @(output_reg or shift_reg_values[7] or shift_reg_values[6] or shift_reg_values[5] or shift_reg_values[4] or shift_reg_values[3] or shift_reg_values[2] or shift_reg_values[1] or shift_reg_values[0] ) begin
    if(output_reg >= 0) begin
      data_out <= shift_reg_values[output_reg];
    end
    else if(output_reg == 0) begin
      data_out <= data_in;
    end
    else begin
      data_out <= shift_reg_values[0];
    end
  end

  genvar regs;
  generate for (regs=0; regs <= NOF_REGS - 1; regs = regs + 1) begin: gen_regs_loop
      if (regs == 0) begin: first_reg
          sfixed_buffer shift_reg(
              .clk(clk),
        .reset(reset),
        .we(we),
        .data_in(data_in),
        .data_out(shift_reg_values[regs]));

    end
    if (regs > 0) begin: other_regs
          sfixed_buffer shift_reg(
              .clk(clk),
        .reset(reset),
        .we(we),
        .data_in(shift_reg_values[regs - 1]),
        .data_out(shift_reg_values[regs]));

    end
  end
  endgenerate

endmodule
