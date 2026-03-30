# Vega CPU 技术架构设计文档（6级流水线双发射版本）

本文档基于当前 RTL 实现整理，覆盖 CPU 总体架构、模块实现细节、关键接口定义与实现说明。源码以 src/cpu 目录为准。

---

## 1. 设计目标与范围

### 1.1 目标
- ISA：RV64IMC（整数基线 + M 扩展 + C 扩展）
- 微架构：**6级流水线 + 有序双发射（In-Order Dual-Issue）**，保留 BTB+BHT 动态分支预测与 L1 Cache 子模块
- 接口：分离的指令口（64-bit 双指令带宽）与数据口，兼容片上总线

### 1.2 版本说明
本次修改从五级单发射（IF/ID/EX/MEM/WB）升级为：

| 版本 | 流水线深度 | 发射宽度 | 流水线寄存器 |
|------|-----------|---------|------------|
| 旧版 | 5 级 | 1 路 | IFID, IDEX, EX/MEM, MEM/WB |
| **新版** | **6 级** | **2 路（双发射）** | **IFID, IDII, IIEX, EX/MEM, MEM/WB** |

---

## 2. 总体架构

### 2.1 六级流水线主路径

```
IF ──IFID──> ID ──IDII──> II ──IIEX──> EX ──EX/MEM──> MEM ──MEM/WB──> WB
```

| 级 | 名称 | 关键功能 | 输出寄存器 |
|----|------|---------|-----------|
| 1 | IF  | PC 推进、双路取指（PC, PC+4）、BTB+BHT 预测 | IFID |
| 2 | ID  | 双路译码（Decode Way1 / Way2）、IDII 寄存器 | IDII |
| 3 | II  | 读 4 口寄存器堆、双发射依赖检测、IIEX 寄存器 | IIEX |
| 4 | EX  | 前递单元 + ALU1 + ALU2 + 分支判断 | EX/MEM |
| 5 | MEM | Way1 数据访存、Way2 透传 | MEM/WB |
| 6 | WB  | 双路写回（2写口寄存器堆） | — |

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
| 系统冒险 | 任一指令为 CSR/ECALL/EBREAK |

### 2.3 时序与复位
- 同步上升沿时钟；低有效异步复位 rst_n
- 初始 PC：64'h1000

---

## 3. 各级详细设计

### 3.1 IF 阶段（if_stage）

实现文件：`src/cpu/core/if_stage/if_stage.v`、`btb.v`、`bht.v`

**双路取指：**
- IF 以 `instr_data_w1/w2` 组成 64-bit 取指窗口，按 PC 对齐后提取顺序两条指令
- 支持 16-bit（C）与 32-bit（I/M）混合：Way1、Way2 均可为 16/32-bit
- 正常非分支时 PC 按实际长度推进：`pc += len(inst1) + len(inst2)`
- 若 BTB 命中（预测 Way1 跳转），Way2 输出无效，PC 跳转到 BTB 目标

**分支预测（保留原机制）：**
```
next_pc = mispredict   ? branch_target  :
          predict_taken ? predict_pc    : pc_reg + 8
```
- BTB（4路组相联，16组）：命中时提供目标地址
- BHT（256项2-bit饱和计数器，GHR 异或索引）：提供方向预测
- 误预测时 EX 阶段反馈，冲刷 IFID/IDII/IIEX

**外部接口变更：**
- `instr_data` 拆分为 `instr_data_w1[31:0]` 和 `instr_data_w2[31:0]`（分别对应 PC 和 PC+4）
- 输出 `pc_out_w1/w2`、`instr_out_w1/w2`、`valid_out_w1/w2`

---

### 3.2 ID 阶段（id_stage）

实现文件：`src/cpu/core/id_stage/id_stage.v`（含两个 decoder 实例）

**双路译码（新增功能）：**
- 例化 `u_decoder_w1` 和 `u_decoder_w2` 两个独立译码器
- 每路产生完整的控制信号集：alu_op、src_sel、mem_*、reg_write_en、wb_sel
- 额外输出：`uses_rs1`、`uses_rs2`（供 II 阶段 RAW 检测）、`is_mem_op`、`is_system`
- 新增输出：`is_muldiv`、`muldiv_funct3`（沿 IDII/IIEX 传递到 EX）

**C 扩展译码：**
- 对 C 指令生成可执行控制字段（load/store/alu/branch/jump/system）
- 与 32-bit 指令共用后续流水线控制/旁路/冒险逻辑

**IDII 流水线寄存器（新增为时序逻辑）：**
- 原版 id_stage 为纯组合逻辑；新版改为时序逻辑，在时钟上升沿锁存译码结果
- stall 时保持 IDII 内容不变（供双发射重试）
- flush 时注入气泡

---

### 3.3 II 阶段（ii_stage）— 新模块

实现文件：`src/cpu/core/ii_stage/ii_stage.v`

**读寄存器堆（4读口）：**
- Way1：rf_raddr1(rs1)，rf_raddr2(rs2)
- Way2：rf_raddr3(rs1)，rf_raddr4(rs2)

**双发射仲裁：**
```
can_dual_issue = !(raw_hazard || waw_hazard || struct_hazard ||
                   ctrl_hazard || sys_hazard)
```

当 `need_stall_dual = !issued_w1 && !can_dual_issue && w1_valid && w2_valid`：
- 本周期：发射 Way1 → IIEX slot1，slot2 无效
- `issued_w1` 标志置 1，`stall_dual` 输出 1 → 停顿 IF/ID
- 次周期：`issued_w1=1` 时将 IDII.Way2 作为 slot1 发射（IDII 因停顿保持不变）

**IIEX 流水线寄存器：**
- 同时传递 rs1_addr/rs2_addr 用于 EX 阶段前递地址比较

---

### 3.4 EX 阶段（ex_stage）

实现文件：`src/cpu/core/ex_stage/ex_stage.v`

**前递单元（Forwarding Unit）：**
- 4路前递源：EX/MEM Way1、EX/MEM Way2、MEM/WB Way1、MEM/WB Way2
- 4路前递目标：rs1_w1、rs2_w1、rs1_w2、rs2_w2
- 优先级：EX/MEM Way1 > EX/MEM Way2 > MEM/WB Way1 > MEM/WB Way2

**双 ALU：**
- `u_alu1`：服务 Way1（主路）
- `u_alu2`：服务 Way2（副路）
- 两个 ALU 实例均为组合逻辑

**M 扩展执行（新增）：**
- EX 阶段新增 `muldiv_pick` 组合执行路径
- 支持：MUL/MULH/MULHSU/MULHU、DIV/DIVU、REM/REMU
- `is_muldiv + muldiv_funct3` 控制每路是否走 M 扩展执行

**分支判断（仅 Way1 含分支，II 阶段已保证）：**
- 支持 BEQ/BNE/BLT/BGE/BLTU/BGEU 条件分支
- JAL（PC+imm）、JALR（rs1+imm）无条件跳转
- mispredict 时向 IF/ID/II 发出冲刷信号

**EX/MEM 流水线寄存器：**
- 同时保存 Way1 和 Way2 的 ALU 结果、目的寄存器、控制信号

---

### 3.5 MEM 阶段（mem_stage）

实现文件：`src/cpu/core/mem_stage/mem_stage.v`

**结构设计：**
- Way1 执行实际内存操作（地址 = alu_result_w1，数据口为单端口）
- Way2 直接透传到 MEM/WB 寄存器（II 阶段已保证 Way2 不含访存）

**访存格式（保留原实现）：**
- LB/LH/LW/LD：符号扩展，LBU/LHU/LWU：零扩展
- mem_be 按访存宽度生成 8-bit 字节使能

**MEM/WB 流水线寄存器：**
- Way1：alu_result、mem_result（load 数据）、rd_addr、reg_write_en、wb_sel
- Way2：alu_result、rd_addr、reg_write_en、wb_sel（无 mem_result）

---

### 3.6 WB 阶段（顶层组合实现）

- Way1 写回：`wb_result_w1 = (wb_sel_w1 == 01) ? mem_result_w1 : alu_result_w1`
- Way2 写回：`wb_result_w2 = alu_result_w2`（副路无访存结果）
- 寄存器堆 waddr1/wdata1/we1、waddr2/wdata2/we2 直接连接

---

## 4. 寄存器堆（register_file）

实现文件：`src/cpu/core/id_stage/register_file.v`

| 特性 | 旧版 | 新版 |
|-----|------|------|
| 读端口 | 2 | 4 |
| 写端口 | 1 | 2 |
| 写优先级 | — | Way2 > Way1（程序序靠后） |
| 写后读旁路 | 1端口 | 4端口均支持 |

- x0 硬连线 0，写 x0 被忽略
- 异步读 + 写后旁路（同周期读写同址返回新值）

---

## 5. 冒险处理（hazard_unit）

实现文件：`src/cpu/core/hazard_unit.v`

### 5.1 控制冒险
`mispredict_ex = 1` → flush_if / flush_id / flush_ex（最高优先级）

### 5.2 Load-Use 冒险
EX 阶段若为 Load，检测 IDII 中 Way1 和 Way2 的所有源依赖：
- 任一命中 → stall_if = 1, stall_id = 1（插入 1 个气泡）

### 5.3 双发射停顿
II 阶段输出 `stall_dual = 1`（当阻断双发射）：
- stall_if = 1, stall_id = 1（IF 和 IDII 寄存器保持）
- 次周期以 `issued_w1 = 1` 标志重试 Way2

### 5.4 EX 阶段前递（不需要 stall）
通过 EX 阶段内嵌前递单元处理大部分 RAW 冒险，无需额外 stall。

---

## 6. 分支预测（保留原机制）

### 6.1 BTB（Branch Target Buffer）
- 4路组相联，16组（共 64 项）
- 索引 = pc[7:2]，标记 = pc[31:12]
- 命中时提供预测目标地址

### 6.2 BHT（Branch History Table）
- 256项 2-bit 饱和计数器（初值 01 = 弱不跳）
- 索引 = pc[9:2] XOR ghr（8-bit 全局历史寄存器）
- 提供方向预测（taken/not-taken）

### 6.3 双发射与分支预测交互
- 当 BTB 命中（Way1 被预测为跳转），Way2 自动无效（IFID 输出 valid_w2 = 0）
- 控制冒险阻断双发射（ctrl_hazard in II）：含分支/跳转的 Way1 独占该周期

---

## 7. 顶层接口变化

### 7.1 指令接口（新版）
```verilog
output wire [63:0] instr_addr,      // 始终 = PC（Way1 地址）
input  wire [31:0] instr_data_w1,   // PC 处指令
input  wire [31:0] instr_data_w2,   // PC+4 处指令
```
> ⚠️ 相比旧版 `input wire [31:0] instr_data`，现在需要外部 Instruction Memory / ICache 每周期提供两条连续指令。

### 7.2 数据接口（不变）
```verilog
output wire [63:0] data_addr, data_wdata
input  wire [63:0] data_rdata
output wire        data_req, data_we
output wire  [7:0] data_be
input  wire        data_gnt
```

---

## 8. Cache 子模块（保留）

### 8.1 ICache（icache.v）
- 2路组相联，64组，256-bit 行宽
- 可扩展接入 IF 阶段指令接口

### 8.2 DCache（dcache.v）
- 2路组相联，64组，256-bit 行宽，维护 valid/dirty/tag/LRU
- 可扩展接入 MEM 阶段数据接口

> 两个 Cache 模块保持独立实现，接口与主流水线兼容，待后续集成。

---

## 9. CSR 与乘除法子模块

- `csr_unit.v`：支持 mstatus/mie/mtvec/mepc/mcause 等 CSR，定时中断逻辑完整，待接入主流水线
- `mul_div.v`：保留独立多周期实现（可用于后续性能优化）
- 当前主流水线已在 `ex_stage.v` 中集成组合 M 扩展执行路径，功能上支持 RV64M

---

## 10. 验证说明

| 测试资源 | 说明 |
|---------|------|
| `test/riscv_cpu_tb.v` | 顶层测试平台（需更新为双宽指令接口） |
| `test/tb_riscv_cpu.v` | 顶层功能验证 |
| `test/modules/tb_*.v` | 各子模块独立 testbench（ii_stage 需新增） |

**建议验证重点：**
1. 双发射阻断逻辑（RAW/WAW/结构/控制/系统冒险各类型）
2. `issued_w1` 重试机制（Way2 下周期作为 Way1 发射）
3. 4路前递覆盖（EX/MEM Way1/Way2 → 当前 EX 操作数）
4. Load-Use 停顿后的双路恢复
5. 分支误预测后 3 级冲刷的正确性

---

## 11. 性能分析（理论估计）

| 指标 | 说明 |
|-----|------|
| 理想 IPC | 2.0（双发射满发射） |
| 实际 IPC | 受限于双发射阻断率、分支预测命中率 |
| 分支惩罚 | 3 个气泡（冲刷 IFID/IDII/IIEX）|
| Load-Use 惩罚 | 1 个停顿周期 |
| 双发射停顿 | 1 个停顿周期（每次阻断） |

---

文档状态：已根据6级流水线双发射 RTL 实现重写  
最后更新：2026-03-29
