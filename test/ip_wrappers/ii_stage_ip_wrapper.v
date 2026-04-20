// ============================================================================
// IP Wrapper 模板：用于替代被替换为 IP 核的模块
// 用法：将此模板复制为 <module_name>_ip_wrapper.v，替换为实际 IP 接口
// 在仿真中，wrapper 内部例化行为模型（BV）或空壳；
// 在综合/FPGA 中，wrapper 内部例化实际 IP 黑盒
// ============================================================================

// ============================================================================
// 示例：ii_stage IP wrapper（如果 ii_stage 被替换为 IP）
// ============================================================================
module ii_stage_ip_wrapper #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  flush,
    input  wire [ADDR_WIDTH-1:0] pc_w1_i,
    input  wire [4:0]            rs1_addr_w1_i,
    input  wire [4:0]            rs2_addr_w1_i,
    input  wire [4:0]            rd_addr_w1_i,
    input  wire [DATA_WIDTH-1:0] imm_w1_i,
    input  wire [3:0]            alu_op_w1_i,
    input  wire                  alu_src1_sel_w1_i,
    input  wire                  alu_src2_sel_w1_i,
    input  wire                  mem_read_en_w1_i,
    input  wire                  mem_write_en_w1_i,
    input  wire [2:0]            mem_size_w1_i,
    input  wire                  reg_write_en_w1_i,
    input  wire [1:0]            wb_sel_w1_i,
    input  wire                  is_branch_w1_i,
    input  wire                  is_jump_w1_i,
    input  wire                  is_system_w1_i,
    input  wire                  is_mem_op_w1_i,
    input  wire                  is_muldiv_w1_i,
    input  wire [2:0]            muldiv_funct3_w1_i,
    input  wire                  uses_rs1_w1_i,
    input  wire                  uses_rs2_w1_i,
    input  wire                  valid_w1_i,
    input  wire [ADDR_WIDTH-1:0] pc_w2_i,
    input  wire [4:0]            rs1_addr_w2_i,
    input  wire [4:0]            rs2_addr_w2_i,
    input  wire [4:0]            rd_addr_w2_i,
    input  wire [DATA_WIDTH-1:0] imm_w2_i,
    input  wire [3:0]            alu_op_w2_i,
    input  wire                  alu_src1_sel_w2_i,
    input  wire                  alu_src2_sel_w2_i,
    input  wire                  mem_read_en_w2_i,
    input  wire                  mem_write_en_w2_i,
    input  wire [2:0]            mem_size_w2_i,
    input  wire                  reg_write_en_w2_i,
    input  wire [1:0]            wb_sel_w2_i,
    input  wire                  is_branch_w2_i,
    input  wire                  is_jump_w2_i,
    input  wire                  is_system_w2_i,
    input  wire                  is_mem_op_w2_i,
    input  wire                  is_muldiv_w2_i,
    input  wire [2:0]            muldiv_funct3_w2_i,
    input  wire                  uses_rs1_w2_i,
    input  wire                  uses_rs2_w2_i,
    input  wire                  valid_w2_i,
    input  wire                  predict_taken_i,
    input  wire [ADDR_WIDTH-1:0] predict_target_i,
    output wire [4:0]            rf_raddr1,
    input  wire [DATA_WIDTH-1:0] rf_rdata1,
    output wire [4:0]            rf_raddr2,
    input  wire [DATA_WIDTH-1:0] rf_rdata2,
    output wire [4:0]            rf_raddr3,
    input  wire [DATA_WIDTH-1:0] rf_rdata3,
    output wire [4:0]            rf_raddr4,
    input  wire [DATA_WIDTH-1:0] rf_rdata4,
    output wire                  stall_dual,
    output reg  [ADDR_WIDTH-1:0] pc_w1_o,
    output reg  [4:0]            rs1_addr_w1_o,
    output reg  [4:0]            rs2_addr_w1_o,
    output reg  [DATA_WIDTH-1:0] rs1_data_w1_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w1_o,
    output reg  [4:0]            rd_addr_w1_o,
    output reg  [DATA_WIDTH-1:0] imm_w1_o,
    output reg  [3:0]            alu_op_w1_o,
    output reg                   alu_src1_sel_w1_o,
    output reg                   alu_src2_sel_w1_o,
    output reg                   mem_read_en_w1_o,
    output reg                   mem_write_en_w1_o,
    output reg  [2:0]            mem_size_w1_o,
    output reg                   reg_write_en_w1_o,
    output reg  [1:0]            wb_sel_w1_o,
    output reg                   is_branch_w1_o,
    output reg                   is_jump_w1_o,
    output reg                   is_muldiv_w1_o,
    output reg  [2:0]            muldiv_funct3_w1_o,
    output reg                   valid_w1_o,
    output reg  [ADDR_WIDTH-1:0] pc_w2_o,
    output reg  [4:0]            rs1_addr_w2_o,
    output reg  [4:0]            rs2_addr_w2_o,
    output reg  [DATA_WIDTH-1:0] rs1_data_w2_o,
    output reg  [DATA_WIDTH-1:0] rs2_data_w2_o,
    output reg  [4:0]            rd_addr_w2_o,
    output reg  [DATA_WIDTH-1:0] imm_w2_o,
    output reg  [3:0]            alu_op_w2_o,
    output reg                   alu_src1_sel_w2_o,
    output reg                   alu_src2_sel_w2_o,
    output reg                   mem_read_en_w2_o,
    output reg                   mem_write_en_w2_o,
    output reg  [2:0]            mem_size_w2_o,
    output reg                   reg_write_en_w2_o,
    output reg  [1:0]            wb_sel_w2_o,
    output reg                   is_branch_w2_o,
    output reg                   is_jump_w2_o,
    output reg                   is_muldiv_w2_o,
    output reg  [2:0]            muldiv_funct3_w2_o,
    output reg                   valid_w2_o,
    output reg                   predict_taken_o,
    output reg  [ADDR_WIDTH-1:0] predict_target_o
);

`ifdef USE_IP_II_STAGE
// ---- 综合路径：例化实际 IP 黑盒 ----
// 请在下方替换为实际 IP 的例化名和接口信号
// ii_stage_ip u_ip (
//     .clk(clk), .rst_n(rst_n), .flush(flush),
//     ...  // 逐信号映射到 IP 端口
// );

// 占位：如果 IP 未提供，则输出全零
initial begin
    $display("[WARN] ii_stage_ip_wrapper: IP black-box placeholder active");
end

`else
// ---- 仿真路径：例化原始 RTL 行为模型 ----
ii_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_rtl (
    .clk(clk), .rst_n(rst_n), .flush(flush),
    .pc_w1_i(pc_w1_i), .rs1_addr_w1_i(rs1_addr_w1_i), .rs2_addr_w1_i(rs2_addr_w1_i),
    .rd_addr_w1_i(rd_addr_w1_i), .imm_w1_i(imm_w1_i), .alu_op_w1_i(alu_op_w1_i),
    .alu_src1_sel_w1_i(alu_src1_sel_w1_i), .alu_src2_sel_w1_i(alu_src2_sel_w1_i),
    .mem_read_en_w1_i(mem_read_en_w1_i), .mem_write_en_w1_i(mem_write_en_w1_i),
    .mem_size_w1_i(mem_size_w1_i), .reg_write_en_w1_i(reg_write_en_w1_i),
    .wb_sel_w1_i(wb_sel_w1_i), .is_branch_w1_i(is_branch_w1_i), .is_jump_w1_i(is_jump_w1_i),
    .is_system_w1_i(is_system_w1_i), .is_mem_op_w1_i(is_mem_op_w1_i),
    .is_muldiv_w1_i(is_muldiv_w1_i), .muldiv_funct3_w1_i(muldiv_funct3_w1_i),
    .uses_rs1_w1_i(uses_rs1_w1_i), .uses_rs2_w1_i(uses_rs2_w1_i), .valid_w1_i(valid_w1_i),
    .pc_w2_i(pc_w2_i), .rs1_addr_w2_i(rs1_addr_w2_i), .rs2_addr_w2_i(rs2_addr_w2_i),
    .rd_addr_w2_i(rd_addr_w2_i), .imm_w2_i(imm_w2_i), .alu_op_w2_i(alu_op_w2_i),
    .alu_src1_sel_w2_i(alu_src1_sel_w2_i), .alu_src2_sel_w2_i(alu_src2_sel_w2_i),
    .mem_read_en_w2_i(mem_read_en_w2_i), .mem_write_en_w2_i(mem_write_en_w2_i),
    .mem_size_w2_i(mem_size_w2_i), .reg_write_en_w2_i(reg_write_en_w2_i),
    .wb_sel_w2_i(wb_sel_w2_i), .is_branch_w2_i(is_branch_w2_i), .is_jump_w2_i(is_jump_w2_i),
    .is_system_w2_i(is_system_w2_i), .is_mem_op_w2_i(is_mem_op_w2_i),
    .is_muldiv_w2_i(is_muldiv_w2_i), .muldiv_funct3_w2_i(muldiv_funct3_w2_i),
    .uses_rs1_w2_i(uses_rs1_w2_i), .uses_rs2_w2_i(uses_rs2_w2_i), .valid_w2_i(valid_w2_i),
    .predict_taken_i(predict_taken_i), .predict_target_i(predict_target_i),
    .rf_raddr1(rf_raddr1), .rf_rdata1(rf_rdata1),
    .rf_raddr2(rf_raddr2), .rf_rdata2(rf_rdata2),
    .rf_raddr3(rf_raddr3), .rf_rdata3(rf_rdata3),
    .rf_raddr4(rf_raddr4), .rf_rdata4(rf_rdata4),
    .stall_dual(stall_dual),
    .pc_w1_o(pc_w1_o), .rs1_addr_w1_o(rs1_addr_w1_o), .rs2_addr_w1_o(rs2_addr_w1_o),
    .rs1_data_w1_o(rs1_data_w1_o), .rs2_data_w1_o(rs2_data_w1_o),
    .rd_addr_w1_o(rd_addr_w1_o), .imm_w1_o(imm_w1_o), .alu_op_w1_o(alu_op_w1_o),
    .alu_src1_sel_w1_o(alu_src1_sel_w1_o), .alu_src2_sel_w1_o(alu_src2_sel_w1_o),
    .mem_read_en_w1_o(mem_read_en_w1_o), .mem_write_en_w1_o(mem_write_en_w1_o),
    .mem_size_w1_o(mem_size_w1_o), .reg_write_en_w1_o(reg_write_en_w1_o),
    .wb_sel_w1_o(wb_sel_w1_o), .is_branch_w1_o(is_branch_w1_o), .is_jump_w1_o(is_jump_w1_o),
    .is_muldiv_w1_o(is_muldiv_w1_o), .muldiv_funct3_w1_o(muldiv_funct3_w1_o), .valid_w1_o(valid_w1_o),
    .pc_w2_o(pc_w2_o), .rs1_addr_w2_o(rs1_addr_w2_o), .rs2_addr_w2_o(rs2_addr_w2_o),
    .rs1_data_w2_o(rs1_data_w2_o), .rs2_data_w2_o(rs2_data_w2_o),
    .rd_addr_w2_o(rd_addr_w2_o), .imm_w2_o(imm_w2_o), .alu_op_w2_o(alu_op_w2_o),
    .alu_src1_sel_w2_o(alu_src1_sel_w2_o), .alu_src2_sel_w2_o(alu_src2_sel_w2_o),
    .mem_read_en_w2_o(mem_read_en_w2_o), .mem_write_en_w2_o(mem_write_en_w2_o),
    .mem_size_w2_o(mem_size_w2_o), .reg_write_en_w2_o(reg_write_en_w2_o),
    .wb_sel_w2_o(wb_sel_w2_o), .is_branch_w2_o(is_branch_w2_o), .is_jump_w2_o(is_jump_w2_o),
    .is_muldiv_w2_o(is_muldiv_w2_o), .muldiv_funct3_w2_o(muldiv_funct3_w2_o), .valid_w2_o(valid_w2_o),
    .predict_taken_o(predict_taken_o), .predict_target_o(predict_target_o)
);
`endif

endmodule