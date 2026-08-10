import jj262_pkg::*;

module io (
    input  logic        clk, rst,
    input  logic [7:0]  addr,
    input  logic [15:0] wdata,
    input  logic        we, re,
    output logic [15:0] q,
    output logic [8:0]  irq_chain,     // {valid, vektor} — MMU haengt sich dran
    input  logic [9:0]  SW,
    input  logic [3:0]  KEY,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    output logic [2:0]  HUB_RGB0, HUB_RGB1,
    output logic [4:0]  HUB_ADDR,
    output logic        HUB_CLK, HUB_LAT, HUB_OE,
    // --- neu: Tape ---
    input  logic        TAPE_IN,
    output logic [15:0] rom_wr_addr,
    output logic [15:0] rom_wr_data,
    output logic        rom_wr_en
);
    logic [15:0] q_hex, q_led, q_sw, q_key;
    logic        sel_hex, sel_led, sel_sw, sel_key;
    logic [15:0] q_tmr;
    logic        sel_tmr;
    logic [15:0] q_dsp;
    logic [15:0] q_tap;
    logic        sel_tap;
    logic        sel_dsp;
    logic [8:0]  ch_hex, ch_led, ch_sw, ch_key, ch_tmr, ch_dsp, ch_tap;
    logic [15:0] q_tape;
    logic        sel_tape;
    logic [8:0]  ch_tape;

    // --- Peripherie-Instanzen. Reihenfolge = Prioritaet, spaeter = hoeher ---
    periph_hex #(.BASE(8'h00)) u_hex (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(9'b0), .irq_out(ch_hex),        // Terminator am Anfang
        .q(q_hex), .sel(sel_hex),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3)
    );
    periph_led #(.BASE(8'h02)) u_led (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_hex), .irq_out(ch_led),
        .q(q_led), .sel(sel_led), .LEDR(LEDR)
    );
    periph_sw #(.BASE(8'h10)) u_sw (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_led), .irq_out(ch_sw),
        .q(q_sw), .sel(sel_sw), .SW(SW)
    );
    periph_key #(.BASE(8'h12), .VEC(8'h02)) u_key (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_sw), .irq_out(ch_key),
        .q(q_key), .sel(sel_key), .KEY(KEY)
    );
    periph_timer #(.BASE(8'h20), .VEC(8'h03)) u_tmr (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_key), .irq_out(ch_tmr),
        .q(q_tmr), .sel(sel_tmr)
    );
    periph_display #(.BASE(8'h40)) u_dsp (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_tmr), .irq_out(ch_dsp),
        .q(q_dsp), .sel(sel_dsp),
        .HUB_RGB0(HUB_RGB0), .HUB_RGB1(HUB_RGB1), .HUB_ADDR(HUB_ADDR),
        .HUB_CLK(HUB_CLK), .HUB_LAT(HUB_LAT), .HUB_OE(HUB_OE)
    );
    periph_tape #(.BASE(8'h60)) u_tap (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata), .we(we), .re(re),
        .irq_in(ch_dsp), .irq_out(ch_tap),
        .q(q_tap), .sel(sel_tap),
        .TAPE_IN(TAPE_IN),
        .rom_wr_addr(rom_wr_addr), .rom_wr_data(rom_wr_data), .rom_wr_en(rom_wr_en)
    );


    assign irq_chain = ch_tap;              // letztes Glied raus zur MMU

    // --- Lesemux + EIN Register (Latenz wie RAM) ---
    logic [15:0] q_next;
    always_comb begin
        if      (sel_hex) q_next = q_hex;
        else if (sel_led) q_next = q_led;
        else if (sel_sw)  q_next = q_sw;
        else if (sel_key) q_next = q_key;
        else if (sel_tmr) q_next = q_tmr;
        else if (sel_dsp) q_next = q_dsp;
        else if (sel_tap) q_next = q_tap;
        else              q_next = 16'h0000;
    end
    always_ff @(posedge clk or posedge rst)
        if (rst) q <= '0;
        else     q <= q_next;
endmodule