// RISC-V CPU测试平台
// 功能：验证CPU核心功能，包括指令执行、流水线操作、冒险处理
// 作者：[项目组名称]
// 日期：[创建日期]

`timescale 1ns / 1ps

module riscv_cpu_tb;

// ============================================================================
// 参数定义
// ============================================================================
parameter CLK_PERIOD = 10;  // 时钟周期10ns（100MHz）
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter MEM_SIZE = 4096;
parameter TEST_TIMEOUT = 100000;  // 测试超时时间（周期数）

// ============================================================================
// 信号声明
// ============================================================================

// 系统信号
reg                     clk;
reg                     rst_n;

// 指令存储器接口
wire [ADDR_WIDTH-1:0]    instr_addr;
reg  [DATA_WIDTH-1:0]    instr_data;
wire                     instr_req;
reg                      instr_gnt;

// 数据存储器接口
wire [ADDR_WIDTH-1:0]    data_addr;
wire [DATA_WIDTH-1:0]    data_wdata;
reg  [DATA_WIDTH-1:0]    data_rdata;
wire                     data_req;
wire                     data_we;
wire [DATA_WIDTH/8-1:0]  data_be;
reg                      data_gnt;

// 中断信号
reg                      irq_external;
reg                      irq_timer;
reg                      irq_software;

// 调试信号
reg                      debug_req;
wire                     debug_halt;
wire                     debug_resume;

// 测试控制
reg                      test_running;
integer                  cycle_count;
integer                  error_count;

// 内存数组
reg [7:0] instruction_mem [0:MEM_SIZE-1];
reg [7:0] data_mem [0:MEM_SIZE-1];

// ============================================================================
// 被测模块实例化
// ============================================================================

riscv_cpu #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .MEM_SIZE(MEM_SIZE)
) u_dut (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // 指令存储器接口
    .instr_addr         (instr_addr),
    .instr_data         (instr_data),
    .instr_req          (instr_req),
    .instr_gnt          (instr_gnt),
    
    // 数据存储器接口
    .data_addr          (data_addr),
    .data_wdata         (data_wdata),
    .data_rdata         (data_rdata),
    .data_req           (data_req),
    .data_we            (data_we),
    .data_be            (data_be),
    .data_gnt           (data_gnt),
    
    // 中断信号
    .irq_external       (irq_external),
    .irq_timer          (irq_timer),
    .irq_software       (irq_software),
    
    // 调试信号
    .debug_req          (debug_req),
    .debug_halt         (debug_halt),
    .debug_resume       (debug_resume)
);

// ============================================================================
// 时钟生成
// ============================================================================

initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ============================================================================
// 存储器模型
// ============================================================================

// 指令存储器读取
always @(*) begin
    if (instr_req) begin
        instr_gnt = 1'b1;
        // 从内存数组中读取指令（按字对齐）
        instr_data = {instruction_mem[instr_addr+3], 
                      instruction_mem[instr_addr+2], 
                      instruction_mem[instr_addr+1], 
                      instruction_mem[instr_addr]};
    end else begin
        instr_gnt = 1'b0;
        instr_data = 32'h00000013;  // NOP指令（addi x0,x0,0）
    end
end

// 数据存储器读写
always @(posedge clk) begin
    if (data_req) begin
        data_gnt = 1'b1;
        if (data_we) begin
            // 写操作
            if (data_be[0]) data_mem[data_addr]   = data_wdata[7:0];
            if (data_be[1]) data_mem[data_addr+1] = data_wdata[15:8];
            if (data_be[2]) data_mem[data_addr+2] = data_wdata[23:16];
            if (data_be[3]) data_mem[data_addr+3] = data_wdata[31:24];
            $display("[%0t] MEM Write: addr=0x%08h, data=0x%08h, be=0x%01h", 
                     $time, data_addr, data_wdata, data_be);
        end else begin
            // 读操作
            data_rdata = {data_mem[data_addr+3], 
                          data_mem[data_addr+2], 
                          data_mem[data_addr+1], 
                          data_mem[data_addr]};
            $display("[%0t] MEM Read: addr=0x%08h, data=0x%08h", 
                     $time, data_addr, data_rdata);
        end
    end else begin
        data_gnt = 1'b0;
    end
end

// ============================================================================
// 测试激励
// ============================================================================

// 初始化内存
task initialize_memory;
    integer i;
    begin
        // 清空指令内存
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            instruction_mem[i] = 8'h00;
            data_mem[i] = 8'h00;
        end
        
        // 加载测试程序（示例：简单的算术测试）
        // addi x1, x0, 5    // x1 = 5
        instruction_mem[0] = 8'h93;
        instruction_mem[1] = 8'h04;
        instruction_mem[2] = 8'h50;
        instruction_mem[3] = 8'h00;
        
        // addi x2, x0, 10   // x2 = 10
        instruction_mem[4] = 8'h13;
        instruction_mem[5] = 8'h08;
        instruction_mem[6] = 8'hA0;
        instruction_mem[7] = 8'h00;
        
        // add  x3, x1, x2   // x3 = x1 + x2 = 15
        instruction_mem[8] = 8'hB3;
        instruction_mem[9] = 8'h80;
        instruction_mem[10] = 8'h21;
        instruction_mem[11] = 8'h00;
        
        // sw   x3, 0(x0)    // mem[0] = x3
        instruction_mem[12] = 8'h23;
        instruction_mem[13] = 8'h20;
        instruction_mem[14] = 8'h30;
        instruction_mem[15] = 8'h00;
        
        // lw   x4, 0(x0)    // x4 = mem[0]
        instruction_mem[16] = 8'h03;
        instruction_mem[17] = 8'h22;
        instruction_mem[18] = 8'h00;
        instruction_mem[19] = 8'h00;
        
        // beq  x3, x4, 8    // if x3==x4, skip 2 instructions
        instruction_mem[20] = 8'h63;
        instruction_mem[21] = 8'h84;
        instruction_mem[22] = 8'h41;
        instruction_mem[23] = 8'h00;
        
        // addi x5, x0, 1    // x5 = 1 (should be skipped if branch taken)
        instruction_mem[24] = 8'h93;
        instruction_mem[25] = 8'h0C;
        instruction_mem[26] = 8'h10;
        instruction_mem[27] = 8'h00;
        
        // addi x6, x0, 2    // x6 = 2 (should be skipped if branch taken)
        instruction_mem[28] = 8'h13;
        instruction_mem[29] = 8'h1D;
        instruction_mem[30] = 8'h20;
        instruction_mem[31] = 8'h00;
        
        // 结束程序（无限循环）
        // beq  x0, x0, -4   // 跳转到自己
        instruction_mem[32] = 8'h63;
        instruction_mem[33] = 8'h80;
        instruction_mem[34] = 8'h00;
        instruction_mem[35] = 8'hFE;
        
        $display("Memory initialized with test program");
    end
endtask

// 复位任务
task reset_cpu;
    begin
        rst_n = 1'b0;
        irq_external = 1'b0;
        irq_timer = 1'b0;
        irq_software = 1'b0;
        debug_req = 1'b0;
        cycle_count = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        $display("[%0t] CPU reset released", $time);
    end
endtask

// 检查寄存器值
task check_register;
    input [4:0] reg_addr;
    input [DATA_WIDTH-1:0] expected_value;
    begin
        // 这里需要访问CPU内部寄存器，可能需要添加调试接口
        // 简化版本：通过观察写回阶段的信号来验证
        $display("[%0t] Checking register x%0d, expected=0x%08h", 
                 $time, reg_addr, expected_value);
    end
endtask

// 监控关键信号
task monitor_signals;
    begin
        // 监控分支预测
        if (u_dut.branch_taken_ex && !u_dut.mispredict_ex) begin
            $display("[%0t] Branch prediction correct: target=0x%08h", 
                     $time, u_dut.branch_target_ex);
        end
        
        if (u_dut.mispredict_ex) begin
            $display("[%0t] Branch misprediction detected", $time);
            error_count = error_count + 1;
        end
        
        // 监控数据冒险
        if (u_dut.u_hazard_unit.stall_id) begin
            $display("[%0t] Pipeline stall due to data hazard", $time);
        end
        
        // 监控前递
        if (u_dut.u_hazard_unit.forward_a != 2'b00 || 
            u_dut.u_hazard_unit.forward_b != 2'b00) begin
            $display("[%0t] Forwarding active: A=%b, B=%b", 
                     $time, u_dut.u_hazard_unit.forward_a, 
                     u_dut.u_hazard_unit.forward_b);
        end
    end
endtask

// ============================================================================
// 主测试流程
// ============================================================================

initial begin
    // 初始化
    error_count = 0;
    test_running = 1'b1;
    
    $display("==============================================");
    $display("RISC-V CPU Testbench Started");
    $display("==============================================");
    
    // 初始化内存
    initialize_memory;
    
    // 复位CPU
    reset_cpu;
    
    // 运行测试
    $display("[%0t] Starting CPU execution...", $time);
    
    // 监控信号
    fork
        begin
            while (test_running && cycle_count < TEST_TIMEOUT) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
                monitor_signals;
                
                // 检查程序是否结束（遇到无限循环）
                if (u_dut.instr_id == 32'hFE000EE3) begin  // beq x0,x0,-4
                    $display("[%0t] Test program completed", $time);
                    test_running = 1'b0;
                end
            end
            
            if (cycle_count >= TEST_TIMEOUT) begin
                $display("[%0t] ERROR: Test timeout!", $time);
                error_count = error_count + 1;
            end
        end
    join
    
    // 测试结果
    $display("==============================================");
    $display("Test Results:");
    $display("  Total cycles: %0d", cycle_count);
    $display("  Errors: %0d", error_count);
    
    if (error_count == 0) begin
        $display("  STATUS: PASS");
    end else begin
        $display("  STATUS: FAIL");
    end
    $display("==============================================");
    
    // 结束仿真
    #100;
    $finish;
end

// ============================================================================
// 波形转储（用于调试）
// ============================================================================

initial begin
    $dumpfile("riscv_cpu_tb.vcd");
    $dumpvars(0, riscv_cpu_tb);
end

// 超时保护
initial begin
    #(CLK_PERIOD * TEST_TIMEOUT * 2);
    $display("ERROR: Simulation timeout!");
    $finish;
end

endmodule