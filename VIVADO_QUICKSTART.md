# Vivado 中测试 Vega CPU 的快速参考

## 🚀 三种快速开始方式

### 方式 1️⃣：GUI 模式（交互式，推荐）
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
bash vivado_test.sh gui
# 或
vivado Vega.xpr
```

**优点:** 可视化、易于调试、可实时波形查看

**步骤:**
1. GUI 打开后，点击 **Flow → Simulation → Run Behavioral Simulation**
2. 等待仿真启动，查看波形
3. 点击 **Flow → Synthesis** 运行综合

---

### 方式 2️⃣：命令行自动化模式（快速）
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
bash vivado_test.sh batch
```

**优点:** 无需交互、自动化、时间短

**执行内容:**
- ✅ 打开项目
- ✅ 添加新文件 (`ii_stage.v`)
- ✅ 运行行为仿真
- ✅ 运行综合
- ✅ 生成报告

**预计时间:** 10-15 分钟

---

### 方式 3️⃣：Vivado Xsim 仅仿真模式
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
bash vivado_test.sh sim
```

**优点:** 最快速，仅验证功能

**预计时间:** 2-3 分钟

---

## 📋 完整 Vivado GUI 工作流 (初学者指南)

### 步骤 1: 打开项目
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
vivado Vega.xpr &
```

### 步骤 2: 添加新文件

在 Vivado GUI 中：

```
File → Add Sources
  ↓
Select "Add Files"
  ↓
选择文件:
  □ /home/liyu/cpuP/Vega_cpu/src/cpu/core/ii_stage/ii_stage.v (新增!)
  □ /home/liyu/cpuP/Vega_cpu/src/cpu/riscv_cpu.v (更新)
  □ /home/liyu/cpuP/Vega_cpu/src/cpu/core/if_stage/if_stage.v (更新)
  □ /home/liyu/cpuP/Vega_cpu/src/cpu/core/id_stage/id_stage.v (更新)
  □ /home/liyu/cpuP/Vega_cpu/src/cpu/core/ex_stage/ex_stage.v (更新)
  ✓ 其他文件...
  ↓
Next → Finish
```

### 步骤 3: 设置顶层模块

在 Hierarchy 面板中：
```
右击 riscv_cpu.v
  ↓
Set as Top
```

### 步骤 4: 创建仿真配置

```
Flow → Simulation → Setup Simulation
  ↓
创建仿真文件集 (sim_behavioral)
  ↓
Add Source → test/riscv_cpu_tb_dual.v
  ↓
OK
```

### 步骤 5: 运行仿真

```
Flow → Simulation → Run Behavioral Simulation
(或快捷键 Shift+F6)
  ↓
Xsim 窗口打开
  ↓
Run All
```

**预期输出:**
```
[TESTBENCH] 测试程序已加载
仿真完成
总周期数: 205
发射指令数: 0
错误数: 0
========================================

✓ 测试通过
```

### 步骤 6: 查看波形

在 Xsim 窗口中：

```
左侧 Scope → riscv_cpu_tb → u_dut
  ↓
右侧 Objects 中双击信号:
  • clk
  • rst_n
  • instr_addr
  • instr_data_w1
  • instr_data_w2
  ↓
拖到 Wave 窗口
  ↓
Run All
```

### 步骤 7: 运行综合

```
Flow → Synthesis → Run Synthesis
(需要 2-5 分钟)
  ↓
综合完成
  ↓
双击 synth_1 查看结果
```

**检查项:**
- ✓ 是否有 ERROR
- ✓ 资源使用情况
- ✓ 计时器数量

### 步骤 8: 运行实现

```
Flow → Implementation → Run Implementation
(需要 3-8 分钟)
  ↓
实现完成
  ↓
查看时序报告
```

---

## 🧪 TCL 命令速查

### 在 Vivado TCL Console 中运行

#### 打开/管理项目
```tcl
open_project Vega.xpr
save_project_as
close_project
```

#### 管理源文件
```tcl
# 添加文件
add_files -fileset sources_1 path/to/file.v

# 移除文件
remove_files [get_files file.v]

# 设置顶层
set_property top riscv_cpu [current_fileset]

# 列出所有源文件
get_files -fileset sources_1
```

#### 仿真相关
```tcl
# 创建仿真文件集
create_fileset -simset sim_behavioral

# 添加 testbench
add_files -fileset sim_behavioral test/riscv_cpu_tb_dual.v

# 设置仿真顶层
set_property top riscv_cpu_tb [get_filesets sim_behavioral]

# Elaborate 设计
elaborate_design

# 启动仿真
launch_simulation

# 运行仿真
run all

# 关闭仿真
close_sim
```

#### 综合
```tcl
# 准备综合
reset_run synth_1

# 运行综合
launch_runs synth_1 -jobs 8

# 等待完成
wait_on_run synth_1

# 打开综合结果
open_run synth_1

# 生成报告
report_utilization -file /tmp/util.txt
report_timing -file /tmp/timing.txt
```

#### 实现
```tcl
# 准备实现
reset_run impl_1

# 运行实现
launch_runs impl_1 -jobs 8

# 等待完成
wait_on_run impl_1

# 打开实现结果
open_run impl_1

# 生成比特流
write_bitstream -force /tmp/vega.bit
```

---

## ✅ 验证检查清单

### 仿真验证
- [ ] Testbench 正确加载
- [ ] 仿真运行 205+ 周期无错误
- [ ] 波形显示正常的时钟
- [ ] `instr_addr` 递增正常
- [ ] `instr_data_w1/w2` 是有效指令

### 综合验证
- [ ] 编译无 CRITICAL 错误
- [ ] 资源使用 < 50% (建议)
- [ ] 所有模块识别正确

### 实现验证
- [ ] 路由成功
- [ ] **Setup Slack > 0** ✅
- [ ] **Hold Slack > 0** ✅
- [ ] 最大频率 ≥ 80 MHz

---

## 🔍 常见错误与解决

| 错误 | 原因 | 解决 |
|------|------|------|
| "Cannot find module riscv_cpu" | 源文件未添加 | Add Files → 添加所有 .v 文件 |
| "Elaboration failed" | 模块连接错误 | 检查 riscv_cpu.v 中的端口名 |
| "Slack < 0" | 时序不满足 | 降低频率或优化关键路径 |
| "Multi-driven net" | 多个驱动源 | 检查信号连接，移除重复驱动 |
| 仿真无输出 | Testbench 路径错误 | 检查 tb_dual.v 在 sim_behavioral 中 |

---

## 📊 性能指标获取

### 运行时间统计
```tcl
# 在 TCL Console 中
set start_time [clock seconds]
# ... 运行命令 ...
set end_time [clock seconds]
set elapsed [expr {$end_time - $start_time}]
puts "耗时: $elapsed 秒"
```

### 资源使用
```tcl
report_utilization -hierarchical -file /tmp/util_hier.txt
```

### 时序分析
```tcl
report_timing_summary -file /tmp/timing_summary.txt
report_timing -sort_by slack -file /tmp/timing_detail.txt
```

### 功耗评估
```tcl
report_power -file /tmp/power_report.txt
```

---

## 📚 文档导航

| 文档 | 说明 |
|------|------|
| `docs/VIVADO_TESTING.md` | 详细 Vivado 使用指南 |
| `docs/VERIFICATION_GUIDE.md` | RTL 仿真完整指南 |
| `VERIFICATION_STATUS.md` | 验证进度报告 |
| `docs/ARCHITECTURE.md` | 6 级双发射架构设计 |

---

## 🎯 快速决策树

```
想要快速验证?
  ├─ 是 → 运行: bash vivado_test.sh batch
  └─ 否 ↓

想要可视化调试?
  ├─ 是 → 打开: vivado Vega.xpr (GUI)
  └─ 否 ↓

只想测试仿真功能?
  ├─ 是 → 运行: bash vivado_test.sh sim
  └─ 否 ↓

需要 FPGA 硬件文件?
  └─ 运行实现后: write_bitstream -force vega.bit
```

---

## 📞 技术支持

**问题排查步骤:**

1. 查看详细日志
   ```bash
   tail -100 /tmp/vivado_verify.log
   ```

2. 在 Vivado TCL Console 中运行诊断
   ```tcl
   get_files
   get_property top [current_fileset]
   check_syntax
   ```

3. 参考官方文档
   - [Xilinx Vivado 官方手册](https://docs.xilinx.com)

---

## ⏱️ 预计耗时

| 任务 | GUI 模式 | Batch 模式 | 仅仿真 |
|------|---------|-----------|-------|
| 打开项目 | 30s | 自动 | - |
| 添加文件 | 1-2m | 自动 | - |
| 运行仿真 | 2-3m | 2-3m | 1-2m |
| 综合 | 2-5m | 2-5m | - |
| 实现 | 3-8m | - | - |
| **总计** | **8-20m** | **5-10m** | **1-2m** |

---

✨ **现在您可以开始在 Vivado 中测试 CPU 了！**

