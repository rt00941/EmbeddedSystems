module sfixed_fifo#(
parameter [31:0] INT_WIDTH=16,
parameter [31:0] FRAC_WIDTH=16,
parameter [31:0] FIFO_DEPTH=128)
(
input clk,
input reset,
input write_en,
input layer_nr,
input [INT_WIDTH-1:-FRAC_WIDTH] data_in,
output reg [INT_WIDTH-1:-FRAC_WIDTH] data_out
);

reg [INT_WIDTH-1:-FRAC_WIDTH] Memory [0:FIFO_DEPTH - 1];
reg [31:0] index;
reg looped;
reg [31:0] LAYER_DEPTH;

  always @(layer_nr) begin
    if(layer_nr == 1) begin
      LAYER_DEPTH <= FIFO_DEPTH;
    end
    else begin
      LAYER_DEPTH <= 25;
    end
  end

  always @(looped or Memory[index] or index) begin
    if(looped == 1) begin
      data_out <= Memory[index];
    end
    else begin
      data_out <= {1{1'b0}};
    end
  end

  always @(posedge clk or posedge reset) begin
    if(reset == 1'b 0) begin
      index <= 0;
      looped <= 0;
    end else begin
      if((write_en == 1'b 1)) begin
        if(looped == 1) begin
          Memory[index] <= (data_in + Memory[index]);
        end
        else begin
          Memory[index] <= data_in;
        end
        if(index == (LAYER_DEPTH - 1)) begin
          index <= 0;
          looped <= 1;
        end
        else begin
          index <= index + 1;
        end
      end
    end
  end


endmodule
