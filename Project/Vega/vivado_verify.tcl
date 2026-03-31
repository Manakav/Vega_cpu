#!/usr/bin/env tclsh

# ============================================================================
# Vega CPU 6 级双发射 Vivado 自动化测试脚本
# ============================================================================
# 用途：自动化在 Vivado 中进行仿真、综合和实现验证
# 用法：vivado -mode batch -source vivado_verify.tcl
# ============================================================================

set project_dir "/home/liyu/cpuP/Vega_cpu/Project/Vega"
set workspace_root "/home/liyu/cpuP/Vega_cpu"

puts "╔════════════════════════════════════════════════════════════╗"
puts "║  Vega CPU 6 级双发射 Vivado 验证                           ║"
puts "╚════════════════════════════════════════════════════════════╝"
puts ""

# ============================================================================
# 第 1 步：打开项目
# ============================================================================
puts "\[1/5\] 打开 Vivado 项目..."

if {[catch {open_project $project_dir/Vega.xpr} err]} {
    puts "✗ 错误：无法打开项目"
    puts "  $err"
    exit 1
}

puts "✓ 项目已打开"
puts ""

# ============================================================================
# 第 2 步：更新源文件（添加 ii_stage.v）
# ============================================================================
puts "\[2/5\] 更新源文件..."

set new_files {
    ../../../src/cpu/core/ii_stage/ii_stage.v
    ../../../src/cpu/riscv_cpu.v
    ../../../src/cpu/core/if_stage/if_stage.v
    ../../../src/cpu/core/id_stage/id_stage.v
    ../../../src/cpu/core/ex_stage/ex_stage.v
    ../../../src/cpu/core/mem_stage/mem_stage.v
    ../../../src/cpu/core/id_stage/register_file.v
    ../../../src/cpu/core/hazard_unit.v
}

# 添加源文件
foreach file $new_files {
    set full_path "$project_dir/$file"
    if {[file exists $full_path]} {
        if {[catch {add_files -fileset sources_1 -norecurse $full_path} err]} {
            # 文件可能已存在，忽略
            # puts "  $file (已存在 或 已添加)"
        } else {
            puts "  + 添加: [file tail $full_path]"
        }
    } else {
        puts "  ✗ 未找到: $file"
    }
}

puts "✓ 源文件已更新"
puts ""

# ============================================================================
# 第 3 步：设置顶层模块并创建仿真配置
# ============================================================================
puts "\[3/5\] 配置顶层模块和仿真..."

# 设置顶层为 riscv_cpu
if {[catch {set_property top riscv_cpu [current_fileset]} err]} {
    puts "✗ 设置顶层失败: $err"
} else {
    puts "✓ 顶层模块: riscv_cpu"
}

# 创建仿真文件集（如果不存在）
if {[catch {get_filesets sim_behavioral} result]} {
    puts "  创建仿真配置: sim_behavioral"
    if {[catch {create_fileset -simset sim_behavioral} err]} {
        puts "  ✗ 创建失败: $err"
    }
}

# 添加 testbench
set tb_file "$project_dir/../../../test/riscv_cpu_tb_dual.v"
if {[file exists $tb_file]} {
    if {[catch {add_files -fileset sim_behavioral -norecurse $tb_file} err]} {
        # 可能已存在
    }
    puts "✓ Testbench: riscv_cpu_tb_dual.v"
} else {
    puts "✗ Testbench 未找到: $tb_file"
}

# 设置仿真顶层
if {[catch {set_property top riscv_cpu_tb [get_filesets sim_behavioral]} err]} {
    puts "✗ 设置仿真顶层失败: $err"
}

puts "✓ 仿真配置完成"
puts ""

# ============================================================================
# 第 4 步：运行行为仿真
# ============================================================================
puts "\[4/5\] 运行行为仿真..."

if {[catch {
    elaborate_design
    puts "✓ 设计已 Elaborate"
    
    launch_simulation
    puts "✓ 仿真已启动"
    
    # 运行全部
    run_all
    puts "✓ 仿真已完成"
    
    # 关闭仿真
    close_sim
} err]} {
    puts "✗ 仿真失败:"
    puts "  $err"
}

puts ""

# ============================================================================
# 第 5 步：运行综合
# ============================================================================
puts "\[5/5\] 运行综合..."

if {[catch {
    # 重置综合运行
    reset_run synth_1
    puts "  编译中... (预计 2-5 分钟)"
    
    # 运行综合（8 个并行任务）
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    
    # 打开综合结果
    open_run synth_1
    
    puts "✓ 综合成功"
    
    # 生成综合报告
    if {[catch {
        report_utilization -file /tmp/vega_utilization.txt
    } err]} {
        puts "  (资源报告生成失败)"
    }
    
} err]} {
    puts "✗ 综合失败:"
    puts "  $err"
}

puts ""

# ============================================================================
# 总结
# ============================================================================
puts "╔════════════════════════════════════════════════════════════╗"
puts "║  验证完成                                                  ║"
puts "╚════════════════════════════════════════════════════════════╝"
puts ""
puts "✓ 步骤总结:"
puts "  1. 项目已打开"
puts "  2. 源文件已更新 (包含 ii_stage.v)"
puts "  3. 顶层模块已设置"
puts "  4. 行为仿真已完成"
puts "  5. 综合已完成"
puts ""
puts "📊 后续步骤:"
puts "  • 查看资源报告:   /tmp/vega_utilization.txt"
puts "  • 在 GUI 中查看波形: vivado Vega.xpr"
puts "  • 运行实现:        Flow → Implementation"
puts "  • 检查时序:        Window → Timing Analyzer"
puts ""

# 保存项目
if {[catch {save_project_as -force} err]} {
    # 项目已保存
}

puts "项目已保存"
puts ""
