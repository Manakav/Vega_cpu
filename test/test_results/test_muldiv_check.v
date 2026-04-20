`timescale 1ns / 1ps
module test_muldiv_check;
reg [63:0] a, b;
reg [2:0] f3;
reg signed [63:0] sa, sb;
reg signed [127:0] prod_ss;
reg signed [127:0] prod_su;
reg [127:0] prod_uu;
initial begin
    a = 64'h8000000000000000; b = 64'h8000000000000000;
    sa = a; sb = b;
    prod_ss = sa * sb;
    prod_su = sa * $unsigned(b);
    prod_uu = a * b;
    $display("MULH ss_upper=%h su_upper=%h uu_upper=%h", prod_ss[127:64], prod_su[127:64], prod_uu[127:64]);

    a = 64'hFFFFFFFFFFFFFFFF; b = 64'h2;
    prod_uu = a * b;
    $display("MULHU uu_upper=%h", prod_uu[127:64]);

    a = 64'hFFFFFFFFFFFFFFF0; b = 64'h4;
    sa = a; sb = b;
    $display("DIV sa/sb=%h", sa / sb);

    a = 64'hFFFFFFFFFFFFFFF0; b = 64'h3;
    sa = a; sb = b;
    $display("REM sa%%sb=%h", sa % sb);

    a = 64'h8000000000000000; b = 64'h2;
    sa = a;
    prod_su = sa * $unsigned(b);
    $display("MULHSU su_upper=%h", prod_su[127:64]);

    $finish;
end
endmodule