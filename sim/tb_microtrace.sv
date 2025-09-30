module tb_microtrace (
    input logic clk,
    input logic rst,
    input logic [11:0] upc,
    input logic [7:0] ir_opcode
);
  
    // Example expected sequence for NOP (uPC 0x000 → 0x001 → FETCH)
    logic [11:0] expected [0:3];
    initial begin
        expected[0] = 12'h000;
        expected[1] = 12'h001;
        expected[2] = 12'h000;
    end

    always @(posedge clk) begin
        if (!rst && ir_opcode == 8'h00) begin // NOP
            assert (upc inside {expected[0], expected[1], expected[2]})
                else $fatal("Microtrace diverged on NOP at %0t", $time);
        end
    end
endmodule
