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

assign next_pc = mispredict ? branch_target : 
                 (predict_taken ? predict_pc : pc_reg + 4);

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
        pc_reg <= 64'h1000;
        ghr <= 8'b0;
        if_valid <= 1'b0;
    end else if (flush) begin
        if_valid <= 1'b0;
    end else if (!stall) begin
        pc_reg <= next_pc;
        if (mispredict) begin
            ghr <= {ghr[6:0], branch_taken};
        end else if (predict_taken) begin
            ghr <= {ghr[6:0], 1'b1};
        end else begin
            ghr <= {ghr[6:0], 1'b0};
        end
        if_valid <= 1'b1;
        if (instr_gnt) begin
            if_pc <= pc_reg;
            if_instr <= instr_data;
        end
    end
end

always @(*) begin
    if (!stall) begin
        pc_out = if_pc;
        instr_out = if_instr;
        valid_out = if_valid;
    end else begin
        pc_out = pc_reg;
        instr_out = 32'b0;
        valid_out = 1'b0;
    end
end

assign instr_addr = pc_reg;
assign instr_req = 1'b1;

endmodule