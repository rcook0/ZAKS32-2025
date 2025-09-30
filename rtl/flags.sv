module flags (
    input  logic       clk,
    input  logic       we,
    input  logic [3:0] nzcv_in,
    output logic [3:0] nzcv_out
);
    always_ff @(posedge clk) begin
        if (we) nzcv_out <= nzcv_in;
    end
endmodule
