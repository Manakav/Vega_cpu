// ============================================================================
// CSR Unit (Control and Status Register)
// 支持Zicntr(计时器)和Zicsr(CSR读写)
// ============================================================================

module csr_unit #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 来自ID/EX阶段的CSR访问
    input  wire [11:0]           csr_addr,
    input  wire [DATA_WIDTH-1:0] csr_wdata,
    input  wire                  csr_we,
    input  wire                  csr_re,
    input  wire [2:0]            funct3,
    
    // CSR读数据输出
    output reg  [DATA_WIDTH-1:0] csr_rdata,
    
    // 中断信号
    output reg                   irq_external,
    output reg                   irq_timer,
    output reg                   irq_software,
    
    // 异常信号
    input  wire                  exception_valid,
    input  wire [3:0]            exception_code,
    input  wire [DATA_WIDTH-1:0] exception_pc,
    input  wire [DATA_WIDTH-1:0] exception_value
);

reg [63:0] mstatus;
reg [63:0] mie;
reg [63:0] mtvec;
reg [63:0] mepc;
reg [63:0] mcause;
reg [63:0] mtval;
reg [63:0] mip;

reg [63:0] mcycle;
reg [63:0] mtime;
reg [63:0] mtimecmp;

wire [63:0] mtime_next = mtime + 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mstatus <= 64'h0000000000000000;
        mie <= 64'h0000000000000000;
        mtvec <= 64'h0000000000000000;
        mepc <= 64'h0000000000000000;
        mcause <= 64'h0000000000000000;
        mtval <= 64'h0000000000000000;
        mip <= 64'h0000000000000000;
        mcycle <= 64'h0000000000000000;
        mtime <= 64'h0000000000000000;
        mtimecmp <= 64'hFFFFFFFFFFFFFFFF;
    end else begin
        mcycle <= mcycle + 1;
        mtime <= mtime_next;
        
        if (mtime >= mtimecmp) begin
            mip[7] <= 1'b1;
        end else begin
            mip[7] <= 1'b0;
        end
        
        if (csr_we) begin
            case (csr_addr)
                12'h300: mstatus <= csr_wdata;
                12'h304: mie <= csr_wdata;
                12'h305: mtvec <= csr_wdata;
                12'h341: mepc <= csr_wdata;
                12'h342: mcause <= csr_wdata;
                12'h343: mtval <= csr_wdata;
                12'h344: mip <= csr_wdata;
                12'hB00: mcycle <= csr_wdata;
                12'hB02: mtimecmp <= csr_wdata;
            endcase
        end
        
        if (exception_valid) begin
            mepc <= exception_pc;
            mcause <= {60'b0, exception_code};
            mtval <= exception_value;
            mstatus[3] <= mstatus[1];
            mstatus[1] <= 1'b1;
        end
    end
end

always @(*) begin
    if (!csr_re) begin
        csr_rdata = 64'b0;
    end else begin
        case (csr_addr)
            12'hF11: csr_rdata = 64'h0000000000000000;
            12'hF12: csr_rdata = 64'h0000000000000000;
            12'hF13: csr_rdata = 64'h0000000000000000;
            12'hF14: csr_rdata = 64'h0000000000000000;
            12'h300: csr_rdata = mstatus;
            12'h304: csr_rdata = mie;
            12'h305: csr_rdata = mtvec;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h343: csr_rdata = mtval;
            12'h344: csr_rdata = mip;
            12'hB00: csr_rdata = mcycle;
            12'hB01: csr_rdata = mtime;
            12'hB02: csr_rdata = mtimecmp;
            default: csr_rdata = 64'b0;
        endcase
    end
    
    irq_timer = mip[7] && mie[7];
    irq_software = mip[3] && mie[3];
    irq_external = mip[11] && mie[11];
end

endmodule