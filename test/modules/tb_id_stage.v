`timescale 1ns / 1ps

module tb_id_stage;
reg clk;
reg rst_n;
reg stall;
reg flush;
reg [63:0] pc_i;
reg [31:0] instr_i;
reg valid_i;
wire [4:0] rs1_addr_o;
wire [4:0] rs2_addr_o;
reg [63:0] rs1_data_i;
reg [63:0] rs2_data_i;
reg [63:0] forward_rs1;
reg [63:0] forward_rs2;
reg [1:0] forward_sel;
wire [63:0] pc_o;
wire [31:0] instr_o;
wire [63:0] rs1_data_o;
wire [63:0] rs2_data_o;
wire [63:0] imm_o;
wire [4:0] rd_addr_o;
wire valid_o;
wire [3:0] alu_op_o;
wire alu_src1_sel_o;
wire alu_src2_sel_o;
wire mem_read_en_o;
wire mem_write_en_o;
wire [2:0] mem_size_o;
wire reg_write_en_o;
wire [1:0] wb_sel_o;
wire is_branch_o;
wire is_jump_o;
integer errors;

id_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .pc_i(pc_i),
    .instr_i(instr_i),
    .valid_i(valid_i),
    .rs1_addr_o(rs1_addr_o),
    .rs2_addr_o(rs2_addr_o),
    .rs1_data_i(rs1_data_i),
    .rs2_data_i(rs2_data_i),
    .forward_rs1(forward_rs1),
    .forward_rs2(forward_rs2),
    .forward_sel(forward_sel),
    .pc_o(pc_o),
    .instr_o(instr_o),
    .rs1_data_o(rs1_data_o),
    .rs2_data_o(rs2_data_o),
    .imm_o(imm_o),
    .rd_addr_o(rd_addr_o),
    .valid_o(valid_o),
    .alu_op_o(alu_op_o),
    .alu_src1_sel_o(alu_src1_sel_o),
    .alu_src2_sel_o(alu_src2_sel_o),
    .mem_read_en_o(mem_read_en_o),
    .mem_write_en_o(mem_write_en_o),
    .mem_size_o(mem_size_o),
    .reg_write_en_o(reg_write_en_o),
    .wb_sel_o(wb_sel_o),
    .is_branch_o(is_branch_o),
    .is_jump_o(is_jump_o)
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
    stall = 0;
    flush = 0;
    pc_i = 64'h1000;
    instr_i = 32'h00412083; // lw x1, 4(x2)
    valid_i = 0;
    rs1_data_i = 64'h10;
    rs2_data_i = 64'h20;
    forward_rs1 = 0;
    forward_rs2 = 0;
    forward_sel = 0;
    errors = 0;

    #12 rst_n = 1;
    valid_i = 1;
    #1;

    check(rs1_addr_o == 5'd2, "rs1 addr decode failed");
    check(rd_addr_o == 5'd1, "rd decode failed");
    check(mem_read_en_o == 1'b1, "load mem_read_en failed");
    check(reg_write_en_o == 1'b1, "load reg_write_en failed");
    check(valid_o == 1'b1, "valid_o failed");

    if (errors == 0) $display("[PASS] tb_id_stage");
    else $display("[FAIL] tb_id_stage errors=%0d", errors);
    $finish;
end

endmodule
