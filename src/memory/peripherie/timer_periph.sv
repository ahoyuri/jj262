import jj262_pkg::*;

// ============================================================================
//  periph_timer  —  Prescaler + Abwaertszaehler mit Auto-Reload
//
//  Registerkarte (Byteadressen im IO-Fenster):
//    BASE+0   RELOAD    RW   Periode.  Zaehler laeuft RELOAD..0, dann IRQ.
//    BASE+2   COUNT     R    aktueller Zaehlerstand
//                       W    IRQ quittieren (Wert egal)
//    BASE+4   CTRL      RW   bit0 = EN (Zaehler laeuft)
//                            bit1 = IE (IRQ erzeugen)
//                            bit15 = IRQ liegt an  (nur lesbar)
//    BASE+6   PRESCALE  RW   Vorteiler.  Tick alle (PRESCALE+1) Takte.
//
//  Periode = (PRESCALE+1) * (RELOAD+1) Takte.
//  Beispiel 25 MHz, 1 ms:  PRESCALE=249, RELOAD=99  -> 250*100 = 25000 Takte.
//
//  Der Handler MUSS quittieren (Schreiben auf COUNT), sonst feuert der
//  Interrupt sofort wieder — gleiche Regel wie bei periph_key.
// ============================================================================
module periph_timer #(
    parameter logic [7:0] BASE = 8'h20,
    parameter logic [7:0] VEC  = 8'h03
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
    // --- Adressdekodierung: 4 Register, 8 Byte ------------------------------
    localparam logic [7:0] A_RELOAD = BASE + 8'd0;
    localparam logic [7:0] A_COUNT  = BASE + 8'd2;
    localparam logic [7:0] A_CTRL   = BASE + 8'd4;
    localparam logic [7:0] A_PRESC  = BASE + 8'd6;

    assign sel = (addr >= BASE) && (addr <= A_PRESC);

    // --- Register ----------------------------------------------------------
    logic [15:0] reload_v, presc_v;
    logic        en, ie;
    logic [15:0] cnt;          // Hauptzaehler
    logic [15:0] pcnt;         // Vorteiler
    logic        irq_latch;

    logic tick;                // ein Takt pro Vorteiler-Durchlauf
    assign tick = en && (pcnt >= presc_v);

    logic wrap;                // Hauptzaehler laeuft ueber
    assign wrap = tick && (cnt == 16'h0000);

    // --- Steuerregister schreiben ------------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            reload_v <= 16'hFFFF;
            presc_v  <= 16'h0000;
            en       <= 1'b0;
            ie       <= 1'b0;
        end else if (we && sel) begin
            case (addr)
                A_RELOAD: reload_v <= wdata;
                A_PRESC:  presc_v  <= wdata;
                A_CTRL:   begin en <= wdata[0]; ie <= wdata[1]; end
                default: ;                      // A_COUNT: nur Ack, s.u.
            endcase
        end

    // --- Vorteiler ---------------------------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst)                          pcnt <= '0;
        else if (!en)                     pcnt <= '0;
        else if (pcnt >= presc_v)         pcnt <= '0;
        else                              pcnt <= pcnt + 16'd1;

    // --- Hauptzaehler ------------------------------------------------------
    //  Neuladen bei: Reset, Schreiben auf RELOAD, Durchlauf.
    always_ff @(posedge clk or posedge rst)
        if (rst)                              cnt <= 16'hFFFF;
        else if (we && sel && addr == A_RELOAD) cnt <= wdata;
        else if (wrap)                        cnt <= reload_v;
        else if (tick)                        cnt <= cnt - 16'd1;

    // --- IRQ-Latch: bleibt bis zum Ack -------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst)                               irq_latch <= 1'b0;
        else if (wrap && ie)                   irq_latch <= 1'b1;
        else if (we && sel && addr == A_COUNT)  irq_latch <= 1'b0;   // Ack

    // --- Daisy-Chain -------------------------------------------------------
    assign irq_out = irq_latch ? {1'b1, VEC} : irq_in;

    // --- Lesepfad (kombinatorisch, io registriert zentral) -----------------
    always_comb begin
        case (addr)
            A_RELOAD: q = reload_v;
            A_COUNT:  q = cnt;
            A_CTRL:   q = {irq_latch, 13'b0, ie, en};
            A_PRESC:  q = presc_v;
            default:  q = 16'h0000;
        endcase
    end
endmodule
