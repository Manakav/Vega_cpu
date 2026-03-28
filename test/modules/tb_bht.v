`timescale 1ns / 1ps

module tb_bht;
reg clk;
reg rst_n;
reg read_en;
reg [63:0] pc;
reg [7:0] ghr;
wire taken;
wire [1:0] counter;
reg update_en;
reg [63:0] update_pc;
reg update_taken;
integer errors;

bht dut (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(read_en),
    .pc(pc),
    .ghr(ghr),
    .taken(taken),
    .counter(counter),
    .update_en(update_en),
    .update_pc(update_pc),
    .update_taken(update_taken)
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
    read_en = 1;
    pc = 64'h1000;
    ghr = 8'h00;
    update_en = 0;
    update_pc = 64'h1000;
    update_taken = 0;
    errors = 0;

    #12 rst_n = 1;
    #1;
    check(counter == 2'b01, "reset counter must be weak-not-taken");
    check(taken == 1'b0, "reset taken must be 0");

    @(posedge clk);
    update_en <= 1;
    update_taken <= 1;
    @(posedge clk);
    update_en <= 0;
    #1;
    check(counter == 2'b10, "first taken update failed");

    @(posedge clk);
    update_en <= 1;
    update_taken <= 1;
    @(posedge clk);
    update_en <= 0;
    #1;
    check(counter == 2'b11, "second taken update failed");
    check(taken == 1'b1, "taken bit failed");

    if (errors == 0) $display("[PASS] tb_bht");
    else $display("[FAIL] tb_bht errors=%0d", errors);
    $finish;
end

endmodule
