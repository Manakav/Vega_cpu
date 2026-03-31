#!/bin/bash

# ============================================================================
# Vega CPU Vivado 快速启动脚本
# ============================================================================
# 用法: bash vivado_test.sh [gui|batch|sim]
# ============================================================================

set -e

WORKSPACE="/home/liyu/cpuP/Vega_cpu"
PROJECT_DIR="$WORKSPACE/Project/Vega"
MODE="${1:-gui}"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Vega CPU 6 级双发射 Vivado 测试                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 检查 Vivado 是否安装
if ! command -v vivado &> /dev/null; then
    echo "✗ 错误：Vivado 未安装或未在 PATH 中"
    echo "  请先安装 Vivado 2025.2 或更高版本"
    exit 1
fi

VIVADO_VERSION=$(vivado -version 2>/dev/null | head -n1)
echo "✓ Vivado 版本: $VIVADO_VERSION"
echo ""

# ========== 模式 1: GUI 模式（交互式） ==========
if [ "$MODE" = "gui" ]; then
    echo "[GUI 模式] 在 Vivado GUI 中打开项目..."
    echo ""
    cd "$PROJECT_DIR"
    vivado Vega.xpr &
    
    echo "✓ Vivado 已启动"
    echo ""
    echo "📋 接下来的步骤:"
    echo "  1. 在 GUI 中打开:"
    echo "     - Analyzer → Sources"
    echo "     - 查看 'sources_1' 文件集"
    echo ""
    echo "  2. 运行仿真:"
    echo "     - Flow → Simulation → Run Behavioral Simulation"
    echo "     - 快捷键: Shift + F6"
    echo ""
    echo "  3. 查看波形:"
    echo "     - 在 Xsim 窗口中查看信号波形"
    echo "     - 追踪: clk, rst_n, instr_addr, instr_data_w1/w2"
    echo ""
    echo "  4. 运行综合:"
    echo "     - Flow → Synthesis → Run Synthesis"
    echo ""
    echo "  5. 运行实现:"
    echo "     - Flow → Implementation → Run Implementation"
    echo ""
    
    # 等待用户退出
    wait 2>/dev/null || true

# ========== 模式 2: 命令行批处理模式 ==========
elif [ "$MODE" = "batch" ]; then
    echo "[BATCH 模式] 运行自动化脚本..."
    echo ""
    
    if [ ! -f "$PROJECT_DIR/vivado_verify.tcl" ]; then
        echo "✗ 脚本不存在: $PROJECT_DIR/vivado_verify.tcl"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    vivado -mode batch -source vivado_verify.tcl -log /tmp/vivado_verify.log -nojournal
    
    if [ -f /tmp/vivado_verify.log ]; then
        echo ""
        echo "📋 详细日志:"
        tail -50 /tmp/vivado_verify.log
    fi

# ========== 模式 3: 仅仿真模式 ==========
elif [ "$MODE" = "sim" ]; then
    echo "[仿真模式] 运行行为仿真..."
    echo ""
    
    # 使用 Vivado 的 Xsim 直接模拟
    cd "$WORKSPACE"
    
    # 编译设计
    echo "编译 RTL 代码..."
    cd build_sim || mkdir -p build_sim && cd build_sim
    
    xvlog -sv \
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
        "$WORKSPACE/test/riscv_cpu_tb_dual.v"
    
    echo "编译 testbench..."
    xelab -debug all -top riscv_cpu_tb -snapshot vega_tb_snapshot
    
    echo "运行仿真..."
    xsim vega_tb_snapshot -runall -log /tmp/xsim.log
    
    echo "✓ 仿真完成"
    
else
    echo "✗ 未知模式: $MODE"
    echo ""
    echo "用法: bash vivado_test.sh [gui|batch|sim]"
    echo ""
    echo "模式说明:"
    echo "  gui   - 打开 Vivado GUI (默认)"
    echo "  batch - 在命令行中运行验证脚本"
    echo "  sim   - 使用 Xsim 运行仿真"
    echo ""
    exit 1
fi

echo ""
echo "✓ 完成"
echo ""
