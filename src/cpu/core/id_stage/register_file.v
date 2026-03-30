// ============================================================================
// 寄存器堆模块 (Register File) - 四读口双写口，支持双发射
// 四读口：Way1 rs1/rs2，Way2 rs1/rs2
// 双写口：Way1 写回，Way2 写回（Way2 优先级更高，防止 WAW）
// ============================================================================

module register_file #(
    parameter DATA_WIDTH = 64,
    parameter REG_COUNT  = 32,
    parameter ADDR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // 读端口 1：Way1 rs1
    input  wire [ADDR_WIDTH-1:0] raddr1,
    output wire [DATA_WIDTH-1:0] rdata1,

    // 读端口 2：Way1 rs2
    input  wire [ADDR_WIDTH-1:0] raddr2,
    output wire [DATA_WIDTH-1:0] rdata2,

    // 读端口 3：Way2 rs1
    input  wire [ADDR_WIDTH-1:0] raddr3,
    output wire [DATA_WIDTH-1:0] rdata3,

    // 读端口 4：Way2 rs2
    input  wire [ADDR_WIDTH-1:0] raddr4,
    output wire [DATA_WIDTH-1:0] rdata4,

    // 写端口 1：Way1 写回
    input  wire [ADDR_WIDTH-1:0] waddr1,
    input  wire [DATA_WIDTH-1:0] wdata1,
    input  wire                  we1,

    // 写端口 2：Way2 写回
    input  wire [ADDR_WIDTH-1:0] waddr2,
    input  wire [DATA_WIDTH-1:0] wdata2,
    input  wire                  we2
);

reg [DATA_WIDTH-1:0] rf [0:REG_COUNT-1];

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < REG_COUNT; i = i + 1)
            rf[i] <= {DATA_WIDTH{1'b0}};
    end else begin
        // Way1 先写，Way2 后写（程序序靠后的 Way2 具有更高优先级）
        if (we1 && (waddr1 != 5'b0)) rf[waddr1] <= wdata1;
        if (we2 && (waddr2 != 5'b0)) rf[waddr2] <= wdata2;
    end
end

// 异步读 + 写后旁路（Way2 优先于 Way1）
assign rdata1 = (raddr1 == 5'b0)              ? {DATA_WIDTH{1'b0}} :
                (we2 && raddr1 == waddr2)      ? wdata2             :
                (we1 && raddr1 == waddr1)      ? wdata1             : rf[raddr1];

assign rdata2 = (raddr2 == 5'b0)              ? {DATA_WIDTH{1'b0}} :
                (we2 && raddr2 == waddr2)      ? wdata2             :
                (we1 && raddr2 == waddr1)      ? wdata1             : rf[raddr2];

assign rdata3 = (raddr3 == 5'b0)              ? {DATA_WIDTH{1'b0}} :
                (we2 && raddr3 == waddr2)      ? wdata2             :
                (we1 && raddr3 == waddr1)      ? wdata1             : rf[raddr3];

assign rdata4 = (raddr4 == 5'b0)              ? {DATA_WIDTH{1'b0}} :
                (we2 && raddr4 == waddr2)      ? wdata2             :
                (we1 && raddr4 == waddr1)      ? wdata1             : rf[raddr4];

endmodule