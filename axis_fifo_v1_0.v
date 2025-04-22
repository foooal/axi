// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4-Stream asynchronous FIFO
 */
module axis_fifo_v1_0 #
(
    parameter ADDR_WIDTH = 12,
    parameter TUSER_WIDTH = 1,
    parameter C_AXIS_TDATA_WIDTH = 32
)
(
    /*
     * AXI slave interface (input to the FIFO)
     */
    input  wire                   s00_axis_aclk,

  
    input  wire                   s00_axis_aresetn,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TDATA" *)
    input  wire [C_AXIS_TDATA_WIDTH-1:0]  s00_axis_tdata,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TSTRB" *)
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TVALID" *)
    input  wire                   s00_axis_tvalid,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TREADY" *)
    output wire                   s00_axis_tready,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TLAST" *)
    input  wire                   s00_axis_tlast,
    
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s00_axis, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 1, HAS_TREADY 1, HAS_TSTRB 1, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s00_axis TUSER" *)
    input  wire [TUSER_WIDTH-1:0] s00_axis_tuser,
    
    /*
     * AXI master interface (output of the FIFO)
     */

    input  wire                   m00_axis_aclk,
    

    input  wire                   m00_axis_aresetn,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TDATA" *)
    output wire [C_AXIS_TDATA_WIDTH-1:0]  m00_axis_tdata,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TSTRB" *)
    output wire [(C_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TVALID" *)
    output wire                   m00_axis_tvalid,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TREADY" *)
    input  wire                   m00_axis_tready,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TLAST" *)
    output wire                   m00_axis_tlast,
    
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m00_axis, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 1, HAS_TREADY 1, HAS_TSTRB 1, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m00_axis TUSER" *)
    output wire [TUSER_WIDTH-1:0] m00_axis_tuser
);

localparam TSTRB_WIDTH =    C_AXIS_TDATA_WIDTH/8;
localparam MEM_WIDTH   =    C_AXIS_TDATA_WIDTH + TSTRB_WIDTH + TUSER_WIDTH + 1;


reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_next;
reg [ADDR_WIDTH:0] wr_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_gray_next;
reg [ADDR_WIDTH:0] wr_addr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}}, rd_ptr_next;
reg [ADDR_WIDTH:0] rd_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}}, rd_ptr_gray_next;
reg [ADDR_WIDTH:0] rd_addr_reg = {ADDR_WIDTH+1{1'b0}};

reg [ADDR_WIDTH:0] wr_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};

reg s00_rst_sync1_reg = 1'b1;
reg s00_rst_sync2_reg = 1'b1;
reg s00_rst_sync3_reg = 1'b1;
reg m00_rst_sync1_reg = 1'b1;
reg m00_rst_sync2_reg = 1'b1;
reg m00_rst_sync3_reg = 1'b1;

reg [MEM_WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg [MEM_WIDTH-1:0] mem_read_data_reg = {MEM_WIDTH{1'b0}};//{C_AXIS_TDATA_WIDTH+2{1'b0}};
reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;
wire [MEM_WIDTH-1:0] mem_write_data;

reg [MEM_WIDTH-1:0] m00_data_reg = {MEM_WIDTH{1'b0}};

reg m00_axis_tvalid_reg = 1'b0, m00_axis_tvalid_next;

// full when first TWO MSBs do NOT match, but rest matches
// (gray code equivalent of first MSB different but rest same)
wire full = ((wr_ptr_gray_reg[ADDR_WIDTH] != rd_ptr_gray_sync2_reg[ADDR_WIDTH]) &&
             (wr_ptr_gray_reg[ADDR_WIDTH-1] != rd_ptr_gray_sync2_reg[ADDR_WIDTH-1]) &&
             (wr_ptr_gray_reg[ADDR_WIDTH-2:0] == rd_ptr_gray_sync2_reg[ADDR_WIDTH-2:0]));
// empty when pointers match exactly
wire empty = rd_ptr_gray_reg == wr_ptr_gray_sync2_reg;

// control signals
reg write;
reg read;
reg store_output;

assign s00_axis_tready = ~full & ~s00_rst_sync3_reg;    //只有当FIFO非满，且s和m的复位都释放，s才准备好接受数据

assign m00_axis_tvalid = m00_axis_tvalid_reg;

assign mem_write_data = {s00_axis_tuser,s00_axis_tlast,s00_axis_tstrb, s00_axis_tdata};
assign {m00_axis_tuser,m00_axis_tlast,m00_axis_tstrb, m00_axis_tdata} = m00_data_reg;

// reset synchronization
always @(posedge s00_axis_aclk) begin
    if (!s00_axis_aresetn) begin
        s00_rst_sync1_reg <= 1'b1;
        s00_rst_sync2_reg <= 1'b1;
        s00_rst_sync3_reg <= 1'b1;
    end else begin
        s00_rst_sync1_reg <= 1'b0;
        s00_rst_sync2_reg <= s00_rst_sync1_reg | m00_rst_sync1_reg;
        s00_rst_sync3_reg <= s00_rst_sync2_reg;
    end
end

always @(posedge m00_axis_aclk) begin
    if (!m00_axis_aresetn) begin
        m00_rst_sync1_reg <= 1'b1;
        m00_rst_sync2_reg <= 1'b1;
        m00_rst_sync3_reg <= 1'b1;
    end else begin
        m00_rst_sync1_reg <= 1'b0;
        m00_rst_sync2_reg <= s00_rst_sync1_reg | m00_rst_sync1_reg;
        m00_rst_sync3_reg <= m00_rst_sync2_reg;
    end
end

// Write logic
always @* begin
    write = 1'b0;

    wr_ptr_next = wr_ptr_reg;
    wr_ptr_gray_next = wr_ptr_gray_reg;

    if (s00_axis_tvalid) begin
        // input data valid
        if (~full) begin
            // not full, perform write
            write = 1'b1;
            wr_ptr_next = wr_ptr_reg + 1;
            wr_ptr_gray_next = wr_ptr_next ^ (wr_ptr_next >> 1);
        end
    end
end

always @(posedge s00_axis_aclk) begin
    if (s00_rst_sync3_reg) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        wr_ptr_reg <= wr_ptr_next;
        wr_ptr_gray_reg <= wr_ptr_gray_next;
    end

    wr_addr_reg <= wr_ptr_next;

    if (write) begin
        mem[wr_addr_reg[ADDR_WIDTH-1:0]] <= mem_write_data;
    end
end

// pointer synchronization
always @(posedge s00_axis_aclk) begin
    if (s00_rst_sync3_reg) begin
        rd_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        rd_ptr_gray_sync1_reg <= rd_ptr_gray_reg;
        rd_ptr_gray_sync2_reg <= rd_ptr_gray_sync1_reg;
    end
end

always @(posedge m00_axis_aclk) begin
    if (m00_rst_sync3_reg) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        wr_ptr_gray_sync1_reg <= wr_ptr_gray_reg;
        wr_ptr_gray_sync2_reg <= wr_ptr_gray_sync1_reg;
    end
end

// Read logic
always @* begin
    read = 1'b0;

    rd_ptr_next = rd_ptr_reg;
    rd_ptr_gray_next = rd_ptr_gray_reg;

    mem_read_data_valid_next = mem_read_data_valid_reg;

    if (store_output | ~mem_read_data_valid_reg) begin
        // output data not valid OR currently being transferred
        if (~empty) begin
            // not empty, perform read
            read = 1'b1;
            mem_read_data_valid_next = 1'b1;
            rd_ptr_next = rd_ptr_reg + 1;
            rd_ptr_gray_next = rd_ptr_next ^ (rd_ptr_next >> 1);
        end else begin
            // empty, invalidate
            mem_read_data_valid_next = 1'b0;
        end
    end
end

always @(posedge m00_axis_aclk) begin
    if (m00_rst_sync3_reg) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        mem_read_data_valid_reg <= 1'b0;
    end else begin
        rd_ptr_reg <= rd_ptr_next;
        rd_ptr_gray_reg <= rd_ptr_gray_next;
        mem_read_data_valid_reg <= mem_read_data_valid_next;
    end

    rd_addr_reg <= rd_ptr_next;

    if (read) begin
        mem_read_data_reg <= mem[rd_addr_reg[ADDR_WIDTH-1:0]];
    end
end

// Output register
always @* begin
    store_output = 1'b0;

    m00_axis_tvalid_next = m00_axis_tvalid_reg;

    if (m00_axis_tready | ~m00_axis_tvalid) begin
        store_output = 1'b1;
        m00_axis_tvalid_next = mem_read_data_valid_reg;
    end
end

always @(posedge m00_axis_aclk) begin
    if (m00_rst_sync3_reg) begin
        m00_axis_tvalid_reg <= 1'b0;
    end else begin
        m00_axis_tvalid_reg <= m00_axis_tvalid_next;
    end

    if (store_output) begin
        m00_data_reg <= mem_read_data_reg;
    end
end

endmodule
