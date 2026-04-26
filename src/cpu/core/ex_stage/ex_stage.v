// ============================================================================
// EX Stage（执行阶段）- 内部 EX1/EX2 双寄存器流水线
// EX1: 前递选择 + 操作数选择 → 流水线寄存器
// EX2: ALU + 乘除法 + 分支判断 → EX/MEM 寄存器
// ============================================================================

module ex_stage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  flush,

    // ---- 来自 IIEX —— Way1 ----
    input  wire [ADDR_WIDTH-1:0] pc_w1_i,
    input  wire [4:0]            rs1_addr_w1_i,
    input  wire [4:0]            rs2_addr_w1_i,
    input  wire [DATA_WIDTH-1:0] rs1_data_w1_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_w1_i,
    input  wire [4:0]            rd_addr_w1_i,
    input  wire [DATA_WIDTH-1:0] imm_w1_i,
    input  wire [3:0]            alu_op_w1_i,
    input  wire                  alu_src1_sel_w1_i,
    input  wire                  alu_src2_sel_w1_i,
    input  wire                  mem_read_en_w1_i,
    input  wire                  mem_write_en_w1_i,
    input  wire [2:0]            mem_size_w1_i,
    input  wire                  reg_write_en_w1_i,
    input  wire [1:0]            wb_sel_w1_i,
    input  wire                  is_branch_w1_i,
    input  wire                  is_jump_w1_i,
    input  wire                  is_muldiv_w1_i,
    input  wire [2:0]            muldiv_funct3_w1_i,
    input  wire                  is_csr_w1_i,
    input  wire [11:0]           csr_addr_w1_i,
    input  wire [2:0]            funct3_w1_i,
    input  wire                  valid_w1_i,

    // ---- 来自 IIEX —— Way2 ----
    input  wire [ADDR_WIDTH-1:0] pc_w2_i,
    input  wire [4:0]            rs1_addr_w2_i,
    input  wire [4:0]            rs2_addr_w2_i,
    input  wire [DATA_WIDTH-1:0] rs1_data_w2_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_w2_i,
    input  wire [4:0]            rd_addr_w2_i,
    input  wire [DATA_WIDTH-1:0] imm_w2_i,
    input  wire [3:0]            alu_op_w2_i,
    input  wire                  alu_src1_sel_w2_i,
    input  wire                  alu_src2_sel_w2_i,
    input  wire                  mem_read_en_w2_i,
    input  wire                  mem_write_en_w2_i,
    input  wire [2:0]            mem_size_w2_i,
    input  wire                  reg_write_en_w2_i,
    input  wire [1:0]            wb_sel_w2_i,
    input  wire                  is_branch_w2_i,
    input  wire                  is_jump_w2_i,
    input  wire                  is_muldiv_w2_i,
    input  wire [2:0]            muldiv_funct3_w2_i,
    input  wire                  is_csr_w2_i,
    input  wire [11:0]           csr_addr_w2_i,
    input  wire [2:0]            funct3_w2_i,
    input  wire                  valid_w2_i,

    // ---- 前递数据：来自 EX/MEM 寄存器（上一周期 EX 结果）----
    input  wire [DATA_WIDTH-1:0] fwd_exmem_result_w1,
    input  wire [4:0]            fwd_exmem_rd_w1,
    input  wire                  fwd_exmem_we_w1,
    input  wire [DATA_WIDTH-1:0] fwd_exmem_result_w2,
    input  wire [4:0]            fwd_exmem_rd_w2,
    input  wire                  fwd_exmem_we_w2,

    // ---- 前递数据：来自 MEM/WB 寄存器 ----
    input  wire [DATA_WIDTH-1:0] fwd_memwb_result_w1,
    input  wire [4:0]            fwd_memwb_rd_w1,
    input  wire                  fwd_memwb_we_w1,
    input  wire [DATA_WIDTH-1:0] fwd_memwb_result_w2,
    input  wire [4:0]            fwd_memwb_rd_w2,
    input  wire                  fwd_memwb_we_w2,

    // ---- 分支预测输入 ----
    input  wire                  predict_taken_i,
    input  wire [ADDR_WIDTH-1:0] predict_target_i,

    // ---- EX/MEM 流水线寄存器 → MEM —— Way1 ----
    output reg  [ADDR_WIDTH-1:0] pc_w1_o,
    output reg  [DATA_WIDTH-1:0] alu_result_w1_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w1_o,
    output reg  [4:0]            rd_addr_w1_o,
    output reg                   mem_read_en_w1_o,
    output reg                   mem_write_en_w1_o,
    output reg  [2:0]            mem_size_w1_o,
    output reg                   reg_write_en_w1_o,
    output reg  [1:0]            wb_sel_w1_o,
    output reg                   valid_w1_o,

    // ---- EX/MEM 流水线寄存器 → MEM —— Way2 ----
    output reg  [ADDR_WIDTH-1:0] pc_w2_o,
    output reg  [DATA_WIDTH-1:0] alu_result_w2_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w2_o,
    output reg  [4:0]            rd_addr_w2_o,
    output reg                   mem_read_en_w2_o,
    output reg                   mem_write_en_w2_o,
    output reg  [2:0]            mem_size_w2_o,
    output reg                   reg_write_en_w2_o,
    output reg  [1:0]            wb_sel_w2_o,
    output reg                   valid_w2_o,

    // ---- 分支控制反馈 ----
    output reg                   branch_taken_o,
    output reg  [ADDR_WIDTH-1:0] branch_target_o,
    output reg                   mispredict_o,

    // ---- 乘除法停顿（用于流水线控制）----
    output wire                  muldiv_stall,

    // ---- 定时器中断（来自 CSR unit）----
    output wire                  irq_timer
);

// ============================================================
// 前递选择 - 并行独热比较，减少关键路径延迟
// 优先级: EX/MEM Way1 > EX/MEM Way2 > MEM/WB Way1 > MEM/WB Way2 > 原值
// ============================================================

// ---- Way1 rs1 前递匹配 ----
wire w1_rs1_match_ex1 = fwd_exmem_we_w1 & (fwd_exmem_rd_w1 != 5'b0) & (fwd_exmem_rd_w1 == rs1_addr_w1_i);
wire w1_rs1_match_ex2 = fwd_exmem_we_w2 & (fwd_exmem_rd_w2 != 5'b0) & (fwd_exmem_rd_w2 == rs1_addr_w1_i);
wire w1_rs1_match_m1  = fwd_memwb_we_w1 & (fwd_memwb_rd_w1  != 5'b0) & (fwd_memwb_rd_w1  == rs1_addr_w1_i);
wire w1_rs1_match_m2  = fwd_memwb_we_w2 & (fwd_memwb_rd_w2  != 5'b0) & (fwd_memwb_rd_w2  == rs1_addr_w1_i);

// ---- Way1 rs2 前递匹配 ----
wire w1_rs2_match_ex1 = fwd_exmem_we_w1 & (fwd_exmem_rd_w1 != 5'b0) & (fwd_exmem_rd_w1 == rs2_addr_w1_i);
wire w1_rs2_match_ex2 = fwd_exmem_we_w2 & (fwd_exmem_rd_w2 != 5'b0) & (fwd_exmem_rd_w2 == rs2_addr_w1_i);
wire w1_rs2_match_m1  = fwd_memwb_we_w1 & (fwd_memwb_rd_w1  != 5'b0) & (fwd_memwb_rd_w1  == rs2_addr_w1_i);
wire w1_rs2_match_m2  = fwd_memwb_we_w2 & (fwd_memwb_rd_w2  != 5'b0) & (fwd_memwb_rd_w2  == rs2_addr_w1_i);

// ---- Way2 rs1 前递匹配 ----
wire w2_rs1_match_ex1 = fwd_exmem_we_w1 & (fwd_exmem_rd_w1 != 5'b0) & (fwd_exmem_rd_w1 == rs1_addr_w2_i);
wire w2_rs1_match_ex2 = fwd_exmem_we_w2 & (fwd_exmem_rd_w2 != 5'b0) & (fwd_exmem_rd_w2 == rs1_addr_w2_i);
wire w2_rs1_match_m1  = fwd_memwb_we_w1 & (fwd_memwb_rd_w1  != 5'b0) & (fwd_memwb_rd_w1  == rs1_addr_w2_i);
wire w2_rs1_match_m2  = fwd_memwb_we_w2 & (fwd_memwb_rd_w2  != 5'b0) & (fwd_memwb_rd_w2  == rs1_addr_w2_i);

// ---- Way2 rs2 前递匹配 ----
wire w2_rs2_match_ex1 = fwd_exmem_we_w1 & (fwd_exmem_rd_w1 != 5'b0) & (fwd_exmem_rd_w1 == rs2_addr_w2_i);
wire w2_rs2_match_ex2 = fwd_exmem_we_w2 & (fwd_exmem_rd_w2 != 5'b0) & (fwd_exmem_rd_w2 == rs2_addr_w2_i);
wire w2_rs2_match_m1  = fwd_memwb_we_w1 & (fwd_memwb_rd_w1  != 5'b0) & (fwd_memwb_rd_w1  == rs2_addr_w2_i);
wire w2_rs2_match_m2  = fwd_memwb_we_w2 & (fwd_memwb_rd_w2  != 5'b0) & (fwd_memwb_rd_w2  == rs2_addr_w2_i);

// ---- 前递数据选择（优先级编码MUX）----
// 优先级: EX1 > EX2 > MEM1 > MEM2 > 原值
wire [DATA_WIDTH-1:0] rs1_w1_fwd =
    w1_rs1_match_ex1 ? fwd_exmem_result_w1 :
    w1_rs1_match_ex2 ? fwd_exmem_result_w2 :
    w1_rs1_match_m1  ? fwd_memwb_result_w1 :
    w1_rs1_match_m2  ? fwd_memwb_result_w2 :
    rs1_data_w1_i;

wire [DATA_WIDTH-1:0] rs2_w1_fwd =
    w1_rs2_match_ex1 ? fwd_exmem_result_w1 :
    w1_rs2_match_ex2 ? fwd_exmem_result_w2 :
    w1_rs2_match_m1  ? fwd_memwb_result_w1 :
    w1_rs2_match_m2  ? fwd_memwb_result_w2 :
    rs2_data_w1_i;

wire [DATA_WIDTH-1:0] rs1_w2_fwd =
    w2_rs1_match_ex1 ? fwd_exmem_result_w1 :
    w2_rs1_match_ex2 ? fwd_exmem_result_w2 :
    w2_rs1_match_m1  ? fwd_memwb_result_w1 :
    w2_rs1_match_m2  ? fwd_memwb_result_w2 :
    rs1_data_w2_i;

wire [DATA_WIDTH-1:0] rs2_w2_fwd =
    w2_rs2_match_ex1 ? fwd_exmem_result_w1 :
    w2_rs2_match_ex2 ? fwd_exmem_result_w2 :
    w2_rs2_match_m1  ? fwd_memwb_result_w1 :
    w2_rs2_match_m2  ? fwd_memwb_result_w2 :
    rs2_data_w2_i;

// ALU 操作数选择（PC 选择 or 寄存器）
wire [DATA_WIDTH-1:0] opA_w1 = alu_src1_sel_w1_i ? pc_w1_i  : rs1_w1_fwd;
wire [DATA_WIDTH-1:0] opB_w1 = alu_src2_sel_w1_i ? imm_w1_i : rs2_w1_fwd;

wire [DATA_WIDTH-1:0] opA_w2 = alu_src1_sel_w2_i ? pc_w2_i  : rs1_w2_fwd;
wire [DATA_WIDTH-1:0] opB_w2 = alu_src2_sel_w2_i ? imm_w2_i : rs2_w2_fwd;

// ============================================================
// Pipeline Register (Stage 1 → Stage 2): 注册ALU操作数，打破长组合路径
// ============================================================
reg [DATA_WIDTH-1:0] ex1_opA_w1, ex1_opB_w1;
reg [DATA_WIDTH-1:0] ex1_opA_w2, ex1_opB_w2;
reg [DATA_WIDTH-1:0] ex1_rs2_w1, ex1_rs2_w2;
reg [ADDR_WIDTH-1:0] ex1_pc_w1, ex1_pc_w2;
reg [DATA_WIDTH-1:0] ex1_imm_w1;
reg [4:0] ex1_rd_w1, ex1_rd_w2;
reg [3:0] ex1_alu_op_w1, ex1_alu_op_w2;
reg ex1_is_muldiv_w1, ex1_is_muldiv_w2;
reg [2:0] ex1_muldiv_f3_w1, ex1_muldiv_f3_w2;
reg ex1_is_branch_w1, ex1_is_jump_w1;
reg ex1_is_csr_w1, ex1_is_csr_w2;
reg [11:0] ex1_csr_addr_w1, ex1_csr_addr_w2;
reg [2:0] ex1_funct3_w1, ex1_funct3_w2;
reg ex1_valid_w1, ex1_valid_w2;
reg [2:0] ex1_mem_sz_w1, ex1_mem_sz_w2;
reg ex1_mem_r_w1, ex1_mem_w_w1;
reg ex1_mem_r_w2, ex1_mem_w_w2;
reg ex1_reg_wr_w1, ex1_reg_wr_w2;
reg [1:0] ex1_wb_sel_w1, ex1_wb_sel_w2;
reg ex1_predict_taken;
reg [ADDR_WIDTH-1:0] ex1_predict_target;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        ex1_opA_w1 <= 64'b0; ex1_opB_w1 <= 64'b0;
        ex1_opA_w2 <= 64'b0; ex1_opB_w2 <= 64'b0;
        ex1_rs2_w1 <= 64'b0; ex1_rs2_w2 <= 64'b0;
        ex1_pc_w1 <= 64'b0; ex1_pc_w2 <= 64'b0;
        ex1_imm_w1 <= 64'b0;
        ex1_rd_w1 <= 5'b0; ex1_rd_w2 <= 5'b0;
        ex1_alu_op_w1 <= 4'b0; ex1_alu_op_w2 <= 4'b0;
        ex1_is_muldiv_w1 <= 1'b0; ex1_is_muldiv_w2 <= 1'b0;
        ex1_muldiv_f3_w1 <= 3'b0; ex1_muldiv_f3_w2 <= 3'b0;
        ex1_is_branch_w1 <= 1'b0; ex1_is_jump_w1 <= 1'b0;
        ex1_is_csr_w1 <= 1'b0; ex1_is_csr_w2 <= 1'b0;
        ex1_csr_addr_w1 <= 12'b0; ex1_csr_addr_w2 <= 12'b0;
        ex1_funct3_w1 <= 3'b0; ex1_funct3_w2 <= 3'b0;
        ex1_valid_w1 <= 1'b0; ex1_valid_w2 <= 1'b0;
        ex1_mem_sz_w1 <= 3'b0; ex1_mem_sz_w2 <= 3'b0;
        ex1_mem_r_w1 <= 1'b0; ex1_mem_w_w1 <= 1'b0;
        ex1_mem_r_w2 <= 1'b0; ex1_mem_w_w2 <= 1'b0;
        ex1_reg_wr_w1 <= 1'b0; ex1_reg_wr_w2 <= 1'b0;
        ex1_wb_sel_w1 <= 2'b0; ex1_wb_sel_w2 <= 2'b0;
        ex1_predict_taken <= 1'b0;
        ex1_predict_target <= 64'b0;
    end else if (!muldiv_stall) begin
        ex1_opA_w1 <= opA_w1; ex1_opB_w1 <= opB_w1;
        ex1_opA_w2 <= opA_w2; ex1_opB_w2 <= opB_w2;
        ex1_rs2_w1 <= rs2_w1_fwd; ex1_rs2_w2 <= rs2_w2_fwd;
        ex1_pc_w1 <= pc_w1_i; ex1_pc_w2 <= pc_w2_i;
        ex1_imm_w1 <= imm_w1_i;
        ex1_rd_w1 <= rd_addr_w1_i; ex1_rd_w2 <= rd_addr_w2_i;
        ex1_alu_op_w1 <= alu_op_w1_i; ex1_alu_op_w2 <= alu_op_w2_i;
        ex1_is_muldiv_w1 <= is_muldiv_w1_i; ex1_is_muldiv_w2 <= is_muldiv_w2_i;
        ex1_muldiv_f3_w1 <= muldiv_funct3_w1_i; ex1_muldiv_f3_w2 <= muldiv_funct3_w2_i;
        ex1_is_branch_w1 <= is_branch_w1_i; ex1_is_jump_w1 <= is_jump_w1_i;
        ex1_is_csr_w1 <= is_csr_w1_i; ex1_csr_addr_w1 <= csr_addr_w1_i; ex1_funct3_w1 <= funct3_w1_i;
        ex1_is_csr_w2 <= is_csr_w2_i; ex1_csr_addr_w2 <= csr_addr_w2_i; ex1_funct3_w2 <= funct3_w2_i;
        ex1_valid_w1 <= valid_w1_i; ex1_valid_w2 <= valid_w2_i;
        ex1_mem_sz_w1 <= mem_size_w1_i; ex1_mem_sz_w2 <= mem_size_w2_i;
        ex1_mem_r_w1 <= mem_read_en_w1_i; ex1_mem_w_w1 <= mem_write_en_w1_i;
        ex1_mem_r_w2 <= mem_read_en_w2_i; ex1_mem_w_w2 <= mem_write_en_w2_i;
        ex1_reg_wr_w1 <= reg_write_en_w1_i; ex1_reg_wr_w2 <= reg_write_en_w2_i;
        ex1_wb_sel_w1 <= wb_sel_w1_i; ex1_wb_sel_w2 <= wb_sel_w2_i;
        ex1_predict_taken <= predict_taken_i;
        ex1_predict_target <= predict_target_i;
    end
end

// ============================================================
// Stage 2: ALU + Muldiv Unit + Branch（基于已注册的操作数）
// ============================================================

// ALU1 & ALU2（组合实例化）
wire [DATA_WIDTH-1:0] alu_res_w1, alu_res_w2;
wire alu_zero_w1, alu_neg_w1, alu_ovf_w1;
wire alu_zero_w2, alu_neg_w2, alu_ovf_w2;

alu u_alu1 (
    .alu_op(ex1_alu_op_w1), .operand_a(ex1_opA_w1), .operand_b(ex1_opB_w1),
    .result(alu_res_w1), .zero(alu_zero_w1),
    .negative(alu_neg_w1), .overflow(alu_ovf_w1)
);

alu u_alu2 (
    .alu_op(ex1_alu_op_w2), .operand_a(ex1_opA_w2), .operand_b(ex1_opB_w2),
    .result(alu_res_w2), .zero(alu_zero_w2),
    .negative(alu_neg_w2), .overflow(alu_ovf_w2)
);

// ---- 乘除法多周期单元 ----
reg muldiv_active_w1, muldiv_active_w2;
wire [DATA_WIDTH-1:0] muldiv_res_w1, muldiv_res_w2;
wire muldiv_done_w1, muldiv_done_w2;

muldiv_unit u_muldiv1 (
    .clk(clk), .rst_n(rst_n),
    .start(ex1_valid_w1 && ex1_is_muldiv_w1 && !muldiv_active_w1),
    .funct3(ex1_muldiv_f3_w1), .operand_a(ex1_opA_w1), .operand_b(ex1_opB_w1),
    .result(muldiv_res_w1), .done(muldiv_done_w1)
);

muldiv_unit u_muldiv2 (
    .clk(clk), .rst_n(rst_n),
    .start(ex1_valid_w2 && ex1_is_muldiv_w2 && !muldiv_active_w2),
    .funct3(ex1_muldiv_f3_w2), .operand_a(ex1_opA_w2), .operand_b(ex1_opB_w2),
    .result(muldiv_res_w2), .done(muldiv_done_w2)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        muldiv_active_w1 <= 1'b0;
        muldiv_active_w2 <= 1'b0;
    end else begin
        if (!muldiv_active_w1 && ex1_valid_w1 && ex1_is_muldiv_w1)
            muldiv_active_w1 <= 1'b1;
        else if (muldiv_done_w1)
            muldiv_active_w1 <= 1'b0;
        if (!muldiv_active_w2 && ex1_valid_w2 && ex1_is_muldiv_w2)
            muldiv_active_w2 <= 1'b1;
        else if (muldiv_done_w2)
            muldiv_active_w2 <= 1'b0;
    end
end

assign muldiv_stall = muldiv_active_w1 || muldiv_active_w2;
assign irq_timer = irq_timer_ex;

// ---- CSR 单元（含 mcycle/mtime/mtimecmp）----
wire [DATA_WIDTH-1:0] csr_rdata_w1;
wire irq_timer_ex;

csr_unit #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_csr_unit (
    .clk(clk), .rst_n(rst_n),
    .csr_addr(ex1_csr_addr_w1),
    .csr_wdata(ex1_opA_w1),
    .csr_we(ex1_is_csr_w1 && ex1_funct3_w1[2] && (ex1_funct3_w1[1:0] == 2'b01 || ex1_rs2_w1 != 64'b0)),
    .csr_re(ex1_is_csr_w1),
    .funct3(ex1_funct3_w1),
    .csr_rdata(csr_rdata_w1),
    .irq_timer(irq_timer_ex),
    .irq_external(),
    .irq_software(),
    .exception_valid(1'b0),
    .exception_code(4'b0),
    .exception_pc(64'b0),
    .exception_value(64'b0)
);

// ---- 分支判断（仅 Way1 主路含分支；II 阶段已阻止 Way2 含分支）----
reg branch_taken_w1;
reg [ADDR_WIDTH-1:0] branch_tgt_w1;

always @(*) begin
    branch_taken_w1 = 1'b0;
    branch_tgt_w1   = ex1_pc_w1 + 4;

    if (ex1_valid_w1) begin
        if (ex1_is_branch_w1) begin
            case (ex1_mem_sz_w1)
                3'b000: branch_taken_w1 = (ex1_opA_w1 == ex1_opB_w1);
                3'b001: branch_taken_w1 = (ex1_opA_w1 != ex1_opB_w1);
                3'b100: branch_taken_w1 = ($signed(ex1_opA_w1) < $signed(ex1_opB_w1));
                3'b101: branch_taken_w1 = ($signed(ex1_opA_w1) >= $signed(ex1_opB_w1));
                3'b110: branch_taken_w1 = (ex1_opA_w1 < ex1_opB_w1);
                3'b111: branch_taken_w1 = (ex1_opA_w1 >= ex1_opB_w1);
                default: branch_taken_w1 = 1'b0;
            endcase
            branch_tgt_w1 = ex1_pc_w1 + ex1_imm_w1;
        end else if (ex1_is_jump_w1) begin
            branch_taken_w1 = 1'b1;
            branch_tgt_w1 = (ex1_alu_op_w1 == 4'b1100) ?
                             (ex1_pc_w1 + ex1_imm_w1) : (ex1_opA_w1 + ex1_imm_w1);
        end
    end
end

// ---- EX/MEM 流水线寄存器锁存 ----
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        valid_w1_o     <= 1'b0; valid_w2_o     <= 1'b0;
        pc_w1_o        <= 64'b0; pc_w2_o       <= 64'b0;
        alu_result_w1_o <= 64'b0; alu_result_w2_o <= 64'b0;
        rs2_data_w1_o  <= 64'b0; rs2_data_w2_o  <= 64'b0;
        rd_addr_w1_o   <= 5'b0;  rd_addr_w2_o   <= 5'b0;
        mem_read_en_w1_o  <= 1'b0; mem_write_en_w1_o  <= 1'b0; mem_size_w1_o <= 3'b0;
        mem_read_en_w2_o  <= 1'b0; mem_write_en_w2_o  <= 1'b0; mem_size_w2_o <= 3'b0;
        reg_write_en_w1_o <= 1'b0; wb_sel_w1_o <= 2'b0;
        reg_write_en_w2_o <= 1'b0; wb_sel_w2_o <= 2'b0;
        branch_taken_o <= 1'b0; branch_target_o <= 64'b0; mispredict_o <= 1'b0;
    end else begin
        // 乘除法结果写回（完成时捕获）
        if (muldiv_done_w1) begin
            valid_w1_o        <= ex1_valid_w1;
            pc_w1_o           <= ex1_pc_w1;
            alu_result_w1_o   <= muldiv_res_w1;
            rs2_data_w1_o     <= ex1_rs2_w1;
            rd_addr_w1_o      <= ex1_rd_w1;
            mem_read_en_w1_o  <= ex1_mem_r_w1;
            mem_write_en_w1_o <= ex1_mem_w_w1;
            mem_size_w1_o     <= ex1_mem_sz_w1;
            reg_write_en_w1_o <= ex1_reg_wr_w1;
            wb_sel_w1_o       <= ex1_wb_sel_w1;
        end
        if (muldiv_done_w2) begin
            valid_w2_o        <= ex1_valid_w2;
            pc_w2_o           <= ex1_pc_w2;
            alu_result_w2_o   <= muldiv_res_w2;
            rs2_data_w2_o     <= ex1_rs2_w2;
            rd_addr_w2_o      <= ex1_rd_w2;
            mem_read_en_w2_o  <= ex1_mem_r_w2;
            mem_write_en_w2_o <= ex1_mem_w_w2;
            mem_size_w2_o     <= ex1_mem_sz_w2;
            reg_write_en_w2_o <= ex1_reg_wr_w2;
            wb_sel_w2_o       <= ex1_wb_sel_w2;
        end
        // 非乘除法/CSR指令正常更新
        if (!muldiv_active_w1 && !muldiv_active_w2 &&
            !(ex1_valid_w1 && ex1_is_muldiv_w1) &&
            !(ex1_valid_w2 && ex1_is_muldiv_w2)) begin
            // Way1
            valid_w1_o        <= ex1_valid_w1;
            pc_w1_o           <= ex1_pc_w1;
            alu_result_w1_o   <= ex1_is_csr_w1 ? csr_rdata_w1 : alu_res_w1;
            rs2_data_w1_o     <= ex1_rs2_w1;
            rd_addr_w1_o      <= ex1_rd_w1;
            mem_read_en_w1_o  <= ex1_mem_r_w1;
            mem_write_en_w1_o <= ex1_mem_w_w1;
            mem_size_w1_o     <= ex1_mem_sz_w1;
            reg_write_en_w1_o <= ex1_reg_wr_w1;
            wb_sel_w1_o       <= ex1_wb_sel_w1;
            // Way2
            valid_w2_o        <= ex1_valid_w2;
            pc_w2_o           <= ex1_pc_w2;
            alu_result_w2_o   <= ex1_is_csr_w2 ? csr_rdata_w1 : alu_res_w2;
            rs2_data_w2_o     <= ex1_rs2_w2;
            rd_addr_w2_o      <= ex1_rd_w2;
            mem_read_en_w2_o  <= ex1_mem_r_w2;
            mem_write_en_w2_o <= ex1_mem_w_w2;
            mem_size_w2_o     <= ex1_mem_sz_w2;
            reg_write_en_w2_o <= ex1_reg_wr_w2;
            wb_sel_w2_o       <= ex1_wb_sel_w2;
            // 分支
            branch_taken_o  <= branch_taken_w1;
            branch_target_o <= branch_tgt_w1;
            if (ex1_valid_w1 && (ex1_is_branch_w1 || ex1_is_jump_w1)) begin
                mispredict_o <= (branch_taken_w1 != ex1_predict_taken) ||
                                (branch_taken_w1 && (branch_tgt_w1 != ex1_predict_target));
            end else begin
                mispredict_o <= 1'b0;
            end
        end
    end
end

endmodule