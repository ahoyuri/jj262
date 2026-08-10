// ============================================================================
//  jj262_pkg.sv  —  ISA-Definition JJ262
//
//  Befehlswort: 16 Bit, immer ein Wort.
//      [15:8] = Opcode
//      [ 7:0] = XY (Daten / Displacement / Vektor)
//
//  Opcode-Aufteilung:
//      op[7:6] = 00  ->  Misc          (misc_op_e ueber op[5:0], 64 Slots)
//      op[7:6] = 01  ->  ALU           (op[7] = 0)
//      op[7:6] = 10  ->  Sprung/Call
//      op[7:6] = 11  ->  ALU erweitert (op[7] = 1)
//
//  Daraus:
//      is_alu   = op[6]                    <- ein Draht
//      alu_op   = {op[7], op[3:0]}         <- 5 Bit, 32 Operationen
//      alu_src  = op[5:4]
//      cond     = op[3:0]
//
//  Invariante: Befehlswort 0x0000 == NOP. Alle *_we sind active high,
//  ctrl = '0 bedeutet "nichts passiert".
// ============================================================================

package jj262_pkg;

  // --------------------------------------------------------------------------
  // Gruppen
  // --------------------------------------------------------------------------
  localparam logic [1:0] GRP_MISC = 2'b00;
  localparam logic [1:0] GRP_ALU  = 2'b01;   // op[7] = 0
  localparam logic [1:0] GRP_JMP  = 2'b10;
  localparam logic [1:0] GRP_ALUX = 2'b11;   // op[7] = 1

  // --------------------------------------------------------------------------
  // 1) misc_op_e  —  op[5:0], Gruppe 00
  //    XY ist hier durchgaengig UNSIGNED (0..255).
  // --------------------------------------------------------------------------
  typedef enum logic [5:0] {
    MOP_NOP     = 6'h00,  // Gesamtbyte 0x00 -> Nullwort = NOP

    // Immediate -> Register
    //   *L : Ziel = zext(XY)      loescht das High-Byte
    //   *H : Ziel[15:8] = XY      Low-Byte bleibt stehen  (immer L vor H!)
    MOP_MILAK   = 6'h01,
    MOP_MIHAK   = 6'h02,
    MOP_MILPT   = 6'h03,
    MOP_MIHPT   = 6'h04,
    MOP_MILSP   = 6'h05,
    MOP_MIHSP   = 6'h06,

    // Register -> Register, alle ueber das Adressrechenwerk (Basis + XY)
    MOP_MAPT    = 6'h07,  // PTR = AKK + XY
    MOP_MPAK    = 6'h08,  // AKK = PTR + XY
    MOP_MASP    = 6'h09,  // SP  = AKK + XY
    MOP_MPSP    = 6'h0A,  // SP  = PTR + XY
    MOP_MSAK    = 6'h0B,  // AKK = SP  + XY   <- LEA / &local
    MOP_MSPT    = 6'h0C,  // PTR = SP  + XY   <- LEA

    // Frame
    MOP_ADDSP   = 6'h0D,  // SP = SP + XY
    MOP_SUBSP   = 6'h0E,  // SP = SP - XY

    // PTR-Arithmetik
    MOP_INCPT   = 6'h0F,  // PTR = PTR + XY
    MOP_DECPT   = 6'h10,  // PTR = PTR - XY

    // Wort-Loads:  Ziel = [Basis + XY]
    MOP_LPAK    = 6'h11,  // AKK = [PTR+XY]
    MOP_LPPT    = 6'h12,  // PTR = [PTR+XY]
    MOP_LAAK    = 6'h13,  // AKK = [AKK+XY]
    MOP_LAPT    = 6'h14,  // PTR = [AKK+XY]
    MOP_LSAK    = 6'h15,  // AKK = [SP+XY]
    MOP_LSPT    = 6'h16,  // PTR = [SP+XY]

    // Wort-Stores: [Basis + XY] = Quelle
    MOP_SAPT    = 6'h17,  // [PTR+XY] = AKK
    MOP_SPPT    = 6'h18,  // [PTR+XY] = PTR
    MOP_SASP    = 6'h19,  // [SP+XY]  = AKK
    MOP_SPSP    = 6'h1A,  // [SP+XY]  = PTR

    // Byte-Zugriffe ueber PTR (Strings, char-Arrays)
    MOP_LBPAK   = 6'h1B,  // AKK = sext(byte [PTR+XY])   signed char
    MOP_LBUPAK  = 6'h1C,  // AKK = zext(byte [PTR+XY])   unsigned char
    MOP_SBPT    = 6'h1D,  // byte [PTR+XY] = AKK[7:0]

    // Speicher -> Speicher (beide Zeiger ueberleben)
    MOP_MVAP    = 6'h1E,  // [PTR+XY] = [AKK+XY]
    MOP_MVPA    = 6'h1F,  // [AKK+XY] = [PTR+XY]

    // Stack (XY ignoriert, Schrittweite immer 2)
    MOP_PUSHA   = 6'h20,
    MOP_POPA    = 6'h21,
    MOP_PUSHP   = 6'h22,
    MOP_POPP    = 6'h23,
    MOP_PUSHF   = 6'h24,  // Flags sichern
    MOP_POPF    = 6'h25,

    // Ablaufsteuerung
    MOP_RET     = 6'h26,  // POP PC
    MOP_RETI    = 6'h27,  // POP Flags, POP PC, IRQ frei
    MOP_INT     = 6'h28,  // XY = Vektor (< 0x10 = Hardware)
    MOP_EI      = 6'h29,
    MOP_DI      = 6'h2A,
    MOP_HALT    = 6'h2B,

    //weiter sprung
    MOP_JMPP    ? 6'h2C
    // 6'h2D .. 6'h3F frei
  } misc_op_e;

  // --------------------------------------------------------------------------
  // 2) alu_op_e  —  {op[7], op[3:0]}
  //    Semantik durchgaengig: AKK = AKK <op> SRC
  // --------------------------------------------------------------------------
  typedef enum logic [4:0] {
    // ---- op[7] = 0  ->  Opcode 0x40..0x7F ----
    ALU_ADD  = 5'h00,
    ALU_SUB  = 5'h01,
    ALU_ADC  = 5'h02,
    ALU_SUC  = 5'h03,
    ALU_AND  = 5'h04,
    ALU_OR   = 5'h05,
    ALU_XOR  = 5'h06,
    ALU_NOT  = 5'h07,   // unaer: AKK = ~SRC
    ALU_SHL  = 5'h08,   // Schiebeweite kommt aus SRC
    ALU_SHR  = 5'h09,
    ALU_ASR  = 5'h0A,
    ALU_ROL  = 5'h0B,   // durch Carry
    ALU_ROR  = 5'h0C,
    ALU_NEG  = 5'h0D,   // unaer: AKK = -SRC
    ALU_CMP  = 5'h0E,   // SUB ohne Writeback
    ALU_TST  = 5'h0F,   // AND ohne Writeback
    // ---- op[7] = 1  ->  Opcode 0xC0..0xFF ----
    ALU_MUL  = 5'h10,   // AKK = low16 (AKK * SRC)   mehrtaktig
    ALU_MULH = 5'h11    // AKK = high16(AKK * SRC)   mehrtaktig
    // 5'h12 .. 5'h1F frei
  } alu_op_e;

  // --------------------------------------------------------------------------
  // 3) alu_src_e  —  op[5:4]
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    SRC_PTR = 2'b00,   // AKK op PTR          XY wird ignoriert
    SRC_IMM = 2'b01,   // AKK op zext(XY)
    SRC_MP  = 2'b10,   // AKK op [PTR+XY]     2 Takte
    SRC_MS  = 2'b11    // AKK op [SP+XY]      2 Takte
  } alu_src_e;

  // --------------------------------------------------------------------------
  // 4) cond_e  —  op[3:0]
  //    Sprung-Opcode: {GRP_JMP, tgt_ptr, link, cond}
  //      tgt_ptr = 0 -> PC  + sext(XY)      1 -> PTR + sext(XY)
  //      link    = 0 -> JMP                 1 -> CALL (pusht PC)
  //    XY ist hier SIGNED (-128..+127).
  // --------------------------------------------------------------------------
  typedef enum logic [3:0] {
    COND_AL = 4'h0,   // immer
    COND_Z  = 4'h1,
    COND_NZ = 4'h2,
    COND_C  = 4'h3,   // unsigned <
    COND_NC = 4'h4,   // unsigned >=
    COND_S  = 4'h5,
    COND_NS = 4'h6,
    COND_V  = 4'h7,
    COND_NV = 4'h8,
    COND_GE = 4'h9,   // signed >=   S == V
    COND_LT = 4'hA,   // signed <    S != V
    COND_GT = 4'hB,   // signed >    !Z && S == V
    COND_LE = 4'hC,   // signed <=    Z || S != V
    COND_HI = 4'hD,   // unsigned >  !C && !Z
    COND_LS = 4'hE    // unsigned <=  C ||  Z
    // 4'hF frei
  } cond_e;

  // ==========================================================================
  //  Datenpfad-Selektoren
  // ==========================================================================
  
  //
  //  Zwei-Bus-Datenpfad:
  //
  //    Datenbus:   bus_src --(off)--> [ ROUTE_DIRECT | ROUTE_ALU ] --> bus_dst
  //    Adressbus:  abus_src --(off)--> M4K-Adressport  (immer, kein dst noetig)
  //
  //  Jeder Bus hat eigene Offset-Steuerung (offset_e + offset_sel_e).
  //
  typedef enum logic [2:0] { BUS_ZERO, BUS_AKK, BUS_PTR, BUS_SP, BUS_PC, BUS_RMEM, BUS_FLG } bus_src_e;
  typedef enum logic [1:0] { ABUS_AKK, ABUS_PTR, ABUS_SP, ABUS_PC }                 abus_src_e;
  typedef enum logic       { ROUTE_DIRECT, ROUTE_ALU }                              route_e;
  typedef enum logic [2:0] { DST_NONE, DST_AKK, DST_PTR, DST_SP, DST_PC, DST_WMEM, DST_FLG } bus_dst_e;

  typedef enum logic { OFF_S_ADD, OFF_S_SUB } offset_sel_e;  // Addierer: base + off / base - off

  typedef enum logic [2:0] {
    OFF_ZERO     = 3'd0,
    OFF_ZDISP    = 3'd1,   // + zext(XY)   Adressrechnung / kleine Konstanten
    OFF_SDISP    = 3'd2,   // + sext(XY)   Spruenge
    OFF_TWO      = 3'd3,   // + 2          PUSH/POP/CALL/RET (haelt SP gerade)
    OFF_IMM_HIGH = 3'd4    // {XY, base[7:0]}  Konkatenation statt Addition (MIH*)
  } offset_e;

  // ==========================================================================
  //  Flagregister-Layout — 5 Bit: {IE, V, S, C, Z}
  //    IE ist ein ganz normales Flagregister-Bit statt ein separates
  //    Register. Damit sichern PUSHF/POPF (und RETI ueber POPF) IE automatisch
  //    mit — RETI braucht kein eigenes irq_set mehr (siehe cu.sv, MOP_RETI).
  //    Nebenwirkung (wie bei x86): POPF kann IE versehentlich umschalten.
  // ==========================================================================
  localparam int FLG_W  = 5;
  localparam int FLG_Z  = 0;
  localparam int FLG_C  = 1;
  localparam int FLG_S  = 2;
  localparam int FLG_V  = 3;
  localparam int FLG_IE = 4;

  // ==========================================================================
  //  Steuerwort  —  Stellung aller Muxe fuer einen Mikroschritt.
  //  ctrl = '0  bedeutet: alle Enables aus, nichts passiert (NOP).
  // ==========================================================================
  typedef struct packed {
    // ---- Register-Write-Enables (lesen vom Datenbus) ----
    logic        akk_we;
    logic        ptr_we;
    logic        sp_we;
    logic        pc_we;
    logic        flg_we;       // Flags <- Datenbus (POPF, RETI)
    logic        flags_we;     // Flags <- ALU-Ergebnis (jede ALU-Op)

    // SP <- Adressbus-Addierer. Erlaubt PUSH in 1 Takt:
    //   abus = SP-2 geht GLEICHZEITIG an den Schreibport und zurueck nach SP.
    logic        sp_abus_we;

    // ---- Datenbus: Quelle -> (Offset) -> Route -> Ziel ----
    bus_src_e    bus_src;
    offset_e     bus_off;      // Offset auf den Datenbus-Addierer
    offset_sel_e bus_addsub;   // add / sub am Datenbus-Addierer
    route_e      route;        // ROUTE_DIRECT | ROUTE_ALU
    bus_dst_e    bus_dst;      // Ziel (inkl. DST_WMEM = Schreibdatenport)

    // ---- Adressbus: Quelle -> (Offset) -> M4K-Adressport ----
    abus_src_e   abus_src;
    offset_e     abus_off;     // eigener Offset fuer den Adressbus-Addierer
    offset_sel_e abus_addsub;

    // ---- Speichersteuerung ----
    logic        mem_re;       // Lesezugriff aktiv (Port A)
    logic        mem_we;       // Schreibzugriff aktiv (Port B)
    logic        mem_byte;     // 1 = Byte-Zugriff, 0 = Wort
    logic        mem_bsext;    // bei Byte-Load: 1 = sign-ext (LB), 0 = zero-ext (LBU)

    // ---- ALU ----
    alu_op_e     alu_op;
    alu_src_e    alu_src;

    // ---- Ablauf / System ----
    logic        done;         // Befehl fertig -> Phase 0, naechster Fetch
    logic        halt;
    
    logic        irq_set;      // EI
    logic        irq_clr;      // DI / Interrupt-Eintritt
  } ctrl_s;

  // ==========================================================================
  //  Dekodierhilfen  —  reine Verdrahtung, null LUTs
  // ==========================================================================
  function automatic logic     f_is_alu (logic [7:0] op); return op[6];                 endfunction
  function automatic logic     f_is_jmp (logic [7:0] op); return (op[7:6] == GRP_JMP);  endfunction
  function automatic logic     f_is_misc(logic [7:0] op); return (op[7:6] == GRP_MISC); endfunction

  function automatic alu_op_e  f_alu_op (logic [7:0] op); return alu_op_e'({op[7], op[3:0]}); endfunction
  function automatic alu_src_e f_alu_src(logic [7:0] op); return alu_src_e'(op[5:4]);         endfunction
  function automatic cond_e    f_cond   (logic [7:0] op); return cond_e'(op[3:0]);            endfunction
  function automatic misc_op_e f_misc_op(logic [7:0] op); return misc_op_e'(op[5:0]);         endfunction

  function automatic logic f_alu_nwb(alu_op_e o);
    return (o == ALU_CMP) || (o == ALU_TST);
  endfunction

  // Bedingungsauswertung — hier sitzen die zusammengesetzten Vergleiche
  function automatic logic f_cond_true(cond_e c, logic z, logic cy, logic s, logic v);
    case (c)
      COND_AL: f_cond_true = 1'b1;
      COND_Z:  f_cond_true = z;
      COND_NZ: f_cond_true = ~z;
      COND_C:  f_cond_true = cy;
      COND_NC: f_cond_true = ~cy;
      COND_S:  f_cond_true = s;
      COND_NS: f_cond_true = ~s;
      COND_V:  f_cond_true = v;
      COND_NV: f_cond_true = ~v;
      COND_GE: f_cond_true = (s == v);
      COND_LT: f_cond_true = (s != v);
      COND_GT: f_cond_true = ~z & (s == v);
      COND_LE: f_cond_true =  z | (s != v);
      COND_HI: f_cond_true = ~cy & ~z;
      COND_LS: f_cond_true =  cy |  z;
      default: f_cond_true = 1'b0;
    endcase
  endfunction

  // ==========================================================================
  //  Kodierhilfen  —  fuer Testbench und ROM-Init
  // ==========================================================================
  function automatic logic [15:0] i_misc(misc_op_e o, logic [7:0] xy);
    return {GRP_MISC, o, xy};
  endfunction

  function automatic logic [15:0] i_alu(alu_op_e o, alu_src_e s, logic [7:0] xy);
    return {o[4], 1'b1, s, o[3:0], xy};
  endfunction

  function automatic logic [15:0] i_jmp(cond_e c, logic link, logic tgt_ptr, logic [7:0] xy);
    return {GRP_JMP, tgt_ptr, link, c, xy};
  endfunction

endpackage
