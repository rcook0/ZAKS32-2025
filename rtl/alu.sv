module alu (
    input  logic [31:0] a, b,
    input  logic [7:0]  op,
    output logic [31:0] y,
    output logic [3:0]  nzcv
);
    logic c;
    always_comb begin
        unique case (op)
            0: y = a;         // PASS
            1: y = a + b;     // ADD
            2: y = a - b;     // SUB
            3: y = a & b;     // AND
            4: y = a | b;     // OR
            5: y = a ^ b;     // XOR
            6: y = ~a;        // NOT
            7: y = a << b[4:0]; // SHL
            8: y = a >> b[4:0]; // SHR
            9: y = $signed(a) >>> b[4:0]; // SAR
            default: y = 32'hDEAD_BEEF;
        endcase
        c = (op==1) && (y < a);
        nzcv = {y[31], (y==0), c, 1'b0}; // {N,Z,C,V}
    end
endmodule
