`timescale 1ns / 1ps

// DCache 单元测试：验证 miss 请求、回填后 hit 与读数据
module tb_dcache;
// 时钟/请求输入
reg clk;
reg rst_n;
reg [63:0] addr;
reg [63:0] wdata;
reg [7:0] be;
reg req;
reg we;
reg [2:0] size;
wire [63:0] data_out;
wire hit;
wire [63:0] mem_addr;
wire [255:0] mem_wdata;
reg [255:0] mem_rdata;
wire mem_req;
wire mem_we;
reg mem_ready;
integer errors;

dcache dut (
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr),
    .wdata(wdata),
    .be(be),
    .req(req),
    .we(we),
    .size(size),
    .data_out(data_out),
    .hit(hit),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_req(mem_req),
    .mem_we(mem_we),
    .mem_ready(mem_ready)
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
    addr = 64'h2000;
    wdata = 64'h0;
    be = 8'hFF;
    req = 0;
    we = 0;
    size = 3'b011;
    mem_rdata = 256'b0;
    mem_ready = 0;
    errors = 0;

    #12 rst_n = 1;

    // 第一次读：期望 miss，并拉起 mem_req
    @(posedge clk);
    req <= 1;
    we <= 0;
    mem_ready <= 0;
    @(posedge clk);
    #1;
    check(hit == 1'b0, "first read should miss");
    check(mem_req == 1'b1, "miss should raise mem_req");

    // 模拟下层返回一条 cache line（低 64bit 有效）
    mem_rdata <= 256'b0;
    mem_rdata[63:0] <= 64'h1122334455667788;
    mem_ready <= 1;
    // 第二次读同地址：期望命中
    @(posedge clk);
    mem_ready <= 0;

    @(posedge clk);
    req <= 1;
    we <= 0;
    @(posedge clk);
    #1;
    check(hit == 1'b1, "second read should hit");
    check(data_out == 64'h1122334455667788, "read data failed");

    if (errors == 0) $display("[PASS] tb_dcache");
    else $display("[FAIL] tb_dcache errors=%0d", errors);
    $finish;
end

endmodule
