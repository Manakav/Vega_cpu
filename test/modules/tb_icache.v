`timescale 1ns / 1ps

module tb_icache;
reg clk;
reg rst_n;
reg [63:0] addr;
reg req;
wire [31:0] data_out;
wire hit;
wire [63:0] mem_addr;
reg [255:0] mem_data;
wire mem_req;
reg mem_ready;
integer errors;

icache dut (
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr),
    .req(req),
    .data_out(data_out),
    .hit(hit),
    .mem_addr(mem_addr),
    .mem_data(mem_data),
    .mem_req(mem_req),
    .mem_ready(mem_ready)
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
    addr = 64'h1000;
    req = 0;
    mem_data = 256'b0;
    mem_ready = 0;
    errors = 0;

    #12 rst_n = 1;

    @(posedge clk);
    req <= 1;
    mem_ready <= 0;
    @(posedge clk);
    #1;
    check(hit == 1'b0, "first access should miss");
    check(mem_req == 1'b1, "miss should request memory");

    mem_data <= 256'h0;
    mem_data[31:0] <= 32'hDEADBEEF;
    mem_ready <= 1;
    @(posedge clk);
    mem_ready <= 0;

    @(posedge clk);
    req <= 1;
    @(posedge clk);
    #1;
    check(hit == 1'b1, "second access should hit");
    check(data_out == 32'hDEADBEEF, "cache line data failed");

    if (errors == 0) $display("[PASS] tb_icache");
    else $display("[FAIL] tb_icache errors=%0d", errors);
    $finish;
end

endmodule
