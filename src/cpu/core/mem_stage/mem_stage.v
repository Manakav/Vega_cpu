// ============================================================================
// MEM Stage (访存阶段)
// 包含Load/Store单元、DCache
// ============================================================================

module mem_stage #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 输入来自EX阶段
    input  wire [ADDR_WIDTH-1:0] pc_i,
    input  wire [DATA_WIDTH-1:0] alu_result_i,
    input  wire [DATA_WIDTH-1:0] rs2_data_i,
    input  wire [4:0]            rd_addr_i,
    input  wire                  valid_i,
    input  wire                  mem_read_en_i,
    input  wire                  mem_write_en_i,
    input  wire [2:0]            mem_size_i,
    input  wire                  reg_write_en_i,
    input  wire [1:0]            wb_sel_i,
    
    // 数据内存接口
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_wdata,
    output wire                  mem_we,
    output wire [DATA_WIDTH/8-1:0] mem_be,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_gnt,
    
    // 输出到WB阶段
    output reg  [DATA_WIDTH-1:0] alu_result_o,
    output reg  [DATA_WIDTH-1:0] mem_result_o,
    output reg  [4:0]            rd_addr_o,
    output reg                   valid_o,
    output reg                   reg_write_en_o,
    output reg  [1:0]            wb_sel_o
);

reg [DATA_WIDTH-1:0] mem_data_reg;
reg mem_done;

wire [DATA_WIDTH-1:0] load_data;
wire [2:0] size = mem_size_i;

// 地址由 EX 结果给出，写使能直通
assign mem_addr = alu_result_i;
assign mem_we = mem_write_en_i;

// byte enable 由访存宽度决定
assign mem_be = (mem_size_i == 3'b000) ? 8'b00000001 :
                (mem_size_i == 3'b001) ? 8'b00000011 :
                (mem_size_i == 3'b010) ? 8'b00001111 :
                (mem_size_i == 3'b011) ? 8'b11111111 : 8'b0;

// store 数据低位对齐
assign mem_wdata = (mem_size_i == 3'b000) ? {56'b0, rs2_data_i[7:0]} :
                   (mem_size_i == 3'b001) ? {48'b0, rs2_data_i[15:0]} :
                   (mem_size_i == 3'b010) ? {32'b0, rs2_data_i[31:0]} :
                   rs2_data_i;

// load 数据根据 size 进行符号/零扩展
assign load_data = (size == 3'b000) ? {{56{mem_rdata[7]}}, mem_rdata[7:0]} :
                   (size == 3'b001) ? {{48{mem_rdata[15]}}, mem_rdata[15:0]} :
                   (size == 3'b010) ? {{32{mem_rdata[31]}}, mem_rdata[31:0]} :
                   (size == 3'b011) ? mem_rdata :
                   (size == 3'b100) ? {56'b0, mem_rdata[7:0]} :
                   (size == 3'b101) ? {48'b0, mem_rdata[15:0]} :
                   (size == 3'b110) ? {32'b0, mem_rdata[31:0]} : mem_rdata;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        alu_result_o <= 64'b0;
        mem_result_o <= 64'b0;
        rd_addr_o <= 5'b0;
        valid_o <= 1'b0;
        reg_write_en_o <= 1'b0;
        wb_sel_o <= 2'b0;
        mem_data_reg <= 64'b0;
        mem_done <= 1'b0;
    end else if (valid_i) begin
        // 非访存类指令也会经过本级，需透传 ALU/WB 元数据
        alu_result_o <= alu_result_i;
        rd_addr_o <= rd_addr_i;
        valid_o <= valid_i;
        reg_write_en_o <= reg_write_en_i;
        wb_sel_o <= wb_sel_i;
        
        if (mem_read_en_i && mem_gnt) begin
            // load 成功握手后锁存读数
            mem_data_reg <= load_data;
            mem_result_o <= load_data;
            mem_done <= 1'b1;
        end else if (mem_write_en_i && mem_gnt) begin
            // store 无写回数据，mem_result 置零
            mem_result_o <= 64'b0;
            mem_done <= 1'b1;
        end else begin
            // 未握手或非访存时保持无效读结果
            mem_result_o <= 64'b0;
            mem_done <= 1'b0;
        end
    end else begin
        valid_o <= 1'b0;
        mem_done <= 1'b0;
    end
end

endmodule