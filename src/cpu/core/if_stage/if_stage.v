// ============================================================================
// IF Stage（取指阶段）- 6级流水线双发射版本
// 每周期从 PC 和 PC+4 同时取两条指令（Way1 / Way2）
// 保留 BTB+BHT 动态分支预测机制
// ============================================================================

module if_stage #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  stall,
    input  wire                  flush,
    
`ifdef USE_IP_ICACHE
    // ICache接口信号（ICache启用时使用）
    output wire [63:0]           icache_addr,
    output wire                  icache_req,
    input  wire [31:0]           icache_data_out,
    input  wire [63:0]           icache_instr_window_out,
    input  wire                  icache_window_valid,
    input  wire                  icache_hit,
    input  wire [63:0]           icache_mem_addr,
    input  wire [255:0]          icache_mem_data,
    input  wire                  icache_mem_req,
    output wire                  icache_mem_ready,
`endif

    // 指令存储器接口（外部提供两条连续指令）
    output wire [ADDR_WIDTH-1:0] instr_addr,      // Way1 取指地址（= PC）
    input  wire [DATA_WIDTH-1:0] instr_data_w1,   // PC   处的指令
    input  wire [DATA_WIDTH-1:0] instr_data_w2,   // PC+4 处的指令
    output wire                  instr_req,
    input  wire                  instr_gnt,

    // EX 阶段分支反馈
    input  wire                  branch_taken,
    input  wire [ADDR_WIDTH-1:0] branch_target,
    input  wire                  mispredict,
    
    // 分支执行后训练使能
    input  wire                  branch_update_en,
    input  wire                  branch_update_taken,
    input  wire [ADDR_WIDTH-1:0] branch_update_target,

    // 输出到 ID 阶段 —— Way1（主路）
    output reg  [ADDR_WIDTH-1:0] pc_out_w1,
    output reg  [DATA_WIDTH-1:0] instr_out_w1,
    output reg                   valid_out_w1,

    // 输出到 ID 阶段 —— Way2（副路）
    output reg  [ADDR_WIDTH-1:0] pc_out_w2,
    output reg  [DATA_WIDTH-1:0] instr_out_w2,
    output reg                   valid_out_w2,
    
    // 预测结果输出（供 EX 级比较）
    output wire                  predict_taken,
    output wire [ADDR_WIDTH-1:0] predict_target,
    output wire [ADDR_WIDTH-1:0] predict_fetch_pc
);

wire [ADDR_WIDTH-1:0] next_pc;
wire [ADDR_WIDTH-1:0] predict_pc;
wire [ADDR_WIDTH-1:0] btb_target;
wire                  btb_hit;
wire                  btb_valid;
wire                  bht_taken;
wire [1:0]            bht_counter;

reg [ADDR_WIDTH-1:0]  pc_reg;
reg [7:0]             ghr;

wire [ADDR_WIDTH-1:0] fetch_base_addr = {pc_reg[ADDR_WIDTH-1:2], 2'b00};

`ifdef USE_IP_ICACHE
wire [63:0] instr_window = icache_instr_window_out;
`else
wire [63:0] instr_window = {instr_data_w2, instr_data_w1};
`endif

wire [1:0]  pc_hw_idx = {1'b0, pc_reg[1]};
wire [15:0] inst1_hw = (pc_hw_idx == 2'd0) ? instr_window[15:0] : instr_window[31:16];
wire        inst1_is_32 = (inst1_hw[1:0] == 2'b11);

wire [31:0] inst1_raw = inst1_is_32 ?
                        ((pc_hw_idx == 2'd0) ? instr_window[31:0] : instr_window[47:16]) :
                        {16'b0, inst1_hw};

wire [ADDR_WIDTH-1:0] pc_after_inst1 = pc_reg + (inst1_is_32 ? 64'd4 : 64'd2);
wire [1:0]            inst2_hw_idx = pc_after_inst1[2:1] - fetch_base_addr[2:1];

wire [15:0] inst2_hw =
    (inst2_hw_idx == 2'd0) ? instr_window[15:0]  :
    (inst2_hw_idx == 2'd1) ? instr_window[31:16] :
    (inst2_hw_idx == 2'd2) ? instr_window[47:32] : instr_window[63:48];

wire inst2_is_32 = (inst2_hw[1:0] == 2'b11);
wire inst2_cross_unavailable = (inst2_hw_idx == 2'd3) && inst2_is_32;

wire [31:0] inst2_raw =
    (inst2_hw_idx == 2'd0) ? (inst2_is_32 ? instr_window[31:0]  : {16'b0, instr_window[15:0]})  :
    (inst2_hw_idx == 2'd1) ? (inst2_is_32 ? instr_window[47:16] : {16'b0, instr_window[31:16]}) :
    (inst2_hw_idx == 2'd2) ? (inst2_is_32 ? instr_window[63:32] : {16'b0, instr_window[47:32]}) :
                              {16'b0, instr_window[63:48]};

wire way2_len_valid = ~inst2_cross_unavailable;
wire [ADDR_WIDTH-1:0] seq_inc = (inst1_is_32 ? 64'd4 : 64'd2) +((way2_fetch_valid && way2_len_valid) ? (inst2_is_32 ? 64'd4 : 64'd2) : 64'd0);

// 控制流选择：纠错重定向 > 预测跳转 > 顺序推进（按 16/32-bit 指令长度）
assign next_pc     = mispredict    ? branch_target :
                     predict_taken ? predict_pc    : pc_reg + seq_inc;

// BTB 命中时使用 BTB 目标，否则退化到 BHT 方向预测
assign predict_taken = btb_hit ? btb_valid : bht_taken;
assign predict_pc    = btb_hit ? btb_target : (pc_reg + seq_inc);

// 输出预测信息供流水线传递
assign predict_target   = predict_pc;
assign predict_fetch_pc = pc_reg;

// Way2 仅在 BTB 未命中（无预测跳转）时有效；若 Way1 被预测为跳转，Way2 路径无效
wire way2_fetch_valid = ~(btb_hit & btb_valid);

//实例化Branch Target Buffer（分支目标缓冲器）
btb u_btb (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(1'b1),
    .pc(pc_reg),
    .hit(btb_hit),
    .target(btb_target),
    .valid(btb_valid),
    .update_en(mispredict || (branch_update_en && branch_update_taken)),
    .update_pc(branch_update_en ? branch_update_target : pc_reg),
    .update_target(branch_update_en ? branch_update_target : branch_target)
);

//实例化Branch History Table（分支历史表）
bht u_bht (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(1'b1),
    .pc(pc_reg),
    .ghr(ghr),
    .taken(bht_taken),
    .counter(bht_counter),
    .update_en(mispredict || branch_update_en),
    .update_pc(branch_update_en ? branch_update_target : pc_reg),
    .update_taken(branch_update_en ? branch_update_taken : branch_taken)
);

`ifdef USE_IP_ICACHE
// ICache地址和请求信号
assign icache_addr = fetch_base_addr;
assign icache_req  = !stall && !flush;

// ICache refill控制
reg refill_in_progress;
reg [ADDR_WIDTH-1:0] refill_addr;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        refill_in_progress <= 1'b0;
        refill_addr <= 64'b0;
    end else begin
        if (icache_mem_req && !refill_in_progress) begin
            refill_in_progress <= 1'b1;
            refill_addr <= icache_mem_addr;
        end else if (instr_gnt && refill_in_progress) begin
            refill_in_progress <= 1'b0;
        end
    end
end

assign instr_addr    = refill_in_progress ? refill_addr : fetch_base_addr;
assign instr_req     = refill_in_progress;
assign icache_mem_ready = instr_gnt && refill_in_progress;
`else
// 直接内存模式：地址和请求总是活跃
assign instr_addr = fetch_base_addr;
assign instr_req  = 1'b1;
`endif

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc_reg        <= 64'h1000;
        ghr           <= 8'b0;
        pc_out_w1     <= 64'b0;
        instr_out_w1  <= 32'b0;
        valid_out_w1  <= 1'b0;
        pc_out_w2     <= 64'b0;
        instr_out_w2  <= 32'b0;
        valid_out_w2  <= 1'b0;
    end else if (flush || mispredict) begin
        if (mispredict)
            pc_reg <= branch_target;
        valid_out_w1 <= 1'b0;
        valid_out_w2 <= 1'b0;
    end else if (!stall) begin
        pc_reg <= next_pc;

        ghr <= {ghr[6:0], predict_taken};

        if (instr_gnt) begin
            pc_out_w1    <= pc_reg;
            instr_out_w1 <= inst1_raw;
            valid_out_w1 <= 1'b1;
            pc_out_w2    <= pc_after_inst1;
            instr_out_w2 <= inst2_raw;
            valid_out_w2 <= way2_fetch_valid & way2_len_valid;
        end else begin
            valid_out_w1 <= 1'b0;
            valid_out_w2 <= 1'b0;
        end
    end
end

endmodule