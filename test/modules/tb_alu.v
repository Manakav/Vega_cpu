`timescale 1ns / 1ps

// ALU 模块单元测试：覆盖算术/逻辑与标志位
module tb_alu;
// DUT 输入
reg [3:0] alu_op;
reg [63:0] operand_a;
reg [63:0] operand_b;
// DUT 输出
wire [63:0] result;
wire zero;
wire negative;
wire overflow;
integer errors;

alu dut (
    .alu_op(alu_op),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .result(result),
    .zero(zero),
    .negative(negative),
    .overflow(overflow)
);

// 通用检查任务：失败时累计错误计数
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
    errors = 0;

    // ADD
    alu_op = 4'b0000; operand_a = 64'd3; operand_b = 64'd5; #1;
    check(result == 64'd8, "ADD failed");

    // SUB
    alu_op = 4'b0001; operand_a = 64'd9; operand_b = 64'd4; #1;
    check(result == 64'd5, "SUB failed");

    // AND + ZERO
    alu_op = 4'b1001; operand_a = 64'hF0; operand_b = 64'h0F; #1;
    check(result == 64'h0, "AND failed");
    check(zero == 1'b1, "ZERO flag failed");

    // SRA + NEGATIVE
    alu_op = 4'b0111; operand_a = 64'h8000000000000000; operand_b = 64'd1; #1;
    check(negative == 1'b1, "NEGATIVE flag failed");

    if (errors == 0) $display("[PASS] tb_alu");
    else $display("[FAIL] tb_alu errors=%0d", errors);
    $finish;
end

endmodule
