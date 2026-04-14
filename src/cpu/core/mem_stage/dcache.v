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
    
    output reg  [63:0] data_out,
    output reg         hit,
    
    output reg  [63:0] mem_addr,
    output reg  [255:0] mem_wdata,
    input  wire [255:0] mem_rdata,
    output reg         mem_req,
    output reg         mem_we,
    input  wire        mem_ready,
    
    // 新增输出端口
    output reg         refill_done,      // 回填完成信号
    output reg         writeback_req,    // 写回请求
    output reg  [63:0] writeback_addr,   // 写回地址
    output reg  [255:0] writeback_data,  // 写回数据
    output reg         cache_stall       // 缓存停顿信号
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

reg found;
reg [1:0] match_way;
integer ii, jj, kk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dcache_state <= DCACHE_IDLE;
        cache_stall <= 1'b0;
        refill_done <= 1'b0;
    end else begin
        case (dcache_state)
            DCACHE_IDLE: begin
                if (req) begin
                    // 查找命中
                    if (found) begin
                        dcache_state <= DCACHE_HIT;
                        cache_stall <= 1'b0;
                    end else begin
                        dcache_state <= DCACHE_MISS_REQ;
                        cache_stall <= 1'b1;
                    end
                end
            end
            
            DCACHE_HIT: begin
                // 处理读写操作
                if (we) begin
                    // 写操作，设置dirty位
                    way_dirty[match_way][index] <= 1'b1;
                end
                dcache_state <= DCACHE_IDLE;
                cache_stall <= 1'b0;
            end
            
            DCACHE_MISS_REQ: begin
                // 检查是否需要写回dirty行
                if (way_dirty[way_lru[index]][index]) begin
                    dcache_state <= DCACHE_WB_REQ;
                end else begin
                    dcache_state <= DCACHE_MISS_WAIT;
                    mem_req <= 1'b1;
                    mem_addr <= {tag, index, 3'b0};
                end
            end
            
            DCACHE_MISS_WAIT: begin
                if (mem_ready) begin
                    dcache_state <= DCACHE_REFILL;
                end
            end
            
            DCACHE_REFILL: begin
                // 回填数据
                way_tag[way_lru[index]][index] <= tag;
                way_valid[way_lru[index]][index] <= 1'b1;
                way_data[way_lru[index]][index] <= mem_rdata;
                way_dirty[way_lru[index]][index] <= 1'b0;
                way_lru[index] <= way_lru[index] - 1;
                refill_done <= 1'b1;
                dcache_state <= DCACHE_HIT;
                cache_stall <= 1'b0;
            end
            
            DCACHE_WB_REQ: begin
                // 发起写回请求
                writeback_req <= 1'b1;
                writeback_addr <= {way_tag[way_lru[index]][index], way_lru[index], 3'b0};
                writeback_data <= way_data[way_lru[index]][index];
                dcache_state <= DCACHE_WB_WAIT;
            end
            
            DCACHE_WB_WAIT: begin
                if (mem_ready) begin
                    writeback_req <= 1'b0;
                    dcache_state <= DCACHE_MISS_WAIT;
                    mem_req <= 1'b1;
                    mem_addr <= {tag, index, 3'b0};
                end
            end
        endcase
    end
end
// 写回地址和数据处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        writeback_req <= 1'b0;
        writeback_addr <= 64'b0;
        writeback_data <= 256'b0;
    end else begin
        if (dcache_state == DCACHE_WB_REQ) begin
            writeback_req <= 1'b1;
            writeback_addr <= {way_tag[way_lru[index]][index], way_lru[index], 3'b0};
            writeback_data <= way_data[way_lru[index]][index];
        end else if (dcache_state == DCACHE_WB_WAIT && mem_ready) begin
            writeback_req <= 1'b0;
            // 清除dirty位
            way_dirty[way_lru[index]][index] <= 1'b0;
        end
    end
end

endmodule