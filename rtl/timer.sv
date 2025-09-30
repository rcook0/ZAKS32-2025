module timer (
    input logic clk,
    input logic rst,
    output logic irq
);
    logic [31:0] count;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            irq <= 0;
        end else begin
            count <= count + 1;
            if (count == 100000) begin
                irq <= 1;
                count <= 0;
            end else irq <= 0;
        end
    end
endmodule
