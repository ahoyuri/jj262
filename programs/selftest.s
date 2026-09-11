; ===========================================================================
;  selftest.s  —  JJ262 Befehlstest
;
;  Bei Erfolg:   HEX zeigt 600D, CPU haelt an.
;  Bei Fehler:   HEX zeigt die Testnummer, CPU haelt an.
;
;  Muster pro Test:
;        <Operation ausfuehren, Ergebnis in AKK>
;        ldiptr <erwartet>
;        cmp                    ; AKK - PTR, setzt Z
;        jz     weiter
;        ldi    <nummer>
;        jmp    fail
; ===========================================================================

.equ IO_HEX,   0xF000
.equ STACKTOP, 0x0800

.bss 0x0100
var:    .space 2
var2:   .space 2
bytes:  .space 4

.vectors
        jmpp 1
        jmpp 1
        jmpp 1
        jmpp 1

.org 0x0100
main:   ldisp STACKTOP

; --- 01  ADDI ---------------------------------------------------------------
        ldi    5
        addi   3
        ldiptr 8
        cmp
        jz     t02
        ldi    0x01
        ldiptr fail
        jmp    ptr

; --- 02  SUBI ---------------------------------------------------------------
t02:    ldi    10
        subi   4
        ldiptr 6
        cmp
        jz     t03
        ldi    0x02
        ldiptr fail
        jmp    ptr

; --- 03  ADD mit PTR --------------------------------------------------------
t03:    ldi    0x1234
        ldiptr 0x1111
        add
        ldiptr 0x2345
        cmp
        jz     t04
        ldi    0x03
        ldiptr fail
        jmp    ptr

; --- 04  SUB mit PTR --------------------------------------------------------
t04:    ldi    0x5555
        ldiptr 0x1111
        sub
        ldiptr 0x4444
        cmp
        jz     t05
        ldi    0x04
        ldiptr fail
        jmp    ptr

; --- 05  ADD: Ueberlauf auf 0, Z-Flag ---------------------------------------
t05:    ldi    0xFFFF
        addi   1
        jz     t06                    ; Z muss gesetzt sein
        ldi    0x05
        ldiptr fail
        jmp    ptr

; --- 06  ADD: Carry ---------------------------------------------------------
t06:    ldi    0xFFFF
        addi   1
        jc     t07                    ; C muss gesetzt sein
        ldi    0x06
        ldiptr fail
        jmp    ptr

; --- 07  ADD: signed Overflow  0x7FFF+1 -------------------------------------
t07:    ldi    0x7FFF
        addi   1
        jv     t08                    ; V muss gesetzt sein
        ldi    0x07
        ldiptr fail
        jmp    ptr

; --- 08  SUB: Borrow  3-5 ---------------------------------------------------
t08:    ldi    3
        subi   5
        jc     t09                    ; C = Borrow
        ldi    0x08
        ldiptr fail
        jmp    ptr

; --- 09  SUB: kein Borrow  5-3 ----------------------------------------------
t09:    ldi    5
        subi   3
        jnc    t0A
        ldi    0x09
        ldiptr fail
        jmp    ptr

; --- 0A  ADC-Kette:  C von 0xFFFF+1 wird mitaddiert -------------------------
t0A:    ldi    0xFFFF
        addi   1                      ; C=1
        ldi    0                      ; AKK=0 (aendert C nicht? -> milak/mihak)
        adci   0                      ; 0 + 0 + C = 1
        ldiptr 1
        cmp
        jz     t0B
        ldi    0x0A
        ldiptr fail
        jmp    ptr

; --- 0B  AND ----------------------------------------------------------------
t0B:    ldi    0xF0F0
        andi   0xF0
        ldiptr 0x00F0
        cmp
        jz     t0C
        ldi    0x0B
        ldiptr fail
        jmp    ptr

; --- 0C  OR -----------------------------------------------------------------
t0C:    ldi    0xF000
        ori    0x0F
        ldiptr 0xF00F
        cmp
        jz     t0D
        ldi    0x0C
        ldiptr fail
        jmp    ptr

; --- 0D  XOR ----------------------------------------------------------------
t0D:    ldi    0xFFFF
        xori   0x0F
        ldiptr 0xFFF0
        cmp
        jz     t0E
        ldi    0x0D
        ldiptr fail
        jmp    ptr

; --- 0E  NOT  (unaer auf die Quelle) ----------------------------------------
t0E:    ldiptr 0x0F0F
        not
        ldiptr 0xF0F0
        cmp
        jz     t0F
        ldi    0x0E
        ldiptr fail
        jmp    ptr

; --- 0F  SHL ----------------------------------------------------------------
t0F:    ldi    1
        shli   4
        ldiptr 0x0010
        cmp
        jz     t10
        ldi    0x0F
        ldiptr fail
        jmp    ptr

; --- 10  SHR ----------------------------------------------------------------
t10:    ldi    0x8000
        shri   4
        ldiptr 0x0800
        cmp
        jz     t11
        ldi    0x10
        ldiptr fail
        jmp    ptr

; --- 11  ASR: Vorzeichen bleibt ---------------------------------------------
t11:    ldi    0x8000
        asri   1
        ldiptr 0xC000
        cmp
        jz     t12
        ldi    0x11
        ldiptr fail
        jmp    ptr

; --- 12  SHR: herausgeschobenes Bit -> C ------------------------------------
t12:    ldi    0x0001
        shri   1
        jc     t13
        ldi    0x12
        ldiptr fail
        jmp    ptr

; --- 13  NEG ----------------------------------------------------------------
t13:    ldi    5
        neg
        ldiptr 0xFFFB
        cmp
        jz     t14
        ldi    0x13
        ldiptr fail
        jmp    ptr

; --- 14  CMP setzt Z, veraendert AKK nicht ----------------------------------
t14:    ldi    0x1234
        cmpi   0x34                   ; ungleich -> Z=0
        jz     .bad
        ldiptr 0x1234
        cmp                            ; gleich -> Z=1
        jz     t15
.bad:   ldi    0x14
        ldiptr fail
        jmp    ptr

; --- 15  signed:  -1 < 1  ---------------------------------------------------
t15:    ldi    0xFFFF                 ; -1
        ldiptr 1
        cmp
        jlt    t16                    ; -1 < 1 signed
        ldi    0x15
        ldiptr fail
        jmp    ptr

; --- 16  unsigned: 0xFFFF > 1 -----------------------------------------------
t16:    ldi    0xFFFF
        ldiptr 1
        cmp
        jhi    t17                    ; unsigned groesser
        ldi    0x16
        ldiptr fail
        jmp    ptr

; --- 17  signed:  1 >= -1 ---------------------------------------------------
t17:    ldi    1
        ldiptr 0xFFFF
        cmp
        jge    t18
        ldi    0x17
        ldiptr fail
        jmp    ptr

; --- 18  Wort speichern und laden -------------------------------------------
t18:    ldi    0xBEEF
        ldiptr var
        sapt   0
        ldi    0
        ldiptr var
        lpak   0
        ldiptr 0xBEEF
        cmp
        jz     t19
        ldi    0x18
        ldiptr fail
        jmp    ptr

; --- 19  SP-relativ speichern/laden -----------------------------------------
t19:    subsp  4
        ldi    0xCAFE
        sasp   2
        ldi    0
        lsak   2
        ldiptr 0xCAFE
        cmp
        jz     .ok
        addsp  4
        ldi    0x19
        ldiptr fail
        jmp    ptr
.ok:    addsp  4

; --- 1A  Byte speichern, unsigned laden -------------------------------------
t1A:    ldiptr bytes
        ldi    0x0080
        sbpt   0                      ; Byte 0x80 an bytes+0
        ldi    0
        lbupak 0                       ; zero-extend
        ldiptr 0x0080
        cmp
        jz     t1B
        ldi    0x1A
        ldiptr fail
        jmp    ptr

; --- 1B  Byte signed laden --------------------------------------------------
t1B:    ldiptr bytes
        lbpak  0                       ; sign-extend -> 0xFF80
        ldiptr 0xFF80
        cmp
        jz     t1C
        ldi    0x1B
        ldiptr fail
        jmp    ptr

; --- 1C  zweites Byte, ungerade Adresse -------------------------------------
t1C:    ldiptr bytes
        ldi    0x0042
        sbpt   1                      ; an bytes+1
        ldi    0
        ldiptr bytes
        lbupak 1
        ldiptr 0x0042
        cmp
        jz     t1D
        ldi    0x1C
        ldiptr fail
        jmp    ptr

; --- 1D  INCPT / DECPT ------------------------------------------------------
t1D:    ldiptr 0x1000
        incpt  4
        mpak   0                       ; AKK = PTR
        ldiptr 0x1004
        cmp
        jz     .b
        ldi    0x1D
        ldiptr fail
        jmp    ptr
.b:     ldiptr 0x1000
        decpt  4
        mpak   0
        ldiptr 0x0FFC
        cmp
        jz     t1E
        ldi    0x1D
        ldiptr fail
        jmp    ptr

; --- 1E  PUSH / POP  AKK ----------------------------------------------------
t1E:    ldi    0x1357
        pusha
        ldi    0
        popa
        ldiptr 0x1357
        cmp
        jz     t1F
        ldi    0x1E
        ldiptr fail
        jmp    ptr

; --- 1F  PUSH / POP  PTR ----------------------------------------------------
t1F:    ldiptr 0x2468
        pushp
        ldiptr 0
        popp
        mpak   0
        ldiptr 0x2468
        cmp
        jz     t20
        ldi    0x1F
        ldiptr fail
        jmp    ptr

; --- 20  CALL / RET ---------------------------------------------------------
t20:    ldi    0x0010
        call   addfive
        ldiptr 0x0015
        cmp
        jz     t21
        ldi    0x20
        ldiptr fail
        jmp    ptr

; --- 21  MSAK: AKK = SP + XY  (LEA) -----------------------------------------
t21:    ldisp  STACKTOP
        msak   4
        ldiptr 0x0804
        cmp
        jz     t22
        ldi    0x21
        ldiptr fail
        jmp    ptr

; --- 22  Speicher -> Speicher (MVAP) ----------------------------------------
t22:    ldi    0x9ABC
        ldiptr var
        sapt   0                      ; var = 0x9ABC
        ldi    var                    ; AKK = Quelle
        ldiptr var2                   ; PTR = Ziel
        mvap   0                      ; [PTR] = [AKK]
        ldiptr var2
        lpak   0
        ldiptr 0x9ABC
        cmp
        jz     t23
        ldi    0x22
        ldiptr fail
        jmp    ptr

; --- 23  MUL ----------------------------------------------------------------
t23:    ldi    7
        ldiptr 6
        mul
        ldiptr 42
        cmp
        jz     t24
        ldi    0x23
        ldiptr fail
        jmp    ptr

; --- 24  ALU mit Speicheroperand  [PTR+XY] ----------------------------------
t24:    ldi    0x0100
        ldiptr var
        sapt   0                      ; var = 0x0100
        ldi    0x0011
        ldiptr var
        addp   0                      ; AKK += [var]
        ldiptr 0x0111
        cmp
        jz     t25
        ldi    0x24
        ldiptr fail
        jmp    ptr

; --- 25  ALU mit Speicheroperand  [SP+XY] -----------------------------------
t25:    subsp  4
        ldi    0x0022
        sasp   2
        ldi    0x0300
        adds   2                      ; AKK += [SP+2]
        ldiptr 0x0322
        cmp
        jz     .ok2
        addsp  4
        ldi    0x25
        ldiptr fail
        jmp    ptr
.ok2:   addsp  4

; ===========================================================================
;  alle Tests bestanden
; ===========================================================================
pass:   ldi    0x600D
        ldiptr IO_HEX
        sapt   0
        halt

; --- Fehlerausgang: Testnummer steht in AKK ---------------------------------
fail:   ldiptr IO_HEX
        sapt   0
        halt

; --- Hilfs-Unterprogramm ----------------------------------------------------
addfive:
        addi   5
        ret
