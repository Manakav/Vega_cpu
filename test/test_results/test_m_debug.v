`timescale 1ns / 1ps
module test_m_debug;
reg clk, rst_n, flush;
reg [63:0] rs1_data_w1_i, rs2_data_w1_i;
reg [4:0] rs1_addr_w1_i, rs2_addr_w1_i, rd_addr_w1_i;
reg [63:0] imm_w1_i;
reg [3:0] alu_op_w1_i;
reg alu_src1_sel_w1_i, alu_src2_sel_w1_i;
reg mem_read_en_w1_i, mem_write_en_w1_i;
reg [2:0] mem_size_w1_i;
reg reg_write_en_w1_i;
reg [1:0] wb_sel_w1_i;
reg is_branch_w1_i, is_jump_w1_i, is_muldiv_w1_i;
reg [2:0] muldiv_funct3_w1_i;
reg valid_w1_i;
reg [63:0] pc_w1_i;
reg [4:0] rs1_addr_w2_i, rs2_addr_w2_i, rd_addr_w2_i;
reg [63:0] rs1_data_w2_i, rs2_data_w2_i, imm_w2_i;
reg [3:0] alu_op_w2_i;
reg alu_src1_sel_w2_i, alu_src2_sel_w2_i;
reg mem_read_en_w2_i, mem_write_en_w2_i;
reg [2:0] mem_size_w2_i;
reg reg_write_en_w2_i;
reg [1:0] wb_sel_w2_i;
reg is_branch_w2_i, is_jump_w2_i, is_muldiv_w2_i;
reg [2:0] muldiv_funct3_w2_i;
reg valid_w2_i;
reg [63:0] fwd_exmem_result_w1; reg [4:0] fwd_exmem_rd_w1; reg fwd_exmem_we_w1;
reg [63:0] fwd_exmem_result_w2; reg [4:0] fwd_exmem_rd_w2; reg fwd_exmem_we_w2;
reg [63:0] fwd_memwb_result_w1; reg [4:0] fwd_memwb_rd_w1; reg fwd_memwb_we_w1;
reg [63:0] fwd_memwb_result_w2; reg [4:0] fwd_memwb_rd_w2; reg fwd_memwb_we_w2;
reg predict_taken_i;
reg [63:0] predict_target_i;
wire [63:0] pc_w1_o, alu_result_w1_o, rs2_data_w1_o;
wire [4:0] rd_addr_w1_o;
wire mem_read_en_w1_o, mem_write_en_w1_o, reg_write_en_w1_o, valid_w1_o;
wire [2:0] mem_size_w1_o;
wire [1:0] wb_sel_w1_o;
wire [63:0] alu_result_w2_o;
wire valid_w2_o, branch_taken_o, mispredict_o;

ex_stage #(.DATA_WIDTH(64), .ADDR_WIDTH(64)) dut (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .pc_w1_i(pc_w1_i), .rs1_addr_w1_i(rs1_addr_w1_i), .rs2_addr_w1_i(rs2_addr_w1_i),
    .rs1_data_w1_i(rs1_data_w1_i), .rs2_data_w1_i(rs2_data_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i), .imm_w1_i(imm_w1_i), .alu_op_w1_i(alu_op_w1_i),
    .alu_src1_sel_w1_i(alu_src1_sel_w1_i), .alu_src2_sel_w1_i(alu_src2_sel_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i), .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i), .reg_write_en_w1_i(reg_write_en_w1_i),
    .wb_sel_w1_i(wb_sel_w1_i), .is_branch_w1_i(is_branch_w1_i), .is_jump_w1_i(is_jump_w1_i),
    .is_muldiv_w1_i(is_muldiv_w1_i), .muldiv_funct3_w1_i(muldiv_funct3_w1_i), .valid_w1_i(valid_w1_i),
    .pc_w2_i(64'h1004), .rs1_addr_w2_i(rs1_addr_w2_i), .rs2_addr_w2_i(rs2_addr_w2_i),
    .rs1_data_w2_i(rs1_data_w2_i), .rs2_data_w2_i(rs2_data_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i), .imm_w2_i(imm_w2_i), .alu_op_w2_i(alu_op_w2_i),
    .alu_src1_sel_w2_i(alu_src1_sel_w2_i), .alu_src2_sel_w2_i(alu_src2_sel_w2_i),
    .mem_read_en_w2_i(mem_read_en_w2_i), .mem_write_en_w2_i(mem_write_en_w2_i),
    .mem_size_w2_i(mem_size_w2_i), .reg_write_en_w2_i(reg_write_en_w2_i),
    .wb_sel_w2_i(wb_sel_w2_i), .is_branch_w2_i(is_branch_w2_i), .is_jump_w2_i(is_jump_w2_i),
    .is_muldiv_w2_i(is_muldiv_w2_i), .muldiv_funct3_w2_i(muldiv_funct3_w2_i), .valid_w2_i(valid_w2_i),
    .fwd_exmem_result_w1(fwd_exmem_result_w1), .fwd_exmem_rd_w1(fwd_exmem_rd_w1), .fwd_exmem_we_w1(fwd_exmem_we_w1),
    .fwd_exmem_result_w2(fwd_exmem_result_w2), .fwd_exmem_rd_w2(fwd_exmem_rd_w2), .fwd_exmem_we_w2(fwd_exmem_we_w2),
    .fwd_memwb_result_w1(fwd_memwb_result_w1), .fwd_memwb_rd_w1(fwd_memwb_rd_w1), .fwd_memwb_we_w1(fwd_memwb_we_w1),
    .fwd_memwb_result_w2(fwd_memwb_result_w2), .fwd_memwb_rd_w2(fwd_memwb_rd_w2), .fwd_memwb_we_w2(fwd_memwb_we_w2),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .pc_w1_o(pc_w1_o), .alu_result_w1_o(alu_result_w1_o), .rs2_data_w1_o(rs2_data_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o),
    .mem_read_en_w1_o(mem_read_en_w1_o), .mem_write_en_w1_o(mem_write_en_w1_o),
    .mem_size_w1_o(mem_size_w1_o), .reg_write_en_w1_o(reg_write_en_w1_o), .wb_sel_w1_o(wb_sel_w1_o), .valid_w1_o(valid_w1_o),
    .pc_w2_o(), .alu_result_w2_o(alu_result_w2_o), .rs2_data_w2_o(), .rd_addr_w2_o(),
    .mem_read_en_w2_o(), .mem_write_en_w2_o(), .mem_size_w2_o(), .reg_write_en_w2_o(), .wb_sel_w2_o(), .valid_w2_o(valid_w2_o),
    .branch_taken_o(branch_taken_o), .branch_target_o(), .mispredict_o(mispredict_o)
);
always #5 clk = ~clk;
initial begin
    clk = 0; rst_n = 0; flush = 0;
    rs1_addr_w1_i = 5'd0; rs2_addr_w1_i = 5'd0; rd_addr_w1_i = 5'd3; pc_w1_i = 64'h1000;
    alu_op_w1_i = 4'b0000; alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    mem_read_en_w1_i = 0; mem_write_en_w1_i = 0; mem_size_w1_i = 3'b0;
    reg_write_en_w1_i = 1; wb_sel_w1_i = 2'b0; is_branch_w1_i = 0; is_jump_w1_i = 0;
    is_muldiv_w1_i = 0; muldiv_funct3_w1_i = 3'b0; valid_w1_i = 0;
    rs1_addr_w2_i = 5'd0; rs2_addr_w2_i = 5'd0; rd_addr_w2_i = 5'd0;
    rs1_data_w2_i = 64'd0; rs2_data_w2_i = 64'd0; imm_w2_i = 64'd0;
    alu_op_w2_i = 4'b0; alu_src1_sel_w2_i = 0; alu_src2_sel_w2_i = 0;
    mem_read_en_w2_i = 0; mem_write_en_w2_i = 0; mem_size_w2_i = 3'b0;
    reg_write_en_w2_i = 0; wb_sel_w2_i = 2'b0;
    is_branch_w2_i = 0; is_jump_w2_i = 0; is_muldiv_w2_i = 0; muldiv_funct3_w2_i = 3'b0; valid_w2_i = 0;
    fwd_exmem_result_w1 = 0; fwd_exmem_rd_w1 = 0; fwd_exmem_we_w1 = 0;
    fwd_exmem_result_w2 = 0; fwd_exmem_rd_w2 = 0; fwd_exmem_we_w2 = 0;
    fwd_memwb_result_w1 = 0; fwd_memwb_rd_w1 = 0; fwd_memwb_we_w1 = 0;
    fwd_memwb_result_w2 = 0; fwd_memwb_rd_w2 = 0; fwd_memwb_we_w2 = 0;
    predict_taken_i = 0; predict_target_i = 64'd0;
    #12 rst_n = 1;
    // DIV -16/4 = -4
    rs1_data_w1_i = 64'hFFFFFFFFFFFFFFF0; rs2_data_w1_i = 64'd4;
    is_muldiv_w1_i = 1; muldiv_funct3_w1_i = 3'b100;
    valid_w1_i = 1; alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    @(posedge clk); #1;
    $display("DIV result = %h", alu_result_w1_o);
    // REM -16%3
    rs1_data_w1_i = 64'hFFFFFFFFFFFFFFF0; rs2_data_w1_i = 64'd3;
    muldiv_funct3_w1_i = 3'b110;
    @(posedge clk); #1;
    $display("REM result = %h", alu_result_w1_o);
    // MULHSU -2^63 * 2
    rs1_data_w1_i = 64'h8000000000000000; rs2_data_w1_i = 64'd2;
    muldiv_funct3_w1_i = 3'b010;
    @(posedge clk); #1;
    $display("MULHSU result = %h", alu_result_w1_o);
    $finish;
end
endmodule