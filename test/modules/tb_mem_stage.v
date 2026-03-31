`timescale 1ns / 1ps

// MEM 阶段测试：验证 Way1 访存与 Way2 透传
module tb_mem_stage;
reg clk;
reg rst_n;

// Way1 输入
reg [63:0] pc_w1_i;
reg [63:0] alu_result_w1_i;
reg [63:0] rs2_data_w1_i;
reg [4:0] rd_addr_w1_i;
reg valid_w1_i;
reg mem_read_en_w1_i;
reg mem_write_en_w1_i;
reg [2:0] mem_size_w1_i;
reg reg_write_en_w1_i;
reg [1:0] wb_sel_w1_i;

// Way2 输入
reg [63:0] alu_result_w2_i;
reg [4:0] rd_addr_w2_i;
reg valid_w2_i;
reg reg_write_en_w2_i;
reg [1:0] wb_sel_w2_i;

// 存储器接口
wire [63:0] mem_addr;
wire [63:0] mem_wdata;
wire mem_we;
wire [7:0] mem_be;
reg [63:0] mem_rdata;
reg mem_gnt;

// 输出
wire [63:0] alu_result_w1_o;
wire [63:0] mem_result_w1_o;
wire [4:0] rd_addr_w1_o;
wire valid_w1_o;
wire reg_write_en_w1_o;
wire [1:0] wb_sel_w1_o;

wire [63:0] alu_result_w2_o;
wire [4:0] rd_addr_w2_o;
wire valid_w2_o;
wire reg_write_en_w2_o;
wire [1:0] wb_sel_w2_o;

integer errors;

mem_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .pc_w1_i(pc_w1_i),
    .alu_result_w1_i(alu_result_w1_i),
    .rs2_data_w1_i(rs2_data_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i),
    .valid_w1_i(valid_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i),
    .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i),
    .reg_write_en_w1_i(reg_write_en_w1_i),
    .wb_sel_w1_i(wb_sel_w1_i),
    .alu_result_w2_i(alu_result_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i),
    .valid_w2_i(valid_w2_i),
    .reg_write_en_w2_i(reg_write_en_w2_i),
    .wb_sel_w2_i(wb_sel_w2_i),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_we(mem_we),
    .mem_be(mem_be),
    .mem_rdata(mem_rdata),
    .mem_gnt(mem_gnt),
    .alu_result_w1_o(alu_result_w1_o),
    .mem_result_w1_o(mem_result_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o),
    .valid_w1_o(valid_w1_o),
    .reg_write_en_w1_o(reg_write_en_w1_o),
    .wb_sel_w1_o(wb_sel_w1_o),
    .alu_result_w2_o(alu_result_w2_o),
    .rd_addr_w2_o(rd_addr_w2_o),
    .valid_w2_o(valid_w2_o),
    .reg_write_en_w2_o(reg_write_en_w2_o),
    .wb_sel_w2_o(wb_sel_w2_o)
);

always #5 clk = ~clk;

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
    rst_n = 0;

    pc_w1_i = 64'h1000;
    alu_result_w1_i = 64'h2000;
    rs2_data_w1_i = 64'h00000000AABBCCDD;
    rd_addr_w1_i = 5'd3;
    valid_w1_i = 0;
    mem_read_en_w1_i = 0;
    mem_write_en_w1_i = 0;
    mem_size_w1_i = 3'b010;
    reg_write_en_w1_i = 1;
    wb_sel_w1_i = 2'b01;

    alu_result_w2_i = 64'h55;
    rd_addr_w2_i = 5'd8;
    valid_w2_i = 1;
    reg_write_en_w2_i = 1;
    wb_sel_w2_i = 2'b00;

    mem_rdata = 64'h00000000000000AA;
    mem_gnt = 0;
    errors = 0;

    #12 rst_n = 1;

    // store word: 检查 byte enable 与写数据
    valid_w1_i = 1;
    mem_write_en_w1_i = 1;
    mem_read_en_w1_i = 0;
    mem_gnt = 1;
    @(posedge clk);
    #1;
    check(mem_we == 1'b1, "mem_we for store failed");
    check(mem_be == 8'b00001111, "mem_be for word store failed");
    check(mem_wdata == 64'h00000000AABBCCDD, "mem_wdata store failed");

    // load byte(signed): 检查符号扩展
    mem_write_en_w1_i = 0;
    mem_read_en_w1_i = 1;
    mem_size_w1_i = 3'b000;
    mem_rdata = 64'h00000000000000AA;
    @(posedge clk);
    #1;
    check(mem_result_w1_o == 64'hFFFFFFFFFFFFFFAA, "signed byte load extend failed");

    // Way2 透传
    check(alu_result_w2_o == 64'h55, "w2 passthrough alu result failed");
    check(rd_addr_w2_o == 5'd8, "w2 passthrough rd failed");
    check(valid_w2_o == 1'b1, "w2 passthrough valid failed");

    if (errors == 0) $display("[PASS] tb_mem_stage");
    else $display("[FAIL] tb_mem_stage errors=%0d", errors);
    $finish;
end

endmodule
