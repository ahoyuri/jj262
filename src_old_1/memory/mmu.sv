import jj262_pkg::*;

module mmu (
    input  logic        clk,
    input  logic        rst,

    // von der CPU
    input  logic [15:0] abus,        // abus_result — Adresse
    input  logic [15:0] wdata,       // bus_result  — Schreibdaten
    input  logic        mem_re,
    input  logic        mem_we,
    input  logic        mem_byte,
    input  logic        mem_bsext,

    // zur CPU
    output logic [15:0] mem_q,       // Lesewert (RAM oder IO)
    output logic [7:0]  irq_vector,  // von der Daisy-Chain
    output logic        irq_pending, // synchronisiertes Sync-Bit (jetzt im cpu takt)

    // Board-Pins (durchgereicht zum io-Modul)
    input  logic [9:0]  SW,
    input  logic [3:0]  KEY,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3
);
    logic is_io, align_fault;
    assign is_io = (abus[15:12] == 4'hF);   // 0xF000+ -> IO

    logic [15:0] ram_q, io_q;
    logic [8:0] io_chain;
    logic [8:0] chain_final;
    assign align_fault = (mem_re | mem_we) & ~mem_byte & abus[0];

    memory u_mem (
        .clk(clk),
        .addr(abus),
        .wdata(wdata),
        .re(mem_re & ~is_io & ~align_fault),      // nur wenn NICHT IO
        .we(mem_we & ~is_io & ~align_fault),
        .byte_en(mem_byte),
        .bsext(mem_bsext),
        .q(ram_q)
    );

    io u_io (
        .clk(clk), .rst(rst),
        .addr(abus[7:0]),          // 8 Bit im IO-Fenster
        .wdata(wdata),
        .re(mem_re & is_io),
        .we(mem_we & is_io),
        .q(io_q),
        .irq_chain(io_chain),
        .SW(SW), .KEY(KEY), .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3)
    );
    assign chain_final = align_fault ? {1'b1, 8'h01} : io_chain;
    assign irq_vector  = chain_final[7:0];
    assign irq_pending = chain_final[8];

    assign mem_q = is_io ? io_q : ram_q;


endmodule



module memory #(
    parameter int DEPTH = 4096          // Wörter pro Bank
)(
    input  logic        clk,
    input  logic [15:0] addr,           // Byteadresse
    input  logic [15:0] wdata,
    input  logic        re,
    input  logic        we,
    input  logic        byte_en,        // 1 = Byte, 0 = Wort
    input  logic        bsext,          // bei Byte-Load: 1 = sign-ext
    output logic [15:0] q
);
    localparam int AW = $clog2(DEPTH);

    // Zwei Bänke: A = gerade Bytes, B = ungerade
    logic [7:0] bank_a [DEPTH];
    logic [7:0] bank_b [DEPTH];

    logic [AW-1:0] word_addr;
    logic          byte_sel;
    assign word_addr = addr[AW:1];      // Bit 0 raus -> Wortadresse
    assign byte_sel  = addr[0];         // welche Bank beim Byte-Zugriff

    // Write-Enables pro Bank
    logic we_a, we_b;
    assign we_a = we & (~byte_en | ~byte_sel);
    assign we_b = we & (~byte_en |  byte_sel);

    // Schreibdaten: bei Byte-Zugriff dasselbe Byte in beide Bänke,
    // das we entscheidet welche es nimmt
    logic [7:0] wd_a, wd_b;
    assign wd_a = byte_en ? wdata[7:0] : wdata[7:0];
    assign wd_b = byte_en ? wdata[7:0] : wdata[15:8];

    // --- die eigentlichen M4K-Blöcke ---
    logic [7:0] qa, qb;
    always_ff @(posedge clk) begin
        if (we_a) bank_a[word_addr] <= wd_a;
        qa <= bank_a[word_addr];        // Lesen: immer, registriert
    end
    always_ff @(posedge clk) begin
        if (we_b) bank_b[word_addr] <= wd_b;
        qb <= bank_b[word_addr];
    end

    // Ausgangs-Mux: Wort oder Byte (mit Extension)
    logic [7:0] sel_byte;
    assign sel_byte = byte_sel ? qb : qa;
    assign q = byte_en
             ? (bsext ? {{8{sel_byte[7]}}, sel_byte} : {8'b0, sel_byte})
             : {qb, qa};                // Little-Endian!
endmodule