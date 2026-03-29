`timescale 1ns / 1ps

// ============================================================================
// 顶层 CPU 基础冒烟测试
// 目标：验证复位后时钟推进、接口连线和基础运行流程
// ============================================================================
module riscv_cpu_tb;

// 时钟/复位
reg                     clk;
reg                     rst_n;

// 指令接口
wire [63:0]            instr_addr;
reg  [31:0]            instr_data;
wire                    instr_req;
reg                     instr_gnt;

// 数据接口
wire [63:0]            data_addr;
wire [63:0]            data_wdata;
reg  [63:0]            data_rdata;
wire                    data_req;
wire                    data_we;
wire [7:0]             data_be;
reg                     data_gnt;

// 中断/调试接口
reg                     irq_external;
reg                     irq_timer;
reg                     irq_software;
reg                     debug_req;
wire                    debug_halt;
wire                    debug_resume;

reg [7:0] instruction_mem [0:16383];
reg [7:0] data_mem [0:16383];

// 统计信息
integer cycle_count;
integer error_count;

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
    .debug_req(debug_req),
    .debug_halt(debug_halt),
    .debug_resume(debug_resume)
);

// 100MHz 时钟（10ns 周期）
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// 基础激励：复位 -> 运行一段时间 -> 结束
initial begin
    rst_n = 0;
    irq_external = 0;
    irq_timer = 0;
    irq_software = 0;
    debug_req = 0;
    instr_data = 32'h00000013;
    instr_gnt = 1;
    data_rdata = 64'h0;
    data_gnt = 1;
    error_count = 0;
    cycle_count = 0;
    
    #100;
    rst_n = 1;
    #1000;
    
    $display("Test finished at cycle %0d, errors: %0d", cycle_count, error_count);
    $finish;
end

// 周期计数器
always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
end

endmodule