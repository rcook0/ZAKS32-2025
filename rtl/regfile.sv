module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [3:0]  rs1, rs2, rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1, rd2
);
    logic [31:0] regs[15:0];

    assign rd1 = (rs1 == 4'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 4'd0) ? 32'd0 : regs[rs2];

    always_ff @(posedge clk) begin
        if (we && rd != 4'd0) regs[rd] <= wd;
    end
endmodule
