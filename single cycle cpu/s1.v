module pc (
    input [31:0] PCNext,
    input clk,
    output reg [31:0] PC_cur
);
    initial PC_cur =32'h00000000;

always @(posedge clk)
begin
    PC_cur <= PCNext;
end
endmodule

module instr_mem (
    input [31:0] addr_instr,
    output reg [31:0] rd_instr
);
reg [31:0] mem [31:0];
initial begin
    mem[0]=32'h00300093;
    mem[1]=32'h00508113;
    mem[2]=32'h40110233;
    mem[3]=32'h0040e2b3;
    mem[4]=32'h0050a423;
    mem[5]=32'h0080a183;
    mem[6]=32'h00518333;
    mem[7]=32'h002303b3;
    mem[8]=32'h0063f1b3;
    mem[9]=32'h00529463;
    mem[10]=32'h00518333;
    mem[11]=32'h00219463;
    mem[12]=32'h00612433;
    mem[13]=32'h00a3e213;
    mem[14]=32'h01127193;
    mem[15]=32'h01d22493;
    mem[16]=32'hfc5ff56f;
    /*addi x1,x0,3
    addi x2,x1,5
    sub x4,x2,x1
    or x5,x1,x4
    sw x5, 8(x1)
    lw x3, 8(x1)
    add x6,x3,x5
    add x7,x6,x2
    and x3,x7,x6
    beq x5,x5,8
    beq x3,x2,8
    slt x8,x2,x6
    ori x4,x7,10
    andi x3,x4,17
    slti x9,x4,29
    jal x10,8*/
end
always @ (addr_instr) begin
    rd_instr = mem[addr_instr[31:2]];
end
endmodule

module main_decoder(
    input [6:0] op,
    output branch,
    output jump,
    output MemWrite,
    output ALUSrc,
    output [1:0] ImmSrc,
    output RegWrite,
    output [1:0] ALUOp,
    output [1:0] ResultSrc
);
reg [10:0] controls;

always @(*)
begin
    case (op)
        7'b0000011: controls <= 11'b10010010000; // lw
        7'b0100011: controls <= 11'b00111xx0000; // sw
        7'b0110011: controls <= 11'b1xx00000100; // R-type
        7'b1100011: controls <= 11'b01000xx1010; // beq
        7'b0010011: controls <= 11'b10010000100; // I-type
        7'b1101111: controls <= 11'b111x0100xx1; // jal
        default: controls <= 11'bxxxxxxxxxxx; // undefined
    endcase
end

assign RegWrite = controls[10];
assign ImmSrc = controls[9:8];
assign ALUSrc = controls[7];
assign MemWrite = controls[6];
assign ResultSrc = controls[5:4];
assign branch = controls[3];
assign ALUOp = controls[2:1];
assign jump = controls[0];
endmodule

module ALU_Decoder(
    input op5, funct7_5,
    input [2:0] funct3,
    input [1:0] ALUOp,
    output reg [2:0] ALUControl
);

always @(*) begin
    case(ALUOp)
        2'b00: ALUControl = 3'b000; // add
        2'b01: ALUControl = 3'b001; // sub
        default: begin
            case(funct3)
                3'b000: begin
                    if (op5 & funct7_5) begin
                        ALUControl = 3'b001; // sub
                    end else begin
                        ALUControl = 3'b000; // add
                    end
                end
                3'b010: ALUControl = 3'b101; // slt
                3'b110: ALUControl = 3'b011; // or
                3'b111: ALUControl = 3'b010; // and
                default: ALUControl = 3'bxxx; 
            endcase
        end
    endcase
end
endmodule

module control_unit(
    input [6:0] op,
    input [2:0] funct3,
    input funct7_5,
    input Zero,
    
    output PCSrc,
    output [1:0] ResultSrc,
    output MemWrite,
    output [2:0] ALUControl,
    output ALUSrc,
    output [1:0] ImmSrc,
    output RegWrite);

wire branch, jump;
wire [1:0] ALUOp;


main_decoder main_dec (op,branch,jump,MemWrite,ALUSrc,ImmSrc,RegWrite,ALUOp,ResultSrc);
ALU_Decoder ALU_dec (op[5],funct7_5,funct3,ALUOp,ALUControl);

assign PCSrc = (branch & Zero) | jump;

endmodule

module reg_file(
    input [4:0] R1,
    input [4:0] R2,
    input [4:0] W1,
    input [31:0] WD1,
    input RegWrite,
    input clk,
    output [31:0] RD1,
    output [31:0] RD2
);
reg [31:0] Registers [31:0]; 

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        Registers[i] = 32'h00000000;
    end
end

always @(posedge clk) begin
    if (W1 != 5'b00000 && RegWrite) begin
        Registers[W1] <= WD1;
    end
end
assign RD1 = Registers[R1];
assign RD2 = Registers[R2];
endmodule

module extend(
    input [1:0] ImmSrc,
    input [31:7] instruction,
    output reg [31:0] ImmExt
);

always @* begin
    case (ImmSrc)
        // I-Type
        2'b00: ImmExt = { {20{instruction[31]}}, instruction[31:20] };
        // S-Type
        2'b01: ImmExt = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] };
        // B-Type
        2'b10: ImmExt = { {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
        // J-Type(jal)
        2'b11: ImmExt = { {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
        default: ImmExt = 32'hxxxxxxxx;
    endcase
end
endmodule

module mux_2x1(
    input [31:0] data0,  
    input [31:0] data1,  
    input sel,            
    output [31:0] out 
);
assign out = sel ? data1 : data0;
endmodule

module ALU(
    input [31:0] SrcA,
    input [31:0] SrcB,
    input [2:0] ALUControl,
    output Zero,
    output reg [31:0] ALUResult
);
//reg [31:0] alu_res;
always @* begin
    case (ALUControl)
        // add
        3'b000: ALUResult = SrcA + SrcB;
        // sub
        3'b001: ALUResult = SrcA - SrcB;
        // and
        3'b010: ALUResult = SrcA & SrcB;
        // or
        3'b011: ALUResult = SrcA | SrcB;
        // slt
        3'b101: ALUResult = (SrcA < SrcB) ? 32'h00000001 : 32'h00000000;
        default: ALUResult = 32'hxxxxxxxx;
    endcase
end
assign Zero = (ALUResult == 32'h00000000) ? 1'b1 : 1'b0;
//assign ALUResult = alu_res;
endmodule

module data_memr(
    input [31:0] a_enter,
    input [31:0] write_data,
    input clk,
    input write_en,
    output [31:0] read_data
);
reg [31:0] datamem [63:0];
integer i;
initial begin
    for (i = 0; i < 64; i = i + 1) begin
        datamem[i] = 32'h00000000;
    end
end

always @(posedge clk) begin
    if (write_en) begin
        datamem[a_enter] <= write_data;
    end
end
assign read_data = datamem[a_enter];
endmodule

module mux_3(
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [1:0] sel,
    output reg [31:0] y
);

always @* begin
    case(sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        default: y = 32'hxxxxxxxx;
    endcase
end
endmodule

module adder_jal(
input [31:0] PC,
output [31:0] PCPlus4);

assign PCPlus4 = PC + 4;
endmodule

module adder_branch(
input [31:0] PC,
input [31:0] ImmExt,
output [31:0] PCTarget);

assign PCTarget = PC + ImmExt;
endmodule

module asd(
    input clk,
    input reset,
    output [31:0] pc,
    output [31:0] instr,
    output Zero,
    output PCSrc,
    output [1:0] ResultSrc,
    output MemWrite,
    output [2:0] ALUControl,
    output ALUSrc,
    output [1:0] ImmSrc,
    output RegWrite,
    output [31:0] resultwd,
    output [31:0] RD1,
    output [31:0] RD2,
    output [31:0] ImmExt,
    output [31:0] srcb,
    output [31:0] ALUResult,
    output [31:0] read_data,
    output [31:0] jal_sonuc,
    output [31:0] branch_sonuc,
    output [31:0] pcnext);

    pc p1(pcnext,clk,pc);
    instr_mem i1(pc,instr);
    control_unit c1(instr[6:0],instr[14:12],instr[30],Zero,PCSrc,ResultSrc,MemWrite,ALUControl,ALUSrc,ImmSrc,RegWrite);
    reg_file r1(instr[19:15],instr[24:20],instr[11:7],resultwd,RegWrite,clk,RD1,RD2);
    extend e1(ImmSrc,instr[31:7],ImmExt);
    mux_2x1 m1(RD2,ImmExt,ALUSrc,srcb);
    ALU a1(RD1,srcb,ALUControl,Zero,ALUResult);
    data_memr d1(ALUResult,RD2,clk,MemWrite,read_data);
    mux_3 m2(ALUResult,read_data,jal_sonuc,ResultSrc,resultwd);
    adder_jal a11(pc,jal_sonuc);
    adder_branch a12(pc,ImmExt,branch_sonuc);
    mux_2x1 m3(jal_sonuc,branch_sonuc,PCSrc,pcnext);

endmodule