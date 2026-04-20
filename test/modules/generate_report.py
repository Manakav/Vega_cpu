#!/usr/bin/env python3
"""
Vega CPU Test Report Generator
Usage: python generate_report.py [--log-dir path] [--output format]
"""

import os
import sys
import re
import json
from datetime import datetime
from pathlib import Path

DEFAULT_LOG_DIR = os.path.join(os.path.dirname(__file__), '..', 'test_results')

ALL_TESTS = [
    'tb_alu', 'tb_register_file', 'tb_hazard_unit', 'tb_decoder',
    'tb_btb', 'tb_bht', 'tb_mul_div', 'tb_csr_unit',
    'tb_icache', 'tb_dcache', 'tb_ex_stage', 'tb_id_stage',
    'tb_if_stage', 'tb_mem_stage', 'tb_ii_stage', 'tb_forwarding',
    'tb_m_extension', 'tb_csr_exception', 'tb_branch_predict',
    'tb_dual_issue_integration'
]

COVERAGE_MAP = {
    'tb_alu': ('ALU', 'Arithmetic/Logic ops, flags, SLT/SLTU'),
    'tb_register_file': ('Register File', '4R/2W, bypass, x0 hardwired'),
    'tb_hazard_unit': ('Hazard Unit', 'Load-Use, stall, flush, dual-issue conflicts'),
    'tb_decoder': ('Decoder', 'R/I/S/B/U/J-type decode, M/CSRI extensions'),
    'tb_btb': ('BTB', 'Branch target buffer hit/miss/update'),
    'tb_bht': ('BHT', '2-bit saturating counter, BHR/GHR'),
    'tb_mul_div': ('MUL/DIV', 'MUL/DIV/REM all variants, latency'),
    'tb_csr_unit': ('CSR Unit', 'CSRRW/CSRRS/CSRRC, mstatus/mepc/mcause'),
    'tb_icache': ('ICache', '2-way set-assoc hit/miss/refill'),
    'tb_dcache': ('DCache', '2-way set-assoc load/store hit/miss/writeback'),
    'tb_ex_stage': ('EX Stage', 'Dual ALU Way1/Way2, branch mispredict'),
    'tb_id_stage': ('ID Stage', 'Dual decode, immediate gen, hazard detect'),
    'tb_if_stage': ('IF Stage', 'PC init, dual-fetch, mispredict redirect, flush/stall'),
    'tb_mem_stage': ('MEM Stage', 'Load/store size, byte-enable, DCache integration'),
    'tb_ii_stage': ('II Stage', 'Dual-issue arbitration, RAW/WAW/struct/ctrl/sys hazards'),
    'tb_forwarding': ('Forwarding', '4-way forwarding priority, EX/MEM vs MEM/WB'),
    'tb_m_extension': ('M Extension', 'MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU, Way2 MUL'),
    'tb_csr_exception': ('CSR+Exception', 'Read/write CSR, timer interrupt, mstatus/mepc/mcause'),
    'tb_branch_predict': ('BTB+BHT', 'Train/hit/miss, saturating counter, reset flush, 4-way alias'),
    'tb_dual_issue_integration': ('II+EX+RF', 'End-to-end dual-issue, RAW/WAW stall, flush, load-use'),
}


def parse_result_log(log_path):
    result = {
        'status': 'UNKNOWN',
        'errors': 0,
        'fail_messages': [],
        'pass_messages': [],
        'info_messages': [],
    }
    if not os.path.exists(log_path):
        result['status'] = 'MISSING'
        return result

    with open(log_path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if '[PASS]' in line:
            result['pass_messages'].append(line)
            result['status'] = 'PASS'
        elif '[FAIL]' in line:
            result['fail_messages'].append(line)
            result['status'] = 'FAIL'
            m = re.search(r'errors=(\d+)', line)
            if m:
                result['errors'] = int(m.group(1))
        elif '[INFO]' in line:
            result['info_messages'].append(line)

    if result['status'] == 'UNKNOWN' and result['fail_messages']:
        result['status'] = 'FAIL'

    return result


def parse_compile_log(log_path):
    result = {
        'status': 'OK',
        'warnings': 0,
        'errors': 0,
    }
    if not os.path.exists(log_path):
        result['status'] = 'MISSING'
        return result

    with open(log_path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if 'warning' in line.lower():
            result['warnings'] += 1
        elif 'error' in line.lower():
            result['errors'] += 1

    if result['errors'] > 0:
        result['status'] = 'ERROR'

    return result


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Vega CPU Test Report Generator')
    parser.add_argument('--log-dir', default=DEFAULT_LOG_DIR, help='Path to test results directory')
    parser.add_argument('--output', default='md', choices=['md', 'json'], help='Output format')
    parser.add_argument('--output-file', default=None, help='Output file path')
    args = parser.parse_args()

    log_dir = Path(args.log_dir).resolve()
    if not log_dir.exists():
        print(f"Error: Log directory {log_dir} does not exist.")
        sys.exit(1)

    results = []
    for name in ALL_TESTS:
        compile_log = log_dir / f'{name}_compile.log'
        result_log = log_dir / f'{name}_result.log'
        if not result_log.exists():
            result_log = log_dir / f'{name}.log'

        c = parse_compile_log(str(compile_log))
        r = parse_result_log(str(result_log))

        results.append({
            'name': name,
            'compile_status': c['status'],
            'compile_warnings': c['warnings'],
            'compile_errors': c['errors'],
            'test_status': r['status'],
            'error_count': r['errors'],
            'fail_messages': r['fail_messages'],
            'pass_messages': r['pass_messages'],
            'info_messages': r['info_messages'],
        })

    total = len(results)
    passed = sum(1 for r in results if r['test_status'] == 'PASS')
    failed = sum(1 for r in results if r['test_status'] == 'FAIL')

    if args.output == 'json':
        output_file = args.output_file or str(log_dir / 'report.json')
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump({'timestamp': datetime.now().isoformat(), 'results': results}, f, indent=2)
        print(f"JSON report written to: {output_file}")
    else:
        output_file = args.output_file or str(log_dir / 'VERIFICATION_REPORT.md')
        lines = [
            f'# Vega CPU Verification Report',
            f'',
            f'**Generated**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}',
            f'',
            f'## Summary',
            f'',
            f'| Metric | Value |',
            f'|--------|-------|',
            f'| Total Tests | {total} |',
            f'| Passed | {passed} |',
            f'| Failed | {failed} |',
            f'| Pass Rate | {passed/total*100:.1f}% |',
            f'',
            f'## Test Details',
            f'',
            f'| # | Test | Compile | Runtime | Errors | Notes |',
            f'|---|------|---------|----------|--------|-------|',
        ]

        for i, r in enumerate(results, 1):
            cs = r.get('compile_status', 'N/A')
            ts = r.get('test_status', 'N/A')
            errs = r.get('error_count', 0)
            notes = ''
            if r.get('info_messages'):
                notes = '; '.join(r['info_messages'][:2])
            if ts == 'FAIL' and r.get('fail_messages'):
                notes = r['fail_messages'][0][:60]
            lines.append(f'| {i} | {r["name"]} | {cs} | {ts} | {errs} | {notes} |')

        lines.extend([
            '',
            '## Coverage Matrix',
            '',
            '| Test | Target Module | Coverage Area |',
            '|------|---------------|--------------|',
        ])
        for name in ALL_TESTS:
            if name in COVERAGE_MAP:
                mod, cov = COVERAGE_MAP[name]
                lines.append(f'| {name} | {mod} | {cov} |')

        lines.extend([
            '',
            '## Recommendations',
            '',
            '1. Add riscv-tests for ISA compliance verification',
            '2. Add CoreMark/Dhrystone for DMIPS/MHz and IPC measurement',
            '3. Add FPGA synthesis for resource utilization and timing',
            '4. For IP-replaced modules, use ip_wrappers with `define USE_IP_<MODULE>',
            '',
        ])

        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        print(f"Markdown report written to: {output_file}")

    print(f"\nSummary: {passed}/{total} tests passed ({passed/total*100:.1f}%)" if total > 0 else "No tests found")
    return 0 if passed == total else 1


if __name__ == '__main__':
    sys.exit(main())