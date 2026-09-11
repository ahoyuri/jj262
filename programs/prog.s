; ==========================================================
; von jc erzeugt — nicht von Hand aendern
; ==========================================================
.equ STACKTOP, 0x0800

.bss 0x0100
counter:  .space 2
arr:  .space 16

.vectors
        jmpp hi(__start)

.align 256
__start:
        ldisp STACKTOP
        ldi   0
        ldiptr counter
        sapt  0
        call  main
        halt
__unhandled:
        reti

add3:
        lsak  2
        pusha
        lsak  6
        mapt  0
        popa
        add
        pusha
        lsak  8
        mapt  0
        popa
        add
        jmp   .ret1
.ret1:
        ret

main:
        subsp 4
        milak 5
        ldiptr counter
        sapt  0
        ldiptr counter
        lpak  0
        addi 3
        ldiptr counter
        sapt  0
        milak 0
        sasp  0
.ftop3:
        lsak  0
        pusha
        milak 8
        mapt  0
        popa
        cmp
        jnc   .fend5
        lsak  0
        muli 2
        pusha
        ldi   arr
        pusha
        lsak  4
        muli  2
        mapt  0
        popa
        add
        mapt  0
        popa
        sapt  0
.fcont4:
        lsak  0
        addi 1
        sasp  0
        jmp   .ftop3
.fend5:
        milak 0
        sasp  2
        milak 0
        sasp  0
.ftop6:
        lsak  0
        pusha
        milak 8
        mapt  0
        popa
        cmp
        jnc   .fend8
        lsak  2
        pusha
        ldi   arr
        pusha
        lsak  4
        muli  2
        mapt  0
        popa
        add
        mapt  0
        lpak  0
        mapt  0
        popa
        add
        sasp  2
.fcont7:
        lsak  0
        pusha
        lsak  2
        addi 1
        sasp  2
        popa
        jmp   .ftop6
.fend8:
        lsak  2
        pusha
        milak 56
        mapt  0
        popa
        cmp
        jnz   .else9
        milak 3
        pusha
        milak 2
        pusha
        milak 1
        pusha
        call  add3
        addsp 6
        sasp  2
        jmp   .endif10
.else9:
        ldi   2989
        sasp  2
.endif10:
.wtop11:
        lsak  2
        pusha
        milak 0
        mapt  0
        popa
        cmp
        jls   .wend12
        lsak  2
        pusha
        lsak  4
        subi 1
        sasp  4
        popa
        jmp   .wtop11
.wend12:
        ldi 0x600D
        ldiptr 0xF000
        sapt 0
.ret2:
        addsp 4
        ret

; ==========================================================================
;  Laufzeitroutinen (vom Compiler eingefuegt)
; ==========================================================================
.bss
__rem:  .space 2

.text
; --------------------------------------------------------------------------
;  __divu   Aufruf:  push Divisor, push Dividend, call __divu, addsp 4
;           Ergebnis: AKK = Quotient,  __rem = Rest
;  Wiederherstellende Division, 16 Schritte, MSB zuerst.
;  Rahmen:  0=quot 2=rest 4=zaehler | 6=retaddr 8=dividend 10=divisor
; --------------------------------------------------------------------------
__divu: subsp 6
        milak 0
        sasp  0
        sasp  2
        milak 16
        sasp  4
.loop:  lsak  2                 ; rest <<= 1
        shli  1
        sasp  2
        lsak  8                 ; oberstes Bit des Dividenden herausschieben
        shli  1
        sasp  8
        jnc   .nobit
        lsak  2                 ; ... und unten in den Rest
        ori   1
        sasp  2
.nobit: lsak  0                 ; quot <<= 1
        shli  1
        sasp  0
        lspt  10                ; PTR = Divisor
        lsak  2                 ; AKK = Rest
        cmp                     ; Rest < Divisor ?  (C = Borrow)
        jc    .next
        lsak  2                 ; Rest -= Divisor
        lspt  10
        sub
        sasp  2
        lsak  0                 ; quot |= 1
        ori   1
        sasp  0
.next:  lsak  4
        subi  1
        sasp  4
        jnz   .loop
        lsak  2                 ; Rest ablegen
        ldiptr __rem
        sapt  0
        lsak  0                 ; Quotient zurueckgeben
        addsp 6
        ret

; --------------------------------------------------------------------------
;  __divs   vorzeichenbehaftet: Vorzeichen abspalten, __divu, Vorzeichen setzen
;  Rahmen:  0=vorzeichen | 2=retaddr 4=dividend 6=divisor
; --------------------------------------------------------------------------
__divs: subsp 2
        milak 0
        sasp  0
        lsak  4                 ; Dividend negativ?
        addi  0
        jns   .s1
        neg
        sasp  4
        lsak  0
        xori  1
        sasp  0
.s1:    lsak  6                 ; Divisor negativ?
        addi  0
        jns   .s2
        neg
        sasp  6
        lsak  0
        xori  1
        sasp  0
.s2:    lsak  6                 ; Divisor pushen
        pusha
        lsak  6                 ; Dividend (Offset um 2 verschoben)
        pusha
        call  __divu
        addsp 4
        mapt  0                 ; Quotient in PTR retten
        lsak  0                 ; Vorzeichenmerker
        addi  0
        jz    .pos
        mpak  0
        neg
        addsp 2
        ret
.pos:   mpak  0
        addsp 2
        ret

