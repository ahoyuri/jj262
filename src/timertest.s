; Timer-Test: Timer erzeugt periodische IRQs, ISR zaehlt hoch,
; Hauptprogramm rechnet dauernd und prueft auf Korruption.
.equ IO_HEX,    0xF000
.equ TMR_RELOAD, 0xF020
.equ TMR_COUNT,  0xF022
.equ TMR_CTRL,   0xF024
.equ TMR_PRESC,  0xF026

.bss 0x0100
ticks:  .space 2

.vectors
        jmpp 1
        jmpp 1
        jmpp 1
        jmpp 3                  ; Vektor 3 = Timer
.org 0x0100
main:   ldisp  0x0800
        ldi    0
        ldiptr ticks
        sapt   0

        ldi    9                ; PRESCALE = 9  -> Tick alle 10 Takte
        ldiptr TMR_PRESC
        sapt   0
        ldi    19               ; RELOAD = 19   -> IRQ alle 200 Takte
        ldiptr TMR_RELOAD
        sapt   0
        ldi    3                ; CTRL: EN=1, IE=1
        ldiptr TMR_CTRL
        sapt   0
        ei

; Hauptschleife: rechnet und prueft, dazwischen Anzeige
loop:   ldi    0x0F0F
        ldiptr 0x0FF0
        and                     ; 0x0F00
        addi   0x10             ; 0x0F10
        ldiptr 0x0F10
        cmp
        jnz    corrupt
        ldiptr ticks
        lpak   0
        ldiptr IO_HEX
        sapt   0
        jmp    loop

corrupt:
        ldi    0xDEAD
        ldiptr IO_HEX
        sapt   0
        halt

; --- Timer-ISR --------------------------------------------------------------
.org 0x0300
tmr_isr:
        pusha
        pushp
        ldiptr ticks
        lpak   0
        addi   1
        sapt   0
        ldiptr TMR_COUNT
        sapt   0                ; Schreiben = IRQ quittieren
        popp
        popa
        reti
