# Vega CPU 6 级双发射验证指南

## 📋 快速开始

### 步骤 1：快速 RTL 仿真（5分钟）
```bash
cd /home/liyu/cpuP/Vega_cpu
bash test/run_rtl_sim.sh
```

**预期输出：**
- 语法检查通过
- 仿真运行 200 个周期
- "✓ 测试通过" 或错误列表

---

## 🧪 验证方法详解

### A. RTL 仿真验证（推荐首先进行）

#### A1. 单元测试
对各个阶段进行隔离测试：

```bash
cd /home/liyu/cpuP/Vega_cpu/test

# 测试 ALU
iverilog -g2001 modules/tb_alu.v ../src/cpu/core/ex_stage/alu.v -o tb_alu && vvp tb_alu

# 测试译码器
iverilog -g2001 modules/tb_decoder.v ../src/cpu/core/id_stage/decoder.v -o tb_decoder && vvp tb_decoder

# 测试寄存器堆（已改为4R/2W）
iverilog -g2001 modules/tb_register_file.v ../src/cpu/core/id_stage/register_file.v -o tb_rf && vvp tb_rf

# 测试 BTB
iverilog -g2001 modules/tb_btb.v ../src/cpu/core/if_stage/btb.v -o tb_btb && vvp tb_btb

# 测试 BHT
iverilog -g2001 modules/tb_bht.v ../src/cpu/core/if_stage/bht.v -o tb_bht && vvp tb_bht
```

#### A2. 集成仿真
通过新的双发射 testbench：

```bash
cd /home/liyu/cpuP/Vega_cpu/build_sim
iverilog -g2001 -Wall \
    ../src/cpu/riscv_cpu.v \
    ../src/cpu/core/*/[!_]*.v \
    ../src/cpu/core/*/*/*.v \
    ../test/riscv_cpu_tb_dual.v \
    -o vega_rtl && vvp vega_rtl
```

---

### B. 功能验证（加载实际程序）

#### 选项 B1：简单汇编程序测试

创建 `test/simple_program.s`：
```asm
# 简单测试程序
# 验证基础 ALU、访存、跳转

.section .text
.globl _start

_start:
    # 测试 ADD 指令（可双发射）
    addi x1, x0, 5        # x1 = 5
    addi x2, x0, 3        # x2 = 3
    add  x3, x1, x2       # x3 = 8
    
    # 测试访存
    la   x4, data_area    # x4 = &data_area
    addi x5, x0, 42
    sw   x5, 0(x4)        # mem[x4] = 42
    lw   x6, 0(x4)        # x6 = 42
    
    # 测试分支
    beq  x6, x5, success  # 如果 x6==x5，跳转
    j    failure
    
success:
    addi x7, x0, 1        # x7 = 1 (成功标志)
    j    end
    
failure:
    addi x7, x0, 0        # x7 = 0 (失败标志)
    
end:
    j    end              # 无限循环

.section .data
data_area:
    .word 0
```

编译和链接：
```bash
riscv64-unknown-elf-as test/simple_program.s -o /tmp/prog.o
riscv64-unknown-elf-ld /tmp/prog.o -o /tmp/prog.elf
riscv64-unknown-elf-objcopy -O binary /tmp/prog.elf /tmp/prog.bin
riscv64-unknown-elf-objdump -d /tmp/prog.elf  # 查看机器码
```

#### 选项 B2：使用 CoreMark 基准测试

```bash
cd /home/liyu/cpuP/Vega_cpu/tools/riscv-coremark
bash build-coremark.sh
```

---

### C. Vivado 综合验证（完整硬件验证）

#### C1. RTL 综合

在 Vivado 中打开项目：
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
vivado Vega.xpr
```

或在命令行启动综合：
```bash
vivado -mode batch -source run_synthesis.tcl
```

**检查项：**
- 无 CRITICAL 警告
- 资源使用合理（LUT、FF、BRAM）
- 检查 timing 报告：setup/hold time met

#### C2. GitHub 实现流程

```bash
vivado -mode batch -source run_implementation.tcl
```

**检查项：**
- 路由成功（无未路由网线）
- 时序约束满足
- 功率评估合理

---

## 📊 关键验证点

### 1. 流水线正确性
- [ ] IF 阶段：双取指 (PC, PC+4) 工作正常
- [ ] ID 阶段：IDII 寄存器正确锁存
- [ ] II 阶段：冒险检测准确（RAW/WAW/structural）
- [ ] EX 阶段：双 ALU 并行执行，前递单元正常
- [ ] MEM 阶段：Way1 访存，Way2 透传
- [ ] WB 阶段：双路写回无冲突

### 2. 双发射阻塞条件
- [ ] RAW 冒险正确阻塞
- [ ] WAW 冒险正确阻塞
- [ ] 结构冒险（2× 内存端口）检测
- [ ] 控制冒险（分支）正确处理
- [ ] CSR 指令系统冒险阻塞

### 3. 分支预测
- [ ] BTB 命中/未命中逻辑
- [ ] BHT 动态预测工作
- [ ] 预测错误后正确 flush+异常恢复

### 4. 寄存器堆
- [ ] 4 读端口同时读取正确
- [ ] 2 写端口无冲突写入
- [ ] `x0` 恒为 0

### 5. 指令解码
- [ ] 双路译码器同时工作
- [ ] 控制信号生成准确

---

## 🔧 故障排除

### 问题：仿真出现 "ERROR: 指令地址未对齐"
**原因：** 分支目标或 PC 不是 4 字节对齐
**解决：** 检查 BTB/分支逻辑是否正确对齐

### 问题：数据冒险导致的不匹配
**原因：** 前递单元或 RAW 检测有缺陷
**解决：** 在 II 阶段添加 `$display` 追踪冒险信号

### 问题：综合失败或时序不满足
**原因：** 6 级流水线延迟过高
**解决：** 
1. 检查 fmax 是否满足（如 100MHz）
2. 考虑在 EX/MEM 间添加额外流水寄存器
3. 优化前递逻辑复杂度

---

## 📈 性能评估

### 关键指标
- **吞吐量 (IPC):** 理想双发射 = 2.0，实际 ≈ 1.2-1.7（取决于冒险）
- **频率 (MHz):** 目标≥80MHz（确认在 Vivado 中）
- **面积 (LUT/FF):** 相对于单发射增加 ≈30-40%
- **功耗 (mW):** 监控内部活动因子

### 测量方法

在 testbench 中添加指令计数：
```verilog
// 在每条指令完成时统计
always @(posedge clk) begin
    if (instr_valid) instr_count <= instr_count + 1;
end

real ipc = instr_count / cycle_count;
$display("IPC = %0.2f", ipc);
```

---

## 📝 检查清单

- [ ] ✓ 语法检查通过（iverilog）
- [ ] 单元测试全部通过
- [ ] RTL 仿真跑 1000+ 周期无错误
- [ ] 测试程序执行正确
- [ ] 分支预测工作
- [ ] 数据冒险正确处理
- [ ] Vivado 综合成功
- [ ] 时序约束满足
- [ ] 硬件逻辑验证通过（如有 FPGA）

---

## 🚀 后续工作

1. **更新所有模块 testbench** - 对标新的双发射接口
2. **集成 Core Marker** - 在实际硬件上验证
3. **性能分析** - 对比单发射 vs 双发射 IPC
4. **功耗优化** - 考虑时钟门控等技术

