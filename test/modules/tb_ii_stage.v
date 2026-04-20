`timescale 1ns / 1ps

module tb_ii_stage;

reg clk;
reg rst_n;
reg flush;

// Way1 IDII inputs
reg [63:0] pc_w1_i;
reg [4:0]  rs1_addr_w1_i;
reg [4:0]  rs2_addr_w1_i;
reg [4:0]  rd_addr_w1_i;
reg [63:0] imm_w1_i;
reg [3:0]  alu_op_w1_i;
reg        alu_src1_sel_w1_i;
reg        alu_src2_sel_w1_i;
reg        mem_read_en_w1_i;
reg        mem_write_en_w1_i;
reg [2:0]  mem_size_w1_i;
reg        reg_write_en_w1_i;
reg [1:0]  wb_sel_w1_i;
reg        is_branch_w1_i;
reg        is_jump_w1_i;
reg        is_system_w1_i;
reg        is_mem_op_w1_i;
reg        is_muldiv_w1_i;
reg [2:0]  muldiv_funct3_w1_i;
reg        uses_rs1_w1_i;
reg        uses_rs2_w1_i;
reg        valid_w1_i;

// Way2 IDII inputs
reg [63:0] pc_w2_i;
reg [4:0]  rs1_addr_w2_i;
reg [4:0]  rs2_addr_w2_i;
reg [4:0]  rd_addr_w2_i;
reg [63:0] imm_w2_i;
reg [3:0]  alu_op_w2_i;
reg        alu_src1_sel_w2_i;
reg        alu_src2_sel_w2_i;
reg        mem_read_en_w2_i;
reg        mem_write_en_w2_i;
reg [2:0]  mem_size_w2_i;
reg        reg_write_en_w2_i;
reg [1:0]  wb_sel_w2_i;
reg        is_branch_w2_i;
reg        is_jump_w2_i;
reg        is_system_w2_i;
reg        is_mem_op_w2_i;
reg        is_muldiv_w2_i;
reg [2:0]  muldiv_funct3_w2_i;
reg        uses_rs1_w2_i;
reg        uses_rs2_w2_i;
reg        valid_w2_i;

reg        predict_taken_i;
reg [63:0] predict_target_i;

// Register file wires
wire [4:0]  rf_raddr1;
wire [63:0] rf_rdata1;
wire [4:0]  rf_raddr2;
wire [63:0] rf_rdata2;
wire [4:0]  rf_raddr3;
wire [63:0] rf_rdata3;
wire [4:0]  rf_raddr4;
wire [63:0] rf_rdata4;

// Register file inputs
reg [4:0]  rf_waddr1;
reg [63:0] rf_wdata1;
reg        rf_we1;
reg [4:0]  rf_waddr2;
reg [63:0] rf_wdata2;
reg        rf_we2;

// Outputs
wire       stall_dual;
wire [63:0] pc_w1_o;
wire [4:0]  rs1_addr_w1_o;
wire [4:0]  rs2_addr_w1_o;
wire [63:0] rs1_data_w1_o;
wire [63:0] rs2_data_w1_o;
wire [4:0]  rd_addr_w1_o;
wire [63:0] imm_w1_o;
wire [3:0]  alu_op_w1_o;
wire        alu_src1_sel_w1_o;
wire        alu_src2_sel_w1_o;
wire        mem_read_en_w1_o;
wire        mem_write_en_w1_o;
wire [2:0]  mem_size_w1_o;
wire        reg_write_en_w1_o;
wire [1:0]  wb_sel_w1_o;
wire        is_branch_w1_o;
wire        is_jump_w1_o;
wire        is_muldiv_w1_o;
wire [2:0]  muldiv_funct3_w1_o;
wire        valid_w1_o;

wire [63:0] pc_w2_o;
wire [4:0]  rs1_addr_w2_o;
wire [4:0]  rs2_addr_w2_o;
wire [63:0] rs1_data_w2_o;
wire [63:0] rs2_data_w2_o;
wire [4:0]  rd_addr_w2_o;
wire [63:0] imm_w2_o;
wire [3:0]  alu_op_w2_o;
wire        alu_src1_sel_w2_o;
wire        alu_src2_sel_w2_o;
wire        mem_read_en_w2_o;
wire        mem_write_en_w2_o;
wire [2:0]  mem_size_w2_o;
wire        reg_write_en_w2_o;
wire [1:0]  wb_sel_w2_o;
wire        is_branch_w2_o;
wire        is_jump_w2_o;
wire        is_muldiv_w2_o;
wire [2:0]  muldiv_funct3_w2_o;
wire        valid_w2_o;
wire        predict_taken_o;
wire [63:0] predict_target_o;

integer errors;

register_file #(
    .DATA_WIDTH(64), .REG_COUNT(32), .ADDR_WIDTH(5)
) u_rf (
    .clk(clk), .rst_n(rst_n),
    .raddr1(rf_raddr1), .rdata1(rf_rdata1),
    .raddr2(rf_raddr2), .rdata2(rf_rdata2),
    .raddr3(rf_raddr3), .rdata3(rf_rdata3),
    .raddr4(rf_raddr4), .rdata4(rf_rdata4),
    .waddr1(rf_waddr1), .wdata1(rf_wdata1), .we1(rf_we1),
    .waddr2(rf_waddr2), .wdata2(rf_wdata2), .we2(rf_we2)
);

ii_stage #(
    .DATA_WIDTH(64), .ADDR_WIDTH(64)
) dut (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .pc_w1_i(pc_w1_i),
    .rs1_addr_w1_i(rs1_addr_w1_i), .rs2_addr_w1_i(rs2_addr_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i), .imm_w1_i(imm_w1_i),
    .alu_op_w1_i(alu_op_w1_i),
    .alu_src1_sel_w1_i(alu_src1_sel_w1_i), .alu_src2_sel_w1_i(alu_src2_sel_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i), .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i),
    .reg_write_en_w1_i(reg_write_en_w1_i), .wb_sel_w1_i(wb_sel_w1_i),
    .is_branch_w1_i(is_branch_w1_i), .is_jump_w1_i(is_jump_w1_i),
    .is_system_w1_i(is_system_w1_i), .is_mem_op_w1_i(is_mem_op_w1_i),
    .is_muldiv_w1_i(is_muldiv_w1_i), .muldiv_funct3_w1_i(muldiv_funct3_w1_i),
    .uses_rs1_w1_i(uses_rs1_w1_i), .uses_rs2_w1_i(uses_rs2_w1_i),
    .valid_w1_i(valid_w1_i),
    .pc_w2_i(pc_w2_i),
    .rs1_addr_w2_i(rs1_addr_w2_i), .rs2_addr_w2_i(rs2_addr_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i), .imm_w2_i(imm_w2_i),
    .alu_op_w2_i(alu_op_w2_i),
    .alu_src1_sel_w2_i(alu_src1_sel_w2_i), .alu_src2_sel_w2_i(alu_src2_sel_w2_i),
    .mem_read_en_w2_i(mem_read_en_w2_i), .mem_write_en_w2_i(mem_write_en_w2_i),
    .mem_size_w2_i(mem_size_w2_i),
    .reg_write_en_w2_i(reg_write_en_w2_i), .wb_sel_w2_i(wb_sel_w2_i),
    .is_branch_w2_i(is_branch_w2_i), .is_jump_w2_i(is_jump_w2_i),
    .is_system_w2_i(is_system_w2_i), .is_mem_op_w2_i(is_mem_op_w2_i),
    .is_muldiv_w2_i(is_muldiv_w2_i), .muldiv_funct3_w2_i(muldiv_funct3_w2_i),
    .uses_rs1_w2_i(uses_rs1_w2_i), .uses_rs2_w2_i(uses_rs2_w2_i),
    .valid_w2_i(valid_w2_i),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .rf_raddr1(rf_raddr1), .rf_rdata1(rf_rdata1),
    .rf_raddr2(rf_raddr2), .rf_rdata2(rf_rdata2),
    .rf_raddr3(rf_raddr3), .rf_rdata3(rf_rdata3),
    .rf_raddr4(rf_raddr4), .rf_rdata4(rf_rdata4),
    .stall_dual(stall_dual),
    .pc_w1_o(pc_w1_o), .rs1_addr_w1_o(rs1_addr_w1_o), .rs2_addr_w1_o(rs2_addr_w1_o),
    .rs1_data_w1_o(rs1_data_w1_o), .rs2_data_w1_o(rs2_data_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o), .imm_w1_o(imm_w1_o),
    .alu_op_w1_o(alu_op_w1_o),
    .alu_src1_sel_w1_o(alu_src1_sel_w1_o), .alu_src2_sel_w1_o(alu_src2_sel_w1_o),
    .mem_read_en_w1_o(mem_read_en_w1_o), .mem_write_en_w1_o(mem_write_en_w1_o),
    .mem_size_w1_o(mem_size_w1_o),
    .reg_write_en_w1_o(reg_write_en_w1_o), .wb_sel_w1_o(wb_sel_w1_o),
    .is_branch_w1_o(is_branch_w1_o), .is_jump_w1_o(is_jump_w1_o),
    .is_muldiv_w1_o(is_muldiv_w1_o), .muldiv_funct3_w1_o(muldiv_funct3_w1_o),
    .valid_w1_o(valid_w1_o),
    .pc_w2_o(pc_w2_o), .rs1_addr_w2_o(rs1_addr_w2_o), .rs2_addr_w2_o(rs2_addr_w2_o),
    .rs1_data_w2_o(rs1_data_w2_o), .rs2_data_w2_o(rs2_data_w2_o),
    .rd_addr_w2_o(rd_addr_w2_o), .imm_w2_o(imm_w2_o),
    .alu_op_w2_o(alu_op_w2_o),
    .alu_src1_sel_w2_o(alu_src1_sel_w2_o), .alu_src2_sel_w2_o(alu_src2_sel_w2_o),
    .mem_read_en_w2_o(mem_read_en_w2_o), .mem_write_en_w2_o(mem_write_en_w2_o),
    .mem_size_w2_o(mem_size_w2_o),
    .reg_write_en_w2_o(reg_write_en_w2_o), .wb_sel_w2_o(wb_sel_w2_o),
    .is_branch_w2_o(is_branch_w2_o), .is_jump_w2_o(is_jump_w2_o),
    .is_muldiv_w2_o(is_muldiv_w2_o), .muldiv_funct3_w2_o(muldiv_funct3_w2_o),
    .valid_w2_o(valid_w2_o),
    .predict_taken_o(predict_taken_o), .predict_target_o(predict_target_o)
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

task setup_default;
begin
    pc_w1_i = 64'h1000; pc_w2_i = 64'h1004;
    rs1_addr_w1_i = 5'd1; rs2_addr_w1_i = 5'd2; rd_addr_w1_i = 5'd3;
    imm_w1_i = 64'd0; alu_op_w1_i = 4'b0000;
    alu_src1_sel_w1_i = 0; alu_src2_sel_w1_i = 0;
    mem_read_en_w1_i = 0; mem_write_en_w1_i = 0; mem_size_w1_i = 3'b000;
    reg_write_en_w1_i = 1; wb_sel_w1_i = 2'b00;
    is_branch_w1_i = 0; is_jump_w1_i = 0;
    is_system_w1_i = 0; is_mem_op_w1_i = 0;
    is_muldiv_w1_i = 0; muldiv_funct3_w1_i = 3'b000;
    uses_rs1_w1_i = 1; uses_rs2_w1_i = 1; valid_w1_i = 1;

    rs1_addr_w2_i = 5'd4; rs2_addr_w2_i = 5'd5; rd_addr_w2_i = 5'd6;
    imm_w2_i = 64'd0; alu_op_w2_i = 4'b0000;
    alu_src1_sel_w2_i = 0; alu_src2_sel_w2_i = 0;
    mem_read_en_w2_i = 0; mem_write_en_w2_i = 0; mem_size_w2_i = 3'b000;
    reg_write_en_w2_i = 1; wb_sel_w2_i = 2'b00;
    is_branch_w2_i = 0; is_jump_w2_i = 0;
    is_system_w2_i = 0; is_mem_op_w2_i = 0;
    is_muldiv_w2_i = 0; muldiv_funct3_w2_i = 3'b000;
    uses_rs1_w2_i = 1; uses_rs2_w2_i = 1; valid_w2_i = 1;

    predict_taken_i = 0; predict_target_i = 64'd0;
    rf_waddr1 = 5'd0; rf_wdata1 = 64'd0; rf_we1 = 0;
    rf_waddr2 = 5'd0; rf_wdata2 = 64'd0; rf_we2 = 0;
end
endtask

initial begin
    clk = 0; rst_n = 0; flush = 0;
    errors = 0;
    setup_default();

    #12 rst_n = 1;

    // === Test 1: Reset clears valid outputs ===
    check(valid_w1_o == 1'b0, "T1: valid_w1_o after reset");
    check(valid_w2_o == 1'b0, "T1: valid_w2_o after reset");

    // === Test 2: Dual-issue no hazard — both ways should emit ===
    // Way1: ADD x3, x1, x2 (rd=x3, rs1=x1, rs2=x2)
    // Way2: ADD x6, x4, x5 (rd=x6, rs1=x4, rs2=x5) — no dependency
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd3; reg_write_en_w1_i = 1;
    rd_addr_w2_i = 5'd6; reg_write_en_w2_i = 1;
    // No dependency: Way2 rs1=x4 != Way1 rd=x3, Way2 rs2=x5 != Way1 rd=x3
    @(posedge clk); #1;
    check(stall_dual == 1'b0, "T2: no stall for dual-issue");
    check(valid_w1_o == 1'b1, "T2: w1 valid after dual-issue");
    check(valid_w2_o == 1'b1, "T2: w2 valid after dual-issue");
    check(rd_addr_w1_o == 5'd3, "T2: w1 rd_addr");
    check(rd_addr_w2_o == 5'd6, "T2: w2 rd_addr");

    // === Test 3: RAW hazard — Way2 rs1 == Way1 rd → stall ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd5; reg_write_en_w1_i = 1;
    rs1_addr_w2_i = 5'd5; uses_rs1_w2_i = 1; // Way2 uses rs1=x5 == Way1 rd=x5
    rd_addr_w2_i = 5'd7; reg_write_en_w2_i = 1;
    #1;
    check(stall_dual == 1'b1, "T3: RAW hazard detected");

    // === Test 4: WAW hazard — Way1 rd == Way2 rd → stall ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd8; reg_write_en_w1_i = 1;
    rd_addr_w2_i = 5'd8; reg_write_en_w2_i = 1; // Same dest register
    #1;
    check(stall_dual == 1'b1, "T4: WAW hazard detected");

    // === Test 5: Struct hazard — both mem ops → stall ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    is_mem_op_w1_i = 1; is_mem_op_w2_i = 1;
    rd_addr_w1_i = 5'd10; rd_addr_w2_i = 5'd11;
    #1;
    check(stall_dual == 1'b1, "T5: struct hazard (two mem ops)");

    // === Test 6: Ctrl hazard — Way1 is branch → stall ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    is_branch_w1_i = 1;
    rd_addr_w1_i = 5'd12; rd_addr_w2_i = 5'd13;
    #1;
    check(stall_dual == 1'b1, "T6: ctrl hazard (branch in Way1)");

    // === Test 7: Sys hazard — system instruction → stall ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    is_system_w1_i = 1;
    #1;
    check(stall_dual == 1'b1, "T7: sys hazard (system in Way1)");

    // === Test 8: Flush clears IIEX outputs ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    @(posedge clk); #1;
    check(valid_w1_o == 1'b1, "T8: valid before flush");
    flush = 1;
    @(posedge clk); #1;
    check(valid_w1_o == 1'b0, "T8: valid_w1 cleared after flush");
    check(valid_w2_o == 1'b0, "T8: valid_w2 cleared after flush");
    check(stall_dual == 1'b0, "T8: stall_dual cleared after flush");
    flush = 0;

    // === Test 9: Way2 rs2 dependency on Way1 rd ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd5; reg_write_en_w1_i = 1;
    rs2_addr_w2_i = 5'd5; uses_rs2_w2_i = 1; // Way2 rs2 depends on Way1 rd
    #1;
    check(stall_dual == 1'b1, "T9: RAW hazard via rs2");

    // === Test 10: Way1 writes x0 — no RAW hazard ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd0; reg_write_en_w1_i = 1; // Write x0
    rs1_addr_w2_i = 5'd0; uses_rs1_w2_i = 1;
    #1;
    check(stall_dual == 1'b0, "T10: no RAW hazard when Way1 rd=x0");

    // === Test 11: issued_w1 retry — Way2 becomes slot1 next cycle ===
    // RAW: Way2 rs1 depends on Way1 rd → stall_dual=1 in first cycle
    // Next cycle: issued_w1=1, sel_w2_as_slot1=1, Way2 emitted as slot1
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd7; reg_write_en_w1_i = 1;
    rs1_addr_w2_i = 5'd7; uses_rs1_w2_i = 1;
    rd_addr_w2_i = 5'd9;
    // Combinational: stall_dual=1 immediately
    #1;
    check(stall_dual == 1'b1, "T11: RAW hazard causes stall");
    // Clock edge latches issued_w1=1, IIEX captures slot1=Way1 (blocking issue)
    @(posedge clk); #1;
    // Now issued_w1=1 so sel_w2_as_slot1=1 in II stage input
    // With valid_w1_i=0 and valid_w2_i=1 (from stall keeping IDII),
    // the II stage selects Way2 as slot1
    valid_w1_i = 0; valid_w2_i = 0; // stall IF/ID so no new input
    // The IIEX output should show the old cycle's Way1
    // After one more clock, the retried Way2 should appear
    @(posedge clk); #1;
    // Now we can verify the retry completed (Way2 as slot1 in IIEX)

    // === Test 12: No hazard when Way1 has no writeback ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd5; reg_write_en_w1_i = 0; // Way1 doesn't write back
    rs1_addr_w2_i = 5'd5; uses_rs1_w2_i = 1;
    #1;
    check(stall_dual == 1'b0, "T12: no RAW when Way1 doesn't write");

    // === Test 13: Register file read address pass-through ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rs1_addr_w1_i = 5'd3; rs2_addr_w1_i = 5'd7;
    rs1_addr_w2_i = 5'd10; rs2_addr_w2_i = 5'd15;
    #1;
    check(rf_raddr1 == 5'd3, "T13: raddr1 == rs1_w1");
    check(rf_raddr2 == 5'd7, "T13: raddr2 == rs2_w1");
    check(rf_raddr3 == 5'd10, "T13: raddr3 == rs1_w2");
    check(rf_raddr4 == 5'd15, "T13: raddr4 == rs2_w2");

    // === Test 14: Predict info pass-through ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    predict_taken_i = 1; predict_target_i = 64'h2000;
    @(posedge clk); #1;
    check(predict_taken_o == 1'b1, "T14: predict_taken pass-through");
    check(predict_target_o == 64'h2000, "T14: predict_target pass-through");

    // === Test 15: Both Way1 and Way2 write same register (WAW) with x0 — no hazard ===
    setup_default();
    valid_w1_i = 1; valid_w2_i = 1;
    rd_addr_w1_i = 5'd0; reg_write_en_w1_i = 1;
    rd_addr_w2_i = 5'd0; reg_write_en_w2_i = 1;
    #1;
    check(stall_dual == 1'b0, "T15: no WAW when both write x0");

    if (errors == 0) $display("[PASS] tb_ii_stage");
    else $display("[FAIL] tb_ii_stage errors=%0d", errors);
    $finish;
end

endmodule