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
├── fpga/           # FPGA相关文件
├── scripts/        # 工具脚本
├── CPU_DESIGN_REQUIREMENTS.md  # 需求文档
└── README.md       # 项目说明
```

## 快速开始

详细的项目需求和技术规范请参考 `CPU_DESIGN_REQUIREMENTS.md` 文件。

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
   - Draw.io (绘图工具)

## 项目文档

### 核心文档
- [需求文档](CPU_DESIGN_REQUIREMENTS.md) - 详细项目需求
- [架构设计](docs/ARCHITECTURE.md) - CPU架构设计模板
- [项目总结](PROJECT_SUMMARY.md) - 项目进度总结

### 代码模板
- [CPU顶层模块](src/riscv_cpu.v)
- [测试平台](test/riscv_cpu_tb.v)
- [Vivado工程文件](Project/)

### 工具脚本
- [仿真脚本](scripts/run_sim.bat) - Windows仿真自动化
- [性能分析](scripts/analyze_performance.py) - Python性能分析工具

## 快速开始

### 1. 环境准备
```bash
# 安装ModelSim并添加到PATH
# 安装Xilinx Vivado并配置环境
# 确保Python3已安装
```

### 2. 获取代码
```bash
git clone <repository-url>
cd Vega_cpu
```

### 3. 运行仿真
```bash
# Windows
scripts\run_sim.bat

# 或使用ModelSim GUI
vsim -do "do scripts/run_sim.tcl"
```

### 4. 性能分析
```bash
python scripts/analyze_performance.py --log sim/riscv_cpu_tb.log
```

## 开发流程

### 阶段1: 架构设计
1. 详细流水线设计
2. 模块划分
3. 接口定义

### 阶段2: RTL实现
1. 各阶段模块编码
2. 模块级仿真
3. 代码审查

### 阶段3: 系统集成
1. 流水线集成
2. 系统级仿真
3. 性能优化

### 阶段4: FPGA验证
1. FPGA综合
2. 硬件测试
3. 性能评估

### 阶段5: 应用开发
1. 测试程序
2. 性能基准
3. 文档整理

## 贡献指南

### 代码规范
1. 遵循Verilog/VHDL编码规范
2. 添加充分的注释
3. 模块接口清晰定义

### 提交规范
1. 提交前进行代码检查
2. 编写清晰的提交信息
3. 关联相关Issue

### 测试要求
1. 新功能必须包含测试
2. 修复Bug需要添加回归测试
3. 性能优化需要基准测试

## 许可证

本项目基于七星微企业命题要求开发，请遵守相关知识产权规定。

## 联系方式

- 项目负责人：[姓名]
- 邮箱：[email@example.com]
- 项目地址：[repository-url]

---
*最后更新：2026年3月26日*
*项目状态：进行中*