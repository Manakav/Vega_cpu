`timescale 1ns / 1ps

module tb_vega_soc_top;

reg clk;
reg rst_n;
reg uart_rx;
wire uart_tx;
wire [3:0] led;

vega_soc_top dut (
    .clk_in(clk),
    .rst_n_in(rst_n),
    .uart_rx_i(uart_rx),
    .uart_tx_o(uart_tx),
    .led_o(led)
);

// 100MHz 等效时钟
always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    // UART 空闲电平
    uart_rx = 1'b1;

    // 复位保持一段时间后释放
    #100;
    rst_n = 1'b1;

    // 作为 smoke test，仅验证 SoC 基本运行不崩溃
    #5000;
    $display("[TB] vega_soc_top smoke finished");
    $finish;
end

endmodule
