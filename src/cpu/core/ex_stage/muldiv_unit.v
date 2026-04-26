// ============================================================================
// MULDIV Unit — 多周期乘除法器
// 乘法：1周期 DSP 流水线（乘→选）
// 除法：64周期迭代（radix-2 恢复除法）
// ============================================================================

module muldiv_unit #(
    parameter DATA_WIDTH = 64
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     start,
    input  wire [2:0]               funct3,
    input  wire [DATA_WIDTH-1:0]    operand_a,
    input  wire [DATA_WIDTH-1:0]    operand_b,
    output reg  [DATA_WIDTH-1:0]    result,
    output reg                      done
);

localparam ST_IDLE     = 3'd0;
localparam ST_MUL_R1   = 3'd1;
localparam ST_MUL_R2   = 3'd2;
localparam ST_DIV_INIT = 3'd3;
localparam ST_DIV_ITER = 3'd4;
localparam ST_DIV_SIGN = 3'd5;

reg [2:0] state;

reg signed [DATA_WIDTH-1:0] r_a;
reg signed [DATA_WIDTH-1:0] r_b;
reg [DATA_WIDTH-1:0]        ur_a;
reg [DATA_WIDTH-1:0]        ur_b;
reg [2:0] r_f3;

reg signed [2*DATA_WIDTH-1:0] prod_ss;
reg signed [2*DATA_WIDTH-1:0] prod_su;
reg [2*DATA_WIDTH-1:0]        prod_uu;

reg [DATA_WIDTH-1:0]          div_quotient;
reg [DATA_WIDTH:0]            div_remainder;
reg [DATA_WIDTH-1:0]          div_divisor;
reg [5:0]                     div_count;
reg                           div_signed;
reg                           div_is_rem;
reg                           div_a_neg;
reg                           div_b_neg;

wire [DATA_WIDTH-1:0] abs_a = r_a[DATA_WIDTH-1] ? (~r_a + 1'b1) : r_a;
wire [DATA_WIDTH-1:0] abs_b = r_b[DATA_WIDTH-1] ? (~r_b + 1'b1) : r_b;

wire [DATA_WIDTH:0] div_shifted = {div_remainder[DATA_WIDTH-1:0], abs_a[div_count]};
wire div_cmp = div_shifted >= {1'b0, div_divisor};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state        <= ST_IDLE;
        result       <= {DATA_WIDTH{1'b0}};
        done         <= 1'b0;
        r_a          <= {DATA_WIDTH{1'b0}};
        r_b          <= {DATA_WIDTH{1'b0}};
        ur_a         <= {DATA_WIDTH{1'b0}};
        ur_b         <= {DATA_WIDTH{1'b0}};
        r_f3         <= 3'b0;
        prod_ss      <= {(2*DATA_WIDTH){1'b0}};
        prod_su      <= {(2*DATA_WIDTH){1'b0}};
        prod_uu      <= {(2*DATA_WIDTH){1'b0}};
        div_quotient <= {DATA_WIDTH{1'b0}};
        div_remainder<= {(DATA_WIDTH+1){1'b0}};
        div_divisor  <= {DATA_WIDTH{1'b0}};
        div_count    <= 6'd0;
        div_signed   <= 1'b0;
        div_is_rem   <= 1'b0;
        div_a_neg    <= 1'b0;
        div_b_neg    <= 1'b0;
    end else begin
        case (state)
            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    r_a  <= operand_a;
                    r_b  <= operand_b;
                    ur_a <= operand_a;
                    ur_b <= operand_b;
                    r_f3 <= funct3;
                    if (funct3 <= 3'b011)
                        state <= ST_MUL_R1;
                    else begin
                        state      <= ST_DIV_INIT;
                        div_signed <= (funct3 == 3'b100 || funct3 == 3'b110);
                        div_is_rem <= (funct3 == 3'b110 || funct3 == 3'b111);
                        div_a_neg  <= operand_a[DATA_WIDTH-1] && (funct3 == 3'b100 || funct3 == 3'b110);
                        div_b_neg  <= operand_b[DATA_WIDTH-1] && (funct3 == 3'b100 || funct3 == 3'b110);
                    end
                end
            end

            ST_MUL_R1: begin
                prod_ss <= r_a * r_b;
                prod_su <= r_a * $signed({1'b0, ur_b});
                prod_uu <= ur_a * ur_b;
                state   <= ST_MUL_R2;
            end

            ST_MUL_R2: begin
                done  <= 1'b1;
                state <= ST_IDLE;
                case (r_f3)
                    3'b000: result <= prod_uu[DATA_WIDTH-1:0];
                    3'b001: result <= prod_ss[2*DATA_WIDTH-1:DATA_WIDTH];
                    3'b010: result <= prod_su[2*DATA_WIDTH-1:DATA_WIDTH];
                    3'b011: result <= prod_uu[2*DATA_WIDTH-1:DATA_WIDTH];
                    default: result <= {DATA_WIDTH{1'b0}};
                endcase
            end

            ST_DIV_INIT: begin
                div_remainder <= {DATA_WIDTH+1{1'b0}};
                div_quotient  <= {DATA_WIDTH{1'b0}};
                div_divisor   <= abs_b;
                div_count     <= 6'd63;
                state         <= ST_DIV_ITER;
            end

            ST_DIV_ITER: begin
                if (div_cmp) begin
                    div_remainder <= div_shifted - {1'b0, div_divisor};
                    div_quotient[div_count] <= 1'b1;
                end else begin
                    div_remainder <= div_shifted;
                end
                if (div_count == 6'd0)
                    state <= ST_DIV_SIGN;
                else
                    div_count <= div_count - 6'd1;
            end

            ST_DIV_SIGN: begin
                done  <= 1'b1;
                state <= ST_IDLE;
                if (div_is_rem) begin
                    if (div_signed && div_a_neg)
                        result <= ~div_remainder[DATA_WIDTH-1:0] + 1'b1;
                    else
                        result <= div_remainder[DATA_WIDTH-1:0];
                end else begin
                    if (div_signed && (div_a_neg ^ div_b_neg))
                        result <= ~div_quotient + 1'b1;
                    else
                        result <= div_quotient;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
