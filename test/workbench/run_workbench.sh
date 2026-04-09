#!/bin/bash

# ============================================================================
# Vega CPU Test Workbench 运行脚本
# 用于编译和运行从 CO-LAB-RISCV 迁移的测试工作台
# ============================================================================

set -e

WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORKSPACE/test/workbench/build_sim"

echo "=========================================="
echo "Vega CPU Test Workbench 仿真"
echo "=========================================="

# 创建构建目录
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[1/3] 构建软件组件..."
cd "$WORKSPACE/test/workbench/soft"
make clean
make
cd "$BUILD_DIR"

echo "[2/3] 编译仿真模型（使用iverilog）..."
iverilog -g2001 -Wall \
    $(find "$WORKSPACE/src" -name '*.v' -o -name '*.sv' -o -name '*.svh') \
    "$WORKSPACE/test/workbench/riscv_cpu_tb.v" \
    -o sim_vvp

echo "✓ 编译完成"

echo "[3/3] 运行仿真..."
vvp sim_vvp

echo ""
echo "=========================================="
echo "仿真完成"
echo "=========================================="