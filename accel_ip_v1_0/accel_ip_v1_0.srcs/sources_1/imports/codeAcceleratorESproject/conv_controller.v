module conv_controller#(
parameter [31:0] IMAGE_DIM=3,
parameter [31:0] KERNEL_DIM=2)
(
input clk,
input conv_en,
input [31:0] layer_nr,
output reg output_valid
);

reg [31:0] row_num = 0;
reg [31:0] column_num = 0;
reg reached_valid_row;
reg conv_en_buf;
wire output_valid_buf;
reg [31:0] curr_img_dim;

  always @(layer_nr) begin
    if(layer_nr == 0) begin
      curr_img_dim <= IMAGE_DIM;
    end
    else if(layer_nr == 1) begin
      curr_img_dim <= ((IMAGE_DIM - KERNEL_DIM + 1)) / 2;
    end
    else begin
      curr_img_dim <= ((((((IMAGE_DIM - KERNEL_DIM + 1)) / 2)) - KERNEL_DIM + 1)) / 2;
    end
  end

  always @(posedge clk) begin
    conv_en_buf <= conv_en;
    if(conv_en == 1'b 1) begin
      if((column_num == curr_img_dim && row_num == curr_img_dim)) begin
        row_num <= 1;
        column_num <= 1;
        reached_valid_row <= 1'b 0;
      end
      else begin
        if((column_num == curr_img_dim)) begin
          column_num <= 1;
          row_num <= row_num + 1;
        end
        else begin
          column_num <= column_num + 1;
        end
        if((row_num == KERNEL_DIM)) begin
          reached_valid_row <= 1'b 1;
        end
      end
    end
    else begin
      row_num <= 1;
      column_num <= 0;
      reached_valid_row <= 1'b 0;
    end
  end

  always @(posedge clk) begin
    if(conv_en_buf == 1'b 1 && reached_valid_row == 1'b 1 && (column_num >= (KERNEL_DIM - 1) && column_num < curr_img_dim)) begin
      output_valid <= 1'b 1;
    end
    else begin
      output_valid <= 1'b 0;
    end
  end


endmodule
