// ============================================================================
// EX Stage (执行阶段)
// 包含ALU、乘除法、分支判断、前递选择
// ============================================================================

module ex_stage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  flush,
    
    // 输入来自ID阶段
    input  wire [ADDR_WIDTH-1:0] pc_i,
    input  wire [DATA_WIDTH-1:0] rs1_data_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_i,
    input  wire [DATA_WIDTH-1:0] imm_i,
    input  wire [4:0]            rd_addr_i,
    input  wire                  valid_i,
    
    // 控制信号输入
    input  wire [3:0]            alu_op_i,
    input  wire                  alu_src1_sel_i,
    input  wire                  alu_src2_sel_i,
    input  wire                  mem_read_en_i,
    input  wire                  mem_write_en_i,
    input  wire [2:0]            mem_size_i,
    input  wire                  reg_write_en_i,
    input  wire [1:0]            wb_sel_i,
    input  wire                  is_branch_i,
    input  wire                  is_jump_i,
    
    // 前递数据
    input  wire [DATA_WIDTH-1:0] forward_ex,
    input  wire [DATA_WIDTH-1:0] forward_mem,
    input  wire [DATA_WIDTH-1:0] forward_wb,
    input  wire [1:0]            forward_a_sel,
    input  wire [1:0]            forward_b_sel,
    
    // 分支预测输入
    input  wire                  predict_taken_i,
    input  wire [ADDR_WIDTH-1:0] predict_target_i,
    
    // 输出到MEM阶段
    output reg  [ADDR_WIDTH-1:0] pc_o,
    output reg  [DATA_WIDTH-1:0] alu_result_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_o,
    output reg  [4:0]            rd_addr_o,
    output reg                   valid_o,
    output reg                   mem_read_en_o,
    output reg                   mem_write_en_o,
    output reg  [2:0]            mem_size_o,
    output reg                   reg_write_en_o,
    output reg  [1:0]            wb_sel_o,
    
    // 分支结果输出
    output reg                   branch_taken_o,
    output reg  [ADDR_WIDTH-1:0] branch_target_o,
    output reg                   mispredict_o
);

wire [DATA_WIDTH-1:0] operand_a;
wire [DATA_WIDTH-1:0] operand_b;
wire [DATA_WIDTH-1:0] alu_result;
wire                  alu_zero;
wire                  alu_negative;
wire                  alu_overflow;

// A/B 操作数多路选择：先看是否选 PC/IMM，再看前递来源
assign operand_a = alu_src1_sel_i ? pc_i : 
                   (forward_a_sel == 2'b01) ? forward_ex :
                   (forward_a_sel == 2'b10) ? forward_mem :
                   (forward_a_sel == 2'b11) ? forward_wb : rs1_data_i;

assign operand_b = alu_src2_sel_i ? imm_i : 
                   (forward_b_sel == 2'b01) ? forward_ex :
                   (forward_b_sel == 2'b10) ? forward_mem :
                   (forward_b_sel == 2'b11) ? forward_wb : rs2_data_i;

alu u_alu (
    .alu_op(alu_op_i),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .result(alu_result),
    .zero(alu_zero),
    .negative(alu_negative),
    .overflow(alu_overflow)
);

reg branch_taken;
reg [ADDR_WIDTH-1:0] branch_target;

always @(*) begin
    // 缺省为不跳转且顺序执行
    branch_taken = 1'b0;
    branch_target = pc_i + 4;
    
    if (is_branch_i) begin
        // 复用 mem_size_i 传递分支比较类型编码
        case (mem_size_i)
            3'b000: branch_taken = (rs1_data_i == rs2_data_i);   // BEQ
            3'b001: branch_taken = (rs1_data_i != rs2_data_i);   // BNE
            3'b100: branch_taken = ($signed(rs1_data_i) < $signed(rs2_data_i));  // BLT
            3'b101: branch_taken = ($signed(rs1_data_i) >= $signed(rs2_data_i)); // BGE
            3'b110: branch_taken = (rs1_data_i < rs2_data_i);    // BLTU
            3'b111: branch_taken = (rs1_data_i >= rs2_data_i);   // BGEU
        endcase
        branch_target = pc_i + imm_i;
    end else if (is_jump_i && wb_sel_i == 2'b10) begin
        // JAL/JALR 均视为必跳转
        branch_taken = 1'b1;
        branch_target = (alu_op_i == 4'b1100) ? (pc_i + imm_i) : (rs1_data_i + imm_i);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        // flush 直接注入气泡，阻断错误控制流继续传播
        pc_o <= 64'b0;
        alu_result_o <= 64'b0;
        rs2_data_o <= 64'b0;
        rd_addr_o <= 5'b0;
        valid_o <= 1'b0;
        mem_read_en_o <= 1'b0;
        mem_write_en_o <= 1'b0;
        mem_size_o <= 3'b0;
        reg_write_en_o <= 1'b0;
        wb_sel_o <= 2'b0;
        branch_taken_o <= 1'b0;
        branch_target_o <= 64'b0;
        mispredict_o <= 1'b0;
    end else if (valid_i) begin
        pc_o <= pc_i;
        alu_result_o <= alu_result;
        rs2_data_o <= rs2_data_i;
        rd_addr_o <= rd_addr_i;
        valid_o <= valid_i;
        mem_read_en_o <= mem_read_en_i;
        mem_write_en_o <= mem_write_en_i;
        mem_size_o <= mem_size_i;
        reg_write_en_o <= reg_write_en_i;
        wb_sel_o <= wb_sel_i;
        
        branch_taken_o <= branch_taken;
        branch_target_o <= branch_target;
        
        if (is_branch_i || is_jump_i) begin
            // 方向或目标任一不一致都判定为误预测
            mispredict_o <= (branch_taken != predict_taken_i) || 
                           (branch_taken && (branch_target != predict_target_i));
        end else begin
            mispredict_o <= 1'b0;
        end
    end
end

endmodule