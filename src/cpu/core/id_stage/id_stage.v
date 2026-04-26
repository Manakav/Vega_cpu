// ============================================================================
// ID Stage（译码阶段）- 6级流水线双发射版本
// 包含双路译码器（Way1 / Way2）+ IDII 流水线寄存器
// 不再包含寄存器堆读接口（移至 II 阶段）
// ============================================================================

module id_stage #(
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 64,
    parameter REG_ADDR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  stall,   // 停顿：保持 IDII 寄存器内容
    input  wire                  flush,   // 冲刷：清空 IDII 寄存器

    // ---- 来自 IF 阶段 (IFID 寄存器输出) ----
    input  wire [ADDR_WIDTH-1:0] pc_w1_i,
    input  wire [31:0]           instr_w1_i,
    input  wire                  valid_w1_i,

    input  wire [ADDR_WIDTH-1:0] pc_w2_i,
    input  wire [31:0]           instr_w2_i,
    input  wire                  valid_w2_i,
    
    // 预测信息输入
    input  wire                  predict_taken_i,
    input  wire [ADDR_WIDTH-1:0] predict_target_i,

    // ---- Way1 译码输出（IDII 寄存器）----
    output reg  [ADDR_WIDTH-1:0] pc_w1_o,
    output reg  [4:0]            rs1_addr_w1_o,
    output reg  [4:0]            rs2_addr_w1_o,
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
    output reg                   is_system_w1_o,
    output reg                   is_csr_w1_o,
    output reg  [11:0]           csr_addr_w1_o,
    output reg  [2:0]            funct3_w1_o,
    output reg                   is_mem_op_w1_o,   // load 或 store
    output reg                   is_muldiv_w1_o,
    output reg  [2:0]            muldiv_funct3_w1_o,
    output reg                   uses_rs1_w1_o,
    output reg                   uses_rs2_w1_o,
    output reg                   valid_w1_o,

    // ---- Way2 译码输出（IDII 寄存器）----
    output reg  [ADDR_WIDTH-1:0] pc_w2_o,
    output reg  [4:0]            rs1_addr_w2_o,
    output reg  [4:0]            rs2_addr_w2_o,
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
    output reg                   is_system_w2_o,
    output reg                   is_csr_w2_o,
    output reg  [11:0]           csr_addr_w2_o,
    output reg  [2:0]            funct3_w2_o,
    output reg                   is_mem_op_w2_o,
    output reg                   is_muldiv_w2_o,
    output reg  [2:0]            muldiv_funct3_w2_o,
    output reg                   uses_rs1_w2_o,
    output reg                   uses_rs2_w2_o,
    output reg                   valid_w2_o,
    
    // 预测信息输出
    output reg                   predict_taken_o,
    output reg  [ADDR_WIDTH-1:0] predict_target_o
);

// ---------- Way1 译码器 ----------
wire [4:0]  rs1_w1, rs2_w1, rd_w1;
wire [63:0] imm_w1;
wire [6:0]  opcode_w1;
wire [2:0]  funct3_w1;
wire [6:0]  funct7_w1;
wire is_branch_w1, is_jump_w1, is_load_w1, is_store_w1;
wire is_alu_imm_w1, is_alu_rr_w1, is_lui_w1, is_auipc_w1, is_system_w1, is_csr_w1;
wire [11:0] csr_addr_w1;
wire is_muldiv_w1;
wire [2:0] muldiv_funct3_w1;
wire is_compressed_w1;

decoder u_decoder_w1 (
    .instr(instr_w1_i),
    .valid(valid_w1_i),
    .rs1_addr(rs1_w1), .rs2_addr(rs2_w1), .rd_addr(rd_w1),
    .imm(imm_w1), .opcode(opcode_w1), .funct3(funct3_w1), .funct7(funct7_w1),
    .is_compressed(is_compressed_w1),
    .is_branch(is_branch_w1), .is_jump(is_jump_w1),
    .is_load(is_load_w1),  .is_store(is_store_w1),
    .is_alu_imm(is_alu_imm_w1), .is_alu_rr(is_alu_rr_w1),
    .is_muldiv(is_muldiv_w1), .muldiv_funct3(muldiv_funct3_w1),
    .is_lui(is_lui_w1), .is_auipc(is_auipc_w1), .is_system(is_system_w1),
    .is_csr(is_csr_w1), .csr_addr(csr_addr_w1)
);

// ---------- Way2 译码器 ----------
wire [4:0]  rs1_w2, rs2_w2, rd_w2;
wire [63:0] imm_w2;
wire [6:0]  opcode_w2;
wire [2:0]  funct3_w2;
wire [6:0]  funct7_w2;
wire is_branch_w2, is_jump_w2, is_load_w2, is_store_w2;
wire is_alu_imm_w2, is_alu_rr_w2, is_lui_w2, is_auipc_w2, is_system_w2, is_csr_w2;
wire [11:0] csr_addr_w2;
wire is_muldiv_w2;
wire [2:0] muldiv_funct3_w2;
wire is_compressed_w2;

decoder u_decoder_w2 (
    .instr(instr_w2_i),
    .valid(valid_w2_i),
    .rs1_addr(rs1_w2), .rs2_addr(rs2_w2), .rd_addr(rd_w2),
    .imm(imm_w2), .opcode(opcode_w2), .funct3(funct3_w2), .funct7(funct7_w2),
    .is_compressed(is_compressed_w2),
    .is_branch(is_branch_w2), .is_jump(is_jump_w2),
    .is_load(is_load_w2),  .is_store(is_store_w2),
    .is_alu_imm(is_alu_imm_w2), .is_alu_rr(is_alu_rr_w2),
    .is_muldiv(is_muldiv_w2), .muldiv_funct3(muldiv_funct3_w2),
    .is_lui(is_lui_w2), .is_auipc(is_auipc_w2), .is_system(is_system_w2),
    .is_csr(is_csr_w2), .csr_addr(csr_addr_w2)
);

// ---------- 控制信号生成（Way1 组合逻辑）----------
reg [3:0]  alu_op_c1;
reg        src1_sel_c1, src2_sel_c1;
reg        mem_r_c1, mem_w_c1;
reg [2:0]  mem_sz_c1;
reg        reg_we_c1;
reg [1:0]  wb_sel_c1;

// rs1/rs2 使用标志（用于 II 阶段冒险检测）
wire uses_rs1_w1_c = !(is_lui_w1 || is_auipc_w1 || (is_jump_w1 && opcode_w1 == 7'b1101111));
wire uses_rs2_w1_c = is_alu_rr_w1 || is_muldiv_w1 || is_branch_w1 || is_store_w1;

always @(*) begin
    alu_op_c1   = 4'b0; src1_sel_c1 = 1'b0; src2_sel_c1 = 1'b0;
    mem_r_c1    = 1'b0; mem_w_c1    = 1'b0; mem_sz_c1   = 3'b0;
    reg_we_c1   = 1'b0; wb_sel_c1   = 2'b0;
    case (opcode_w1)
        7'b0000011: begin // LOAD
            alu_op_c1=4'b0000; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b1; mem_w_c1=1'b0; mem_sz_c1=funct3_w1; reg_we_c1=1'b1; wb_sel_c1=2'b01;
        end
        7'b0100011: begin // STORE
            alu_op_c1=4'b0000; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b1; mem_sz_c1=funct3_w1; reg_we_c1=1'b0; wb_sel_c1=2'b00;
        end
        7'b1100011: begin // BRANCH
            alu_op_c1=4'b0000; src1_sel_c1=1'b0; src2_sel_c1=1'b0;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=funct3_w1; reg_we_c1=1'b0; wb_sel_c1=2'b00;
        end
        7'b1100111: begin // JALR
            alu_op_c1=4'b0000; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b10;
        end
        7'b1101111: begin // JAL
            alu_op_c1=4'b1100; src1_sel_c1=1'b1; src2_sel_c1=1'b0;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b10;
        end
        7'b0010111: begin // AUIPC
            alu_op_c1=4'b1100; src1_sel_c1=1'b1; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b0110111: begin // LUI
            alu_op_c1=4'b1010; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b0010011: begin // OP-IMM
            alu_op_c1={funct7_w1[5],funct3_w1}; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b0011011: begin // OP-IMM32
            alu_op_c1={funct7_w1[5],funct3_w1}; src1_sel_c1=1'b0; src2_sel_c1=1'b1;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b0110011: begin // OP
            alu_op_c1={funct7_w1[5],funct3_w1}; src1_sel_c1=1'b0; src2_sel_c1=1'b0;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b0111011: begin // OP32
            alu_op_c1={funct7_w1[5],funct3_w1}; src1_sel_c1=1'b0; src2_sel_c1=1'b0;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0; reg_we_c1=1'b1; wb_sel_c1=2'b00;
        end
        7'b1110011: begin // SYSTEM
            alu_op_c1=4'b0000; src1_sel_c1=1'b0; src2_sel_c1=1'b0;
            mem_r_c1=1'b0; mem_w_c1=1'b0; mem_sz_c1=3'b0;
            reg_we_c1=(funct3_w1!=3'b000); wb_sel_c1=2'b00;
        end
        default: begin end
    endcase
end

// ---------- 控制信号生成（Way2 组合逻辑）----------
reg [3:0]  alu_op_c2;
reg        src1_sel_c2, src2_sel_c2;
reg        mem_r_c2, mem_w_c2;
reg [2:0]  mem_sz_c2;
reg        reg_we_c2;
reg [1:0]  wb_sel_c2;

wire uses_rs1_w2_c = !(is_lui_w2 || is_auipc_w2 || (is_jump_w2 && opcode_w2 == 7'b1101111));
wire uses_rs2_w2_c = is_alu_rr_w2 || is_muldiv_w2 || is_branch_w2 || is_store_w2;

always @(*) begin
    alu_op_c2   = 4'b0; src1_sel_c2 = 1'b0; src2_sel_c2 = 1'b0;
    mem_r_c2    = 1'b0; mem_w_c2    = 1'b0; mem_sz_c2   = 3'b0;
    reg_we_c2   = 1'b0; wb_sel_c2   = 2'b0;
    case (opcode_w2)
        7'b0000011: begin
            alu_op_c2=4'b0000; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b1; mem_w_c2=1'b0; mem_sz_c2=funct3_w2; reg_we_c2=1'b1; wb_sel_c2=2'b01;
        end
        7'b0100011: begin
            alu_op_c2=4'b0000; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b1; mem_sz_c2=funct3_w2; reg_we_c2=1'b0; wb_sel_c2=2'b00;
        end
        7'b1100011: begin
            alu_op_c2=4'b0000; src1_sel_c2=1'b0; src2_sel_c2=1'b0;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=funct3_w2; reg_we_c2=1'b0; wb_sel_c2=2'b00;
        end
        7'b1100111: begin
            alu_op_c2=4'b0000; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b10;
        end
        7'b1101111: begin
            alu_op_c2=4'b1100; src1_sel_c2=1'b1; src2_sel_c2=1'b0;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b10;
        end
        7'b0010111: begin
            alu_op_c2=4'b1100; src1_sel_c2=1'b1; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b0110111: begin
            alu_op_c2=4'b1010; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b0010011: begin
            alu_op_c2={funct7_w2[5],funct3_w2}; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b0011011: begin
            alu_op_c2={funct7_w2[5],funct3_w2}; src1_sel_c2=1'b0; src2_sel_c2=1'b1;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b0110011: begin
            alu_op_c2={funct7_w2[5],funct3_w2}; src1_sel_c2=1'b0; src2_sel_c2=1'b0;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b0111011: begin
            alu_op_c2={funct7_w2[5],funct3_w2}; src1_sel_c2=1'b0; src2_sel_c2=1'b0;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0; reg_we_c2=1'b1; wb_sel_c2=2'b00;
        end
        7'b1110011: begin
            alu_op_c2=4'b0000; src1_sel_c2=1'b0; src2_sel_c2=1'b0;
            mem_r_c2=1'b0; mem_w_c2=1'b0; mem_sz_c2=3'b0;
            reg_we_c2=(funct3_w2!=3'b000); wb_sel_c2=2'b00;
        end
        default: begin end
    endcase
end

// ---------- IDII 流水线寄存器（时序逻辑）----------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        // 复位或冲刷时注入气泡
        valid_w1_o <= 1'b0; valid_w2_o <= 1'b0;
        pc_w1_o    <= 64'b0; pc_w2_o   <= 64'b0;
        rs1_addr_w1_o <= 5'b0; rs2_addr_w1_o <= 5'b0; rd_addr_w1_o <= 5'b0;
        rs1_addr_w2_o <= 5'b0; rs2_addr_w2_o <= 5'b0; rd_addr_w2_o <= 5'b0;
        imm_w1_o <= 64'b0; imm_w2_o <= 64'b0;
        alu_op_w1_o <= 4'b0; alu_op_w2_o <= 4'b0;
        alu_src1_sel_w1_o <= 1'b0; alu_src2_sel_w1_o <= 1'b0;
        alu_src1_sel_w2_o <= 1'b0; alu_src2_sel_w2_o <= 1'b0;
        mem_read_en_w1_o <= 1'b0; mem_write_en_w1_o <= 1'b0; mem_size_w1_o <= 3'b0;
        mem_read_en_w2_o <= 1'b0; mem_write_en_w2_o <= 1'b0; mem_size_w2_o <= 3'b0;
        reg_write_en_w1_o <= 1'b0; wb_sel_w1_o <= 2'b0;
        reg_write_en_w2_o <= 1'b0; wb_sel_w2_o <= 2'b0;
        is_branch_w1_o <= 1'b0; is_jump_w1_o <= 1'b0;
        is_branch_w2_o <= 1'b0; is_jump_w2_o <= 1'b0;
        is_system_w1_o <= 1'b0; is_system_w2_o <= 1'b0;
        is_csr_w1_o <= 1'b0; is_csr_w2_o <= 1'b0;
        csr_addr_w1_o <= 12'b0; csr_addr_w2_o <= 12'b0;
        funct3_w1_o <= 3'b0; funct3_w2_o <= 3'b0;
        is_mem_op_w1_o <= 1'b0; is_mem_op_w2_o <= 1'b0;
        is_muldiv_w1_o <= 1'b0; is_muldiv_w2_o <= 1'b0;
        muldiv_funct3_w1_o <= 3'b0; muldiv_funct3_w2_o <= 3'b0;
        uses_rs1_w1_o <= 1'b0; uses_rs2_w1_o <= 1'b0;
        uses_rs1_w2_o <= 1'b0; uses_rs2_w2_o <= 1'b0;
        predict_taken_o     <= 1'b0;
        predict_target_o    <= 64'b0;
    end else if (!stall) begin
        // Way1 锁存
        valid_w1_o         <= valid_w1_i;
        pc_w1_o            <= pc_w1_i;
        rs1_addr_w1_o      <= rs1_w1;
        rs2_addr_w1_o      <= rs2_w1;
        rd_addr_w1_o       <= rd_w1;
        imm_w1_o           <= imm_w1;
        alu_op_w1_o        <= alu_op_c1;
        alu_src1_sel_w1_o  <= src1_sel_c1;
        alu_src2_sel_w1_o  <= src2_sel_c1;
        mem_read_en_w1_o   <= mem_r_c1;
        mem_write_en_w1_o  <= mem_w_c1;
        mem_size_w1_o      <= mem_sz_c1;
        reg_write_en_w1_o  <= reg_we_c1;
        wb_sel_w1_o        <= wb_sel_c1;
        is_branch_w1_o     <= is_branch_w1;
        is_jump_w1_o       <= is_jump_w1;
        is_system_w1_o     <= is_system_w1;
        is_csr_w1_o        <= is_csr_w1;
        csr_addr_w1_o      <= csr_addr_w1;
        funct3_w1_o        <= funct3_w1;
        is_mem_op_w1_o     <= is_load_w1 || is_store_w1;
        is_muldiv_w1_o     <= is_muldiv_w1;
        muldiv_funct3_w1_o <= muldiv_funct3_w1;
        uses_rs1_w1_o      <= uses_rs1_w1_c;
        uses_rs2_w1_o      <= uses_rs2_w1_c;
        // Way2 锁存
        valid_w2_o         <= valid_w2_i;
        pc_w2_o            <= pc_w2_i;
        rs1_addr_w2_o      <= rs1_w2;
        rs2_addr_w2_o      <= rs2_w2;
        rd_addr_w2_o       <= rd_w2;
        imm_w2_o           <= imm_w2;
        alu_op_w2_o        <= alu_op_c2;
        alu_src1_sel_w2_o  <= src1_sel_c2;
        alu_src2_sel_w2_o  <= src2_sel_c2;
        mem_read_en_w2_o   <= mem_r_c2;
        mem_write_en_w2_o  <= mem_w_c2;
        mem_size_w2_o      <= mem_sz_c2;
        reg_write_en_w2_o  <= reg_we_c2;
        wb_sel_w2_o        <= wb_sel_c2;
        is_branch_w2_o     <= is_branch_w2;
        is_jump_w2_o       <= is_jump_w2;
        is_system_w2_o     <= is_system_w2;
        is_csr_w2_o        <= is_csr_w2;
        csr_addr_w2_o      <= csr_addr_w2;
        funct3_w2_o        <= funct3_w2;
        is_mem_op_w2_o     <= is_load_w2 || is_store_w2;
        is_muldiv_w2_o     <= is_muldiv_w2;
        muldiv_funct3_w2_o <= muldiv_funct3_w2;
        uses_rs1_w2_o      <= uses_rs1_w2_c;
        uses_rs2_w2_o      <= uses_rs2_w2_c;
        predict_taken_o     <= predict_taken_i;
        predict_target_o    <= predict_target_i;
    end
    // stall 时保持 IDII 寄存器内容不变
end

endmodule
