# Vega CPU 技术架构设计文档

本文档基于当前 RTL 实现整理，覆盖 CPU 总体架构、模块实现细节、关键接口定义与实现说明。源码以 src/cpu 目录为准。

## 1. 设计目标与范围

### 1.1 目标
- ISA 目标：RV64 基线，译码器已覆盖 RV64I 常见整数指令格式，并包含压缩指令识别路径与 M 扩展子模块。
- 微架构目标：五级流水线（IF/ID/EX/MEM/WB），带基础冒险处理与动态分支预测。
- 接口目标：分离的指令口与数据口，便于后续对接片上总线或外部存储控制器。

### 1.2 范围说明
- 本文档描述已在 RTL 中实现的行为。
- 对于工程中存在但尚未在顶层完整接入的模块（如 icache、dcache、csr_unit、mul_div），本文档按其独立实现进行说明，并标注集成状态。

## 2. 总体架构

### 2.1 顶层结构
顶层模块为 riscv_cpu，位于 src/cpu/riscv_cpu.v，核心参数如下：
- DATA_WIDTH = 64
- ADDR_WIDTH = 64
- REG_COUNT = 32

流水线主路径：
1. IF：PC 生成、取指、分支预测
2. ID：译码、立即数生成、寄存器读、控制信号生成
3. EX：算术逻辑运算、分支决策、预测校验
4. MEM：Load/Store 数据格式处理与外部数据口驱动
5. WB：写回结果选择并写寄存器堆

### 2.2 数据与控制主通路
- 数据主通路：寄存器堆读数 -> EX 运算 -> MEM 访存结果 -> WB 选择 -> 寄存器堆写回。
- 控制主通路：ID 产生控制信号，随流水级传递，hazard_unit 统一产生 stall/flush/forward。
- 分支通路：IF 预测 -> EX 实际判断 -> mispredict 回传 IF/ID/EX 冲刷。

### 2.3 时序与复位
- 时序类型：同步时钟上升沿驱动。
- 复位类型：低有效异步复位 rst_n。
- 初始 PC：64'h1000（由 IF 阶段 pc_reg 复位值定义）。

## 3. 五级流水线详细设计

## 3.1 IF 阶段（if_stage）

实现文件：
- src/cpu/core/if_stage/if_stage.v
- src/cpu/core/if_stage/btb.v
- src/cpu/core/if_stage/bht.v

功能：
- 维护当前 PC。
- 与指令存储器接口交互并输出取回指令。
- 调用 BTB/BHT 进行动态分支预测。
- 接收 EX 阶段 mispredict 并重定向 PC。

关键逻辑：
- next_pc = mispredict ? branch_target : (predict_taken ? predict_pc : pc + 4)
- predict_taken 由 BTB 命中有效或 BHT 结果给出。
- 使用 8 位 GHR（全局历史寄存器），在预测或纠错时移位更新。

输入接口：
- 流控：stall, flush
- 指令口握手：instr_data, instr_gnt
- 分支反馈：branch_taken, branch_target, mispredict

输出接口：
- 指令口请求：instr_addr, instr_req
- 送 ID：pc_out, instr_out, valid_out

实现特点：
- instr_req 固定拉高，当前模型为简化请求协议。
- stall 时输出无效泡沫，避免错误指令推进。

## 3.2 ID 阶段（id_stage）

实现文件：
- src/cpu/core/id_stage/id_stage.v
- src/cpu/core/id_stage/decoder.v
- src/cpu/core/id_stage/register_file.v

功能：
- 指令字段拆分与类型判定。
- 立即数生成。
- 读寄存器堆。
- 生成 EX/MEM/WB 控制信号。

译码覆盖：
- 32-bit 指令：LOAD、STORE、BRANCH、JALR、JAL、AUIPC、LUI、OP-IMM、OP、SYSTEM。
- 压缩指令：通过 instr[1:0] != 2'b11 判定并进入 C 指令解析分支。

控制信号生成：
- alu_op_o：由 opcode/funct3/funct7 组合编码。
- alu_src1_sel_o/alu_src2_sel_o：选择 PC、寄存器或立即数参与运算。
- mem_read_en_o/mem_write_en_o/mem_size_o：访存控制。
- reg_write_en_o/wb_sel_o：写回使能与写回源（ALU/MEM/PC+4）。

前递输入：
- forward_rs1, forward_rs2, forward_sel 支持在译码级进行源操作数替换。

寄存器堆设计：
- 32 x 64-bit。
- 双读单写。
- 异步读，同步写。
- x0 恒为 0，写 x0 被忽略。
- 同周期写后读同地址支持旁路返回 wdata。

## 3.3 EX 阶段（ex_stage）

实现文件：
- src/cpu/core/ex_stage/ex_stage.v
- src/cpu/core/ex_stage/alu.v
- src/cpu/core/ex_stage/mul_div.v（独立模块，当前未在 ex_stage 内例化）

功能：
- 通过 forward_a_sel/forward_b_sel 选择最终操作数。
- 执行 ALU 运算。
- 进行分支比较与跳转目标计算。
- 与 IF 阶段预测结果比对，输出 mispredict。

ALU 操作（alu.v）：
- ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND
- LUI（直通 operand_b）
- AUIPC 类路径（直通 operand_a）

分支与跳转：
- 条件分支依据 mem_size_i 编码区分 BEQ/BNE/BLT/BGE/BLTU/BGEU。
- 跳转目标：
1. JAL：pc + imm
2. JALR：rs1 + imm

预测错误判定：
- 若为分支或跳转，满足以下任一条件即 mispredict：
1. 实际跳转方向与 predict_taken_i 不一致
2. 实际跳转且目标地址与 predict_target_i 不一致

mul_div 模块说明：
- 支持 MUL、MULH、MULHSU、MULHU、DIV、DIVU、REM、REMU。
- 输出 done 握手，内部为简化状态机（IDLE/DONE）。
- 顶层尚未将其接入 EX 控制路径。

## 3.4 MEM 阶段（mem_stage）

实现文件：
- src/cpu/core/mem_stage/mem_stage.v
- src/cpu/core/mem_stage/dcache.v（独立模块，当前未在 mem_stage 内例化）

功能：
- 驱动数据存储器接口地址、写数据与字节使能。
- 对 Load 数据进行符号扩展/零扩展。
- 透传 ALU 结果与目标寄存器号到 WB。

访存编码：
- mem_size_i 用于字节数/扩展方式选择。
- mem_be 根据访存宽度生成 8-bit byte enable。
- 写数据按访存宽度低位对齐。

Load 数据处理：
- LB/LH/LW/LD 进行符号扩展。
- LBU/LHU/LWU 进行零扩展。

dcache 模块说明：
- 2 路组相联，64 组，单行 256-bit。
- 维护 valid/dirty/tag/data 与简单 LRU。
- 读 miss 时发起 mem_req，mem_ready 返回整行填充。
- 顶层尚未把 dcache 挂入主访存路径。

## 3.5 WB 阶段（顶层组合实现）

WB 在顶层 riscv_cpu.v 中以组合方式完成：
- wb_result = (wb_sel == 2'b01) ? mem_result_mem : alu_result_ex
- reg_write_en_wb 连接自执行路径控制信号。
- 写回端口接 register_file。

说明：
- 当前实现将写回结果直接取自 EX/MEM 可见信号，后续可进一步细化为显式 WB 流水寄存器以提升时序可控性。

## 4. 冒险处理与分支预测

## 4.1 hazard_unit 设计

实现文件：
- src/cpu/core/hazard_unit.v

输入：
- ID 阶段源寄存器地址及使用标志。
- EX/MEM/WB 目的寄存器地址及写使能。
- EX 阶段 Load 标志与分支修正标志。

输出：
- 流控：stall_if, stall_id, flush_if, flush_id, flush_ex
- 前递选择：forward_a, forward_b

策略：
- 控制冒险优先：mispredict_ex 为真时冲刷 IF/ID/EX。
- Load-Use 冒险：若 EX 是 Load 且 ID 依赖 EX 目的寄存器，则停顿 IF/ID。
- 其余数据冒险：优先 EX，再 MEM，再 WB 前递。

## 4.2 BTB 设计（btb）

结构：
- 4 路组相联。
- 16 组。
- 每项包含 tag、target、valid。
- 每组维护 2-bit 近似 LRU 指针。

索引与标记：
- index = pc[7:2]
- tag = pc[31:12]

更新：
- update_en 拉高时进行命中更新或替换写入。

## 4.3 BHT 设计（bht）

结构：
- 256 项 2-bit 饱和计数器。
- 初值 01（弱不跳转）。

索引：
- index = pc[9:2] XOR ghr

更新：
- 根据 update_taken 对 2-bit 计数器做饱和加减。

## 5. CSR 与异常/中断实现

实现文件：
- src/cpu/core/csr/csr_unit.v

功能覆盖：
- CSR 读写：mstatus/mie/mtvec/mepc/mcause/mtval/mip/mcycle/mtime/mtimecmp
- 计数器：mcycle 和 mtime 自增
- 定时中断：mtime >= mtimecmp 时置位 mip[7]
- 异常入口信息记录：mepc/mcause/mtval

CSR 访问接口：
- 输入：csr_addr[11:0]、csr_wdata、csr_we、csr_re、funct3
- 输出：csr_rdata

中断输出：
- irq_timer = mip[7] & mie[7]
- irq_software = mip[3] & mie[3]
- irq_external = mip[11] & mie[11]

集成状态：
- csr_unit 已实现但未在顶层主流水线中完整接入。

## 6. 模块接口实现说明

## 6.1 顶层外部接口（riscv_cpu）

时钟复位：
- clk：系统时钟
- rst_n：低有效复位

指令接口：
- 输出：instr_addr[63:0], instr_req
- 输入：instr_data[31:0], instr_gnt
- 语义：CPU 发起取指地址与请求，外部返回 32-bit 指令与授予信号。

数据接口：
- 输出：data_addr[63:0], data_wdata[63:0], data_req, data_we, data_be[7:0]
- 输入：data_rdata[63:0], data_gnt
- 语义：统一 load/store 接口，字节使能适配不同访存宽度。

中断与调试：
- 输入：irq_external, irq_timer, irq_software, debug_req
- 输出：debug_halt, debug_resume
- 当前调试输出固定：debug_halt=0, debug_resume=1。

## 6.2 流水线内部接口

IF -> ID：
- pc_if, instr_if, valid_if

ID -> EX：
- 数据：pc、rs1_data、rs2_data、imm、rd_addr、valid
- 控制：alu_op、alu_src1/2_sel、mem_read/write_en、mem_size、reg_write_en、wb_sel、is_branch、is_jump

EX -> MEM：
- alu_result、rs2_data、rd_addr、valid
- 控制透传：mem_read/write_en、mem_size、reg_write_en、wb_sel
- 分支反馈：branch_taken、branch_target、mispredict

MEM -> WB：
- alu_result、mem_result、rd_addr、valid、reg_write_en、wb_sel

## 6.3 前递与冲刷接口

来自 hazard_unit：
- stall_if/stall_id
- flush_if/flush_id/flush_ex
- forward_a[1:0]/forward_b[1:0]

前递源：
- EX 结果
- MEM 结果
- WB 结果

## 7. 存储与缓存子系统

## 7.1 指令侧
- 当前 IF 阶段直接使用 instr_* 外部接口。
- icache 提供了可选的片上 ICache 实现（2-way, 64 set, 256-bit line），可作为后续集成路径。

## 7.2 数据侧
- 当前 MEM 阶段直接使用 data_* 外部接口。
- dcache 提供了可选 DCache 实现（2-way, 64 set, 256-bit line, dirty 管理）。

## 8. 验证实现现状

测试文件：
- 系统级：test/riscv_cpu_tb.v
- 模块级：test/modules/tb_*.v（ALU、BTB、BHT、CSR、各流水级与缓存模块）

已具备的验证方式：
- 模块独立 testbench，便于逐模块功能回归。
- 顶层 testbench 提供时钟、复位、简化存储模型与基本运行框架。

建议补充：
- 增加自动化回归脚本中的断言覆盖率统计。
- 增加随机指令流与异常/中断场景验证。
- 增加分支预测命中率统计监控信号。

## 9. 关键实现结论与后续演进

当前 RTL 体现了一个可扩展的五级流水线 CPU 框架，具备以下可用基础：
- 基本整数流水线数据通路
- 前递与 Load-Use 停顿
- BTB+BHT 动态分支预测框架
- 独立 CSR/M 扩展/Cache 子模块实现

后续建议优先级：
1. 完成 csr_unit 与异常返回路径在顶层接入。
2. 将 mul_div 接入 EX 控制路径并处理多周期停顿。
3. 将 icache/dcache 接入主路径并补全一致的握手机制。
4. 细化 WB 与控制信号跨级寄存，强化时序收敛能力。

---
文档状态：已根据当前源码完成技术化重写
最后更新：2026-03-28