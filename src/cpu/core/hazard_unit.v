// ============================================================================
// Hazard Unit (冒险处理单元)
// 检测数据冒险、结构冒险、控制冒险，生成stall和flush信号
// ============================================================================

module hazard_unit (
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 源寄存器地址 (ID阶段)
    input  wire [4:0]            rs1_addr_id,
    input  wire [4:0]            rs2_addr_id,
    input  wire                  rs1_used_id,
    input  wire                  rs2_used_id,
    
    // 目标寄存器地址 (EX/MEM/WB阶段)
    input  wire [4:0]            rd_addr_ex,
    input  wire [4:0]            rd_addr_mem,
    input  wire [4:0]            rd_addr_wb,
    
    // 写使能信号
    input  wire                  reg_write_en_ex,
    input  wire                  reg_write_en_mem,
    input  wire                  reg_write_en_wb,
    
    // 内存访问信号
    input  wire                  mem_read_en_ex,
    
    // 分支信号
    input  wire                  branch_taken_ex,
    input  wire                  mispredict_ex,
    
    // 流水线控制输出
    output reg                   stall_if,
    output reg                   stall_id,
    output reg                   flush_if,
    output reg                   flush_id,
    output reg                   flush_ex,
    
    // 前递控制输出
    output reg  [1:0]            forward_a,
    output reg  [1:0]            forward_b
);

wire rs1_ex_hazard = rs1_used_id && (rs1_addr_id == rd_addr_ex) && reg_write_en_ex;
wire rs1_mem_hazard = rs1_used_id && (rs1_addr_id == rd_addr_mem) && reg_write_en_mem;
wire rs1_wb_hazard = rs1_used_id && (rs1_addr_id == rd_addr_wb) && reg_write_en_wb;

wire rs2_ex_hazard = rs2_used_id && (rs2_addr_id == rd_addr_ex) && reg_write_en_ex;
wire rs2_mem_hazard = rs2_used_id && (rs2_addr_id == rd_addr_mem) && reg_write_en_mem;
wire rs2_wb_hazard = rs2_used_id && (rs2_addr_id == rd_addr_wb) && reg_write_en_wb;

always @(*) begin
    flush_if = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;
    stall_if = 1'b0;
    stall_id = 1'b0;
    forward_a = 2'b00;
    forward_b = 2'b00;
    
    if (mispredict_ex) begin
        flush_if = 1'b1;
        flush_id = 1'b1;
        flush_ex = 1'b1;
    end else if (mem_read_en_ex && ((rs1_addr_id == rd_addr_ex) || (rs2_addr_id == rd_addr_ex))) begin
        stall_if = 1'b1;
        stall_id = 1'b1;
    end else begin
        if (rs1_ex_hazard) begin
            forward_a = 2'b01;
        end else if (rs1_mem_hazard) begin
            forward_a = 2'b10;
        end else if (rs1_wb_hazard) begin
            forward_a = 2'b11;
        end
        
        if (rs2_ex_hazard) begin
            forward_b = 2'b01;
        end else if (rs2_mem_hazard) begin
            forward_b = 2'b10;
        end else if (rs2_wb_hazard) begin
            forward_b = 2'b11;
        end
    end
end

endmodule