# Vega SoC Software Development Kit

## 目录结构

```
SDK/
├── Makefile                 # 构建系统
├── linker.ld                # 链接脚本（boot ROM + data RAM）
├── crt0.S                   # 启动代码（清零→搬运.data→清零.bss→main）
│
├── include/                 # 头文件
│   ├── soc.h                # 内存映射和外设基地址
│   └── csr.h                # CSR 寄存器地址 + 内联汇编封装
│
├── drivers/                 # 外设驱动
│   ├── uart.h               # UART 寄存器定义
│   └── uart.c               # 轮询收发、hex/decimal 打印
│
├── examples/                # 示例程序
│   ├── hello.c              # Vega logo + mcycle/mtime 测试
│   └── core_portme_vega.h   # Coremark 移植配置头文件
│
└── scripts/                 # 辅助脚本
    └── README.md            # COE 转换和 bitstream 生成说明
```

## 硬件平台

| 参数 | 值 |
|------|-----|
| CPU 架构 | RV64IMC, 7级流水线, 双发射 |
| 工作时钟 | 100 MHz |
| boot ROM | 16KB @ 0x1000（FPGA BRAM，含 COE 初始化文件） |
| data RAM | 64KB @ 0x80000000（FPGA BRAM，可读写） |
| UART | AXI UART Lite @ 0x60100000, 9600 baud, 8N1 |
| 指示灯 | 4x LED，映射 data_addr[5:2] |

### 内存映射

| 区域 | 基地址 | 大小 | 权限 |
|------|--------|------|------|
| Boot ROM | `0x1000` | 16KB | 只读（CPU 启动入口） |
| Data RAM | `0x80000000` | 64KB | 读写（代码/数据/堆栈） |
| UART | `0x60100000` | 4KB | 读写 |

---

## 环境要求

### 1. RISC-V 工具链

```bash
# Ubuntu/Debian
sudo apt-get install gcc-riscv64-unknown-elf

# macOS (Homebrew)
brew install riscv64-unknown-elf-gcc

# 或从源码编译
git clone https://github.com/riscv-collab/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv64imc --with-abi=lp64
make -j$(nproc)
export PATH=/opt/riscv/bin:$PATH
```

### 2. Vivado（用于更新 bitstream）

Vivado 2025.2，含 Artix-7 xc7a200tfbg676-3 器件支持。

---

## 快速开始

### 编译 Hello World

```bash
cd SDK
make hello
```

成功后在 `build/` 中生成：

| 文件 | 说明 |
|------|------|
| `hello.elf` | ELF 可执行文件 |
| `hello.bin` | 原始二进制（从 0x1000 开始） |
| `hello.coe` | Xilinx COE 格式（用于 boot_rom IP） |
| `hello.dump` | 反汇编（需 `make dump`） |

查看各段大小：

```bash
make size
```

示例输出：

```
text    data    bss     dec     hex     filename
2784    128     256     3168    c60     build/hello.elf
```

检查 `.text + .data` 是否 ≤ 16KB。

### 编译 Coremark

```bash
make coremark
```

若提示 `coremark sources not found`，先克隆 Coremark：

```bash
cd ..
git clone https://github.com/eembc/coremark riscv-coremark
cd riscv-coremark
# 将 SDK/examples/core_portme_vega.h 重命名为 core_portme.h
cp ../SDK/examples/core_portme_vega.h core_portme.h
# 同时需要 core_portme.c 和 crt.S：
# 从裸机示例 riscv64-baremetal/ 获取，或在 SDK 中实现
cd ../SDK
make coremark
```

### 生成自定义 COE

```bash
# 从任意 .elf 生成 COE
make coe ELF=myprogram.elf
```

或手动：

```bash
hexdump -v -e '/4 "0x%08X\n"' build/hello.bin | \
    sed '1i memory_initialization_radix=16;\nmemory_initialization_vector=' > build/hello.coe
```

---

## 更新 FPGA Bitstream

### 方法一：替换 COE + 重运行综合

```bash
# 1. 用生成的 COE 替换启动文件
cp build/hello.coe test/workbench/soft/start_inst.coe
```

然后打开 Vivado 或在 Tcl Console 中运行：

```tcl
# 2. 重新生成 boot_rom IP
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 3. 布局布线
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 4. 生成 bitstream
write_bitstream -force Project/Vega/Vega.runs/impl_1/vega_soc_top.bit
# 同时生成 .bin（某些烧录工具需要）
write_cfgmem -force -format BIN -size 128 -interface SMAPx32 \
    -loadbit "up 0x0 Project/Vega/Vega.runs/impl_1/vega_soc_top.bit" \
    Project/Vega/Vega.runs/impl_1/vega_soc_top.bin
```

### 方法二：直接使用 `update_mem`（需要 IP 已生成）

```tcl
# 仅更新 BRAM 内容，不需重新综合布局布线
update_mem -meminfo Project/Vega/Vega.runs/impl_1/vega_soc_top.mmi \
    -data build/hello.bin \
    -bit Project/Vega/Vega.runs/impl_1/vega_soc_top.bit \
    -proc boot_rom_ip \
    -out update.bit
```

此方法更快（几分钟 vs 综合+布局布线数十分钟），但要求已有完整的 `.mmi` 和 `.bit` 文件。

---

## 上板运行

### 硬件连接

| 信号 | FPGA 引脚（xc7a200t-fbg676） | 连接 |
|------|------------------------------|------|
| `clk_in` | AC19 | 100MHz 有源晶振 |
| `rst_n_in` | Y3 | 按键（低有效复位） |
| `uart_tx_o` | H19 | USB-UART RXD |
| `uart_rx_i` | F23 | USB-UART TXD |
| `led_o[3:0]` | A3, D5, A5, H7 | 4x LED |

### 串口配置

| 参数 | 值 |
|------|-----|
| 波特率 | 9600 |
| 数据位 | 8 |
| 校验位 | 无 |
| 停止位 | 1 |

### 操作步骤

```bash
# 1. 打开串口终端
screen /dev/ttyUSB0 9600

# 2. 下载 bitstream（Vivado Hardware Manager）
#    或使用 openFPGALoader / openocd
openFPGALoader -b nexys_video build/update.bit

# 3. 观察输出
#    成功时将看到 Vega logo ASCII art + mcycle 计数值
```

---

## 软件编程指南

### 启动流程

```
上电 → CPU 从 0x1000 处开始执行 crt0.S
  ↓
清零全部通用寄存器 (x1..x31)
  ↓
设置 gp = __global_pointer$ (.sdata 区域中点)
  ↓
设置 sp = 0x8000FF00（64KB RAM 顶）
  ↓
搬运 .data 段初始值从 ROM → RAM
  ↓
清零 .bss / .sbss 段
  ↓
li a0, 0; li a1, 0; jal main   (argc=0, argv=NULL)
  ↓
main() 执行完毕后死循环
```

### 使用 UART 输出

```c
#include "soc.h"
#include "uart.h"

int main(void) {
    uart_init();
    uart_puts("Hello Vega!\r\n");
    uart_putdec(123456);       // 输出 "123456"
    uart_puthex(0xDEAD);       // 输出 "0x000000000000DEAD"
    uart_flush();
    return 0;
}
```

### 读取性能计数器

```c
#include <stdint.h>
#include "csr.h"

uint64_t start = csr_read(CSR_MCYCLE);
do_something();
uint64_t elapsed = csr_read(CSR_MCYCLE) - start;
// elapsed = 所用时钟周期数
```

### 配置 mtime 定时器

```c
// mtime 每时钟周期自增
// mtimecmp 匹配时触发时钟中断
csr_write(CSR_MTIMECMP, csr_read(CSR_MTIME) + 100000000);
// 100MHz 下约 1 秒后触发中断
```

---

## 注意事项

1. **Boot ROM 大小限制**：16KB。如果程序超出，需：
   - 使用 `-Os` 编译优化
   - 将初始化数据改为运行时计算（放在 .bss）
   - 将常量字符串放入 `.rodata`（不是 `.data`）
   - 减少不必要的包含头文件和库函数

2. **Data RAM 大小限制**：64KB。栈、堆、数据统共享此空间。

3. **UART 9600 baud**：发送 1 字节约 1ms。大量输出时注意对性能测试的影响。

4. **无 MMU**：物理地址直接映射，不支持虚拟内存。

5. **无 JTAG 调试**：仅能通过 UART 输出观察程序运行。

---

## 常见问题

### Q: riscv64-unknown-elf-gcc 找不到
```bash
sudo apt-get install gcc-riscv64-unknown-elf
```

### Q: 编译后 .text + .rodata 超过 16KB
```bash
# 查看各段占用
riscv64-unknown-elf-size -A build/hello.elf
# 检查 .text 大小
riscv64-unknown-elf-objdump -h build/hello.elf | grep text
```
若超限，考虑移除不必要功能或使用 `-Os`。

### Q: 如何确认代码在 boot ROM 中的实际地址
运行 `make size` 查看 `text` 段起始地址是否为 `0x1000`。

### Q: 上板后无 UART 输出
- 检查串口配置（9600, 8N1）
- 检查 boot ROM 是否已用更新后的 COE 重新生成
- 检查引脚连接是否正确
- 检查复位按键是否正常释放
