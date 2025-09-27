module uart (
input logic clk,
input logic we,
input logic [7:0] din,
output logic [7:0] dout,
output logic tx_ready
);
logic [7:0] tx_reg;
assign dout = tx_reg;
assign tx_ready = we;


always_ff @(posedge clk) begin
if (we) tx_reg <= din;
end
endmodule
