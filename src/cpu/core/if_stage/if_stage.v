// ============================================================================
// IF Stage (取指阶段)
// 负责 PC 更新、分支预测选择、指令请求发起与 IF/ID 寄存输出
// ============================================================================

module if_stage #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  stall,
    input  wire                  flush,
    
    output wire [ADDR_WIDTH-1:0] instr_addr,
    input  wire [DATA_WIDTH-1:0] instr_data,
    output wire                   instr_req,
    input  wire                   instr_gnt,
    
    input  wire                  branch_taken,
    input  wire [ADDR_WIDTH-1:0] branch_target,
    input  wire                  mispredict,
    
    output reg  [ADDR_WIDTH-1:0] pc_out,
    output reg  [DATA_WIDTH-1:0] instr_out,
    output reg                   valid_out
);

// next_pc: 优先级为纠错重定向 > 预测跳转 > 顺序执行
wire [ADDR_WIDTH-1:0] next_pc;
wire [ADDR_WIDTH-1:0] predict_pc;
wire                  predict_taken;
wire [ADDR_WIDTH-1:0] btb_target;
wire                  btb_hit;
wire                  btb_valid;
wire                  bht_taken;
wire [1:0]            bht_counter;

reg [ADDR_WIDTH-1:0] pc_reg;
reg [7:0]            ghr;
reg [ADDR_WIDTH-1:0] if_pc;
reg [DATA_WIDTH-1:0] if_instr;
reg if_valid;

// 控制流选择：一旦 EX 判定误预测，立即改用 branch_target
assign next_pc = mispredict ? branch_target : 
                 (predict_taken ? predict_pc : pc_reg + 4);

// BTB 命中时优先使用 BTB；否则退化到 BHT 方向预测
assign predict_taken = btb_hit ? btb_valid : bht_taken;
assign predict_pc = btb_hit ? btb_target : (pc_reg + 4);

btb u_btb (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(1'b1),
    .pc(pc_reg),
    .hit(btb_hit),
    .target(btb_target),
    .valid(btb_valid),
    .update_en(mispredict),
    .update_pc(pc_reg),
    .update_target(branch_target)
);

bht u_bht (
    .clk(clk),
    .rst_n(rst_n),
    .read_en(1'b1),
    .pc(pc_reg),
    .ghr(ghr),
    .taken(bht_taken),
    .counter(bht_counter),
    .update_en(mispredict),
    .update_pc(pc_reg),
    .update_taken(branch_taken)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位后从固定启动地址开始取指
        pc_reg <= 64'h1000;
        ghr <= 8'b0;
        if_valid <= 1'b0;
    end else if (flush) begin
        // 冲刷流水时仅清空有效位，PC 更新由后续周期完成
        if_valid <= 1'b0;
    end else if (!stall) begin
        // 正常推进时更新 PC
        pc_reg <= next_pc;

        // GHR 在纠错和预测路径上都进行更新，维持历史相关性
        if (mispredict) begin
            ghr <= {ghr[6:0], branch_taken};
        end else if (predict_taken) begin
            ghr <= {ghr[6:0], 1'b1};
        end else begin
            ghr <= {ghr[6:0], 1'b0};
        end

        if_valid <= 1'b1;
        if (instr_gnt) begin
            // 握手成功才锁存指令和对应 PC
            if_pc <= pc_reg;
            if_instr <= instr_data;
        end
    end
end

always @(*) begin
    if (!stall) begin
        // 非停顿时输出上一拍锁存的 IF 结果
        pc_out = if_pc;
        instr_out = if_instr;
        valid_out = if_valid;
    end else begin
        // 停顿时输出气泡，防止下游误推进
        pc_out = pc_reg;
        instr_out = 32'b0;
        valid_out = 1'b0;
    end
end

// 当前版本取指请求常高，外部通过 gnt 控制可用性
assign instr_addr = pc_reg;
assign instr_req = 1'b1;

endmodule