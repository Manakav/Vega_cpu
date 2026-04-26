// ============================================================================
// MEM Stage（访存阶段）- 6级流水线双发射版本
// Way1 负责实际内存访问（II 阶段已保证 Way2 不含访存指令），
// Way2 结果直接透传至 MEM/WB 寄存器。
// 优化：简化MUX树 + 寄存化关键路径
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

    // DCache接口 (连接到外部axi_mem)
    output wire [ADDR_WIDTH-1:0] dcache_addr,
    output wire [DATA_WIDTH-1:0] dcache_wdata,
    output wire [7:0]            dcache_be,
    output wire                  dcache_req,
    output wire                  dcache_we,
    output wire [2:0]            dcache_size,
    output wire                  dcache_writeback_req,
    output wire [63:0]           dcache_writeback_addr,
    output wire [255:0]          dcache_writeback_data,
    output wire                  dcache_cache_stall,
    output wire [63:0]           dcache_mem_addr,
    output wire [255:0]          dcache_mem_wdata,
    input  wire [255:0]          dcache_mem_rdata,
    output wire                  dcache_mem_req,
    output wire                  dcache_mem_we,
    input  wire                  dcache_mem_ready
);

// 在mem_stage.v中例化DCache
wire [DATA_WIDTH-1:0] dcache_data_out;
wire                  dcache_hit;
wire                  dcache_refill_done;

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

// 字节使能 - 用移位+掩码替代7层三元MUX
wire [3:0] be_bytes = (dcache_size == 3'b000) ? 4'd1 :
                       (dcache_size == 3'b001) ? 4'd2 :
                       (dcache_size == 3'b010) ? 4'd4 :
                       (dcache_size == 3'b011) ? 4'd8 : 4'd0;
assign dcache_be = (be_bytes > 0) ? ((8'b1 << be_bytes) - 1) : 8'b0;

// 写数据处理 - 用掩码替代7层三元MUX
wire [63:0] wdata_mask = (dcache_size == 3'b000) ? 64'h00000000000000FF :
                         (dcache_size == 3'b001) ? 64'h000000000000FFFF :
                         (dcache_size == 3'b010) ? 64'h00000000FFFFFFFF :
                                                   64'hFFFFFFFFFFFFFFFF;
assign dcache_wdata = rs2_data_w1_i & wdata_mask;

// Load数据格式化 - 寄存化dcache_data_out和size，打破长组合路径
reg [2:0]            load_size_r;
reg [DATA_WIDTH-1:0] load_data_raw_r;

always @(posedge clk) begin
    load_size_r   <= dcache_size;
    load_data_raw_r <= dcache_data_out;
end

wire [DATA_WIDTH-1:0] load_data =
    (load_size_r == 3'b000) ? {{56{load_data_raw_r[7]}},  load_data_raw_r[7:0]}  :
    (load_size_r == 3'b001) ? {{48{load_data_raw_r[15]}}, load_data_raw_r[15:0]} :
    (load_size_r == 3'b010) ? {{32{load_data_raw_r[31]}}, load_data_raw_r[31:0]} :
    (load_size_r == 3'b011) ? load_data_raw_r :
    (load_size_r == 3'b100) ? {56'b0, load_data_raw_r[7:0]}  :
    (load_size_r == 3'b101) ? {48'b0, load_data_raw_r[15:0]} :
    (load_size_r == 3'b110) ? {32'b0, load_data_raw_r[31:0]} :
    load_data_raw_r;

// 流水线寄存器更新逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        alu_result_w1_o <= 64'b0;
        mem_result_w1_o <= 64'b0;
        rd_addr_w1_o <= 5'b0;
        valid_w1_o <= 1'b0;
        reg_write_en_w1_o <= 1'b0;
        wb_sel_w1_o <= 2'b0;
        alu_result_w2_o <= 64'b0;
        rd_addr_w2_o <= 5'b0;
        valid_w2_o <= 1'b0;
        reg_write_en_w2_o <= 1'b0;
        wb_sel_w2_o <= 2'b0;
    end else begin
        alu_result_w1_o <= alu_result_w1_i;
        mem_result_w1_o <= load_data;
        rd_addr_w1_o <= rd_addr_w1_i;
        valid_w1_o <= valid_w1_i;
        reg_write_en_w1_o <= reg_write_en_w1_i;
        wb_sel_w1_o <= wb_sel_w1_i;
        alu_result_w2_o <= alu_result_w2_i;
        rd_addr_w2_o <= rd_addr_w2_i;
        valid_w2_o <= valid_w2_i;
        reg_write_en_w2_o <= reg_write_en_w2_i;
        wb_sel_w2_o <= wb_sel_w2_i;
    end
end

endmodule