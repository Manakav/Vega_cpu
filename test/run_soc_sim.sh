#!/usr/bin/env bash
set -euo pipefail

# SoC 级 smoke 仿真：编译最小 SoC 路径并运行 testbench
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build_sim"
SIM_EXE="$BUILD_DIR/vega_soc_sim"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 仅包含当前 SoC bring-up 所需 RTL，避免引入无关文件
iverilog -g2012 -Wall \
    "$ROOT_DIR/src/cpu/riscv_cpu.v" \
    "$ROOT_DIR/src/cpu/core/if_stage/if_stage.v" \
    "$ROOT_DIR/src/cpu/core/if_stage/btb.v" \
    "$ROOT_DIR/src/cpu/core/if_stage/bht.v" \
    "$ROOT_DIR/src/cpu/core/id_stage/id_stage.v" \
    "$ROOT_DIR/src/cpu/core/id_stage/decoder.v" \
    "$ROOT_DIR/src/cpu/core/id_stage/register_file.v" \
    "$ROOT_DIR/src/cpu/core/ii_stage/ii_stage.v" \
    "$ROOT_DIR/src/cpu/core/ex_stage/ex_stage.v" \
    "$ROOT_DIR/src/cpu/core/ex_stage/alu.v" \
    "$ROOT_DIR/src/cpu/core/ex_stage/mul_div.v" \
    "$ROOT_DIR/src/cpu/core/mem_stage/mem_stage.v" \
    "$ROOT_DIR/src/cpu/core/csr/csr_unit.v" \
    "$ROOT_DIR/src/cpu/core/hazard_unit.v" \
    "$ROOT_DIR/src/soc/reset/reset_sync.v" \
    "$ROOT_DIR/src/soc/memory/boot_rom.v" \
    "$ROOT_DIR/src/soc/memory/data_ram.v" \
    "$ROOT_DIR/src/soc/peripherals/uart_lite.v" \
    "$ROOT_DIR/src/soc/vega_soc_top.v" \
    "$ROOT_DIR/test/soc/tb_vega_soc_top.v" \
    -o "$SIM_EXE"

# -n: 关闭交互模式，脚本化执行
vvp "$SIM_EXE" -n
