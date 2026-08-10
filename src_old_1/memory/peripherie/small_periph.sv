import jj262_pkg::*;

// ============================================================================
//  small_periph.sv  —  kleine Board-Peripherien fuer JJ262
//
//  Einheitliche Signatur (siehe periph_xxx unten):
//    - addr/wdata/we/re : Zugriff aus dem IO-Fenster (addr = abus[7:0])
//    - sel              : "diese Adresse gehoert mir"  (kombinatorisch)
//    - q                : Lesewert                     (kombinatorisch!)
//                         io registriert einmal zentral -> Latenz wie RAM
//    - irq_in/irq_out   : Daisy-Chain, 9 Bit {valid, vektor}
//                         irq_out = eigener IRQ, sonst irq_in durchreichen
//                         -> spaeter instanziiert = hoehere Prioritaet
//
//  Adressen sind BYTEadressen. Register liegen 2 auseinander (Wortzugriff).
// ============================================================================


// ----------------------------------------------------------------------------
//  Vorlage — kopieren fuer neue Peripherie
// ----------------------------------------------------------------------------
module periph_xxx #(
    parameter logic [7:0] BASE = 8'h00,
    parameter logic [7:0] VEC  = 8'h00
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel
);
    assign sel = (addr == BASE);

    // eigene Logik hier

    logic my_irq;
    assign my_irq  = 1'b0;                                  // wirft nichts
    assign irq_out = my_irq ? {1'b1, VEC} : irq_in;
    assign q       = 16'h0000;
endmodule


// ----------------------------------------------------------------------------
//  periph_hex — 4 Hexziffern auf HEX0..HEX3
//    BASE   : W = Wert, R = Rueckgelesener Wert
//  DE1: 7-Segment ist ACTIVE LOW (Segment an = Bit 0).
// ----------------------------------------------------------------------------
module periph_hex #(
    parameter logic [7:0] BASE = 8'h00,
    parameter logic [7:0] VEC  = 8'h00
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3
);
    assign sel     = (addr == BASE);
    assign irq_out = irq_in;                    // kein eigener IRQ

    logic [15:0] val;
    always_ff @(posedge clk or posedge rst)
        if (rst)             val <= '0;
        else if (we && sel)  val <= wdata;

    assign q = val;                             // rueckliesbar

    function automatic logic [6:0] seg(logic [3:0] d);
        case (d)                    //      gfedcba
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;          // alles aus
        endcase
    endfunction

    assign HEX0 = seg(val[3:0]);
    assign HEX1 = seg(val[7:4]);
    assign HEX2 = seg(val[11:8]);
    assign HEX3 = seg(val[15:12]);
endmodule


// ----------------------------------------------------------------------------
//  periph_led — 10 rote LEDs
//    BASE : W = Muster (nur Bits 9:0), R = Rueckgelesen
// ----------------------------------------------------------------------------
module periph_led #(
    parameter logic [7:0] BASE = 8'h02,
    parameter logic [7:0] VEC  = 8'h00
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,
    output logic [9:0]  LEDR
);
    assign sel     = (addr == BASE);
    assign irq_out = irq_in;

    logic [9:0] val;
    always_ff @(posedge clk or posedge rst)
        if (rst)             val <= '0;
        else if (we && sel)  val <= wdata[9:0];

    assign LEDR = val;
    assign q    = {6'b0, val};
endmodule


// ----------------------------------------------------------------------------
//  periph_sw — 10 Schiebeschalter, nur lesbar
//    BASE : R = Schalterzustand
//  SW kommt asynchron vom Board -> 2-FF-Sync.
// ----------------------------------------------------------------------------
module periph_sw #(
    parameter logic [7:0] BASE = 8'h10,
    parameter logic [7:0] VEC  = 8'h00
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,
    input  logic [9:0]  SW
);
    assign sel     = (addr == BASE);
    assign irq_out = irq_in;

    logic [9:0] sw_meta, sw_sync;
    always_ff @(posedge clk) begin
        sw_meta <= SW;
        sw_sync <= sw_meta;
    end

    assign q = {6'b0, sw_sync};
endmodule


// ----------------------------------------------------------------------------
//  periph_key — 4 Taster, entprellt, mit Interrupt
//    BASE : R = Zustand (1 = gedrueckt),  W = Interrupt quittieren
//
//  KEY ist ACTIVE LOW und prellt mechanisch.
//  IRQ auf FLANKE (nicht Pegel): ein Druck dauert ~100 ms, Pegel wuerde
//  tausendfach feuern. Latch bleibt bis zum Ack stehen.
// ----------------------------------------------------------------------------
module periph_key #(
    parameter logic [7:0] BASE  = 8'h12,
    parameter logic [7:0] VEC   = 8'h02,
    parameter int         DEB_N = 500_000      // ~10 ms bei 50 MHz
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,
    input  logic [3:0]  KEY
);
    localparam int DEB_W = $clog2(DEB_N + 1);

    assign sel = (addr == BASE);

    // 2-FF-Sync: KEY ist asynchron
    logic [3:0] key_meta, key_sync;
    always_ff @(posedge clk) begin
        key_meta <= ~KEY;                       // invertieren: 1 = gedrueckt
        key_sync <= key_meta;
    end

    // Entpreller: Zustand muss DEB_N Takte stabil sein
    logic [3:0]       key_last, key_stable;
    logic [DEB_W-1:0] cnt;
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            key_last   <= '0;
            key_stable <= '0;
            cnt        <= '0;
        end else if (key_sync != key_last) begin
            key_last <= key_sync;               // Aenderung -> Zaehler neu
            cnt      <= '0;
        end else if (cnt < DEB_N[DEB_W-1:0]) begin
            cnt <= cnt + 1'b1;
        end else begin
            key_stable <= key_last;             // stabil -> uebernehmen
        end

    // Flankenerkennung + IRQ-Latch
    logic [3:0] key_prev;
    always_ff @(posedge clk or posedge rst)
        if (rst) key_prev <= '0;
        else     key_prev <= key_stable;

    logic pressed;
    assign pressed = |(key_stable & ~key_prev); // steigende Flanke

    logic irq_latch;
    always_ff @(posedge clk or posedge rst)
        if (rst)              irq_latch <= 1'b0;
        else if (pressed)     irq_latch <= 1'b1;
        else if (we && sel)   irq_latch <= 1'b0;    // Schreiben = Ack

    assign irq_out = irq_latch ? {1'b1, VEC} : irq_in;
    assign q       = {12'b0, key_stable};
endmodule
