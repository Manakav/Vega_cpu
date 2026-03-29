`timescale 1ns / 1ps

// Hazard 单元测试：前递优先级、load-use 停顿、误预测冲刷
module tb_hazard_unit;
// 输入激励
reg clk;
reg rst_n;
reg [4:0] rs1_addr_id;
reg [4:0] rs2_addr_id;
reg rs1_used_id;
reg rs2_used_id;
reg [4:0] rd_addr_ex;
reg [4:0] rd_addr_mem;
reg [4:0] rd_addr_wb;
reg reg_write_en_ex;
reg reg_write_en_mem;
reg reg_write_en_wb;
reg mem_read_en_ex;
reg branch_taken_ex;
reg mispredict_ex;
wire stall_if;
wire stall_id;
wire flush_if;
wire flush_id;
wire flush_ex;
wire [1:0] forward_a;
wire [1:0] forward_b;
integer errors;

hazard_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr_id(rs1_addr_id),
    .rs2_addr_id(rs2_addr_id),
    .rs1_used_id(rs1_used_id),
    .rs2_used_id(rs2_used_id),
    .rd_addr_ex(rd_addr_ex),
    .rd_addr_mem(rd_addr_mem),
    .rd_addr_wb(rd_addr_wb),
    .reg_write_en_ex(reg_write_en_ex),
    .reg_write_en_mem(reg_write_en_mem),
    .reg_write_en_wb(reg_write_en_wb),
    .mem_read_en_ex(mem_read_en_ex),
    .branch_taken_ex(branch_taken_ex),
    .mispredict_ex(mispredict_ex),
    .stall_if(stall_if),
    .stall_id(stall_id),
    .flush_if(flush_if),
    .flush_id(flush_id),
    .flush_ex(flush_ex),
    .forward_a(forward_a),
    .forward_b(forward_b)
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

    // 检查前递优先级（本例 rs1 取 MEM，rs2 取 WB）
    rs1_addr_id = 5'd1; rs2_addr_id = 5'd2;
    rs1_used_id = 1; rs2_used_id = 1;
    rd_addr_ex = 5'd3; rd_addr_mem = 5'd1; rd_addr_wb = 5'd2;
    reg_write_en_ex = 1; reg_write_en_mem = 1; reg_write_en_wb = 1;
    mem_read_en_ex = 0; branch_taken_ex = 0; mispredict_ex = 0;
    #1;
    check(forward_a == 2'b10, "forward_a from MEM failed");
    check(forward_b == 2'b11, "forward_b from WB failed");

    // 检查 load-use 停顿
    rd_addr_ex = 5'd1;
    mem_read_en_ex = 1;
    #1;
    check(stall_if == 1'b1 && stall_id == 1'b1, "load-use stall failed");

    // 检查 mispredict 冲刷
    mem_read_en_ex = 0;
    mispredict_ex = 1;
    #1;
    check(flush_if && flush_id && flush_ex, "mispredict flush failed");

    if (errors == 0) $display("[PASS] tb_hazard_unit");
    else $display("[FAIL] tb_hazard_unit errors=%0d", errors);
    $finish;
end

endmodule
