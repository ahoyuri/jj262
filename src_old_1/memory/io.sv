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
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3
);
    logic [15:0] q_hex, q_led, q_sw, q_key;
    logic        sel_hex, sel_led, sel_sw, sel_key;
    logic [8:0]  ch_hex, ch_led, ch_sw, ch_key;

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

    assign irq_chain = ch_key;              // letztes Glied raus zur MMU

    // --- Lesemux + EIN Register (Latenz wie RAM) ---
    logic [15:0] q_next;
    always_comb begin
        if      (sel_hex) q_next = q_hex;
        else if (sel_led) q_next = q_led;
        else if (sel_sw)  q_next = q_sw;
        else if (sel_key) q_next = q_key;
        else              q_next = 16'h0000;
    end
    always_ff @(posedge clk or posedge rst)
        if (rst) q <= '0;
        else     q <= q_next;
endmodule