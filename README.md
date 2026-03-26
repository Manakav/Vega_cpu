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
- 语言：Verilog或VHDL
- 平台：FPGA（Xilinx Zynq-7000/Artix-7系列）
- 工具：ModelSim、VCS、Vivado、Quartus

## 性能目标

- 主频：≥ 50MHz
- LUT占用：＜ 5K
- 分支预测准确率：＞ 90%
- IPC：≥ 0.8

## 开发环境

### 必需工具
1. **仿真工具**
   - ModelSim (功能仿真)
   - VCS (时序仿真，可选)

2. **综合工具**
   - Xilinx Vivado (针对Xilinx FPGA)
   - Intel Quartus (针对Intel FPGA)

3. **开发板**
   - Xilinx Zynq-7000系列
   - Xilinx Artix-7系列

### 推荐工具
1. **代码编辑器**
   - VSCode + Verilog/VHDL插件
   - Emacs/Vim

2. **版本控制**
   - Git

3. **文档工具**
   - Markdown编辑器

## 项目文档

### 核心文档
- [需求文档](CPU_DESIGN_REQUIREMENTS.md) - 详细项目需求
- [架构设计](docs/ARCHITECTURE.md) - CPU架构设计模板
- [项目总结](PROJECT_SUMMARY.md) - 项目进度总结

### 代码模板
- [CPU顶层模块](src/riscv_cpu.v)
- [测试平台](test/riscv_cpu_tb.v)
- [Vivado工程文件](Project/)


---
*最后更新：2026年3月26日*
*项目状态：进行中*