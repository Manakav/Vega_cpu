# MUL/DIV Unit — 多周期乘除法器

## 概述

`muldiv_unit` 是一个流水线化的多周期乘除法单元，专为 RV64M 扩展指令集设计。它将 RISC-V 的 M 扩展指令（MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU）的硬件实现从组合逻辑改为多周期状态机，解决了 Artix-7 FPGA 上 64 位组合除法导致的关键路径时序违例问题（-192ns）。

## 接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | 输入 | 1 | 时钟 |
| `rst_n` | 输入 | 1 | 异步复位，低有效 |
| `start` | 输入 | 1 | 启动信号（高有效一个周期），将 operands 和 funct3 锁存到内部寄存器 |
| `funct3` | 输入 | 3 | RISC-V M 扩展 funct3 编码（见下方） |
| `operand_a` | 输入 | 64 | 操作数 a（被乘数/被除数） |
| `operand_b` | 输入 | 64 | 操作数 b（乘数/除数） |
| `result` | 输出 | 64 | 计算结果 |
| `done` | 输出 | 1 | 计算完成标志（高有效一个周期） |

## funct3 编码

| funct3 | 指令 | 操作 |
|--------|------|------|
| 000 | MUL | a × b 的低 64 位 |
| 001 | MULH | signed(a) × signed(b) 的高 64 位 |
| 010 | MULHSU | signed(a) × unsigned(b) 的高 64 位 |
| 011 | MULHU | unsigned(a) × unsigned(b) 的高 64 位 |
| 100 | DIV | signed(a) ÷ signed(b)，结果取整 |
| 101 | DIVU | unsigned(a) ÷ unsigned(b) |
| 110 | REM | signed(a) % signed(b) |
| 111 | REMU | unsigned(a) % unsigned(b) |

## 状态机

```
                  ┌───────────────────┐
                  │                   │
                  ▼                   │
    ┌─────┐  start=1 & mul   ┌─────┐ │
    │     │──────────────────►│MUL_R1│ │
    │IDLE │                   └──┬──┘ │
    │     │                      │    │
    └──┬──┘                      ▼    │
       │                     ┌──────┐ │
       │ start=1 & div       │MUL_R2│─┤
       └────────────────────►└──────┘ │
                              │done=1 │
                              └───────┘
                              │
                              ▼
                       ┌──────────┐
                       │ DIV_INIT │  (1 cycle)
                       └────┬─────┘
                            ▼
                       ┌──────────┐
                       │ DIV_ITER │  (64 cycles, d63→d0)
                       └────┬─────┘
                            ▼
                       ┌──────────┐
                       │DIV_SIGN  │  (1 cycle, done=1)
                       └────┬─────┘
                            │
                            ▼
                        ┌───────┐
                        │ IDLE  │
                        └───────┘
```

### 状态说明

#### IDLE（空闲）
等待 `start` 上升沿。当 `start=1` 时：
- 锁存 `operand_a/b` 到内部寄存器（同时保留 signed 和 unsigned 两份拷贝用于不同乘法）
- 锁存 `funct3`
- 根据 funct3[2] 选择路径：乘法（funct3 ≤ 011）进入 MUL_R1；除法（funct3 ≥ 100）进入 DIV_INIT

#### MUL_R1（乘法阶段 1：计算）
- 并行计算三个 128 位乘积：
  - `prod_ss = signed(a) × signed(b)`（用于 MULH）
  - `prod_su = signed(a) × unsigned(b)`（用于 MULHSU）
  - `prod_uu = unsigned(a) × unsigned(b)`（用于 MUL 和 MULHU）
- DSP48 乘法器在 Artix-7 上约 1 周期即可稳定

#### MUL_R2（乘法阶段 2：选择）
- 根据 `funct3` 选择最终结果，置 `done=1`
- MUL：取 `prod_uu[63:0]`（低 64 位，signed/unsigned 结果相同）
- MULH：取 `prod_ss[127:64]`
- MULHSU：取 `prod_su[127:64]`
- MULHU：取 `prod_uu[127:64]`

#### DIV_INIT（除法初始化）
- 将除数和被除数转换为绝对值（使用二进制补码取反+1）
- 重置商和余数寄存器
- 设置迭代计数器 dcount=63

#### DIV_ITER（除法迭代）
radix-2 恢复除法算法：

```
每周期：
  shifted = {remainder[62:0], abs_a[dcount]}  // 左移一位并载入被除数下一个比特
  if shifted >= divisor:
      remainder = shifted - divisor
      quotient[dcount] = 1
  else:
      remainder = shifted
```

- 从最高位 (dcount=63) 向最低位 (dcount=0) 迭代
- 共 64 个周期
- `div_shifted` 和 `div_cmp` 为组合逻辑，使用当前余数和被除数比特实时计算

#### DIV_SIGN（除法符号修正）
- 商：signed 且两操作数符号相反（a_sign ^ b_sign）时取负
- 余数：signed 且被除数为负时取负

## 时序特性

| 操作 | 周期数 | 说明 |
|------|--------|------|
| MUL | 3 周期 | IDLE→MUL_R1→MUL_R2→IDLE(done) |
| MULH/MULHSU/MULHU | 3 周期 | 同上 |
| DIV | 68 周期 | IDLE→DIV_INIT→64×DIV_ITER→DIV_SIGN(done)→IDLE |
| DIVU | 68 周期 | 同上 |
| REM | 68 周期 | 同上 |
| REMU | 68 周期 | 同上 |

## 与 EX Stage 的集成

`ex_stage.v` 实例化两个 `muldiv_unit`（Way1/Way2 各一个），通过以下信号协调：

- **启动条件**：`ex1_valid_w1 && ex1_is_muldiv_w1 && !muldiv_active_w1`——仅在指令进入 EX2 且该单元空闲时启动
- **活跃追踪**：`muldiv_active_w1` 寄存器从启动到 done 期间保持为 1
- **停顿信号**：`muldiv_stall = muldiv_active_w1 || muldiv_active_w2`，输出到 hazard_unit 冻结 IF/ID，同时冻结 EX1 寄存器
- **结果捕获**：EX/MEM 流水线寄存器在 `muldiv_done_w1` 有效时锁存 `muldiv_res_w1` 和所有关联字段（valid/pc/rd_addr 等）

### EX 内部流水线

```
IIEX → EX1 (forwarding mux + operand selection) → [EX1 reg] → EX2 (ALU + muldiv + CSR + branch) → EX/MEM → MEM
                                                      ↑
                                              muldiv_stall 冻结 EX1 寄存器
```

乘除法指令进入 EX2 后启动 muldiv_unit，同时 `muldiv_stall` 冻结 EX1 及之前的流水线阶段；muldiv 完成后解除停顿，结果写入 EX/MEM 寄存器。

## 除法溢出处理

符合 RISC-V 特权规范 Volume 1 §7：

| 场景 | 商 | 余数 |
|------|-----|------|
| 有符号 ÷ 0 | 全 1（-1） | 被除数本身 |
| 无符号 ÷ 0 | 全 1 | 被除数本身 |
| -2^63 ÷ -1 | -2^63（溢出） | 0 |

## 面积估算

| 资源 | 用量（每单元） |
|------|--------------|
| LUT | ~1800（含 64 位比较器和加减器） |
| FF | ~400（状态机 + 数据寄存器） |
| DSP48 | 3（三个并行 128 位乘法） |

## 与旧方案的差异

原方案（`decoder.v:192` 的 `muldiv_pick` 函数）使用组合逻辑的 `/` 和 `%` 运算符，在 Artix-7 FPGA 上：
- 单条路径延迟约 200ns
- 完全无法满足 10ns（100MHz）的时序目标

新方案将乘除法分离为独立的多周期流水线：
- ALU 路径保持单周期组合（ADD/SUB/SLT/SLL 等约 15-20ns）
- 乘法使用 DSP48 硬核，3 周期完成
- 除法使用 radix-2 恢复算法，68 周期完成
