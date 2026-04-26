# Vega_cpu - RISC-V RV64IMC 6级双发射 CPU 项目

本项目实现了一个面向 FPGA 验证的 RISC-V CPU 内核，当前主干架构为 RV64IMC、6 级流水线、有序双发射（In-Order Dual-Issue）。

## 项目状态

- RTL 主线：可编译、可运行，主用双发射 testbench 已通过。
- 指令/数据接口：采用双指令取指接口（instr_data_w1/w2）+ 单路数据访存接口。
- Cache：ICache/DCache 已完成系统级集成。
- FPGA 实现：已切换至 xc7a200t，XDC 约束已在 Vivado 中完成，bitstream 已生成。

## 架构概览

- ISA：RV64IMC（RV64I + M + C）
- 流水线：IF -> ID -> II -> EX -> MEM -> WB
- 发射宽度：双发射（Way1/Way2）
- 分支预测：BTB + BHT
- 寄存器堆：4 读 2 写
- 访存模型：Way1 访存，Way2 透传

更完整的模块与接口说明见文档：
- docs/ARCHITECTURE.md
- PROJECT_SUMMARY.md

## 目录结构

```text
Vega_cpu/
├── docs/                  # 架构、验证、工具链、Vivado 文档
├── src/cpu/               # CPU RTL 主代码
├── test/                  # 系统级与模块级 testbench、仿真脚本
├── Project/Vega/          # Vivado 工程与运行目录
├── tools/                 # 第三方/辅助工具（如 CoreMark）
└── README.md
```

## 快速开始

### 1) RTL 快速回归（推荐入口）

```bash
bash test/run_rtl_sim.sh
```

说明：
- 当前主用顶层 testbench 为 test/riscv_cpu_tb_dual.v。
- 若脚本输出错误数为 0，即表示该轮基础功能回归通过。

### 2) 模块级测试

```bash
bash test/run_module_tbs.sh
```

该脚本会依次执行 ALU、译码器、分支预测、Cache 等模块 testbench。

## Vivado 相关

可参考：
- docs/VIVADO_TESTING.md
- VIVADO_QUICKSTART.md
- Project/Vega/vivado_test.sh

当前已知情况（工程态）：
- synth 可完成；
- impl 可完成；
- bitstream 已生成，待上板验证。

## 关键文档索引

- docs/ARCHITECTURE.md：当前架构与实现状态（已与主干 RTL 对齐）
- docs/SOC_REMAINING_PARTS.md：SoC 收敛剩余 Part 清单
- VERIFICATION_STATUS.md：验证阶段状态
- VERIFICATION_QUICKSTART.md：验证命令速查
- docs/TOOLCHAIN_INSTALL.md：工具链安装与配置

## 许可证

本仓库内第三方目录（如 tools/riscv-coremark）遵循其各自许可证；
其余项目内容按仓库后续约定执行。
