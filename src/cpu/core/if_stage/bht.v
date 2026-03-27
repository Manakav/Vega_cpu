module bht (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        read_en,
    input  wire [63:0] pc,
    input  wire [7:0]  ghr,
    
    output wire        taken,
    output wire [1:0]  counter,
    
    input  wire        update_en,
    input  wire [63:0] update_pc,
    input  wire        update_taken
);

reg [1:0] bht_counter [0:255];

wire [7:0] index;
wire [7:0] upd_idx;

assign index = pc[9:2] ^ ghr;
assign upd_idx = update_pc[9:2] ^ ghr;

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 256; i = i + 1) begin
            bht_counter[i] <= 2'b01;
        end
    end else if (update_en) begin
        case (bht_counter[upd_idx])
            2'b00: begin
                if (update_taken) bht_counter[upd_idx] <= 2'b01;
            end
            2'b01: begin
                bht_counter[upd_idx] <= update_taken ? 2'b10 : 2'b00;
            end
            2'b10: begin
                bht_counter[upd_idx] <= update_taken ? 2'b11 : 2'b01;
            end
            2'b11: begin
                if (!update_taken) bht_counter[upd_idx] <= 2'b10;
            end
        endcase
    end
end

assign counter = bht_counter[index];
assign taken = bht_counter[index][1];

endmodule