# RISC-V 工具链与模拟器安装指南

本文档详细介绍在 Ubuntu/Debian Linux 环境下安装 RISC-V 交叉编译工具链和 Verilog 模拟器的方法。

---

## 目录

- [1. 环境概述](#1-环境概述)
- [2. 安装 Verilog 模拟器](#2-安装-verilog-模拟器)
- [3. 安装 RISC-V 工具链](#3-安装-risc-v-工具链)
- [4. 验证安装](#4-验证安装)
- [5. 常见问题](#5-常见问题)

---

## 1. 环境概述

### 1.1 需要安装的软件

| 软件 | 用途 | 安装方式 |
|------|------|----------|
| Icarus Verilog | Verilog 仿真器 | apt |
| GTKWave | 波形查看器 | apt |
| riscv64-unknown-elf-gcc | RISC-V 交叉编译 | 预编译包或源码编译 |

### 1.2 安装架构

```
┌─────────────────────────────────────────────┐
│              Linux 主机                       │
│  ┌───────────────────────────────────────┐  │
│  │           终端环境                      │  │
│  │  ┌─────────┐  ┌─────────────────┐   │  │
│  │  │ iverilog│  │riscv64-elf-gcc  │   │  │
│  │  └─────────┘  └─────────────────┘   │  │
│  │  ┌─────────┐                        │  │
│  │  │  GTKWave │                       │  │
│  │  └─────────┘                        │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 2. 安装 Verilog 模拟器

### 2.1 通过 apt 安装

```bash
# 更新软件包列表
sudo apt update

# 安装 Icarus Verilog
sudo apt install iverilog

# 安装 GTKWave 波形查看器
sudo apt install gtkwave
```

### 2.2 验证安装

```bash
# 检查 iverilog 版本
iverilog -v

# 检查 vvp 版本
vvp -v

# 检查 gtkwave
gtkwave --version
```

预期输出示例：

```
Icarus Verilog version 11.0 (devel) ()
```

### 2.3 从源码编译安装（可选）

如果 apt 版本过低，可以从源码编译：

```bash
# 安装依赖
sudo apt install git make flex bison g++ tcl-dev tk-dev

# 下载源码
git clone https://github.com/steveicarus/iverilog.git
cd iverilog

# 编译安装
sh autoconf
./configure
make
sudo make install
```

---

## 3. 安装 RISC-V 工具链

### 3.1 方法一：从仓库安装（简单）

```bash
# Debian/Ubuntu 22.04+ 自带 riscv64 gcc
sudo apt install gcc-riscv64-unknown-elf
```

### 3.2 方法二：使用预编译包（推荐）

**步骤 1：下载预编译工具链**

```bash
# 创建安装目录
mkdir -p ~/opt/riscv
cd ~/opt/riscv

# 下载 xPack 预编译版本
wget https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v13.2.0-2/xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz

# 解压
tar -xzf xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz
```

**步骤 2：配置环境变量**

```bash
# 编辑 ~/.bashrc 或 ~/.zshrc
vim ~/.bashrc
```

在文件末尾添加：

```bash
# RISC-V Toolchain
export RISCV_ROOT="$HOME/opt/riscv/xpack-riscv-none-elf-gcc-13.2.0-2"
export PATH="$RISCV_ROOT/bin:$PATH"
```

使配置生效：

```bash
source ~/.bashrc
```

### 3.3 方法三：从源码编译（完整但耗时）

```bash
# 安装依赖
sudo apt install autoconf automake autotools-dev curl python3 libmpc-dev \
    libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
    gperf libtool patchutils bc zlib1g-dev libexpat1-dev

# 下载源码
git clone --recursive https://github.com/riscv/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain

# 配置并编译（RV64IMC，耗时约 1-2 小时）
./configure --prefix=$HOME/opt/riscv
make -j$(nproc)

# 配置环境变量
echo 'export PATH="$HOME/opt/riscv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3.4 验证工具链

```bash
# 检查 GCC 版本
riscv64-unknown-elf-gcc --version

# 检查工具链组件
riscv64-unknown-elf-as --version
riscv64-unknown-elf-ld --version
riscv64-unknown-elf-objcopy --version
```

预期输出示例：

```
riscv64-unknown-elf-gcc (GCC) 13.2.0
Copyright (C) 2023 Free Software Foundation, Inc.
```

---

## 4. 验证安装

### 4.1 创建测试项目

```bash
# 进入项目目录
cd ~/Vega_cpu

# 创建测试文件
cat > hello.c << 'EOF'
int main() {
    return 42;
}
EOF
```

**编译测试：**

```bash
riscv64-unknown-elf-gcc -nostdlib -static -march=rv64imc -mabi=lp64 -o hello.elf hello.c
riscv64-unknown-elf-objdump -D hello.elf
```

### 4.2 编译项目测试程序

```bash
cd ~/Vega_cpu/test/workbench/soft

# 清理旧文件
make clean

# 编译并生成 hex
make all

# 查看反汇编
make dump
```

### 4.3 运行 RTL 仿真

```bash
cd ~/Vega_cpu

# 运行仿真
bash test/run_rtl_sim.sh

# 或运行完整验证
bash test/run_verification_suite.sh
```

---

## 5. 常见问题

### Q1: apt 安装提示权限错误

**问题**：执行 `sudo apt install` 提示权限不足。

**解决**：

```bash
# 确认当前用户有 sudo 权限
sudo whoami

# 如果没有，先切换到有权限的用户
su - <username>
```

---

### Q2: 工具链命令找不到

**问题**：执行 `riscv64-unknown-elf-gcc` 提示命令不存在。

**解决**：

1. 确认安装成功：
   ```bash
   ls ~/opt/riscv/bin/
   ```

2. 检查环境变量：
   ```bash
   echo $PATH
   which riscv64-unknown-elf-gcc
   ```

3. 重新加载配置：
   ```bash
   source ~/.bashrc
   ```

---

### Q3: iverilog 仿真报错

**问题**：仿真时出现 `iverilog: command not found` 或语法错误。

**解决**：

1. 检查 iverilog 版本：
   ```bash
   which iverilog
   iverilog -v
   ```

2. 如果 apt 版本有问题，尝试从源码编译安装（见 2.3 节）

---

### Q4: 编译时找不到库

**问题**：工具链编译时提示缺少库文件。

**解决**：

```bash
# 安装缺失的依赖
sudo apt install libmpc-dev libmpfr-dev libgmp-dev
```

---

### Q5: xPack 下载失败

**问题**：wget 下载 GitHub  releases 超时。

**解决**：

1. 使用国内镜像：
   ```bash
   wget https://ghproxy.com/https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v13.2.0-2/xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz
   ```

2. 或使用 git clone 方式从源码编译

---

### Q6: 波形文件无法打开

**问题**：GTKWave 打开 .vcd 文件显示乱码。

**解决**：

1. 确认仿真时生成了波形文件：
   ```bash
   ls -la build_sim/*.vcd
   ```

2. 使用 GTKwave 打开：
   ```bash
   gtkwave build_sim/tb.vcd &
   ```

---

## 附录：完整安装命令汇总

### 一键安装脚本

```bash
#!/bin/bash

echo "=== 安装 RISC-V 开发环境 ==="

# 1. 更新系统
sudo apt update

# 2. 安装 Verilog 仿真器
sudo apt install -y iverilog gtkwave

# 3. 创建安装目录
mkdir -p ~/opt/riscv

# 4. 下载并安装 RISC-V 工具链
cd ~/opt/riscv
wget -q https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v13.2.0-2/xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz
tar -xzf xpack-riscv-none-elf-gcc-13.2.0-2-linux-x64.tar.gz

# 5. 配置环境变量
echo 'export RISCV_ROOT="$HOME/opt/riscv/xpack-riscv-none-elf-gcc-13.2.0-2"' >> ~/.bashrc
echo 'export PATH="$RISCV_ROOT/bin:$PATH"' >> ~/.bashrc

# 6. 验证安装
source ~/.bashrc
echo ""
echo "=== 验证安装 ==="
iverilog -v | head -1
riscv64-unknown-elf-gcc --version | head -1

echo ""
echo "=== 安装完成 ==="
echo "请执行 'source ~/.bashrc' 或重新打开终端"
```

保存为 `install_env.sh` 并执行：

```bash
chmod +x install_env.sh
./install_env.sh
```

---

## 附录：环境变量配置详解

### 临时设置（当前终端有效）

```bash
export RISCV_ROOT="$HOME/opt/riscv/xpack-riscv-none-elf-gcc-13.2.0-2"
export PATH="$RISCV_ROOT/bin:$PATH"
```

### 永久设置

```bash
# 编辑配置文件
vim ~/.bashrc

# 添加以下内容
export RISCV_ROOT="$HOME/opt/riscv/xpack-riscv-none-elf-gcc-13.2.0-2"
export PATH="$RISCV_ROOT/bin:$PATH"

# 使配置生效
source ~/.bashrc
```

### 多工具链切换（可选）

```bash
# 默认工具链
export RISCV=/opt/riscv

# 切换到其他版本
export RISCV=/opt/riscv-new
source ~/.bashrc
```

---

## 参考链接

- Ubuntu 官网：https://ubuntu.com/
- Icarus Verilog：http://iverilog.icarus.com/
- GTKWave：http://gtkwave.sourceforge.net/
- XPack RISC-V GCC：https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
- RISC-V 官方工具链：https://github.com/riscv-collab/riscv-gnu-toolchain
- RISC-V 官方文档：https://riscv.org/software-tools/

---

*文档版本：2.0（Ubuntu/Debian）*
*最后更新：2026-04-09*
