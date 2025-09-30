import z32u_pkg::*;
module sequencer (
    input  logic        clk, rst,
    input  logic [5:0]  ir_opcode,
    input  logic        flag_z, flag_n,
    input  uinstr_t     ui,
    output logic [11:0] upc
);
    logic [11:0] nxt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) upc <= 12'd0;
        else begin
            nxt = ui.next;
            if (ui.dispatch) nxt[11:6] = {2'b00, ir_opcode};
            if (ui.jam_z && flag_z) nxt[0] = 1'b1;
            if (ui.jam_n && flag_n) nxt[0] = 1'b1;
            upc <= ui.endi ? 12'd0 : nxt;
        end
    end
endmodule
