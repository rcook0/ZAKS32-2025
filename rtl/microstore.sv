import z32u_pkg::*;
module microstore (
    input logic clk,
    input logic [11:0] addr,
    output uinstr_t uinstr
);
    // Packed ROM: 96-bit microinstructions
    logic [95:0] rom [0:4095];
    initial $readmemh("microcode.hex", rom);
    assign uinstr = rom[addr];
endmodule
