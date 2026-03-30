// ============================================================================
// II Stage（发射阶段）- 6级流水线双发射版本
// 功能：读寄存器堆（4读口）、双发射依赖检测、生成 IIEX 流水线寄存器
// ============================================================================

module ii_stage #(
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  flush,

    // ---- IDII 输入 —— Way1 ----
    input  wire [ADDR_WIDTH-1:0] pc_w1_i,
    input  wire [4:0]            rs1_addr_w1_i,
    input  wire [4:0]            rs2_addr_w1_i,
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
    input  wire                  is_system_w1_i,
    input  wire                  is_mem_op_w1_i,
    input  wire                  is_muldiv_w1_i,
    input  wire [2:0]            muldiv_funct3_w1_i,
    input  wire                  uses_rs1_w1_i,
    input  wire                  uses_rs2_w1_i,
    input  wire                  valid_w1_i,

    // ---- IDII 输入 —— Way2 ----
    input  wire [ADDR_WIDTH-1:0] pc_w2_i,
    input  wire [4:0]            rs1_addr_w2_i,
    input  wire [4:0]            rs2_addr_w2_i,
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
    input  wire                  is_system_w2_i,
    input  wire                  is_mem_op_w2_i,
    input  wire                  is_muldiv_w2_i,
    input  wire [2:0]            muldiv_funct3_w2_i,
    input  wire                  uses_rs1_w2_i,
    input  wire                  uses_rs2_w2_i,
    input  wire                  valid_w2_i,

    // ---- 寄存器堆读端口（4读口）----
    output wire [4:0]            rf_raddr1,
    input  wire [DATA_WIDTH-1:0] rf_rdata1,
    output wire [4:0]            rf_raddr2,
    input  wire [DATA_WIDTH-1:0] rf_rdata2,
    output wire [4:0]            rf_raddr3,
    input  wire [DATA_WIDTH-1:0] rf_rdata3,
    output wire [4:0]            rf_raddr4,
    input  wire [DATA_WIDTH-1:0] rf_rdata4,

    // ---- 向 hazard_unit 发出停顿请求 ----
    output wire                  stall_dual,

    // ---- IIEX 寄存器输出 → EX 阶段 —— Way1 ----
    output reg  [ADDR_WIDTH-1:0] pc_w1_o,
    output reg  [4:0]            rs1_addr_w1_o,   // 用于 EX 内前递地址比较
    output reg  [4:0]            rs2_addr_w1_o,
    output reg  [DATA_WIDTH-1:0] rs1_data_w1_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w1_o,
    output reg  [4:0]            rd_addr_w1_o,
    output reg  [DATA_WIDTH-1:0] imm_w1_o,
    output reg  [3:0]            alu_op_w1_o,
    output reg                   alu_src1_sel_w1_o,
    output reg                   alu_src2_sel_w1_o,
    output reg                   mem_read_en_w1_o,
    output reg                   mem_write_en_w1_o,
    output reg  [2:0]            mem_size_w1_o,
    output reg                   reg_write_en_w1_o,
    output reg  [1:0]            wb_sel_w1_o,
    output reg                   is_branch_w1_o,
    output reg                   is_jump_w1_o,
    output reg                   is_muldiv_w1_o,
    output reg  [2:0]            muldiv_funct3_w1_o,
    output reg                   valid_w1_o,

    // ---- IIEX 寄存器输出 → EX 阶段 —— Way2 ----
    output reg  [ADDR_WIDTH-1:0] pc_w2_o,
    output reg  [4:0]            rs1_addr_w2_o,
    output reg  [4:0]            rs2_addr_w2_o,
    output reg  [DATA_WIDTH-1:0] rs1_data_w2_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w2_o,
    output reg  [4:0]            rd_addr_w2_o,
    output reg  [DATA_WIDTH-1:0] imm_w2_o,
    output reg  [3:0]            alu_op_w2_o,
    output reg                   alu_src1_sel_w2_o,
    output reg                   alu_src2_sel_w2_o,
    output reg                   mem_read_en_w2_o,
    output reg                   mem_write_en_w2_o,
    output reg  [2:0]            mem_size_w2_o,
    output reg                   reg_write_en_w2_o,
    output reg  [1:0]            wb_sel_w2_o,
    output reg                   is_branch_w2_o,
    output reg                   is_jump_w2_o,
    output reg                   is_muldiv_w2_o,
    output reg  [2:0]            muldiv_funct3_w2_o,
    output reg                   valid_w2_o
);

// ---- 寄存器堆地址直通 ----
assign rf_raddr1 = rs1_addr_w1_i;
assign rf_raddr2 = rs2_addr_w1_i;
assign rf_raddr3 = rs1_addr_w2_i;
assign rf_raddr4 = rs2_addr_w2_i;

// ---- 双发射阻断检测 ----
wire raw_hazard =
    valid_w1_i && valid_w2_i && reg_write_en_w1_i && (rd_addr_w1_i != 5'b0) &&
    ((uses_rs1_w2_i && rs1_addr_w2_i == rd_addr_w1_i) ||
     (uses_rs2_w2_i && rs2_addr_w2_i == rd_addr_w1_i));

wire waw_hazard =
    valid_w1_i && valid_w2_i &&
    reg_write_en_w1_i && reg_write_en_w2_i &&
    (rd_addr_w1_i != 5'b0) && (rd_addr_w1_i == rd_addr_w2_i);

wire struct_hazard = valid_w1_i && valid_w2_i && is_mem_op_w1_i && is_mem_op_w2_i;

wire ctrl_hazard   = valid_w1_i && (is_branch_w1_i || is_jump_w1_i);

wire sys_hazard    = valid_w1_i && valid_w2_i && (is_system_w1_i || is_system_w2_i);

wire can_dual_issue = !(raw_hazard || waw_hazard || struct_hazard ||
                        ctrl_hazard || sys_hazard);

// ---- issued_w1 标志 ----
reg issued_w1;

wire need_stall_dual = !issued_w1 && valid_w1_i && valid_w2_i && !can_dual_issue;
assign stall_dual    = need_stall_dual;

// 当 issued_w1=1 时，将 IDII.w2 作为主路发射
wire sel_w2_as_slot1 = issued_w1;

// 主路（slot1）数据
wire [ADDR_WIDTH-1:0] s1_pc         = sel_w2_as_slot1 ? pc_w2_i           : pc_w1_i;
wire [4:0]            s1_rs1_addr   = sel_w2_as_slot1 ? rs1_addr_w2_i     : rs1_addr_w1_i;
wire [4:0]            s1_rs2_addr   = sel_w2_as_slot1 ? rs2_addr_w2_i     : rs2_addr_w1_i;
wire [DATA_WIDTH-1:0] s1_rs1_data   = sel_w2_as_slot1 ? rf_rdata3         : rf_rdata1;
wire [DATA_WIDTH-1:0] s1_rs2_data   = sel_w2_as_slot1 ? rf_rdata4         : rf_rdata2;
wire [4:0]            s1_rd         = sel_w2_as_slot1 ? rd_addr_w2_i      : rd_addr_w1_i;
wire [DATA_WIDTH-1:0] s1_imm        = sel_w2_as_slot1 ? imm_w2_i          : imm_w1_i;
wire [3:0]            s1_alu_op     = sel_w2_as_slot1 ? alu_op_w2_i       : alu_op_w1_i;
wire                  s1_src1_sel   = sel_w2_as_slot1 ? alu_src1_sel_w2_i : alu_src1_sel_w1_i;
wire                  s1_src2_sel   = sel_w2_as_slot1 ? alu_src2_sel_w2_i : alu_src2_sel_w1_i;
wire                  s1_mem_r      = sel_w2_as_slot1 ? mem_read_en_w2_i  : mem_read_en_w1_i;
wire                  s1_mem_w      = sel_w2_as_slot1 ? mem_write_en_w2_i : mem_write_en_w1_i;
wire [2:0]            s1_mem_sz     = sel_w2_as_slot1 ? mem_size_w2_i     : mem_size_w1_i;
wire                  s1_reg_we     = sel_w2_as_slot1 ? reg_write_en_w2_i : reg_write_en_w1_i;
wire [1:0]            s1_wb_sel     = sel_w2_as_slot1 ? wb_sel_w2_i       : wb_sel_w1_i;
wire                  s1_is_branch  = sel_w2_as_slot1 ? is_branch_w2_i    : is_branch_w1_i;
wire                  s1_is_jump    = sel_w2_as_slot1 ? is_jump_w2_i      : is_jump_w1_i;
wire                  s1_is_muldiv  = sel_w2_as_slot1 ? is_muldiv_w2_i    : is_muldiv_w1_i;
wire [2:0]            s1_muldiv_f3  = sel_w2_as_slot1 ? muldiv_funct3_w2_i: muldiv_funct3_w1_i;
wire                  s1_valid      = sel_w2_as_slot1 ? valid_w2_i        : valid_w1_i;

// 副路（slot2）：仅在正常双发时有效
wire issue_slot2 = !issued_w1 && can_dual_issue && valid_w1_i && valid_w2_i;

// ---- issued_w1 更新 ----
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush)
        issued_w1 <= 1'b0;
    else
        issued_w1 <= need_stall_dual;
end

// ---- IIEX 寄存器锁存 ----
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        valid_w1_o <= 1'b0; valid_w2_o <= 1'b0;
        pc_w1_o <= 64'b0; pc_w2_o <= 64'b0;
        rs1_addr_w1_o <= 5'b0; rs2_addr_w1_o <= 5'b0;
        rs1_addr_w2_o <= 5'b0; rs2_addr_w2_o <= 5'b0;
        rs1_data_w1_o <= 64'b0; rs2_data_w1_o <= 64'b0;
        rs1_data_w2_o <= 64'b0; rs2_data_w2_o <= 64'b0;
        rd_addr_w1_o  <= 5'b0;  rd_addr_w2_o  <= 5'b0;
        imm_w1_o <= 64'b0; imm_w2_o <= 64'b0;
        alu_op_w1_o <= 4'b0; alu_op_w2_o <= 4'b0;
        alu_src1_sel_w1_o <= 1'b0; alu_src2_sel_w1_o <= 1'b0;
        alu_src1_sel_w2_o <= 1'b0; alu_src2_sel_w2_o <= 1'b0;
        mem_read_en_w1_o  <= 1'b0; mem_write_en_w1_o  <= 1'b0; mem_size_w1_o <= 3'b0;
        mem_read_en_w2_o  <= 1'b0; mem_write_en_w2_o  <= 1'b0; mem_size_w2_o <= 3'b0;
        reg_write_en_w1_o <= 1'b0; wb_sel_w1_o <= 2'b0;
        reg_write_en_w2_o <= 1'b0; wb_sel_w2_o <= 2'b0;
        is_branch_w1_o <= 1'b0; is_jump_w1_o <= 1'b0;
        is_branch_w2_o <= 1'b0; is_jump_w2_o <= 1'b0;
        is_muldiv_w1_o <= 1'b0; muldiv_funct3_w1_o <= 3'b0;
        is_muldiv_w2_o <= 1'b0; muldiv_funct3_w2_o <= 3'b0;
    end else begin
        // Slot1（主路）
        valid_w1_o        <= s1_valid;
        pc_w1_o           <= s1_pc;
        rs1_addr_w1_o     <= s1_rs1_addr;
        rs2_addr_w1_o     <= s1_rs2_addr;
        rs1_data_w1_o     <= s1_rs1_data;
        rs2_data_w1_o     <= s1_rs2_data;
        rd_addr_w1_o      <= s1_rd;
        imm_w1_o          <= s1_imm;
        alu_op_w1_o       <= s1_alu_op;
        alu_src1_sel_w1_o <= s1_src1_sel;
        alu_src2_sel_w1_o <= s1_src2_sel;
        mem_read_en_w1_o  <= s1_mem_r;
        mem_write_en_w1_o <= s1_mem_w;
        mem_size_w1_o     <= s1_mem_sz;
        reg_write_en_w1_o <= s1_reg_we;
        wb_sel_w1_o       <= s1_wb_sel;
        is_branch_w1_o    <= s1_is_branch;
        is_jump_w1_o      <= s1_is_jump;
        is_muldiv_w1_o    <= s1_is_muldiv;
        muldiv_funct3_w1_o<= s1_muldiv_f3;
        // Slot2（副路）
        valid_w2_o        <= issue_slot2;
        pc_w2_o           <= pc_w2_i;
        rs1_addr_w2_o     <= rs1_addr_w2_i;
        rs2_addr_w2_o     <= rs2_addr_w2_i;
        rs1_data_w2_o     <= rf_rdata3;
        rs2_data_w2_o     <= rf_rdata4;
        rd_addr_w2_o      <= rd_addr_w2_i;
        imm_w2_o          <= imm_w2_i;
        alu_op_w2_o       <= alu_op_w2_i;
        alu_src1_sel_w2_o <= alu_src1_sel_w2_i;
        alu_src2_sel_w2_o <= alu_src2_sel_w2_i;
        mem_read_en_w2_o  <= mem_read_en_w2_i  & issue_slot2;
        mem_write_en_w2_o <= mem_write_en_w2_i & issue_slot2;
        mem_size_w2_o     <= mem_size_w2_i;
        reg_write_en_w2_o <= reg_write_en_w2_i & issue_slot2;
        wb_sel_w2_o       <= wb_sel_w2_i;
        is_branch_w2_o    <= is_branch_w2_i & issue_slot2;
        is_jump_w2_o      <= is_jump_w2_i   & issue_slot2;
        is_muldiv_w2_o    <= is_muldiv_w2_i & issue_slot2;
        muldiv_funct3_w2_o<= muldiv_funct3_w2_i;
    end
end

endmodule
