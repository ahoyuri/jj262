; ===========================================================================
;  boot.s  —  JJ262 Bootloader
;
;  Liegt vollstaendig im geschuetzten ROM-Bereich (< PROTECT = 0x0300) und
;  kann sich daher nicht selbst ueberschreiben.
;
;  Ablauf
;    1. Empfaenger einschalten, auf Magic "JJ26" warten
;    2. Laenge lesen (Anzahl Woerter)
;    3. Woerter lesen und ueber die Tape-Peripherie ins ROM ab 0x0300 schreiben
;    4. Pruefsumme und Endmagic "END!" vergleichen
;    5. Nach 0x0300 springen
;
;  Statusanzeige auf den HEX-Anzeigen:
;    8000  wartet auf Traeger
;    8001  Magic erkannt, laedt
;    xxxx  waehrend des Ladens: Anzahl noch fehlender Woerter
;    E001  Rahmenfehler       E002  Ueberlauf
;    E003  Magic falsch       E004  Pruefsumme falsch    E005  Endmagic falsch
;
;  Warum Polling und kein Interrupt:  beim Booten gibt es nichts anderes zu
;  tun, und ein Byte kommt nur alle ~3 ms.  Polling ist deterministisch und
;  braucht keine funktionierende Interruptkette — genau richtig fuer Code,
;  der laufen muss, bevor irgendetwas anderes geprueft ist.  Die IRQ-Leitung
;  der Peripherie bleibt fuer spaeteres Streaming im laufenden Betrieb frei.
; ===========================================================================

.equ IO_HEX,      0xF000
.equ TP_DATA,     0xF060
.equ TP_STATUS,   0xF062
.equ TP_CTRL,     0xF064
.equ TP_THRESH,   0xF066
.equ TP_ROMADDR,  0xF068
.equ TP_ROMDATA,  0xF06A

.equ LOAD_START,  0x0300        ; erste Wortadresse des geladenen Programms
.equ STACKTOP,    0x0800

; --- Zustand im RAM --------------------------------------------------------
.bss 0x0100
count:    .space 2              ; noch fehlende Woerter
sum:      .space 2              ; laufende Pruefsumme
word:     .space 2              ; gerade zusammengesetztes Wort

; --- Vektortabelle ---------------------------------------------------------
.vectors
        jmpp  1                 ; 0  Reset
        jmpp  1                 ; 1  Alignment Fault
        jmpp  1                 ; 2  Taster
        jmpp  1                 ; 3  Timer
        jmpp  1                 ; 4  Display
        jmpp  1                 ; 5  Tape

; ===========================================================================
.org 0x0100
boot:   ldisp  STACKTOP

        ldi    0x8000           ; "wartet"
        call   show

        ldi    1                ; Empfaenger an
        ldiptr TP_CTRL
        sapt   0

; --- auf Magic "JJ26" warten -----------------------------------------------
;  Bei jedem Fehltreffer von vorn anfangen: so rastet der Loader auch mitten
;  im Band ein, sobald das naechste Magic vorbeikommt.
.wmagic:
        call   getbyte
        ldiptr 0x004A           ; 'J'
        cmp
        jnz    .wmagic
        call   getbyte
        ldiptr 0x004A           ; 'J'
        cmp
        jnz    .wmagic
        call   getbyte
        ldiptr 0x0032           ; '2'
        cmp
        jnz    .wmagic
        call   getbyte
        ldiptr 0x0036           ; '6'
        cmp
        jnz    .wmagic

        ldi    0x8001           ; "laedt"
        call   show

; --- Laenge lesen ----------------------------------------------------------
        call   getword
        ldiptr count
        sapt   0

        ldi    0                ; Pruefsumme zuruecksetzen
        ldiptr sum
        sapt   0

        ldi    LOAD_START       ; Zieladresse im ROM
        ldiptr TP_ROMADDR
        sapt   0

; --- Woerter uebertragen ---------------------------------------------------
.loop:  ldiptr count
        lpak   0
        addi   0                ; Z setzen
        jz     .done
        call   show             ; Fortschritt anzeigen

        call   getword          ; AKK = Wort
        ldiptr word
        sapt   0

        ldiptr TP_ROMDATA       ; ins ROM, Adresse zaehlt selbst weiter
        sapt   0

        ldiptr sum              ; Pruefsumme aufaddieren
        lpak   0
        pusha
        ldiptr word
        lpak   0
        mapt   0
        popa
        add
        ldiptr sum
        sapt   0

        ldiptr count            ; count--
        lpak   0
        subi   1
        ldiptr count
        sapt   0
        jmp    .loop

; --- Pruefsumme vergleichen ------------------------------------------------
.done:  call   getword          ; erwartete Summe
        pusha
        ldiptr sum
        lpak   0
        mapt   0
        popa
        cmp
        jnz    .esum

; --- Endmagic "END!" -------------------------------------------------------
        call   getbyte
        ldiptr 0x0045           ; 'E'
        cmp
        jnz    .emagic
        call   getbyte
        ldiptr 0x004E           ; 'N'
        cmp
        jnz    .emagic
        call   getbyte
        ldiptr 0x0044           ; 'D'
        cmp
        jnz    .emagic
        call   getbyte
        ldiptr 0x0021           ; '!'
        cmp
        jnz    .emagic

; --- fertig: Empfaenger aus, Programm starten ------------------------------
        ldi    0
        ldiptr TP_CTRL
        sapt   0
        ldi    0x0000
        call   show
        ldiptr LOAD_START
        jmp    ptr

; --- Fehlerausgaenge -------------------------------------------------------
.esum:  ldi    0xE004
        call   show
        halt
.emagic:
        ldi    0xE005
        call   show
        halt

; ===========================================================================
;  getbyte  —  wartet auf ein Byte, Ergebnis in AKK.  Zerstoert PTR.
;              Bricht bei Rahmenfehler oder Ueberlauf ab.
; ===========================================================================
getbyte:
.gpoll: ldiptr TP_STATUS
        lpak   0
        pusha
        andi   0x06             ; Fehlerbits
        jnz    .gerr
        popa
        andi   0x01             ; Byte da?
        jz     .gpoll
        ldiptr TP_DATA
        lpak   0                ; Lesen quittiert
        ret
.gerr:  popa
        andi   0x02
        jnz    .gframe
        ldi    0xE002
        call   show
        halt
.gframe:
        ldi    0xE001
        call   show
        halt

; ===========================================================================
;  getword  —  zwei Bytes, little endian, Ergebnis in AKK.
; ===========================================================================
getword:
        call   getbyte          ; low
        pusha
        call   getbyte          ; high
        shli   8
        mapt   0                ; PTR = high << 8
        popa                    ; AKK = low
        add
        ret

; ===========================================================================
;  show  —  AKK auf die HEX-Anzeigen.  AKK bleibt erhalten, PTR nicht.
; ===========================================================================
show:   pusha
        ldiptr IO_HEX
        sapt   0
        popa
        ret
