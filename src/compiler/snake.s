; ==========================================================
; von jc erzeugt — nicht von Hand aendern
; ==========================================================
.equ STACKTOP, 0x0800

.bss 0x0100
bx:  .space 128
by:  .space 128
apx:  .space 16
apy:  .space 16
head:  .space 2
tail:  .space 2
len:  .space 2
hx:  .space 2
hy:  .space 2
dx:  .space 2
dy:  .space 2
ai:  .space 2
ax:  .space 2
ay:  .space 2

.vectors
        jmpp hi(__start)

.align 256
__start:
        ldisp STACKTOP
        ldi   0
        ldiptr head
        sapt  0
        ldi   0
        ldiptr tail
        sapt  0
        ldi   0
        ldiptr len
        sapt  0
        ldi   0
        ldiptr hx
        sapt  0
        ldi   0
        ldiptr hy
        sapt  0
        ldi   0
        ldiptr dx
        sapt  0
        ldi   0
        ldiptr dy
        sapt  0
        ldi   0
        ldiptr ai
        sapt  0
        ldi   0
        ldiptr ax
        sapt  0
        ldi   0
        ldiptr ay
        sapt  0
        call  main
        halt
__unhandled:
        reti

setpix:
        lsak  2
        pusha
        ldi   61504
        mapt  0
        popa
        sapt  0
        lsak  4
        pusha
        ldi   61506
        mapt  0
        popa
        sapt  0
        lsak  6
        pusha
        ldi   61508
        mapt  0
        popa
        sapt  0
.ret1:
        ret

readkeys:
        ldi   61458
        mapt  0
        lpak  0
        jmp   .ret2
.ret2:
        ret

showlen:
        lsak  2
        pusha
        ldi   61440
        mapt  0
        popa
        sapt  0
.ret3:
        ret

delay:
        subsp 4
        milak 0
        sasp  0
.ftop5:
        lsak  0
        pusha
        lsak  8
        mapt  0
        popa
        cmp
        jnc   .fend7
        milak 0
        sasp  2
.wtop8:
        lsak  2
        pusha
        ldi   500
        mapt  0
        popa
        cmp
        jnc   .wend9
        lsak  2
        pusha
        lsak  4
        addi 1
        sasp  4
        popa
        jmp   .wtop8
.wend9:
.fcont6:
        lsak  0
        pusha
        lsak  2
        addi 1
        sasp  2
        popa
        jmp   .ftop5
.fend7:
.ret4:
        addsp 4
        ret

clear_screen:
        subsp 2
        milak 2
        pusha
        ldi   61510
        mapt  0
        popa
        sapt  0
        ldi   61510
        mapt  0
        lpak  0
        sasp  0
.wtop11:
        lsak  0
        pusha
        ldi   32768
        mapt  0
        popa
        and
        addi  0
        jz    .wend12
        ldi   61510
        mapt  0
        lpak  0
        sasp  0
        jmp   .wtop11
.wend12:
        milak 1
        pusha
        ldi   61510
        mapt  0
        popa
        sapt  0
.ret10:
        addsp 2
        ret

init_apples:
        milak 10
        pusha
        ldi   apx
        pusha
        milak 0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 10
        pusha
        ldi   apy
        pusha
        milak 0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 50
        pusha
        ldi   apx
        pusha
        milak 1
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 12
        pusha
        ldi   apy
        pusha
        milak 1
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 20
        pusha
        ldi   apx
        pusha
        milak 2
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 40
        pusha
        ldi   apy
        pusha
        milak 2
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 45
        pusha
        ldi   apx
        pusha
        milak 3
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 45
        pusha
        ldi   apy
        pusha
        milak 3
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 8
        pusha
        ldi   apx
        pusha
        milak 4
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 55
        pusha
        ldi   apy
        pusha
        milak 4
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 60
        pusha
        ldi   apx
        pusha
        milak 5
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 30
        pusha
        ldi   apy
        pusha
        milak 5
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 30
        pusha
        ldi   apx
        pusha
        milak 6
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 5
        pusha
        ldi   apy
        pusha
        milak 6
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 15
        pusha
        ldi   apx
        pusha
        milak 7
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 25
        pusha
        ldi   apy
        pusha
        milak 7
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 55
        pusha
        ldi   apx
        pusha
        milak 8
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 58
        pusha
        ldi   apy
        pusha
        milak 8
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 40
        pusha
        ldi   apx
        pusha
        milak 9
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 20
        pusha
        ldi   apy
        pusha
        milak 9
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 5
        pusha
        ldi   apx
        pusha
        milak 10
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 40
        pusha
        ldi   apy
        pusha
        milak 10
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 35
        pusha
        ldi   apx
        pusha
        milak 11
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 50
        pusha
        ldi   apy
        pusha
        milak 11
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 58
        pusha
        ldi   apx
        pusha
        milak 12
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 8
        pusha
        ldi   apy
        pusha
        milak 12
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 25
        pusha
        ldi   apx
        pusha
        milak 13
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 60
        pusha
        ldi   apy
        pusha
        milak 13
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 48
        pusha
        ldi   apx
        pusha
        milak 14
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 35
        pusha
        ldi   apy
        pusha
        milak 14
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 12
        pusha
        ldi   apx
        pusha
        milak 15
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 45
        pusha
        ldi   apy
        pusha
        milak 15
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
.ret13:
        ret

spawn_apple:
        ldi   apx
        pusha
        ldiptr ai
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        lbupak 0
        ldiptr ax
        sapt  0
        ldi   apy
        pusha
        ldiptr ai
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        lbupak 0
        ldiptr ay
        sapt  0
        milak 2
        pusha
        ldiptr ay
        lpak  0
        pusha
        ldiptr ax
        lpak  0
        pusha
        call  setpix
        addsp 6
.ret14:
        ret

read_dir:
        subsp 2
        call  readkeys
        sasp  0
        lsak  0
        andi 1
        addi  0
        jz    .else16
        ldiptr dy
        lpak  0
        pusha
        milak 1
        mapt  0
        popa
        cmp
        jz    .else16
        milak 0
        ldiptr dx
        sapt  0
        milak 1
        neg
        ldiptr dy
        sapt  0
.else16:
        lsak  0
        andi 2
        addi  0
        jz    .else18
        ldiptr dy
        lpak  0
        pusha
        milak 1
        neg
        mapt  0
        popa
        cmp
        jz    .else18
        milak 0
        ldiptr dx
        sapt  0
        milak 1
        ldiptr dy
        sapt  0
.else18:
        lsak  0
        andi 4
        addi  0
        jz    .else20
        ldiptr dx
        lpak  0
        pusha
        milak 1
        mapt  0
        popa
        cmp
        jz    .else20
        milak 1
        neg
        ldiptr dx
        sapt  0
        milak 0
        ldiptr dy
        sapt  0
.else20:
        lsak  0
        andi 8
        addi  0
        jz    .else22
        ldiptr dx
        lpak  0
        pusha
        milak 1
        neg
        mapt  0
        popa
        cmp
        jz    .else22
        milak 1
        ldiptr dx
        sapt  0
        milak 0
        ldiptr dy
        sapt  0
.else22:
.ret15:
        addsp 2
        ret

main:
        subsp 4
        call  clear_screen
        call  init_apples
        milak 30
        pusha
        ldi   bx
        pusha
        milak 0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 32
        pusha
        ldi   by
        pusha
        milak 0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 31
        pusha
        ldi   bx
        pusha
        milak 1
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 32
        pusha
        ldi   by
        pusha
        milak 1
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 32
        pusha
        ldi   bx
        pusha
        milak 2
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 32
        pusha
        ldi   by
        pusha
        milak 2
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        milak 0
        ldiptr tail
        sapt  0
        milak 2
        ldiptr head
        sapt  0
        milak 3
        ldiptr len
        sapt  0
        milak 32
        ldiptr hx
        sapt  0
        milak 32
        ldiptr hy
        sapt  0
        milak 1
        ldiptr dx
        sapt  0
        milak 0
        ldiptr dy
        sapt  0
        milak 7
        pusha
        milak 32
        pusha
        milak 30
        pusha
        call  setpix
        addsp 6
        milak 7
        pusha
        milak 32
        pusha
        milak 31
        pusha
        call  setpix
        addsp 6
        milak 7
        pusha
        milak 32
        pusha
        milak 32
        pusha
        call  setpix
        addsp 6
        ldiptr len
        lpak  0
        pusha
        call  showlen
        addsp 2
        milak 0
        ldiptr ai
        sapt  0
        call  spawn_apple
.wtop25:
        milak 1
        addi  0
        jz    .wend26
        call  read_dir
        ldiptr hx
        lpak  0
        pusha
        ldiptr dx
        lpak  0
        mapt  0
        popa
        add
        sasp  0
        ldiptr hy
        lpak  0
        pusha
        ldiptr dy
        lpak  0
        mapt  0
        popa
        add
        sasp  2
        lsak  0
        pusha
        milak 0
        mapt  0
        popa
        cmp
        jlt   .or29
        lsak  0
        pusha
        milak 63
        mapt  0
        popa
        cmp
        jgt   .or29
        lsak  2
        pusha
        milak 0
        mapt  0
        popa
        cmp
        jlt   .or29
        lsak  2
        pusha
        milak 63
        mapt  0
        popa
        cmp
        jle   .else27
.or29:
        ldiptr len
        lpak  0
        pusha
        call  showlen
        addsp 2
.wtop30:
        milak 1
        addi  0
        jz    .wend31
        ldiptr len
        lpak  0
        pusha
        call  showlen
        addsp 2
        jmp   .wtop30
.wend31:
.else27:
        ldiptr head
        lpak  0
        addi 1
        ldiptr head
        sapt  0
        ldiptr head
        lpak  0
        pusha
        milak 128
        mapt  0
        popa
        cmp
        jnz   .else32
        milak 0
        ldiptr head
        sapt  0
.else32:
        lsak  0
        pusha
        ldi   bx
        pusha
        ldiptr head
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        lsak  2
        pusha
        ldi   by
        pusha
        ldiptr head
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        popa
        sbpt  0
        lsak  0
        ldiptr hx
        sapt  0
        lsak  2
        ldiptr hy
        sapt  0
        milak 7
        pusha
        lsak  4
        pusha
        lsak  4
        pusha
        call  setpix
        addsp 6
        lsak  0
        pusha
        ldiptr ax
        lpak  0
        mapt  0
        popa
        cmp
        jnz   .else34
        lsak  2
        pusha
        ldiptr ay
        lpak  0
        mapt  0
        popa
        cmp
        jnz   .else34
        ldiptr len
        lpak  0
        pusha
        milak 128
        subi 1
        mapt  0
        popa
        cmp
        jnc   .else36
        ldiptr len
        lpak  0
        addi 1
        ldiptr len
        sapt  0
.else36:
        ldiptr len
        lpak  0
        pusha
        call  showlen
        addsp 2
        ldiptr ai
        lpak  0
        addi 1
        ldiptr ai
        sapt  0
        ldiptr ai
        lpak  0
        pusha
        milak 16
        mapt  0
        popa
        cmp
        jnz   .else38
        milak 0
        ldiptr ai
        sapt  0
.else38:
        call  spawn_apple
        jmp   .endif35
.else34:
        milak 0
        pusha
        ldi   by
        pusha
        ldiptr tail
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        lbupak 0
        pusha
        ldi   bx
        pusha
        ldiptr tail
        lpak  0
        mapt  0
        popa
        add
        mapt  0
        lbupak 0
        pusha
        call  setpix
        addsp 6
        ldiptr tail
        lpak  0
        addi 1
        ldiptr tail
        sapt  0
        ldiptr tail
        lpak  0
        pusha
        milak 128
        mapt  0
        popa
        cmp
        jnz   .else40
        milak 0
        ldiptr tail
        sapt  0
.else40:
.endif35:
        milak 150
        pusha
        call  delay
        addsp 2
        jmp   .wtop25
.wend26:
.ret24:
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

