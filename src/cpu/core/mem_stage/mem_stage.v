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
    output reg  [1:0]            wb_sel_w2_o
);

wire [2:0] size = mem_size_w1_i;

// Way1 内存地址、写使能、字节使能、写数据
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

// Load 数据格式化（符号/零扩展）
wire [DATA_WIDTH-1:0] load_data =
    (size == 3'b000) ? {{56{mem_rdata[7]}},  mem_rdata[7:0]}  :
    (size == 3'b001) ? {{48{mem_rdata[15]}}, mem_rdata[15:0]} :
    (size == 3'b010) ? {{32{mem_rdata[31]}}, mem_rdata[31:0]} :
    (size == 3'b011) ? mem_rdata :
    (size == 3'b100) ? {56'b0, mem_rdata[7:0]}  :
    (size == 3'b101) ? {48'b0, mem_rdata[15:0]} :
    (size == 3'b110) ? {32'b0, mem_rdata[31:0]} : mem_rdata;

// ---- MEM/WB 流水线寄存器 ----
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_w1_o       <= 1'b0; valid_w2_o       <= 1'b0;
        alu_result_w1_o  <= 64'b0; alu_result_w2_o <= 64'b0;
        mem_result_w1_o  <= 64'b0;
        rd_addr_w1_o     <= 5'b0;  rd_addr_w2_o    <= 5'b0;
        reg_write_en_w1_o <= 1'b0; wb_sel_w1_o     <= 2'b0;
        reg_write_en_w2_o <= 1'b0; wb_sel_w2_o     <= 2'b0;
    end else begin
        // Way1
        alu_result_w1_o   <= alu_result_w1_i;
        rd_addr_w1_o      <= rd_addr_w1_i;
        valid_w1_o        <= valid_w1_i;
        reg_write_en_w1_o <= reg_write_en_w1_i;
        wb_sel_w1_o       <= wb_sel_w1_i;

        if (mem_read_en_w1_i && mem_gnt)
            mem_result_w1_o <= load_data;
        else
            mem_result_w1_o <= 64'b0;

        // Way2（透传，无访存）
        alu_result_w2_o   <= alu_result_w2_i;
        rd_addr_w2_o      <= rd_addr_w2_i;
        valid_w2_o        <= valid_w2_i;
        reg_write_en_w2_o <= reg_write_en_w2_i;
        wb_sel_w2_o       <= wb_sel_w2_i;
    end
end

endmodule
