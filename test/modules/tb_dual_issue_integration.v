`timescale 1ns / 1ps

module tb_dual_issue_integration;

reg clk;
reg rst_n;

// Simplified integration test: exercise II ➜ EX pipeline for dual-issue
// with register file, similar to a micro-end-to-end test

// II Stage signals
reg flush_ii;

reg [63:0] pc_w1_i, pc_w2_i;
reg [4:0]  rs1_addr_w1_i, rs2_addr_w1_i, rd_addr_w1_i;
reg [4:0]  rs1_addr_w2_i, rs2_addr_w2_i, rd_addr_w2_i;
reg [63:0] imm_w1_i, imm_w2_i;
reg [3:0]  alu_op_w1_i, alu_op_w2_i;
reg        alu_src1_sel_w1_i, alu_src2_sel_w1_i;
reg        alu_src1_sel_w2_i, alu_src2_sel_w2_i;
reg        mem_read_en_w1_i, mem_write_en_w1_i, mem_read_en_w2_i, mem_write_en_w2_i;
reg [2:0]  mem_size_w1_i, mem_size_w2_i;
reg        reg_write_en_w1_i, reg_write_en_w2_i;
reg [1:0]  wb_sel_w1_i, wb_sel_w2_i;
reg        is_branch_w1_i, is_jump_w1_i, is_branch_w2_i, is_jump_w2_i;
reg        is_system_w1_i, is_system_w2_i;
reg        is_mem_op_w1_i, is_mem_op_w2_i;
reg        is_muldiv_w1_i, is_muldiv_w2_i;
reg [2:0]  muldiv_funct3_w1_i, muldiv_funct3_w2_i;
reg        uses_rs1_w1_i, uses_rs2_w1_i, uses_rs1_w2_i, uses_rs2_w2_i;
reg        valid_w1_i, valid_w2_i;
reg        predict_taken_i;
reg [63:0] predict_target_i;

// EX Stage forwarding inputs (directly driven)
reg [63:0] fwd_exmem_result_w1; reg [4:0] fwd_exmem_rd_w1; reg fwd_exmem_we_w1;
reg [63:0] fwd_exmem_result_w2; reg [4:0] fwd_exmem_rd_w2; reg fwd_exmem_we_w2;
reg [63:0] fwd_memwb_result_w1; reg [4:0] fwd_memwb_rd_w1; reg fwd_memwb_we_w1;
reg [63:0] fwd_memwb_result_w2; reg [4:0] fwd_memwb_rd_w2; reg fwd_memwb_we_w2;

// Register file
wire [4:0]  rf_raddr1, rf_raddr2, rf_raddr3, rf_raddr4;
wire [63:0] rf_rdata1, rf_rdata2, rf_rdata3, rf_rdata4;
reg [4:0]  rf_waddr1, rf_waddr2;
reg [63:0] rf_wdata1, rf_wdata2;
reg        rf_we1, rf_we2;

// II Stage outputs
wire       stall_dual;
wire [63:0] ii_pc_w1_o, ii_pc_w2_o;
wire [4:0]  ii_rs1_addr_w1_o, ii_rs2_addr_w1_o, ii_rd_addr_w1_o;
wire [63:0] ii_rs1_data_w1_o, ii_rs2_data_w1_o;
wire [63:0] ii_imm_w1_o;
wire [3:0]  ii_alu_op_w1_o;
wire        ii_alu_src1_sel_w1_o, ii_alu_src2_sel_w1_o;
wire        ii_mem_read_en_w1_o, ii_mem_write_en_w1_o;
wire [2:0]  ii_mem_size_w1_o;
wire        ii_reg_write_en_w1_o, ii_valid_w1_o;
wire [1:0]  ii_wb_sel_w1_o;
wire        ii_is_branch_w1_o, ii_is_jump_w1_o;
wire        ii_is_muldiv_w1_o;
wire [2:0]  ii_muldiv_funct3_w1_o;
wire [4:0]  ii_rs1_addr_w2_o, ii_rs2_addr_w2_o, ii_rd_addr_w2_o;
wire [63:0] ii_rs1_data_w2_o, ii_rs2_data_w2_o;
wire [63:0] ii_imm_w2_o;
wire [3:0]  ii_alu_op_w2_o;
wire        ii_alu_src1_sel_w2_o, ii_alu_src2_sel_w2_o;
wire        ii_mem_read_en_w2_o, ii_mem_write_en_w2_o;
wire [2:0]  ii_mem_size_w2_o;
wire        ii_reg_write_en_w2_o, ii_valid_w2_o;
wire [1:0]  ii_wb_sel_w2_o;
wire        ii_is_branch_w2_o, ii_is_jump_w2_o;
wire        ii_is_muldiv_w2_o;
wire [2:0]  ii_muldiv_funct3_w2_o;

// EX Stage outputs
wire [63:0] ex_pc_w1_o, ex_alu_result_w1_o, ex_rs2_data_w1_o;
wire [4:0]  ex_rd_addr_w1_o;
wire        ex_mem_read_en_w1_o, ex_mem_write_en_w1_o;
wire        ex_reg_write_en_w1_o, ex_valid_w1_o;
wire [2:0]  ex_mem_size_w1_o;
wire [1:0]  ex_wb_sel_w1_o;
wire [63:0] ex_pc_w2_o, ex_alu_result_w2_o, ex_rs2_data_w2_o;
wire [4:0]  ex_rd_addr_w2_o;
wire        ex_mem_read_en_w2_o, ex_mem_write_en_w2_o;
wire        ex_reg_write_en_w2_o, ex_valid_w2_o;
wire [2:0]  ex_mem_size_w2_o;
wire [1:0]  ex_wb_sel_w2_o;
wire        ex_branch_taken_o;
wire [63:0] ex_branch_target_o;
wire        ex_mispredict_o;

integer errors;

register_file #(.DATA_WIDTH(64), .REG_COUNT(32), .ADDR_WIDTH(5)) u_rf (
    .clk(clk), .rst_n(rst_n),
    .raddr1(rf_raddr1), .rdata1(rf_rdata1),
    .raddr2(rf_raddr2), .rdata2(rf_rdata2),
    .raddr3(rf_raddr3), .rdata3(rf_rdata3),
    .raddr4(rf_raddr4), .rdata4(rf_rdata4),
    .waddr1(rf_waddr1), .wdata1(rf_wdata1), .we1(rf_we1),
    .waddr2(rf_waddr2), .wdata2(rf_wdata2), .we2(rf_we2)
);

ii_stage #(.DATA_WIDTH(64), .ADDR_WIDTH(64)) u_ii (
    .clk(clk), .rst_n(rst_n), .flush(flush_ii),
    .pc_w1_i(pc_w1_i), .rs1_addr_w1_i(rs1_addr_w1_i), .rs2_addr_w1_i(rs2_addr_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i), .imm_w1_i(imm_w1_i), .alu_op_w1_i(alu_op_w1_i),
    .alu_src1_sel_w1_i(alu_src1_sel_w1_i), .alu_src2_sel_w1_i(alu_src2_sel_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i), .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i), .reg_write_en_w1_i(reg_write_en_w1_i),
    .wb_sel_w1_i(wb_sel_w1_i), .is_branch_w1_i(is_branch_w1_i), .is_jump_w1_i(is_jump_w1_i),
    .is_system_w1_i(is_system_w1_i), .is_mem_op_w1_i(is_mem_op_w1_i),
    .is_muldiv_w1_i(is_muldiv_w1_i), .muldiv_funct3_w1_i(muldiv_funct3_w1_i),
    .uses_rs1_w1_i(uses_rs1_w1_i), .uses_rs2_w1_i(uses_rs2_w1_i), .valid_w1_i(valid_w1_i),
    .pc_w2_i(pc_w2_i), .rs1_addr_w2_i(rs1_addr_w2_i), .rs2_addr_w2_i(rs2_addr_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i), .imm_w2_i(imm_w2_i), .alu_op_w2_i(alu_op_w2_i),
    .alu_src1_sel_w2_i(alu_src1_sel_w2_i), .alu_src2_sel_w2_i(alu_src2_sel_w2_i),
    .mem_read_en_w2_i(mem_read_en_w2_i), .mem_write_en_w2_i(mem_write_en_w2_i),
    .mem_size_w2_i(mem_size_w2_i), .reg_write_en_w2_i(reg_write_en_w2_i),
    .wb_sel_w2_i(wb_sel_w2_i), .is_branch_w2_i(is_branch_w2_i), .is_jump_w2_i(is_jump_w2_i),
    .is_system_w2_i(is_system_w2_i), .is_mem_op_w2_i(is_mem_op_w2_i),
    .is_muldiv_w2_i(is_muldiv_w2_i), .muldiv_funct3_w2_i(muldiv_funct3_w2_i),
    .uses_rs1_w2_i(uses_rs1_w2_i), .uses_rs2_w2_i(uses_rs2_w2_i), .valid_w2_i(valid_w2_i),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .rf_raddr1(rf_raddr1), .rf_rdata1(rf_rdata1),
    .rf_raddr2(rf_raddr2), .rf_rdata2(rf_rdata2),
    .rf_raddr3(rf_raddr3), .rf_rdata3(rf_rdata3),
    .rf_raddr4(rf_raddr4), .rf_rdata4(rf_rdata4),
    .stall_dual(stall_dual),
    .pc_w1_o(ii_pc_w1_o), .rs1_addr_w1_o(ii_rs1_addr_w1_o), .rs2_addr_w1_o(ii_rs2_addr_w1_o),
    .rs1_data_w1_o(ii_rs1_data_w1_o), .rs2_data_w1_o(ii_rs2_data_w1_o),
    .rd_addr_w1_o(ii_rd_addr_w1_o), .imm_w1_o(ii_imm_w1_o), .alu_op_w1_o(ii_alu_op_w1_o),
    .alu_src1_sel_w1_o(ii_alu_src1_sel_w1_o), .alu_src2_sel_w1_o(ii_alu_src2_sel_w1_o),
    .mem_read_en_w1_o(ii_mem_read_en_w1_o), .mem_write_en_w1_o(ii_mem_write_en_w1_o),
    .mem_size_w1_o(ii_mem_size_w1_o), .reg_write_en_w1_o(ii_reg_write_en_w1_o),
    .wb_sel_w1_o(ii_wb_sel_w1_o), .is_branch_w1_o(ii_is_branch_w1_o), .is_jump_w1_o(ii_is_jump_w1_o),
    .is_muldiv_w1_o(ii_is_muldiv_w1_o), .muldiv_funct3_w1_o(ii_muldiv_funct3_w1_o), .valid_w1_o(ii_valid_w1_o),
    .pc_w2_o(ii_pc_w2_o), .rs1_addr_w2_o(ii_rs1_addr_w2_o), .rs2_addr_w2_o(ii_rs2_addr_w2_o),
    .rs1_data_w2_o(ii_rs1_data_w2_o), .rs2_data_w2_o(ii_rs2_data_w2_o),
    .rd_addr_w2_o(ii_rd_addr_w2_o), .imm_w2_o(ii_imm_w2_o), .alu_op_w2_o(ii_alu_op_w2_o),
    .alu_src1_sel_w2_o(ii_alu_src1_sel_w2_o), .alu_src2_sel_w2_o(ii_alu_src2_sel_w2_o),
    .mem_read_en_w2_o(ii_mem_read_en_w2_o), .mem_write_en_w2_o(ii_mem_write_en_w2_o),
    .mem_size_w2_o(ii_mem_size_w2_o), .reg_write_en_w2_o(ii_reg_write_en_w2_o),
    .wb_sel_w2_o(ii_wb_sel_w2_o), .is_branch_w2_o(ii_is_branch_w2_o), .is_jump_w2_o(ii_is_jump_w2_o),
    .is_muldiv_w2_o(ii_is_muldiv_w2_o), .muldiv_funct3_w2_o(ii_muldiv_funct3_w2_o), .valid_w2_o(ii_valid_w2_o),
    .predict_taken_o(), .predict_target_o()
);

ex_stage #(.DATA_WIDTH(64), .ADDR_WIDTH(64)) u_ex (
    .clk(clk), .rst_n(rst_n), .flush(1'b0),
    .pc_w1_i(ii_pc_w1_o),
    .rs1_addr_w1_i(ii_rs1_addr_w1_o), .rs2_addr_w1_i(ii_rs2_addr_w1_o),
    .rs1_data_w1_i(ii_rs1_data_w1_o), .rs2_data_w1_i(ii_rs2_data_w1_o),
    .rd_addr_w1_i(ii_rd_addr_w1_o), .imm_w1_i(ii_imm_w1_o), .alu_op_w1_i(ii_alu_op_w1_o),
    .alu_src1_sel_w1_i(ii_alu_src1_sel_w1_o), .alu_src2_sel_w1_i(ii_alu_src2_sel_w1_o),
    .mem_read_en_w1_i(ii_mem_read_en_w1_o), .mem_write_en_w1_i(ii_mem_write_en_w1_o),
    .mem_size_w1_i(ii_mem_size_w1_o), .reg_write_en_w1_i(ii_reg_write_en_w1_o),
    .wb_sel_w1_i(ii_wb_sel_w1_o), .is_branch_w1_i(ii_is_branch_w1_o), .is_jump_w1_i(ii_is_jump_w1_o),
    .is_muldiv_w1_i(ii_is_muldiv_w1_o), .muldiv_funct3_w1_i(ii_muldiv_funct3_w1_o), .valid_w1_i(ii_valid_w1_o),
    .pc_w2_i(ii_pc_w2_o),
    .rs1_addr_w2_i(ii_rs1_addr_w2_o), .rs2_addr_w2_i(ii_rs2_addr_w2_o),
    .rs1_data_w2_i(ii_rs1_data_w2_o), .rs2_data_w2_i(ii_rs2_data_w2_o),
    .rd_addr_w2_i(ii_rd_addr_w2_o), .imm_w2_i(ii_imm_w2_o), .alu_op_w2_i(ii_alu_op_w2_o),
    .alu_src1_sel_w2_i(ii_alu_src1_sel_w2_o), .alu_src2_sel_w2_i(ii_alu_src2_sel_w2_o),
    .mem_read_en_w2_i(ii_mem_read_en_w2_o), .mem_write_en_w2_i(ii_mem_write_en_w2_o),
    .mem_size_w2_i(ii_mem_size_w2_o), .reg_write_en_w2_i(ii_reg_write_en_w2_o),
    .wb_sel_w2_i(ii_wb_sel_w2_o), .is_branch_w2_i(ii_is_branch_w2_o), .is_jump_w2_i(ii_is_jump_w2_o),
    .is_muldiv_w2_i(ii_is_muldiv_w2_o), .muldiv_funct3_w2_i(ii_muldiv_funct3_w2_o), .valid_w2_i(ii_valid_w2_o),
    .fwd_exmem_result_w1(fwd_exmem_result_w1), .fwd_exmem_rd_w1(fwd_exmem_rd_w1), .fwd_exmem_we_w1(fwd_exmem_we_w1),
    .fwd_exmem_result_w2(fwd_exmem_result_w2), .fwd_exmem_rd_w2(fwd_exmem_rd_w2), .fwd_exmem_we_w2(fwd_exmem_we_w2),
    .fwd_memwb_result_w1(fwd_memwb_result_w1), .fwd_memwb_rd_w1(fwd_memwb_rd_w1), .fwd_memwb_we_w1(fwd_memwb_we_w1),
    .fwd_memwb_result_w2(fwd_memwb_result_w2), .fwd_memwb_rd_w2(fwd_memwb_rd_w2), .fwd_memwb_we_w2(fwd_memwb_we_w2),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .pc_w1_o(ex_pc_w1_o), .alu_result_w1_o(ex_alu_result_w1_o), .rs2_data_w1_o(ex_rs2_data_w1_o),
    .rd_addr_w1_o(ex_rd_addr_w1_o),
    .mem_read_en_w1_o(ex_mem_read_en_w1_o), .mem_write_en_w1_o(ex_mem_write_en_w1_o),
    .mem_size_w1_o(ex_mem_size_w1_o), .reg_write_en_w1_o(ex_reg_write_en_w1_o),
    .wb_sel_w1_o(ex_wb_sel_w1_o), .valid_w1_o(ex_valid_w1_o),
    .pc_w2_o(ex_pc_w2_o), .alu_result_w2_o(ex_alu_result_w2_o), .rs2_data_w2_o(ex_rs2_data_w2_o),
    .rd_addr_w2_o(ex_rd_addr_w2_o),
    .mem_read_en_w2_o(ex_mem_read_en_w2_o), .mem_write_en_w2_o(ex_mem_write_en_w2_o),
    .mem_size_w2_o(ex_mem_size_w2_o), .reg_write_en_w2_o(ex_reg_write_en_w2_o),
    .wb_sel_w2_o(ex_wb_sel_w2_o), .valid_w2_o(ex_valid_w2_o),
    .branch_taken_o(ex_branch_taken_o), .branch_target_o(ex_branch_target_o), .mispredict_o(ex_mispredict_o)
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

initial begin
    clk = 0; rst_n = 0; flush_ii = 0; errors = 0;

    // Initialize all II stage inputs
    pc_w1_i = 64'h1000; pc_w2_i = 64'h1004;
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    imm_w1_i = 64'd0; alu_op_w1_i = 4'b0000;
    alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    mem_read_en_w1_i = 0; mem_write_en_w1_i = 0; mem_size_w1_i = 3'b000;
    reg_write_en_w1_i = 1; wb_sel_w1_i = 2'b00;
    is_branch_w1_i = 0; is_jump_w1_i = 0;
    is_system_w1_i = 0; is_mem_op_w1_i = 0;
    is_muldiv_w1_i = 0; muldiv_funct3_w1_i = 3'b000;
    uses_rs1_w1_i = 1; uses_rs2_w1_i = 1; valid_w1_i = 0;

    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd6;
    imm_w2_i = 64'd0; alu_op_w2_i = 4'b0000;
    alu_src1_sel_w2_i = 0; alu_src2_sel_w2_i = 0;
    mem_read_en_w2_i = 0; mem_write_en_w2_i = 0; mem_size_w2_i = 3'b000;
    reg_write_en_w2_i = 1; wb_sel_w2_i = 2'b00;
    is_branch_w2_i = 0; is_jump_w2_i = 0;
    is_system_w2_i = 0; is_mem_op_w2_i = 0;
    is_muldiv_w2_i = 0; muldiv_funct3_w2_i = 3'b000;
    uses_rs1_w2_i = 1; uses_rs2_w2_i = 1; valid_w2_i = 0;

    predict_taken_i = 0; predict_target_i = 64'd0;

    // Clear forwarding
    fwd_exmem_result_w1 = 64'd0; fwd_exmem_rd_w1 = 5'd0; fwd_exmem_we_w1 = 0;
    fwd_exmem_result_w2 = 64'd0; fwd_exmem_rd_w2 = 5'd0; fwd_exmem_we_w2 = 0;
    fwd_memwb_result_w1 = 64'd0; fwd_memwb_rd_w1 = 5'd0; fwd_memwb_we_w1 = 0;
    fwd_memwb_result_w2 = 64'd0; fwd_memwb_rd_w2 = 5'd0; fwd_memwb_we_w2 = 0;

    // Write register values: x1=10, x2=20, x4=5, x5=7
    rf_waddr1 = 5'd0; rf_wdata1 = 64'd0; rf_we1 = 0;
    rf_waddr2 = 5'd0; rf_wdata2 = 64'd0; rf_we2 = 0;

    #12 rst_n = 1;

    // Preload registers
    @(posedge clk);
    rf_we1 = 1; rf_waddr1 = 5'd1; rf_wdata1 = 64'd10;
    @(posedge clk);
    rf_waddr1 = 5'd2; rf_wdata1 = 64'd20;
    @(posedge clk);
    rf_waddr1 = 5'd4; rf_wdata1 = 64'd5;
    @(posedge clk);
    rf_waddr1 = 5'd5; rf_wdata1 = 64'd7;
    @(posedge clk);
    rf_we1 = 0;

    // === Test 1: Dual-issue independent instructions ===
    // Way1: ADD x3, x1, x2 (x1=10, x2=20 → x3=30)
    // Way2: ADD x6, x4, x5 (x4=5, x5=7 → x6=12)
    valid_w1_i = 1; valid_w2_i = 1;
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    alu_op_w1_i = 4'b0000; // ADD
    alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    reg_write_en_w1_i = 1;
    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd6;
    alu_op_w2_i = 4'b0000;
    alu_src1_sel_w2_i = 0; alu_src2_sel_w2_i = 0;
    reg_write_en_w2_i = 1;
    uses_rs1_w1_i = 1; uses_rs2_w1_i = 1;
    uses_rs1_w2_i = 1; uses_rs2_w2_i = 1;

    #1;
    check(stall_dual == 1'b0, "T1: no stall for independent dual-issue");

    // II stage latches data on next clock edge, then EX stage latches on the following edge
    @(posedge clk); #1; // II stage captures inputs
    @(posedge clk); #1; // EX stage captures II output
    check(ex_valid_w1_o == 1'b1, "T1: EX Way1 valid");
    check(ex_valid_w2_o == 1'b1, "T1: EX Way2 valid");
    check(ex_alu_result_w1_o == 64'd30, "T1: EX Way1 ADD 10+20=30");
    check(ex_alu_result_w2_o == 64'd12, "T1: EX Way2 ADD 5+7=12");

    // === Test 2: RAW hazard detection at II stage ===
    // Way1: ADD x3, x1, x2  (writes x3)
    // Way2: ADD x7, x3, x4  (reads x3 — RAW hazard!)
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    rs1_addr_w2_i = 5'd3; rs2_addr_w2_i = 5'd4; rd_addr_w2_i = 5'd7;
    reg_write_en_w1_i = 1; reg_write_en_w2_i = 1;
    uses_rs1_w2_i = 1;
    #1;
    check(stall_dual == 1'b1, "T2: RAW hazard detected — stall_dual=1");
    // Only Way1 should be issued as slot1
    // After stall resolves, Way2 becomes slot1 next cycle

    // === Test 3: WAW hazard detection at II stage ===
    // Way1: ADD x3, x1, x2  (writes x3)
    // Way2: SUB x3, x4, x5  (also writes x3 — WAW hazard!)
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd3;
    reg_write_en_w1_i = 1; reg_write_en_w2_i = 1;
    uses_rs1_w2_i = 1; uses_rs2_w2_i = 1;
    #1;
    check(stall_dual == 1'b1, "T3: WAW hazard detected — stall_dual=1");

    // === Test 4: Control hazard — branch in Way1 blocks dual issue ===
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    is_branch_w1_i = 1; is_mem_op_w1_i = 0;
    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd6;
    reg_write_en_w1_i = 1; reg_write_en_w2_i = 1;
    uses_rs1_w1_i = 1; uses_rs2_w1_i = 1; uses_rs1_w2_i = 1; uses_rs2_w2_i = 1;
    #1;
    check(stall_dual == 1'b1, "T4: Branch in Way1 blocks dual-issue");

    // === Test 5: Struct hazard — both mem ops ===
    is_branch_w1_i = 0;
    is_mem_op_w1_i = 1; is_mem_op_w2_i = 1;
    #1;
    check(stall_dual == 1'b1, "T5: Dual mem ops → struct hazard");

    // === Test 6: Flush clears EX outputs ===
    is_mem_op_w1_i = 0; is_mem_op_w2_i = 0;
    valid_w1_i = 1; valid_w2_i = 1;
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd6;
    @(posedge clk); #1; // II captures
    @(posedge clk); #1; // EX captures
    check(ex_valid_w1_o == 1'b1, "T6: EX valid before flush");
    flush_ii = 1;
    valid_w1_i = 0; valid_w2_i = 0;
    @(posedge clk); #1; // II flushes, EX gets flushed values
    @(posedge clk); #1; // EX output from flushed cycle
    check(ex_valid_w1_o == 1'b0, "T6a: EX Way1 invalid after II flush");
    check(ex_valid_w2_o == 1'b0, "T6b: EX Way2 invalid after II flush");
    flush_ii = 0;

    // === Test 7: Load-Use hazard unit interaction (standalone) ===
    // Verify that EX produces correct mem_read_en for a load instruction
    valid_w1_i = 1; valid_w2_i = 0;
    mem_read_en_w1_i = 1;
    rs1_addr_w1_i = 5'd1; imm_w1_i = 64'd4; rd_addr_w1_i = 5'd7;
    alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 1; // LW: use immediate
    reg_write_en_w1_i = 1;
    @(posedge clk); #1; // II captures
    @(posedge clk); #1; // EX captures
    check(ex_mem_read_en_w1_o == 1'b1, "T7: Load produces mem_read_en in EX");

    if (errors == 0) $display("[PASS] tb_dual_issue_integration");
    else $display("[FAIL] tb_dual_issue_integration errors=%0d", errors);
    $finish;
end

endmodule