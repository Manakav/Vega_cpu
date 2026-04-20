@echo off
REM ============================================================================
REM Vega CPU 统一回归测试脚本 (Windows)
REM 用法：run_all_tests.bat [--iverilog path] [--clean]
REM ============================================================================

setlocal enabledelayedexpansion

set IVERILOG=iverilog
set VVP=vvp
set SRC_DIR=..\src\cpu\core
set TB_DIR=modules
set LOG_DIR=..\test_results
set PASS=0
set FAIL=0
set TOTAL=0

REM Parse arguments
:parse_args
if "%1"=="" goto end_parse
if "%1"=="--iverilog" (
    set IVERILOG=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--clean" (
    if exist %LOG_DIR% rmdir /s /q %LOG_DIR%
    shift
    goto parse_args
)
shift
goto parse_args
:end_parse

if not exist %LOG_DIR% mkdir %LOG_DIR%

echo ============================================================
echo  Vega CPU Regression Test Suite
echo  Date: %date% %time%
echo  iverilog: %IVERILOG%
echo ============================================================
echo.

REM ============================================================================
REM Module Unit Tests
REM ============================================================================

echo [1/8] ALU Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_alu.vvp %SRC_DIR%\ex_stage\alu.v %TB_DIR%\tb_alu.v 2> %LOG_DIR%\tb_alu_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_alu.vvp > %LOG_DIR%\tb_alu_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_alu_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_alu
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [2/8] Register File Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_register_file.vvp %SRC_DIR%\id_stage\register_file.v %TB_DIR%\tb_register_file.v 2> %LOG_DIR%\tb_register_file_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_register_file.vvp > %LOG_DIR%\tb_register_file_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_register_file_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_register_file
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [3/8] Hazard Unit Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_hazard_unit.vvp %SRC_DIR%\hazard_unit.v %TB_DIR%\tb_hazard_unit.v 2> %LOG_DIR%\tb_hazard_unit_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_hazard_unit.vvp > %LOG_DIR%\tb_hazard_unit_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_hazard_unit_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_hazard_unit
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [4/8] II Stage (Dual-Issue Arbitration) Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_ii_stage.vvp %SRC_DIR%\id_stage\register_file.v %SRC_DIR%\ii_stage\ii_stage.v %TB_DIR%\tb_ii_stage.v 2> %LOG_DIR%\tb_ii_stage_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_ii_stage.vvp > %LOG_DIR%\tb_ii_stage_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_ii_stage_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_ii_stage
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [5/8] EX Stage (Forwarding) Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_forwarding.vvp %SRC_DIR%\ex_stage\alu.v %SRC_DIR%\ex_stage\ex_stage.v %TB_DIR%\tb_forwarding.v 2> %LOG_DIR%\tb_forwarding_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_forwarding.vvp > %LOG_DIR%\tb_forwarding_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_forwarding_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_forwarding
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [6/8] M Extension Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_m_extension.vvp %SRC_DIR%\ex_stage\alu.v %SRC_DIR%\ex_stage\ex_stage.v %TB_DIR%\tb_m_extension.v 2> %LOG_DIR%\tb_m_extension_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_m_extension.vvp > %LOG_DIR%\tb_m_extension_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_m_extension_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_m_extension
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [7/8] CSR / Exception Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_csr_exception.vvp %SRC_DIR%\csr\csr_unit.v %TB_DIR%\tb_csr_exception.v 2> %LOG_DIR%\tb_csr_exception_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_csr_exception.vvp > %LOG_DIR%\tb_csr_exception_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_csr_exception_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_csr_exception
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo [8/8] Branch Prediction (BTB+BHT) Test...
%IVERILOG% -g2001 -o %LOG_DIR%\tb_branch_predict.vvp %SRC_DIR%\if_stage\btb.v %SRC_DIR%\if_stage\bht.v %TB_DIR%\tb_branch_predict.v 2> %LOG_DIR%\tb_branch_predict_compile.log
if errorlevel 1 (
    echo   [FAIL] Compilation error
    set /a FAIL+=1
) else (
    %VVP% %LOG_DIR%\tb_branch_predict.vvp > %LOG_DIR%\tb_branch_predict_result.log 2>&1
    findstr /C:"[PASS]" %LOG_DIR%\tb_branch_predict_result.log >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Test failed
        set /a FAIL+=1
    ) else (
        echo   [PASS] tb_branch_predict
        set /a PASS+=1
    )
)
set /a TOTAL+=1

echo.
echo ============================================================
echo  Regression Test Summary
echo ============================================================
echo  Total:  %TOTAL%
echo  Passed: %PASS%
echo  Failed: %FAIL%
echo  Rate:   ??? TBD (no arithmetic in batch easily)
echo ============================================================
echo.
echo Full logs in: %LOG_DIR%\
echo.

if %FAIL%==0 (
    echo ALL TESTS PASSED
) else (
    echo SOME TESTS FAILED - check logs for details
)

endlocal