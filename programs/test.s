; ===========================================================================
;  test.s  —  JJ262 Board-Test
;  Zaehlt hoch und zeigt den Wert auf den HEX-Anzeigen.
; ===========================================================================

; --- Konstanten ------------------------------------------------------------
.equ  IO_HEX,   0xF000        ; W: 4 Hexziffern
.equ  IO_LEDR,  0xF002        ; W: 10 LEDs
.equ  IO_SW,    0xF010        ; R: Schalter
.equ  IO_KEY,   0xF012        ; R: Taster / W: IRQ-Ack
.equ  STACKTOP, 0x0800        ; RAM waechst nach unten

; --- Variablen im RAM ------------------------------------------------------
.bss  0x0100
counter:  .space 2
tmp:      .space 2

; --- Vektortabelle:  ein JMPP pro Vektor, Seitennummer als Ziel ------------
.vectors
        jmpp  1                 ; Vektor 0: Reset  -> Seite 0x01 = 0x0100
        jmpp  2                 ; Vektor 1: Alignment Fault
        jmpp  2                 ; Vektor 2: Taster
        jmpp  2                 ; Vektor 3

; --- Hauptprogramm ---------------------------------------------------------
.org  0x0100
main:   ldi    0xBEEF
        ldiptr IO_HEX
        sapt   0            ; muss sofort BEEF zeigen
        ldisp STACKTOP          ; SP initialisieren (Pseudo -> 2 Befehle)
        ldi   0                 ; AKK = 0
        ldiptr counter
        sapt  0                 ; counter = 0

loop:
        ldiptr counter
        lpak  0                 ; AKK = counter
        addi  1                 ; +1
        sapt  0                 ; zurueckschreiben

        ldiptr IO_HEX
        sapt  0                 ; auf die HEX-Anzeigen

        call  delay             ; kurz warten
        jmp   loop

; --- Unterprogramm: Warteschleife -----------------------------------------
;  Zerstoert AKK und PTR, nutzt den Stack fuer den Zaehler.
delay:
        subsp 2                 ; ein lokales Wort
        ldi   0xFFFF
        sasp  0                 ; local = 0xFFFF
.wait:
        lsak  0                 ; AKK = local
        subi  1
        sasp  0                 ; local = AKK
        jnz   .wait             ; bis 0
        addsp 2                 ; Frame abbauen
        ret

; --- Interrupt-Handler -----------------------------------------------------
.org  0x0200
irq:
        pusha                   ; Zustand sichern
        pushp
        ldiptr IO_KEY
        sapt  0                 ; IRQ quittieren (Schreiben = Ack)
        popp
        popa
        reti
