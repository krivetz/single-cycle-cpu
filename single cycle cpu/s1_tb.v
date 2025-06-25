`include "s1.v"

module stest;
    reg clk, rst;
    wire [31:0] pc,instr;
    wire Zero;
    wire PCSrc;
    wire [1:0] ResultSrc;
    wire MemWrite;
    wire [2:0] ALUControl;
    wire ALUSrc;
    wire [1:0] ImmSrc;
    wire RegWrite;
    wire [31:0] resultwd;
    wire [31:0] RD1;
    wire [31:0] RD2;
    wire [31:0] ImmExt;
    wire [31:0] srcb;
    wire [31:0] ALUResult;
    wire [31:0] read_data;
    wire [31:0] jal_sonuc;
    wire [31:0] branch_sonuc;
    wire [31:0] pcnext;
    
    asd a1(clk,rst,pc,instr,Zero,PCSrc,ResultSrc,MemWrite,ALUControl,ALUSrc,ImmSrc,RegWrite,resultwd,RD1,RD2,ImmExt,srcb,ALUResult,read_data,jal_sonuc,branch_sonuc,pcnext);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
        #215;
        $finish;
    end

    initial begin
            $dumpfile("s1_vcd.vcd");
            $dumpvars(0, stest);
    end
endmodule
