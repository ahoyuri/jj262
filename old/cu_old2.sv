import jj262_pkg::*;

// ============================================================================
//  cu_decode  —  kombinatorisch: (op, phase, flags) -> ctrl
//
//  phase ist 2 Bit: INT braucht 3 Takte, RETI 4. Der Sequencer (extern):
//      always_ff @(posedge clk)
//        if (rst | ctrl.done) phase <= 2'd0;
//        else                 phase <= phase + 2'd1;
//
//  Taktkosten (CPI):
//      1 Takt : Moves, Frame, Stores, PUSH*, JMP, EI/DI/HALT, ALU (PTR/IMM)
//      2 Takte: Loads, MV*, POP*, RET, CALL, ALU (Speicheroperand)
//      3 Takte: INT
//      4 Takte: RETI
// ============================================================================
module cu_decode (
    input  logic [7:0] op,       // opcode_e existiert nicht mehr - rohes Byte
    input  logic [1:0] phase,
    input  logic       f_z, f_c, f_s, f_v,   // Flagregister (fuer Sprungbedingung)
    output ctrl_s      ctrl
);
    // Sprungfelder (reine Verdrahtung)
    logic jmp_link, jmp_tgt_ptr, jmp_taken;
    assign jmp_tgt_ptr = op[5];
    assign jmp_link    = op[4];
    assign jmp_taken   = f_cond_true(f_cond(op), f_z, f_c, f_s, f_v);

    always_comb begin
        ctrl = '0;
        ctrl.done = 1'b1;   //Default: einzyklisch. nur bei Ausnahmen done = 0

        // ====================================================================
        //  MISC
        // ====================================================================
        if (f_is_misc(op)) begin
            //default
            ctrl.bus_dst    = DST_NONE;
            ctrl.bus_off    = OFF_ZDISP;
            ctrl.bus_addsub = OFF_S_ADD;
            ctrl.route      = ROUTE_DIRECT;
            unique case (f_misc_op(op))
                MOP_NOP:;               // nichts
                //Immediate -> register
                MOP_MILAK: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MIHAK: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MILPT: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MIHPT: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MILSP: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MIHSP: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_SP;
                end
                // Register -> Register  (Ziel = Quelle + zext(XY))
                MOP_MAPT: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_MPAK: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MASP: begin
                    ctrl.bus_src = BUS_AKK;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MPSP: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_MSAK: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_AKK;
                end
                MOP_MSPT: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_PTR;
                end
                // Frame
                MOP_ADDSP: begin
                    ctrl.bus_src = BUS_SP;
                    ctrl.bus_dst = DST_SP;
                end
                MOP_SUBSP: begin
                    ctrl.bus_src    = BUS_SP;
                    ctrl.bus_addsub = OFF_S_SUB;
                    ctrl.bus_dst    = DST_SP;
                end
                // PTR Arithmetik
                MOP_INCPT: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_dst = DST_PTR;
                end
                MOP_DECPT: begin                    // FIX: war BUS_SP/DST_SP
                    ctrl.bus_src    = BUS_PTR;
                    ctrl.bus_addsub = OFF_S_SUB;
                    ctrl.bus_dst    = DST_PTR;
                end
                // Wort loads   ziel = [basis + XY]     2 Takte
                MOP_LPAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LPPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                MOP_LAAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_AKK;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LAPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_AKK;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                MOP_LSAK: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_LSPT: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                // Wort stores  [basis + XY] = quelle   1 Takt
                //   Adressbus: wohin.  Datenbus: was.  Gleichzeitig.
                MOP_SAPT: begin
                    ctrl.abus_src = ABUS_PTR;
                    ctrl.abus_off = OFF_ZDISP;
                    ctrl.bus_src  = BUS_AKK;
                    ctrl.bus_off  = OFF_ZERO;
                    ctrl.bus_dst  = DST_WMEM;
                end
                MOP_SPPT: begin
                    ctrl.abus_src = ABUS_PTR;
                    ctrl.abus_off = OFF_ZDISP;
                    ctrl.bus_src  = BUS_PTR;
                    ctrl.bus_off  = OFF_ZERO;
                    ctrl.bus_dst  = DST_WMEM;
                end
                MOP_SASP: begin
                    ctrl.abus_src = ABUS_SP;
                    ctrl.abus_off = OFF_ZDISP;
                    ctrl.bus_src  = BUS_AKK;
                    ctrl.bus_off  = OFF_ZERO;
                    ctrl.bus_dst  = DST_WMEM;
                end
                MOP_SPSP: begin
                    ctrl.abus_src = ABUS_SP;
                    ctrl.abus_off = OFF_ZDISP;
                    ctrl.bus_src  = BUS_PTR;
                    ctrl.bus_off  = OFF_ZERO;
                    ctrl.bus_dst  = DST_WMEM;
                end
                // Byte-Zugriffe ueber PTR
                MOP_LBPAK: begin                    // AKK = sext(byte [PTR+XY])
                    if (phase == 0) begin
                        ctrl.abus_src  = ABUS_PTR;
                        ctrl.abus_off  = OFF_ZDISP;
                        ctrl.mem_re    = 1'b1;
                        ctrl.mem_byte  = 1'b1;
                        ctrl.done      = 1'b0;
                    end else begin
                        ctrl.bus_src   = BUS_RMEM;
                        ctrl.mem_byte  = 1'b1;
                        ctrl.mem_bsext = 1'b1;
                        ctrl.bus_dst   = DST_AKK;
                    end
                end
                MOP_LBUPAK: begin                   // AKK = zext(byte [PTR+XY])
                    if (phase == 0) begin
                        ctrl.abus_src  = ABUS_PTR;
                        ctrl.abus_off  = OFF_ZDISP;
                        ctrl.mem_re    = 1'b1;
                        ctrl.mem_byte  = 1'b1;
                        ctrl.done      = 1'b0;
                    end else begin
                        ctrl.bus_src   = BUS_RMEM;
                        ctrl.mem_byte  = 1'b1;
                        ctrl.mem_bsext = 1'b0;
                        ctrl.bus_dst   = DST_AKK;
                    end
                end
                MOP_SBPT: begin                     // byte [PTR+XY] = AKK[7:0]
                    ctrl.abus_src = ABUS_PTR;
                    ctrl.abus_off = OFF_ZDISP;
                    ctrl.bus_src  = BUS_AKK;
                    ctrl.bus_off  = OFF_ZERO;
                    ctrl.mem_byte = 1'b1;
                    ctrl.bus_dst  = DST_WMEM;
                end
                // Speicher -> Speicher              2 Takte
                MOP_MVAP: begin                     // [PTR+XY] = [AKK+XY]
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_AKK;   // Leseadresse
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.abus_src = ABUS_PTR;   // Schreibadresse
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.bus_src  = BUS_RMEM;   // q durchreichen
                        ctrl.bus_off  = OFF_ZERO;
                        ctrl.bus_dst  = DST_WMEM;
                    end
                end
                MOP_MVPA: begin                     // [AKK+XY] = [PTR+XY]
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.abus_src = ABUS_AKK;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.bus_src  = BUS_RMEM;
                        ctrl.bus_off  = OFF_ZERO;
                        ctrl.bus_dst  = DST_WMEM;
                    end
                end
                // Stack                             PUSH 1 Takt, POP 2 Takte
                //   PUSH: abus = SP-2 geht an Schreibport UND zurueck nach SP
                //   POP:  T0 Leseadresse SP + SP+=2 (Datenbus), T1 q -> Ziel
                MOP_PUSHA: begin
                    ctrl.abus_src    = ABUS_SP;
                    ctrl.abus_off    = OFF_TWO;
                    ctrl.abus_addsub = OFF_S_SUB;
                    ctrl.sp_abus_we  = 1'b1;        // SP = SP-2
                    ctrl.bus_src     = BUS_AKK;
                    ctrl.bus_off     = OFF_ZERO;
                    ctrl.bus_dst     = DST_WMEM;    // [SP-2] = AKK
                end
                MOP_PUSHP: begin
                    ctrl.abus_src    = ABUS_SP;
                    ctrl.abus_off    = OFF_TWO;
                    ctrl.abus_addsub = OFF_S_SUB;
                    ctrl.sp_abus_we  = 1'b1;
                    ctrl.bus_src     = BUS_PTR;
                    ctrl.bus_off     = OFF_ZERO;
                    ctrl.bus_dst     = DST_WMEM;
                end
                MOP_PUSHF: begin
                    ctrl.abus_src    = ABUS_SP;
                    ctrl.abus_off    = OFF_TWO;
                    ctrl.abus_addsub = OFF_S_SUB;
                    ctrl.sp_abus_we  = 1'b1;
                    ctrl.bus_src     = BUS_FLG;
                    ctrl.bus_off     = OFF_ZERO;
                    ctrl.bus_dst     = DST_WMEM;
                end
                MOP_POPA: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;    // lesen von [SP]
                        ctrl.abus_off = OFF_ZERO;
                        ctrl.mem_re   = 1'b1;
                        ctrl.bus_src  = BUS_SP;     // parallel: SP += 2
                        ctrl.bus_off  = OFF_TWO;
                        ctrl.bus_dst  = DST_SP;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_AKK;
                    end
                end
                MOP_POPP: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZERO;
                        ctrl.mem_re   = 1'b1;
                        ctrl.bus_src  = BUS_SP;
                        ctrl.bus_off  = OFF_TWO;
                        ctrl.bus_dst  = DST_SP;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PTR;
                    end
                end
                MOP_POPF: begin
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZERO;
                        ctrl.mem_re   = 1'b1;
                        ctrl.bus_src  = BUS_SP;
                        ctrl.bus_off  = OFF_TWO;
                        ctrl.bus_dst  = DST_SP;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_FLG;
                    end
                end
                // Ablaufsteuerung
                MOP_RET: begin                      // POP PC          2 Takte
                    if (phase == 0) begin
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZERO;
                        ctrl.mem_re   = 1'b1;
                        ctrl.bus_src  = BUS_SP;
                        ctrl.bus_off  = OFF_TWO;
                        ctrl.bus_dst  = DST_SP;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src = BUS_RMEM;
                        ctrl.bus_dst = DST_PC;
                    end
                end
                MOP_RETI: begin                     // POP FLG, POP PC  4 Takte
                    unique case (phase)
                        2'd0: begin                 // Leseadresse SP, SP+=2
                            ctrl.abus_src = ABUS_SP;
                            ctrl.abus_off = OFF_ZERO;
                            ctrl.mem_re   = 1'b1;
                            ctrl.bus_src  = BUS_SP;
                            ctrl.bus_off  = OFF_TWO;
                            ctrl.bus_dst  = DST_SP;
                            ctrl.done     = 1'b0;
                        end
                        2'd1: begin                 // q -> Flags
                            ctrl.bus_src = BUS_RMEM;
                            ctrl.bus_dst = DST_FLG;
                            ctrl.done    = 1'b0;
                        end
                        2'd2: begin                 // Leseadresse SP, SP+=2
                            ctrl.abus_src = ABUS_SP;
                            ctrl.abus_off = OFF_ZERO;
                            ctrl.mem_re   = 1'b1;
                            ctrl.bus_src  = BUS_SP;
                            ctrl.bus_off  = OFF_TWO;
                            ctrl.bus_dst  = DST_SP;
                            ctrl.done     = 1'b0;
                        end
                        default: begin              // q -> PC
                            // IE steckt in den Flags (Bit FLG_IE) und wurde
                            // bereits in Phase 1 per POPF wiederhergestellt.
                            // Kein explizites irq_set mehr noetig.
                            ctrl.bus_src = BUS_RMEM;
                            ctrl.bus_dst = DST_PC;
                        end
                    endcase
                end
                MOP_INT: begin                      // Software-Interrupt  3 Takte
                    unique case (phase)
                        2'd0: begin                 // push PC (Ruecksprungadresse)
                            ctrl.abus_src    = ABUS_SP;
                            ctrl.abus_off    = OFF_TWO;
                            ctrl.abus_addsub = OFF_S_SUB;
                            ctrl.sp_abus_we  = 1'b1;
                            ctrl.bus_src     = BUS_PC;
                            ctrl.bus_off     = OFF_ZERO;
                            ctrl.bus_dst     = DST_WMEM;
                            ctrl.done        = 1'b0;
                        end
                        2'd1: begin                 // push Flags, IRQ sperren
                            // BUS_FLG wird kombinatorisch VOR der Flanke gelesen,
                            // irq_clr wirkt erst ZUR Flanke -> es wird der
                            // Vor-Sperr-Zustand (IE=1) gepusht. RETI stellt ihn
                            // per POPF wieder her, siehe MOP_RETI.
                            ctrl.abus_src    = ABUS_SP;
                            ctrl.abus_off    = OFF_TWO;
                            ctrl.abus_addsub = OFF_S_SUB;
                            ctrl.sp_abus_we  = 1'b1;
                            ctrl.bus_src     = BUS_FLG;
                            ctrl.bus_off     = OFF_ZERO;
                            ctrl.bus_dst     = DST_WMEM;
                            ctrl.irq_clr     = 1'b1;
                            ctrl.done        = 1'b0;
                        end
                        default: begin              // PC = zext(XY)  (Vektor)
                            ctrl.bus_src = BUS_ZERO;
                            ctrl.bus_off = OFF_ZDISP;
                            ctrl.bus_dst = DST_PC;
                        end
                    endcase
                end
                MOP_EI:   ctrl.irq_set = 1'b1;
                MOP_DI:   ctrl.irq_clr = 1'b1;
                MOP_HALT: ctrl.halt    = 1'b1;

                MOP_JMPP: begin                 // Jump to Page: PC = {XY, 8'h00}
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_off = OFF_IMM_HIGH;
                    ctrl.bus_dst = DST_PC;
                end

                default:;                           // illegal: tut nichts, done=1
            endcase
        end

        // ====================================================================
        //  ALU    AKK = AKK <op> SRC
        //    SRC_PTR / SRC_IMM : 1 Takt
        //    SRC_MP  / SRC_MS  : 2 Takte (Speicheroperand)
        // ====================================================================
        else if (f_is_alu(op)) begin
            ctrl.route  = ROUTE_ALU;
            ctrl.alu_op = f_alu_op(op);

            unique case (f_alu_src(op))
                SRC_PTR: begin
                    ctrl.bus_src = BUS_PTR;
                    ctrl.bus_off = OFF_ZERO;        // XY wird ignoriert
                end
                SRC_IMM: begin
                    ctrl.bus_src = BUS_ZERO;
                    ctrl.bus_off = OFF_ZDISP;       // Operand = zext(XY)
                end
                SRC_MP: begin
                    if (phase == 0) begin
                        ctrl.route    = ROUTE_DIRECT;   // noch nicht rechnen
                        ctrl.abus_src = ABUS_PTR;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src  = BUS_RMEM;
                        ctrl.bus_off  = OFF_ZERO;
                    end
                end
                SRC_MS: begin
                    if (phase == 0) begin
                        ctrl.route    = ROUTE_DIRECT;
                        ctrl.abus_src = ABUS_SP;
                        ctrl.abus_off = OFF_ZDISP;
                        ctrl.mem_re   = 1'b1;
                        ctrl.done     = 1'b0;
                    end else begin
                        ctrl.bus_src  = BUS_RMEM;
                        ctrl.bus_off  = OFF_ZERO;
                    end
                end
            endcase

            // Writeback + Flags nur im Rechen-Takt (done==1)
            if (ctrl.done) begin
                ctrl.flags_we = 1'b1;
                ctrl.bus_dst  = f_alu_nwb(f_alu_op(op)) ? DST_NONE : DST_AKK;
            end
        end

        // ====================================================================
        //  JMP / CALL    {GRP_JMP, tgt_ptr, link, cond}
        //    Ziel: tgt_ptr ? PTR+sext(XY) : PC+sext(XY)
        //    JMP  taken: 1 Takt.   CALL taken: 2 Takte (push PC, dann Sprung).
        //    not taken: 1 Takt, nichts.
        // ====================================================================
        else if (f_is_jmp(op)) begin
            if (jmp_taken) begin
                if (jmp_link) begin                 // CALL
                    if (phase == 0) begin           // push Ruecksprungadresse
                        ctrl.abus_src    = ABUS_SP;
                        ctrl.abus_off    = OFF_TWO;
                        ctrl.abus_addsub = OFF_S_SUB;
                        ctrl.sp_abus_we  = 1'b1;
                        ctrl.bus_src     = BUS_PC;  // PC zeigt schon auf naechsten Befehl
                        ctrl.bus_off     = OFF_ZERO;
                        ctrl.bus_dst     = DST_WMEM;
                        ctrl.done        = 1'b0;
                    end else begin                  // PC = Ziel
                        ctrl.bus_src = jmp_tgt_ptr ? BUS_PTR : BUS_PC;
                        ctrl.bus_off = OFF_SDISP;
                        ctrl.bus_dst = DST_PC;
                    end
                end else begin                      // JMP
                    ctrl.bus_src = jmp_tgt_ptr ? BUS_PTR : BUS_PC;
                    ctrl.bus_off = OFF_SDISP;
                    ctrl.bus_dst = DST_PC;
                end
            end
            // not taken: ctrl bleibt '0 + done -> faellt durch
        end

        // ====================================================================
        //  Ziel-Enables aus bus_dst ableiten (eine Wahrheit)
        // ====================================================================
        ctrl.akk_we = (ctrl.bus_dst == DST_AKK);
        ctrl.ptr_we = (ctrl.bus_dst == DST_PTR);
        ctrl.sp_we  = (ctrl.bus_dst == DST_SP);
        ctrl.pc_we  = (ctrl.bus_dst == DST_PC);
        ctrl.mem_we = (ctrl.bus_dst == DST_WMEM);
        ctrl.flg_we = (ctrl.bus_dst == DST_FLG);
    end

endmodule
