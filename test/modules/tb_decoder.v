`timescale 1ns / 1ps

// Decoder 单元测试：覆盖 decoder.v 中所有已支持译码路径
module tb_decoder;
// 输入激励
reg [31:0] instr;
reg valid;
// 输出观测
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
reg [15:0] c_instr;

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

// 通用检查任务
task check;
    input cond;
    input [255:0] msg;
begin
    if (!cond) begin
        $display("[FAIL] %0s", msg);
        errors = errors + 1;
    end
end
endtask

// 检查10个类型标志（顺序固定）
task check_flags;
    input [9:0] exp_flags;
    input [255:0] msg;
begin
    if (exp_flags == 10'b1000000000) begin
        // 压缩指令快速检查：当前测试仅要求进入 RVC 通路
        check(is_compressed == 1'b1, msg);
    end else begin
        check({is_compressed, is_branch, is_jump, is_load, is_store,
               is_alu_imm, is_alu_rr, is_lui, is_auipc, is_system} == exp_flags,
              msg);
    end
end
endtask

// 驱动标准32位指令
task drive_instr32;
    input [31:0] i;
begin
    valid = 1'b1;
    instr = i;
    #1;
end
endtask

// 驱动压缩16位指令（放在instr低16位）
task drive_instr16;
    input [15:0] i;
begin
    valid = 1'b1;
    instr = {16'b0, i};
    #1;
end
endtask

initial begin
    errors = 0;

    // =============================
    // 标准32位指令通路覆盖
    // =============================

    // LOAD: lw x1, 4(x2)
    drive_instr32({12'h004, 5'd2, 3'b010, 5'd1, 7'b0000011});
    check_flags(10'b0001000000, "LOAD flags failed");
    check(rs1_addr == 5'd2, "LOAD rs1 failed");
    check(rd_addr == 5'd1, "LOAD rd failed");
    check(imm == 64'd4, "LOAD imm failed");

    // STORE: sw x5, 8(x6)
    drive_instr32({7'b0000000, 5'd5, 5'd6, 3'b010, 5'b01000, 7'b0100011});
    check_flags(10'b0000100000, "STORE flags failed");
    check(rs1_addr == 5'd6, "STORE rs1 failed");
    check(rs2_addr == 5'd5, "STORE rs2 failed");
    check(imm == 64'd8, "STORE imm failed");

    // BRANCH: beq x3, x4, +16
    drive_instr32({1'b0, 6'b000000, 5'd4, 5'd3, 3'b000, 4'b1000, 1'b0, 7'b1100011});
    check_flags(10'b0100000000, "BRANCH flags failed");
    check(rs1_addr == 5'd3, "BRANCH rs1 failed");
    check(rs2_addr == 5'd4, "BRANCH rs2 failed");
    check(imm == 64'd16, "BRANCH imm failed");

    // JALR: jalr x7, 12(x8)
    drive_instr32({12'h00c, 5'd8, 3'b000, 5'd7, 7'b1100111});
    check_flags(10'b0010000000, "JALR flags failed");
    check(rs1_addr == 5'd8, "JALR rs1 failed");
    check(rd_addr == 5'd7, "JALR rd failed");
    check(imm == 64'd12, "JALR imm failed");

    // JAL: jal x1, +20
    drive_instr32({1'b0, 10'd10, 1'b0, 8'd0, 5'd1, 7'b1101111});
    check_flags(10'b0010000000, "JAL flags failed");
    check(rd_addr == 5'd1, "JAL rd failed");
    check(imm == 64'd20, "JAL imm failed");

    // AUIPC
    drive_instr32({20'h12345, 5'd9, 7'b0010111});
    check_flags(10'b0000000010, "AUIPC flags failed");
    check(rd_addr == 5'd9, "AUIPC rd failed");
    check(imm == 64'h0000_0000_1234_5000, "AUIPC imm failed");

    // LUI
    drive_instr32({20'h54321, 5'd10, 7'b0110111});
    check_flags(10'b0000000100, "LUI flags failed");
    check(rd_addr == 5'd10, "LUI rd failed");
    check(imm == 64'h0000_0000_5432_1000, "LUI imm failed");

    // OP-IMM: addi x3, x4, -1
    drive_instr32({12'hfff, 5'd4, 3'b000, 5'd3, 7'b0010011});
    check_flags(10'b0000010000, "OP-IMM flags failed");
    check(rs1_addr == 5'd4, "OP-IMM rs1 failed");
    check(rd_addr == 5'd3, "OP-IMM rd failed");
    check(imm == 64'hffff_ffff_ffff_ffff, "OP-IMM imm failed");

    // OP-IMM32: addiw x6, x7, 1
    drive_instr32({12'h001, 5'd7, 3'b000, 5'd6, 7'b0011011});
    check_flags(10'b0000010000, "OP-IMM32 flags failed");
    check(rs1_addr == 5'd7, "OP-IMM32 rs1 failed");
    check(rd_addr == 5'd6, "OP-IMM32 rd failed");
    check(imm == 64'd1, "OP-IMM32 imm failed");

    // OP: add x10, x11, x12
    drive_instr32({7'b0000000, 5'd12, 5'd11, 3'b000, 5'd10, 7'b0110011});
    check_flags(10'b0000001000, "OP flags failed");
    check(rs1_addr == 5'd11, "OP rs1 failed");
    check(rs2_addr == 5'd12, "OP rs2 failed");
    check(rd_addr == 5'd10, "OP rd failed");

    // OP32: addw x13, x14, x15
    drive_instr32({7'b0000000, 5'd15, 5'd14, 3'b000, 5'd13, 7'b0111011});
    check_flags(10'b0000001000, "OP32 flags failed");
    check(rs1_addr == 5'd14, "OP32 rs1 failed");
    check(rs2_addr == 5'd15, "OP32 rs2 failed");
    check(rd_addr == 5'd13, "OP32 rd failed");

    // SYSTEM: csrrw x1, csr=0x300, x2
    drive_instr32({12'h300, 5'd2, 3'b001, 5'd1, 7'b1110011});
    check_flags(10'b0000000001, "SYSTEM flags failed");
    check(rs1_addr == 5'd2, "SYSTEM rs1 failed");
    check(rd_addr == 5'd1, "SYSTEM rd failed");
    check(imm == 64'd2, "SYSTEM imm failed");

    // 未支持opcode（且instr[1:0]==2'b11）应走default并清opcode
    drive_instr32({25'b0, 7'b0101111});
    check(opcode == 7'b0, "Unsupported opcode must clear opcode");
    check_flags(10'b0000000000, "Unsupported opcode flags must clear");

    // =============================
    // 压缩16位指令通路冒烟覆盖
    // 仅检查进入 RVC 通路及关键类型标志
    // =============================

    // C.ADDI4SPN
    c_instr = {3'b000, 1'b1, 2'b01, 3'b101, 2'b10, 3'b011, 2'b00};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.ADDI4SPN compressed failed");
    check(is_alu_imm == 1'b1, "C.ADDI4SPN type failed");

    // C.LW
    c_instr = {3'b010, 1'b1, 2'b10, 3'b011, 2'b01, 3'b110, 2'b00};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.LW compressed failed");
    check(is_load == 1'b1, "C.LW type failed");

    // C.SW
    c_instr = {3'b110, 1'b0, 2'b11, 3'b100, 2'b10, 3'b001, 2'b00};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.SW compressed failed");
    check(is_store == 1'b1, "C.SW type failed");

    // C.J
    c_instr = {3'b101, 1'b1, 2'b01, 3'b100, 2'b10, 3'b001, 2'b01};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.J compressed failed");
    check(is_jump == 1'b1, "C.J type failed");

    // C.BEQZ
    c_instr = {3'b110, 1'b1, 2'b00, 3'b100, 2'b01, 3'b010, 2'b01};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.BEQZ compressed failed");
    check(is_branch == 1'b1, "C.BEQZ type failed");

    // C.SLLI
    c_instr = {3'b000, 1'b0, 2'b11, 3'b001, 2'b10, 3'b100, 2'b10};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.SLLI compressed failed");
    check(is_alu_imm == 1'b1, "C.SLLI type failed");

    // C.LWSP
    c_instr = {3'b010, 1'b0, 2'b01, 3'b110, 2'b11, 3'b010, 2'b10};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.LWSP compressed failed");
    check(is_load == 1'b1, "C.LWSP type failed");

    // C.SWSP
    c_instr = {3'b110, 1'b1, 2'b01, 3'b100, 2'b10, 3'b110, 2'b10};
    drive_instr16(c_instr);
    check_flags(10'b1000000000, "C.SWSP compressed failed");
    check(is_store == 1'b1, "C.SWSP type failed");

    // valid=0 时应清空 opcode/funct3/funct7
    valid = 1'b0;
    instr = 32'hffff_ffff;
    #1;
    check(opcode == 7'b0, "invalid opcode must clear");
    check(funct3 == 3'b0, "invalid funct3 must clear");
    check(funct7 == 7'b0, "invalid funct7 must clear");
    check_flags(10'b0000000000, "invalid flags must clear");

    if (errors == 0) $display("[PASS] tb_decoder");
    else $display("[FAIL] tb_decoder errors=%0d", errors);
    $finish;
end

endmodule
