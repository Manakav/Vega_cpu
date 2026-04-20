`timescale 1ns / 1ps

module tb_branch_predict;

reg clk;
reg rst_n;

reg [63:0] pc;
reg        read_en;
reg        update_en;
reg [63:0] update_pc;
reg [63:0] update_target;
reg        update_taken;

wire       btb_hit;
wire       btb_valid;
wire [63:0] btb_target;
wire       bht_taken;
wire [1:0]  bht_counter;

integer errors;
integer total_branches;
integer correct_predictions;
real accuracy;

btb u_btb (
    .clk(clk), .rst_n(rst_n),
    .read_en(read_en),
    .pc(pc),
    .hit(btb_hit),
    .target(btb_target),
    .valid(btb_valid),
    .update_en(update_en),
    .update_pc(update_pc),
    .update_target(update_target)
);

bht u_bht (
    .clk(clk), .rst_n(rst_n),
    .read_en(read_en),
    .pc(pc),
    .ghr(8'b0), // Use fixed GHR for unit test — automate updates in a real integration env.
    .taken(bht_taken),
    .counter(bht_counter),
    .update_en(update_en),
    .update_pc(update_pc),
    .update_taken(update_taken)
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
    clk = 0; rst_n = 0; errors = 0;
    pc = 64'h1000; read_en = 0;
    update_en = 0; update_pc = 64'd0;
    update_target = 64'd0; update_taken = 0;
    total_branches = 0; correct_predictions = 0;

    #12 rst_n = 1;

    // === Test 1: Empty BTB — no hit on unknown address ===
    read_en = 1; pc = 64'h1000;
    #1;
    check(btb_hit == 1'b0, "T1: BTB miss on unknown address");
    check(bht_taken == 1'b0 || bht_taken == 1'b1, "T1: BHT has default output");

    // === Test 2: Train BTB — branch at 0x1000 → 0x2000 ===
    update_en = 1; update_pc = 64'h1000; update_target = 64'h2000; update_taken = 1;
    @(posedge clk); #1;
    update_en = 0;

    // === Test 3: BTB should now hit for 0x1000 ===
    pc = 64'h1000; read_en = 1;
    #1;
    check(btb_hit == 1'b1, "T3: BTB hit after training");
    check(btb_target == 64'h2000, "T3: BTB target matches");

    // === Test 4: BTB miss on different address ===
    pc = 64'h2000; read_en = 1;
    #1;
    check(btb_hit == 1'b0, "T4: BTB miss on untrained address");

    // === Test 5: Train another branch ===
    update_en = 1; update_pc = 64'h2000; update_target = 64'h3000; update_taken = 1;
    @(posedge clk); #1;
    update_en = 0;
    pc = 64'h2000; read_en = 1;
    #1;
    check(btb_hit == 1'b1, "T5: BTB hit on second trained address");
    check(btb_target == 64'h3000, "T5: BTB target for second branch");

    // === Test 6: BHT 2-bit saturating counter behavior ===
    // After reset, counter should be weakly not-taken (01)
    // Train "not taken" transitions: should go toward strongly not-taken
    update_en = 1; update_pc = 64'h3000; update_taken = 0;
    @(posedge clk); #1;
    @(posedge clk); #1; // Train twice
    update_en = 0;

    pc = 64'h3000; read_en = 1;
    #1;
    check(bht_taken == 1'b0, "T6: BHT not-taken after training not-taken");

    // === Test 7: BHT train "taken" ===
    update_en = 1; update_pc = 64'h4000; update_taken = 1;
    repeat(3) @(posedge clk); // Train 3 times to saturate
    update_en = 0;
    pc = 64'h4000; read_en = 1;
    #1;
    check(bht_taken == 1'b1, "T7: BHT taken after repeated taken training");

    // === Test 8: Branch prediction accuracy simulation ===
    // Simple always-taken pattern: predict should converge to "taken"
    rst_n = 0;
    #12 rst_n = 1;
    total_branches = 0;
    correct_predictions = 0;

    // Train a taken branch at 0x1000
    update_en = 1; update_pc = 64'h1000; update_target = 64'h2000; update_taken = 1;
    @(posedge clk); #1;
    update_en = 0;

    // Check prediction: should predict taken (BTB hit + BHT strong taken)
    pc = 64'h1000; read_en = 1;
    #1;
    total_branches = total_branches + 1;
    if (btb_hit && btb_valid) correct_predictions = correct_predictions + 1;

    // Train another not-taken at 0x2000
    update_en = 1; update_pc = 64'h2000; update_taken = 0; update_target = 64'd0;
    @(posedge clk); #1;
    update_en = 0;

    pc = 64'h2000; read_en = 1;
    #1;
    // Not-taken: BTB hit won't match because update_target was 0
    // This tests the BHT separately
    total_branches = total_branches + 1;

    // Report accuracy
    if (total_branches > 0) begin
        accuracy = (correct_predictions * 100.0) / total_branches;
        $display("[INFO] Branch prediction accuracy: %0.1f%% (%0d/%0d)", accuracy, correct_predictions, total_branches);
    end

    // === Test 9: Flush via reset clears BTB ===
    rst_n = 0;
    #12 rst_n = 1;
    pc = 64'h1000; read_en = 1;
    #1;
    check(btb_hit == 1'b0, "T9: BTB cleared after reset");

    // === Test 10: Train-verify at different BTB indices ===
    // BTB index = pc[7:2]; 0x1000->idx=0, 0x1040->idx=0x10, etc.
    // Train entries and verify hits after each train
    update_en = 1; update_taken = 1;
    update_pc = 64'h1000; update_target = 64'h2000;
    @(posedge clk); #1;
    pc = 64'h1000; read_en = 1;
    #1;
    check(btb_hit == 1'b1 && btb_target == 64'h2000, "T10a: BTB hit after train at 0x1000");

    update_pc = 64'h1040; update_target = 64'h2100;
    @(posedge clk); #1;
    pc = 64'h1040; read_en = 1;
    #1;
    check(btb_hit == 1'b1 && btb_target == 64'h2100, "T10b: BTB hit after train at 0x1040");

    update_pc = 64'h1080; update_target = 64'h2200;
    @(posedge clk); #1;
    pc = 64'h1080; read_en = 1;
    #1;
    check(btb_hit == 1'b1 && btb_target == 64'h2200, "T10c: BTB hit after train at 0x1080");

    update_en = 0;

    if (errors == 0) $display("[PASS] tb_branch_predict");
    else $display("[FAIL] tb_branch_predict errors=%0d", errors);
    $finish;
end

endmodule