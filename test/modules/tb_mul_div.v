`timescale 1ns / 1ps

module tb_mul_div;
reg clk;
reg rst_n;
reg start;
reg [2:0] funct3;
reg [63:0] operand_a;
reg [63:0] operand_b;
wire [63:0] result;
wire done;
integer errors;

mul_div dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .funct3(funct3),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .result(result),
    .done(done)
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
    start = 0;
    funct3 = 0;
    operand_a = 0;
    operand_b = 0;
    errors = 0;

    #12 rst_n = 1;

    @(posedge clk);
    start <= 1;
    funct3 <= 3'b000;
    operand_a <= 64'd3;
    operand_b <= 64'd4;

    @(posedge clk);
    @(posedge clk);
    #1;
    check(result == 64'd12, "MUL result failed");
    check(done == 1'b1, "MUL done failed");

    start <= 0;
    @(posedge clk);

    start <= 1;
    funct3 <= 3'b100;
    operand_a <= 64'd9;
    operand_b <= 64'd0;
    @(posedge clk);
    @(posedge clk);
    #1;
    check(result == 64'hFFFFFFFFFFFFFFFF, "DIV by zero failed");

    if (errors == 0) $display("[PASS] tb_mul_div");
    else $display("[FAIL] tb_mul_div errors=%0d", errors);
    $finish;
end

endmodule
