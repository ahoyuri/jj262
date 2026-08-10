import jj262_pkg::*;

module rom #(
    parameter int    DEPTH     = 4096,        // Wörter
    parameter int    PROTECT   = 768         // unterste N Wörter schreibgeschützt
    //parameter string INIT_FILE = "boot.hex"
)(
    input  logic                     clk,

    // Port A — Fetch, nur lesen
    input  logic [$clog2(DEPTH)-1:0] addr_a,
    output logic [15:0]              q_a,

    // Port B — Tape-Peripherie, nur schreiben
    input  logic [$clog2(DEPTH)-1:0] addr_b,
    input  logic [15:0]              data_b,
    input  logic                     we_b
);
    logic [15:0] mem [DEPTH];

    // Bootcode schützen: Tape darf die unteren PROTECT Wörter nicht überschreiben
    logic we_ok;
    assign we_ok = we_b && (addr_b >= PROTECT[$clog2(DEPTH)-1:0]);

    // Simple Dual-Port: ein Lese-, ein Schreibport, gemeinsamer Takt.
    // muster für Quartus als M4K.
    always_ff @(posedge clk) begin
        if (we_ok) mem[addr_b] <= data_b;
        q_a <= mem[addr_a];              // registriert -> ein Takt Latenz
    end

    // Bootcode beim Start hineinbacken
    //initial $readmemh(INIT_FILE, mem);
    initial $readmemh("src/boot.hex", mem);
endmodule