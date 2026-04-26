// ============================================================================
// 数据缓存 (D-Cache)
// 处理 load/store 访问的命中检测、写掩码更新以及外部内存交互
// ============================================================================

module dcache (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [63:0] addr,
    input  wire [63:0] wdata,
    input  wire [7:0]  be,
    input  wire        req,
    input  wire        we,
    input  wire [2:0]  size,
    
    output wire [63:0] data_out,
    output wire         hit,

    output reg  [63:0] mem_addr,
    output reg  [255:0] mem_wdata,
    input  wire [255:0] mem_rdata,
    output reg         mem_req,
    output reg         mem_we,
    input  wire        mem_ready,

    output wire         refill_done,      // 回填完成信号
    output wire         writeback_req,    // 写回请求
    output wire [63:0] writeback_addr,   // 写回地址
    output wire [255:0] writeback_data,  // 写回数据
    output wire         cache_stall       // 缓存停顿信号
);

localparam WAY_NUM = 2;
localparam SET_NUM = 64;
// DCache状态机定义
localparam DCACHE_IDLE = 3'b000;
localparam DCACHE_HIT = 3'b001;
localparam DCACHE_MISS_REQ = 3'b010;
localparam DCACHE_MISS_WAIT = 3'b011;
localparam DCACHE_REFILL = 3'b100;
localparam DCACHE_WB_REQ = 3'b101;
localparam DCACHE_WB_WAIT = 3'b110;
reg [2:0] dcache_state;

// 地址切分：组索引、Tag、行内偏移
wire [5:0] index = addr[8:3];
wire [27:0] tag = addr[31:4];
wire [2:0] offset = addr[4:3];

reg [27:0] way_tag   [0:1][0:63];
reg        way_valid [0:1][0:63];
reg        way_dirty [0:1][0:63];
reg [255:0] way_data [0:1][0:63];
reg [1:0] way_lru [0:63];

// 并行命中检测 - 展开回路以减少关键路径延迟
wire way0_match = way_valid[0][index] & (way_tag[0][index] == tag);
wire way1_match = way_valid[1][index] & (way_tag[1][index] == tag);
wire found = way0_match | way1_match;
wire [1:0] match_way = way1_match ? 2'd1 : (way0_match ? 2'd0 : 2'd0);

integer kk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dcache_state <= DCACHE_IDLE;
        mem_req <= 1'b0;
        mem_we <= 1'b0;
        mem_addr <= 64'b0;
        mem_wdata <= 256'b0;
        for (kk = 0; kk < SET_NUM; kk = kk + 1) begin
            way_lru[kk] <= 2'b0;
        end
    end else begin
        case (dcache_state)
            DCACHE_IDLE: begin
                mem_req <= 1'b0;
                if (req) begin
                    if (found) begin
                        dcache_state <= DCACHE_HIT;
                    end else begin
                        dcache_state <= DCACHE_MISS_REQ;
                    end
                end
            end

            DCACHE_HIT: begin
                mem_req <= 1'b0;
                if (we) begin
                    way_dirty[match_way][index] <= 1'b1;
                end
                dcache_state <= DCACHE_IDLE;
            end

            DCACHE_MISS_REQ: begin
                mem_req <= 1'b0;
                if (way_dirty[way_lru[index]][index]) begin
                    dcache_state <= DCACHE_WB_REQ;
                end else begin
                    dcache_state <= DCACHE_MISS_WAIT;
                    mem_req <= 1'b1;
                    mem_addr <= {tag, index, 3'b0};
                end
            end

            DCACHE_MISS_WAIT: begin
                mem_req <= 1'b1;
                mem_addr <= {tag, index, 3'b0};
                if (mem_ready) begin
                    dcache_state <= DCACHE_REFILL;
                    mem_req <= 1'b0;
                end
            end

            DCACHE_REFILL: begin
                mem_req <= 1'b0;
                mem_addr <= 64'b0;
                way_tag[way_lru[index]][index] <= tag;
                way_valid[way_lru[index]][index] <= 1'b1;
                way_data[way_lru[index]][index] <= mem_rdata;
                way_dirty[way_lru[index]][index] <= 1'b0;
                way_lru[index] <= way_lru[index] - 1;
                dcache_state <= DCACHE_HIT;
            end

            DCACHE_WB_REQ: begin
                mem_req <= 1'b0;
                mem_addr <= 64'b0;
                dcache_state <= DCACHE_WB_WAIT;
            end

            DCACHE_WB_WAIT: begin
                mem_req <= 1'b1;
                mem_addr <= {tag, index, 3'b0};
                if (mem_ready) begin
                    way_dirty[way_lru[index]][index] <= 1'b0;
                    dcache_state <= DCACHE_MISS_WAIT;
                end
            end
            default: begin
                mem_req <= 1'b0;
                mem_addr <= 64'b0;
            end
        endcase
    end
end

assign data_out = way_data[match_way][index];
assign hit = found;

assign cache_stall = (dcache_state != DCACHE_IDLE) && (dcache_state != DCACHE_HIT) && (dcache_state != DCACHE_REFILL);

assign refill_done = (dcache_state == DCACHE_REFILL);
assign writeback_req = (dcache_state == DCACHE_WB_REQ) || (dcache_state == DCACHE_WB_WAIT);

reg [63:0]  wb_addr_r;
reg [255:0] wb_data_r;

always @(posedge clk) begin
    if (dcache_state == DCACHE_WB_REQ) begin
        wb_addr_r <= {way_tag[way_lru[index]][index], way_lru[index], 3'b0};
        wb_data_r <= way_data[way_lru[index]][index];
    end
end

assign writeback_addr = wb_addr_r;
assign writeback_data = wb_data_r;

endmodule