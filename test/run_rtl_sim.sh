#!/bin/bash

# ============================================================================
# Vega CPU 6 级双发射 RTL 仿真脚本
# ============================================================================

set -e

WORKSPACE="/home/liyu/cpuP/Vega_cpu"
BUILD_DIR="$WORKSPACE/build_sim"
SIM_EXE="$BUILD_DIR/vega_sim"

echo "=========================================="
echo "Vega CPU RTL 仿真"
echo "=========================================="

# 创建构建目录
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[1/3] 语法检查和编译..."
iverilog -g2001 -Wall \
    "$WORKSPACE/src/cpu/riscv_cpu.v" \
    "$WORKSPACE/src/cpu/core/if_stage/if_stage.v" \
    "$WORKSPACE/src/cpu/core/if_stage/btb.v" \
    "$WORKSPACE/src/cpu/core/if_stage/bht.v" \
    "$WORKSPACE/src/cpu/core/if_stage/icache.v" \
    "$WORKSPACE/src/cpu/core/id_stage/id_stage.v" \
    "$WORKSPACE/src/cpu/core/id_stage/decoder.v" \
    "$WORKSPACE/src/cpu/core/id_stage/register_file.v" \
    "$WORKSPACE/src/cpu/core/ii_stage/ii_stage.v" \
    "$WORKSPACE/src/cpu/core/ex_stage/ex_stage.v" \
    "$WORKSPACE/src/cpu/core/ex_stage/alu.v" \
    "$WORKSPACE/src/cpu/core/ex_stage/mul_div.v" \
    "$WORKSPACE/src/cpu/core/mem_stage/mem_stage.v" \
    "$WORKSPACE/src/cpu/core/mem_stage/dcache.v" \
    "$WORKSPACE/src/cpu/core/csr/csr_unit.v" \
    "$WORKSPACE/src/cpu/core/hazard_unit.v" \
    "$WORKSPACE/test/riscv_cpu_tb_dual.v" \
    -o "$SIM_EXE"

if [ $? -ne 0 ]; then
    echo "✗ 编译失败"
    exit 1
fi
echo "✓ 编译完成"
vvp "$SIM_EXE" -n

echo ""
echo "=========================================="
echo "仿真完成"
echo "=========================================="
