module soc_top (
    input  logic        clk,
    input  logic        rst,
    output logic        uart_tx_ready,
    output logic [7:0]  uart_tx_data,
    output logic        commit_valid,
    output logic [31:0] commit_instr,
    output logic [31:0] regfile_dbg [15:0]  // debug export for tb
);

    // === Core state ===
    logic [31:0] ir;
    logic [11:0] upc;
    z32u_pkg::uinstr_t uinstr;

    // === Register file ===
    regfile rf (
        .clk(clk),
        .we(rf_we),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(rf_wd),
        .rd1(rf_rd1),
        .rd2(rf_rd2)
    );

    // Debug export
    genvar i;
    generate for (i=0; i<16; i++) begin
        assign regfile_dbg[i] = rf.regs[i];
    end endgenerate

    // === ALU ===
    alu alu0 (
        .a(alu_a),
        .b(alu_b),
        .op(uinstr.alu_op),
        .y(alu_y),
        .nzcv(flags_next)
    );

    // === Flags ===
    flags fl (
        .clk(clk),
        .we(uinstr.flags_we),
        .nzcv_in(flags_next),
        .nzcv_out(flags_cur)
    );

    // === PC ===
    pc pc0 (
        .clk(clk),
        .we(uinstr.wr_pc),
        .inc(uinstr.pc_inc),
        .din(alu_y),
        .pc(pc_val)
    );

    // === IR ===
    always_ff @(posedge clk) begin
        if (uinstr.ir_load) ir <= mdr; // MDR output
    end

    // === Microstore & Sequencer ===
    microstore ustore (.clk(clk), .addr(upc), .uinstr(uinstr));
    sequencer useq (
        .clk(clk), .rst(rst),
        .ir_opcode(ir[31:24]),
        .flag_z(flags_cur[0]), .flag_n(flags_cur[1]),
        .ui(uinstr), .upc(upc)
    );

    // === Commit pulse ===
    always_ff @(posedge clk) begin
        if (uinstr.endi) begin
            commit_valid <= 1;
            commit_instr <= ir;
        end else commit_valid <= 0;
    end

    // TODO: MAR, MDR, memory, UART, timer integration
endmodule
