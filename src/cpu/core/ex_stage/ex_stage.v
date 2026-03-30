// ============================================================================
// EX Stage（执行阶段）- 6级流水线双发射版本
// 包含：前递单元 + 异步 ALU×2 + 分支判断 + EX/MEM 流水线寄存器
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
    output reg                   mispredict_o
);

// ============================================================
// 前递选择：优先级 EX/MEM Way1 > Way2 > MEM/WB Way1 > Way2 > 原值
// ============================================================
function [DATA_WIDTH-1:0] fwd_pick;
    input [4:0]            rs_addr;
    input [DATA_WIDTH-1:0] orig;
    input [DATA_WIDTH-1:0] ex1_r; input [4:0] ex1_rd; input ex1_we;
    input [DATA_WIDTH-1:0] ex2_r; input [4:0] ex2_rd; input ex2_we;
    input [DATA_WIDTH-1:0] m1_r;  input [4:0] m1_rd;  input m1_we;
    input [DATA_WIDTH-1:0] m2_r;  input [4:0] m2_rd;  input m2_we;
    begin
        if      (ex1_we && ex1_rd != 5'b0 && ex1_rd == rs_addr) fwd_pick = ex1_r;
        else if (ex2_we && ex2_rd != 5'b0 && ex2_rd == rs_addr) fwd_pick = ex2_r;
        else if (m1_we  && m1_rd  != 5'b0 && m1_rd  == rs_addr) fwd_pick = m1_r;
        else if (m2_we  && m2_rd  != 5'b0 && m2_rd  == rs_addr) fwd_pick = m2_r;
        else fwd_pick = orig;
    end
endfunction

function [DATA_WIDTH-1:0] muldiv_pick;
    input [2:0] f3;
    input [DATA_WIDTH-1:0] a;
    input [DATA_WIDTH-1:0] b;
    reg signed [DATA_WIDTH-1:0] sa;
    reg signed [DATA_WIDTH-1:0] sb;
    reg signed [2*DATA_WIDTH-1:0] prod_ss;
    reg signed [2*DATA_WIDTH-1:0] prod_su;
    reg [2*DATA_WIDTH-1:0] prod_uu;
    begin
        sa = a;
        sb = b;
        prod_ss = sa * sb;
        prod_su = sa * $signed({1'b0, b});
        prod_uu = a * b;
        case (f3)
            3'b000: muldiv_pick = a * b; // MUL
            3'b001: muldiv_pick = prod_ss[2*DATA_WIDTH-1:DATA_WIDTH]; // MULH
            3'b010: muldiv_pick = prod_su[2*DATA_WIDTH-1:DATA_WIDTH]; // MULHSU
            3'b011: muldiv_pick = prod_uu[2*DATA_WIDTH-1:DATA_WIDTH]; // MULHU
            3'b100: muldiv_pick = (b != 0) ? (sa / sb) : {DATA_WIDTH{1'b1}}; // DIV
            3'b101: muldiv_pick = (b != 0) ? (a / b)   : {DATA_WIDTH{1'b1}}; // DIVU
            3'b110: muldiv_pick = (b != 0) ? (sa % sb) : {DATA_WIDTH{1'b1}}; // REM
            3'b111: muldiv_pick = (b != 0) ? (a % b)   : {DATA_WIDTH{1'b1}}; // REMU
            default: muldiv_pick = {DATA_WIDTH{1'b0}};
        endcase
    end
endfunction

// Way1 前递后操作数
wire [DATA_WIDTH-1:0] rs1_w1_fwd = fwd_pick(
    rs1_addr_w1_i, rs1_data_w1_i,
    fwd_exmem_result_w1, fwd_exmem_rd_w1, fwd_exmem_we_w1,
    fwd_exmem_result_w2, fwd_exmem_rd_w2, fwd_exmem_we_w2,
    fwd_memwb_result_w1, fwd_memwb_rd_w1, fwd_memwb_we_w1,
    fwd_memwb_result_w2, fwd_memwb_rd_w2, fwd_memwb_we_w2
);
wire [DATA_WIDTH-1:0] rs2_w1_fwd = fwd_pick(
    rs2_addr_w1_i, rs2_data_w1_i,
    fwd_exmem_result_w1, fwd_exmem_rd_w1, fwd_exmem_we_w1,
    fwd_exmem_result_w2, fwd_exmem_rd_w2, fwd_exmem_we_w2,
    fwd_memwb_result_w1, fwd_memwb_rd_w1, fwd_memwb_we_w1,
    fwd_memwb_result_w2, fwd_memwb_rd_w2, fwd_memwb_we_w2
);

// Way2 前递后操作数
wire [DATA_WIDTH-1:0] rs1_w2_fwd = fwd_pick(
    rs1_addr_w2_i, rs1_data_w2_i,
    fwd_exmem_result_w1, fwd_exmem_rd_w1, fwd_exmem_we_w1,
    fwd_exmem_result_w2, fwd_exmem_rd_w2, fwd_exmem_we_w2,
    fwd_memwb_result_w1, fwd_memwb_rd_w1, fwd_memwb_we_w1,
    fwd_memwb_result_w2, fwd_memwb_rd_w2, fwd_memwb_we_w2
);
wire [DATA_WIDTH-1:0] rs2_w2_fwd = fwd_pick(
    rs2_addr_w2_i, rs2_data_w2_i,
    fwd_exmem_result_w1, fwd_exmem_rd_w1, fwd_exmem_we_w1,
    fwd_exmem_result_w2, fwd_exmem_rd_w2, fwd_exmem_we_w2,
    fwd_memwb_result_w1, fwd_memwb_rd_w1, fwd_memwb_we_w1,
    fwd_memwb_result_w2, fwd_memwb_rd_w2, fwd_memwb_we_w2
);

// ALU 操作数选择（PC 选择 or 寄存器）
wire [DATA_WIDTH-1:0] opA_w1 = alu_src1_sel_w1_i ? pc_w1_i  : rs1_w1_fwd;
wire [DATA_WIDTH-1:0] opB_w1 = alu_src2_sel_w1_i ? imm_w1_i : rs2_w1_fwd;

wire [DATA_WIDTH-1:0] opA_w2 = alu_src1_sel_w2_i ? pc_w2_i  : rs1_w2_fwd;
wire [DATA_WIDTH-1:0] opB_w2 = alu_src2_sel_w2_i ? imm_w2_i : rs2_w2_fwd;

// ALU1 & ALU2（组合实例化）
wire [DATA_WIDTH-1:0] alu_res_w1, alu_res_w2;
wire alu_zero_w1, alu_neg_w1, alu_ovf_w1;
wire alu_zero_w2, alu_neg_w2, alu_ovf_w2;

alu u_alu1 (
    .alu_op(alu_op_w1_i), .operand_a(opA_w1), .operand_b(opB_w1),
    .result(alu_res_w1), .zero(alu_zero_w1),
    .negative(alu_neg_w1), .overflow(alu_ovf_w1)
);

alu u_alu2 (
    .alu_op(alu_op_w2_i), .operand_a(opA_w2), .operand_b(opB_w2),
    .result(alu_res_w2), .zero(alu_zero_w2),
    .negative(alu_neg_w2), .overflow(alu_ovf_w2)
);

wire [DATA_WIDTH-1:0] ex_res_w1 = is_muldiv_w1_i ?
                                  muldiv_pick(muldiv_funct3_w1_i, rs1_w1_fwd, rs2_w1_fwd) :
                                  alu_res_w1;
wire [DATA_WIDTH-1:0] ex_res_w2 = is_muldiv_w2_i ?
                                  muldiv_pick(muldiv_funct3_w2_i, rs1_w2_fwd, rs2_w2_fwd) :
                                  alu_res_w2;

// ---- 分支判断（仅 Way1 主路含分支；II 阶段已阻止 Way2 含分支）----
reg branch_taken_w1;
reg [ADDR_WIDTH-1:0] branch_tgt_w1;

always @(*) begin
    branch_taken_w1 = 1'b0;
    branch_tgt_w1   = pc_w1_i + 4;

    if (valid_w1_i) begin
        if (is_branch_w1_i) begin
            case (mem_size_w1_i)
                3'b000: branch_taken_w1 = (rs1_w1_fwd == rs2_w1_fwd);
                3'b001: branch_taken_w1 = (rs1_w1_fwd != rs2_w1_fwd);
                3'b100: branch_taken_w1 = ($signed(rs1_w1_fwd) < $signed(rs2_w1_fwd));
                3'b101: branch_taken_w1 = ($signed(rs1_w1_fwd) >= $signed(rs2_w1_fwd));
                3'b110: branch_taken_w1 = (rs1_w1_fwd < rs2_w1_fwd);
                3'b111: branch_taken_w1 = (rs1_w1_fwd >= rs2_w1_fwd);
                default: branch_taken_w1 = 1'b0;
            endcase
            branch_tgt_w1 = pc_w1_i + imm_w1_i;
        end else if (is_jump_w1_i) begin
            branch_taken_w1 = 1'b1;
            // JAL: alu_op=1100 使用 PC+imm；JALR: rs1+imm
            branch_tgt_w1 = (alu_op_w1_i == 4'b1100) ?
                             (pc_w1_i + imm_w1_i) : (rs1_w1_fwd + imm_w1_i);
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
        // Way1
        valid_w1_o        <= valid_w1_i;
        pc_w1_o           <= pc_w1_i;
        alu_result_w1_o   <= ex_res_w1;
        rs2_data_w1_o     <= rs2_w1_fwd;
        rd_addr_w1_o      <= rd_addr_w1_i;
        mem_read_en_w1_o  <= mem_read_en_w1_i;
        mem_write_en_w1_o <= mem_write_en_w1_i;
        mem_size_w1_o     <= mem_size_w1_i;
        reg_write_en_w1_o <= reg_write_en_w1_i;
        wb_sel_w1_o       <= wb_sel_w1_i;
        // Way2
        valid_w2_o        <= valid_w2_i;
        pc_w2_o           <= pc_w2_i;
        alu_result_w2_o   <= ex_res_w2;
        rs2_data_w2_o     <= rs2_w2_fwd;
        rd_addr_w2_o      <= rd_addr_w2_i;
        mem_read_en_w2_o  <= mem_read_en_w2_i;
        mem_write_en_w2_o <= mem_write_en_w2_i;
        mem_size_w2_o     <= mem_size_w2_i;
        reg_write_en_w2_o <= reg_write_en_w2_i;
        wb_sel_w2_o       <= wb_sel_w2_i;
        // 分支
        branch_taken_o  <= branch_taken_w1;
        branch_target_o <= branch_tgt_w1;
        if (valid_w1_i && (is_branch_w1_i || is_jump_w1_i)) begin
            mispredict_o <= (branch_taken_w1 != predict_taken_i) ||
                            (branch_taken_w1 && (branch_tgt_w1 != predict_target_i));
        end else begin
            mispredict_o <= 1'b0;
        end
    end
end

endmodule
