# ⚡ Vega CPU 6 级双发射验证 - 快速参考

## 🚀 快速开始 (3分钟)

### 最小验证
```bash
cd /home/liyu/cpuP/Vega_cpu
bash test/run_rtl_sim.sh
```

### 完整验证套件
```bash
bash test/run_verification_suite.sh
```

---

## 📋 验证检查清单

### ✓ 已完成
- [x] **语法检查** — iverilog -g2001 -Wall
- [x] **编译** — 0 错误，仅预期警告
- [x] **基础仿真** — 205 个周期通过

### 📝 待验证
- [ ] **单元测试** — ALU、译码器、BTB、BHT（各 5-10 分钟）
- [ ] **功能测试** — 加载实际程序（CoreMark、gcc 生成的二进制）
- [ ] **Vivado 综合** — 时序、资源、功耗（30 分钟）
- [ ] **FPGA 实现** — 实际硬件验证（可选）

---

## 🎯 验证目标

| 验证层级 | 工具 | 预计时间 | 关键指标 |
|---------|------|---------|---------|
| 语法 | iverilog | 1 分钟 | ✓ 0 错误 |
| RTL 仿真 | Verilog | 5 分钟 | ✓ 流水线运行 |
| 功能 | 汇编/机器码 | 20 分钟 | 正确执行指令 |
| 综合 | Vivado | 30 分钟 | ✓ 时序满足 |
| 硬件 | FPGA | 1 小时 | ✓ 板上运行 |

---

## 🔍 常见问题

### Q: "仿射周期数: 0"是什么意思？
**A:** 说明流水线还在复位和填充阶段，还未遇到有效指令。这是正常的—需要运行更久的仿真。

### Q: 如何验证指令是否正确执行？
**A:** 在 testbench 中添加 probe：
```verilog
// 在关键点添加 display
always @(posedge clk) begin
    if (wb_valid) begin
        $display("[WB] x%d <- 0x%x", wb_rd, wb_result);
    end
end
```

### Q: 时序不满足怎么办？
**A:** 检查关键路径（通常在前递单元或 ALU）。考虑：
1. 降低频率（如 80MHz）
2. 在前递路径添加寄存器
3. 优化 ALU 逻辑

### Q: 如何在 Vivado 中验证？
**A:** 
```bash
vivado -mode batch -source $WORKSPACE/Project/Vega/run_synthesis.tcl
```

---

## 📊 性能指标

### 目标 IPC（指令/周期）
- **单发射基线:** 1.0 IPC
- **理想双发射:** 2.0 IPC
- **实际双发射:** 1.2-1.7 IPC（受冒险限制）

### 频率目标
- **综合频率 (fmax):** &geq;100 MHz
- **实施频率:** &geq;80 MHz（留余量）

---

## 🔧 调试技巧

### 追踪冒险信号
编辑 `ii_stage.v`，添加：
```verilog
always @(posedge clk) begin
    if (need_stall_dual) begin
        $display("[II] 第 %0d 周期: 双发射阻塞", cycle_count);
        $display("     RAW=%d WAW=%d STRUCT=%d CTRL=%d", raw_hazard, waw_hazard, struct_hazard, ctrl_hazard);
    end
end
```

### 查看前递信号
编辑 `ex_stage.v`：
```verilog
always @(posedge clk) begin
    $display("[EX] 前递: rs1_w1=%d->0x%x, rs2_w1=%d->0x%x", 
             rs1_src_w1, rs1_w1_fwd, rs2_src_w1, rs2_w1_fwd);
end
```

### 检查寄存器文件
编辑 `register_file.v`：
```verilog
always @(posedge clk) begin
    $display("[RF] WB: x%d=0x%x, x%d=0x%x", waddr1, wdata1, waddr2, wdata2);
end
```

---

## 📚 详细指南

查看完整文档：[docs/VERIFICATION_GUIDE.md](../docs/VERIFICATION_GUIDE.md)

---

## ✅ 验证成功标志

**✓ RTL 仿真通过** 当：
- 编译无错误
- 仿真运行 > 100 周期
- 无地址对齐/冲突错误
- 流水线正常推进

**✓ 功能验证通过** 当：
- 执行简单汇编程序正确
- 指令结果与参考值匹配
- 分支跳转工作
- 访存操作正确

**✓ 硬件验证通过** 当：
- Vivado 综合成功
- 时序约束满足
- 板上正确运行
- IPC 接近预期

---

## 🎓 下一步

1. **单元测试** → 隔离验证各模块
2. **CoreMark** → 实际基准测试
3. **对标** → 与单发射设计对比性能
4. **优化** → 时钟、面积、功耗优化

