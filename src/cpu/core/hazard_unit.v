// ============================================================================
// Hazard Unit（冒险处理单元）- 6级流水线双发射版本（EX 内部分为 EX1/EX2）
// 检测数据冒险、Load-Use 冒险、控制冒险，生成 stall 与 flush 信号
// EX 分两段 → Load-Use 停顿需延长为 2 个周期
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
    input  wire                  mem_read_en_ex_w1,  // Load-Use 检测
    input  wire [4:0]            rd_addr_ex_w2,
    input  wire                  mem_read_en_ex_w2,

    // ---- 分支/误预测信号（来自 EX 阶段）----
    input  wire                  mispredict_ex,

    // ---- II 阶段双发射停顿请求 ----
    input  wire                  stall_dual,

    // ---- 乘除法停顿（来自 EX 阶段）----
    input  wire                  muldiv_stall,

    // ---- 流水线控制输出 ----
    output reg                   stall_if,
    output reg                   stall_id,
    output reg                   flush_if,
    output reg                   flush_id,
    output reg                   flush_ex,
    
    // 添加DCache停顿输入
    input  wire                  dcache_stall
);

// Load-Use 冒险检测：若 EX 级正在执行 Load，且 IDII 的源依赖其目的，必须停顿二周期（EX 含 EX1+EX2）
wire lu_w1_w1 = mem_read_en_ex_w1 && rs1_used_id_w1 && (rs1_addr_id_w1 == rd_addr_ex_w1);
wire lu_w1_w2 = mem_read_en_ex_w1 && rs2_used_id_w1 && (rs2_addr_id_w1 == rd_addr_ex_w1);
wire lu_w2_w1 = mem_read_en_ex_w2 && rs1_used_id_w1 && (rs1_addr_id_w1 == rd_addr_ex_w2);
wire lu_w2_w2 = mem_read_en_ex_w2 && rs2_used_id_w1 && (rs2_addr_id_w1 == rd_addr_ex_w2);
// Way2 指令也需检测 Load-Use
wire lu_w1_w1b = mem_read_en_ex_w1 && rs1_used_id_w2 && (rs1_addr_id_w2 == rd_addr_ex_w1);
wire lu_w1_w2b = mem_read_en_ex_w1 && rs2_used_id_w2 && (rs2_addr_id_w2 == rd_addr_ex_w1);
wire lu_w2_w1b = mem_read_en_ex_w2 && rs1_used_id_w2 && (rs1_addr_id_w2 == rd_addr_ex_w2);
wire lu_w2_w2b = mem_read_en_ex_w2 && rs2_used_id_w2 && (rs2_addr_id_w2 == rd_addr_ex_w2);

wire load_use_hazard_new = lu_w1_w1 || lu_w1_w2 || lu_w2_w1 || lu_w2_w2 ||
                           lu_w1_w1b || lu_w1_w2b || lu_w2_w1b || lu_w2_w2b;

// Load-Use 停顿延长：EX 现分 EX1/EX2 两段，需在 Load 离开 IIEX 后额外停顿一个周期
reg load_in_ex1;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || mispredict_ex)
        load_in_ex1 <= 1'b0;
    else
        load_in_ex1 <= load_use_hazard_new;
end

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
    end else if (muldiv_stall) begin
        // 乘除法停顿：停顿 IF 和 ID，等待乘除法完成
        stall_if = 1'b1;
        stall_id = 1'b1;
    end else if (load_use_hazard_new || load_in_ex1) begin
        stall_if = 1'b1;
        stall_id = 1'b1;
    end else if (stall_dual) begin
        stall_if = 1'b1;
        stall_id = 1'b1;
    end
end

endmodule