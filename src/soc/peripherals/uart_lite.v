module uart_lite #(
    parameter [63:0] BASE_ADDR = 64'h0000_0000_6010_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req,
    input  wire        we,
    input  wire [63:0] addr,
    input  wire [63:0] wdata,
    output reg  [63:0] rdata,
    output wire        tx_o,
    input  wire        rx_i
);

localparam [31:0] REG_RX_FIFO = 32'h0;
localparam [31:0] REG_TX_FIFO = 32'h4;
localparam [31:0] REG_STATUS  = 32'h8;
localparam [31:0] REG_CONTROL = 32'hc;

reg [31:0] rx_fifo;
reg [31:0] tx_fifo;
reg [31:0] control;

// 4KB 页粒度匹配，寄存器偏移使用 addr[3:2]
wire hit = req && (addr[63:12] == BASE_ADDR[63:12]);
wire [31:0] reg_off = {30'b0, addr[3:2], 2'b0};
// bit2=1: TX 可写（当前简化实现）
wire [31:0] status = 32'h0000_0004;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_fifo  <= 32'h0;
        tx_fifo  <= 32'h0;
        control  <= 32'h0;
    end else if (hit && we) begin
        case (reg_off)
            REG_TX_FIFO: begin
                tx_fifo <= wdata[31:0];
`ifndef SYNTHESIS
                // 仿真阶段将 UART 输出直接映射到控制台
                $write("%c", wdata[7:0]);
`endif
            end
            REG_CONTROL: begin
                control <= wdata[31:0];
            end
            default: begin
            end
        endcase
    end
end

always @(*) begin
    rdata = 64'h0;
    if (hit && !we) begin
        case (reg_off)
            REG_RX_FIFO: rdata = {32'h0, rx_fifo};
            REG_TX_FIFO: rdata = {32'h0, tx_fifo};
            REG_STATUS:  rdata = {32'h0, status};
            REG_CONTROL: rdata = {32'h0, control};
            default:     rdata = 64'h0;
        endcase
    end
end

// 当前为占位输出：后续接入真实 UART 波特率发送器
assign tx_o = 1'b1;
wire _unused_rx = rx_i;

endmodule
