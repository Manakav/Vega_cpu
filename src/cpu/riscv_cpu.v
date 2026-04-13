// ============================================================================
// RISC-V CPU 顶层模块 (RV64IMC) — 6级流水线双发射版本
// 流水线：IF → ID → II → EX → MEM → WB
// 每周期最多同时发射两条指令（Way1 主路 / Way2 副路）
// 保留 BTB+BHT 动态分支预测、icache/dcache 子模块接口不变
// ============================================================================

module riscv_cpu (
    input  wire                  clk,
    input  wire                  rst_n,

    // 指令存储器接口（双发射：同时提供两条连续指令）
    output wire [63:0]           instr_addr,      // Way1 取指地址（= PC）
    input  wire [31:0]           instr_data_w1,   // PC 处指令
    input  wire [31:0]           instr_data_w2,   // PC+4 处指令
    output wire                  instr_req,
    input  wire                  instr_gnt,

    // 数据存储器接口（仅 Way1 访存）
    output wire [63:0]           data_addr,
    output wire [63:0]           data_wdata,
    input  wire [63:0]           data_rdata,
    output wire                  data_req,
    output wire                  data_we,
    output wire [7:0]            data_be,
    input  wire                  data_gnt,

    // 中断接口
    input  wire                  irq_external,
    input  wire                  irq_timer,
    input  wire                  irq_software,

    // 调试接口
    input  wire                  debug_req,
    output wire                  debug_halt,
    output wire                  debug_resume
);

parameter DATA_WIDTH = 64;
parameter ADDR_WIDTH = 64;
parameter REG_COUNT  = 32;

// ============================================================
// 流水线控制信号
// ============================================================
wire stall_if, stall_id;
wire flush_if, flush_id, flush_ex;
wire stall_dual;
wire branch_taken, mispredict;
wire [ADDR_WIDTH-1:0] branch_target;

// ============================================================
// Stage 1 → Stage 2：IFID 寄存器（内置于 if_stage 输出寄存器）
// ============================================================
wire [ADDR_WIDTH-1:0] ifid_pc_w1,  ifid_pc_w2;
wire [31:0]           ifid_instr_w1, ifid_instr_w2;
wire                  ifid_valid_w1, ifid_valid_w2;

if_stage #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(32)
) u_if_stage (
    .clk(clk), .rst_n(rst_n),
    .stall(stall_if), .flush(flush_if),
    .instr_addr(instr_addr),
    .instr_data_w1(instr_data_w1),
    .instr_data_w2(instr_data_w2),
    .instr_req(instr_req), .instr_gnt(instr_gnt),
    .branch_taken(branch_taken),
    .branch_target(branch_target),
    .mispredict(mispredict),
    .pc_out_w1(ifid_pc_w1),    .instr_out_w1(ifid_instr_w1), .valid_out_w1(ifid_valid_w1),
    .pc_out_w2(ifid_pc_w2),    .instr_out_w2(ifid_instr_w2), .valid_out_w2(ifid_valid_w2)
);

// ============================================================
// Stage 2：ID（双译码）—— 含 IDII 寄存器
// ============================================================
wire [ADDR_WIDTH-1:0] idii_pc_w1,  idii_pc_w2;
wire [4:0]  idii_rs1_w1, idii_rs2_w1, idii_rd_w1;
wire [4:0]  idii_rs1_w2, idii_rs2_w2, idii_rd_w2;
wire [DATA_WIDTH-1:0] idii_imm_w1, idii_imm_w2;
wire [3:0]  idii_alu_op_w1,  idii_alu_op_w2;
wire        idii_src1_w1, idii_src2_w1, idii_src1_w2, idii_src2_w2;
wire        idii_mr_w1, idii_mw_w1, idii_mr_w2, idii_mw_w2;
wire [2:0]  idii_msz_w1, idii_msz_w2;
wire        idii_rwe_w1, idii_rwe_w2;
wire [1:0]  idii_wbsel_w1, idii_wbsel_w2;
wire        idii_isbr_w1, idii_isjmp_w1, idii_issys_w1, idii_ismem_w1;
wire        idii_isbr_w2, idii_isjmp_w2, idii_issys_w2, idii_ismem_w2;
wire        idii_ismul_w1, idii_ismul_w2;
wire [2:0]  idii_mulf3_w1, idii_mulf3_w2;
wire        idii_urs1_w1, idii_urs2_w1, idii_valid_w1;
wire        idii_urs1_w2, idii_urs2_w2, idii_valid_w2;

id_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .REG_ADDR_WIDTH(5)
) u_id_stage (
    .clk(clk), .rst_n(rst_n),
    .stall(stall_id), .flush(flush_id),
    .pc_w1_i(ifid_pc_w1),   .instr_w1_i(ifid_instr_w1), .valid_w1_i(ifid_valid_w1),
    .pc_w2_i(ifid_pc_w2),   .instr_w2_i(ifid_instr_w2), .valid_w2_i(ifid_valid_w2),
    .pc_w1_o(idii_pc_w1),   .pc_w2_o(idii_pc_w2),
    .rs1_addr_w1_o(idii_rs1_w1), .rs2_addr_w1_o(idii_rs2_w1), .rd_addr_w1_o(idii_rd_w1),
    .rs1_addr_w2_o(idii_rs1_w2), .rs2_addr_w2_o(idii_rs2_w2), .rd_addr_w2_o(idii_rd_w2),
    .imm_w1_o(idii_imm_w1), .imm_w2_o(idii_imm_w2),
    .alu_op_w1_o(idii_alu_op_w1), .alu_op_w2_o(idii_alu_op_w2),
    .alu_src1_sel_w1_o(idii_src1_w1), .alu_src2_sel_w1_o(idii_src2_w1),
    .alu_src1_sel_w2_o(idii_src1_w2), .alu_src2_sel_w2_o(idii_src2_w2),
    .mem_read_en_w1_o(idii_mr_w1), .mem_write_en_w1_o(idii_mw_w1), .mem_size_w1_o(idii_msz_w1),
    .mem_read_en_w2_o(idii_mr_w2), .mem_write_en_w2_o(idii_mw_w2), .mem_size_w2_o(idii_msz_w2),
    .reg_write_en_w1_o(idii_rwe_w1), .wb_sel_w1_o(idii_wbsel_w1),
    .reg_write_en_w2_o(idii_rwe_w2), .wb_sel_w2_o(idii_wbsel_w2),
    .is_branch_w1_o(idii_isbr_w1), .is_jump_w1_o(idii_isjmp_w1),
    .is_branch_w2_o(idii_isbr_w2), .is_jump_w2_o(idii_isjmp_w2),
    .is_system_w1_o(idii_issys_w1), .is_system_w2_o(idii_issys_w2),
    .is_mem_op_w1_o(idii_ismem_w1), .is_mem_op_w2_o(idii_ismem_w2),
    .is_muldiv_w1_o(idii_ismul_w1), .muldiv_funct3_w1_o(idii_mulf3_w1),
    .is_muldiv_w2_o(idii_ismul_w2), .muldiv_funct3_w2_o(idii_mulf3_w2),
    .uses_rs1_w1_o(idii_urs1_w1),  .uses_rs2_w1_o(idii_urs2_w1), .valid_w1_o(idii_valid_w1),
    .uses_rs1_w2_o(idii_urs1_w2),  .uses_rs2_w2_o(idii_urs2_w2), .valid_w2_o(idii_valid_w2)
);

// ============================================================
// 寄存器堆（4读口，2写口）
// ============================================================
wire [4:0]            rf_ra1, rf_ra2, rf_ra3, rf_ra4;
wire [DATA_WIDTH-1:0] rf_rd1, rf_rd2, rf_rd3, rf_rd4;

// WB 写回
wire [4:0]            wb_waddr1, wb_waddr2;
wire [DATA_WIDTH-1:0] wb_wdata1, wb_wdata2;
wire                  wb_we1,    wb_we2;

register_file #(
    .DATA_WIDTH(DATA_WIDTH),
    .REG_COUNT(REG_COUNT),
    .ADDR_WIDTH(5)
) u_register_file (
    .clk(clk), .rst_n(rst_n),
    .raddr1(rf_ra1), .rdata1(rf_rd1),
    .raddr2(rf_ra2), .rdata2(rf_rd2),
    .raddr3(rf_ra3), .rdata3(rf_rd3),
    .raddr4(rf_ra4), .rdata4(rf_rd4),
    .waddr1(wb_waddr1), .wdata1(wb_wdata1), .we1(wb_we1),
    .waddr2(wb_waddr2), .wdata2(wb_wdata2), .we2(wb_we2)
);

// ============================================================
// Stage 3：II（发射）—— 含 IIEX 寄存器
// ============================================================
wire [ADDR_WIDTH-1:0] iiex_pc_w1,  iiex_pc_w2;
wire [4:0]  iiex_rs1a_w1, iiex_rs2a_w1, iiex_rd_w1;
wire [4:0]  iiex_rs1a_w2, iiex_rs2a_w2, iiex_rd_w2;
wire [DATA_WIDTH-1:0] iiex_rs1d_w1, iiex_rs2d_w1;
wire [DATA_WIDTH-1:0] iiex_rs1d_w2, iiex_rs2d_w2;
wire [DATA_WIDTH-1:0] iiex_imm_w1,  iiex_imm_w2;
wire [3:0]  iiex_aop_w1,   iiex_aop_w2;
wire        iiex_src1_w1,  iiex_src2_w1, iiex_src1_w2, iiex_src2_w2;
wire        iiex_mr_w1,    iiex_mw_w1, iiex_mr_w2, iiex_mw_w2;
wire [2:0]  iiex_msz_w1,   iiex_msz_w2;
wire        iiex_rwe_w1,   iiex_rwe_w2;
wire [1:0]  iiex_wbsel_w1, iiex_wbsel_w2;
wire        iiex_isbr_w1,  iiex_isjmp_w1, iiex_valid_w1;
wire        iiex_isbr_w2,  iiex_isjmp_w2, iiex_valid_w2;
wire        iiex_ismul_w1, iiex_ismul_w2;
wire [2:0]  iiex_mulf3_w1, iiex_mulf3_w2;

ii_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_ii_stage (
    .clk(clk), .rst_n(rst_n), .flush(flush_ex),
    // IDII Way1
    .pc_w1_i(idii_pc_w1),
    .rs1_addr_w1_i(idii_rs1_w1), .rs2_addr_w1_i(idii_rs2_w1), .rd_addr_w1_i(idii_rd_w1),
    .imm_w1_i(idii_imm_w1), .alu_op_w1_i(idii_alu_op_w1),
    .alu_src1_sel_w1_i(idii_src1_w1), .alu_src2_sel_w1_i(idii_src2_w1),
    .mem_read_en_w1_i(idii_mr_w1), .mem_write_en_w1_i(idii_mw_w1), .mem_size_w1_i(idii_msz_w1),
    .reg_write_en_w1_i(idii_rwe_w1), .wb_sel_w1_i(idii_wbsel_w1),
    .is_branch_w1_i(idii_isbr_w1), .is_jump_w1_i(idii_isjmp_w1),
    .is_system_w1_i(idii_issys_w1), .is_mem_op_w1_i(idii_ismem_w1),
    .is_muldiv_w1_i(idii_ismul_w1), .muldiv_funct3_w1_i(idii_mulf3_w1),
    .uses_rs1_w1_i(idii_urs1_w1), .uses_rs2_w1_i(idii_urs2_w1), .valid_w1_i(idii_valid_w1),
    // IDII Way2
    .pc_w2_i(idii_pc_w2),
    .rs1_addr_w2_i(idii_rs1_w2), .rs2_addr_w2_i(idii_rs2_w2), .rd_addr_w2_i(idii_rd_w2),
    .imm_w2_i(idii_imm_w2), .alu_op_w2_i(idii_alu_op_w2),
    .alu_src1_sel_w2_i(idii_src1_w2), .alu_src2_sel_w2_i(idii_src2_w2),
    .mem_read_en_w2_i(idii_mr_w2), .mem_write_en_w2_i(idii_mw_w2), .mem_size_w2_i(idii_msz_w2),
    .reg_write_en_w2_i(idii_rwe_w2), .wb_sel_w2_i(idii_wbsel_w2),
    .is_branch_w2_i(idii_isbr_w2), .is_jump_w2_i(idii_isjmp_w2),
    .is_system_w2_i(idii_issys_w2), .is_mem_op_w2_i(idii_ismem_w2),
    .is_muldiv_w2_i(idii_ismul_w2), .muldiv_funct3_w2_i(idii_mulf3_w2),
    .uses_rs1_w2_i(idii_urs1_w2), .uses_rs2_w2_i(idii_urs2_w2), .valid_w2_i(idii_valid_w2),
    // 寄存器堆
    .rf_raddr1(rf_ra1), .rf_rdata1(rf_rd1),
    .rf_raddr2(rf_ra2), .rf_rdata2(rf_rd2),
    .rf_raddr3(rf_ra3), .rf_rdata3(rf_rd3),
    .rf_raddr4(rf_ra4), .rf_rdata4(rf_rd4),
    // 停顿
    .stall_dual(stall_dual),
    // IIEX Way1
    .pc_w1_o(iiex_pc_w1),
    .rs1_addr_w1_o(iiex_rs1a_w1), .rs2_addr_w1_o(iiex_rs2a_w1), .rd_addr_w1_o(iiex_rd_w1),
    .rs1_data_w1_o(iiex_rs1d_w1), .rs2_data_w1_o(iiex_rs2d_w1),
    .imm_w1_o(iiex_imm_w1), .alu_op_w1_o(iiex_aop_w1),
    .alu_src1_sel_w1_o(iiex_src1_w1), .alu_src2_sel_w1_o(iiex_src2_w1),
    .mem_read_en_w1_o(iiex_mr_w1), .mem_write_en_w1_o(iiex_mw_w1), .mem_size_w1_o(iiex_msz_w1),
    .reg_write_en_w1_o(iiex_rwe_w1), .wb_sel_w1_o(iiex_wbsel_w1),
    .is_branch_w1_o(iiex_isbr_w1), .is_jump_w1_o(iiex_isjmp_w1), .valid_w1_o(iiex_valid_w1),
    .is_muldiv_w1_o(iiex_ismul_w1), .muldiv_funct3_w1_o(iiex_mulf3_w1),
    // IIEX Way2
    .pc_w2_o(iiex_pc_w2),
    .rs1_addr_w2_o(iiex_rs1a_w2), .rs2_addr_w2_o(iiex_rs2a_w2), .rd_addr_w2_o(iiex_rd_w2),
    .rs1_data_w2_o(iiex_rs1d_w2), .rs2_data_w2_o(iiex_rs2d_w2),
    .imm_w2_o(iiex_imm_w2), .alu_op_w2_o(iiex_aop_w2),
    .alu_src1_sel_w2_o(iiex_src1_w2), .alu_src2_sel_w2_o(iiex_src2_w2),
    .mem_read_en_w2_o(iiex_mr_w2), .mem_write_en_w2_o(iiex_mw_w2), .mem_size_w2_o(iiex_msz_w2),
    .reg_write_en_w2_o(iiex_rwe_w2), .wb_sel_w2_o(iiex_wbsel_w2),
    .is_branch_w2_o(iiex_isbr_w2), .is_jump_w2_o(iiex_isjmp_w2),
    .is_muldiv_w2_o(iiex_ismul_w2), .muldiv_funct3_w2_o(iiex_mulf3_w2), .valid_w2_o(iiex_valid_w2)
);

// ============================================================
// Stage 4：EX（双 ALU）—— 含 EX/MEM 寄存器
// ============================================================
wire [ADDR_WIDTH-1:0] exmem_pc_w1,  exmem_pc_w2;
wire [DATA_WIDTH-1:0] exmem_alu_w1, exmem_alu_w2;
wire [DATA_WIDTH-1:0] exmem_rs2_w1, exmem_rs2_w2;
wire [4:0]  exmem_rd_w1,  exmem_rd_w2;
wire        exmem_mr_w1,  exmem_mw_w1, exmem_mr_w2, exmem_mw_w2;
wire [2:0]  exmem_msz_w1, exmem_msz_w2;
wire        exmem_rwe_w1, exmem_rwe_w2;
wire [1:0]  exmem_wbs_w1, exmem_wbs_w2;
wire        exmem_val_w1, exmem_val_w2;

// WB 前递给 EX：来自 MEM/WB 寄存器
wire [DATA_WIDTH-1:0] memwb_result_w1, memwb_result_w2;
wire [4:0]            memwb_rd_w1,     memwb_rd_w2;
wire                  memwb_rwe_w1,    memwb_rwe_w2;

ex_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_ex_stage (
    .clk(clk), .rst_n(rst_n), .flush(flush_ex),
    // IIEX Way1
    .pc_w1_i(iiex_pc_w1),
    .rs1_addr_w1_i(iiex_rs1a_w1), .rs2_addr_w1_i(iiex_rs2a_w1),
    .rs1_data_w1_i(iiex_rs1d_w1), .rs2_data_w1_i(iiex_rs2d_w1),
    .rd_addr_w1_i(iiex_rd_w1), .imm_w1_i(iiex_imm_w1),
    .alu_op_w1_i(iiex_aop_w1),
    .alu_src1_sel_w1_i(iiex_src1_w1), .alu_src2_sel_w1_i(iiex_src2_w1),
    .mem_read_en_w1_i(iiex_mr_w1), .mem_write_en_w1_i(iiex_mw_w1), .mem_size_w1_i(iiex_msz_w1),
    .reg_write_en_w1_i(iiex_rwe_w1), .wb_sel_w1_i(iiex_wbsel_w1),
    .is_branch_w1_i(iiex_isbr_w1), .is_jump_w1_i(iiex_isjmp_w1),
    .is_muldiv_w1_i(iiex_ismul_w1), .muldiv_funct3_w1_i(iiex_mulf3_w1), .valid_w1_i(iiex_valid_w1),
    // IIEX Way2
    .pc_w2_i(iiex_pc_w2),
    .rs1_addr_w2_i(iiex_rs1a_w2), .rs2_addr_w2_i(iiex_rs2a_w2),
    .rs1_data_w2_i(iiex_rs1d_w2), .rs2_data_w2_i(iiex_rs2d_w2),
    .rd_addr_w2_i(iiex_rd_w2), .imm_w2_i(iiex_imm_w2),
    .alu_op_w2_i(iiex_aop_w2),
    .alu_src1_sel_w2_i(iiex_src1_w2), .alu_src2_sel_w2_i(iiex_src2_w2),
    .mem_read_en_w2_i(iiex_mr_w2), .mem_write_en_w2_i(iiex_mw_w2), .mem_size_w2_i(iiex_msz_w2),
    .reg_write_en_w2_i(iiex_rwe_w2), .wb_sel_w2_i(iiex_wbsel_w2),
    .is_branch_w2_i(iiex_isbr_w2), .is_jump_w2_i(iiex_isjmp_w2),
    .is_muldiv_w2_i(iiex_ismul_w2), .muldiv_funct3_w2_i(iiex_mulf3_w2), .valid_w2_i(iiex_valid_w2),
    // 前递：EX/MEM（即上一周期 EX 输出，本周期 EX 同时可用）
    .fwd_exmem_result_w1(exmem_alu_w1), .fwd_exmem_rd_w1(exmem_rd_w1), .fwd_exmem_we_w1(exmem_rwe_w1),
    .fwd_exmem_result_w2(exmem_alu_w2), .fwd_exmem_rd_w2(exmem_rd_w2), .fwd_exmem_we_w2(exmem_rwe_w2),
    // 前递：MEM/WB
    .fwd_memwb_result_w1(memwb_result_w1), .fwd_memwb_rd_w1(memwb_rd_w1), .fwd_memwb_we_w1(memwb_rwe_w1),
    .fwd_memwb_result_w2(memwb_result_w2), .fwd_memwb_rd_w2(memwb_rd_w2), .fwd_memwb_we_w2(memwb_rwe_w2),
    // 分支预测（当前简化：不接预测值）
    .predict_taken_i(1'b0), .predict_target_i(64'b0),
    // EX/MEM 寄存器 Way1
    .pc_w1_o(exmem_pc_w1), .alu_result_w1_o(exmem_alu_w1), .rs2_data_w1_o(exmem_rs2_w1),
    .rd_addr_w1_o(exmem_rd_w1),
    .mem_read_en_w1_o(exmem_mr_w1), .mem_write_en_w1_o(exmem_mw_w1), .mem_size_w1_o(exmem_msz_w1),
    .reg_write_en_w1_o(exmem_rwe_w1), .wb_sel_w1_o(exmem_wbs_w1), .valid_w1_o(exmem_val_w1),
    // EX/MEM 寄存器 Way2
    .pc_w2_o(exmem_pc_w2), .alu_result_w2_o(exmem_alu_w2), .rs2_data_w2_o(exmem_rs2_w2),
    .rd_addr_w2_o(exmem_rd_w2),
    .mem_read_en_w2_o(exmem_mr_w2), .mem_write_en_w2_o(exmem_mw_w2), .mem_size_w2_o(exmem_msz_w2),
    .reg_write_en_w2_o(exmem_rwe_w2), .wb_sel_w2_o(exmem_wbs_w2), .valid_w2_o(exmem_val_w2),
    // 分支
    .branch_taken_o(branch_taken), .branch_target_o(branch_target), .mispredict_o(mispredict)
);

// ============================================================
// Stage 5：MEM（访存）—— 含 MEM/WB 寄存器
// ============================================================
wire [DATA_WIDTH-1:0] memwb_alu_w1, memwb_mem_w1;
wire [4:0]  memwb_rd_w1_raw, memwb_rd_w2_raw;
wire        memwb_val_w1, memwb_val_w2;
wire [1:0]  memwb_wbs_w1, memwb_wbs_w2;

mem_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_mem_stage (
    .clk(clk), .rst_n(rst_n),
    // EX/MEM Way1
    .pc_w1_i(exmem_pc_w1), .alu_result_w1_i(exmem_alu_w1), .rs2_data_w1_i(exmem_rs2_w1),
    .rd_addr_w1_i(exmem_rd_w1), .valid_w1_i(exmem_val_w1),
    .mem_read_en_w1_i(exmem_mr_w1), .mem_write_en_w1_i(exmem_mw_w1), .mem_size_w1_i(exmem_msz_w1),
    .reg_write_en_w1_i(exmem_rwe_w1), .wb_sel_w1_i(exmem_wbs_w1),
    // EX/MEM Way2 (透传)
    .alu_result_w2_i(exmem_alu_w2), .rd_addr_w2_i(exmem_rd_w2), .valid_w2_i(exmem_val_w2),
    .reg_write_en_w2_i(exmem_rwe_w2), .wb_sel_w2_i(exmem_wbs_w2),
    // 数据存储器接口
    .mem_addr(data_addr), .mem_wdata(data_wdata),
    .mem_we(data_we), .mem_be(data_be),
    .mem_rdata(data_rdata), .mem_gnt(data_gnt),
    // MEM/WB Way1
    .alu_result_w1_o(memwb_alu_w1), .mem_result_w1_o(memwb_mem_w1),
    .rd_addr_w1_o(memwb_rd_w1_raw), .valid_w1_o(memwb_val_w1),
    .reg_write_en_w1_o(memwb_rwe_w1), .wb_sel_w1_o(memwb_wbs_w1),
    // MEM/WB Way2
    .alu_result_w2_o(memwb_result_w2), .rd_addr_w2_o(memwb_rd_w2_raw),
    .valid_w2_o(memwb_val_w2), .reg_write_en_w2_o(memwb_rwe_w2), .wb_sel_w2_o(memwb_wbs_w2)
);

// MEM/WB 前递结果（用于 EX 前递网络）
assign memwb_rd_w1     = memwb_rd_w1_raw;
assign memwb_rd_w2     = memwb_rd_w2_raw;
assign memwb_result_w1 = (memwb_wbs_w1 == 2'b01) ? memwb_mem_w1 : memwb_alu_w1;

// ============================================================
// Stage 6：WB（写回，组合逻辑）
// ============================================================
assign wb_waddr1 = memwb_rd_w1_raw;
assign wb_wdata1 = (memwb_wbs_w1 == 2'b01) ? memwb_mem_w1 : memwb_alu_w1;
assign wb_we1    = memwb_rwe_w1 && memwb_val_w1;

assign wb_waddr2 = memwb_rd_w2_raw;
assign wb_wdata2 = memwb_result_w2;
assign wb_we2    = memwb_rwe_w2 && memwb_val_w2;

// data_req：有访存时拉高
assign data_req = exmem_mr_w1 | exmem_mw_w1;

// ============================================================
// 冒险处理单元
// ============================================================
hazard_unit u_hazard_unit (
    .clk(clk), .rst_n(rst_n),
    // IDII 源寄存器（来自 ID 的 IDII 寄存器输出）
    .rs1_addr_id_w1(idii_rs1_w1), .rs2_addr_id_w1(idii_rs2_w1),
    .rs1_used_id_w1(idii_urs1_w1), .rs2_used_id_w1(idii_urs2_w1),
    .rs1_addr_id_w2(idii_rs1_w2), .rs2_addr_id_w2(idii_rs2_w2),
    .rs1_used_id_w2(idii_urs1_w2), .rs2_used_id_w2(idii_urs2_w2),
    // IIEX 目的寄存器（EX 阶段 Load-Use 检测）
    .rd_addr_ex_w1(iiex_rd_w1), .reg_write_en_ex_w1(iiex_rwe_w1), .mem_read_en_ex_w1(iiex_mr_w1),
    .rd_addr_ex_w2(iiex_rd_w2), .reg_write_en_ex_w2(iiex_rwe_w2), .mem_read_en_ex_w2(iiex_mr_w2),
    // EX/MEM 目的寄存器
    .rd_addr_mem_w1(exmem_rd_w1), .reg_write_en_mem_w1(exmem_rwe_w1),
    .rd_addr_mem_w2(exmem_rd_w2), .reg_write_en_mem_w2(exmem_rwe_w2),
    // 分支信号
    .branch_taken_ex(branch_taken), .mispredict_ex(mispredict),
    // 双发射停顿
    .stall_dual(stall_dual),
    // 流水线控制
    .stall_if(stall_if), .stall_id(stall_id),
    .flush_if(flush_if), .flush_id(flush_id), .flush_ex(flush_ex)
);

// ============================================================
// 调试接口占位
// ============================================================
assign debug_halt   = 1'b0;
assign debug_resume = 1'b1;

endmodule
