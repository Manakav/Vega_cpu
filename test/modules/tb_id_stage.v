`timescale 1ns / 1ps

// ID 阶段测试：验证双路译码与 IDII 锁存输出
module tb_id_stage;
// 输入激励
reg clk;
reg rst_n;
reg stall;
reg flush;
reg [63:0] pc_w1_i;
reg [31:0] instr_w1_i;
reg valid_w1_i;
reg [63:0] pc_w2_i;
reg [31:0] instr_w2_i;
reg valid_w2_i;

wire [63:0] pc_w1_o;
wire [4:0] rs1_addr_w1_o;
wire [4:0] rs2_addr_w1_o;
wire [4:0] rd_addr_w1_o;
wire [63:0] imm_w1_o;
wire [3:0] alu_op_w1_o;
wire alu_src1_sel_w1_o;
wire alu_src2_sel_w1_o;
wire mem_read_en_w1_o;
wire mem_write_en_w1_o;
wire [2:0] mem_size_w1_o;
wire reg_write_en_w1_o;
wire [1:0] wb_sel_w1_o;
wire is_branch_w1_o;
wire is_jump_w1_o;
wire is_system_w1_o;
wire is_mem_op_w1_o;
wire is_muldiv_w1_o;
wire [2:0] muldiv_funct3_w1_o;
wire uses_rs1_w1_o;
wire uses_rs2_w1_o;
wire valid_w1_o;

wire [63:0] pc_w2_o;
wire [4:0] rs1_addr_w2_o;
wire [4:0] rs2_addr_w2_o;
wire [4:0] rd_addr_w2_o;
wire [63:0] imm_w2_o;
wire [3:0] alu_op_w2_o;
wire alu_src1_sel_w2_o;
wire alu_src2_sel_w2_o;
wire mem_read_en_w2_o;
wire mem_write_en_w2_o;
wire [2:0] mem_size_w2_o;
wire reg_write_en_w2_o;
wire [1:0] wb_sel_w2_o;
wire is_branch_w2_o;
wire is_jump_w2_o;
wire is_system_w2_o;
wire is_mem_op_w2_o;
wire is_muldiv_w2_o;
wire [2:0] muldiv_funct3_w2_o;
wire uses_rs1_w2_o;
wire uses_rs2_w2_o;
wire valid_w2_o;
integer errors;

id_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .pc_w1_i(pc_w1_i),
    .instr_w1_i(instr_w1_i),
    .valid_w1_i(valid_w1_i),
    .pc_w2_i(pc_w2_i),
    .instr_w2_i(instr_w2_i),
    .valid_w2_i(valid_w2_i),
    .pc_w1_o(pc_w1_o),
    .rs1_addr_w1_o(rs1_addr_w1_o),
    .rs2_addr_w1_o(rs2_addr_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o),
    .imm_w1_o(imm_w1_o),
    .alu_op_w1_o(alu_op_w1_o),
    .alu_src1_sel_w1_o(alu_src1_sel_w1_o),
    .alu_src2_sel_w1_o(alu_src2_sel_w1_o),
    .mem_read_en_w1_o(mem_read_en_w1_o),
    .mem_write_en_w1_o(mem_write_en_w1_o),
    .mem_size_w1_o(mem_size_w1_o),
    .reg_write_en_w1_o(reg_write_en_w1_o),
    .wb_sel_w1_o(wb_sel_w1_o),
    .is_branch_w1_o(is_branch_w1_o),
    .is_jump_w1_o(is_jump_w1_o),
    .is_system_w1_o(is_system_w1_o),
    .is_mem_op_w1_o(is_mem_op_w1_o),
    .is_muldiv_w1_o(is_muldiv_w1_o),
    .muldiv_funct3_w1_o(muldiv_funct3_w1_o),
    .uses_rs1_w1_o(uses_rs1_w1_o),
    .uses_rs2_w1_o(uses_rs2_w1_o),
    .valid_w1_o(valid_w1_o),
    .pc_w2_o(pc_w2_o),
    .rs1_addr_w2_o(rs1_addr_w2_o),
    .rs2_addr_w2_o(rs2_addr_w2_o),
    .rd_addr_w2_o(rd_addr_w2_o),
    .imm_w2_o(imm_w2_o),
    .alu_op_w2_o(alu_op_w2_o),
    .alu_src1_sel_w2_o(alu_src1_sel_w2_o),
    .alu_src2_sel_w2_o(alu_src2_sel_w2_o),
    .mem_read_en_w2_o(mem_read_en_w2_o),
    .mem_write_en_w2_o(mem_write_en_w2_o),
    .mem_size_w2_o(mem_size_w2_o),
    .reg_write_en_w2_o(reg_write_en_w2_o),
    .wb_sel_w2_o(wb_sel_w2_o),
    .is_branch_w2_o(is_branch_w2_o),
    .is_jump_w2_o(is_jump_w2_o),
    .is_system_w2_o(is_system_w2_o),
    .is_mem_op_w2_o(is_mem_op_w2_o),
    .is_muldiv_w2_o(is_muldiv_w2_o),
    .muldiv_funct3_w2_o(muldiv_funct3_w2_o),
    .uses_rs1_w2_o(uses_rs1_w2_o),
    .uses_rs2_w2_o(uses_rs2_w2_o),
    .valid_w2_o(valid_w2_o)
);

// 时钟
always #5 clk = ~clk;

// 通用检查任务
task check;
    input cond;
    input [127:0] msg;
begin
    if (!cond) begin
        $display("[FAIL] %0s", msg);
        errors = errors + 1;
    end
end
endtask

initial begin
    // 初始化默认激励
    clk = 0;
    rst_n = 0;
    stall = 0;
    flush = 0;
    pc_w1_i = 64'h1000;
    instr_w1_i = 32'h00412083; // lw x1, 4(x2)
    valid_w1_i = 0;
    pc_w2_i = 64'h1004;
    instr_w2_i = 32'h002081B3; // add x3, x1, x2
    valid_w2_i = 0;
    errors = 0;

    #12 rst_n = 1;
    valid_w1_i = 1;
    valid_w2_i = 1;

    // 输出经过 IDII 锁存，需要一个时钟沿
    @(posedge clk);
    #1;

    // 检查 Way1: lw x1,4(x2)
    check(rs1_addr_w1_o == 5'd2, "w1 rs1 addr decode failed");
    check(rd_addr_w1_o == 5'd1, "w1 rd decode failed");
    check(mem_read_en_w1_o == 1'b1, "w1 load mem_read_en failed");
    check(reg_write_en_w1_o == 1'b1, "w1 load reg_write_en failed");
    check(valid_w1_o == 1'b1, "w1 valid failed");

    // 检查 Way2: add x3,x1,x2
    check(rs1_addr_w2_o == 5'd1, "w2 rs1 addr decode failed");
    check(rs2_addr_w2_o == 5'd2, "w2 rs2 addr decode failed");
    check(rd_addr_w2_o == 5'd3, "w2 rd decode failed");
    check(mem_read_en_w2_o == 1'b0, "w2 mem_read_en should be 0");
    check(reg_write_en_w2_o == 1'b1, "w2 reg_write_en failed");
    check(valid_w2_o == 1'b1, "w2 valid failed");

    if (errors == 0) $display("[PASS] tb_id_stage");
    else $display("[FAIL] tb_id_stage errors=%0d", errors);
    $finish;
end

endmodule
