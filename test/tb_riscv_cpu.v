// ============================================================================
// RISC-V CPU Testbench
// ============================================================================

module tb_riscv_cpu;

reg clk;
reg rst_n;

reg [31:0] instr_mem [0:4095];
reg [63:0] data_mem [0:4095];

wire [63:0] instr_addr;
wire [31:0] instr_data;
wire instr_req;
wire instr_gnt;

wire [63:0] data_addr;
wire [63:0] data_wdata;
wire [63:0] data_rdata;
wire data_req;
wire data_we;
wire [7:0] data_be;
wire data_gnt;

reg irq_external;
reg irq_timer;
reg irq_software;

wire debug_halt;
wire debug_resume;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    irq_external = 0;
    irq_timer = 0;
    irq_software = 0;
    
    $readmemh("instr_mem.hex", instr_mem);
    
    #100;
    rst_n = 1;
    #10000;
    $display("Simulation finished");
    $finish;
end

assign instr_data = instr_mem[instr_addr[13:2]];
assign instr_gnt = instr_req;
assign data_rdata = data_mem[data_addr[13:3]];
assign data_gnt = data_req;

riscv_cpu u_dut (
    .clk(clk),
    .rst_n(rst_n),
    .instr_addr(instr_addr),
    .instr_data(instr_data),
    .instr_req(instr_req),
    .instr_gnt(instr_gnt),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_req(data_req),
    .data_we(data_we),
    .data_be(data_be),
    .data_gnt(data_gnt),
    .irq_external(irq_external),
    .irq_timer(irq_timer),
    .irq_software(irq_software),
    .debug_req(1'b0),
    .debug_halt(debug_halt),
    .debug_resume(debug_resume)
);

initial begin
    $dumpfile("riscv_cpu.vcd");
    $dumpvars(0, tb_riscv_cpu);
end

endmodule