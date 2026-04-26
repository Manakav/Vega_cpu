module uart_adapter (
    input  wire        clk,
    input  wire        rst_n,
    // 用户侧接口 (连接你的 SoC 总线)
    input  wire        req,
    input  wire        we,
    input  wire [31:0] addr,      // 假设是 32 位地址
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        tx_o,
    input  wire        rx_i,
    // 状态返回 (可选)
    output reg         busy
);

    // --- AXI 信号定义 ---
    wire        axi_aclk = clk;
    wire        axi_aresetn = rst_n;
    
    // 写地址通道
    reg  [3:0]  axi_awaddr;
    reg         axi_awvalid;
    wire        axi_awready;
    
    // 写数据通道
    reg  [31:0] axi_wdata;
    reg  [3:0]  axi_wstrb;     // 写掩码 (AXI 是字节掩码)
    reg         axi_wvalid;
    wire        axi_wready;
    
    // 写响应通道
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    reg         axi_bready;
    
    // 读地址通道
    reg  [3:0]  axi_araddr;
    reg         axi_arvalid;
    wire        axi_arready;
    
    // 读数据通道
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rvalid;
    reg         axi_rready;

    // --- AXI Uartlite 例化 ---
    axi_uartlite_0 u_axi_uart (
        .s_axi_aclk(axi_aclk),
        .s_axi_aresetn(axi_aresetn),
        
        // 写地址
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        
        // 写数据
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        
        // 写响应
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        
        // 读地址
        .s_axi_araddr(axi_araddr),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        
        // 读数据
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),
        
        // 外部中断 (如果不使用可以悬空)
        .interrupt(),
        
        // 物理端口
        .rx(rx_i),
        .tx(tx_o)
    );

    // --- 协议转换逻辑 ---
    
    // 1. 地址和控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awaddr <= 0;
            axi_araddr <= 0;
            axi_awvalid <= 0;
            axi_arvalid <= 0;
            axi_wvalid <= 0;
            axi_bready <= 0;
            axi_rready <= 0;
            rdata <= 0;
            busy <= 0;
        end else begin
            // 默认拉高，准备接收下一次事务
            axi_bready <= 1;
            axi_rready <= 1;
            
            // 写事务开始
            if (req && we && !busy) begin
                axi_awaddr <= addr[3:0]; // 直接连接地址
                axi_awvalid <= 1;
                axi_wdata <= wdata;
                axi_wstrb <= 4'b1111; // 假设全写，或者根据你的 be 信号连接
                axi_wvalid <= 1;
                busy <= 1;
            end
            // 写响应接收
            else if (axi_bvalid && busy) begin
                axi_awvalid <= 0;
                axi_wvalid <= 0;
                busy <= 0;
            end
            
            // 读事务开始
            if (req && !we && !busy) begin
                axi_araddr <= addr[3:0];
                axi_arvalid <= 1;
                busy <= 1;
            end
            // 读数据接收
            else if (axi_rvalid && busy) begin
                rdata <= axi_rdata;
                axi_arvalid <= 0;
                busy <= 0;
            end
        end
    end

endmodule