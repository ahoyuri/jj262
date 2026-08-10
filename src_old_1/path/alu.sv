module alu (
    input  alu_op_e      op,
    input  logic [15:0]  a,        // = akk (fest)
    input  logic [15:0]  b,        // = stage_a (Bus-Operand)
    input  logic         cin,      // = flags[FLG_C] für ADC/SUC/ROL/ROR
    output logic [15:0]  y,
    output logic         z, c, s, v
);
    logic [16:0] res;

    always_comb begin
        c = 1'b0;v = 1'b0;res = '0;
        unique case (op)
            ALU_ADD: begin 
                res = {1'b0,a} + {1'b0,b}; y = res[15:0]; c = res[16]; 
                v = (a[15]==b[15] && (y[15]!=a[15]));end
            ALU_SUB: begin 
                res = {1'b0,a} - {1'b0,b}; y = res[15:0]; c = res[16]; 
                v = (a[15]!=b[15]) && (y[15]!=a[15]);end
            ALU_ADC: begin 
                res = {1'b0,a} + {1'b0,b} + cin;  y=res[15:0]; c=res[16]; 
                v = (a[15]==b[15]) && (y[15]!=a[15]);end
            ALU_SUC: begin 
                res = {1'b0,a} - {1'b0,b} - cin;  y=res[15:0]; c=res[16]; 
                v = (a[15]!=b[15]) && (y[15]!=a[15]);end
            ALU_AND:    y = a & b;
            ALU_OR:     y = a | b;
            ALU_XOR:    y = a ^ b;
            ALU_NOT:    y = ~b;
            ALU_SHL:begin res = {1'b0,a} << b[3:0]; y = res[15:0]; c = res[16];end
            ALU_SHR:begin res = {a,1'b0} >> b[3:0]; y = res[16:1]; c = res[0]; end
            ALU_ASR: begin res = $signed({a,1'b0}) >>> b[3:0]; y = res[16:1]; c = res[0]; end
            ALU_ROL: begin y = (a << b[3:0]) | (a >> (16-b[3:0])); c = y[0]; end    //Barrel-Rotate
            ALU_ROR: begin y = (a >> b[3:0]) | (a << (16-b[3:0])); c = y[15]; end
            ALU_RCL: {c, y} = {a, cin};
            ALU_RCR: {y, c} = {cin, a};
            ALU_NEG: begin res = 17'd0 - {1'b0,a}; y = res[15:0]; c = res[16];
               v = (a == 16'h8000); end
            ALU_CMP: begin 
                res = {1'b0,a} - {1'b0,b}; y = res[15:0]; c = res[16]; 
                v = (a[15]!=b[15]) && (y[15]!=a[15]);end
            ALU_TST: y = a & b;
            ALU_MUL:  y = a * b;              // untere 16 Bit
            ALU_MULH: begin logic [31:0] p; p = a * b; y = p[31:16]; end
            default: y = '0;
        endcase
        z = (y == 0);
        s = y[15];
    end

endmodule