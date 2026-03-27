// ============================================================================
// ALU (Arithmetic Logic Unit)
// 支持RV64I所有算术逻辑操作，包括移位和比较
// ============================================================================

module alu (
    input  wire [3:0]  alu_op,
    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    output reg  [63:0] result,
    output wire        zero,
    output wire        negative,
    output wire        overflow
);

wire signed [63:0] signed_a = operand_a;
wire signed [63:0] signed_b = operand_b;
wire signed [63:0] signed_result = result;

always @(*) begin
    case (alu_op)
        4'b0000: result = operand_a + operand_b;              // ADD
        4'b0001: result = operand_a - operand_b;              // SUB
        4'b0010: result = operand_a << operand_b[5:0];       // SLL
        4'b0011: result = (signed_a < signed_b) ? 64'b1 : 64'b0;  // SLT
        4'b0100: result = (operand_a < operand_b) ? 64'b1 : 64'b0; // SLTU
        4'b0101: result = operand_a ^ operand_b;              // XOR
        4'b0110: result = operand_a >> operand_b[5:0];        // SRL
        4'b0111: result = signed_a >>> operand_b[5:0];         // SRA
        4'b1000: result = operand_a | operand_b;              // OR
        4'b1001: result = operand_a & operand_b;              // AND
        4'b1010: result = operand_b;                          // LUI (pass immediate)
        4'b1100: result = operand_a;                         // PASS A (AUIPC)
        default: result = 64'b0;
    endcase
end

assign zero = (result == 64'b0);
assign negative = result[63];
assign overflow = (alu_op == 4'b0001) ? 
                  ((operand_a[63] ^ operand_b[63]) & (result[63] ^ operand_a[63])) : 1'b0;

endmodule