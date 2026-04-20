// ============================================================================
// MEM Stage（访存阶段）- 6级流水线双发射版本
// Way1 负责实际内存访问（II 阶段已保证 Way2 不含访存指令），
// Way2 结果直接透传至 MEM/WB 寄存器。
// ============================================================================

module mem_stage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // ---- 来自 EX/MEM 寄存器 —— Way1 ----
    input  wire [ADDR_WIDTH-1:0] pc_w1_i,
    input  wire [DATA_WIDTH-1:0] alu_result_w1_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_w1_i,
    input  wire [4:0]            rd_addr_w1_i,
    input  wire                  valid_w1_i,
    input  wire                  mem_read_en_w1_i,
    input  wire                  mem_write_en_w1_i,
    input  wire [2:0]            mem_size_w1_i,
    input  wire                  reg_write_en_w1_i,
    input  wire [1:0]            wb_sel_w1_i,

    // ---- 来自 EX/MEM 寄存器 —— Way2 (无访存，透传)----
    input  wire [DATA_WIDTH-1:0] alu_result_w2_i,
    input  wire [4:0]            rd_addr_w2_i,
    input  wire                  valid_w2_i,
    input  wire                  reg_write_en_w2_i,
    input  wire [1:0]            wb_sel_w2_i,

    // ---- 数据存储器接口（只有 Way1 会驱动）----
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_wdata,
    output wire                  mem_we,
    output wire [DATA_WIDTH/8-1:0] mem_be,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_gnt,

    // ---- MEM/WB 寄存器 → WB —— Way1 ----
    output reg  [DATA_WIDTH-1:0] alu_result_w1_o,
    output reg  [DATA_WIDTH-1:0] mem_result_w1_o,
    output reg  [4:0]            rd_addr_w1_o,
    output reg                   valid_w1_o,
    output reg                   reg_write_en_w1_o,
    output reg  [1:0]            wb_sel_w1_o,

    // ---- MEM/WB 寄存器 → WB —— Way2 ----
    output reg  [DATA_WIDTH-1:0] alu_result_w2_o,
    output reg  [4:0]            rd_addr_w2_o,
    output reg                   valid_w2_o,
    output reg                   reg_write_en_w2_o,
    output reg  [1:0]            wb_sel_w2_o,
    
    // DCache接口
    output wire [ADDR_WIDTH-1:0] dcache_addr,
    output wire [DATA_WIDTH-1:0] dcache_wdata,
    output wire [7:0]            dcache_be,
    output wire                  dcache_req,
    output wire                  dcache_we,
    output wire [2:0]            dcache_size,
    input  wire [DATA_WIDTH-1:0] dcache_data_out,
    input  wire                  dcache_hit,
    input  wire                  dcache_refill_done,
    input  wire                  dcache_writeback_req,
    input  wire [63:0]           dcache_writeback_addr,
    input  wire [255:0]          dcache_writeback_data,
    input  wire                  dcache_cache_stall,
    output wire [63:0]           dcache_mem_addr,
    output wire [255:0]          dcache_mem_wdata,
    input  wire [255:0]          dcache_mem_rdata,
    input  wire                  dcache_mem_req,
    input  wire                  dcache_mem_we,
    output wire                  dcache_mem_ready
);

wire [2:0] size = mem_size_w1_i;

assign mem_addr  = alu_result_w1_i;
assign mem_we    = mem_write_en_w1_i;

assign mem_be =
    (size == 3'b000) ? 8'b00000001 :
    (size == 3'b001) ? 8'b00000011 :
    (size == 3'b010) ? 8'b00001111 :
    (size == 3'b011) ? 8'b11111111 : 8'b0;

assign mem_wdata =
    (size == 3'b000) ? {56'b0, rs2_data_w1_i[7:0]}  :
    (size == 3'b001) ? {48'b0, rs2_data_w1_i[15:0]} :
    (size == 3'b010) ? {32'b0, rs2_data_w1_i[31:0]} :
    rs2_data_w1_i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_w1_o       <= 1'b0;
        mem_result_w1_o  <= 64'b0;
        // ... 其他复位逻辑
    end else begin
        // Way1
        alu_result_w1_o   <= alu_result_w1_i;
        rd_addr_w1_o      <= rd_addr_w1_i;
        valid_w1_o        <= valid_w1_i && !dcache_cache_stall;
        reg_write_en_w1_o <= reg_write_en_w1_i;
        wb_sel_w1_o       <= wb_sel_w1_i;
        // 处理load数据
        if (mem_read_en_w1_i && dcache_hit) begin
            mem_result_w1_o <= load_data;
        end else if (dcache_refill_done) begin
            mem_result_w1_o <= load_data;
        end else begin
            mem_result_w1_o <= 64'b0;
        end
        // Way2（透传）
        alu_result_w2_o   <= alu_result_w2_i;
        rd_addr_w2_o      <= rd_addr_w2_i;
        valid_w2_o        <= valid_w2_i;
        reg_write_en_w2_o <= reg_write_en_w2_i;
        wb_sel_w2_o       <= wb_sel_w2_i;
    end
end
// 在mem_stage.v中例化DCache
dcache u_dcache (
    .clk(clk),
    .rst_n(rst_n),
    .addr(dcache_addr),
    .wdata(dcache_wdata),
    .be(dcache_be),
    .req(dcache_req),
    .we(dcache_we),
    .size(dcache_size),
    .data_out(dcache_data_out),
    .hit(dcache_hit),
    .refill_done(dcache_refill_done),
    .writeback_req(dcache_writeback_req),
    .writeback_addr(dcache_writeback_addr),
    .writeback_data(dcache_writeback_data),
    .cache_stall(dcache_cache_stall),
    .mem_addr(dcache_mem_addr),
    .mem_wdata(dcache_mem_wdata),
    .mem_rdata(dcache_mem_rdata),
    .mem_req(dcache_mem_req),
    .mem_we(dcache_mem_we),
    .mem_ready(dcache_mem_ready)
);

// 连接DCache接口
assign dcache_addr  = alu_result_w1_i;
assign dcache_we    = mem_write_en_w1_i;
assign dcache_size  = mem_size_w1_i;
assign dcache_req   = (mem_read_en_w1_i || mem_write_en_w1_i) && valid_w1_i;
// 字节使能处理
assign dcache_be =
    (dcache_size == 3'b000) ? 8'b00000001 :
    (dcache_size == 3'b001) ? 8'b00000011 :
    (dcache_size == 3'b010) ? 8'b00001111 :
    (dcache_size == 3'b011) ? 8'b11111111 :
    (dcache_size == 3'b100) ? 8'b00000001 :
    (dcache_size == 3'b101) ? 8'b00000011 :
    (dcache_size == 3'b110) ? 8'b00001111 :
    8'b0;
// 写数据处理
assign dcache_wdata =
    (dcache_size == 3'b000) ? {56'b0, rs2_data_w1_i[7:0]}  :
    (dcache_size == 3'b001) ? {48'b0, rs2_data_w1_i[15:0]} :
    (dcache_size == 3'b010) ? {32'b0, rs2_data_w1_i[31:0]} :
    rs2_data_w1_i;
// Load数据格式化
wire [DATA_WIDTH-1:0] load_data =
    (dcache_size == 3'b000) ? {{56{dcache_data_out[7]}},  dcache_data_out[7:0]}  :
    (dcache_size == 3'b001) ? {{48{dcache_data_out[15]}}, dcache_data_out[15:0]} :
    (dcache_size == 3'b010) ? {{32{dcache_data_out[31]}}, dcache_data_out[31:0]} :
    (dcache_size == 3'b011) ? dcache_data_out :
    (dcache_size == 3'b100) ? {56'b0, dcache_data_out[7:0]}  :
    (dcache_size == 3'b101) ? {48'b0, dcache_data_out[15:0]} :
    (dcache_size == 3'b110) ? {32'b0, dcache_data_out[31:0]} :
    dcache_data_out;

endmodule
