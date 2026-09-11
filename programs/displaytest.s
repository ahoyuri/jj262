.equ D_X,     0xF040
.equ D_Y,     0xF042
.equ D_COLOR, 0xF044
.equ D_CTRL,  0xF046
.vectors
        jmpp 1
        jmpp 1
        jmpp 1
        jmpp 1
.org 0x0100
main:   ldisp  0x0800
        ldi    2                ; CTRL: Bildschirm loeschen
        ldiptr D_CTRL
        sapt   0
.wclr:  ldiptr D_CTRL           ; warten bis Loeschen fertig (bit15)
        lpak   0
        addi   0                ; setzt S = bit15
        js     .wclr
        ldi    5                ; CTRL: an + autoinc
        ldiptr D_CTRL
        sapt   0
        ; Pixel (3,1) rot
        ldi    3
        ldiptr D_X
        sapt   0
        ldi    1
        ldiptr D_Y
        sapt   0
        ldi    1                ; R
        ldiptr D_COLOR
        sapt   0
        ldi    6                ; naechster Pixel (4,1): G+B  (autoinc)
        sapt   0
        ; Pixel (0,40) weiss -> untere Haelfte
        ldi    0
        ldiptr D_X
        sapt   0
        ldi    40
        ldiptr D_Y
        sapt   0
        ldi    7
        ldiptr D_COLOR
        sapt   0
        halt
