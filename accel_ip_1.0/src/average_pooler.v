module average_pooler#(
parameter [31:0] IMG_DIM=8,
parameter [31:0] KERNEL_DIM=3,
parameter [31:0] POOL_DIM=2,
parameter [31:0] INT_WIDTH=8,
parameter [31:0] FRAC_WIDTH=8
)
(
input clk,
input reset,
input conv_en,
input [31:0] layer_nr,
input weight_in,
input weight_we,
input input_valid,
input data_in,
output reg data_out,
output reg output_valid,
output output_weight
);

localparam POOL_ARRAY_DIM_MAX = IMG_DIM/POOL_DIM;

wire [INT_WIDTH-1:-FRAC_WIDTH] buffer_values [POOL_ARRAY_DIM_MAX - 2:0];
reg reset_buffers;
reg write_buffers;
reg pool_sum;
reg weight;
reg output_valid_buf;
reg [31:0] pool_x = 0;
wire buf_reset;
reg averaged_sum;
reg averaged_sum_valid;
reg [31:0] POOL_ARRAY_DIM;

  assign buf_reset = reset & reset_buffers;
  always @(layer_nr) begin
    if(layer_nr == 0) begin
      POOL_ARRAY_DIM <= POOL_ARRAY_DIM_MAX;
    end
    else begin
      POOL_ARRAY_DIM <= ((((IMG_DIM / 2)) - KERNEL_DIM + 1)) / POOL_DIM;
    end
  end

  genvar i;
  generate for (i=0; i <= POOL_ARRAY_DIM_MAX - 2; i = i + 1) begin: generate_buffers
      if (i == 0) begin: first_buffer
          sfixed_buffer uf_buffer(
              .clk(clk),
        .reset(buf_reset),
        .we(write_buffers),
        .data_in(pool_sum),
        .data_out(buffer_values[i]));
    end
    if (i > 0) begin: other_buffers
          sfixed_buffer uf_buffer(
              .clk(clk),
        .reset(buf_reset),
        .we(write_buffers),
        .data_in(buffer_values[i - 1]),
        .data_out(buffer_values[i]));

    end
  end
  endgenerate
  always @(posedge clk) begin : P1
    reg [31:0] x;
    reg [31:0] y;

    if(conv_en == 1'b0 || reset == 1'b0) begin
      output_valid_buf <= 1'b0;
      reset_buffers <= 1'b1;
      write_buffers <= 1'b0;
      x = 0;
      y = 0;
      pool_x <= 0;
    end
    else if(input_valid == 1'b1) begin
      if(x == (POOL_DIM - 1) && y == (POOL_DIM - 1)) begin
        if(pool_x == (POOL_ARRAY_DIM - 1)) begin
          output_valid_buf <= 1'b1;
          reset_buffers <= 1'b0;
          write_buffers <= 1'b0;
          x = 0;
          y = 0;
          pool_x <= 0;
        end
        else begin
          output_valid_buf <= 1'b1;
          reset_buffers <= 1'b1;
          write_buffers <= 1'b1;
          x = 0;
          pool_x <= pool_x + 1;
        end
      end
      else if(x == (POOL_DIM - 1)) begin
        output_valid_buf <= 1'b0;
        x = 0;
        write_buffers <= 1'b1;
        reset_buffers <= 1'b1;
        if(pool_x == (POOL_ARRAY_DIM - 1)) begin
          y = y + 1;
          pool_x <= 0;
        end
        else begin
          pool_x <= pool_x + 1;
        end
      end
      else begin
        x = x + 1;
        output_valid_buf <= 1'b0;
        reset_buffers <= 1'b1;
        write_buffers <= 1'b0;
      end
    end
    else begin
      output_valid_buf <= 1'b0;
      reset_buffers <= 1'b1;
      write_buffers <= 1'b0;
    end
  end

  always @(posedge clk) begin
    if(conv_en == 1'b0 || reset_buffers == 1'b0 || reset == 1'b0) begin
      pool_sum <= {1{1'b0}};
    end
    else if(input_valid == 1'b1) begin
      if(write_buffers == 1'b1) begin
        pool_sum <= (data_in + buffer_values[POOL_ARRAY_DIM - 2]);
      end
      else begin
        pool_sum <= (data_in + pool_sum);
      end
    end
    else if(write_buffers == 1'b1) begin
      pool_sum <= buffer_values[POOL_ARRAY_DIM - 2];
    end
  end

  always @(posedge clk) begin
    if(reset == 1'b0) begin
      weight <= {1{1'b0}};
    end
    else if(weight_we == 1'b1) begin
      weight <= weight_in;
    end
  end

  always @(posedge clk) begin
    if(reset == 1'b0) begin
      averaged_sum <= {1{1'b0}};
      averaged_sum_valid <= 1'b0;
    end
    else begin
      averaged_sum <= (weight * pool_sum);
      averaged_sum_valid <= output_valid_buf;
    end
  end

  always @(posedge clk) begin
    output_valid <= averaged_sum_valid;
    data_out <= averaged_sum;
  end

  assign output_weight = weight;

endmodule
