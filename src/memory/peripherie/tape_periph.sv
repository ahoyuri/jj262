import jj262_pkg::*;

// ============================================================================
//  periph_tape  —  Programme vom Band (Line-In) laden
//
//  Kodierung: ein Bit pro Schwingung, Frequenzumtastung.
//    kurze Periode -> 0,  lange Periode -> 1
//    Bei 25 MHz und 4410/2205 Hz:  5669 / 11338 Takte, Schwelle 8500.
//  Byte-Rahmen: Startbit 0, 8 Datenbits (LSB zuerst), Stoppbit 1.
//
//  Registerkarte (Byteadressen im IO-Fenster):
//    BASE+0   DATA     R   empfangenes Byte.  Lesen quittiert den IRQ.
//    BASE+2   STATUS   R   bit0 Byte da
//                          bit1 Rahmenfehler (Stoppbit war 0)
//                          bit2 Ueberlauf (Byte nicht abgeholt)
//                          bit3 Traeger erkannt (Flanken kommen)
//    BASE+4   CTRL     W   bit0 Empfaenger an
//                          bit1 Fehlerbits loeschen
//    BASE+6   THRESH   RW  Periodenschwelle in Takten (Vorgabe 8500)
//    BASE+8   ROMADDR  W   ROM-Schreibadresse (Wortadresse)
//    BASE+10  ROMDATA  W   Wort ins ROM schreiben, ROMADDR danach +1
//
//  Die CPU schreibt NIE direkt ins ROM — nur ueber ROMDATA. Der Bootbereich
//  bleibt zusaetzlich durch PROTECT in rom.sv geschuetzt.
// ============================================================================
module periph_tape #(
    parameter logic [7:0] BASE      = 8'h60,
    parameter logic [7:0] VEC       = 8'h05,
    parameter int         THRESH_DEF = 8500,
    parameter int         MAXPER     = 40000   // laenger = kein gueltiges Bit
)(
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    input  logic [8:0]  irq_in,
    output logic [8:0]  irq_out,
    output logic [15:0] q,
    output logic        sel,

    input  logic        TAPE_IN,          // vom Komparator am Line-In

    // ROM-Schreibport -> op_loader
    output logic [15:0] rom_wr_addr,
    output logic [15:0] rom_wr_data,
    output logic        rom_wr_en
);
    localparam logic [7:0] A_DATA    = BASE + 8'd0;
    localparam logic [7:0] A_STATUS  = BASE + 8'd2;
    localparam logic [7:0] A_CTRL    = BASE + 8'd4;
    localparam logic [7:0] A_THRESH  = BASE + 8'd6;
    localparam logic [7:0] A_ROMADDR = BASE + 8'd8;
    localparam logic [7:0] A_ROMDATA = BASE + 8'd10;

    assign sel = (addr >= BASE) && (addr <= A_ROMDATA);

    // ------------------------------------------------------------------
    //  Eingang synchronisieren + Flanke erkennen
    //  TAPE_IN kommt asynchron von aussen -> zwei Stufen sind Pflicht.
    // ------------------------------------------------------------------
    logic in_meta, in_sync, in_prev;
    always_ff @(posedge clk) begin
        in_meta <= TAPE_IN;
        in_sync <= in_meta;
        in_prev <= in_sync;
    end
    logic rise;
    assign rise = in_sync & ~in_prev;

    // ------------------------------------------------------------------
    //  Periode messen: Abstand zwischen zwei steigenden Flanken
    // ------------------------------------------------------------------
    logic        enable;
    logic [15:0] thresh;
    logic [15:0] per_cnt;
    logic        bit_val, bit_new;

    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            per_cnt <= '0;  bit_new <= 1'b0;  bit_val <= 1'b0;
        end else begin
            bit_new <= 1'b0;
            if (!enable) begin
                per_cnt <= '0;
            end else if (rise) begin
                if (per_cnt >= 16'd200 && per_cnt < MAXPER[15:0]) begin
                    bit_val <= (per_cnt > thresh);   // lange Periode = 1
                    bit_new <= 1'b1;
                end
                per_cnt <= '0;
            end else if (per_cnt != 16'hFFFF) begin
                per_cnt <= per_cnt + 16'd1;
            end
        end

    // Traeger erkannt, solange regelmaessig Flanken kommen
    logic carrier;
    assign carrier = (per_cnt < MAXPER[15:0]);

    // ------------------------------------------------------------------
    //  Byte-Rahmen:  IDLE -> 8 Datenbits -> Stoppbit
    // ------------------------------------------------------------------
    typedef enum logic [1:0] { R_IDLE, R_DATA, R_STOP } rx_e;
    rx_e         st;
    logic [3:0]  nbit;
    logic [7:0]  sh;

    logic [7:0]  data_reg;
    logic        ready, err_frame, err_over;

    logic data_read;
    assign data_read = re && sel && (addr == A_DATA);

    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            st <= R_IDLE;  nbit <= '0;  sh <= '0;
            data_reg <= '0;  ready <= 1'b0;
            err_frame <= 1'b0;  err_over <= 1'b0;
        end else begin
            if (data_read)                    ready <= 1'b0;      // Lesen quittiert
            if (we && sel && addr == A_CTRL && wdata[1]) begin
                err_frame <= 1'b0;  err_over <= 1'b0;
            end
            if (!enable) begin
                st <= R_IDLE;
            end else if (bit_new) begin
                unique case (st)
                    R_IDLE:
                        if (!bit_val) begin              // Startbit gefunden
                            st <= R_DATA;  nbit <= '0;
                        end
                    R_DATA: begin
                        sh <= {bit_val, sh[7:1]};        // LSB zuerst
                        if (nbit == 4'd7) st <= R_STOP;
                        else              nbit <= nbit + 4'd1;
                    end
                    R_STOP: begin
                        st <= R_IDLE;
                        if (bit_val) begin               // Stoppbit korrekt
                            if (ready && !data_read) err_over <= 1'b1;
                            data_reg <= sh;
                            ready    <= 1'b1;
                        end else begin
                            err_frame <= 1'b1;
                        end
                    end
                endcase
            end
        end

    // ------------------------------------------------------------------
    //  Steuerregister
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst)
        if (rst) begin
            enable <= 1'b0;
            thresh <= THRESH_DEF[15:0];
        end else if (we && sel) begin
            if (addr == A_CTRL)   enable <= wdata[0];
            if (addr == A_THRESH) thresh <= wdata;
        end

    // ------------------------------------------------------------------
    //  ROM-Schreibport
    //   ROMADDR setzen, dann je Wort ein Schreibzugriff auf ROMDATA.
    // ------------------------------------------------------------------
    logic [15:0] rom_addr;
    always_ff @(posedge clk or posedge rst)
        if (rst)                                   rom_addr <= '0;
        else if (we && sel && addr == A_ROMADDR)   rom_addr <= wdata;
        else if (we && sel && addr == A_ROMDATA)   rom_addr <= rom_addr + 16'd1;

    assign rom_wr_addr = rom_addr;
    assign rom_wr_data = wdata;
    assign rom_wr_en   = we && sel && (addr == A_ROMDATA);

    // ------------------------------------------------------------------
    //  IRQ:  ein Byte liegt bereit.  Lesen von DATA quittiert.
    // ------------------------------------------------------------------
    assign irq_out = ready ? {1'b1, VEC} : irq_in;

    // ------------------------------------------------------------------
    //  Lesepfad (kombinatorisch — io registriert zentral)
    // ------------------------------------------------------------------
    always_comb begin
        case (addr)
            A_DATA:    q = {8'b0, data_reg};
            A_STATUS:  q = {12'b0, carrier, err_over, err_frame, ready};
            A_THRESH:  q = thresh;
            A_ROMADDR: q = rom_addr;
            default:   q = 16'h0000;
        endcase
    end
endmodule
