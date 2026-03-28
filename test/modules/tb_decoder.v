`timescale 1ns / 1ps

module tb_decoder;
reg [31:0] instr;
reg valid;
wire [4:0] rs1_addr;
wire [4:0] rs2_addr;
wire [4:0] rd_addr;
wire [63:0] imm;
wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;
wire is_compressed;
wire is_branch;
wire is_jump;
wire is_load;
wire is_store;
wire is_alu_imm;
wire is_alu_rr;
wire is_lui;
wire is_auipc;
wire is_system;
integer errors;

decoder dut (
    .instr(instr),
    .valid(valid),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .imm(imm),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .is_compressed(is_compressed),
    .is_branch(is_branch),
    .is_jump(is_jump),
    .is_load(is_load),
    .is_store(is_store),
    .is_alu_imm(is_alu_imm),
    .is_alu_rr(is_alu_rr),
    .is_lui(is_lui),
    .is_auipc(is_auipc),
    .is_system(is_system)
);

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
    errors = 0;

    valid = 1'b1;
    instr = 32'h00412083; // lw x1, 4(x2)
    #1;
    check(is_load == 1'b1, "LOAD decode flag failed");
    check(rs1_addr == 5'd2, "LOAD rs1 failed");
    check(rd_addr == 5'd1, "LOAD rd failed");
    check(imm == 64'd4, "LOAD imm failed");

    valid = 1'b0;
    instr = 32'hFFFFFFFF;
    #1;
    check(opcode == 7'b0, "invalid opcode must clear");

    if (errors == 0) $display("[PASS] tb_decoder");
    else $display("[FAIL] tb_decoder errors=%0d", errors);
    $finish;
end

endmodule
