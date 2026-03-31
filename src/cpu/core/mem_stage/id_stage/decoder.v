// ============================================================================
// 指令译码器 (Instruction Decoder)
// 支持RV64GC指令集：RVI, RVM, RVC
// ============================================================================

module decoder (
    // ---- 输入 ----
    input  wire [31:0] instr,          // 待译码的32位指令字（含压缩指令）
    input  wire        valid,           // 指令有效标志，低电平时输出全清零

    // ---- 寄存器地址 ----
    output reg  [4:0]  rs1_addr,       // 源寄存器1地址（RS1）
    output reg  [4:0]  rs2_addr,       // 源寄存器2地址（RS2）
    output reg  [4:0]  rd_addr,        // 目的寄存器地址（RD）

    // ---- 立即数与指令字段 ----
    output reg  [63:0] imm,            // 符号扩展后的64位立即数
    output reg  [6:0]  opcode,         // 指令操作码字段 [6:0]
    output reg  [2:0]  funct3,         // 指令funct3字段 [14:12]
    output reg  [6:0]  funct7,         // 指令funct7字段 [31:25]

    // ---- 指令类型标志 ----
    output reg         is_compressed,  // 压缩指令（RVC，16-bit）
    output reg         is_branch,      // 条件分支指令（BRANCH）
    output reg         is_jump,        // 无条件跳转指令（JAL/JALR）
    output reg         is_load,        // 内存加载指令（LOAD）
    output reg         is_store,       // 内存存储指令（STORE）
    output reg         is_alu_imm,     // ALU立即数运算指令（OP-IMM/OP-IMM-32）
    output reg         is_alu_rr,      // ALU寄存器-寄存器运算指令（OP/OP-32）
    output reg         is_muldiv,      // M扩展乘除法指令
    output reg  [2:0]  muldiv_funct3,  // M扩展子操作编码
    output reg         is_lui,         // 高位立即数加载指令（LUI）
    output reg         is_auipc,       // PC相对高位立即数指令（AUIPC）
    output reg         is_system       // 系统指令（CSR/ECALL/EBREAK等）
);

wire [6:0] op = instr[6:0];
wire [2:0] f3 = instr[14:12];
wire [6:0] f7 = instr[31:25];

always @(*) begin
    // 默认输出：未命中类型时保持空操作
    rs1_addr = 5'b0;
    rs2_addr = 5'b0;
    rd_addr = 5'b0;
    imm = 64'b0;
    opcode = op;
    funct3 = f3;
    funct7 = f7;
    is_compressed = 1'b0;
    is_branch = 1'b0;
    is_jump = 1'b0;
    is_load = 1'b0;
    is_store = 1'b0;
    is_alu_imm = 1'b0;
    is_alu_rr = 1'b0;
    is_muldiv = 1'b0;
    muldiv_funct3 = 3'b0;
    is_lui = 1'b0;
    is_auipc = 1'b0;
    is_system = 1'b0;
    
    if (!valid) begin
        opcode = 7'b0;
        funct3 = 3'b0;
        funct7 = 7'b0;
    end else if (instr[1:0] != 2'b11) begin
        // 压缩指令通路（RVC）
        is_compressed = 1'b1;
        case (instr[1:0])
            2'b00: begin
                case (instr[15:13])
                    3'b000: begin // C.ADDI4SPN
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rs1_addr = 5'd2;
                        rd_addr  = {2'b01, instr[4:2]};
                        imm = {54'b0, instr[10:7], instr[12:11], instr[5], instr[6], 2'b00};
                        is_alu_imm = 1'b1;
                    end
                    3'b010: begin // C.LW
                        opcode = 7'b0000011;
                        funct3 = 3'b010;
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr  = {2'b01, instr[4:2]};
                        imm = {57'b0, instr[5], instr[12:10], instr[6], 2'b00};
                        is_load = 1'b1;
                    end
                    3'b011: begin // C.LD
                        opcode = 7'b0000011;
                        funct3 = 3'b011;
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr  = {2'b01, instr[4:2]};
                        imm = {56'b0, instr[6:5], instr[12:10], 3'b000};
                        is_load = 1'b1;
                    end
                    3'b110: begin // C.SW
                        opcode = 7'b0100011;
                        funct3 = 3'b010;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = {2'b01, instr[4:2]};
                        imm = {57'b0, instr[5], instr[12], instr[11:10], instr[6], 2'b00};
                        is_store = 1'b1;
                    end
                    3'b111: begin // C.SD
                        opcode = 7'b0100011;
                        funct3 = 3'b011;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = {2'b01, instr[4:2]};
                        imm = {56'b0, instr[6:5], instr[12:10], 3'b000};
                        is_store = 1'b1;
                    end
                endcase
            end
            2'b01: begin
                case (instr[15:13])
                    3'b000: begin // C.ADDI/C.NOP
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm = {{58{instr[12]}}, instr[12], instr[6:2]};
                        is_alu_imm = 1'b1;
                    end
                    3'b001: begin // C.ADDIW
                        opcode = 7'b0011011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm = {{58{instr[12]}}, instr[12], instr[6:2]};
                        is_alu_imm = 1'b1;
                    end
                    3'b010: begin // C.LI
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = 5'b0;
                        imm = {{58{instr[12]}}, instr[12], instr[6:2]};
                        is_alu_imm = 1'b1;
                    end
                    3'b011: begin
                        if (instr[11:7] == 5'd2) begin // C.ADDI16SP
                            opcode = 7'b0010011;
                            funct3 = 3'b000;
                            rd_addr  = 5'd2;
                            rs1_addr = 5'd2;
                            imm = {{54{instr[12]}}, instr[12], instr[4:3], instr[5], instr[2], instr[6], 4'b0000};
                            is_alu_imm = 1'b1;
                        end else begin // C.LUI
                            opcode = 7'b0110111;
                            rd_addr = instr[11:7];
                            imm = {{46{instr[12]}}, instr[12], instr[6:2], 12'b0};
                            is_lui = 1'b1;
                        end
                    end
                    3'b100: begin
                        if (instr[11:10] == 2'b00) begin // C.SRLI
                            opcode = 7'b0010011;
                            funct3 = 3'b101;
                            funct7 = 7'b0000000;
                            rd_addr  = {2'b01, instr[9:7]};
                            rs1_addr = {2'b01, instr[9:7]};
                            imm = {58'b0, instr[12], instr[6:2]};
                            is_alu_imm = 1'b1;
                        end else if (instr[11:10] == 2'b01) begin // C.SRAI
                            opcode = 7'b0010011;
                            funct3 = 3'b101;
                            funct7 = 7'b0100000;
                            rd_addr  = {2'b01, instr[9:7]};
                            rs1_addr = {2'b01, instr[9:7]};
                            imm = {58'b0, instr[12], instr[6:2]};
                            is_alu_imm = 1'b1;
                        end else if (instr[11:10] == 2'b10) begin // C.ANDI
                            opcode = 7'b0010011;
                            funct3 = 3'b111;
                            rd_addr  = {2'b01, instr[9:7]};
                            rs1_addr = {2'b01, instr[9:7]};
                            imm = {{58{instr[12]}}, instr[12], instr[6:2]};
                            is_alu_imm = 1'b1;
                        end else begin
                            rd_addr  = {2'b01, instr[9:7]};
                            rs1_addr = {2'b01, instr[9:7]};
                            rs2_addr = {2'b01, instr[4:2]};
                            if ({instr[12], instr[6:5]} == 3'b000) begin // C.SUB
                                opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000; is_alu_rr = 1'b1;
                            end else if ({instr[12], instr[6:5]} == 3'b001) begin // C.XOR
                                opcode = 7'b0110011; funct3 = 3'b100; funct7 = 7'b0000000; is_alu_rr = 1'b1;
                            end else if ({instr[12], instr[6:5]} == 3'b010) begin // C.OR
                                opcode = 7'b0110011; funct3 = 3'b110; funct7 = 7'b0000000; is_alu_rr = 1'b1;
                            end else if ({instr[12], instr[6:5]} == 3'b011) begin // C.AND
                                opcode = 7'b0110011; funct3 = 3'b111; funct7 = 7'b0000000; is_alu_rr = 1'b1;
                            end else if ({instr[12], instr[6:5]} == 3'b100) begin // C.SUBW
                                opcode = 7'b0111011; funct3 = 3'b000; funct7 = 7'b0100000; is_alu_rr = 1'b1;
                            end else if ({instr[12], instr[6:5]} == 3'b101) begin // C.ADDW
                                opcode = 7'b0111011; funct3 = 3'b000; funct7 = 7'b0000000; is_alu_rr = 1'b1;
                            end
                        end
                    end
                    3'b101: begin // C.J
                        opcode = 7'b1101111;
                        rd_addr = 5'b0;
                        imm = {{52{instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
                        is_jump = 1'b1;
                    end
                    3'b110: begin // C.BEQZ
                        opcode = 7'b1100011;
                        funct3 = 3'b000;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = 5'b0;
                        imm = {{55{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
                        is_branch = 1'b1;
                    end
                    3'b111: begin // C.BNEZ
                        opcode = 7'b1100011;
                        funct3 = 3'b001;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = 5'b0;
                        imm = {{55{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
                        is_branch = 1'b1;
                    end
                endcase
            end
            2'b10: begin
                case (instr[15:13])
                    3'b000: begin // C.SLLI
                        opcode = 7'b0010011;
                        funct3 = 3'b001;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm = {58'b0, instr[12], instr[6:2]};
                        is_alu_imm = 1'b1;
                    end
                    3'b010: begin // C.LWSP
                        opcode = 7'b0000011;
                        funct3 = 3'b010;
                        rd_addr = instr[11:7];
                        rs1_addr = 5'd2;
                        imm = {56'b0, instr[3:2], instr[12], instr[6:4], 2'b00};
                        is_load = 1'b1;
                    end
                    3'b011: begin // C.LDSP
                        opcode = 7'b0000011;
                        funct3 = 3'b011;
                        rd_addr = instr[11:7];
                        rs1_addr = 5'd2;
                        imm = {55'b0, instr[4:2], instr[12], instr[6:5], 3'b000};
                        is_load = 1'b1;
                    end
                    3'b100: begin
                        rd_addr = instr[11:7];
                        rs1_addr = instr[11:7];
                        rs2_addr = instr[6:2];
                        if (!instr[12] && (instr[6:2] == 5'b0)) begin // C.JR
                            opcode = 7'b1100111;
                            rd_addr = 5'b0;
                            is_jump = 1'b1;
                            imm = 64'b0;
                        end else if (!instr[12] && (instr[6:2] != 5'b0)) begin // C.MV
                            opcode = 7'b0010011;
                            funct3 = 3'b000;
                            rs1_addr = instr[6:2];
                            imm = 64'b0;
                            is_alu_imm = 1'b1;
                        end else if (instr[12] && (instr[11:7] == 5'b0) && (instr[6:2] == 5'b0)) begin // C.EBREAK
                            opcode = 7'b1110011;
                            funct3 = 3'b000;
                            is_system = 1'b1;
                        end else if (instr[12] && (instr[6:2] == 5'b0)) begin // C.JALR
                            opcode = 7'b1100111;
                            rd_addr = 5'd1;
                            is_jump = 1'b1;
                            imm = 64'b0;
                        end else begin // C.ADD
                            opcode = 7'b0110011;
                            funct3 = 3'b000;
                            funct7 = 7'b0000000;
                            is_alu_rr = 1'b1;
                        end
                    end
                    3'b110: begin // C.SWSP
                        opcode = 7'b0100011;
                        funct3 = 3'b010;
                        rs1_addr = 5'd2;
                        rs2_addr = instr[6:2];
                        imm = {56'b0, instr[8:7], instr[12:9], 2'b00};
                        is_store = 1'b1;
                    end
                    3'b111: begin // C.SDSP
                        opcode = 7'b0100011;
                        funct3 = 3'b011;
                        rs1_addr = 5'd2;
                        rs2_addr = instr[6:2];
                        imm = {55'b0, instr[9:7], instr[12:10], 3'b000};
                        is_store = 1'b1;
                    end
                endcase
            end
        endcase
    end else begin
        // 标准 32-bit 指令通路
        case (op)
            7'b0000011: begin // LOAD
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm = {{52{instr[31]}}, instr[31:20]};
                is_load = 1'b1;
            end
            
            7'b0100011: begin // STORE
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};
                is_store = 1'b1;
            end
            
            7'b1100011: begin // BRANCH
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                imm = {{52{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
                is_branch = 1'b1;
            end
            
            7'b1100111: begin // JALR
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm = {{52{instr[31]}}, instr[31:20]};
                is_jump = 1'b1;
            end
            
            7'b1101111: begin // JAL
                rd_addr = instr[11:7];
                imm = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
                is_jump = 1'b1;
            end
            
            7'b0010111: begin // AUIPC
                rd_addr = instr[11:7];
                imm = {instr[31:12], 12'b0};
                is_auipc = 1'b1;
            end
            
            7'b0110111: begin // LUI
                rd_addr = instr[11:7];
                imm = {instr[31:12], 12'b0};
                is_lui = 1'b1;
            end
            
            7'b0010011: begin // OP-IMM
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm = {{52{instr[31]}}, instr[31:20]};
                is_alu_imm = 1'b1;
            end
            
            7'b0011011: begin // OP-IMM32 (64-bit)
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm = {{52{instr[31]}}, instr[31:20]};
                is_alu_imm = 1'b1;
            end
            
            7'b0110011: begin // OP (R-type)
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                rd_addr = instr[11:7];
                if (instr[31:25] == 7'b0000001) begin
                    is_muldiv = 1'b1;
                    muldiv_funct3 = instr[14:12];
                end else begin
                    is_alu_rr = 1'b1;
                end
            end
            
            7'b0111011: begin // OP32 (64-bit)
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                rd_addr = instr[11:7];
                is_alu_rr = 1'b1;
            end
            
            7'b1110011: begin // SYSTEM
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm = {57'b0, instr[19:15]};
                is_system = 1'b1;
            end
            
            default: begin
                opcode = 7'b0;
            end
        endcase
    end
end

endmodule