`timescale 1ns / 1ps

// Hazard 单元测试：前递优先级、load-use 停顿、误预测冲刷
module tb_hazard_unit;
// 输入激励
reg clk;
reg rst_n;
reg [4:0] rs1_addr_id_w1;
reg [4:0] rs2_addr_id_w1;
reg rs1_used_id_w1;
reg rs2_used_id_w1;
reg [4:0] rs1_addr_id_w2;
reg [4:0] rs2_addr_id_w2;
reg rs1_used_id_w2;
reg rs2_used_id_w2;
reg [4:0] rd_addr_ex_w1;
reg reg_write_en_ex_w1;
reg mem_read_en_ex_w1;
reg [4:0] rd_addr_ex_w2;
reg reg_write_en_ex_w2;
reg mem_read_en_ex_w2;
reg [4:0] rd_addr_mem_w1;
reg reg_write_en_mem_w1;
reg [4:0] rd_addr_mem_w2;
reg reg_write_en_mem_w2;
reg branch_taken_ex;
reg mispredict_ex;
reg stall_dual;
wire stall_if;
wire stall_id;
wire flush_if;
wire flush_id;
wire flush_ex;
integer errors;

hazard_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr_id_w1(rs1_addr_id_w1),
    .rs2_addr_id_w1(rs2_addr_id_w1),
    .rs1_used_id_w1(rs1_used_id_w1),
    .rs2_used_id_w1(rs2_used_id_w1),
    .rs1_addr_id_w2(rs1_addr_id_w2),
    .rs2_addr_id_w2(rs2_addr_id_w2),
    .rs1_used_id_w2(rs1_used_id_w2),
    .rs2_used_id_w2(rs2_used_id_w2),
    .rd_addr_ex_w1(rd_addr_ex_w1),
    .reg_write_en_ex_w1(reg_write_en_ex_w1),
    .mem_read_en_ex_w1(mem_read_en_ex_w1),
    .rd_addr_ex_w2(rd_addr_ex_w2),
    .reg_write_en_ex_w2(reg_write_en_ex_w2),
    .mem_read_en_ex_w2(mem_read_en_ex_w2),
    .rd_addr_mem_w1(rd_addr_mem_w1),
    .reg_write_en_mem_w1(reg_write_en_mem_w1),
    .rd_addr_mem_w2(rd_addr_mem_w2),
    .reg_write_en_mem_w2(reg_write_en_mem_w2),
    .branch_taken_ex(branch_taken_ex),
    .mispredict_ex(mispredict_ex),
    .stall_dual(stall_dual),
    .stall_if(stall_if),
    .stall_id(stall_id),
    .flush_if(flush_if),
    .flush_id(flush_id),
    .flush_ex(flush_ex)
);

// 时钟
always #5 clk = ~clk;

// 通用检查任务
task check;
    input cond;
    input [127:0] msg;
begin
    if (!cond) begin
        $display("[FAIL] %0s", msg);
        errors = errors + 1;
    end
end
endtask

initial begin
    clk = 0;
    rst_n = 1;
    errors = 0;

    rs1_addr_id_w1 = 0;
    rs2_addr_id_w1 = 0;
    rs1_used_id_w1 = 0;
    rs2_used_id_w1 = 0;
    rs1_addr_id_w2 = 0;
    rs2_addr_id_w2 = 0;
    rs1_used_id_w2 = 0;
    rs2_used_id_w2 = 0;
    rd_addr_ex_w1 = 0;
    reg_write_en_ex_w1 = 0;
    mem_read_en_ex_w1 = 0;
    rd_addr_ex_w2 = 0;
    reg_write_en_ex_w2 = 0;
    mem_read_en_ex_w2 = 0;
    rd_addr_mem_w1 = 0;
    reg_write_en_mem_w1 = 0;
    rd_addr_mem_w2 = 0;
    reg_write_en_mem_w2 = 0;
    branch_taken_ex = 0;
    mispredict_ex = 0;
    stall_dual = 0;

    // 检查 load-use 停顿（EX Way1 的 load 依赖 ID Way1 rs1）
    rs1_addr_id_w1 = 5'd1;
    rs1_used_id_w1 = 1'b1;
    rd_addr_ex_w1 = 5'd1;
    mem_read_en_ex_w1 = 1'b1;
    #1;
    check(stall_if == 1'b1 && stall_id == 1'b1, "load-use stall failed");

    // 释放 load-use
    mem_read_en_ex_w1 = 1'b0;

    // 检查 dual-issue 停顿请求传递
    stall_dual = 1'b1;
    #1;
    check(stall_if == 1'b1 && stall_id == 1'b1, "stall_dual stall failed");

    // 检查 mispredict 冲刷
    stall_dual = 1'b0;
    mispredict_ex = 1;
    #1;
    check(flush_if && flush_id && flush_ex, "mispredict flush failed");

    if (errors == 0) $display("[PASS] tb_hazard_unit");
    else $display("[FAIL] tb_hazard_unit errors=%0d", errors);
    $finish;
end

endmodule
