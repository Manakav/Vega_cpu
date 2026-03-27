// ============================================================================
// 指令译码器 (Instruction Decoder)
// 支持RV64GC指令集：RVI, RVM, RVC
// ============================================================================

module decoder (
    input  wire [31:0] instr,
    input  wire        valid,
    
    output reg  [4:0] rs1_addr,
    output reg  [4:0] rs2_addr,
    output reg  [4:0] rd_addr,
    output reg  [63:0] imm,
    output reg  [6:0] opcode,
    output reg  [2:0] funct3,
    output reg  [6:0] funct7,
    output reg         is_compressed,
    output reg         is_branch,
    output reg         is_jump,
    output reg         is_load,
    output reg         is_store,
    output reg         is_alu_imm,
    output reg         is_alu_rr,
    output reg         is_lui,
    output reg         is_auipc,
    output reg         is_system
);

wire [6:0] op = instr[6:0];
wire [2:0] f3 = instr[14:12];
wire [6:0] f7 = instr[31:25];

always @(*) begin
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
    is_lui = 1'b0;
    is_auipc = 1'b0;
    is_system = 1'b0;
    
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
                        rs2_addr = {2'b01, instr[4:2]};
                        rd_addr = {2'b01, instr[9:7]};
                        imm = {{59{1'b0}}, instr[12], instr[11:5]};
                    end
                    3'b010: begin
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr = {2'b01, instr[9:7]};
                        imm = {{57{1'b0}}, instr[12], instr[11:10], instr[6:5], instr[4:3], instr[8:7]};
                    end
                    3'b110: begin
                        rs2_addr = {2'b01, instr[4:2]};
                        rs1_addr = {2'b01, instr[9:7]};
                        imm = {{58{1'b0}}, instr[12], instr[11:5]};
                    end
                endcase
            end
            2'b01: begin
                case (instr[15:13])
                    3'b000: begin
                        rd_addr = {2'b01, instr[9:7]};
                        rs1_addr = {2'b01, instr[9:7]};
                        imm = {{59{1'b0}}, instr[12], instr[11:5]};
                    end
                    3'b001: begin
                        rd_addr = {2'b01, instr[9:7]};
                        rs1_addr = {2'b01, instr[9:7]};
                        imm = {{59{1'b0}}, instr[12], instr[11:5]};
                    end
                    3'b010: begin
                        rs1_addr = {2'b01, instr[9:7]};
                        rd_addr = {2'b01, instr[11:7]};
                        imm = {{57{1'b0}}, instr[12], instr[11:10], instr[4:3], instr[8:7]};
                    end
                    3'b100: begin
                        rd_addr = {2'b01, instr[9:7]};
                        rs1_addr = {2'b10, instr[6:2]};
                        rs2_addr = 5'b0;
                    end
                    3'b110: begin
                        rs2_addr = {2'b01, instr[4:2]};
                        rs1_addr = {2'b01, instr[9:7]};
                        imm = {{58{1'b0}}, instr[12], instr[11:5]};
                    end
                endcase
            end
            2'b10: begin
                case (instr[15:13])
                    3'b000: begin
                        rs1_addr = {2'b10, instr[9:7]};
                        rs2_addr = {2'b10, instr[4:2]};
                        rd_addr = {2'b10, instr[9:7]};
                    end
                    3'b001: begin
                        rs1_addr = {2'b10, instr[9:7]};
                        rd_addr = {2'b10, instr[9:7]};
                        imm = {52'b0, instr[12:5]};
                    end
                    3'b010: begin
                        rs1_addr = {2'b10, instr[9:7]};
                        rd_addr = {2'b10, instr[9:7]};
                        imm = {52'b0, instr[12:5]};
                    end
                    3'b011: begin
                        rd_addr = {2'b10, instr[9:7]};
                        imm = {52'b0, instr[12:5]};
                    end
                    3'b100: begin
                        rs1_addr = {2'b10, instr[9:7]};
                        rs2_addr = {2'b10, instr[4:2]};
                        rd_addr = {2'b10, instr[9:7]};
                    end
                    3'b110: begin
                        rs1_addr = {2'b10, instr[9:7]};
                        rs2_addr = {2'b10, instr[4:2]};
                        rd_addr = {2'b10, instr[9:7]};
                    end
                endcase
            end
        endcase
    end else begin
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
                is_alu_rr = 1'b1;
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