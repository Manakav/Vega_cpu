// ============================================================================
// 指令译码器 (Instruction Decoder)
// 支持RV64IMC指令集：RVI, RVM, RVC
// 优化：拆分指令类型/寄存器地址/立即数为独立并行逻辑，减少关键路径深度
// ============================================================================

module decoder (
    input  wire [31:0] instr,
    input  wire        valid,

    output reg  [4:0]  rs1_addr,
    output reg  [4:0]  rs2_addr,
    output reg  [4:0]  rd_addr,

    output reg  [63:0] imm,
    output reg  [6:0]  opcode,
    output reg  [2:0]  funct3,
    output reg  [6:0]  funct7,

    output reg         is_compressed,
    output reg         is_branch,
    output reg         is_jump,
    output reg         is_load,
    output reg         is_store,
    output reg         is_alu_imm,
    output reg         is_alu_rr,
    output reg         is_muldiv,
    output reg  [2:0]  muldiv_funct3,
    output reg         is_lui,
    output reg         is_auipc,
    output reg         is_system,
    output reg         is_csr,
    output reg  [11:0] csr_addr
);

wire [6:0] op = instr[6:0];
wire [2:0] f3 = instr[14:12];
wire [6:0] f7 = instr[31:25];

// ============================================================
// 立即数类型编码 - 独立于指令类型判断，减少关键路径
// ============================================================
localparam IMM_I    = 4'd0;
localparam IMM_S    = 4'd1;
localparam IMM_B    = 4'd2;
localparam IMM_U    = 4'd3;
localparam IMM_J    = 4'd4;
localparam IMM_CI   = 4'd5;
localparam IMM_CJ   = 4'd6;
localparam IMM_CB   = 4'd7;
localparam IMM_CIW  = 4'd8;
localparam IMM_CSS  = 4'd9;
localparam IMM_CLD  = 4'd10;
localparam IMM_CSD  = 4'd11;
localparam IMM_CLW  = 4'd12;
localparam IMM_CSW  = 4'd13;
localparam IMM_CADDI16SP = 4'd14;
localparam IMM_CSLLI = 4'd15;
localparam IMM_SYS   = 5'd16;

reg [4:0] imm_type;

// 立即数生成 - 独立组合逻辑块
always @(*) begin
    case (imm_type)
        IMM_I:    imm = {{52{instr[31]}}, instr[31:20]};
        IMM_S:    imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};
        IMM_B:    imm = {{52{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        IMM_U:    imm = {instr[31:12], 12'b0};
        IMM_J:    imm = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
        IMM_CI:   imm = {{58{instr[12]}}, instr[12], instr[6:2]};
        IMM_CJ:   imm = {{52{instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
        IMM_CB:   imm = {{55{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
        IMM_CIW:  imm = {54'b0, instr[10:7], instr[12:11], instr[5], instr[6], 2'b00};
        IMM_CSS:  imm = {56'b0, instr[8:7], instr[12:9], 2'b00};
        IMM_CLD:  imm = {55'b0, instr[4:2], instr[12], instr[6:5], 3'b000};
        IMM_CSD:  imm = {55'b0, instr[9:7], instr[12:10], 3'b000};
        IMM_CLW:  imm = {56'b0, instr[3:2], instr[12], instr[6:4], 2'b00};
        IMM_CSW:  imm = {57'b0, instr[5], instr[12], instr[11:10], instr[6], 2'b00};
        IMM_CADDI16SP: imm = {{54{instr[12]}}, instr[12], instr[4:3], instr[5], instr[2], instr[6], 4'b0000};
        IMM_CSLLI: imm = {58'b0, instr[12], instr[6:2]};
        IMM_SYS:   imm = {57'b0, instr[19:15]};
        default:  imm = 64'b0;
    endcase
end

// ============================================================
// 指令类型判断 + 寄存器地址 + 立即数类型选择 - 并行逻辑
// ============================================================
always @(*) begin
    rs1_addr = 5'b0;
    rs2_addr = 5'b0;
    rd_addr = 5'b0;
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
    is_csr = 1'b0;
    csr_addr = 12'b0;
    imm_type = 4'd0;

    if (!valid) begin
        opcode = 7'b0;
        funct3 = 3'b0;
        funct7 = 7'b0;
    end else if (instr[1:0] != 2'b11) begin
        is_compressed = 1'b1;
        case (instr[1:0])
            2'b00: begin
                case (instr[15:13])
                    3'b000: begin
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rs1_addr = 5'd2;
                        rd_addr  = {2'b01, instr[4:2]};
                        imm_type = IMM_CIW;
                        is_alu_imm = 1'b1;
                    end
                    3'b001: begin
                        opcode = 7'b0;
                    end
                    3'b010: begin
                        opcode = 7'b0000011;
                        funct3 = 3'b010;
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr  = {2'b01, instr[4:2]};
                        imm_type = IMM_CSW;
                        is_load = 1'b1;
                    end
                    3'b011: begin
                        opcode = 7'b0000011;
                        funct3 = 3'b011;
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr  = {2'b01, instr[4:2]};
                        imm_type = IMM_CSD;
                        is_load = 1'b1;
                    end
                    3'b100: begin
                        opcode = 7'b0;
                    end
                    3'b101: begin
                        opcode = 7'b0;
                    end
                    3'b110: begin
                        opcode = 7'b0100011;
                        funct3 = 3'b010;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = {2'b01, instr[4:2]};
                        imm_type = IMM_CSW;
                        is_store = 1'b1;
                    end
                    3'b111: begin
                        opcode = 7'b0100011;
                        funct3 = 3'b011;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = {2'b01, instr[4:2]};
                        imm_type = IMM_CSD;
                        is_store = 1'b1;
                    end
                    default: begin
                        opcode = 7'b0;
                    end
                endcase
            end
            2'b01: begin
                case (instr[15:13])
                    3'b000: begin
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm_type = IMM_CI;
                        is_alu_imm = 1'b1;
                    end
                    3'b001: begin
                        opcode = 7'b0011011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm_type = IMM_CI;
                        is_alu_imm = 1'b1;
                    end
                    3'b010: begin
                        opcode = 7'b0010011;
                        funct3 = 3'b000;
                        rd_addr  = instr[11:7];
                        rs1_addr = 5'b0;
                        imm_type = IMM_CI;
                        is_alu_imm = 1'b1;
                    end
                    3'b011: begin
                        if (instr[11:7] == 5'd2) begin
                            opcode = 7'b0010011;
                            funct3 = 3'b000;
                            rd_addr  = 5'd2;
                            rs1_addr = 5'd2;
                            imm_type = IMM_CADDI16SP;
                            is_alu_imm = 1'b1;
                        end else begin
                            opcode = 7'b0110111;
                            rd_addr = instr[11:7];
                            imm_type = IMM_U;
                            is_lui = 1'b1;
                        end
                    end
                    3'b100: begin
                        case (instr[11:10])
                            2'b00: begin
                                opcode = 7'b0010011;
                                funct3 = 3'b101;
                                funct7 = 7'b0000000;
                                rd_addr  = {2'b01, instr[9:7]};
                                rs1_addr = {2'b01, instr[9:7]};
                                imm_type = IMM_CSLLI;
                                is_alu_imm = 1'b1;
                            end
                            2'b01: begin
                                opcode = 7'b0010011;
                                funct3 = 3'b101;
                                funct7 = 7'b0100000;
                                rd_addr  = {2'b01, instr[9:7]};
                                rs1_addr = {2'b01, instr[9:7]};
                                imm_type = IMM_CSLLI;
                                is_alu_imm = 1'b1;
                            end
                            2'b10: begin
                                opcode = 7'b0010011;
                                funct3 = 3'b111;
                                rd_addr  = {2'b01, instr[9:7]};
                                rs1_addr = {2'b01, instr[9:7]};
                                imm_type = IMM_CI;
                                is_alu_imm = 1'b1;
                            end
                            default: begin
                                rd_addr  = {2'b01, instr[9:7]};
                                rs1_addr = {2'b01, instr[9:7]};
                                rs2_addr = {2'b01, instr[4:2]};
                                case ({instr[12], instr[6:5]})
                                    3'b000: begin opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000; is_alu_rr = 1'b1; end
                                    3'b001: begin opcode = 7'b0110011; funct3 = 3'b100; funct7 = 7'b0000000; is_alu_rr = 1'b1; end
                                    3'b010: begin opcode = 7'b0110011; funct3 = 3'b110; funct7 = 7'b0000000; is_alu_rr = 1'b1; end
                                    3'b011: begin opcode = 7'b0110011; funct3 = 3'b111; funct7 = 7'b0000000; is_alu_rr = 1'b1; end
                                    3'b100: begin opcode = 7'b0111011; funct3 = 3'b000; funct7 = 7'b0100000; is_alu_rr = 1'b1; end
                                    3'b101: begin opcode = 7'b0111011; funct3 = 3'b000; funct7 = 7'b0000000; is_alu_rr = 1'b1; end
                                    default: begin opcode = 7'b0; end
                                endcase
                            end
                        endcase
                    end
                    3'b101: begin
                        opcode = 7'b1101111;
                        rd_addr = 5'b0;
                        imm_type = IMM_CJ;
                        is_jump = 1'b1;
                    end
                    3'b110: begin
                        opcode = 7'b1100011;
                        funct3 = 3'b000;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = 5'b0;
                        imm_type = IMM_CB;
                        is_branch = 1'b1;
                    end
                    3'b111: begin
                        opcode = 7'b1100011;
                        funct3 = 3'b001;
                        rs1_addr = {2'b01, instr[9:7]};
                        rs2_addr = 5'b0;
                        imm_type = IMM_CB;
                        is_branch = 1'b1;
                    end
                    default: begin
                        opcode = 7'b0;
                    end
                endcase
            end
            2'b10: begin
                case (instr[15:13])
                    3'b000: begin
                        opcode = 7'b0010011;
                        funct3 = 3'b001;
                        funct7 = 7'b0000000;
                        rd_addr  = instr[11:7];
                        rs1_addr = instr[11:7];
                        imm_type = IMM_CSLLI;
                        is_alu_imm = 1'b1;
                    end
                    3'b001: begin
                        opcode = 7'b0010011;
                        funct3 = 3'b101;
                        funct7 = 7'b0000000;
                        rd_addr  = {2'b01, instr[9:7]};
                        rs1_addr = {2'b01, instr[9:7]};
                        imm_type = IMM_CSLLI;
                        is_alu_imm = 1'b1;
                    end
                    3'b010: begin
                        opcode = 7'b0000011;
                        funct3 = 3'b010;
                        rd_addr = instr[11:7];
                        rs1_addr = 5'd2;
                        imm_type = IMM_CLW;
                        is_load = 1'b1;
                    end
                    3'b011: begin
                        opcode = 7'b0000011;
                        funct3 = 3'b011;
                        rd_addr = instr[11:7];
                        rs1_addr = 5'd2;
                        imm_type = IMM_CLD;
                        is_load = 1'b1;
                    end
                    3'b100: begin
                        rd_addr = instr[11:7];
                        rs1_addr = instr[11:7];
                        rs2_addr = instr[6:2];
                        case ({instr[12], (instr[6:2] == 5'b0)})
                            2'b00: begin
                                opcode = 7'b0010011;
                                funct3 = 3'b000;
                                rs1_addr = instr[6:2];
                                is_alu_imm = 1'b1;
                            end
                            2'b10: begin
                                opcode = 7'b1100111;
                                rd_addr = 5'b0;
                                is_jump = 1'b1;
                            end
                            2'b01: begin
                                opcode = 7'b1100111;
                                rd_addr = 5'd1;
                                is_jump = 1'b1;
                            end
                            default: begin
                                if (instr[11:7] == 5'b0) begin
                                    opcode = 7'b1110011;
                                    funct3 = 3'b000;
                                    is_system = 1'b1;
                                end else begin
                                    opcode = 7'b0110011;
                                    funct3 = 3'b000;
                                    funct7 = 7'b0000000;
                                    is_alu_rr = 1'b1;
                                end
                            end
                        endcase
                    end
                    3'b110: begin
                        opcode = 7'b0100011;
                        funct3 = 3'b010;
                        rs1_addr = 5'd2;
                        rs2_addr = instr[6:2];
                        imm_type = IMM_CSS;
                        is_store = 1'b1;
                    end
                    3'b111: begin
                        opcode = 7'b0100011;
                        funct3 = 3'b011;
                        rs1_addr = 5'd2;
                        rs2_addr = instr[6:2];
                        imm_type = IMM_CSS;
                        is_store = 1'b1;
                    end
                    default: begin
                        opcode = 7'b0;
                    end
                endcase
            end
            default: begin
                opcode = 7'b0;
            end
        endcase
    end else begin
        case (op)
            7'b0000011: begin
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm_type = IMM_I;
                is_load = 1'b1;
            end
            7'b0100011: begin
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                imm_type = IMM_S;
                is_store = 1'b1;
            end
            7'b1100011: begin
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                imm_type = IMM_B;
                is_branch = 1'b1;
            end
            7'b1100111: begin
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm_type = IMM_I;
                is_jump = 1'b1;
            end
            7'b1101111: begin
                rd_addr = instr[11:7];
                imm_type = IMM_J;
                is_jump = 1'b1;
            end
            7'b0010111: begin
                rd_addr = instr[11:7];
                imm_type = IMM_U;
                is_auipc = 1'b1;
            end
            7'b0110111: begin
                rd_addr = instr[11:7];
                imm_type = IMM_U;
                is_lui = 1'b1;
            end
            7'b0010011: begin
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm_type = IMM_I;
                is_alu_imm = 1'b1;
            end
            7'b0011011: begin
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm_type = IMM_I;
                is_alu_imm = 1'b1;
            end
            7'b0110011: begin
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
            7'b0111011: begin
                rs1_addr = instr[19:15];
                rs2_addr = instr[24:20];
                rd_addr = instr[11:7];
                is_alu_rr = 1'b1;
            end
            7'b1110011: begin
                rs1_addr = instr[19:15];
                rd_addr = instr[11:7];
                imm_type = IMM_SYS;
                if (f3 != 3'b000) begin
                    is_csr = 1'b1;
                    csr_addr = instr[31:20];
                    funct3 = f3;
                end else begin
                    is_system = 1'b1;
                end
            end
            default: begin
                opcode = 7'b0;
            end
        endcase
    end
end

endmodule