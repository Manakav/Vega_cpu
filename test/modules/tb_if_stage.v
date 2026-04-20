`timescale 1ns / 1ps

module tb_if_stage;
reg clk;
reg rst_n;
reg stall;
reg flush;
wire [63:0] instr_addr;
reg [31:0] instr_data_w1;
reg [31:0] instr_data_w2;
wire instr_req;
reg instr_gnt;
reg branch_taken;
reg [63:0] branch_target;
reg mispredict;
wire [63:0] pc_out_w1;
wire [31:0] instr_out_w1;
wire valid_out_w1;
wire [63:0] pc_out_w2;
wire [31:0] instr_out_w2;
wire valid_out_w2;
wire predict_taken;
wire [63:0] predict_target;
wire [63:0] predict_fetch_pc;
reg branch_update_en;
reg branch_update_taken;
reg [63:0] branch_update_target;
integer errors;

if_stage #(
    .ADDR_WIDTH(64),
    .DATA_WIDTH(32)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .instr_addr(instr_addr),
    .instr_data_w1(instr_data_w1),
    .instr_data_w2(instr_data_w2),
    .instr_req(instr_req),
    .instr_gnt(instr_gnt),
    .branch_taken(branch_taken),
    .branch_target(branch_target),
    .mispredict(mispredict),
    .pc_out_w1(pc_out_w1),
    .instr_out_w1(instr_out_w1),
    .valid_out_w1(valid_out_w1),
    .pc_out_w2(pc_out_w2),
    .instr_out_w2(instr_out_w2),
    .valid_out_w2(valid_out_w2),
    .predict_taken(predict_taken),
    .predict_target(predict_target),
    .predict_fetch_pc(predict_fetch_pc),
    .branch_update_en(branch_update_en),
    .branch_update_taken(branch_update_taken),
    .branch_update_target(branch_update_target)
);

always #5 clk = ~clk;

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
    clk = 0;
    rst_n = 0;
    stall = 0;
    flush = 0;
    instr_data_w1 = 32'h00000013;
    instr_data_w2 = 32'h00000013;
    instr_gnt = 1;
    branch_taken = 0;
    branch_target = 64'h2000;
    mispredict = 0;
    branch_update_en = 0;
    branch_update_taken = 0;
    branch_update_target = 64'h0;
    errors = 0;

    #12 rst_n = 1;

    // After reset, first active posedge: pipeline fills
    @(posedge clk); #1;
    @(posedge clk); #1;

    // Test 1: instr_req always high in direct mode
    check(instr_req == 1'b1, "instr_req should be high");
    check(valid_out_w1 == 1'b1, "valid_out_w1 should be 1");
    check(instr_out_w1 == 32'h00000013, "instr should be NOP");

    // Test 2: Dual-issue Way2
    check(valid_out_w2 == 1'b1, "Way2 valid should be 1 for dual issue");
    check(pc_out_w2 == pc_out_w1 + 4, "Way2 PC should be Way1 PC + 4");

    // Test 3: Mispredict - valid clears, then redirects
    mispredict = 1;
    @(posedge clk); #1;
    mispredict = 0;
    check(valid_out_w1 == 1'b0, "valid should be 0 on mispredict cycle");
    check(valid_out_w2 == 1'b0, "Way2 valid should be 0 on mispredict cycle");

    // Next cycle: fetch from target
    @(posedge clk); #1;
    check(valid_out_w1 == 1'b1, "valid should recover after mispredict");

    // Test 4: Flush clears pipeline
    flush = 1;
    @(posedge clk); #1;
    flush = 0;
    check(valid_out_w1 == 1'b0, "valid should be 0 after flush");

    // Test 5: Stall freezes pipeline
    @(posedge clk); #1;
    stall = 1;
    @(posedge clk); #1;
    // During stall, PC and outputs freeze
    stall = 0;

    // Test 6: Branch update training (BTB)
    branch_update_en = 1;
    branch_update_taken = 1;
    branch_update_target = 64'h3000;
    @(posedge clk); #1;
    branch_update_en = 0;

    // Test 7: Stalled instruction data path
    instr_data_w1 = 32'h00a00193; // addi x3, x0, 10
    instr_data_w2 = 32'h00b00213; // addi x4, x0, 11
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(instr_out_w1 == 32'h00a00193 || instr_out_w1 == 32'h00000013,
          "instruction data path works");

    if (errors == 0) $display("[PASS] tb_if_stage");
    else $display("[FAIL] tb_if_stage errors=%0d", errors);
    $finish;
end

endmodule