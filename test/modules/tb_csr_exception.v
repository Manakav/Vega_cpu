`timescale 1ns / 1ps

module tb_csr_exception;

reg clk;
reg rst_n;

reg [11:0]          csr_addr;
reg [63:0]          csr_wdata;
reg                 csr_we;
reg                 csr_re;
reg [2:0]           funct3;
reg                 exception_valid;
reg [3:0]           exception_code;
reg [63:0]          exception_pc;
reg [63:0]          exception_value;

wire [63:0]         csr_rdata;
wire                irq_external;
wire                irq_timer;
wire                irq_software;

integer errors;

csr_unit #(
    .DATA_WIDTH(64), .ADDR_WIDTH(64)
) dut (
    .clk(clk), .rst_n(rst_n),
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
    input [255:0] msg;
begin
    if (!cond) begin
        $display("[FAIL] %0s", msg);
        errors = errors + 1;
    end
end
endtask

initial begin
    clk = 0; rst_n = 0; errors = 0;
    csr_addr = 12'd0; csr_wdata = 64'd0;
    csr_we = 0; csr_re = 0; funct3 = 3'b010;
    exception_valid = 0; exception_code = 4'd0;
    exception_pc = 64'd0; exception_value = 64'd0;

    #12 rst_n = 1;

    // === Test 1: Read mstatus after reset (should be 0) ===
    csr_re = 1; csr_addr = 12'h300; csr_we = 0;
    #1;
    check(csr_rdata == 64'd0, "T1: mstatus read after reset");

    // === Test 2: Write and read back mstatus ===
    csr_re = 0; csr_we = 1; csr_addr = 12'h300; csr_wdata = 64'hFF;
    @(posedge clk); #1;
    csr_we = 0; csr_re = 1;
    @(posedge clk); #1;
    check(csr_rdata == 64'hFF, "T2: mstatus write/readback");

    // === Test 3: Write and read mie ===
    csr_re = 0; csr_we = 1; csr_addr = 12'h304; csr_wdata = 64'h888;
    @(posedge clk); #1;
    csr_we = 0; csr_re = 1;
    @(posedge clk); #1;
    check(csr_rdata == 64'h888, "T3: mie write/readback");

    // === Test 4: Write mtvec ===
    csr_re = 0; csr_we = 1; csr_addr = 12'h305; csr_wdata = 64'h1000;
    @(posedge clk); #1;
    csr_we = 0; csr_re = 1; csr_addr = 12'h305;
    @(posedge clk); #1;
    check(csr_rdata == 64'h1000, "T4: mtvec write/readback");

    // === Test 5: Read mcycle (should be incrementing) ===
    csr_re = 1; csr_addr = 12'hB00;
    @(posedge clk); #1;
    check(csr_rdata > 64'd0, "T5: mcycle incrementing");

    // === Test 6: Write mtimecmp and check timer interrupt ===
    csr_re = 0; csr_we = 1; csr_addr = 12'h304; csr_wdata = 64'h888; // Enable MTIE
    @(posedge clk); #1;
    csr_we = 1; csr_addr = 12'hB02; csr_wdata = 64'd5; // mtimecmp = 5
    @(posedge clk); #1;
    csr_we = 0;
    // Wait for mtime to reach mtimecmp
    repeat(20) @(posedge clk);
    check(irq_timer == 1'b1, "T6: timer interrupt fires after mtime >= mtimecmp");

    // === Test 7: Exception handling — mepc and mcause ===
    csr_re = 0;
    exception_valid = 1; exception_code = 4'hB; // Machine ecall
    exception_pc = 64'h2000; exception_value = 64'd0;
    @(posedge clk); #1;
    exception_valid = 0;
    // Read mepc
    csr_re = 1; csr_addr = 12'h341;
    #1;
    check(csr_rdata == 64'h2000, "T7: mepc saved after exception");
    // Read mcause
    csr_addr = 12'h342;
    #1;
    check(csr_rdata[3:0] == 4'hB, "T7: mcause saved after exception");
    // Check mstatus[3]=old mstatus[1], mstatus[1]=1
    csr_addr = 12'h300;
    #1;
    check(csr_rdata[1] == 1'b1, "T7: mstatus.MIE set after exception");

    // === Test 8: Software interrupt check ===
    csr_we = 1; csr_addr = 12'h304; csr_wdata = 64'h008; // Enable MSIE (bit 3)
    @(posedge clk); #1;
    csr_we = 1; csr_addr = 12'h344; csr_wdata = 64'h008; // Set MSIP
    @(posedge clk); #1;
    csr_we = 0;
    #1;
    check(irq_software == 1'b1, "T8: software interrupt fires");

    // === Test 9: External interrupt check ===
    csr_we = 1; csr_addr = 12'h304; csr_wdata = 64'h800; // Enable MEIE (bit 11)
    @(posedge clk); #1;
    csr_we = 1; csr_addr = 12'h344; csr_wdata = 64'h800; // Set MEIP
    @(posedge clk); #1;
    csr_we = 0; csr_re = 1;
    #1;
    check(irq_external == 1'b1, "T9: external interrupt fires");

    // === Test 10: No read when csr_re=0 ===
    csr_re = 0; csr_addr = 12'h300;
    #1;
    check(csr_rdata == 64'd0, "T10: csr_rdata=0 when csr_re=0");

    // === Test 11: Writing x0 CSR address should be no-op (unmapped) ===
    csr_we = 1; csr_addr = 12'h000; csr_wdata = 64'hDEAD;
    @(posedge clk); #1;
    csr_we = 0; csr_re = 1; csr_addr = 12'h000;
    #1;
    check(csr_rdata == 64'd0, "T11: unmapped CSR reads as 0");

    if (errors == 0) $display("[PASS] tb_csr_exception");
    else $display("[FAIL] tb_csr_exception errors=%0d", errors);
    $finish;
end

endmodule