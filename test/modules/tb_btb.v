`timescale 1ns / 1ps

// BTB 单元测试：验证写入更新后可命中并返回目标地址
module tb_btb;
reg clk;
reg rst_n;
reg read_en;
reg [63:0] pc;
wire hit;
wire [63:0] target;
wire valid;
reg update_en;
reg [63:0] update_pc;
reg [63:0] update_target;
integer errors;

btb dut (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(read_en),
    .pc(pc),
    .hit(hit),
    .target(target),
    .valid(valid),
    .update_en(update_en),
    .update_pc(update_pc),
    .update_target(update_target)
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
    pc = 64'h0000_2000;
    update_en = 0;
    update_pc = 64'h0000_2000;
    update_target = 64'h0000_3000;
    errors = 0;

    #12 rst_n = 1;
    #1;
    // 复位后应 miss
    check(hit == 1'b0, "reset must miss");

    // 写入一条 BTB 项
    @(posedge clk);
    update_en <= 1;
    @(posedge clk);
    update_en <= 0;
    #1;

    pc = 64'h0000_2000;
    #1;
    // 再次读取应命中并返回更新目标
    check(hit == 1'b1, "updated entry must hit");
    check(valid == 1'b1, "updated entry valid failed");
    check(target == 64'h0000_3000, "updated target failed");

    if (errors == 0) $display("[PASS] tb_btb");
    else $display("[FAIL] tb_btb errors=%0d", errors);
    $finish;
end

endmodule
