`timescale 1ns / 1ps

module tb_mem_stage;
reg clk;
reg rst_n;

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

reg [63:0] alu_result_w2_i;
reg [4:0] rd_addr_w2_i;
reg valid_w2_i;
reg reg_write_en_w2_i;
reg [1:0] wb_sel_w2_i;

wire [63:0] mem_addr;
wire [63:0] mem_wdata;
wire mem_we;
wire [7:0] mem_be;
reg [63:0] mem_rdata;
reg mem_gnt;

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

// DCache interface wires
wire [63:0]  dcache_addr;
wire [63:0]  dcache_wdata;
wire [7:0]   dcache_be;
wire         dcache_req;
wire         dcache_we;
wire [2:0]   dcache_size;
wire [63:0]  dcache_data_out;
wire         dcache_hit;
wire         dcache_refill_done;
wire         dcache_writeback_req;
wire [63:0]  dcache_writeback_addr;
wire [255:0] dcache_writeback_data;
wire         dcache_cache_stall;
wire [63:0]  dcache_mem_addr;
wire [255:0] dcache_mem_wdata;
wire [255:0] dcache_mem_rdata;
wire         dcache_mem_req;
wire         dcache_mem_we;
wire         dcache_mem_ready;

integer errors;

mem_stage #(
    .DATA_WIDTH(64),
    .ADDR_WIDTH(64)
) dut (
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
    .wb_sel_w2_o(wb_sel_w2_o),
    .dcache_addr(dcache_addr),
    .dcache_wdata(dcache_wdata),
    .dcache_be(dcache_be),
    .dcache_req(dcache_req),
    .dcache_we(dcache_we),
    .dcache_size(dcache_size),
    .dcache_data_out(dcache_data_out),
    .dcache_hit(dcache_hit),
    .dcache_refill_done(dcache_refill_done),
    .dcache_writeback_req(dcache_writeback_req),
    .dcache_writeback_addr(dcache_writeback_addr),
    .dcache_writeback_data(dcache_writeback_data),
    .dcache_cache_stall(dcache_cache_stall),
    .dcache_mem_addr(dcache_mem_addr),
    .dcache_mem_wdata(dcache_mem_wdata),
    .dcache_mem_rdata(dcache_mem_rdata),
    .dcache_mem_req(dcache_mem_req),
    .dcache_mem_we(dcache_mem_we),
    .dcache_mem_ready(dcache_mem_ready)
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
    mem_gnt = 1;
    errors = 0;

    #12 rst_n = 1;

    // Test 1: Store word - check byte enable and write data
    valid_w1_i = 1;
    mem_write_en_w1_i = 1;
    mem_read_en_w1_i = 0;
    @(posedge clk);
    #1;
    check(mem_we == 1'b1, "mem_we for store failed");
    check(mem_be == 8'b00001111, "mem_be for word store failed");
    check(mem_wdata == 64'h00000000AABBCCDD, "mem_wdata store failed");

    // Test 2: DCache store interface
    check(dcache_we == 1'b1, "dcache_we for store failed");
    check(dcache_req == 1'b1, "dcache_req should be high for store");
    check(dcache_addr == 64'h2000, "dcache_addr should match alu_result");

    // Test 3: Load word (signed)
    mem_write_en_w1_i = 0;
    mem_read_en_w1_i = 1;
    mem_size_w1_i = 3'b010;
    @(posedge clk);
    #1;

    // Test 4: Way2 passthrough (no memory access)
    check(alu_result_w2_o == 64'h55, "w2 passthrough alu result failed");
    check(rd_addr_w2_o == 5'd8, "w2 passthrough rd failed");
    check(valid_w2_o == 1'b1, "w2 passthrough valid failed");

    // Test 5: Half-word store byte enable
    mem_read_en_w1_i = 0;
    mem_write_en_w1_i = 1;
    mem_size_w1_i = 3'b001;
    rs2_data_w1_i = 64'h0000000000001234;
    @(posedge clk);
    #1;
    check(mem_be == 8'b00000011, "mem_be for half-word store failed");
    check(dcache_be == 8'b00000011, "dcache_be for half-word store failed");

    // Test 6: Byte store byte enable
    mem_size_w1_i = 3'b000;
    rs2_data_w1_i = 64'h00000000000000AB;
    @(posedge clk);
    #1;
    check(mem_be == 8'b00000001, "mem_be for byte store failed");

    if (errors == 0) $display("[PASS] tb_mem_stage");
    else $display("[FAIL] tb_mem_stage errors=%0d", errors);
    $finish;
end

endmodule