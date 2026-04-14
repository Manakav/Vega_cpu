`define INIT_HEX "test/workbench/soft/start_inst.hex"
module boot_rom #(
    parameter integer DEPTH_WORDS = 4096
) (
    input  wire [31:0] addr_word_w1,
    input  wire [31:0] addr_word_w2,
    output wire [31:0] data_w1,
    output wire [31:0] data_w2
);

reg [31:0] mem [0:DEPTH_WORDS-1];
integer i;
integer load_fd;

initial begin
    // 默认填充 NOP，避免 hex 缺失时出现 X 扩散
    for (i = 0; i < DEPTH_WORDS; i = i + 1) begin
        mem[i] = 32'h00000013;
    end
    // 优先从工作区路径加载，其次尝试上级相对路径
    load_fd = $fopen(`INIT_HEX, "r");
    if (load_fd != 0) begin
        $fclose(load_fd);
        $readmemh(`INIT_HEX, mem);
    end else begin
        load_fd = $fopen("../test/workbench/soft/start_inst.hex", "r");
        if (load_fd != 0) begin
            $fclose(load_fd);
            $readmemh("../test/workbench/soft/start_inst.hex", mem);
        end
    end
end

// 超出 ROM 深度时回退为 NOP，避免非法地址触发未知值
assign data_w1 = (addr_word_w1 < DEPTH_WORDS) ? mem[addr_word_w1] : 32'h00000013;
assign data_w2 = (addr_word_w2 < DEPTH_WORDS) ? mem[addr_word_w2] : 32'h00000013;

endmodule
