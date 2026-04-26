module reset_sync (
    input  wire clk,
    input  wire rst_n_in,
    output wire rst_n_out
);

reg [1:0] sync_ff;

always @(posedge clk or negedge rst_n_in) begin
    if (!rst_n_in) begin
        // 异步断言
        sync_ff <= 2'b00;
    end else begin
        // 同步释放，降低复位去使能时亚稳态风险
        sync_ff <= {sync_ff[0], 1'b1};
    end
end

assign rst_n_out = sync_ff[1];

endmodule
