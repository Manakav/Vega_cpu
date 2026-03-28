module icache (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [63:0] addr,
    input  wire        req,
    output reg  [31:0] data_out,
    output reg         hit,
    
    output reg  [63:0] mem_addr,
    input  wire [255:0] mem_data,
    output reg         mem_req,
    input  wire        mem_ready
);

localparam WAY_NUM = 2;
localparam SET_NUM = 64;

// 组索引/Tag/行内字偏移
wire [5:0] index = addr[8:3];
wire [27:0] tag = addr[31:4];
wire [2:0] offset = addr[4:2];

reg [27:0] way_tag   [0:1][0:63];
reg        way_valid [0:1][0:63];
reg [255:0] way_data [0:1][0:63];
reg [1:0] way_lru [0:63];

reg found;
reg [1:0] match_way;
integer ii, jj, kk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 清空 cache 元数据与数据阵列
        for (ii = 0; ii < 2; ii = ii + 1) begin
            for (jj = 0; jj < 64; jj = jj + 1) begin
                way_tag[ii][jj] <= 28'b0;
                way_valid[ii][jj] <= 1'b0;
                way_data[ii][jj] <= 256'b0;
            end
        end
        for (jj = 0; jj < 64; jj = jj + 1) begin
            way_lru[jj] <= 2'b01;
        end
    end else begin
        if (mem_ready) begin
            // miss 回填：按 LRU way 写入整行
            way_tag[way_lru[index]][index] <= tag;
            way_valid[way_lru[index]][index] <= 1'b1;
            way_data[way_lru[index]][index] <= mem_data;
            way_lru[index] <= way_lru[index] - 1;
            hit <= 1'b1;
        end else if (req) begin
            // 命中查找
            found = 1'b0;
            match_way = 2'b0;
            for (kk = 0; kk < 2; kk = kk + 1) begin
                if (way_valid[kk][index] && (way_tag[kk][index] == tag)) begin
                    found = 1'b1;
                    match_way = kk;
                end
            end
            if (found) begin
                // 返回 256-bit 行中的一个 32-bit 指令字
                data_out <= way_data[match_way][index][offset*32 +: 32];
                hit <= 1'b1;
            end else begin
                // miss: 发起下层访存请求
                hit <= 1'b0;
                mem_req <= 1'b1;
                mem_addr <= {tag, index, 3'b0};
            end
        end else begin
            hit <= 1'b0;
            mem_req <= 1'b0;
        end
    end
end

endmodule