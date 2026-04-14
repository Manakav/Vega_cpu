// ============================================================================
// Hazard Unit（冒险处理单元）- 6级流水线双发射版本
// 检测数据冒险、Load-Use 冒险、控制冒险，生成 stall 与 flush 信号
// ============================================================================

module hazard_unit (
    input  wire                  clk,
    input  wire                  rst_n,

    // ---- II 阶段（IDII 寄存器）源/目的寄存器 ----
    // Way1
    input  wire [4:0]            rs1_addr_id_w1,
    input  wire [4:0]            rs2_addr_id_w1,
    input  wire                  rs1_used_id_w1,
    input  wire                  rs2_used_id_w1,
    // Way2
    input  wire [4:0]            rs1_addr_id_w2,
    input  wire [4:0]            rs2_addr_id_w2,
    input  wire                  rs1_used_id_w2,
    input  wire                  rs2_used_id_w2,

    // ---- EX 阶段（IIEX 寄存器）目的寄存器 ----
    input  wire [4:0]            rd_addr_ex_w1,
    input  wire                  reg_write_en_ex_w1,
    input  wire                  mem_read_en_ex_w1,  // Load-Use 检测
    input  wire [4:0]            rd_addr_ex_w2,
    input  wire                  reg_write_en_ex_w2,
    input  wire                  mem_read_en_ex_w2,

    // ---- MEM 阶段目的寄存器（用于扩展前递覆盖判断）----
    input  wire [4:0]            rd_addr_mem_w1,
    input  wire                  reg_write_en_mem_w1,
    input  wire [4:0]            rd_addr_mem_w2,
    input  wire                  reg_write_en_mem_w2,

    // ---- 分支/误预测信号（来自 EX 阶段）----
    input  wire                  branch_taken_ex,
    input  wire                  mispredict_ex,

    // ---- II 阶段双发射停顿请求 ----
    input  wire                  stall_dual,

    // ---- 流水线控制输出 ----
    output reg                   stall_if,
    output reg                   stall_id,
    output reg                   flush_if,
    output reg                   flush_id,
    output reg                   flush_ex,
    
    // 添加DCache停顿输入
    input  wire                  dcache_stall
);

// Load-Use 冒险检测：若 EX 级正在执行 Load，且 IDII 的源依赖其目的，必须停顿一周期
wire lu_w1_w1 = mem_read_en_ex_w1 && rs1_used_id_w1 && (rs1_addr_id_w1 == rd_addr_ex_w1);
wire lu_w1_w2 = mem_read_en_ex_w1 && rs2_used_id_w1 && (rs2_addr_id_w1 == rd_addr_ex_w1);
wire lu_w2_w1 = mem_read_en_ex_w2 && rs1_used_id_w1 && (rs1_addr_id_w1 == rd_addr_ex_w2);
wire lu_w2_w2 = mem_read_en_ex_w2 && rs2_used_id_w1 && (rs2_addr_id_w1 == rd_addr_ex_w2);
// Way2 指令也需检测 Load-Use
wire lu_w1_w1b = mem_read_en_ex_w1 && rs1_used_id_w2 && (rs1_addr_id_w2 == rd_addr_ex_w1);
wire lu_w1_w2b = mem_read_en_ex_w1 && rs2_used_id_w2 && (rs2_addr_id_w2 == rd_addr_ex_w1);
wire lu_w2_w1b = mem_read_en_ex_w2 && rs1_used_id_w2 && (rs1_addr_id_w2 == rd_addr_ex_w2);
wire lu_w2_w2b = mem_read_en_ex_w2 && rs2_used_id_w2 && (rs2_addr_id_w2 == rd_addr_ex_w2);

wire load_use_hazard = lu_w1_w1 || lu_w1_w2 || lu_w2_w1 || lu_w2_w2 ||
                       lu_w1_w1b || lu_w1_w2b || lu_w2_w1b || lu_w2_w2b;



// 修改停顿信号生成
always @(*) begin
    flush_if = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;
    stall_if = 1'b0;
    stall_id = 1'b0;
    if (mispredict_ex) begin
        flush_if = 1'b1;
        flush_id = 1'b1;
        flush_ex = 1'b1;
    end else if (dcache_stall) begin
        // DCache缺失：停顿IF和ID
        stall_if = 1'b1;
        stall_id = 1'b1;
    end else if (load_use_hazard) begin
        stall_if = 1'b1;
        stall_id = 1'b1;
    end else if (stall_dual) begin
        stall_if = 1'b1;
        stall_id = 1'b1;
    end
end

endmodule