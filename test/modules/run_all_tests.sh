#!/bin/bash
# ============================================================================
# Vega CPU 统一回归测试脚本 (Linux/macOS/Git Bash)
# 用法：bash run_all_tests.sh [--iverilog path] [--clean]
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../../src/cpu/core"
TB_DIR="$SCRIPT_DIR"
LOG_DIR="$SCRIPT_DIR/../test_results"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
PASS=0
FAIL=0
TOTAL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --iverilog) IVERILOG="$2"; shift 2 ;;
        --vvp) VVP="$2"; shift 2 ;;
        --clean) rm -rf "$LOG_DIR"; shift ;;
        -h|--help)
            echo "Usage: $0 [--iverilog path] [--vvp path] [--clean]"
            exit 0 ;;
        *) shift ;;
    esac
done

mkdir -p "$LOG_DIR"

# Source files for each test
declare -A TEST_DEPS
TEST_DEPS[tb_alu]="$SRC_DIR/ex_stage/alu.v"
TEST_DEPS[tb_register_file]="$SRC_DIR/id_stage/register_file.v"
TEST_DEPS[tb_hazard_unit]="$SRC_DIR/hazard_unit.v"
TEST_DEPS[tb_ii_stage]="$SRC_DIR/id_stage/register_file.v $SRC_DIR/ii_stage/ii_stage.v"
TEST_DEPS[tb_forwarding]="$SRC_DIR/ex_stage/alu.v $SRC_DIR/ex_stage/ex_stage.v"
TEST_DEPS[tb_m_extension]="$SRC_DIR/ex_stage/alu.v $SRC_DIR/ex_stage/ex_stage.v"
TEST_DEPS[tb_csr_exception]="$SRC_DIR/csr/csr_unit.v"
TEST_DEPS[tb_branch_predict]="$SRC_DIR/if_stage/btb.v $SRC_DIR/if_stage/bht.v"
TEST_DEPS[tb_ex_stage]="$SRC_DIR/ex_stage/alu.v $SRC_DIR/ex_stage/ex_stage.v"
TEST_DEPS[tb_dual_issue_integration]="$SRC_DIR/id_stage/register_file.v $SRC_DIR/ii_stage/ii_stage.v $SRC_DIR/ex_stage/alu.v $SRC_DIR/ex_stage/ex_stage.v"

TEST_ORDER=(tb_alu tb_register_file tb_hazard_unit tb_ii_stage tb_forwarding tb_m_extension tb_csr_exception tb_branch_predict tb_ex_stage tb_dual_issue_integration)

echo "============================================================"
echo " Vega CPU Regression Test Suite"
echo " Date: $(date)"
echo " iverilog: $IVERILOG"
echo " vvp: $VVP"
echo "============================================================"
echo ""

for test in "${TEST_ORDER[@]}"; do
    TOTAL=$((TOTAL + 1))
    deps="${TEST_DEPS[$test]}"
    tb_file="$TB_DIR/${test}.v"
    vvp_file="$LOG_DIR/${test}.vvp"
    compile_log="$LOG_DIR/${test}_compile.log"
    result_log="$LOG_DIR/${test}_result.log"

    echo -n "[$TOTAL/${#TEST_ORDER[@]}] $test ... "

    # Compile
    if ! $IVERILOG -g2001 -Wall -o "$vvp_file" $deps "$tb_file" > "$compile_log" 2>&1; then
        echo "[FAIL] Compilation error"
        FAIL=$((FAIL + 1))
        continue
    fi

    # Run
    if ! $VVP "$vvp_file" > "$result_log" 2>&1; then
        echo "[FAIL] Runtime error"
        FAIL=$((FAIL + 1))
        continue
    fi

    # Check result
    if grep -q "\[PASS\]" "$result_log"; then
        echo "[PASS]"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Assertion failed"
        FAIL=$((FAIL + 1))
        # Show first few FAIL lines
        grep "\[FAIL\]" "$result_log" | head -5
    fi
done

RATE=$(echo "scale=1; $PASS * 100 / $TOTAL" | bc 2>/dev/null || echo "N/A")

echo ""
echo "============================================================"
echo " Regression Test Summary"
echo "============================================================"
echo " Total:  $TOTAL"
echo " Passed: $PASS"
echo " Failed: $FAIL"
echo " Rate:   ${RATE}%"
echo "============================================================"
echo ""
echo "Full logs in: $LOG_DIR/"
echo ""

# Write summary file
cat > "$LOG_DIR/REGRESSION_SUMMARY.md" <<EOF
# Vega CPU Regression Test Summary

- **Date**: $(date)
- **iverilog**: $IVERILOG
- **Total**: $TOTAL
- **Passed**: $PASS
- **Failed**: $FAIL
- **Rate**: ${RATE}%

## Test Results

| # | Test | Status |
|---|------|--------|
EOF

idx=1
for test in "${TEST_ORDER[@]}"; do
    result_log="$LOG_DIR/${test}_result.log"
    if [ -f "$result_log" ] && grep -q "\[PASS\]" "$result_log" 2>/dev/null; then
        status="PASS"
    else
        status="FAIL"
    fi
    echo "| $idx | $test | $status |" >> "$LOG_DIR/REGRESSION_SUMMARY.md"
    idx=$((idx + 1))
done

echo ""
echo "Summary written to: $LOG_DIR/REGRESSION_SUMMARY.md"

if [ "$FAIL" -eq 0 ]; then
    echo "ALL TESTS PASSED"
    exit 0
else
    echo "SOME TESTS FAILED - check logs for details"
    exit 1
fi