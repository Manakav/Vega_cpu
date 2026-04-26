module vega_soc_top (
    input  wire        clk_in,
    input  wire        rst_n_in,
    input  wire        uart_rx_i,
    output wire        uart_tx_o,
    output wire [3:0]  led_o
);

localparam [63:0] ROM_BASE  = 64'h0000_0000_0000_1000;
localparam [63:0] RAM_BASE  = 64'h0000_0000_8000_0000;
localparam [63:0] RAM_SIZE  = 64'h0000_0000_0001_0000;
localparam [63:0] UART_BASE = 64'h0000_0000_6010_0000;

wire rst_n;
wire clk = clk_in;

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
wire [31:0] uart_rdata;

wire ram_hit;
wire uart_hit;
wire uart_req;

wire [12:0] ram_addr;
wire        ram_ena;
wire [7:0]  ram_wea;
wire [63:0] ram_dina;

assign ram_hit  = (data_addr >= RAM_BASE) && (data_addr < (RAM_BASE + RAM_SIZE));
assign uart_hit = (data_addr[63:12] == UART_BASE[63:12]);
assign uart_req = data_req && uart_hit;

assign ram_addr = data_addr[15:3];
assign ram_ena  = data_req && ram_hit && !data_we;
assign ram_wea  = data_req && ram_hit ? data_be : 8'b0;
assign ram_dina = data_wdata;

reset_sync u_reset_sync (
    .clk    (clk_in),
    .rst_n_in(rst_n_in),
    .rst_n_out(rst_n)
);

boot_rom_ip u_boot_rom_ip (
    .clka   (clk_in),
    .addra  (instr_addr[13:2]),
    .douta  (instr_data_w1),
    .clkb   (clk_in),
    .addrb  (instr_addr[13:2] + 12'd1),
    .doutb  (instr_data_w2)
);

data_ram_b u_data_ram (
    .clka   (clk_in),
    .ena    (ram_ena),
    .wea    (ram_wea),
    .addra  (ram_addr),
    .dina   (ram_dina),
    .douta  (ram_rdata)
);

uart_adapter u_uart_adapter (
    .clk    (clk_in),
    .rst_n  (rst_n),
    .req    (uart_req),
    .we     (data_we),
    .addr   (data_addr[31:0]),
    .wdata  (data_wdata[31:0]),
    .rdata  (uart_rdata),
    .tx_o   (uart_tx_o),
    .rx_i   (uart_rx_i),
    .busy   ()
);

riscv_cpu u_cpu (
    .clk                (clk_in),
    .rst_n              (rst_n),
    .instr_addr         (instr_addr),
    .instr_data_w1      (instr_data_w1),
    .instr_data_w2      (instr_data_w2),
    .instr_req          (instr_req),
    .instr_gnt          (instr_gnt),
    .data_addr          (data_addr),
    .data_wdata         (data_wdata),
    .data_rdata         (data_rdata),
    .data_req           (data_req),
    .data_we            (data_we),
    .data_be            (data_be),
    .data_gnt           (data_gnt),
    .irq_external       (1'b0),
    .irq_timer          (1'b0),
    .irq_software       (1'b0),
    .debug_req          (1'b0),
    .debug_halt         (),
    .debug_resume       ()
);

assign instr_gnt = instr_req;
assign data_rdata = ram_hit   ? ram_rdata :
                    uart_hit  ? {32'h0, uart_rdata} :
                                64'h0;
assign data_gnt  = data_req;
assign led_o     = data_addr[5:2];

endmodule