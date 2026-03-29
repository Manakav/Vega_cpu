`timescale 1ns / 1ps

// MEM 阶段测试：验证字节使能、窄写数据与 load 扩展
module tb_mem_stage;
// 输入激励
reg clk;
reg rst_n;
reg [63:0] pc_i;
reg [63:0] alu_result_i;
reg [63:0] rs2_data_i;
reg [4:0] rd_addr_i;
reg valid_i;
reg mem_read_en_i;
reg mem_write_en_i;
reg [2:0] mem_size_i;
reg reg_write_en_i;
reg [1:0] wb_sel_i;
wire [63:0] mem_addr;
wire [63:0] mem_wdata;
wire mem_we;
wire [7:0] mem_be;
reg [63:0] mem_rdata;
reg mem_gnt;
wire [63:0] alu_result_o;
wire [63:0] mem_result_o;
wire [4:0] rd_addr_o;
wire valid_o;
wire reg_write_en_o;
wire [1:0] wb_sel_o;
integer errors;

mem_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .pc_i(pc_i),
    .alu_result_i(alu_result_i),
    .rs2_data_i(rs2_data_i),
    .rd_addr_i(rd_addr_i),
    .valid_i(valid_i),
    .mem_read_en_i(mem_read_en_i),
    .mem_write_en_i(mem_write_en_i),
    .mem_size_i(mem_size_i),
    .reg_write_en_i(reg_write_en_i),
    .wb_sel_i(wb_sel_i),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_be(mem_be),
    .mem_rdata(mem_rdata),
    .mem_gnt(mem_gnt),
    .alu_result_o(alu_result_o),
    .mem_result_o(mem_result_o),
    .rd_addr_o(rd_addr_o),
    .valid_o(valid_o),
    .reg_write_en_o(reg_write_en_o),
    .wb_sel_o(wb_sel_o)
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
    // 初始化
    clk = 0;
    rst_n = 0;
    pc_i = 64'h1000;
    alu_result_i = 64'h2000;
    rs2_data_i = 64'h00000000AABBCCDD;
    rd_addr_i = 5'd3;
    valid_i = 0;
    mem_read_en_i = 0;
    mem_write_en_i = 0;
    mem_size_i = 3'b010;
    reg_write_en_i = 1;
    wb_sel_i = 2'b01;
    mem_rdata = 64'h00000000FFFFFFFF;
    mem_gnt = 0;
    errors = 0;

    #12 rst_n = 1;

    // store word: 检查 mem_be 与写数据低位对齐
    valid_i = 1;
    mem_write_en_i = 1;
    mem_read_en_i = 0;
    mem_gnt = 1;
    @(posedge clk);
    #1;
    check(mem_be == 8'b00001111, "mem_be for word store failed");
    check(mem_wdata == 64'h00000000AABBCCDD, "mem_wdata narrow store failed");

    // load byte(signed): 检查符号扩展
    mem_write_en_i = 0;
    mem_read_en_i = 1;
    mem_size_i = 3'b000; // signed byte
    mem_rdata = 64'h00000000000000AA;
    @(posedge clk);
    #1;
    check(mem_result_o == 64'hFFFFFFFFFFFFFFAA, "signed byte load extend failed");

    if (errors == 0) $display("[PASS] tb_mem_stage");
    else $display("[FAIL] tb_mem_stage errors=%0d", errors);
    $finish;
end

endmodule
