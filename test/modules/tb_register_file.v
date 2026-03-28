`timescale 1ns / 1ps

module tb_register_file;
reg clk;
reg rst_n;
reg [4:0] raddr1;
reg [4:0] raddr2;
wire [63:0] rdata1;
wire [63:0] rdata2;
reg [4:0] waddr;
reg [63:0] wdata;
reg we;
integer errors;

register_file dut (
    .clk(clk),
    .rst_n(rst_n),
    .raddr1(raddr1),
    .rdata1(rdata1),
    .raddr2(raddr2),
    .rdata2(rdata2),
    .waddr(waddr),
    .wdata(wdata),
    .we(we)
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
    raddr1 = 0;
    raddr2 = 0;
    waddr = 0;
    wdata = 0;
    we = 0;
    errors = 0;

    #12 rst_n = 1;

    @(posedge clk);
    we <= 1;
    waddr <= 5'd1;
    wdata <= 64'h12345678ABCDEF00;

    @(posedge clk);
    we <= 0;
    raddr1 <= 5'd1;
    #1;
    check(rdata1 == 64'h12345678ABCDEF00, "Write/read x1 failed");

    raddr2 <= 5'd0;
    #1;
    check(rdata2 == 64'b0, "x0 must be zero");

    if (errors == 0) $display("[PASS] tb_register_file");
    else $display("[FAIL] tb_register_file errors=%0d", errors);
    $finish;
end

endmodule
