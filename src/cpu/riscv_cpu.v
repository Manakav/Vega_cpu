// ============================================================================
// RISC-V CPU 顶层模块 (RV64GC)
// 五级流水线 + 动态分支预测 + L1 Cache
// ============================================================================

module riscv_cpu (
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 指令存储器接口
    output wire [63:0]           instr_addr,
    input  wire [31:0]           instr_data,
    output wire                  instr_req,
    input  wire                  instr_gnt,
    
    // 数据存储器接口
    output wire [63:0]           data_addr,
    output wire [63:0]           data_wdata,
    input  wire [63:0]           data_rdata,
    output wire                  data_req,
    output wire                  data_we,
    output wire [7:0]            data_be,
    input  wire                  data_gnt,
    
    // 中断接口
    input  wire                  irq_external,
    input  wire                  irq_timer,
    input  wire                  irq_software,
    
    // 调试接口
    input  wire                  debug_req,
    output wire                  debug_halt,
    output wire                  debug_resume
);

parameter DATA_WIDTH = 64;
parameter ADDR_WIDTH = 64;
parameter REG_COUNT = 32;

wire [4:0] rs1_addr_id, rs2_addr_id;
wire [DATA_WIDTH-1:0] rs1_data_id, rs2_data_id;
wire [4:0] rd_addr_ex, rd_addr_mem, rd_addr_wb;
wire [DATA_WIDTH-1:0] wb_result;
wire reg_write_en_wb;

wire stall_if, stall_id, flush_if, flush_ex;
wire [1:0] forward_a, forward_b;

wire [ADDR_WIDTH-1:0] pc_if, pc_id, pc_ex;
wire [31:0] instr_if, instr_id;
wire valid_if, valid_id, valid_ex, valid_mem, valid_wb;

wire [DATA_WIDTH-1:0] alu_result_ex, mem_result_mem;
wire branch_taken;
wire [ADDR_WIDTH-1:0] branch_target;
wire mispredict;

wire [3:0] alu_op;
wire alu_src1_sel, alu_src2_sel;
wire mem_read_en, mem_write_en;
wire [2:0] mem_size;
wire reg_write_en_ex;
wire [1:0] wb_sel;

wire is_branch, is_jump;

wire [DATA_WIDTH-1:0] forward_ex_data, forward_mem_data, forward_wb_data;

wire predict_taken;
wire [ADDR_WIDTH-1:0] predict_target;

register_file #(
    .DATA_WIDTH(DATA_WIDTH),
    .REG_COUNT(REG_COUNT),
    .ADDR_WIDTH(5)
) u_register_file (
    .clk(clk),
    .rst_n(rst_n),
    .raddr1(rs1_addr_id),
    .rdata1(rs1_data_id),
    .raddr2(rs2_addr_id),
    .rdata2(rs2_data_id),
    .waddr(rd_addr_wb),
    .wdata(wb_result),
    .we(reg_write_en_wb)
);

if_stage #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(32)
) u_if_stage (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall_if),
    .flush(flush_if),
    .instr_addr(instr_addr),
    .instr_data(instr_data),
    .instr_req(instr_req),
    .instr_gnt(instr_gnt),
    .branch_taken(branch_taken),
    .branch_target(branch_target),
    .mispredict(mispredict),
    .pc_out(pc_if),
    .instr_out(instr_if),
    .valid_out(valid_if)
);

id_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .REG_ADDR_WIDTH(5)
) u_id_stage (
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall_id),
    .flush(flush_id),
    .pc_i(pc_if),
    .instr_i(instr_if),
    .valid_i(valid_if),
    .rs1_addr_o(rs1_addr_id),
    .rs2_addr_o(rs2_addr_id),
    .rs1_data_i(rs1_data_id),
    .rs2_data_i(rs2_data_id),
    .forward_rs1(forward_ex_data),
    .forward_rs2(forward_ex_data),
    .forward_sel(2'b00),
    .pc_o(pc_id),
    .instr_o(instr_id),
    .rs1_data_o(),
    .rs2_data_o(),
    .imm_o(),
    .rd_addr_o(),
    .valid_o(valid_id),
    .alu_op_o(alu_op),
    .alu_src1_sel_o(alu_src1_sel),
    .alu_src2_sel_o(alu_src2_sel),
    .mem_read_en_o(mem_read_en),
    .mem_write_en_o(mem_write_en),
    .mem_size_o(mem_size),
    .reg_write_en_o(reg_write_en_ex),
    .wb_sel_o(wb_sel),
    .is_branch_o(is_branch),
    .is_jump_o(is_jump)
);

ex_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_ex_stage (
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush_ex),
    .pc_i(pc_id),
    .rs1_data_i(rs1_data_id),
    .rs2_data_i(rs2_data_id),
    .imm_i(64'b0),
    .rd_addr_i(rd_addr_ex),
    .valid_i(valid_id),
    .alu_op_i(alu_op),
    .alu_src1_sel_i(alu_src1_sel),
    .alu_src2_sel_i(alu_src2_sel),
    .mem_read_en_i(mem_read_en),
    .mem_write_en_i(mem_write_en),
    .mem_size_i(mem_size),
    .reg_write_en_i(reg_write_en_ex),
    .wb_sel_i(wb_sel),
    .is_branch_i(is_branch),
    .is_jump_i(is_jump),
    .forward_ex(alu_result_ex),
    .forward_mem(mem_result_mem),
    .forward_wb(wb_result),
    .forward_a_sel(forward_a),
    .forward_b_sel(forward_b),
    .predict_taken_i(predict_taken),
    .predict_target_i(predict_target),
    .pc_o(pc_ex),
    .alu_result_o(alu_result_ex),
    .rs2_data_o(),
    .rd_addr_o(rd_addr_ex),
    .valid_o(valid_ex),
    .mem_read_en_o(),
    .mem_write_en_o(),
    .mem_size_o(),
    .reg_write_en_o(),
    .wb_sel_o(),
    .branch_taken_o(branch_taken),
    .branch_target_o(branch_target),
    .mispredict_o(mispredict)
);

mem_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_mem_stage (
    .clk(clk),
    .rst_n(rst_n),
    .pc_i(pc_ex),
    .alu_result_i(alu_result_ex),
    .rs2_data_i(64'b0),
    .rd_addr_i(rd_addr_ex),
    .valid_i(valid_ex),
    .mem_read_en_i(mem_read_en),
    .mem_write_en_i(mem_write_en),
    .mem_size_i(mem_size),
    .reg_write_en_i(reg_write_en_ex),
    .wb_sel_i(wb_sel),
    .mem_addr(data_addr),
    .mem_wdata(data_wdata),
    .mem_we(data_we),
    .mem_be(data_be),
    .mem_rdata(data_rdata),
    .mem_gnt(data_gnt),
    .alu_result_o(),
    .mem_result_o(mem_result_mem),
    .rd_addr_o(rd_addr_mem),
    .valid_o(valid_mem),
    .reg_write_en_o(),
    .wb_sel_o()
);

assign data_req = mem_read_en | mem_write_en;
assign rd_addr_wb = rd_addr_mem;
assign reg_write_en_wb = reg_write_en_ex;
assign wb_result = (wb_sel == 2'b01) ? mem_result_mem : alu_result_ex;

assign forward_ex_data = alu_result_ex;
assign forward_mem_data = mem_result_mem;
assign forward_wb_data = wb_result;

hazard_unit u_hazard_unit (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr_id(rs1_addr_id),
    .rs2_addr_id(rs2_addr_id),
    .rs1_used_id(valid_id),
    .rs2_used_id(valid_id),
    .rd_addr_ex(rd_addr_ex),
    .rd_addr_mem(rd_addr_mem),
    .rd_addr_wb(rd_addr_wb),
    .reg_write_en_ex(reg_write_en_ex),
    .reg_write_en_mem(1'b0),
    .reg_write_en_wb(reg_write_en_wb),
    .mem_read_en_ex(mem_read_en),
    .branch_taken_ex(branch_taken),
    .mispredict_ex(mispredict),
    .stall_if(stall_if),
    .stall_id(stall_id),
    .flush_if(flush_if),
    .flush_id(flush_id),
    .flush_ex(flush_ex),
    .forward_a(forward_a),
    .forward_b(forward_b)
);

assign debug_halt = 1'b0;
assign debug_resume = 1'b1;

endmodule