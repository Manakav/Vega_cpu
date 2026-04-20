`timescale 1ns / 1ps

module tb_forwarding;

reg clk;
reg rst_n;
reg flush;

// Way1 IIEX inputs
reg [63:0] pc_w1_i;
reg [4:0]  rs1_addr_w1_i, rs2_addr_w1_i, rd_addr_w1_i;
reg [63:0] rs1_data_w1_i, rs2_data_w1_i;
reg [63:0] imm_w1_i;
reg [3:0]  alu_op_w1_i;
reg        alu_src1_sel_w1_i, alu_src2_sel_w1_i;
reg        mem_read_en_w1_i, mem_write_en_w1_i;
reg [2:0]  mem_size_w1_i;
reg        reg_write_en_w1_i;
reg [1:0]  wb_sel_w1_i;
reg        is_branch_w1_i, is_jump_w1_i;
reg        is_muldiv_w1_i;
reg [2:0]  muldiv_funct3_w1_i;
reg        valid_w1_i;

// Way2 IIEX inputs
reg [63:0] pc_w2_i;
reg [4:0]  rs1_addr_w2_i, rs2_addr_w2_i, rd_addr_w2_i;
reg [63:0] rs1_data_w2_i, rs2_data_w2_i;
reg [63:0] imm_w2_i;
reg [3:0]  alu_op_w2_i;
reg        alu_src1_sel_w2_i, alu_src2_sel_w2_i;
reg        mem_read_en_w2_i, mem_write_en_w2_i;
reg [2:0]  mem_size_w2_i;
reg        reg_write_en_w2_i;
reg [1:0]  wb_sel_w2_i;
reg        is_branch_w2_i, is_jump_w2_i;
reg        is_muldiv_w2_i;
reg [2:0]  muldiv_funct3_w2_i;
reg        valid_w2_i;

// Forwarding sources
reg [63:0] fwd_exmem_result_w1; reg [4:0] fwd_exmem_rd_w1; reg fwd_exmem_we_w1;
reg [63:0] fwd_exmem_result_w2; reg [4:0] fwd_exmem_rd_w2; reg fwd_exmem_we_w2;
reg [63:0] fwd_memwb_result_w1; reg [4:0] fwd_memwb_rd_w1; reg fwd_memwb_we_w1;
reg [63:0] fwd_memwb_result_w2; reg [4:0] fwd_memwb_rd_w2; reg fwd_memwb_we_w2;

reg        predict_taken_i;
reg [63:0] predict_target_i;

// Outputs
wire [63:0] pc_w1_o, alu_result_w1_o, rs2_data_w1_o;
wire [4:0]  rd_addr_w1_o;
wire        mem_read_en_w1_o, mem_write_en_w1_o, reg_write_en_w1_o, valid_w1_o;
wire [2:0]  mem_size_w1_o;
wire [1:0]  wb_sel_w1_o;
wire [63:0] pc_w2_o, alu_result_w2_o, rs2_data_w2_o;
wire [4:0]  rd_addr_w2_o;
wire        mem_read_en_w2_o, mem_write_en_w2_o, reg_write_en_w2_o, valid_w2_o;
wire [2:0]  mem_size_w2_o;
wire [1:0]  wb_sel_w2_o;
wire        branch_taken_o;
wire [63:0] branch_target_o;
wire        mispredict_o;

integer errors;

ex_stage #(
    .DATA_WIDTH(64), .ADDR_WIDTH(64)
) dut (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .pc_w1_i(pc_w1_i),
    .rs1_addr_w1_i(rs1_addr_w1_i), .rs2_addr_w1_i(rs2_addr_w1_i),
    .rs1_data_w1_i(rs1_data_w1_i), .rs2_data_w1_i(rs2_data_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i), .imm_w1_i(imm_w1_i),
    .alu_op_w1_i(alu_op_w1_i),
    .alu_src1_sel_w1_i(alu_src1_sel_w1_i), .alu_src2_sel_w1_i(alu_src2_sel_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i), .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i),
    .reg_write_en_w1_i(reg_write_en_w1_i), .wb_sel_w1_i(wb_sel_w1_i),
    .is_branch_w1_i(is_branch_w1_i), .is_jump_w1_i(is_jump_w1_i),
    .is_muldiv_w1_i(is_muldiv_w1_i), .muldiv_funct3_w1_i(muldiv_funct3_w1_i),
    .valid_w1_i(valid_w1_i),
    .pc_w2_i(pc_w2_i),
    .rs1_addr_w2_i(rs1_addr_w2_i), .rs2_addr_w2_i(rs2_addr_w2_i),
    .rs2_data_w2_i(rs2_data_w2_i), .rs1_data_w2_i(rs1_data_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i), .imm_w2_i(imm_w2_i),
    .alu_op_w2_i(alu_op_w2_i),
    .alu_src1_sel_w2_i(alu_src1_sel_w2_i), .alu_src2_sel_w2_i(alu_src2_sel_w2_i),
    .mem_read_en_w2_i(mem_read_en_w2_i), .mem_write_en_w2_i(mem_write_en_w2_i),
    .mem_size_w2_i(mem_size_w2_i),
    .reg_write_en_w2_i(reg_write_en_w2_i), .wb_sel_w2_i(wb_sel_w2_i),
    .is_branch_w2_i(is_branch_w2_i), .is_jump_w2_i(is_jump_w2_i),
    .is_muldiv_w2_i(is_muldiv_w2_i), .muldiv_funct3_w2_i(muldiv_funct3_w2_i),
    .valid_w2_i(valid_w2_i),
    .fwd_exmem_result_w1(fwd_exmem_result_w1), .fwd_exmem_rd_w1(fwd_exmem_rd_w1), .fwd_exmem_we_w1(fwd_exmem_we_w1),
    .fwd_exmem_result_w2(fwd_exmem_result_w2), .fwd_exmem_rd_w2(fwd_exmem_rd_w2), .fwd_exmem_we_w2(fwd_exmem_we_w2),
    .fwd_memwb_result_w1(fwd_memwb_result_w1), .fwd_memwb_rd_w1(fwd_memwb_rd_w1), .fwd_memwb_we_w1(fwd_memwb_we_w1),
    .fwd_memwb_result_w2(fwd_memwb_result_w2), .fwd_memwb_rd_w2(fwd_memwb_rd_w2), .fwd_memwb_we_w2(fwd_memwb_we_w2),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .pc_w1_o(pc_w1_o), .alu_result_w1_o(alu_result_w1_o), .rs2_data_w1_o(rs2_data_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o),
    .mem_read_en_w1_o(mem_read_en_w1_o), .mem_write_en_w1_o(mem_write_en_w1_o),
    .mem_size_w1_o(mem_size_w1_o),
    .reg_write_en_w1_o(reg_write_en_w1_o), .wb_sel_w1_o(wb_sel_w1_o), .valid_w1_o(valid_w1_o),
    .pc_w2_o(pc_w2_o), .alu_result_w2_o(alu_result_w2_o), .rs2_data_w2_o(rs2_data_w2_o),
    .rd_addr_w2_o(rd_addr_w2_o),
    .mem_read_en_w2_o(mem_read_en_w2_o), .mem_write_en_w2_o(mem_write_en_w2_o),
    .mem_size_w2_o(mem_size_w2_o),
    .reg_write_en_w2_o(reg_write_en_w2_o), .wb_sel_w2_o(wb_sel_w2_o), .valid_w2_o(valid_w2_o),
    .branch_taken_o(branch_taken_o), .branch_target_o(branch_target_o), .mispredict_o(mispredict_o)
);

always #5 clk = ~clk;

task check;
    input cond;
    input [255:0] msg;
begin
    if (!cond) begin
        $display("[FAIL] %0s", msg);
        errors = errors + 1;
    end
end
endtask

task clear_fwd;
begin
    fwd_exmem_result_w1 = 64'd0; fwd_exmem_rd_w1 = 5'd0; fwd_exmem_we_w1 = 0;
    fwd_exmem_result_w2 = 64'd0; fwd_exmem_rd_w2 = 5'd0; fwd_exmem_we_w2 = 0;
    fwd_memwb_result_w1 = 64'd0; fwd_memwb_rd_w1 = 5'd0; fwd_memwb_we_w1 = 0;
    fwd_memwb_result_w2 = 64'd0; fwd_memwb_rd_w2 = 5'd0; fwd_memwb_we_w2 = 0;
end
endtask

initial begin
    clk = 0; rst_n = 0; flush = 0; errors = 0;

    pc_w1_i = 64'h1000; rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2;
    rs1_data_w1_i = 64'd10; rs2_data_w1_i = 64'd20;
    rd_addr_w1_i = 5'd3; imm_w1_i = 64'd0;
    alu_op_w1_i = 4'b0000; alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    mem_read_en_w1_i = 0; mem_write_en_w1_i = 0; mem_size_w1_i = 3'b000;
    reg_write_en_w1_i = 1; wb_sel_w1_i = 2'b00;
    is_branch_w1_i = 0; is_jump_w1_i = 0;
    is_muldiv_w1_i = 0; muldiv_funct3_w1_i = 3'b000; valid_w1_i = 0;

    pc_w2_i = 64'h1004; rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5;
    rs1_data_w2_i = 64'd30; rs2_data_w2_i = 64'd40;
    rd_addr_w2_i = 5'd6; imm_w2_i = 64'd0;
    alu_op_w2_i = 4'b0000; alu_src1_sel_w2_i = 0; alu_src2_sel_w2_i = 0;
    mem_read_en_w2_i = 0; mem_write_en_w2_i = 0; mem_size_w2_i = 3'b000;
    reg_write_en_w2_i = 1; wb_sel_w2_i = 2'b00;
    is_branch_w2_i = 0; is_jump_w2_i = 0;
    is_muldiv_w2_i = 0; muldiv_funct3_w2_i = 3'b000; valid_w2_i = 0;

    predict_taken_i = 0; predict_target_i = 64'd0;
    clear_fwd();

    #12 rst_n = 1;

    // === Test 1: No forwarding — ALU uses register file values ===
    valid_w1_i = 1;
    // ADD: rs1=10, rs2=20 → result=30
    alu_op_w1_i = 4'b0000; alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd30, "T1: no fwd ADD 10+20=30");

    // === Test 2: EX/MEM Way1 forwarding to Way1 rs1 ===
    // EX/MEM Way1 wrote rd=x3, value=100; current instr reads rs1=x3
    clear_fwd();
    rs1_addr_w1_i = 5'd3; rs1_data_w1_i = 64'd5; // stale value 5
    fwd_exmem_result_w1 = 64'd100; fwd_exmem_rd_w1 = 5'd3; fwd_exmem_we_w1 = 1;
    alu_op_w1_i = 4'b0000; alu_src2_sel_w1_i = 0; rs2_data_w1_i = 64'd7;
    valid_w1_i = 1;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd107, "T2: fwd EX/MEM Way1 → rs1 (100+7=107)");

    // === Test 3: EX/MEM Way2 forwarding to Way1 rs1 ===
    clear_fwd();
    rs1_addr_w1_i = 5'd7; rs1_data_w1_i = 64'd5;
    fwd_exmem_result_w2 = 64'd200; fwd_exmem_rd_w2 = 5'd7; fwd_exmem_we_w2 = 1;
    rs2_data_w1_i = 64'd3;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd203, "T3: fwd EX/MEM Way2 → rs1 (200+3=203)");

    // === Test 4: MEM/WB Way1 forwarding (lower priority) ===
    clear_fwd();
    rs1_addr_w1_i = 5'd8; rs1_data_w1_i = 64'd5;
    fwd_memwb_result_w1 = 64'd300; fwd_memwb_rd_w1 = 5'd8; fwd_memwb_we_w1 = 1;
    rs2_data_w1_i = 64'd4;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd304, "T4: fwd MEM/WB Way1 → rs1 (300+4=304)");

    // === Test 5: MEM/WB Way2 forwarding (lowest priority) ===
    clear_fwd();
    rs1_addr_w1_i = 5'd9; rs1_data_w1_i = 64'd5;
    fwd_memwb_result_w2 = 64'd400; fwd_memwb_rd_w2 = 5'd9; fwd_memwb_we_w2 = 1;
    rs2_data_w1_i = 64'd6;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd406, "T5: fwd MEM/WB Way2 → rs1 (400+6=406)");

    // === Test 6: Priority test — EX/MEM Way1 beats MEM/WB Way1 ===
    clear_fwd();
    rs1_addr_w1_i = 5'd3; rs1_data_w1_i = 64'd5;
    // Both EX/MEM Way1 and MEM/WB Way1 write to x3
    fwd_exmem_result_w1 = 64'd100; fwd_exmem_rd_w1 = 5'd3; fwd_exmem_we_w1 = 1;
    fwd_memwb_result_w1 = 64'd999; fwd_memwb_rd_w1 = 5'd3; fwd_memwb_we_w1 = 1;
    rs2_data_w1_i = 64'd0;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd100, "T6: EX/MEM Way1 priority over MEM/WB Way1");

    // === Test 7: EX/MEM Way1 priority over EX/MEM Way2 ===
    clear_fwd();
    rs1_addr_w1_i = 5'd5; rs1_data_w1_i = 64'd5;
    fwd_exmem_result_w1 = 64'd111; fwd_exmem_rd_w1 = 5'd5; fwd_exmem_we_w1 = 1;
    fwd_exmem_result_w2 = 64'd222; fwd_exmem_rd_w2 = 5'd5; fwd_exmem_we_w2 = 1;
    rs2_data_w1_i = 64'd0;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd111, "T7: EX/MEM Way1 priority over Way2");

    // === Test 8: Forwarding to Way2 rs1 ===
    clear_fwd();
    rs1_addr_w2_i = 5'd10; rs1_data_w2_i = 64'd5;
    fwd_exmem_result_w1 = 64'd777; fwd_exmem_rd_w1 = 5'd10; fwd_exmem_we_w1 = 1;
    rs2_data_w2_i = 64'd3;
    valid_w2_i = 1; valid_w1_i = 0;
    @(posedge clk); #1;
    check(alu_result_w2_o == 64'd780, "T8: fwd EX/MEM Way1 → Way2 rs1 (777+3=780)");

    // === Test 9: No forwarding to x0 ===
    clear_fwd();
    rs1_addr_w1_i = 5'd0; rs1_data_w1_i = 64'd0;
    fwd_exmem_result_w1 = 64'd999; fwd_exmem_rd_w1 = 5'd0; fwd_exmem_we_w1 = 1;
    rs2_data_w1_i = 64'd42;
    valid_w1_i = 1; valid_w2_i = 0;
    alu_op_w1_i = 4'b0000;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd42, "T9: no fwd when rd=x0 (0+42=42)");

    // === Test 10: rs2 forwarding ===
    clear_fwd();
    rs1_addr_w1_i = 5'd1; rs1_data_w1_i = 64'd10;
    rs2_addr_w1_i = 5'd4; rs2_data_w1_i = 64'd5;
    fwd_exmem_result_w1 = 64'd55; fwd_exmem_rd_w1 = 5'd4; fwd_exmem_we_w1 = 1;
    alu_op_w1_i = 4'b0000; alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    valid_w1_i = 1;
    @(posedge clk); #1;
    check(alu_result_w1_o == 64'd65, "T10: fwd EX/MEM to rs2 (10+55=65)");

    if (errors == 0) $display("[PASS] tb_forwarding");
    else $display("[FAIL] tb_forwarding errors=%0d", errors);
    $finish;
end

endmodule