// RISC-V CPU顶层设计模块
// 支持RV32I/RV64I指令集，五级流水线架构
// 作者：[项目组名称]
// 日期：[创建日期]

module riscv_cpu #(
    parameter DATA_WIDTH = 64,          // 数据位宽：64位(RV64I)
    parameter ADDR_WIDTH = 32,          // 地址位宽
    parameter REG_COUNT = 32,           // 寄存器数量
    parameter MEM_SIZE = 4096,          // 存储器大小（字节）
    parameter BTB_SIZE = 64,            // 分支目标缓冲大小
    parameter BHT_SIZE = 256            // 分支历史表大小
)(
    // 系统信号
    input  wire                     clk,
    input  wire                     rst_n,
    
    // 指令存储器接口（指令ROM）
    output wire [ADDR_WIDTH-1:0]    instr_addr,
    input  wire [DATA_WIDTH-1:0]    instr_data,
    output wire                     instr_req,
    input  wire                     instr_gnt,
    
    // 数据存储器接口（数据RAM）
    output wire [ADDR_WIDTH-1:0]    data_addr,
    output wire [DATA_WIDTH-1:0]    data_wdata,
    input  wire [DATA_WIDTH-1:0]    data_rdata,
    output wire                     data_req,
    output wire                     data_we,      // 写使能
    output wire [DATA_WIDTH/8-1:0]  data_be,      // 字节使能
    input  wire                     data_gnt,
    
    // 中断接口
    input  wire                     irq_external, // 外部中断
    input  wire                     irq_timer,    // 定时器中断
    input  wire                     irq_software, // 软件中断
    
    // 调试接口（可选）
    input  wire                     debug_req,
    output wire                     debug_halt,
    output wire                     debug_resume
);

// ============================================================================
// 内部信号声明
// ============================================================================

// 流水线寄存器信号
// IF阶段
wire [ADDR_WIDTH-1:0] pc_if;
wire [DATA_WIDTH-1:0] instr_if;
wire                  valid_if;

// ID阶段
wire [ADDR_WIDTH-1:0] pc_id;
wire [DATA_WIDTH-1:0] instr_id;
wire                  valid_id;
wire [4:0]            rs1_addr_id;
wire [4:0]            rs2_addr_id;
wire [4:0]            rd_addr_id;
wire [DATA_WIDTH-1:0] imm_id;
wire [6:0]            opcode_id;
wire [2:0]            funct3_id;
wire [6:0]            funct7_id;

// EX阶段
wire [ADDR_WIDTH-1:0] pc_ex;
wire [DATA_WIDTH-1:0] alu_result_ex;
wire [DATA_WIDTH-1:0] rs2_data_ex;
wire                  valid_ex;
wire [4:0]            rd_addr_ex;
wire                  branch_taken_ex;
wire [ADDR_WIDTH-1:0] branch_target_ex;

// MEM阶段
wire [DATA_WIDTH-1:0] mem_result_mem;
wire                  valid_mem;
wire [4:0]            rd_addr_mem;

// WB阶段
wire [DATA_WIDTH-1:0] wb_result_wb;
wire                  valid_wb;
wire [4:0]            rd_addr_wb;
wire                  reg_write_en_wb;

// 控制信号
wire                  stall_if;
wire                  stall_id;
wire                  flush_if;
wire                  flush_id;
wire                  flush_ex;

// 前递（Forwarding）信号
wire [1:0]            forward_a_ex;
wire [1:0]            forward_b_ex;

// 分支预测信号
wire                  predict_taken_if;
wire [ADDR_WIDTH-1:0] predict_target_if;
wire                  branch_mispredict_ex;

// 执行单元控制信号
wire [3:0]            alu_op_ex;
wire                  alu_src1_sel_ex;
wire                  alu_src2_sel_ex;
wire                  mem_write_en_ex;
wire                  mem_read_en_ex;
wire [2:0]            mem_size_ex;
wire                  reg_write_en_ex;
wire [1:0]            wb_sel_ex;

// ============================================================================
// 流水线实例化
// ============================================================================

// 取指阶段（IF）
if_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .BTB_SIZE(BTB_SIZE),
    .BHT_SIZE(BHT_SIZE)
) u_if_stage (
    .clk                (clk),
    .rst_n              (rst_n),
    .stall              (stall_if),
    .flush              (flush_if),
    
    // 指令存储器接口
    .instr_addr_o       (instr_addr),
    .instr_data_i       (instr_data),
    .instr_req_o        (instr_req),
    .instr_gnt_i        (instr_gnt),
    
    // 分支预测接口
    .branch_taken_i     (branch_taken_ex),
    .branch_target_i    (branch_target_ex),
    .mispredict_i       (branch_mispredict_ex),
    .predict_taken_o    (predict_taken_if),
    .predict_target_o   (predict_target_if),
    
    // 输出到ID阶段
    .pc_o               (pc_if),
    .instr_o            (instr_if),
    .valid_o            (valid_if)
);

// 译码阶段（ID）
id_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .REG_COUNT(REG_COUNT)
) u_id_stage (
    .clk                (clk),
    .rst_n              (rst_n),
    .stall              (stall_id),
    .flush              (flush_id),
    
    // 输入来自IF阶段
    .pc_i               (pc_if),
    .instr_i            (instr_if),
    .valid_i            (valid_if),
    
    // 寄存器堆读端口
    .rs1_addr_o         (rs1_addr_id),
    .rs2_addr_o         (rs2_addr_id),
    .rs1_data_i         (), // 来自寄存器堆
    .rs2_data_i         (), // 来自寄存器堆
    
    // 输出到EX阶段
    .pc_o               (pc_id),
    .instr_o            (instr_id),
    .rs1_addr_o         (),
    .rs2_addr_o         (),
    .rd_addr_o          (rd_addr_id),
    .imm_o              (imm_id),
    .opcode_o           (opcode_id),
    .funct3_o           (funct3_id),
    .funct7_o           (funct7_id),
    .valid_o            (valid_id),
    
    // 控制信号输出
    .alu_op_o           (),
    .alu_src1_sel_o     (),
    .alu_src2_sel_o     (),
    .mem_write_en_o     (),
    .mem_read_en_o      (),
    .mem_size_o         (),
    .reg_write_en_o     (),
    .wb_sel_o           (),
    .branch_op_o        ()
);

// 执行阶段（EX）
ex_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_ex_stage (
    .clk                (clk),
    .rst_n              (rst_n),
    .flush              (flush_ex),
    
    // 输入来自ID阶段
    .pc_i               (pc_id),
    .rs1_data_i         (), // 来自ID阶段或前递
    .rs2_data_i         (), // 来自ID阶段或前递
    .imm_i              (imm_id),
    .rd_addr_i          (rd_addr_id),
    .valid_i            (valid_id),
    
    // 控制信号输入
    .alu_op_i           (),
    .alu_src1_sel_i     (),
    .alu_src2_sel_i     (),
    .mem_write_en_i     (),
    .mem_read_en_i      (),
    .mem_size_i         (),
    .reg_write_en_i     (),
    .wb_sel_i           (),
    .branch_op_i        (),
    
    // 前递信号
    .forward_a_i        (forward_a_ex),
    .forward_b_i        (forward_b_ex),
    .forward_mem_i      (), // 来自MEM阶段的结果
    .forward_wb_i       (), // 来自WB阶段的结果
    
    // 分支预测
    .predict_taken_i    (predict_taken_if),
    .predict_target_i   (predict_target_if),
    
    // 输出到MEM阶段
    .alu_result_o       (alu_result_ex),
    .rs2_data_o         (rs2_data_ex),
    .rd_addr_o          (rd_addr_ex),
    .valid_o            (valid_ex),
    
    // 分支结果
    .branch_taken_o     (branch_taken_ex),
    .branch_target_o    (branch_target_ex),
    .mispredict_o       (branch_mispredict_ex),
    
    // 数据存储器接口
    .mem_addr_o         (data_addr),
    .mem_wdata_o        (data_wdata),
    .mem_write_en_o     (data_we),
    .mem_be_o           (data_be)
);

// 访存阶段（MEM）
mem_stage #(
    .DATA_WIDTH(DATA_WIDTH)
) u_mem_stage (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // 输入来自EX阶段
    .alu_result_i       (alu_result_ex),
    .rs2_data_i         (rs2_data_ex),
    .rd_addr_i          (rd_addr_ex),
    .valid_i            (valid_ex),
    .mem_write_en_i     (),
    .mem_read_en_i      (),
    .mem_size_i         (),
    
    // 数据存储器接口
    .mem_data_i         (data_rdata),
    .mem_gnt_i          (data_gnt),
    .mem_req_o          (data_req),
    
    // 输出到WB阶段
    .mem_result_o       (mem_result_mem),
    .rd_addr_o          (rd_addr_mem),
    .valid_o            (valid_mem)
);

// 写回阶段（WB）
wb_stage #(
    .DATA_WIDTH(DATA_WIDTH),
    .REG_COUNT(REG_COUNT)
) u_wb_stage (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // 输入来自MEM阶段
    .alu_result_i       (alu_result_ex), // 直接来自EX阶段用于前递
    .mem_result_i       (mem_result_mem),
    .rd_addr_i          (rd_addr_mem),
    .valid_i            (valid_mem),
    .wb_sel_i           (),
    
    // 寄存器堆写端口
    .reg_write_en_o     (reg_write_en_wb),
    .rd_addr_o          (rd_addr_wb),
    .rd_data_o          (wb_result_wb)
);

// ============================================================================
// 冒险处理单元
// ============================================================================

hazard_unit u_hazard_unit (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // 源寄存器地址
    .rs1_addr_id_i      (rs1_addr_id),
    .rs2_addr_id_i      (rs2_addr_id),
    
    // 目标寄存器地址（各阶段）
    .rd_addr_ex_i       (rd_addr_ex),
    .rd_addr_mem_i      (rd_addr_mem),
    .rd_addr_wb_i       (rd_addr_wb),
    
    // 写使能信号
    .reg_write_en_ex_i  (),
    .reg_write_en_mem_i (),
    .reg_write_en_wb_i  (reg_write_en_wb),
    
    // 内存访问信号
    .mem_read_en_ex_i   (),
    
    // 分支信号
    .branch_taken_ex_i  (branch_taken_ex),
    .mispredict_ex_i    (branch_mispredict_ex),
    
    // 流水线控制输出
    .stall_if_o         (stall_if),
    .stall_id_o         (stall_id),
    .flush_if_o         (flush_if),
    .flush_id_o         (flush_id),
    .flush_ex_o         (flush_ex),
    
    // 前递控制输出
    .forward_a_o        (forward_a_ex),
    .forward_b_o        (forward_b_ex)
);

// ============================================================================
// 寄存器堆实例化
// ============================================================================

register_file #(
    .DATA_WIDTH(DATA_WIDTH),
    .REG_COUNT(REG_COUNT)
) u_register_file (
    .clk                (clk),
    .rst_n              (rst_n),
    
    // 读端口1（ID阶段）
    .raddr1_i           (rs1_addr_id),
    .rdata1_o           (), // 连接到ID阶段
    
    // 读端口2（ID阶段）
    .raddr2_i           (rs2_addr_id),
    .rdata2_o           (), // 连接到ID阶段
    
    // 写端口（WB阶段）
    .waddr_i            (rd_addr_wb),
    .wdata_i            (wb_result_wb),
    .we_i               (reg_write_en_wb),
    
    // 调试接口（可选）
    .dbg_addr           (),
    .dbg_rdata          ()
);

// ============================================================================
// 控制与状态寄存器（CSR）模块（可选）
// ============================================================================

// csr_unit u_csr_unit (...);

// ============================================================================
// 中断处理单元（可选）
// ============================================================================

// interrupt_unit u_interrupt_unit (...);

// ============================================================================
// 性能计数器（可选）
// ============================================================================

// perf_counter u_perf_counter (...);

endmodule