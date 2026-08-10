; ===========================================================================
;  irqtest.s  —  JJ262 Interrupt-Test
;
;  Teil 1 (automatisch):  Software-INT selbstpruefend.
;                         Fehler -> HEX zeigt E0..E5, CPU haelt an.
;  Teil 2 (interaktiv):   Endlosschleife, zeigt einen Zaehler an.
;                         KEY[1..3] loesen den Hardware-IRQ aus -> Zaehler +1.
;
;  Vektoren:  0 Reset | 1 Alignment | 2 Taster (VEC aus periph_key) | 3 Print
; ===========================================================================

.equ IO_HEX,   0xF000
.equ IO_KEY,   0xF012
.equ STACKTOP, 0x0800

.bss 0x0100
counter:  .space 2
saved_sp: .space 2
flagmark: .space 2

.vectors
        jmpp 1                  ; 0: Reset          -> 0x0100
        jmpp 2                  ; 1: Alignment      -> 0x0200
        jmpp 3                  ; 2: Taster (HW)    -> 0x0300
        jmpp 4                  ; 3: Print (SW)     -> 0x0400

; ===========================================================================
;  Teil 1 — selbstpruefend
; ===========================================================================
.org 0x0100
main:   ldisp  STACKTOP
        ldi    0
        ldiptr counter
        sapt   0

; --- E0: SP ist nach einem INT/RETI unveraendert ---------------------------
        msak   0                ; AKK = SP
        ldiptr saved_sp
        sapt   0                ; SP merken
        ldi    0x1111
        int    3                ; Print-ISR: zeigt 1111, kehrt zurueck
        msak   0                ; AKK = SP danach
        ldiptr saved_sp
        lpak   0
        ldiptr saved_sp
        lppt   0                ; PTR = gemerkter SP
        cmp                     ; AKK(alt) == PTR? (beide aus dem Speicher)
        jz     .e0ok
        ldi    0xE0
        ldiptr fail
        jmp    ptr
.e0ok:

; --- E1: AKK ueberlebt den INT (ISR sichert nichts, nutzt AKK nur) ---------
        ldi    0x2222
        int    3
        ldiptr 0x2222
        cmp
        jz     .e1ok
        ldi    0xE1
        ldiptr fail
        jmp    ptr
.e1ok:

; --- E2: PTR ueberlebt den INT (ISR macht pushp/popp) ----------------------
        ldiptr 0x3333
        ldi    0x0044
        int    3
        mpak   0                ; AKK = PTR
        ldiptr 0x3333
        cmp
        jz     .e2ok
        ldi    0xE2
        ldiptr fail
        jmp    ptr
.e2ok:

; --- E3: INT innerhalb eines CALL — Stack bleibt konsistent ---------------
        ldi    0x0055
        call   sub_with_int     ; ruft intern int 3 auf
        ldiptr 0x005A           ; sub addiert 5
        cmp
        jz     .e3ok
        ldi    0xE3
        ldiptr fail
        jmp    ptr
.e3ok:

; --- E4: Flags ueberleben den INT ------------------------------------------
        ldi    5
        subi   5                ; Z = 1
        int    3                ; RETI muss Z restaurieren
        jz     .e4ok
        ldi    0xE4
        ldiptr fail
        jmp    ptr
.e4ok:

; --- E5: verschachtelt — CALL, darin CALL, darin INT ----------------------
        ldi    0x0060
        call   outer
        ldiptr 0x0063           ; outer +1, inner +2
        cmp
        jz     .e5ok
        ldi    0xE5
        ldiptr fail
        jmp    ptr
.e5ok:

; ===========================================================================
;  Teil 2 — interaktiv:  Taster erhoeht den Zaehler, Anzeige per INT 3
; ===========================================================================
        ldi    0x0000
        ldiptr counter
        sapt   0
        ei                      ; Hardware-IRQ freigeben

loop:   call   show
        jmp    loop

; zeigt counter an — der Print laeuft ueber den Software-Interrupt
show:   ldiptr counter
        lpak   0
        int    3
        ret

; Hilfs-Unterprogramme fuer die Tests
sub_with_int:
        addi   5
        int    3
        ret

outer:  addi   1
        call   inner
        ret
inner:  addi   2
        int    3
        ret

fail:   ldiptr IO_HEX
        sapt   0
        halt

; ===========================================================================
;  ISRs
; ===========================================================================

; --- Vektor 1: Alignment Fault ---------------------------------------------
.org 0x0200
align_isr:
        ldi    0x0AAA
        ldiptr IO_HEX
        sapt   0
        halt

; --- Vektor 2: Taster (Hardware) -------------------------------------------
;  Erhoeht counter und quittiert die Quelle.  Muss ALLES sichern.
.org 0x0300
key_isr:
        pusha
        pushp
        ldiptr counter
        lpak   0
        addi   1
        sapt   0
        ldiptr IO_KEY
        sapt   0                ; Schreiben = IRQ quittieren
        popp
        popa
        reti

; --- Vektor 3: Print (Software) --------------------------------------------
;  Zeigt AKK auf den HEX-Anzeigen.  AKK ist der Parameter, bleibt erhalten.
.org 0x0400
print_isr:
        pushp
        ldiptr IO_HEX
        sapt   0
        popp
        reti
