module pc (
    input  logic        clk,
    input  logic        we,
    input  logic        inc,
    input  logic [31:0] din,
    output logic [31:0] pc
);
    always_ff @(posedge clk) begin
        if (we) pc <= din;
        else if (inc) pc <= pc + 32'd4;
    end
endmodule
