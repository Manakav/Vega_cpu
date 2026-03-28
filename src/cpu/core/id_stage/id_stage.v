// ============================================================================
// ID Stage (译码阶段)
// 包含Decoder、寄存器堆读端口、立即数生成、控制信号生成
// ============================================================================

module id_stage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64,
    parameter REG_ADDR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  stall,
    input  wire                  flush,
    
    // 输入来自IF阶段
    input  wire [ADDR_WIDTH-1:0] pc_i,
    input  wire [31:0]           instr_i,
    input  wire                  valid_i,
    
    // 寄存器堆接口
    output wire [REG_ADDR_WIDTH-1:0] rs1_addr_o,
    output wire [REG_ADDR_WIDTH-1:0] rs2_addr_o,
    input  wire [DATA_WIDTH-1:0] rs1_data_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_i,
    
    // 前递数据输入
    input  wire [DATA_WIDTH-1:0] forward_rs1,
    input  wire [DATA_WIDTH-1:0] forward_rs2,
    input  wire [1:0]            forward_sel,
    
    // 输出到EX阶段
    output reg  [ADDR_WIDTH-1:0] pc_o,
    output reg  [31:0]           instr_o,
    output reg  [DATA_WIDTH-1:0] rs1_data_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_o,
    output reg  [DATA_WIDTH-1:0] imm_o,
    output reg  [4:0]            rd_addr_o,
    output reg                   valid_o,
    
    // 控制信号输出
    output reg  [3:0]            alu_op_o,
    output reg                   alu_src1_sel_o,
    output reg                   alu_src2_sel_o,
    output reg                   mem_read_en_o,
    output reg                   mem_write_en_o,
    output reg  [2:0]            mem_size_o,
    output reg                   reg_write_en_o,
    output reg  [1:0]            wb_sel_o,
    output reg                   is_branch_o,
    output reg                   is_jump_o
);

wire [4:0] rs1_addr;
wire [4:0] rs2_addr;
wire [4:0] rd_addr;
wire [63:0] imm;
wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;
wire is_compressed, is_branch, is_jump, is_load, is_store;
wire is_alu_imm, is_alu_rr, is_lui, is_auipc, is_system;

decoder u_decoder (
    .instr(instr_i),
    .valid(valid_i),
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

assign rs1_addr_o = rs1_addr;
assign rs2_addr_o = rs2_addr;

// 译码级前递：在进入 EX 前可对源操作数进行一次替换
wire [63:0] rs1_data_pre = (forward_sel == 2'b01) ? forward_rs1 : 
                            (forward_sel == 2'b10) ? forward_rs2 : rs1_data_i;
wire [63:0] rs2_data_pre = (forward_sel == 2'b01) ? forward_rs1 :
                            (forward_sel == 2'b10) ? forward_rs2 : rs2_data_i;

always @(*) begin
    if (!rst_n || flush) begin
        // flush 时输出气泡并清零控制信号
        pc_o = 64'b0;
        instr_o = 32'b0;
        rs1_data_o = 64'b0;
        rs2_data_o = 64'b0;
        imm_o = 64'b0;
        rd_addr_o = 5'b0;
        valid_o = 1'b0;
        alu_op_o = 4'b0;
        alu_src1_sel_o = 1'b0;
        alu_src2_sel_o = 1'b0;
        mem_read_en_o = 1'b0;
        mem_write_en_o = 1'b0;
        mem_size_o = 3'b0;
        reg_write_en_o = 1'b0;
        wb_sel_o = 2'b0;
        is_branch_o = 1'b0;
        is_jump_o = 1'b0;
    end else if (!stall && valid_i) begin
        // 正常译码推进
        pc_o = pc_i;
        instr_o = instr_i;
        rs1_data_o = rs1_data_pre;
        rs2_data_o = rs2_data_pre;
        imm_o = imm;
        rd_addr_o = rd_addr;
        valid_o = valid_i;
        is_branch_o = is_branch;
        is_jump_o = is_jump;
        
        // 按 opcode 生成执行/访存/写回控制信号
        case (opcode)
            7'b0000011: begin // LOAD
                alu_op_o = 4'b0000;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b1;
                mem_write_en_o = 1'b0;
                mem_size_o = funct3;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b01;
            end
            
            7'b0100011: begin // STORE
                alu_op_o = 4'b0000;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b1;
                mem_size_o = funct3;
                reg_write_en_o = 1'b0;
                wb_sel_o = 2'b00;
            end
            
            7'b1100011: begin // BRANCH
                alu_op_o = 4'b0000;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b0;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b0;
                wb_sel_o = 2'b00;
            end
            
            7'b1100111: begin // JALR
                alu_op_o = 4'b0000;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b10;
            end
            
            7'b1101111: begin // JAL
                alu_op_o = 4'b1100;
                alu_src1_sel_o = 1'b1;
                alu_src2_sel_o = 1'b0;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b10;
            end
            
            7'b0010111: begin // AUIPC
                alu_op_o = 4'b1100;
                alu_src1_sel_o = 1'b1;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b00;
            end
            
            7'b0110111: begin // LUI
                alu_op_o = 4'b1010;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b00;
            end
            
            7'b0010011: begin // OP-IMM
                alu_op_o = {funct7[5], funct3};
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b1;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b00;
            end
            
            7'b0110011: begin // OP (R-type)
                alu_op_o = {funct7[5], funct3};
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b0;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b1;
                wb_sel_o = 2'b00;
            end
            
            7'b1110011: begin // SYSTEM
                alu_op_o = 4'b0000;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b0;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = (funct3 != 3'b000);
                wb_sel_o = 2'b00;
            end
            
            default: begin
                alu_op_o = 4'b0;
                alu_src1_sel_o = 1'b0;
                alu_src2_sel_o = 1'b0;
                mem_read_en_o = 1'b0;
                mem_write_en_o = 1'b0;
                mem_size_o = 3'b0;
                reg_write_en_o = 1'b0;
                wb_sel_o = 2'b0;
            end
        endcase
    end else begin
        valid_o = 1'b0;
    end
end

endmodule