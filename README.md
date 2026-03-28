# Vega_cpu - 基于RISC-V的高性能CPU设计项目

本项目基于RISC-V指令集架构，设计一款高性能CPU并通过FPGA平台进行验证。

## 项目概述

五级流水线RISC-V CPU，支持RV32I/RV64I指令集，包含分支预测、数据旁路等优化技术。

## 项目结构

```
Vega_cpu/
├── docs/           # 项目文档
├── src/            # Verilog/VHDL源代码
├── test/           # 测试代码和TestBench
├── Project/        # Vivado相关文件
├── tools/          # 工具
├── CPU_DESIGN_REQUIREMENTS.md  # 需求文档
└── README.md       # 项目说明
```


## 技术要求

- 指令集：RISC-V RV32I/RV64I
- 架构：五级流水线（IF、ID、EX、MEM、WB）
- 语言：Verilog
- 平台：FPGA
- 工具：Vivado

## 性能目标

- 主频：≥ 50MHz
- LUT占用：＜ 5K
- 分支预测准确率：＞ 90%
- IPC：≥ 0.8