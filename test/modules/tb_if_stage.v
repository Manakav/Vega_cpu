`timescale 1ns / 1ps

module tb_if_stage;
reg clk;
reg rst_n;
reg stall;
reg flush;
wire [63:0] instr_addr;
reg [31:0] instr_data;
wire instr_req;
reg instr_gnt;
reg branch_taken;
reg [63:0] branch_target;
reg mispredict;
wire [63:0] pc_out;
wire [31:0] instr_out;
wire valid_out;
integer errors;

if_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .flush(flush),
    .instr_addr(instr_addr),
    .instr_data(instr_data),
    .instr_req(instr_req),
    .instr_gnt(instr_gnt),
    .branch_taken(branch_taken),
    .branch_target(branch_target),
    .mispredict(mispredict),
    .pc_out(pc_out),
    .instr_out(instr_out),
    .valid_out(valid_out)
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
    instr_data = 32'h00000013;
    instr_gnt = 1;
    branch_taken = 0;
    branch_target = 64'h2000;
    mispredict = 0;
    errors = 0;

    #12 rst_n = 1;

    repeat (3) @(posedge clk);
    #1;
    check(instr_req == 1'b1, "instr_req should be always high");
    check(valid_out == 1'b1, "valid_out should become high");

    mispredict = 1;
    @(posedge clk);
    mispredict = 0;
    #1;
    check(instr_addr == 64'h2000, "mispredict redirection failed");

    if (errors == 0) $display("[PASS] tb_if_stage");
    else $display("[FAIL] tb_if_stage errors=%0d", errors);
    $finish;
end

endmodule
