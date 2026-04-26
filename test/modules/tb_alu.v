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
    check(zero == 1'b0, "ADD zero fail");
    check(negative == 1'b0, "ADD neg fail");
    check(overflow == 1'b0, "ADD ovf fail");

    // SUB
    alu_op = 4'b0001; operand_a = 64'd9; operand_b = 64'd4; #1;
    check(result == 64'd5, "SUB failed");
    check(overflow == 1'b0, "SUB ovf clr");

    // SUB overflow: -2^63 - 1 => +2^63-1，溢出应置位
    alu_op = 4'b0001; operand_a = 64'h8000000000000000; operand_b = 64'd1; #1;
    check(result == 64'h7FFFFFFFFFFFFFFF, "SUB ovf res");
    check(overflow == 1'b1, "SUB ovf set");

    // SLL
    alu_op = 4'b0010; operand_a = 64'h1; operand_b = 64'd4; #1;
    check(result == 64'h10, "SLL failed");

    // SLT (signed): -1 < 1
    alu_op = 4'b0011; operand_a = 64'hFFFFFFFFFFFFFFFF; operand_b = 64'h1; #1;
    check(result == 64'h1, "SLT true");

    // SLT (signed): 1 < -1 为假
    alu_op = 4'b0011; operand_a = 64'h1; operand_b = 64'hFFFFFFFFFFFFFFFF; #1;
    check(result == 64'h0, "SLT false");

    // SLTU (unsigned): 1 < 2
    alu_op = 4'b0100; operand_a = 64'd1; operand_b = 64'd2; #1;
    check(result == 64'h1, "SLTU true");

    // SLTU (unsigned): max < 1 为假
    alu_op = 4'b0100; operand_a = 64'hFFFFFFFFFFFFFFFF; operand_b = 64'd1; #1;
    check(result == 64'h0, "SLTU false");

    // XOR
    alu_op = 4'b0101; operand_a = 64'hAA55; operand_b = 64'h0F0F; #1;
    check(result == 64'hA55A, "XOR failed");

    // SRL
    alu_op = 4'b0110; operand_a = 64'h8000000000000000; operand_b = 64'd1; #1;
    check(result == 64'h4000000000000000, "SRL failed");

    // AND + ZERO
    alu_op = 4'b1001; operand_a = 64'hF0; operand_b = 64'h0F; #1;
    check(result == 64'h0, "AND failed");
    check(zero == 1'b1, "ZERO flag failed");

    // SRA + NEGATIVE
    alu_op = 4'b0111; operand_a = 64'h8000000000000000; operand_b = 64'd1; #1;
    check(result == 64'hC000000000000000, "SRA failed");
    check(negative == 1'b1, "NEGATIVE flag failed");

    // OR
    alu_op = 4'b1000; operand_a = 64'hF0; operand_b = 64'h0F; #1;
    check(result == 64'hFF, "OR failed");

    // LUI (pass B)
    alu_op = 4'b1010; operand_a = 64'hDEADBEEF; operand_b = 64'h123456789ABCDEF0; #1;
    check(result == 64'h123456789ABCDEF0, "LUI failed");

    // PASS A (AUIPC)
    alu_op = 4'b1100; operand_a = 64'hCAFEBABE11223344; operand_b = 64'h0; #1;
    check(result == 64'hCAFEBABE11223344, "PASSA failed");

    // default 分支
    alu_op = 4'b1011; operand_a = 64'h1234; operand_b = 64'h5678; #1;
    check(result == 64'h0, "DEFAULT fail");
    check(zero == 1'b1, "DEF zero fail");
    check(overflow == 1'b0, "DEF ovf fail");

    if (errors == 0) $display("[PASS] tb_alu");
    else $display("[FAIL] tb_alu errors=%0d", errors);
    $finish;
end

endmodule
