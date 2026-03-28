// ============================================================================
// 分支目标缓冲器 (BTB)
// 保存分支指令目标地址并在取指阶段提供命中与目标预测
// ============================================================================

module btb (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        read_en,
    input  wire [63:0] pc,
    
    output reg         hit,
    output reg  [63:0] target,
    output reg         valid,
    
    input  wire        update_en,
    input  wire [63:0] update_pc,
    input  wire [63:0] update_target
);

localparam WAY_NUM = 4;
localparam SET_NUM = 16;

// 组索引与标记切分
wire [5:0] index = pc[7:2];
wire [19:0] tag = pc[31:12];

wire [5:0] upd_idx = update_pc[7:2];
wire [19:0] upd_tag = update_pc[31:12];

reg [19:0] way_tag   [0:3][0:15];
reg [63:0] way_target [0:3][0:15];
reg        way_valid [0:3][0:15];
reg [1:0] way_lru [0:15];

reg found;
reg [1:0] match_way;
integer i, j, k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位清空所有路的 tag/target/valid
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                way_tag[i][j] <= 20'b0;
                way_target[i][j] <= 64'b0;
                way_valid[i][j] <= 1'b0;
            end
        end
        for (j = 0; j < 16; j = j + 1) begin
            way_lru[j] <= 2'b11;
        end
    end else if (update_en) begin
        // update 时先查命中，命中则改 target，未命中则按 LRU 替换
        found = 1'b0;
        match_way = 2'b00;
        for (k = 0; k < 4; k = k + 1) begin
            if (way_valid[k][upd_idx] && (way_tag[k][upd_idx] == upd_tag)) begin
                found = 1'b1;
                match_way = k;
            end
        end
        if (found) begin
            way_target[match_way][upd_idx] <= update_target;
            way_valid[match_way][upd_idx] <= 1'b1;
        end else begin
            way_tag[way_lru[upd_idx]][upd_idx] <= upd_tag;
            way_target[way_lru[upd_idx]][upd_idx] <= update_target;
            way_valid[way_lru[upd_idx]][upd_idx] <= 1'b1;
            way_lru[upd_idx] <= way_lru[upd_idx] - 1;
        end
    end
end

reg [63:0] hit_target;
reg hit_valid;
integer m;

always @(*) begin
    // 组合读路径：在所有 way 中查 tag 命中
    hit = 1'b0;
    hit_target = 64'b0;
    hit_valid = 1'b0;
    if (read_en) begin
        for (m = 0; m < 4; m = m + 1) begin
            if (way_valid[m][index] && (way_tag[m][index] == tag)) begin
                hit = 1'b1;
                hit_target = way_target[m][index];
                hit_valid = way_valid[m][index];
            end
        end
    end
end

always @(*) begin
    target = hit_target;
    valid = hit_valid;
end

endmodule