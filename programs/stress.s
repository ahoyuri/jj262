; IRQ-Stresstest: rechnet dauernd und prueft nach jeder Runde,
; ob AKK/PTR/SP durch Interrupts beschaedigt wurden.
.equ IO_HEX, 0xF000
.equ IO_KEY, 0xF012
.bss 0x0100
irqs:  .space 2
.vectors
        jmpp 1
        jmpp 1
        jmpp 3
        jmpp 1
.org 0x0100
main:   ldisp 0x0800
        ldi   0
        ldiptr irqs
        sapt  0
        ei
loop:   ldi    0x1234
        ldiptr 0x1111
        add                     ; 0x2345
        call   work
        subi   0x11             ; 0x2345+5-0x11 = 0x2339
        ldiptr 0x2339
        cmp
        jz     loop             ; alles gut -> weiter
        ldi    0xDEAD           ; Korruption erkannt
        ldiptr IO_HEX
        sapt   0
        halt
work:   pushp
        addi   5
        popp
        ret
.org 0x0300
isr:    pusha
        pushp
        ldiptr irqs
        lpak   0
        addi   1
        sapt   0
        ldiptr IO_KEY
        sapt   0
        popp
        popa
        reti
