module mul_div (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0] funct3,
    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    
    output reg  [63:0] result,
    output reg         done
);

localparam IDLE = 2'b00;
localparam DONE = 2'b10;

reg [1:0] state;
reg [127:0] mul_result;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 64'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    case (funct3)
                        3'b000: begin
                            result <= operand_a * operand_b;
                            state <= DONE;
                        end
                        3'b001: begin
                            result <= ($signed(operand_a) * $signed(operand_b))[127:64];
                            state <= DONE;
                        end
                        3'b010: begin
                            result <= ($signed(operand_a) * {64{1'b0}, operand_b})[127:64];
                            state <= DONE;
                        end
                        3'b011: begin
                            result <= ({64{1'b0}, operand_a} * {64{1'b0}, operand_b})[127:64];
                            state <= DONE;
                        end
                        3'b100: begin
                            result <= operand_b != 0 ? $signed(operand_a) / $signed(operand_b) : 64'hFFFFFFFFFFFFFFFF;
                            state <= DONE;
                        end
                        3'b101: begin
                            result <= operand_b != 0 ? operand_a / operand_b : 64'hFFFFFFFFFFFFFFFF;
                            state <= DONE;
                        end
                        3'b110: begin
                            result <= operand_b != 0 ? $signed(operand_a) % $signed(operand_b) : 64'hFFFFFFFFFFFFFFFF;
                            state <= DONE;
                        end
                        3'b111: begin
                            result <= operand_b != 0 ? operand_a % operand_b : 64'hFFFFFFFFFFFFFFFF;
                            state <= DONE;
                        end
                        default: state <= DONE;
                    endcase
                end
            end
            
            DONE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
        endcase
    end
end

endmodule