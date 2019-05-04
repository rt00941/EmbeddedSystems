module convolution_layer#(
parameter IMG_DIM=32,
parameter KERNEL_DIM=5,
parameter POOL_DIM=2,
parameter INT_WIDTH=16,
parameter FRAC_WIDTH=16)
(
input clk,
input reset,
input conv_en,
input final_set,
input [31:0] layer_nr,
input weight_we,
input [31:0] weight_data,
input [31:0] pixel_in,
output reg pixel_valid,
output reg [31:0] pixel_out,
output [31:0] dummy_bias
);

wire [INT_WIDTH-1:-FRAC_WIDTH] bias;
reg [INT_WIDTH-1:-FRAC_WIDTH] bias2;
wire [INT_WIDTH-1:-FRAC_WIDTH] weight_avgPoolToBias2;
reg [INT_WIDTH-1:-FRAC_WIDTH] scale_factor;
wire convEn_convToMux;
wire outputValid_convToMux;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_convToMux;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixel_BufToMux;
wire buffer_we;
reg [INT_WIDTH-1:-FRAC_WIDTH] pixel_MuxToBias;
reg valid_MuxToBias;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixel_MuxToF2F;
wire pixelValid_MuxToF2F;
reg valid_biasToTanh;
reg [INT_WIDTH-1:-FRAC_WIDTH] pixel_biasToTanh;
wire pixelValid_TanhToAvgPool;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_TanhToAvgPool;
wire pixelValid_AvgPoolToScaleFactor;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_AvgPoolToScaleFactor;
reg pixelValid_ScaleFactorToBias2;
reg [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_ScaleFactorToBias2;
reg pixelValid_Bias2ToTanh2;
reg [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_Bias2ToTanh2;
wire pixelValid_Tanh2ToOut;
wire [INT_WIDTH-1:-FRAC_WIDTH] pixelOut_Tanh2ToOut;
reg pixelValid_F2FToOut;
reg pixelOut_F2FToOut;
wire float_size;
reg is_layer_1;

  convolution conv(
      .clk(clk),
    .reset(reset),
    .conv_en(conv_en),
    .layer_nr(layer_nr),
    .weight_we(weight_we),
    .weight_data(weight_data),
    .pixel_in(pixel_in),
    .output_valid(outputValid_convToMux),
    //dv_conv_to_buf_and_mux,
    .conv_en_out(convEn_convToMux),
    .pixel_out(pixelOut_convToMux),
    //data_conv_to_buf_and_mux,
    .bias(bias));

  always @(layer_nr) begin
    if(layer_nr == 1 || layer_nr == 2) begin
      is_layer_1 <= 1'b 1;
    end
    else begin
      is_layer_1 <= 1'b 0;
    end
  end

  assign buffer_we = is_layer_1 & outputValid_convToMux;
  sfixed_fifo intermediate_buffer(
      .clk(clk),
    .reset(reset),
    .write_en(buffer_we),
    .layer_nr(layer_nr),
    .data_in(pixelOut_convToMux),
    .data_out(pixel_BufToMux)
    );

  always @(posedge clk) begin
    if(layer_nr == 0) begin
      pixel_MuxToBias <= pixelOut_convToMux;
      valid_MuxToBias <= outputValid_convToMux;
    end
    else if(layer_nr == 1 || layer_nr == 2) begin
      if(final_set == 1'b 1) begin
        pixel_MuxToBias <= (pixelOut_convToMux + pixel_BufToMux);
        valid_MuxToBias <= outputValid_convToMux;
      end
      else begin
        pixel_MuxToBias <= {32{1'b0}};
        valid_MuxToBias <= 1'b 0;
      end
    end
  end

  always @(posedge clk) begin
    pixel_biasToTanh <= (bias + pixel_MuxToBias);
    valid_biasToTanh <= valid_MuxToBias;
  end

  tan_h activation_function(
      .clk(clk),
    .input_valid(valid_biasToTanh),
    .x(pixel_biasToTanh[INT_WIDTH-1:-FRAC_WIDTH]),
    .output_valid(pixelValid_TanhToAvgPool),
    .y(pixelOut_TanhToAvgPool));

  average_pooler avg_pooler(
      .clk(clk),
    .reset(reset),
    .conv_en(conv_en),
    .layer_nr(layer_nr),
    .weight_in(bias),
    .weight_we(weight_we),
    .input_valid(pixelValid_TanhToAvgPool),
    .data_in(pixelOut_TanhToAvgPool),
    .data_out(pixelOut_AvgPoolToScaleFactor),
    .output_valid(pixelValid_AvgPoolToScaleFactor),
    .output_weight(weight_avgPoolToBias2));

  always @(posedge clk) begin
    pixelOut_ScaleFactorToBias2 <= (scale_factor * pixelOut_AvgPoolToScaleFactor);
    pixelValid_ScaleFactorToBias2 <= pixelValid_AvgPoolToScaleFactor;
  end

  always @(posedge clk) begin
    pixelOut_Bias2ToTanh2 <= (bias2 + pixelOut_ScaleFactorToBias2);
    pixelValid_Bias2ToTanh2 <= pixelValid_ScaleFactorToBias2;
  end

  tan_h activation_function2(
      .clk(clk),
    .input_valid(pixelValid_Bias2ToTanh2),
    .x(pixelOut_Bias2ToTanh2[INT_WIDTH-1:-FRAC_WIDTH]),
    .output_valid(pixelValid_Tanh2ToOut),
    .y(pixelOut_Tanh2ToOut));

  always @(posedge clk) begin
    pixelOut_F2FToOut <= pixelOut_TanhToAvgPool;
    pixelValid_F2FToOut <= pixelValid_TanhToAvgPool;
  end

  always @(posedge clk) begin
    if(layer_nr == 0) begin
      pixel_out <= pixelOut_Tanh2ToOut;
      pixel_valid <= pixelValid_Tanh2ToOut;
    end
    else if(layer_nr == 1) begin
      pixel_out <= pixelOut_Tanh2ToOut;
      pixel_valid <= pixelValid_Tanh2ToOut & ((final_set));
    end
    else begin
      pixel_out <= pixelOut_F2FToOut;
      pixel_valid <= pixelValid_F2FToOut;
    end
  end

  always @(posedge clk) begin
    if(reset == 1'b 0) begin
      bias2 <= {32{1'b0}};
    end
    else if(weight_we == 1'b 1) begin
      bias2 <= weight_avgPoolToBias2;
    end
  end

  always @(posedge clk) begin
    if(reset == 1'b 0) begin
      scale_factor <= {32{1'b0}};
    end
    else if(weight_we == 1'b 1) begin
      scale_factor <= bias2;
    end
  end


endmodule
