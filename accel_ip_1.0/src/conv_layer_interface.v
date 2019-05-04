module conv_layer_interface#(
parameter [31:0] C_S_AXI_DATA_WIDTH=32,
parameter [31:0] IMG_DIM=32,
parameter [31:0] KERNEL_DIM=5,
parameter [31:0] POOL_DIM=2,
parameter [31:0] INT_WIDTH=16,
parameter [31:0] FRAC_WIDTH=16)
(
input clk,
input reset,
// NOTE: Is active low.
// Interface for controlling module
input [2:0] s_axi_raddr,
output reg [C_S_AXI_DATA_WIDTH - 1:0] s_axi_rdata,
input [C_S_AXI_DATA_WIDTH - 1:0] s_axi_wdata,
input [2:0] s_axi_waddr,
input s_axi_we,
// Interface for streaming data in
input s_axis_tvalid,
output s_axis_tready,
input [C_S_AXI_DATA_WIDTH - 1:0] s_axis_tdata,
input [((C_S_AXI_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
input s_axis_tlast,
// Interface for streaming data out
output reg m_axis_tvalid,
input m_axis_tready,
output [C_S_AXI_DATA_WIDTH - 1:0] m_axis_tdata,
output [((C_S_AXI_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
output reg m_axis_tlast
);



wire [INT_WIDTH-1:-FRAC_WIDTH] results[3:0]; 
// Conv layer (cl) signals --
reg cl_reset;
wire conv_layer_reset;
wire cl_conv_en;
reg [INT_WIDTH-1:-FRAC_WIDTH] cl_layer_nr;
reg cl_final_set;
wire cl_weight_we;
wire [INT_WIDTH-1:-FRAC_WIDTH] cl_weight_data;
wire [INT_WIDTH-1:-FRAC_WIDTH] cl_pixel_in;
wire cl_pixel_valid;
wire [INT_WIDTH + FRAC_WIDTH - 1:0] cl_pixel_out;
wire [INT_WIDTH-1:-FRAC_WIDTH] cl_dummy_bias;

// control signals 

reg [31:0] Set_Size;
wire [1:0] op_code;
reg [C_S_AXI_DATA_WIDTH-1:0] nof_outputs;
reg start_processing;
reg [C_S_AXI_DATA_WIDTH-1:0] nof_input_sets;

// constants

localparam Layer0_Nof_Outputs = 32'd196;
localparam Layer1_Nof_Outputs = 32'd25;
localparam Layer1_Set_Size = 32'd196;
localparam Layer2_Set_Size = 32'd25;
localparam Layer2_Nof_Outputs = 32'd1;

// state signals
reg is_writing_weights;
reg is_executing_cl;

// output streaming buffer
reg [INT_WIDTH+FRAC_WIDTH-1:0] out_sbuffer;

  assign op_code = s_axi_wdata[1:0];
  always @(posedge clk or posedge reset) begin
    if(reset == 1'b0) begin
      cl_layer_nr <= 0;
      nof_outputs <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b0}};
      start_processing <= 1'b0;
      nof_input_sets <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b0}};
    end else begin
      if(s_axi_we == 1'b1) begin
        if(s_axi_waddr == 3'b 000) begin
          case(op_code)
          2'b 00 : begin
            start_processing <= 1'b 1;
          end
          default : begin
            start_processing <= 1'b 0;
          end
          endcase
        end
        else if(s_axi_waddr == 3'b 001) begin
          start_processing <= 1'b 0;
          if(s_axi_wdata[0] == 1'b 1) begin
            nof_outputs <= Layer0_Nof_Outputs;
            cl_layer_nr <= 0;
            Set_Size <= {32{1'b0}};
          end
          else if(s_axi_wdata[1] == 1'b 1) begin
            nof_outputs <= Layer1_Nof_Outputs;
            cl_layer_nr <= 1;
            Set_Size <= Layer1_Set_Size;
          end
          else if(s_axi_wdata[2] == 1'b 1) begin
            nof_outputs <= Layer2_Nof_Outputs;
            cl_layer_nr <= 2;
            Set_Size <= Layer2_Set_Size;
          end
        end
        else if(s_axi_waddr == 3'b 010) begin
          start_processing <= 1'b 0;
          nof_input_sets <= s_axi_wdata;
        end
        else begin
          start_processing <= 1'b 0;
        end
      end
      else begin
        start_processing <= 1'b 0;
      end
    end
  end

  always @(*) begin
    case(s_axi_raddr)
    3'b 000 : begin
      s_axi_rdata <= s_axis_tdata;
      // 0
    end
    3'b 001 : begin
      s_axi_rdata <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b1}};
      // 4
    end
    3'b 010 : begin
      s_axi_rdata <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b1}};
      // 8
    end
    3'b 011 : begin
      s_axi_rdata <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b1}};
      // 12
      //            when b"100" => s_axi_rdata <= (0 => (is_writing_weights or is_executing_cl)) others => '0'); -- 16
    end
    3'b 101 : begin
      s_axi_rdata <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b1}};
      // 20
    end
    3'b 110 : begin
      s_axi_rdata <= nof_outputs;
      // 24
    end
    3'b 111 : begin
      s_axi_rdata <= cl_dummy_bias;
      // 28
    end
    default : begin
      s_axi_rdata <= {(((C_S_AXI_DATA_WIDTH - 1))-((0))+1){1'b1}};
    end
    endcase
  end

  assign s_axis_tready = is_writing_weights | is_executing_cl;
  assign cl_weight_we = is_writing_weights & s_axis_tvalid;
  assign cl_weight_data = s_axis_tdata;
  always @(posedge clk or posedge reset) begin : P1
    reg [31:0] nof_processed_outputs;
    reg [31:0] nof_data_written;
    reg [31:0] nof_weights_written;
    reg [31:0] nof_input_sets_processed;

    if(reset == 1'b 0) begin
      nof_processed_outputs = 0;
      nof_data_written = 0;
      nof_weights_written = 0;
      nof_input_sets_processed = 0;
      is_executing_cl <= 1'b 0;
      is_writing_weights <= 1'b 0;
      cl_final_set <= 1'b 0;
      m_axis_tlast <= 1'b 0;
      m_axis_tvalid <= 1'b 0;
      cl_reset <= 1'b 1;
    end else begin
      if(start_processing == 1'b 1) begin
        is_writing_weights <= 1'b 1;
        cl_reset <= 1'b 1;
        // WEIGHT HANDLING
      end
      else if(is_writing_weights == 1'b1) begin
        cl_reset <= 1'b1;
        m_axis_tlast <= 1'b0;
        m_axis_tvalid <= 1'b0;
        cl_final_set <= 1'b0;
        if(s_axis_tvalid == 1'b1) begin
          if(nof_weights_written == (KERNEL_DIM * KERNEL_DIM + 3)) begin
            is_writing_weights <= 1'b0;
            nof_weights_written = 0;
            is_executing_cl <= 1'b1;
          end
          else begin
            nof_weights_written = nof_weights_written + 1;
          end
        end
        // PROCESSING HANDLING
      end
      else if(is_executing_cl == 1'b1) begin
        // PROCESSING FINAL INPUT SET
        if(nof_input_sets_processed == (nof_input_sets - 1)) begin
          cl_final_set = 1'b1;
          if(cl_pixel_valid == 1'b1) begin
            out_sbuffer = cl_pixel_out;
            m_axis_tvalid = 1'b1;
            if(nof_processed_outputs == (nof_outputs - 1)) begin
              cl_reset = 1'b0;
              is_executing_cl = 1'b0;
              m_axis_tlast = 1'b1;
              nof_processed_outputs = 0;
              nof_input_sets_processed = 0;
            end
            else begin
              cl_reset = 1'b1;
              nof_processed_outputs = nof_processed_outputs + 1;
              m_axis_tlast = 1'b0;
            end
          end
          else begin
            cl_reset <= 1'b1;
            m_axis_tlast <= 1'b0;
            m_axis_tvalid <= 1'b0;
          end
          // PROCESSING ALL OTHER SETS
        end
        else begin
          cl_reset <= 1'b1;
          cl_final_set <= 1'b0;
          m_axis_tvalid <= 1'b0;
          m_axis_tlast <= 1'b0;
          if(nof_data_written == (Set_Size - 1)) begin
            is_writing_weights <= 1'b1;
            is_executing_cl <= 1'b0;
            nof_data_written = 0;
            nof_input_sets_processed = nof_input_sets_processed + 1;
          end
          else begin
            nof_data_written = nof_data_written + 1;
          end
        end
      end
      else begin
        cl_reset <= 1'b1;
        nof_processed_outputs = 0;
        nof_data_written = 0;
        nof_weights_written = 0;
        nof_input_sets_processed = 0;
        is_executing_cl <= 1'b0;
        is_writing_weights <= 1'b0;
        m_axis_tlast <= 1'b0;
        m_axis_tvalid <= 1'b0;
      end
    end
  end

  assign cl_conv_en = is_executing_cl;
  assign cl_pixel_in = s_axis_tdata;
  assign m_axis_tkeep = {(((((C_S_AXI_DATA_WIDTH / 8)) - 1))-((0))+1){1'b1}};
  assign m_axis_tdata = out_sbuffer;
  // PORT MAPS --
  assign conv_layer_reset = reset & cl_reset;
  convolution_layer conv_layer_port_map(
      .clk(clk),
    .reset(conv_layer_reset),
    .conv_en(cl_conv_en),
    .final_set(cl_final_set),
    .layer_nr(cl_layer_nr),
    .weight_we(cl_weight_we),
    .weight_data(cl_weight_data),
    .pixel_in(cl_pixel_in),
    .pixel_valid(cl_pixel_valid),
    .pixel_out(cl_pixel_out),
    .dummy_bias(cl_dummy_bias));


endmodule
