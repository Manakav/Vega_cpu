`timescale 1ns / 1ps

module tb_csr_unit;
reg clk;
reg rst_n;
reg [11:0] csr_addr;
reg [63:0] csr_wdata;
reg csr_we;
reg csr_re;
reg [2:0] funct3;
wire [63:0] csr_rdata;
wire irq_external;
wire irq_timer;
wire irq_software;
reg exception_valid;
reg [3:0] exception_code;
reg [63:0] exception_pc;
reg [63:0] exception_value;
integer errors;

csr_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .csr_addr(csr_addr),
    .csr_wdata(csr_wdata),
    .csr_we(csr_we),
    .csr_re(csr_re),
    .funct3(funct3),
    .csr_rdata(csr_rdata),
    .irq_external(irq_external),
    .irq_timer(irq_timer),
    .irq_software(irq_software),
    .exception_valid(exception_valid),
    .exception_code(exception_code),
    .exception_pc(exception_pc),
    .exception_value(exception_value)
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
    csr_addr = 0;
    csr_wdata = 0;
    csr_we = 0;
    csr_re = 0;
    funct3 = 0;
    exception_valid = 0;
    exception_code = 0;
    exception_pc = 0;
    exception_value = 0;
    errors = 0;

    #12 rst_n = 1;

    // enable timer interrupt bit in mie[7]
    @(posedge clk);
    csr_we <= 1;
    csr_addr <= 12'h304;
    csr_wdata <= 64'h0000000000000080;
    @(posedge clk);
    csr_we <= 0;

    // set compare small so timer interrupt can trigger
    @(posedge clk);
    csr_we <= 1;
    csr_addr <= 12'hB02;
    csr_wdata <= 64'h0000000000000002;
    @(posedge clk);
    csr_we <= 0;

    repeat (5) @(posedge clk);
    #1;
    check(irq_timer == 1'b1, "irq_timer should assert when mtime>=mtimecmp and mie[7]=1");

    // read back mie
    csr_re = 1;
    csr_addr = 12'h304;
    #1;
    check(csr_rdata[7] == 1'b1, "readback mie[7] failed");
    csr_re = 0;

    if (errors == 0) $display("[PASS] tb_csr_unit");
    else $display("[FAIL] tb_csr_unit errors=%0d", errors);
    $finish;
end

endmodule
