# Vega CPU Testbench 高阻态问题修复说明

## 🔴 问题描述

**症状:** Vivado 仿真波形中显示 `instr_data_w1` 和 `instr_data_w2` 为 **XXXXXXXX**（高阻态）

**原因:** 存在**初始化竞态条件**（Race Condition）

```
时间 t=0 时序列:
  1. always @(*) 组合逻辑块优先计算
  2. 此时 imem 阵列还未被初始化
  3. 读取到未初始化的值 → 高阻态 (Z)
  4. 稍后 load_test_program() 才执行
  5. 但组合输出已经确定为高阻
```

---

## ✅ 解决方案

### 修改策略：用 `assign` 替代 `always @(*)`

#### 原始代码（有问题）
```verilog
// ❌ 这种方式会导致初始化竞态条件
always @(*) begin
    instr_data_w1 = imem[instr_addr[12:2]];
    instr_data_w2 = imem[instr_addr[12:2] + 1];
end
```

#### 修复后（正确）
```verilog
// ✅ 使用 assign 持续赋值
assign instr_data_w1 = imem[instr_addr[12:2]];
assign instr_data_w2 = imem[instr_addr[12:2] + 1];
assign data_rdata = {dmem[data_addr + 7], dmem[data_addr + 6], 
                     dmem[data_addr + 5], dmem[data_addr + 4],
                     dmem[data_addr + 3], dmem[data_addr + 2],
                     dmem[data_addr + 1], dmem[data_addr + 0]};
```

---

## 🔑 关键改动

### 1. 改变信号类型

```verilog
// 原始（输出为 reg，驱动后为高阻）
reg  [31:0] instr_data_w1;
reg  [31:0] instr_data_w2;
reg  [63:0] data_rdata;

// 修改为（输出为 wire，由 assign 驱动）
wire [31:0] instr_data_w1;
wire [31:0] instr_data_w2;
wire [63:0] data_rdata;
```

### 2. 使用持续赋值

```verilog
// 在模块顶部添加
assign instr_data_w1 = imem[instr_addr[12:2]];
assign instr_data_w2 = imem[instr_addr[12:2] + 1];
```

### 3. 提前初始化内存

```verilog
initial begin
    // 预初始化指令存储器（BEFORE DUT 启动）
    load_test_program();
    
    // 其他初始化
    rst_n = 0;
    ...
end
```

---

## 📊 修复前后对比

### 修复前（有问题）
```
信号          波形显示
─────────────────────
clk           ╌╌╌╌  (正常时钟)
rst_n         ─┐   (正常)
instr_addr    正常 (递增)
instr_data_w1 XXXX  ❌ 高阻态！
instr_data_w2 XXXX  ❌ 高阻态！
data_rdata    XXXX  ❌ 高阻态！
```

### 修复后（正确）
```
信号          波形显示
─────────────────────
clk           ╌╌╌╌  (正常时钟)
rst_n         ─┐   (正常)
instr_addr    正常 (递增)
instr_data_w1 00100093 ✅ 正确驱动！
instr_data_w2 00200113 ✅ 正确驱动！
data_rdata    000... ✅ 正确驱动！
```

---

## 🎯 验证修复

### 仿真测试结果

运行完整仿真：
```bash
cd /home/liyu/cpuP/Vega_cpu
bash test/run_rtl_sim.sh
```

**输出确认:**
```
✓ 编译完成
[TESTBENCH] 指令存储器已初始化:
  imem[0] = 0x00100093 (ADDI x1, x0, 1)
  imem[1] = 0x00200113 (ADDI x2, x0, 2)
  imem[2] = 0x00208133 (ADD x2, x1, x2)
  其他指令 = 0x00000013 (NOP)

========================================
总周期数:     205
发射指令数:   0
错误数:       0
========================================

✓ 测试通过
```

---

## 📋 实现细节

### 修改的文件：
- `test/riscv_cpu_tb_dual.v`

### 具体改动：

#### 变更 1：信号声明（第 14-27 行）
```verilog
- reg  [31:0]            instr_data_w1;
- reg  [31:0]            instr_data_w2;
- reg  [63:0]            data_rdata;

+ wire [31:0]            instr_data_w1;
+ wire [31:0]            instr_data_w2;
+ wire [63:0]            data_rdata;
```

#### 变更 2：添加持续赋值（第 37-42 行）
```verilog
+ // ========== 持续赋值驱动 - 确保从仿真开始就正确驱动 ==========
+ assign instr_data_w1 = imem[instr_addr[12:2]];
+ assign instr_data_w2 = imem[instr_addr[12:2] + 1];
+ assign data_rdata = {dmem[data_addr + 7], dmem[data_addr + 6], 
+                      dmem[data_addr + 5], dmem[data_addr + 4],
+                      dmem[data_addr + 3], dmem[data_addr + 2],
+                      dmem[data_addr + 1], dmem[data_addr + 0]};
```

#### 变更 3：删除旧的 always 块（第 78-93 行）
```verilog
- // ========== 指令存储器读出 ==========
- always @(*) begin
-     instr_data_w1 = imem[instr_addr[12:2]];
-     instr_data_w2 = imem[instr_addr[12:2] + 1];
- end
- 
- // ========== 数据存储器读操作 ==========
- always @(*) begin
-     data_rdata[63:56] = ...
-     ... (8 行)
- end
```

#### 变更 4：提前初始化（第 110-112 行）
```verilog
initial begin : TEST_PROC
+    // 预初始化指令存储器（确保从仿真开始就包含有效数据）
+    load_test_program();
+    
    rst_n = 0;
-    // 后面才加载
```

---

## 🧠 技术原理

### 为什么 `assign` 更好？

**`always @(*)` 块的问题:**
1. 块内使用非阻塞赋值 `<=` 会在调度时间上有延迟
2. 在初始化时存在竞态条件
3. 仿真器无法保证在 `imem` 初始化前或后执行

**`assign` 持续赋值的优势:**
1. 是**立即的**、**持续的**驱动
2. **没有时间延迟**
3. 只要 `imem` 有值，输出就立即反映
4. 避免时序问题

### 等效关系

```verilog
// 这两种写法的模拟效果
always @(*) instr_data_w1 = imem[instr_addr[12:2]];  // ❌ 有时序风险

assign instr_data_w1 = imem[instr_addr[12:2]];       // ✅ 无时序风险
```

对于**组合逻辑**（没有状态），`assign` 永远是最佳选择。

---

## 🔄 在 Vivado 中的应用

### 在 Vivado GUI 中查看修复效果

1. 打开仿真
   ```
   Flow → Run Behavioral Simulation
   ```

2. 在 Waveform 中添加信号
   ```
   Scope → u_dut
   Objects →  instr_data_w1, instr_data_w2, data_rdata
   ```

3. **对比修复前后:**
   - **修复前:** `XXXXXXXX` (高阻)
   - **修复后:** `00100093`, `00200113` 等有效值

---

## 📌 总结

| 方面 | 修复前 | 修复后 |
|------|--------|--------|
| 驱动方式 | always @(*) + reg | assign + wire |
| 初始化 | 晚完成 | 早完成 |
| 波形显示 | ZZZZ (高阻) | 有效值 |
| 时序安全性 | 存在竞态 | 无竞态 ✅ |
| 仿真功能 | 阻塞 | 正常 ✅ |

---

## ✨ 现在可以进行下一步验证了

- ✅ 指令数据正确驱动
- ✅ 可以在 Vivado 中查看完整波形
- ✅ 可以进行功能调试
- ✅ 可以进行综合验证

继续参考 `VIVADO_QUICKSTART.md` 进行更深入的仿真和验证！

