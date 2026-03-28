// ============================================================================
// 寄存器堆模块 (Register File)
// 双读口，单写口，异步读， Synchronous写
// ============================================================================

module register_file #(
    parameter DATA_WIDTH = 64,
    parameter REG_COUNT = 32,
    parameter ADDR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 读端口1
    input  wire [ADDR_WIDTH-1:0] raddr1,
    output wire [DATA_WIDTH-1:0] rdata1,
    
    // 读端口2
    input  wire [ADDR_WIDTH-1:0] raddr2,
    output wire [DATA_WIDTH-1:0] rdata2,
    
    // 写端口
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire                  we
);

reg [DATA_WIDTH-1:0] rf [0:REG_COUNT-1];

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位清零全部通用寄存器
        for (i = 0; i < REG_COUNT; i = i + 1) begin
            rf[i] <= {DATA_WIDTH{1'b0}};
        end
    end else if (we && waddr != 5'b0) begin
        // x0 保持硬连线 0，不允许写入
        rf[waddr] <= wdata;
    end
end

// 异步读 + 写后读旁路（同周期读写同址时返回新值）
assign rdata1 = (raddr1 == 5'b0) ? {DATA_WIDTH{1'b0}} : 
                (we && (raddr1 == waddr)) ? wdata : rf[raddr1];

assign rdata2 = (raddr2 == 5'b0) ? {DATA_WIDTH{1'b0}} : 
                (we && (raddr2 == waddr)) ? wdata : rf[raddr2];

endmodule