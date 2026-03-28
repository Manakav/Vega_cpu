#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

run_tb() {
    local name="$1"
    shift
    echo "=== ${name} ==="
    iverilog -g2012 -o "/tmp/${name}.out" "$@"
    vvp "/tmp/${name}.out"
}

run_tb tb_alu test/modules/tb_alu.v src/cpu/core/ex_stage/alu.v
run_tb tb_mul_div test/modules/tb_mul_div.v src/cpu/core/ex_stage/mul_div.v
run_tb tb_register_file test/modules/tb_register_file.v src/cpu/core/id_stage/register_file.v
run_tb tb_decoder test/modules/tb_decoder.v src/cpu/core/id_stage/decoder.v
run_tb tb_hazard_unit test/modules/tb_hazard_unit.v src/cpu/core/hazard_unit.v
run_tb tb_bht test/modules/tb_bht.v src/cpu/core/if_stage/bht.v
run_tb tb_btb test/modules/tb_btb.v src/cpu/core/if_stage/btb.v
run_tb tb_icache test/modules/tb_icache.v src/cpu/core/if_stage/icache.v
run_tb tb_dcache test/modules/tb_dcache.v src/cpu/core/mem_stage/dcache.v
run_tb tb_if_stage test/modules/tb_if_stage.v src/cpu/core/if_stage/if_stage.v src/cpu/core/if_stage/btb.v src/cpu/core/if_stage/bht.v
run_tb tb_id_stage test/modules/tb_id_stage.v src/cpu/core/id_stage/id_stage.v src/cpu/core/id_stage/decoder.v
run_tb tb_ex_stage test/modules/tb_ex_stage.v src/cpu/core/ex_stage/ex_stage.v src/cpu/core/ex_stage/alu.v
run_tb tb_mem_stage test/modules/tb_mem_stage.v src/cpu/core/mem_stage/mem_stage.v
run_tb tb_csr_unit test/modules/tb_csr_unit.v src/cpu/core/csr/csr_unit.v

echo "All module testbenches finished."
