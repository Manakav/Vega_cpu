`timescale 1ns / 1ps

// BHT 单元测试：验证复位值与 2-bit 饱和计数器更新
module tb_bht;
// 时钟与输入激励
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

// 时钟
always #5 clk = ~clk;

// 通用检查任务
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
    // 初始化
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
    // 复位后应为弱不跳转
    check(counter == 2'b01, "reset counter must be weak-not-taken");
    check(taken == 1'b0, "reset taken must be 0");

    // 第一次 taken 更新：01 -> 10
    @(posedge clk);
    update_en <= 1;
    update_taken <= 1;
    @(posedge clk);
    update_en <= 0;
    #1;
    check(counter == 2'b10, "first taken update failed");

    // 第二次 taken 更新：10 -> 11
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
