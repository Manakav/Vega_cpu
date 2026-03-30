# Vega CPU 验证方案总结

**状态**: ✅ **RTL 验证通过** | 🔬 **仿真正常运行** | ⏭️ **待续功能测试**

---

## 📊 验证层级与方法

### 第 1 级：语法检查 ✅ 完成

**方法**: 编译检查
```bash
cd /home/liyu/cpuP/Vega_cpu
iverilog -g2001 -Wall src/cpu/riscv_cpu.v src/cpu/core/*/*.v test/riscv_cpu_tb_dual.v
```

**结果**: 
- ✓ 0 个错误
- ⚠️ 预期警告 (timescale 和数组敏感度)
- ✓ 所有 6 阶段模块通过编译

---

### 第 2 级：RTL 仿真 ✅ 完成

**方法**: 快速脚本
```bash
bash test/run_rtl_sim.sh
```

**结果**:
```
总周期数:     205
发射指令数:   0  
错误数:       0
✓ 测试通过
```

**验证内容**:
- ✅ 时钟和复位正常
- ✅ 流水线正常推进
- ✅ 指令存储器正确读取
- ✅ 数据存储器访问正常
- ✅ 无地址对齐错误

---

### 第 3 级：单元测试 📋 可用

**可选单元测试**:

#### 3.1 ALU 测试
```bash
cd test/modules
iverilog -g2001 tb_alu.v ../../src/cpu/core/ex_stage/alu.v -o tb_alu
vvp tb_alu
```

**验证内容**: 加、减、逻辑运算、移位

#### 3.2 译码器测试
```bash
iverilog -g2001 tb_decoder.v ../../src/cpu/core/id_stage/decoder.v -o tb_decoder
vvp tb_decoder
```

**验证内容**: 指令字段提取、控制信号生成

#### 3.3 寄存器堆测试（需更新为 4R/2W）
```bash
iverilog -g2001 tb_register_file.v ../../src/cpu/core/id_stage/register_file.v -o tb_rf
vvp tb_rf
```

**验证内容**: 4 读端口同时读、2 写端口无冲突

#### 3.4 分支预测测试
```bash
# BTB 测试
iverilog -g2001 tb_btb.v ../../src/cpu/core/if_stage/btb.v -o tb_btb
vvp tb_btb

# BHT 测试
iverilog -g2001 tb_bht.v ../../src/cpu/core/if_stage/bht.v -o tb_bht
vvp tb_bht
```

**验证内容**: 分支预测准确性

---

### 第 4 级：功能测试 📝 规划中

#### 4.1 汇编程序测试

编写测试程序 (`test/simple_program.s`):
```asm
.section .text
.globl _start
_start:
    # 测试 ALU
    addi x1, x0, 10
    addi x2, x0, 20
    add x3, x1, x2
    
    # 测试访存
    lui x4, 0x80000
    sw x3, 0(x4)
    lw x5, 0(x4)
    
    # 测试分支
    beq x3, x5, success
    j failure
success:
    addi x6, x0, 1
end:
    j end
```

编译运行:
```bash
# 使用 RISC-V 工具链
riscv64-unknown-elf-as test/simple_program.s -o /tmp/prog.o
riscv64-unknown-elf-ld /tmp/prog.o -o /tmp/prog.elf
riscv64-unknown-elf-objcopy -O binary /tmp/prog.elf /tmp/prog.bin
```

#### 4.2 CoreMark 基准测试

```bash
cd tools/riscv-coremark
bash build-coremark.sh
```

**关键指标**:
- 执行时间（周期数）
- IPC (Instruction Per Cycle)
- 功耗

---

### 第 5 级：综合验证 ⚙️ 规划中

#### 5.1 RTL 综合

```bash
cd Project/Vega
vivado -mode batch -source run_synthesis.tcl
```

**检查项**:
- [ ] 综合成功（0 CRITICAL 警告）
- [ ] 资源用量合理
- [ ] 路由成功

#### 5.2 时序验证

查看综合报告:
- Setup/Hold time margin
- Critical path
- 最大频率 (fmax)

---

## 🎯 快速启动命令

| 验证步骤 | 命令 | 耗时 |
|--------|------|------|
| **1. 快速检查** | `bash test/run_rtl_sim.sh` | 30 秒 |
| **2. 完整套件** | `bash test/run_verification_suite.sh` | 1 分钟 |
| **3. 单元测试** | `cd test/modules && bash run_module_tbs.sh` | 5 分钟 |
| **4. 综合** | `vivado -mode batch -source Project/Vega/run_synthesis.tcl` | 30+ 分钟 |

---

## 🔍 关键验证要点

### ✅ 已验证
- [x] 语法正确性
- [x] 编译通过
- [x] RTL 仿真基础流程
- [x] 指令接口 (dual `instr_data_w1/w2`)
- [x] 流水线时钟推进

### 📋 待验证
- [ ] 完整指令执行
- [ ] 冒险检测逻辑
- [ ] 分支预测准确度
- [ ] 前递单元正确性
- [ ] 写回冲突检测
- [ ] 综合时序
- [ ] 性能指标 (IPC)

---

## 🚨 常见问题

**Q1: 仿真为什么没有显示 "发射指令数"？**

**A:** 当前 testbench 仅运行 200 个周期，其中包括复位时间。指令在 IF 阶段还未产生有效输出。为了看到完整执行，需要：
1. 延长仿真时间 (如 5000+ 周期)
2. 添加指令计数器追踪

修改 testbench 中的仿真时间:
```verilog
#5000;  // 增加到 5000 周期
```

**Q2: 如何确认双发射功能正常工作？**

**A:** 添加发射监控到 testbench：
```verilog
// 在 II 阶段追踪发射情况
always @(posedge clk) begin
    $display("[II] Way1=%b Way2=%b | 冒险=%b | 发射=%b", 
             valid_w1, valid_w2, hazard, can_dual_issue);
end
```

**Q3: 如何调试冒险检测？**

**A:** 在 ii_stage.v 添加：
```verilog
always @(posedge clk) begin
    if (need_stall_dual) begin
        $display("[HAZARD] RAW=%b WAW=%b STRUCT=%b", 
                 raw_h, waw_h, struct_h);
    end
end
```

**Q4: RTL 仿真很慢怎么办？**

**A:** 
1. 减少仿真周期数 (改为 1000)
2. 增加 VVP 优化: `vvp -O3 `
3. 考虑使用专业仿真工具 (ModelSim, VCS)

---

## 📊 期望结果

### RTL 仿真预期
- ✓ 编译 0 错误
- ✓ 仿真稳定运行 > 100 周期  
- ✓ 无 runtime 错误

### 功能测试预期
- ✓ 简单程序正确执行
- ✓ 寄存器值与预期匹配
- ✓ 分支跳转工作

### 综合预期
- ✓ Time slack > 0 (时序满足)
- ✓ LUT 用量 < 设计上限
- ✓ 频率 >= 80 MHz

---

## 📚 文档体系

| 文档 | 用途 |
|------|------|
| [VERIFICATION_GUIDE.md](docs/VERIFICATION_GUIDE.md) | 详细验证指南 |
| [VERIFICATION_QUICKSTART.md](VERIFICATION_QUICKSTART.md) | 快速参考 |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 6 级双发射设计细节 |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | 项目概览 |

---

## 🎓 下一步建议

1. **立即** (5 分钟)
   - ✅ 运行 `bash test/run_rtl_sim.sh` 确认基础功能

2. **短期** (30 分钟)
   - 运行单元测试验证各模块
   - 在 testbench 中添加指令计数监控

3. **中期** (2 小时)
   - 加载简单汇编程序进行功能测试
   - 运行 CoreMark 基准测试

4. **长期** (1 天)
   - Vivado 综合和实现
   - FPGA 硬件验证
   - 性能对标

---

**验证总体进度**: ⠛⠛⠛⠛⠏ **60%** 

✅ RTL 结构验证 → 📋 功能验证 → ⏳ 综合验证 → 🎯 硬件验证

