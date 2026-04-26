# Vega CPU 技术架构设计文档（7级流水线双发射版本）

本文档基于当前 RTL 实现整理，覆盖 CPU 总体架构、模块实现细节、关键接口定义与实现说明。源码以 `src/cpu/` 目录为准。

---

## 1. 设计目标与范围

### 1.1 目标

- **ISA**：RV64IMC（整数基线 + M 扩展 + C 扩展）
- **CSR**：Zicsr + Zicntr（机器级 CSR + 计时器）
- **微架构**：**7级流水线 + 有序双发射（In-Order Dual-Issue）**，保留 BTB+BHT 动态分支预测与 L1 Cache 子模块
- **接口**：分离的指令口（64-bit 双指令带宽）与数据口

### 1.2 版本演进

| 版本 | 流水线深度 | 发射宽度 | 备注 |
|------|-----------|---------|------|
| 旧版 | 5 级 | 1 路 | IF/ID/EX/MEM/WB |
| 6 级版 | 6 级 | 2 路 | 加入 II 阶段（发射），IF/ID/II/EX/MEM/WB |
| **当前** | **7 级** | **2 路** | **EX 内部分为 EX1/EX2**，IF/ID/II/EX1/EX2/MEM/WB |

---

## 2. 总体架构

### 2.1 七级流水线主路径

```
IF ──IFID──> ID ──IDII──> II ──IIEX──> EX1 ──reg──> EX2 ──EX/MEM──> MEM ──MEM/WB──> WB
```

| 级 | 名称 | 关键功能 | 输出寄存器 |
|----|------|---------|-----------|
| 1 | IF | PC 推进、双路取指、BTB+BHT 预测 | IFID |
| 2 | ID | 双路译码（Decode Way1/Way2）、CSR 检测 | IDII |
| 3 | II | 读 4 口寄存器堆、双发射依赖检测 | IIEX |
| 4 | **EX1** | **前递选择 + 操作数选择 → 流水线寄存器** | **EX1 寄存器** |
| 5 | **EX2** | **ALU + 乘除法 + 分支判断 + CSR 读写** | EX/MEM |
| 6 | MEM | Way1 数据访存、Way2 透传 | MEM/WB |
| 7 | WB | 双路写回（2 写口寄存器堆） | — |

> **为什么 EX 分为 EX1/EX2？** 原单级 EX 中，前递网络（4 路优先 MUX × 64-bit）→ ALU（64-bit 运算）→ muldiv（64-bit 组合除法）路径过长，Artix-7 上时序违例达 -192ns。拆为两段后：
> - EX1：前递 MUX + 操作数选择（约 5-8ns）
> - EX2：ALU + muldiv + CSR + 分支（约 10-15ns，除法另由多周期单元处理）

### 2.2 双发射策略（有序、静态）

每周期从 IDII 寄存器取出两条指令（Way1 主路 / Way2 副路）：

- **可双发射**：两路均进入 IIEX，并行执行
- **阻断双发射**（只发 Way1，Way2 下周期重试）：

| 阻断条件 | 说明 |
|---------|------|
| RAW 冒险 | Way2 源寄存器 == Way1 目的寄存器 |
| WAW 冒险 | 两路写同一目的寄存器 |
| 结构冒险 | 两路均为访存指令（单端口数据存储器） |
| 控制冒险 | Way1 为分支/跳转指令 |
| 系统冒险 | 任一指令为 CSR/ECALL/EBREAK/SRET |

### 2.3 时序与复位

- 同步上升沿时钟；低有效异步复位 `rst_n`
- 初始 PC：`64'h1000`
- 目标频率：100 MHz（Artix-7 xc7a200t-3）

---

## 3. 各级详细设计

### 3.1 IF 阶段（`if_stage.v`）

实现文件：`src/cpu/core/if_stage/if_stage.v`、`btb.v`、`bht.v`

**双路取指：**
- IF 以 `instr_data_w1/w2` 组成 64-bit 取指窗口，按 PC 对齐后提取顺序两条指令
- 支持 16-bit（C）与 32-bit（I/M）混合：Way1、Way2 均可为 16/32-bit
- 正常非分支时 PC 按实际长度推进：`pc += len(inst1) + len(inst2)`
- 若 BTB 命中（预测 Way1 跳转），Way2 输出无效，PC 跳转到 BTB 目标

**分支预测：**
```
next_pc = mispredict    ? branch_target :
          predict_taken ? predict_pc    : pc_reg + seq_inc
```
- BTB（4路组相联，16组）：命中时提供目标地址
- BHT（256项2-bit饱和计数器，GHR 异或索引）：提供方向预测
- IF 阶段按 16/32-bit 混合长度计算 `seq_inc`
- 误预测时由 EX2 反馈，冲刷 IFID/IDII/IIEX/EX1

### 3.2 ID 阶段（`id_stage.v`）

实现文件：`src/cpu/core/id_stage/id_stage.v`（含两个 decoder 实例）

**双路译码：**
- 例化 `u_decoder_w1` 和 `u_decoder_w2` 两个独立译码器
- 每路产生完整的控制信号集：alu_op、src_sel、mem\_\*、reg_write_en、wb_sel
- 输出：`uses_rs1`、`uses_rs2`（II 阶段 RAW 检测）、`is_mem_op`、`is_system`
- **CSR 检测**：`is_csr`、`csr_addr`、`funct3`（沿 IDII/IIEX 传递到 EX2 的 CSR unit）

**C 扩展译码：**
- 对 C 指令生成可执行控制字段，与 32-bit 指令共用后续流水线

**IDII 流水线寄存器：**
- 时序逻辑，stall 时保持供双发射重试，flush 时注入气泡

### 3.3 II 阶段（`ii_stage.v`）

实现文件：`src/cpu/core/ii_stage/ii_stage.v`

**读寄存器堆（4读口）：**
- Way1：rf_raddr1(rs1)，rf_raddr2(rs2)
- Way2：rf_raddr3(rs1)，rf_raddr4(rs2)

**双发射仲裁：**
```
can_dual_issue = !(raw_hazard || waw_hazard || struct_hazard ||
                   ctrl_hazard || sys_hazard)
```

**CSR 阻断**：`sys_hazard` 已覆盖 `is_csr`，CSR 指令不与任何指令双发（单个 CSR unit 仅服务 Way1）。

**IIEX 流水线寄存器：**
- 传递 CSR 信号：`is_csr`、`csr_addr`、`funct3`

### 3.4 EX1 阶段（前递 + 操作数选择）

位于 `ex_stage.v` 内部，无独立模块。

**前递单元（Forwarding Unit）：**
- 4路前递源：EX/MEM Way1/Way2、MEM/WB Way1/Way2
- 4路前递目标：rs1_w1、rs2_w1、rs1_w2、rs2_w2
- 优先级：EX/MEM Way1 > EX/MEM Way2 > MEM/WB Way1 > MEM/WB Way2

**操作数选择：**
```verilog
opA_w1 = alu_src1_sel_w1_i ? pc_w1_i  : rs1_w1_fwd;
opB_w1 = alu_src2_sel_w1_i ? imm_w1_i : rs2_w1_fwd;
```

**EX1 流水线寄存器：**
- 锁存所有操作数和控制信号供给 EX2
- `muldiv_stall` 时冻结（等待乘除法完成）

### 3.5 EX2 阶段（ALU + CSR + Muldiv + 分支）

位于 `ex_stage.v` 内部。

**双 ALU：**
- `u_alu1` / `u_alu2`：64-bit 组合 ALU（ADD/SUB/SLL/SRL/SRA/SLT/SLTU/XOR/OR/AND）

**CSR 单元：**（新增，已集成）
```verilog
csr_unit u_csr_unit (
    .csr_addr(ex1_csr_addr_w1),
    .csr_wdata(ex1_opA_w1),      // rs1 data via forwarding
    .csr_we(ex1_is_csr_w1 && funct3[2]),
    .csr_re(ex1_is_csr_w1),
    .funct3(ex1_funct3_w1),
    .csr_rdata(csr_rdata_w1),    // → alu_result_w1_o via mux
    .irq_timer(irq_timer_ex)     // → CPU irq_timer port
);
```

支持 CSR：
| 地址 | CSR | 读写 |
|------|-----|------|
| 0x300 | mstatus | 读写 |
| 0x304 | mie | 读写 |
| 0x305 | mtvec | 读写 |
| 0x341 | mepc | 读写 |
| 0x342 | mcause | 读写 |
| 0x343 | mtval | 读写 |
| 0x344 | mip | 读写 |
| **0xB00** | **mcycle** | **每周期+1** |
| 0xB01 | mtime | 每周期+1 |
| 0xB02 | mtimecmp | 读写 |

funct3 支持：CSRRW（直接写）、CSRRS（置位）、CSRRC（清零）、对应立即数变体。

**乘除法多周期单元：**（替换原组合 `muldiv_pick`）
| 操作 | 延迟 | 实现 |
|------|------|------|
| MUL / MULH / MULHSU / MULHU | 3 周期 | DSP48 流水线 |
| DIV / DIVU / REM / REMU | 68 周期 | radix-2 迭代恢复除法 |

详见 `MULDIV_UNIT.md`。

**分支判断（仅 Way1）：**
- 条件分支：BEQ/BNE/BLT/BGE/BLTU/BGEU
- 无条件跳转：JAL/JALR
- mispredict 时冲刷 IF/ID/II/EX1

**EX/MEM 流水线寄存器**：同时保存 Way1 和 Way2 的 ALU/CSR 结果、目的寄存器、控制信号。

### 3.6 MEM 阶段（`mem_stage.v`）

实现文件：`src/cpu/core/mem_stage/mem_stage.v`

- Way1 执行实际内存操作（地址 = alu_result_w1）
- Way2 直接透传到 MEM/WB 寄存器
- 访存格式：LB/LH/LW/LD（符号扩展），LBU/LHU/LWU（零扩展）
- D-Cache 子模块声明为内部 wire，端口方向已修正（`dcache_data_out`/`hit`/`refill_done` 为内部信号，`dcache_writeback_*`/`cache_stall` 为 output）

### 3.7 WB 阶段（顶层组合实现）

```verilog
wb_waddr1 = memwb_rd_w1_raw;
wb_wdata1 = (wb_sel_w1 == 2'b01) ? memwb_mem_w1 : memwb_alu_w1;
```

CSR 指令的读数据通过 `alu_result_w1_o` 路径返回（`wb_sel = 2'b00`）。

---

## 4. 寄存器堆（`register_file.v`）

| 特性 | 值 |
|-----|-----|
| 读端口 | 4 |
| 写端口 | 2 |
| 写优先级 | Way2 > Way1（程序序靠后） |
| 写后读旁路 | 4 端口均支持 |
| x0 | 硬连线 0，写 x0 被忽略 |

---

## 5. 冒险处理（`hazard_unit.v`）

### 5.1 控制冒险
`mispredict_ex = 1` → flush_if / flush_id / flush_ex（最高优先级）

### 5.2 Load-Use 冒险
EX 分 EX1/EX2 两段后，load 数据从 EX1 到 WB 需要 4 周期（EX1→EX2→MEM→WB），Load-Use 停顿由 1 周期延长为 **2 周期**：

```
Cycle N:    load 在 IIEX, dep 在 ID   →   stall (load_use_hazard_new)
Cycle N+1:  load 在 EX1, dep 在 ID   →   stall (load_in_ex1=1)
Cycle N+2:  load 在 EX2, dep 在 II   →   恢复
Cycle N+3:  load 在 MEM, dep 在 EX1
Cycle N+4:  load 在 WB,  dep 在 EX2  →   转发可用
```

`load_in_ex1` 寄存器将 `load_use_hazard_new` 延一拍，实现两周期停顿。

### 5.3 乘除法停顿
`muldiv_stall = muldiv_active_w1 || muldiv_active_w2`：
- 停顿 IF/ID（EX1 在内部自动冻结）
- 等待乘除法单元完成后恢复

### 5.4 双发射停顿
`stall_dual` 来自 II 阶段，停顿 IF/ID，次周期重试 Way2。

### 5.5 DCache 停顿
`dcache_stall` 来自 MEM 阶段，停顿 IF/ID 等待访存完成。

### 停顿优先级

```
mispredict > dcache_miss > muldiv > load_use > dual_issue
```

---

## 6. 分支预测

### BTB（Branch Target Buffer）
- 4路组相联，16组（共 64 项）
- 索引 = pc[7:2]，标记 = pc[31:12]
- 命中时提供预测目标地址

### BHT（Branch History Table）
- 256项 2-bit 饱和计数器（初值 01 = 弱不跳）
- 索引 = pc[9:2] XOR ghr（8-bit 全局历史寄存器）

### 双发射与分支预测交互
- BTB 命中时 Way2 自动无效
- 控制冒险阻断双发射

---

## 7. SoC 顶层（`vega_soc_top.v`）

### 内存映射

| 区域 | 基地址 | 大小 | 说明 |
|------|--------|------|------|
| Boot ROM | `0x1000` | 16KB | CPU 复位入口，由 COE 初始化 |
| Data RAM | `0x80000000` | 64KB | 读写，无初始化 |
| UART | `0x60100000` | 4KB | AXI UART Lite，9600 baud |

### 资源占用（xc7a200tfbg676-3）

| 资源 | 用量 | 占比 |
|------|------|------|
| LUT | 23,119 | 17% |
| FF | 23,678 | 9% |
| BRAM36 | 20 | 5% |
| DSP48 | 96 | 13% |

### 时序（100MHz）

| 指标 | 值 |
|------|-----|
| WNS（setup） | +0.389 ns |
| WHS（hold） | +0.070 ns |
| WPWS（pulse width） | +4.230 ns |

---

## 8. Cache 子模块（保留，独立实现）

| Cache | 结构 | 状态 |
|-------|------|------|
| ICache | 2路组相联，64组，256-bit 行宽 | 代码完备，综合通过 |
| DCache | 2路组相联，64组，256-bit 行宽，WBACK | 代码完备，综合通过 |

两个 Cache 模块接口与主流水线兼容，端口方向已修正（dcache 内部信号不再暴露为顶层 input）。当前 SoC 直通内存模式（无 cache 仲裁）。

---

## 9. SDK 与软件支持

详见 `SDK/` 目录：

| 组件 | 文件 | 说明 |
|------|------|------|
| 启动代码 | `crt0.S` | 清零 regs → GP/SP → 搬运.data → 清零.bss → main |
| 链接脚本 | `linker.ld` | 代码 0x1000 / 数据 0x80000000 |
| UART 驱动 | `drivers/uart.c` | AXI UART Lite 轮询驱动 |
| CSR 宏 | `include/csr.h` | 所有机器级 CSR 地址 + inline asm |
| Coremark 配置 | `examples/core_portme_vega.h` | Vega → Coremark 移植配置 |
| 示例 | `examples/hello.c` | 打印 Vega logo + mcycle 测试 |

---

## 10. 验证说明

| 测试资源 | 说明 |
|---------|------|
| `test/riscv_cpu_tb_dual.v` | 主用顶层验证 testbench |
| `Project/Vega/Vega.sim/` | Vivado xsim 工程文件 |
| 综合后布线 | `vega_soc_top_routed.dcp` 已生成，时序收敛 |

**验证重点：**
1. 双发射阻断逻辑（RAW/WAW/结构/控制/系统冒险）
2. `issued_w1` 重试机制
3. 4路前递覆盖
4. Load-Use 停顿后的双路恢复（2 周期）
5. 分支误预测后 4 级冲刷（IF/ID/II/EX1）
6. CSR 读写（csrr/csrw）→ mcycle 自增
7. Muldiv 多周期停顿 → EX1 冻结 → 恢复

---

## 11. 性能分析

| 指标 | 说明 |
|-----|------|
| 理想 IPC | 2.0（双发射满发射） |
| 实际 IPC | ~0.6-1.2（受双发射阻断率、分支预测命中率限制） |
| 分支惩罚 | 4 个气泡（冲刷 IFID/IDII/IIEX/EX1） |
| Load-Use 惩罚 | 2 个停顿周期 |
| 双发射停顿 | 1 个停顿周期（每次阻断） |
| 乘除法惩罚 | MUL=3周期，DIV=68周期，期间流水线冻结 |

---

文档状态：已与当前 RTL 对齐（含实现现状说明）
最后更新：2026-04-26
