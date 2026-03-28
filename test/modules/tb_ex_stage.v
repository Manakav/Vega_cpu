`timescale 1ns / 1ps

module tb_ex_stage;
reg clk;
reg rst_n;
reg flush;
reg [63:0] pc_i;
reg [63:0] rs1_data_i;
reg [63:0] rs2_data_i;
reg [63:0] imm_i;
reg [4:0] rd_addr_i;
reg valid_i;
reg [3:0] alu_op_i;
reg alu_src1_sel_i;
reg alu_src2_sel_i;
reg mem_read_en_i;
reg mem_write_en_i;
reg [2:0] mem_size_i;
reg reg_write_en_i;
reg [1:0] wb_sel_i;
reg is_branch_i;
reg is_jump_i;
reg [63:0] forward_ex;
reg [63:0] forward_mem;
reg [63:0] forward_wb;
reg [1:0] forward_a_sel;
reg [1:0] forward_b_sel;
reg predict_taken_i;
reg [63:0] predict_target_i;
wire [63:0] pc_o;
wire [63:0] alu_result_o;
wire [63:0] rs2_data_o;
wire [4:0] rd_addr_o;
wire valid_o;
wire mem_read_en_o;
wire mem_write_en_o;
wire [2:0] mem_size_o;
wire reg_write_en_o;
wire [1:0] wb_sel_o;
wire branch_taken_o;
wire [63:0] branch_target_o;
wire mispredict_o;
integer errors;

ex_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .pc_i(pc_i),
    .rs1_data_i(rs1_data_i),
    .rs2_data_i(rs2_data_i),
    .imm_i(imm_i),
    .rd_addr_i(rd_addr_i),
    .valid_i(valid_i),
    .alu_op_i(alu_op_i),
    .alu_src1_sel_i(alu_src1_sel_i),
    .alu_src2_sel_i(alu_src2_sel_i),
    .mem_read_en_i(mem_read_en_i),
    .mem_write_en_i(mem_write_en_i),
    .mem_size_i(mem_size_i),
    .reg_write_en_i(reg_write_en_i),
    .wb_sel_i(wb_sel_i),
    .is_branch_i(is_branch_i),
    .is_jump_i(is_jump_i),
    .forward_ex(forward_ex),
    .forward_mem(forward_mem),
    .forward_wb(forward_wb),
    .forward_a_sel(forward_a_sel),
    .forward_b_sel(forward_b_sel),
    .predict_taken_i(predict_taken_i),
    .predict_target_i(predict_target_i),
    .pc_o(pc_o),
    .alu_result_o(alu_result_o),
    .rs2_data_o(rs2_data_o),
    .rd_addr_o(rd_addr_o),
    .valid_o(valid_o),
    .mem_read_en_o(mem_read_en_o),
    .mem_write_en_o(mem_write_en_o),
    .mem_size_o(mem_size_o),
    .reg_write_en_o(reg_write_en_o),
    .wb_sel_o(wb_sel_o),
    .branch_taken_o(branch_taken_o),
    .branch_target_o(branch_target_o),
    .mispredict_o(mispredict_o)
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
    flush = 0;
    pc_i = 64'h1000;
    rs1_data_i = 64'd5;
    rs2_data_i = 64'd5;
    imm_i = 64'd8;
    rd_addr_i = 5'd1;
    valid_i = 0;
    alu_op_i = 4'b0000;
    alu_src1_sel_i = 0;
    alu_src2_sel_i = 0;
    mem_read_en_i = 0;
    mem_write_en_i = 0;
    mem_size_i = 3'b000;
    reg_write_en_i = 1;
    wb_sel_i = 2'b00;
    is_branch_i = 0;
    is_jump_i = 0;
    forward_ex = 0;
    forward_mem = 0;
    forward_wb = 0;
    forward_a_sel = 0;
    forward_b_sel = 0;
    predict_taken_i = 0;
    predict_target_i = 64'h0;
    errors = 0;

    #12 rst_n = 1;

    valid_i = 1;
    @(posedge clk);
    #1;
    check(alu_result_o == 64'd10, "ALU add result failed");

    is_branch_i = 1;
    mem_size_i = 3'b000; // BEQ
    predict_taken_i = 0;
    predict_target_i = 64'h0;
    @(posedge clk);
    #1;
    check(branch_taken_o == 1'b1, "branch_taken failed");
    check(mispredict_o == 1'b1, "mispredict detect failed");

    if (errors == 0) $display("[PASS] tb_ex_stage");
    else $display("[FAIL] tb_ex_stage errors=%0d", errors);
    $finish;
end

endmodule
