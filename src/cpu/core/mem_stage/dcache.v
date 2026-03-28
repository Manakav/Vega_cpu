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
    input  wire        mem_ready
);

localparam WAY_NUM = 2;
localparam SET_NUM = 64;

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
        // 清空所有 way 的状态
        for (ii = 0; ii < 2; ii = ii + 1) begin
            for (jj = 0; jj < 64; jj = jj + 1) begin
                way_tag[ii][jj] <= 28'b0;
                way_valid[ii][jj] <= 1'b0;
                way_dirty[ii][jj] <= 1'b0;
                way_data[ii][jj] <= 256'b0;
            end
        end
        for (jj = 0; jj < 64; jj = jj + 1) begin
            way_lru[jj] <= 2'b01;
        end
        hit <= 1'b0;
        mem_req <= 1'b0;
        mem_we <= 1'b0;
    end else if (req) begin
        // 查找命中路
        found = 1'b0;
        match_way = 2'b0;
        for (kk = 0; kk < 2; kk = kk + 1) begin
            if (way_valid[kk][index] && (way_tag[kk][index] == tag)) begin
                found = 1'b1;
                match_way = kk;
            end
        end
        
        if (found) begin
            if (we) begin
                // 写命中按访问宽度更新行数据，置 dirty
                case (size)
                    3'b000: way_data[match_way][index][offset*8 +: 8] <= wdata[7:0];
                    3'b001: way_data[match_way][index][offset*8 +: 16] <= wdata[15:0];
                    default: way_data[match_way][index][offset*8 +: 64] <= wdata;
                endcase
                way_dirty[match_way][index] <= 1'b1;
            end
            // 读命中返回 64-bit 视图
            data_out <= way_data[match_way][index][offset*8 +: 64];
            hit <= 1'b1;
        end else begin
            hit <= 1'b0;
            if (mem_ready) begin
                // 回填新行并更新 LRU
                way_tag[way_lru[index]][index] <= tag;
                way_valid[way_lru[index]][index] <= 1'b1;
                way_data[way_lru[index]][index] <= mem_rdata;
                way_dirty[way_lru[index]][index] <= 1'b0;
                way_lru[index] <= way_lru[index] - 1;
                hit <= 1'b1;
            end else begin
                // miss 请求下层存储
                mem_req <= 1'b1;
                mem_addr <= {tag, index, 3'b0};
            end
        end
    end else begin
        hit <= 1'b0;
        mem_req <= 1'b0;
    end
end

endmodule