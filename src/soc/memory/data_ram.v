module data_ram #(
    parameter integer SIZE_BYTES = 65536
) (
    input  wire        clk,
    input  wire        req,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [63:0] wdata,
    input  wire [7:0]  be,
    output wire [63:0] rdata
);

reg [7:0] mem [0:SIZE_BYTES-1];
integer i;

initial begin
    // 上电清零，保证仿真行为可重复
    for (i = 0; i < SIZE_BYTES; i = i + 1) begin
        mem[i] = 8'h00;
    end
end

always @(posedge clk) begin
    if (req && we) begin
        // 按字节写掩码更新 64-bit 写数据
        if (be[0] && (addr + 0 < SIZE_BYTES)) mem[addr + 0] <= wdata[7:0];
        if (be[1] && (addr + 1 < SIZE_BYTES)) mem[addr + 1] <= wdata[15:8];
        if (be[2] && (addr + 2 < SIZE_BYTES)) mem[addr + 2] <= wdata[23:16];
        if (be[3] && (addr + 3 < SIZE_BYTES)) mem[addr + 3] <= wdata[31:24];
        if (be[4] && (addr + 4 < SIZE_BYTES)) mem[addr + 4] <= wdata[39:32];
        if (be[5] && (addr + 5 < SIZE_BYTES)) mem[addr + 5] <= wdata[47:40];
        if (be[6] && (addr + 6 < SIZE_BYTES)) mem[addr + 6] <= wdata[55:48];
        if (be[7] && (addr + 7 < SIZE_BYTES)) mem[addr + 7] <= wdata[63:56];
    end
end

// 组合读，越界字节返回 0
assign rdata = {
    (addr + 7 < SIZE_BYTES) ? mem[addr + 7] : 8'h00,
    (addr + 6 < SIZE_BYTES) ? mem[addr + 6] : 8'h00,
    (addr + 5 < SIZE_BYTES) ? mem[addr + 5] : 8'h00,
    (addr + 4 < SIZE_BYTES) ? mem[addr + 4] : 8'h00,
    (addr + 3 < SIZE_BYTES) ? mem[addr + 3] : 8'h00,
    (addr + 2 < SIZE_BYTES) ? mem[addr + 2] : 8'h00,
    (addr + 1 < SIZE_BYTES) ? mem[addr + 1] : 8'h00,
    (addr + 0 < SIZE_BYTES) ? mem[addr + 0] : 8'h00
};

endmodule
