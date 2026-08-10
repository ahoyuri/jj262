import jj262_pkg::*;

module op_loader #(
    parameter int DEPTH = 4096
)(
    input  logic        clk, rst,

    // CPU
    input  logic        done,          // ctrl.done
    input  logic        halt,          // ctrl.halt — PC einfrieren
    input  logic        pc_we,         // ctrl.pc_we
    input  logic [15:0] pc_load,       // bus_result (Sprungziel)
    output logic [15:0] pc,            // -> datapath (BUS_PC)
    output logic [15:0] iw,            // -> cu, datapath
    output logic        injected,      // NEU: 1 = INT wurde injiziert (HW-IRQ)

    // Interrupt
    input  logic        irq_pending,
    input  logic [7:0]  irq_vector,
    input  logic        irq_enabled,   // flags[FLG_IE]

    // ROM-Schreibport (Tape-Peripherie)
    input  logic [15:0] rom_wr_addr,
    input  logic [15:0] rom_wr_data,
    input  logic        rom_wr_en
);
    localparam int AW = $clog2(DEPTH);

    // --- Injektionszustand: haelt den INT-Opcode ueber alle 3 Phasen ---
    logic       inj_active;
    logic [7:0] inj_vec;
    logic       irq_take;

    assign irq_take = done & irq_pending & irq_enabled & ~inj_active;

    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            inj_active <= 1'b0;
            inj_vec    <= '0;
        end else if (irq_take) begin
            inj_active <= 1'b1;
            inj_vec    <= irq_vector;       // Vektor festhalten
        end else if (done) begin
            inj_active <= 1'b0;             // INT durchgelaufen
        end

    // --- PC ---
    logic [15:0] pc_next;

    pc_reg u_pc (
        .clk(clk), .rst(rst),
        .load(pc_we), .load_val(pc_load),
        .advance(done & ~halt),
        .pc(pc), .pc_next(pc_next)
    );

    // --- ROM: Port A liest pc_next -> q ist immer mem[pc] ---
    logic [15:0] rom_q;
    rom #(.DEPTH(DEPTH)) u_rom (
        .clk    (clk),
        .addr_a (pc_next[AW-1:0]),
        .q_a    (rom_q),
        .addr_b (rom_wr_addr[AW-1:0]),
        .data_b (rom_wr_data),
        .we_b   (rom_wr_en)
    );

    // --- IW: ROM-Wort oder injizierter INT-Befehl ---
    assign injected = inj_active;
    assign iw = inj_active ? {GRP_MISC, MOP_INT, inj_vec} : rom_q;

endmodule