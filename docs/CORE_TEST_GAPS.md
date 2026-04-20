# Vega CPU Core 验证清单

> 更新日期：2026-04-19
> 状态：**单元测试文件已创建，待 iverilog 环境中编译运行**

---

## 一、验证总表

### 1.1 模块级单元测试

| # | 测试项 | 测试文件 | 目标模块 | 状态 | 测试点数 |
|---|--------|---------|---------|------|---------|
| 1 | ALU 运算 | `test/modules/tb_alu.v` | ALU | ✅ 已有 | 15 |
| 2 | 寄存器堆 4R2W | `test/modules/tb_register_file.v` | register_file | ⚠️ 需更新4R2W | 2 |
| 3 | 译码器 | `test/modules/tb_decoder.v` | decoder | ✅ 已有 | — |
| 4 | BTB | `test/modules/tb_btb.v` | BTB | ✅ 已有 | — |
| 5 | BHT | `test/modules/tb_bht.v` | BHT | ✅ 已有 | — |
| 6 | CSR 单元 | `test/modules/tb_csr_unit.v` | CSR | ✅ 已有 | — |
| 7 | DCache | `test/modules/tb_dcache.v` | DCache | ✅ 已有 | — |
| 8 | ICache | `test/modules/tb_icache.v` | ICache | ✅ 已有 | — |
| 9 | IF 阶段 | `test/modules/tb_if_stage.v` | if_stage | ✅ 已有 | — |
| 10 | ID 阶段 | `test/modules/tb_id_stage.v` | id_stage | ✅ 已有 | — |
| 11 | EX 阶段 | `test/modules/tb_ex_stage.v` | ex_stage | ✅ 已有 | 2 |
| 12 | MEM 阶段 | `test/modules/tb_mem_stage.v` | mem_stage | ✅ 已有 | — |
| 13 | Mul/Div | `test/modules/tb_mul_div.v` | mul_div | ✅ 已有 | — |
| 14 | 冒险单元 | `test/modules/tb_hazard_unit.v` | hazard_unit | ✅ 已有 | 3 |

### 1.2 新增核心测试

| # | 测试项 | 测试文件 | 目标模块 | 状态 | 测试点数 |
|---|--------|---------|---------|------|---------|
| 15 | II 阶段双发射仲裁 | `test/modules/tb_ii_stage.v` | ii_stage | 🆕 新建 | 15 |
| 16 | EX 4路前递网络 | `test/modules/tb_forwarding.v` | ex_stage 前递 | 🆕 新建 | 10 |
| 17 | 双发射端到端集成 | `test/modules/tb_dual_issue_integration.v` | ii+ex+rf | 🆕 新建 | 7 |
| 18 | M 扩展全指令 | `test/modules/tb_m_extension.v` | ex_stage muldiv | 🆕 新建 | 14 |
| 19 | CSR + 异常组合 | `test/modules/tb_csr_exception.v` | csr_unit | 🆕 新建 | 11 |
| 20 | 分支预测准确性 | `test/modules/tb_branch_predict.v` | BTB+BHT | 🆕 新建 | 10 |

### 1.3 仍需补充的测试（按优先级）

#### P0 — 关键缺失

| # | 测试项 | 说明 | 前置条件 |
|---|--------|------|---------|
| 21 | riscv-tests ISA 合规 | 逐条验证 RV64IMC 指令 | 需 RISC-V 工具链 |
| 22 | 指令覆盖率统计 | 量化 I/M/C 各类型覆盖比 | 需覆盖率工具 |
| 23 | Load-Use 后双发射恢复 | 冒险停顿后 Way1/Way2 恢复 | tb_hazard_unit 部分覆盖，需集成测试 |
| 24 | 分支误预测 3级冲刷 | 误预测冲刷 IFID/IDII/IIEX | 需完整流水线仿真 |
| 25 | C 扩展指令对 | 16-bit 指令双发射对齐与取指 | 需 IF+ID 联合验证 |

#### P1 — 性能指标（报告必需）

| # | 测试项 | 说明 | 关键指标 |
|---|--------|------|---------|
| 26 | IPC 实测 | 单发射/可双发射/综合场景 | IPC(目标≥1.5) |
| 27 | DMIPS/MHz | Dhrystone 基准测试 | DMIPS/MHz(目标≥1.0) |
| 28 | CoreMark/MHz | CoreMark 基准测试 | CoreMark/MHz |
| 29 | 分支预测准确率 | BTB+BHT 在真实负载下 | 准确率(目标>90%) |
| 30 | 优化前后对比 | 5级单射 vs 6级双射性能差 | IPC/频率/资源差异 |

#### P2 — FPGA 与边界（完整性）

| # | 测试项 | 说明 | 关键指标 |
|---|--------|------|---------|
| 31 | FPGA 综合与时序 | LUT/FF/DSP/BRAM/fmax/slack | 资源占用率、时序裕量 |
| 32 | 在板验证 | 比特流下载后功能验证 | 功能正确性 |
| 33 | 异常完整路径 | ECALL/EBREAK→CSR冲刷→恢复 | 异常处理正确 |
| 34 | Cache 集成端到端 | ICache/DCache 与主流水线联合 | Cache命中率 |
| 35 | 长时间稳定性 | FPGA 上持续运行 1h+ | 无挂死、无违例 |
| 36 | 功耗评估 | 动态/静态功耗 | 功耗数值 |

---

## 二、测试详细说明（新建项）

### 2.1 tb_ii_stage.v — II 阶段双发射仲裁（15项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | 复位清零 | 复位后 valid_w1_o/valid_w2_o = 0 |
| T2 | 无冒险双发射 | 两条独立指令同时发射，stall_dual=0 |
| T3 | RAW 冒险检测 | Way2 rs1 == Way1 rd → stall_dual=1 |
| T4 | WAW 冒险检测 | Way1/Way2 同 rd → stall_dual=1 |
| T5 | 结构冒险 | 双 mem 操作 → stall_dual=1 |
| T6 | 控制冒险 | Way1 为 branch → stall_dual=1 |
| T7 | 系统冒险 | Way1 为 system → stall_dual=1 |
| T8 | Flush 清零 | flush 后 valid 全零，stall_dual=0 |
| T9 | Way2 rs2 依赖 | Way2 rs2 == Way1 rd → RAW |
| T10 | x0 不冒险 | Way1 rd=x0 时不触发 RAW |
| T11 | issued_w1 重试 | RAW 冒险后 Way2 下周期作为 slot1 发射 |
| T12 | Way1 写使能为0 | Way1 不写回时不触发 RAW |
| T13 | 寄存器堆地址直通 | 4 读口地址 = 输入 rs1/rs2 地址 |
| T14 | 预测信息传递 | predict_taken/target 直接传到 IIEX |
| T15 | 双写 x0 不冒险 | Way1/Way2 均 rd=x0 时不触发 WAW |

### 2.2 tb_forwarding.v — EX 4路前递网络（10项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | 无前递 | ALU 使用寄存器文件原文值 |
| T2 | EX/MEM Way1→rs1 | 前递值替换 rs1 |
| T3 | EX/MEM Way2→rs1 | Way2 前递值替换 rs1 |
| T4 | MEM/WB Way1→rs1 | 更低优先级前递 |
| T5 | MEM/WB Way2→rs1 | 最低优先级前递 |
| T6 | EX/MEM 优先于 MEM/WB | 同地址 EX/MEM W1 和 MEM/WB W1 均有效，选 EX/MEM |
| T7 | EX/MEM W1 优先于 W2 | 同地址 EX/MEM W1 和 W2 均有效，选 W1 |
| T8 | 前递到 Way2 | EX/MEM W1 前递到 Way2 的 rs1 |
| T9 | x0 不前递 | rd=x0 时前递值不替换 |
| T10 | rs2 前递 | EX/MEM W1 前递到 Way1 的 rs2 |

### 2.3 tb_dual_issue_integration.v — 双发射集成（7项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | 独立双发射 | ADD x3,x1,x2 ‖ ADD x6,x4,x5 同时通过 EX |
| T2 | RAW 冒险停顿 | Way2 依赖 Way1 结果，stall_dual=1 |
| T3 | WAW 冒险停顿 | Way1/Way2 同目的寄存器，stall_dual=1 |
| T4 | 控制冒险 | Way1 为 branch，双发射阻断 |
| T5 | 结构冒险 | 双 mem 指令同时发射 |
| T6 | Flush 清零 | flush 后 EX 输出 valid=0 |
| T7 | Load 信号传递 | mem_read_en 通过 II→EX 正确传递 |

### 2.4 tb_m_extension.v — M 扩展（14项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | MUL | 7*6=42 |
| T2 | MULH | (-2^63)*(-2^63) 高64位 |
| T3 | MULHU | 0xFFFF*2 高64位 |
| T4 | DIV | -16/4=-4 |
| T5 | DIVU | 100/7=14 |
| T6 | REM | -16%3=-1 |
| T7 | REMU | 100%7=2 |
| T8 | DIV 除零 | 除零返回全1 |
| T9 | REM 除零 | 余零返回全1 |
| T10 | DIVU 除零 | 无符号除零返回全1 |
| T11 | Way2 MUL | Way2 独立执行 MUL |
| T12 | 双路 MUL | Way1=3*4=12, Way2=5*6=30 |
| T13 | MULHSU | 有符号*无符号高位 |
| T14 | is_muldiv=0 | 非M扩展指令回退ALU路径 |

### 2.5 tb_csr_exception.v — CSR + 异常（11项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | 复位读 mstatus | 复位后 mstatus=0 |
| T2 | 写读 mstatus | 写入 0xFF 后读回 |
| T3 | 写读 mie | 写入 0x888 后读回 |
| T4 | 写读 mtvec | 写入 0x1000 后读回 |
| T5 | mcycle 递增 | mcycle > 0 |
| T6 | 定时器中断 | mtime≥mtimecmp 且 mie.MTIE=1 → irq_timer=1 |
| T7 | 异常保存 | exception 后 mepc/mcause/mstatus 更新 |
| T8 | 软件中断 | mip[3]&&mie[3] → irq_software |
| T9 | 外部中断 | mip[11]&&mie[11] → irq_external |
| T10 | csr_re=0 | 读使能为0时输出0 |
| T11 | 未映射 CSR | 地址0写入后读回为0 |

### 2.6 tb_branch_predict.v — 分支预测（10项）

| # | 测试用例 | 测试内容 |
|---|---------|---------|
| T1 | 空 BTB Miss | 未训练地址 btb_hit=0 |
| T2 | BTB 训练 | 训练后 btb_hit=1, target 正确 |
| T3 | 不同地址 Miss | 未训练地址 btb_hit=0 |
| T4 | 多地址训练 | 第二个地址训练后命中 |
| T5 | BHT not-taken | 训练 not-taken 后 bht_taken=0 |
| T6 | BHT taken | 训练 taken 后 bht_taken=1 |
| T7 | 预测准确率 | 简单 always-taken 负载下统计 |
| T8 | Reset 清空 | 复位后 BTB 全空 |
| T9 | 4路组相联 | 4 个同 set 地址全部存活 |
| T10 | 准确率报告 | 输出预测准确率数值 |

---

## 三、辅助脚本

| 文件 | 用途 |
|------|------|
| `test/modules/run_all_tests.sh` | Linux/macOS/Git Bash 统一回归脚本 |
| `test/modules/run_all_tests.bat` | Windows CMD 统一回归脚本 |
| `test/modules/generate_report.py` | 解析日志生成 Markdown/JSON 验证报告 |
| `test/ip_wrappers/ii_stage_ip_wrapper.v` | IP 核替换模板 |

---

## 四、运行方式

### 1. 安装 iverilog 后直接运行回归

```bash
# Linux/macOS/Git Bash
bash test/modules/run_all_tests.sh

# Windows CMD
test\modules\run_all_tests.bat
```

### 2. 单独编译运行某个测试

```bash
iverilog -g2001 -o tb.vvp src/cpu/core/ii_stage/ii_stage.v src/cpu/core/id_stage/register_file.v test/modules/tb_ii_stage.v
vvp tb.vvp
```

### 3. 生成报告

```bash
python3 test/modules/generate_report.py --log-dir test/test_results --output md
```

---

## 五、IP 核替换适配说明

当模块替换为 IP 核时：

1. 复制 `test/ip_wrappers/ii_stage_ip_wrapper.v` 为目标模板
2. 修改模块名为对应 IP 名，替换内部例化为 IP 黑盒或行为模型
3. 编译时通过 `+define+USE_IP_II_STAGE` 切换 IP/RTL 模式
4. 回归脚本自动选择对应编译列表

---

## 六、验证进度跟踪

| 阶段 | 项目 | 进度 |
|------|------|------|
| L1 语法检查 | 编译通过 | ✅ 100% |
| L2 RTL 仿真 | 基础仿真通过 | ✅ 100% |
| L3 单元测试 | 已有 14 项 | ✅ 完成 |
| L3 新增单元测试 | 6 项新增 | ⏳ 待编译运行 |
| L4 功能测试 | ISA 合规 + 性能基准 | 📋 规划中 |
| L5 综合验证 | FPGA 综合 + 时序 | ⏳ 待开始 |

| # | 测试文件 | 覆盖目标模块 | 关键测试点 |
|---|---------|------------|-----------|
| 1 | `test/modules/tb_ii_stage.v` | II 阶段（ii_stage.v） | RAW/WAW/结构/控制/系统 冒险检测、`can_dual_issue` 全覆盖、`stall_dual` 与 `issued_w1` 重试、IDII/IIEX 时序与冲刷、寄存器堆直通、预测信息传递、x0 寄存器特判 |
| 2 | `test/modules/tb_forwarding.v` | EX 阶段前递网络 | 4 路前递：EX/MEM Way1→rs1/rs2、EX/MEM Way2→rs1/rs2、MEM/WB Way1→rs1/rs2、MEM/WB Way2→rs1/rs2；优先级测试（EX/MEM W1 > EX/MEM W2 > MEM/WB W1 > MEM/WB W2）；x0 不前递 |
| 3 | `test/modules/tb_dual_issue_integration.v` | II+EX+RegisterFile 端到端 | 独立双发射正确性、RAW/WAW/控制/结构冒险端到端验证、冲刷后 EX 输出清零、Load 指令 mem_read_en 传递 |
| 4 | `test/modules/tb_m_extension.v` | M 扩展（muldiv_pick） | MUL、MULH、MULHSU、MULHU、DIV、DIVU、REM、REMU；除零处理（全1）；Way2 独立 M 扩展；双路同时 M 扩展；is_muldiv=0 回退 ALU |
| 5 | `test/modules/tb_csr_exception.v` | CSR 单元 + 异常 | mstatus/mie/mtvec/mepc/mcause 读写；定时器中断（mtime/mtimecmp）；异常保存 mepc/mcause/mstatus；软件中断；外部中断；读未映射 CSR 返回 0 |
| 6 | `test/modules/tb_branch_predict.v` | BTB + BHT | BTB 空 查 Miss；训练后 Hit 与 target 正确性；BTB 4 路组相联无驱逐；BHT 2-bit 饱和计数器状态转移；reset 清空后行为；预测准确率统计 |

---

## 辅助脚本

| 文件 | 用途 |
|------|------|
| `test/modules/run_all_tests.sh` | Linux/macOS/Git Bash 统一回归脚本 |
| `test/modules/run_all_tests.bat` | Windows CMD 统一回归脚本 |
| `test/modules/generate_report.py` | 解析日志生成 Markdown/JSON 验证报告 |
| `test/ip_wrappers/ii_stage_ip_wrapper.v` | IP Wrapper 模板（含 `ifdef USE_IP_II_STAGE 切换） |

---

## 运行方式

### 1. 安装 iverilog 后直接运行回归

```bash
# Linux/macOS/Git Bash
bash test/modules/run_all_tests.sh

# Windows CMD
test\modules\run_all_tests.bat
```

### 2. 单独编译运行某个测试

```bash
iverilog -g2001 -o tb.vvp src/cpu/core/ii_stage/ii_stage.v src/cpu/core/id_stage/register_file.v test/modules/tb_ii_stage.v
vvp tb.vvp
```

### 3. 生成报告

```bash
python3 test/modules/generate_report.py --log-dir test/test_results --output md
```

---

## 仍需补充的测试（优先级排序）

### P0 — 关键缺失（未在本轮创建）

| 测试项 | 说明 | 建议 |
|--------|------|------|
| riscv-tests ISA 合规 | 逐条验证 RV64IMC 指令 | 需 RISC-V 工具链，移植 riscv-tests 到 testbench |
| 指令覆盖率统计 | 量化 I/M/C 各类型指令覆盖比 | 需功能覆盖率工具或脚本统计 |
| Load-Use 停顿后双发射恢复 | Load-Use 冒险后的 Way1/Way2 双路恢复 | 已在 tb_hazard_unit 中部分覆盖，需在集成测试中补充 |
| 分支误预测 3 级冲刷 | 误预测后冲刷 IFID/IDII/IIEX 的端到端正确性 | 需仿真完整流水线重构 |

### P1 — 性能指标（报告必需）

| 测试项 | 说明 | 建议 |
|--------|------|------|
| IPC 实测 | 单发射/可双发射/综合场景下的 IPC | 需加载程序计数器到 testbench，统计退休指令/cycle |
| DMIPS/MHz | Dhrystone 基准测试 | 需工具链移植 Dhrystone |
| CoreMark/MHz | CoreMark 基准测试 | 需移植与运行环境 |
| 优化前后对比 | 5 级单发射 vs 6 级双发射的 IPC/频率/资源差异 | 需 FPGA 综合后收集数据 |

### P2 — FPGA 与边界（完整性）

| 测试项 | 说明 | 建议 |
|--------|------|------|
| FPGA 综合与时序 | LUT/FF/DSP/BRAM 占用率、fmax、slack | Vivado 综合后获取 |
| 在板验证 | 比特流下载后功能验证 | 需 FPGA 开发板 |
| 异常完整路径 | ECALL/EBREAK → CSR 冲刷 → 恢复 | 需完整流水线 |
| Cache 集成 | ICache/DCache 与主流水线联合 | 需 Cache 行为模型 |

---

## IP 核替换适配说明

当模块替换为 IP 核时：

1. 复制 `test/ip_wrappers/ii_stage_ip_wrapper.v` 为目标模板
2. 修改模块名为对应 IP 名，替换内部例化为 IP 黑盒或行为模型
3. 编译时通过 `+define+USE_IP_II_STAGE` 切换 IP/RTL 模式
4. 回归脚本自动选择对应编译列表

---