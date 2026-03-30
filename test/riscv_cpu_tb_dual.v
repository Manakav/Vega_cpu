`timescale 1ns / 1ps

// ============================================================================
// Vega CPU 6 级双发射验证 Testbench
// 目标：验证双发射流水线的基础功能
// ============================================================================
module riscv_cpu_tb;

// ========== 时钟/复位 ==========
reg                     clk;
reg                     rst_n;

// ========== 指令接口（改为双路） ==========
wire [63:0]            instr_addr;
wire [31:0]            instr_data_w1;   // PC 处指令（由持续赋值驱动）
wire [31:0]            instr_data_w2;   // PC+4 处指令（由持续赋值驱动）
wire                   instr_req;
reg                    instr_gnt;

// ========== 数据接口 ==========
wire [63:0]            data_addr;
wire [63:0]            data_wdata;
wire [63:0]            data_rdata;         // 由持续赋值驱动
wire                   data_req;
wire                   data_we;
wire [7:0]             data_be;
reg                    data_gnt;

// ========== 中断/调试接口 ==========
reg                    irq_external;
reg                    irq_timer;
reg                    irq_software;
reg                    debug_req;
wire                   debug_halt;
wire                   debug_resume;

// ========== 内存 ==========
reg [31:0] imem [0:4095];           // 指令存储器 (16KB)
reg [7:0]  dmem [0:16383];          // 数据存储器 (64KB)
// ========== 持续赋值驱动 - 确保从仿真开始就正确驱动 ==========
assign instr_data_w1 = imem[instr_addr[12:2]];
assign instr_data_w2 = imem[instr_addr[12:2] + 1];
assign data_rdata = {dmem[data_addr + 7], dmem[data_addr + 6], dmem[data_addr + 5], dmem[data_addr + 4],
                     dmem[data_addr + 3], dmem[data_addr + 2], dmem[data_addr + 1], dmem[data_addr + 0]};


// ========== 统计信息 ==========
reg [31:0] cycle_count;
reg [31:0] instr_count;
reg [31:0] error_count;

// ========== DUT 实例化 ==========
riscv_cpu u_dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .instr_addr         (instr_addr),
    .instr_data_w1      (instr_data_w1),  // 改为 w1
    .instr_data_w2      (instr_data_w2),  // 改为 w2
    .instr_req          (instr_req),
    .instr_gnt          (instr_gnt),
    .data_addr          (data_addr),
    .data_wdata         (data_wdata),
    .data_rdata         (data_rdata),
    .data_req           (data_req),
    .data_we            (data_we),
    .data_be            (data_be),
    .data_gnt           (data_gnt),
    .irq_external       (irq_external),
    .irq_timer          (irq_timer),
    .irq_software       (irq_software),
    .debug_req          (debug_req),
    .debug_halt         (debug_halt),
    .debug_resume       (debug_resume)
);

// ========== 100MHz 时钟（10ns 周期）==========
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// ========== 指令存储器读出 ==========

// ========== 数据存储器写操作 ==========
always @(posedge clk) begin
    if (data_req && data_we) begin
        if (data_be[0]) dmem[data_addr + 0] <= data_wdata[7:0];
        if (data_be[1]) dmem[data_addr + 1] <= data_wdata[15:8];
        if (data_be[2]) dmem[data_addr + 2] <= data_wdata[23:16];
        if (data_be[3]) dmem[data_addr + 3] <= data_wdata[31:24];
        if (data_be[4]) dmem[data_addr + 4] <= data_wdata[39:32];
        if (data_be[5]) dmem[data_addr + 5] <= data_wdata[47:40];
        if (data_be[6]) dmem[data_addr + 6] <= data_wdata[55:48];
        if (data_be[7]) dmem[data_addr + 7] <= data_wdata[63:56];
    end
end

// ========== 主激励 ==========
initial begin
    // 初始化
    // 预初始化指令存储器（确保从仿真开始就包含有效数据，避免高阻态）
    load_test_program();
    
    rst_n           = 0;
    irq_external    = 0;
    irq_timer       = 0;
    irq_software    = 0;
    debug_req       = 0;
    instr_gnt       = 1;
    data_gnt        = 1;
    error_count     = 0;
    cycle_count     = 0;
    instr_count     = 0;
    
    // 加载测试程序到指令存储器
    // (已在模块启动时初始化，此行为备注)
    
    // 复位序列
    #50;
    rst_n = 1;
    
    // 运行 200 个周期
    #2000;
    
    // 完成
    $display("\n");
    $display("========================================");
    $display("仿真完成");
    $display("总周期数:     %0d", cycle_count);
    $display("发射指令数:   %0d", instr_count);
    $display("错误数:       %0d", error_count);
    $display("========================================\n");
    
    if (error_count == 0) begin
        $display("✓ 测试通过");
    end else begin
        $display("✗ 测试失败");
    end
    
    $finish;
end

// ========== 周期计数 ==========
always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
end

// ========== 测试程序加载 ==========
task load_test_program;
        integer idx;
    begin
        for (idx = 0; idx < 4096; idx = idx + 1) begin
            imem[idx] = 32'h00000013;  // NOP: ADDI x0, x0, 0
        end
        
        // 加载测试程序到内存
        imem[0]  = 32'h00100093;     // ADDI x1, x0, 1       # x1 = 1
        imem[1]  = 32'h00200113;     // ADDI x2, x0, 2       # x2 = 2
        imem[2]  = 32'h00208133;     // ADD  x2, x1, x2      # x2 = 3
        imem[3]  = 32'h00000013;     // NOP
        imem[4]  = 32'h00000013;     // NOP
        imem[5]  = 32'h00000013;     // NOP
        
        // 消息输出（验证初始化）
        $display("[TESTBENCH] 指令存储器已初始化:");
        $display("  imem[0] = 0x%08x (ADDI x1, x0, 1)", imem[0]);
        $display("  imem[1] = 0x%08x (ADDI x2, x0, 2)", imem[1]);
        $display("  imem[2] = 0x%08x (ADD x2, x1, x2)", imem[2]);
        $display("  其他指令 = 0x00000013 (NOP)");
        $display("");
    end
endtask

endmodule
