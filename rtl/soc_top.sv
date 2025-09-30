// Zaks32-2025 — SoC top-level (simulation-first)
// Wires together: core datapath, microstore/sequencer, unified memory, UART, timer
// Exposes commit pulse + regfile snapshot for the Verilator testbench.

`timescale 1ns/1ps

import z32u_pkg::*; // uinstr_t, op enums

module soc_top (
    input  logic        clk,
    input  logic        rst,
    // UART TX observation (for tb)
    output logic        uart_tx_ready,
    output logic [7:0]  uart_tx_data,
    // Commit interface for ISS diff
    output logic        commit_valid,
    output logic [31:0] commit_instr,
    // Debug: mirror of architectural regs (simulation-only)
    output logic [31:0] regfile_dbg [15:0]
);
    // -----------------------------
    // Architectural state
    // -----------------------------
    logic [31:0] pc_q, pc_d;
    logic [31:0] ir_q;                 // instruction register
    logic [3:0]  rs1, rs2, rd;         // decoded fields
    logic [17:0] imm18;                // immediate from IR

    // Datapath minor state
    logic [31:0] mar_q, mdr_q;         // memory address/data registers
    logic [31:0] imm_q;                // sign/zero-extended immediate latch
    logic [3:0]  nzcv_q, nzcv_d;       // flags: {N,Z,C,V} — map as you prefer

    // Register file wires
    logic        rf_we;
    logic [31:0] rf_rd1, rf_rd2, rf_wd;

    // ALU wires
    logic [31:0] alu_a, alu_b, alu_y;

    // Microcode control
    logic [11:0] upc;
    uinstr_t     ui;

    // -----------------------------
    // Instances: regfile, ALU, microstore, sequencer
    // -----------------------------
    regfile rf (
        .clk (clk),
        .we  (rf_we),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (rf_wd),
        .rd1 (rf_rd1),
        .rd2 (rf_rd2)
    );

    // Export internal regs for tb (hierarchical ref allowed in sim)
    genvar gi;
    generate for (gi=0; gi<16; gi++) begin : G_DBG
        assign regfile_dbg[gi] = rf.regs[gi];
    end endgenerate

    // Simple ALU (assumed to set nzcv_d when ui.flags_we)
    alu alu0 (
        .a  (alu_a),
        .b  (alu_b),
        .op (ui.alu_op),
        .y  (alu_y),
        .nzcv(nzcv_d)
    );

    // Flags register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) nzcv_q <= '0; else if (ui.flags_we) nzcv_q <= nzcv_d; end

    // -----------------------------
    // PC block
    // -----------------------------
    always_comb begin
        pc_d = pc_q;
        if (ui.pc_inc) pc_d = pc_q + 32'd4;
        if (ui.wr_pc)  pc_d = alu_y; // target provided via ALU mux path
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) pc_q <= 32'h0000_0000; else pc_q <= pc_d; end

    // -----------------------------
    // IR decode (32-bit encoding from spec)
    // opcode[31:26] | rd[25:22] | rs1[21:18] | rs2[17:14] | funct[13:8] | imm18[17:0]
    // -----------------------------
    wire [5:0] opcode = ir_q[31:26];
    always_comb begin
        rd    = ir_q[25:22];
        rs1   = ir_q[21:18];
        rs2   = ir_q[17:14];
        imm18 = ir_q[17:0];
    end

    // IR load
    always_ff @(posedge clk or posedge rst) begin
        if (rst) ir_q <= 32'h0000_0000; else if (ui.ir_load) ir_q <= mdr_q; end

    // Immediate latch (sign/zero handling can be steered by FUNCT bits later)
    always_ff @(posedge clk or posedge rst) begin
        if (rst)      imm_q <= 32'd0;
        else if (ui.imm_load) imm_q <= {{14{imm18[17]}}, imm18};
    end

    // -----------------------------
    // Microstore + Sequencer
    // -----------------------------
    microstore ustore (
        .clk  (clk),
        .addr (upc),
        .uinstr (ui)
    );

    sequencer useq (
        .clk       (clk),
        .rst       (rst),
        .ir_opcode (opcode),
        .flag_z    (nzcv_q[1]), // map Z to bit[1] if you like
        .flag_n    (nzcv_q[3]), // map N to bit[3]
        .ui        (ui),
        .upc       (upc)
    );

    // Commit pulse (endi returns to fetch)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            commit_valid <= 1'b0;
            commit_instr <= 32'd0;
        end else begin
            commit_valid <= ui.endi;
            if (ui.endi) commit_instr <= ir_q;
        end
    end

    // -----------------------------
    // Source muxes for ALU operands (REG/PC/MDR/IMM/MAR/CONST)
    // -----------------------------
    localparam SRC_REG  = 4'd0;
    localparam SRC_PC   = 4'd1;
    localparam SRC_MDR  = 4'd2;
    localparam SRC_IMM  = 4'd3;
    localparam SRC_MAR  = 4'd4;
    localparam SRC_C0   = 4'd5;
    localparam SRC_C1   = 4'd6;
    localparam SRC_C4   = 4'd7;

    // Select register operands according to a_is_rs1/b_is_rs2 flags
    logic [31:0] reg_sel_a, reg_sel_b;
    always_comb begin
        reg_sel_a = ui.a_is_rs1 ? rf_rd1 : rf_rd2; // choose rs1/rs2/rd by convention if extended
        reg_sel_b = ui.b_is_rs2 ? rf_rd2 : rf_rd1;
    end

    always_comb begin
        unique case (ui.src_a)
            SRC_REG:  alu_a = reg_sel_a;
            SRC_PC:   alu_a = pc_q;
            SRC_MDR:  alu_a = mdr_q;
            SRC_IMM:  alu_a = imm_q;
            SRC_MAR:  alu_a = mar_q;
            SRC_C0:   alu_a = 32'd0;
            SRC_C1:   alu_a = 32'd1;
            SRC_C4:   alu_a = 32'd4;
            default:  alu_a = 32'd0;
        endcase

        unique case (ui.src_b)
            SRC_REG:  alu_b = reg_sel_b;
            SRC_PC:   alu_b = pc_q;
            SRC_MDR:  alu_b = mdr_q;
            SRC_IMM:  alu_b = imm_q;
            SRC_MAR:  alu_b = mar_q;
            SRC_C0:   alu_b = 32'd0;
            SRC_C1:   alu_b = 32'd1;
            SRC_C4:   alu_b = 32'd4;
            default:  alu_b = 32'd0;
        endcase
    end

    // -----------------------------
    // Architectural write-backs
    // -----------------------------
    assign rf_we = ui.wr_rd;
    assign rf_wd = alu_y; // write-back value via ALU PASS/compute path

    always_ff @(posedge clk or posedge rst) begin
        if (rst)      mar_q <= 32'd0; else if (ui.wr_mar) mar_q <= alu_y; end
    always_ff @(posedge clk or posedge rst) begin
        if (rst)      mdr_q <= 32'd0; else if (ui.wr_mdr) mdr_q <= alu_y; end

    // -----------------------------
    // Unified memory + MMIO decode
    // ROM  : 0x0000_0000 .. 0x0000_FFFF  (hello.hex)
    // RAM  : 0x0001_0000 .. 0x000F_FFFF
    // UART : 0x1000_0000 .. 0x1000_00FF
    // TIMER: 0x1000_1000 .. 0x1000_10FF
    // -----------------------------
    function automatic bit is_rom(input logic [31:0] a);
        return (a[31:16] == 16'h0000);
    endfunction
    function automatic bit is_ram(input logic [31:0] a);
        return (a[31:16] >= 16'h0001 && a[31:16] <= 16'h000F);
    endfunction
    function automatic bit is_uart(input logic [31:0] a);
        return (a[31:8] == 24'h100000);
    endfunction
    function automatic bit is_timer(input logic [31:0] a);
        return (a[31:8] == 24'h100010);
    endfunction

    // Simple ROM/RAM models
    logic [31:0] rom [0:16383];   // 64 KB / 16K words
    logic [31:0] ram [0:262143];  // 1 MB / 256K words

    initial $readmemh("hello.hex", rom);

    // UART + Timer
    logic        uart_we;
    logic [7:0]  uart_din, uart_dout;
    uart u_uart (
        .clk     (clk),
        .we      (uart_we),
        .din     (uart_din),
        .dout    (uart_dout),
        .tx_ready(uart_tx_ready)
    );
    assign uart_tx_data = uart_dout;

    logic timer_irq;
    timer u_tim (.clk(clk), .rst(rst), .irq(timer_irq)); // irq not yet consumed by sequencer

    // Memory read cycle (blocking, 1-cycle for sim)
    always_ff @(posedge clk) begin
        if (ui.mem_rd) begin
            if (ui.io_space && is_uart(mar_q)) begin
                // UART read — return last TX value (loopback-friendly)
                mdr_q <= {24'd0, uart_dout};
            end else if (ui.io_space && is_timer(mar_q)) begin
                mdr_q <= {31'd0, timer_irq};
            end else if (is_rom(mar_q)) begin
                mdr_q <= rom[mar_q[15:2]]; // word-addressed
            end else if (is_ram(mar_q)) begin
                mdr_q <= ram[mar_q[19:2]];
            end else begin
                mdr_q <= 32'hDEAD_BEEF;
            end
        end
    end

    // Memory write cycle
    always_ff @(posedge clk) begin
        if (ui.mem_wr) begin
            if (ui.io_space && is_uart(mar_q)) begin
                uart_we  <= 1'b1;
                uart_din <= mdr_q[7:0];
            end else if (is_ram(mar_q)) begin
                ram[mar_q[19:2]] <= mdr_q;
                uart_we <= 1'b0;
            end else begin
                uart_we <= 1'b0; // ignore writes to ROM/invalid
            end
        end else begin
            uart_we <= 1'b0;
        end
    end

endmodule
