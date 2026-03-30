# Vivado 中的 Vega CPU 6 级双发射仿真与验证

## 📋 快速开始

### 方法 A: 图形界面 (推荐)
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
vivado Vega.xpr
```

### 方法 B: 命令行
```bash
cd /home/liyu/cpuP/Vega_cpu/Project/Vega
vivado -mode batch -source vivado_verify.tcl
```

---

## 🖥️ 图形界面步骤详解

### 步骤 1: 打开项目

```bash
vivado Vega.xpr
```

**预期画面:**
- Vivado GUI 启动
- 左侧面板显示 "Hierarchy"
- 底部显示现有仿真集合 (Decoder)

### 步骤 2: 更新项目文件

**问题:** 项目中缺少新的 `ii_stage.v` 模块

**解决方案:**

1. 在 Vivado 中，点击 **File → Add Sources**

   ![File Menu](docs/vivado_add_sources.png)

2. 选择 **Add Files** 并添加以下新文件：
   ```
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/ii_stage/ii_stage.v       (新增)
   /home/liyu/cpuP/Vega_cpu/src/cpu/riscv_cpu.v                    (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/if_stage/if_stage.v       (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/id_stage/id_stage.v       (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/ex_stage/ex_stage.v       (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/mem_stage/mem_stage.v     (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/id_stage/register_file.v (已更新)
   /home/liyu/cpuP/Vega_cpu/src/cpu/core/hazard_unit.v             (已更新)
   ```

3. 点击 **Next** → **Finish**

**或使用 TCL 命令:**
```tcl
add_files -fileset sources_1 {
    /home/liyu/cpuP/Vega_cpu/src/cpu/core/ii_stage/ii_stage.v
}
```

### 步骤 3: 更新顶层模块

1. 右击 **riscv_cpu.v** → **Set as Top**

   ![Set as Top](docs/vivado_set_top.png)

2. 或在 TCL Console 中运行：
   ```tcl
   set_property top riscv_cpu [current_fileset]
   ```

### 步骤 4: 创建行为仿真配置

1. 点击 **Flow → Simulation → Behavioral Simulation**

   ![Behavioral Simulation](docs/vivado_sim_menu.png)

2. 或在 TCL Console：
   ```tcl
   create_fileset -simset sim_behavioral
   ```

### 步骤 5: 添加行为仿真 Testbench

1. 右击 **sim_behavioral** → **Add Sources**

2. 选择 **Add Files** 并添加：
   ```
   /home/liyu/cpuP/Vega_cpu/test/riscv_cpu_tb_dual.v
   ```

3. 完成后查看文件树结构。

**验证结果:**
- sim_behavioral 文件集包含 testbench
- riscv_cpu_tb_dual 显示为 Simulation Source

### 步骤 6: 配置仿真参数

1. 右击 **sim_behavioral** → **Simulation Settings**

2. 在 "Elaboration" 页签中设置：
   - Top Module: `riscv_cpu_tb`
   - Default Library: `xil_defaultlib`

3. 在 "Simulation" 页签中设置：
   - Simulation Time: `2050 ns`  (对应 testbench 中的 #2000 ns 仿真)
   - Simulation Type: `Behavioral`

   ![Simulation Settings](docs/vivado_sim_settings.png)

4. 点击 **OK**

### 步骤 7: 运行行为仿真

**GUI 方式:**

1. 点击 **Flow → Run Behavioral Simulation**

   ![Run Simulation](docs/vivado_run_sim.png)

2. 或按快捷键: **Shift + F6**

**预期输出:**

```
launch_simulation
...
[TESTBENCH] 测试程序已加载
仿真完成
总周期数: 205
发射指令数: 0
错误数: 0
========================================

✓ 测试通过
```

### 步骤 8: 查看波形

在 Xsim 窗口中：

1. 左侧 **Scope** 面板展开 `riscv_cpu_tb` 层次

2. 在 **Objects** 中选择关键信号：
   ```
   u_dut.clk
   u_dut.rst_n
   u_dut.instr_addr
   u_dut.instr_data_w1
   u_dut.instr_data_w2
   u_dut.instr_req
   u_dut.cycle_count
   ```

3. 双击或拖到 **Wave** 窗口

4. 点击 **Run All** 完整执行

   ![Waveform View](docs/vivado_waveform.png)

**查看要点:**
- `instr_addr` 是否每周期 +8（双发射）
- `instr_data_w1/w2` 是否都是有效指令
- `cycle_count` 正常递增
- 时序正确（无时钟偏差）

### 步骤 9: 添加探针（Probe）追踪关键信号

**追踪双发射情况:**

在 TCL Console 中：
```tcl
# 添加显示 II 阶段冒险信号
add_wave {{/riscv_cpu_tb/u_dut/u_ii_stage/need_stall_dual}}
add_wave {{/riscv_cpu_tb/u_dut/u_ii_stage/raw_hazard}}
add_wave {{/riscv_cpu_tb/u_dut/u_ii_stage/waw_hazard}}
add_wave {{/riscv_cpu_tb/u_dut/u_ii_stage/can_dual_issue}}

# 运行仿真
run all
```

---

## 📊 Vivado 综合验证

### 步骤 1: 运行综合

1. 点击 **Flow → Synthesis → Run Synthesis**

   ![Run Synthesis](docs/vivado_run_synth.png)

2. 或在 TCL Console：
   ```tcl
   reset_run synth_1
   launch_runs synth_1 -jobs 8
   wait_on_run synth_1
   ```

**预期时间:** 2-5 分钟

**预期结果:**
- ✓ Synthesis completed successfully
- ✓ 无 CRITICAL 警告
- 可能有部分 WARNING (正常)

### 步骤 2: 查看综合报告

1. 综合完成后自动弹出 **Synthesis Results**

2. 或手动打开：**Design → Show Schematic**

   ![Schematic Diagram](docs/vivado_schematic.png)

3. 查看资源使用：**Window → Synthesis Results → Resource Report**

**关键指标:**
```
LUT Utilization:    xxxx / xxxxx  (xx%)
BRAM Utilization:   xxxx / xxxxx  (xx%)
FF Utilization:     xxxx / xxxxx  (xx%)
```

### 步骤 3: 运行实现

1. 点击 **Flow → Implementation → Run Implementation**

   ![Run Implementation](docs/vivado_run_impl.png)

2. 或 TCL：
   ```tcl
   reset_run impl_1
   launch_runs impl_1 -jobs 8
   wait_on_run impl_1
   ```

**预期时间:** 3-8 分钟

### 步骤 4: 检查时序报告

1. 实现完成后，打开 **Timing Report**：

   **Window → Timing Analyzer**

2. 或 TCL：
   ```tcl
   report_timing -file /tmp/timing_report.txt
   report_timing_summary -file /tmp/timing_summary.txt
   ```

**关键指标:**

```
Clock: clk
Period:             10.000 ns (100 MHz)
Slack (Setup/Hold): xxxx.xxx ns ✓ (应 > 0)
Critical Path:      xxxx ns
```

**✅ 通过条件:**
- Setup Time slack > 0
- Hold Time slack > 0
- 综合频率 ≥ 100 MHz

### 步骤 5: 生成比特流（可选）

用于 FPGA 硬件烧写：

```tcl
open_run impl_1
write_bitstream -force /tmp/vega_cpu.bit
write_debug_probes -force /tmp/vega_cpu.ltx
```

---

## 🧪 高级调试技巧

### 6.1 添加 ILA (集成逻辑分析仪)

用于实时波形采样：

```tcl
# 在 TCL Console 中运行
create_ip -name ila_v6 -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_NUM_OF_PROBES {8}] [get_ips ila_0]

# 连接到关键信号
set_property CONFIG.C_PROBE0_PORT_WIDTH {64} [get_ips ila_0]
connect_ip_signals ila_0 {clk riscv_cpu/clk}
```

### 6.2 添加 VIO (虚拟 I/O)

动态控制信号：

```tcl
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
set_property -dict [list CONFIG.C_NUM_PROBE_IN {1} CONFIG.C_NUM_PROBE_OUT {1}] [get_ips vio_0]
```

### 6.3 生成详细的功耗报告

```tcl
report_power -file /tmp/power_report.txt
```

---

## 📋 常见问题与解决

### Q1: "Cannot find module riscv_cpu"

**原因:** 源文件未添加或路径错误

**解决:**
1. 检查 **sources_1** 文件集
2. 确保所有 `.v` 文件都已添加
3. 特别确认 `ii_stage.v` 已添加
4. Reload 项目：**File → Reload Project**

### Q2: "Top module not set correctly"

**原因:** 顶层模块设置错误

**解决:**
1. 右击 **riscv_cpu.v** → **Set as Top**
2. 验证 Properties 中 `top = riscv_cpu`
3. 重新启动仿真

### Q3: 仿真报错 "Signal not found in module"

**原因:** 模块实例名或信号名不匹配

**解决:**
1. 确认模块实例名 (如 `u_ii_stage` vs `u_issue_stage`)
2. 检查信号大小写
3. 重新编译：**Flow → Simulation → Elaborate Design**

### Q4: 综合时出现 "multi-driven net"

**原因:** 多个模块驱动同一信号

**解决:**
1. 检查 `riscv_cpu.v` 中的信号连接
2. 确保 Way1/Way2 输出信号无重复驱动
3. 查看错误位置并修正

### Q5: 时序不满足 (Slack < 0)

**原因:** 流水线延迟过高

**解决方案:**

**选项 A:** 降低工作频率

```tcl
# 修改约束文件
set_property PERIOD 12.5 [get_clocks clk]  # 80 MHz 替代 100 MHz
```

**选项 B:** 添加额外的流水寄存器

在 ex_stage 和 mem_stage 之间添加：
```verilog
always @(posedge clk) begin
    exmem2_alu_result <= exmem_alu_result;
    exmem2_mem_we <= exmem_mem_we;
    // ...
end
```

**选项 C:** 优化关键路径

检查 `fwd_pick` 函数和 ALU 复杂度。

---

## 🎯 完整验证工作流

```
1. 打开项目
   Vivado Vega.xpr
   ↓
2. 添加新文件
   Add ii_stage.v 和更新的文件
   ↓
3. 设置顶层为 riscv_cpu
   ↓
4. 创建 Testbench
   添加 riscv_cpu_tb_dual.v
   ↓
5. 运行行为仿真
   Flow → Run Behavioral Simulation
   ├─ 预期: ✓ 205 周期通过
   └─ 查看: 波形、信号、日志
   ↓
6. 运行综合
   Flow → Run Synthesis
   ├─ 检查: 资源使用
   └─ 无 CRITICAL 错误
   ↓
7. 运行实现
   Flow → Run Implementation
   ├─ 检查: 路由成功
   └─ 验证: 时序 slack > 0
   ↓
8. 生成报告
   Timing, Power, Area
   ✓ 设计完成
```

---

## 📊 验证检查清单

```
行为仿真:
  [ ] Testbench 添加
  [ ] 仿真配置正确
  [ ] 运行成功完成
  [ ] 波形显示预期信号
  [ ] 没有运行时错误

综合验证:
  [ ] 所有文件编译通过
  [ ] 无 CRITICAL 警告
  [ ] 模块层次正确
  [ ] 顶层设置为 riscv_cpu

实现验证:
  [ ] 综合成功
  [ ] 实现成功
  [ ] 路由成功
  [ ] Setup slack > 0 ✓
  [ ] Hold slack > 0 ✓
  [ ] 频率 ≥ 80 MHz

综合报告:
  [ ] 生成 timing 报告
  [ ] 生成 area 报告
  [ ] 生成 power 报告
```

---

## 🔗 相关命令速查

### TCL 命令

```tcl
# 项目管理
open_project Vega.xpr
save_project_as

# 源文件
add_files -fileset sources_1 /path/to/file.v
remove_files [get_files file.v]
set_property top riscv_cpu

# 仿真
create_fileset -simset sim_behavioral
add_files -fileset sim_behavioral /path/to/tb.v
launch_simulation
run_all
wave add /path/to/signal

# 综合
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 实现
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# 报告
report_timing -file timing.txt
report_power -file power.txt
report_utilization -file area.txt
```

---

## 📚 更多资源

- [Vivado Design Suite 用户指南](https://docs.xilinx.com/r/2025.2-English/ug973-vivado-release-notes)
- RTL 仿真基础：见 `docs/VERIFICATION_GUIDE.md`
- 性能分析：见 `VERIFICATION_STATUS.md`

