import jj262_pkg::*;

// ============================================================================
//  periph_display  —  64x64 HUB75-Panel, 1 Bit pro Farbe (8 Farben)
//
//  Registerkarte (Byteadressen im IO-Fenster):
//    BASE+0   X       RW   Spalte 0..63
//    BASE+2   Y       RW   Zeile  0..63
//    BASE+4   COLOR   W    {B,G,R} in Bit 2..0  — SCHREIBEN SETZT DEN PIXEL
//                     R    zuletzt geschriebene Farbe
//    BASE+6   CTRL    W    bit0 = Anzeige an
//                          bit1 = Bildschirm loeschen (selbstloeschend)
//                          bit2 = X nach jedem Pixel automatisch +1
//                     R    bit15 = Loeschen laeuft noch
//
//  Pixel setzen:   X schreiben, Y schreiben, COLOR schreiben.
//  Mit AUTOINC reicht danach je ein COLOR-Schreibzugriff pro Pixel.
//
//  Framebuffer: zwei M4K-Bloecke (obere/untere Panelhaelfte), je 2048x3 Bit.
//  Port A liest der Scanner, Port B schreibt die CPU — kein Konflikt.
//
//  HUB75 zeigt pro Durchlauf nur 1 Bit je Farbe. Mehr Farbtiefe braucht
//  Binary Code Modulation (mehrere Durchlaeufe mit gewichteter Anzeigedauer);
//  das Register-Interface bliebe dabei unveraendert.
// ============================================================================
module periph_display #(
    parameter logic [7:0] BASE   = 8'h40,
    parameter logic [7:0] VEC    = 8'h04,
    parameter int         CLKDIV = 4        // Panel-Takt = clk / CLKDIV
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,

    // --- HUB75-Pins ---
    output logic [2:0]  HUB_RGB0,      // {B,G,R} obere Haelfte  (Zeilen 0..31)
    output logic [2:0]  HUB_RGB1,      // {B,G,R} untere Haelfte (Zeilen 32..63)
    output logic [4:0]  HUB_ADDR,      // A..E  Zeilenauswahl
    output logic        HUB_CLK,
    output logic        HUB_LAT,
    output logic        HUB_OE         // active low
);
    localparam logic [7:0] A_X     = BASE + 8'd0;
    localparam logic [7:0] A_Y     = BASE + 8'd2;
    localparam logic [7:0] A_COLOR = BASE + 8'd4;
    localparam logic [7:0] A_CTRL  = BASE + 8'd6;

    assign sel     = (addr >= BASE) && (addr <= A_CTRL);
    assign irq_out = irq_in;                        // wirft (noch) keinen IRQ

    // ========================================================================
    //  CPU-seitige Register
    // ========================================================================
    logic [5:0]  x_reg, y_reg;
    logic [2:0]  col_reg;
    logic        disp_on, autoinc;

    // Loeschvorgang
    logic        clr_busy;
    logic [10:0] clr_addr;

    logic px_we;                                    // ein Takt: Pixel schreiben
    assign px_we = we && sel && (addr == A_COLOR) && !clr_busy;

    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            x_reg <= '0;  y_reg <= '0;  col_reg <= '0;
            disp_on <= 1'b0;  autoinc <= 1'b0;
        end else begin
            if (we && sel) begin
                case (addr)
                    A_X:     x_reg   <= wdata[5:0];
                    A_Y:     y_reg   <= wdata[5:0];
                    A_COLOR: col_reg <= wdata[2:0];
                    A_CTRL:  begin disp_on <= wdata[0]; autoinc <= wdata[2]; end
                    default: ;
                endcase
            end
            if (px_we && autoinc) x_reg <= x_reg + 6'd1;
        end

    // Loeschzaehler
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            clr_busy <= 1'b0;  clr_addr <= '0;
        end else if (we && sel && addr == A_CTRL && wdata[1]) begin
            clr_busy <= 1'b1;  clr_addr <= '0;
        end else if (clr_busy) begin
            if (clr_addr == 11'd2047) clr_busy <= 1'b0;
            clr_addr <= clr_addr + 11'd1;
        end

    // ========================================================================
    //  Framebuffer: zwei Haelften, je 2048 x 3 Bit
    //   Adresse = {y[4:0], x[5:0]},  Haelfte = y[5]
    // ========================================================================
    logic [2:0] fb_hi [2048];
    logic [2:0] fb_lo [2048];

    logic [10:0] wr_addr;
    logic [2:0]  wr_data;
    logic        wr_hi, wr_lo;

    assign wr_addr = clr_busy ? clr_addr : {y_reg[4:0], x_reg};
    assign wr_data = clr_busy ? 3'b000   : wdata[2:0];
    assign wr_hi   = clr_busy ? 1'b1 : (px_we && !y_reg[5]);
    assign wr_lo   = clr_busy ? 1'b1 : (px_we &&  y_reg[5]);

    // ========================================================================
    //  Scanner:  1/32-Multiplex, schiebt 64 Pixel pro Zeile raus
    // ========================================================================
    localparam int DW = (CLKDIV < 2) ? 1 : $clog2(CLKDIV);
    logic [DW-1:0] div;
    logic          pstep;                           // ein Panel-Schritt
    always_ff @(posedge clk or posedge rst)
        if (rst)                     div <= '0;
        else if (div >= CLKDIV-1)    div <= '0;
        else                         div <= div + 1'b1;
    assign pstep = (div == 0);

    typedef enum logic [1:0] { S_SHIFT, S_BLANK, S_LATCH, S_SHOW } scan_e;
    scan_e       st;
    logic [5:0]  col;                               // 0..63
    logic [4:0]  row;                               // 0..31
    logic [7:0]  show_cnt;                          // Leuchtdauer

    logic [10:0] rd_addr;
    assign rd_addr = {row, col};

    logic [2:0] q_hi, q_lo;

    // --- M4K: Port A lesen (Scanner), Port B schreiben (CPU) ---------------
    always_ff @(posedge clk) begin
        if (wr_hi) fb_hi[wr_addr] <= wr_data;
        q_hi <= fb_hi[rd_addr];
    end
    always_ff @(posedge clk) begin
        if (wr_lo) fb_lo[wr_addr] <= wr_data;
        q_lo <= fb_lo[rd_addr];
    end

    assign HUB_CLK = (st == S_SHIFT) && (div == CLKDIV-1);

    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            st <= S_SHIFT;  col <= '0;  row <= '0;  show_cnt <= '0;
            //HUB_CLK <= 1'b0;  HUB_LAT <= 1'b0;  HUB_OE <= 1'b1;
            HUB_ADDR <= '0;
        end else if (pstep) begin
            //HUB_CLK <= 1'b0;
            HUB_LAT <= 1'b0;
            unique case (st)
                S_SHIFT: begin
                    //HUB_CLK <= 1'b1;                // Pixel uebernehmen
                    if (col == 6'd63) begin
                        col <= '0;
                        st  <= S_BLANK;
                    end else
                        col <= col + 6'd1;
                end
                S_BLANK: begin
                    HUB_OE   <= 1'b1;               // dunkel schalten
                    //HUB_ADDR <= row;                // Zeile anlegen
                    HUB_ADDR <= {row[3:0], row[4]}; // E rutscht auf A-Position
                    st       <= S_LATCH;
                end
                S_LATCH: begin
                    HUB_LAT  <= 1'b1;               // Schieberegister uebernehmen
                    show_cnt <= '0;
                    st       <= S_SHOW;
                end
                S_SHOW: begin
                    HUB_OE <= ~disp_on;             // leuchten lassen
                    if (show_cnt == 8'd200) begin
                        row <= row + 5'd1;          // naechste Zeile
                        st  <= S_SHIFT;
                    end else
                        show_cnt <= show_cnt + 8'd1;
                end
            endcase
        end

    assign HUB_RGB0 = (st == S_SHIFT) ? q_hi : 3'b000;
    assign HUB_RGB1 = (st == S_SHIFT) ? q_lo : 3'b000;

    // ========================================================================
    //  Lesepfad (kombinatorisch — io registriert zentral)
    // ========================================================================
    always_comb begin
        case (addr)
            A_X:     q = {10'b0, x_reg};
            A_Y:     q = {10'b0, y_reg};
            A_COLOR: q = {13'b0, col_reg};
            A_CTRL:  q = {clr_busy, 12'b0, autoinc, 1'b0, disp_on};
            default: q = 16'h0000;
        endcase
    end
endmodule
