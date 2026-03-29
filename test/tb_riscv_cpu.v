// ============================================================================
// 顶层 CPU 冒烟测试 (tb_riscv_cpu)
// 测试目标：验证复位/时钟驱动下，CPU 可通过指令与数据接口完成基础取指与访存流程
// 覆盖范围：
// 1) 指令口请求-授权握手与取指地址推进
// 2) 数据口请求-授权握手与读写通路连通性
// 3) 在零等待存储模型下完成固定时长稳定运行并导出波形
// ============================================================================

module tb_riscv_cpu;

// 时钟/复位
reg clk;
reg rst_n;

// 简化指令/数据存储模型
reg [31:0] instr_mem [0:4095];
reg [63:0] data_mem [0:4095];

// 指令侧接口
wire [63:0] instr_addr;
wire [31:0] instr_data;
wire instr_req;
wire instr_gnt;

// 数据侧接口
wire [63:0] data_addr;
wire [63:0] data_wdata;
wire [63:0] data_rdata;
wire data_req;
wire data_we;
wire [7:0] data_be;
wire data_gnt;

// 外部中断输入
reg irq_external;
reg irq_timer;
reg irq_software;

// 调试状态输出
wire debug_halt;
wire debug_resume;

// 时钟生成
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// 复位与测试控制流程
initial begin
    rst_n = 0;
    irq_external = 0;
    irq_timer = 0;
    irq_software = 0;
    
    $readmemh("test/instr_mem.hex", instr_mem, 0, 7);
    
    #100;
    rst_n = 1;
    #10000;
    $display("Simulation finished");
    $finish;
end

// 零等待存储器模型：请求即授权
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

// 生成波形
initial begin
    $dumpfile("riscv_cpu.vcd");
    $dumpvars(0, tb_riscv_cpu);
end

endmodule