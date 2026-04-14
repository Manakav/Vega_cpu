module vega_soc_top (
    input  wire        clk_in,
    input  wire        rst_n_in,
    input  wire        uart_rx_i,
    output wire        uart_tx_o,
    output wire [3:0]  led_o
);

// SoC 最小地址空间：ROM(取指)、RAM(数据)、UART(MMIO)
localparam [63:0] ROM_BASE  = 64'h0000_0000_0000_1000;
localparam [63:0] RAM_BASE  = 64'h0000_0000_8000_0000;
localparam [63:0] RAM_SIZE  = 64'h0000_0000_0001_0000;
localparam [63:0] UART_BASE = 64'h0000_0000_6010_0000;

wire rst_n;

wire [63:0] instr_addr;
wire [31:0] instr_data_w1;
wire [31:0] instr_data_w2;
wire        instr_req;
wire        instr_gnt;

wire [63:0] data_addr;
wire [63:0] data_wdata;
wire [63:0] data_rdata;
wire        data_req;
wire        data_we;
wire [7:0]  data_be;
wire        data_gnt;

wire [63:0] ram_rdata;
wire [63:0] uart_rdata;

// 简单地址译码：数据访问在 RAM / UART 之间二选一
wire ram_hit  = (data_addr >= RAM_BASE) && (data_addr < (RAM_BASE + RAM_SIZE));
wire uart_hit = (data_addr[63:12] == UART_BASE[63:12]);

wire [31:0] instr_word_idx_w1 = instr_addr[13:2] - ROM_BASE[13:2];
wire [31:0] instr_word_idx_w2 = instr_word_idx_w1 + 1;
wire [31:0] ram_addr_local = data_addr[31:0] - RAM_BASE[31:0];

reset_sync u_reset_sync (
    .clk(clk_in),
    .rst_n_in(rst_n_in),
    .rst_n_out(rst_n)
);

/*
boot_rom #(
    .DEPTH_WORDS(4096)
) u_boot_rom (
    .addr_word_w1(instr_word_idx_w1),
    .addr_word_w2(instr_word_idx_w2),
    .data_w1(instr_data_w1),
    .data_w2(instr_data_w2)
);
*/

boot_rom_ip u_boot_rom_ip (
    // 端口 A
    .clka   (1'b0),             // ROM 不需要时钟，但在真双端口模式下通常需要连接（取决于具体IP版本，有时可以悬空或接地）
                                // *修正：对于纯组合逻辑读，Vivado BRAM IP 可能需要时钟。如果报错，请接入系统时钟 clk。*
    .addra  (pc_if_id),         // 连接端口 A 地址
    .douta  (inst_if_id),       // 连接端口 A 输出数据

    // 端口 B
    .clkb   (1'b0),             // 同上
    .addrb  (pc_id_ex),         // 连接端口 B 地址
    .doutb  (inst_id_ex)        // 连接端口 B 输出数据
);

/*
data_ram #(
    .SIZE_BYTES(65536)
) u_data_ram (
    .clk(clk_in),
    .req(data_req && ram_hit),
    .we(data_we),
    .addr(ram_addr_local),
    .wdata(data_wdata),
    .be(data_be),
    .rdata(ram_rdata)
);
*/
data_ram_b u_data_ram (
     //时钟
     .clka(clk),
     
     //使能、写控制
     .ena(req),
     .wea(we? be :8'b0), //逻辑转换：只有当 we=1 时，be 信号才传给 IP 核的写掩码端口
     
     //截取 [15:3] 以匹配 64位宽（8字节对齐）
     .addra(ram_addr_local[15:3]),
     
     //数据端口
     .dina(wdata),
     .douta(rdata)
);

uart_adapter u_uart_adapter (
    .clk(clk_in),
    .rst_n(rst_n),          // 你的复位信号
    .req(uart_req),         // 你的 UART 请求信号
    .we(uart_we),           // 你的 UART 写使能
    .addr(uart_addr),       // 你的 UART 地址 (注意位宽匹配)
    .wdata(uart_wdata),     // 你的写数据
    .rdata(uart_rdata),     // 你的读数据
    .tx_o(uart_tx),         // 连接到外部 IO
    .rx_i(uart_rx),         // 连接到外部 IO
    .busy()                 // 可以悬空或连接到状态机
);

riscv_cpu u_cpu (
    .clk(clk_in),
    .rst_n(rst_n),
    .instr_addr(instr_addr),
    .instr_data_w1(instr_data_w1),
    .instr_data_w2(instr_data_w2),
    .instr_req(instr_req),
    .instr_gnt(instr_gnt),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_req(data_req),
    .data_we(data_we),
    .data_be(data_be),
    .data_gnt(data_gnt),
    .irq_external(1'b0),
    .irq_timer(1'b0),
    .irq_software(1'b0),
    .debug_req(1'b0),
    .debug_halt(),
    .debug_resume()
);

assign instr_gnt = instr_req;
// 非命中区域读回 0，便于 bring-up 阶段快速定位非法访问
assign data_rdata = ram_hit ? ram_rdata : (uart_hit ? uart_rdata : 64'h0);
assign data_gnt = data_req;
// 临时可观测信号：导出低位地址到 LED
assign led_o = data_addr[5:2];

endmodule
