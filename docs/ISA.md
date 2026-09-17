# JJ262 — Instruction Set Architecture

<!--
  Regel fuer dieses Dokument: die Hardware ist die Wahrheit, nicht dieses
  Dokument. Wenn beim Schreiben eine Abweichung auffaellt -> unter
  "Offene Punkte" notieren, nicht stillschweigend die schoenere Variante
  aufschreiben.
-->

Status: Entwurf
Gilt für: Commit `TODO`
Autor: Julius Jackisch

---

## 1. Überblick

<!-- Quelle: src/jj262_pkg.sv:1-22, src/jj262_top.sv -->
Der JJ262 ist eine 16-Bit-Harvard CPU mit Akkumulator-Architektur.
Ein Wort ist 16 Bit und jeder Befehl ist ein Wort lang.
Als Arbeitsregister gibt es nur AKK und PTR, dazu kommen SP, PC und das Flagregister.
Die meisten Befehle werden in einem Takt ausgeführt.
Auf dem DE1-Board läuft die CPU derzeit mit 25MHz.


## 2. Programmiermodell

<!-- Quelle: src/path/register.sv, src/jj262_pkg.sv -->
Es gibt vier Register, alle 16 Bit breit. Nach einem Reset sind alle
Register und das Flagregister 0 (Interrupts sind damit gesperrt).

**AKK** — Akkumulator. Erster Operand und Ziel aller ALU-Operationen.

**PTR** — Zeigerregister. Basis für
PTR-relative Sprünge und das einzige Register mit Byte-Zugriffen
(LBPAK, LBUPAK, SBPT) und eigener Arithmetik (INCPT, DECPT).
Achtung: Der Assembler überschreibt PTR, wenn er einen zu weiten Sprung umbaut.

**SP** — Stackpointer. Basis für `[SP+XY]` (lokale Variablen).
Der Stack wächst nach unten: PUSH verringert SP zuerst um 2 und schreibt
dann nach `[SP]`, SP zeigt also immer auf das zuletzt abgelegte Wort.
PUSH/POP/CALL/RET/INT/RETI verändern SP immer um 2. Zusätzlich ist SP
direkt ladbar (MILSP/MIHSP, MASP, MPSP, ADDSP, SUBSP).

**PC** — Befehlszähler. Enthält die Adresse des gerade ausgeführten
Befehls und zählt in Befehlen (ROM ist wortadressiert). Nach jedem
Befehl +1, sofern der Befehl ihn nicht selbst lädt: Sprünge, CALL,
RET, RETI, INT, JMPP und die Interrupt-Injektion.

Gemeinsam für AKK, PTR und SP: Alle drei lassen sich per Immediate laden,
über das Adressrechenwerk (Basis + XY) untereinander kopieren und als
Basis für Wort-Loads `[Basis+XY]` verwenden. Ziel eines Wort-Loads ist
AKK oder PTR. Wort-Stores und ALU-Speicheroperanden gibt es nur mit
PTR oder SP als Basis.

### 2.1 Flagregister

<!-- Quelle: src/jj262_pkg.sv:212-217 (Layout), src/path/alu.sv (Erzeugung) -->

TODO — Layout `{IE, V, S, C, Z}`, Bedeutung jedes Bits, und — wichtig —
welche Befehlsgruppen die Flags ueberhaupt anfassen. IE liegt absichtlich
im Flagregister (PUSHF/POPF sichern es mit).

## 3. Befehlsformat

<!-- Quelle: src/jj262_pkg.sv:1-32, Dekodierhilfen :273-280 -->

TODO — Bitfeld-Bild des 16-Bit-Wortes: `[15:8]` Opcode, `[7:0]` XY.
Dann die Aufteilung des Opcodes ueber `op[7:6]` in die vier Gruppen und
wie sich `is_alu`, `alu_op`, `alu_src`, `cond` daraus ergeben.

Invariante, die erwaehnt gehoeren muss: Befehlswort `0x0000` ist NOP.

## 4. Bedeutung von XY

<!-- Quelle: src/jj262_pkg.sv:36 (unsigned), :156 (signed), src/jj262_pkg.sv:196-203 -->

TODO — Die eine Stelle, an der Leser stolpern: XY ist bei Adressrechnung
und Konstanten *unsigned*, bei Spruengen *signed*. Tabelle: Gruppe ->
Interpretation von XY.

## 5. Befehlssatz

### 5.1 Misc-Gruppe (`op[7:6] = 00`)

<!-- Quelle: src/jj262_pkg.sv:38-109 (Kodierung), src/cu/cu_decode.sv:38-470 (Semantik) -->

TODO — Tabelle mit Spalten: Opcode | Mnemonic | Operation | Flags | Takte.
Sinnvoll untergliedert wie im Package: Immediate-Loads, Register-Moves,
Frame (ADDSP/SUBSP), PTR-Arithmetik, Wort-Loads/Stores, Byte-Zugriffe,
Speicher-Speicher, Stack, Ablaufsteuerung.

Frei: `0x2D`–`0x3F`.

### 5.2 ALU-Gruppe (`op[6] = 1`)

<!-- Quelle: src/jj262_pkg.sv:115-149, src/path/alu.sv -->

TODO — Durchgaengige Semantik `AKK = AKK <op> SRC` vorab erklaeren, dann
die Operationstabelle. Eigene Erwaehnung wert:

- `NOT` und `NEG` sind unaer, arbeiten also auf SRC und ignorieren AKK
- `CMP` und `TST` schreiben nicht zurueck, setzen nur Flags
- `SHL`/`SHR`/`ASR`/`ROL`/`ROR`/`RCL`/`RCR` nehmen die Schiebeweite aus SRC
- `MUL`/`MULH` brauchen mehrere Takte

### 5.3 Adressierungsarten (`alu_src`, `op[5:4]`)

<!-- Quelle: src/jj262_pkg.sv:144-149 -->

TODO — Vier Modi: PTR, Immediate `zext(XY)`, `[PTR+XY]`, `[SP+XY]`.
Je Modus: Assembler-Suffix, Taktkosten.

### 5.4 Spruenge und Unterprogramme (`op[7:6] = 10`)

<!-- Quelle: src/jj262_pkg.sv:151-175, src/cu/cu_decode.sv (Sprungteil) -->

TODO — Opcode-Aufbau `{10, tgt_ptr, link, cond}`, die 15 Bedingungscodes
mit ihrer Flag-Formel, und JMP/CALL als `link`-Variante.

**Der Punkt, der einen Simulator kostet, wenn er falsch steht:** das
Displacement ist relativ zur *eigenen* Adresse, nicht zu PC+1. `disp = 0`
springt auf sich selbst, `disp = 1` ist ein Sprung auf den Folgebefehl.
Belegt in `tools/jjasm.py:256` und in `docs/todo_JJ262.txt` (Zeile 36).

Frei: `cond = 0xF`.

## 6. Speichermodell

<!-- Quelle: src/loader/op_loader.sv + src/loader/rom.sv (ROM),
     src/memory/mmu.sv:87-143 (RAM) -->

TODO — Der zweite Stolperstein, explizit ausschreiben:

- Befehls-ROM ist **wortadressiert**, der PC zaehlt Befehle (4096 Worte)
- Daten-RAM ist **byteadressiert**, little endian, zwei Byte-Baenke
- Wortzugriffe muessen gerade sein; `align_fault` loest einen Interrupt
  mit Vektor `0x01` aus (`src/memory/mmu.sv:40,68`)

## 7. Speicher- und I/O-Karte

<!-- Quelle: src/memory/mmu.sv:35,55 (Fenster), src/memory/io.sv:37-79 (Basisadressen) -->

TODO — I/O-Fenster ab `0xF000` (dekodiert auf `abus[15:12] == 0xF`), nur
die unteren 8 Bit erreichen die Peripherie. Dann eine Tabelle
Basis | Peripherie | IRQ-Vektor, und je Peripherie die Registerkarte.
Die Registerdetails stehen schon in den Kopfkommentaren von
`src/memory/peripherie/*.sv` — von dort uebernehmen, nicht neu erfinden.

## 8. Interrupts

<!-- Quelle: src/loader/op_loader.sv:28-45,71 (Injektion),
     src/cu/cu_decode.sv:382-453 (INT/RETI), src/memory/io.sv:37-79 (Daisy-Chain) -->

TODO — Ablauf beschreiben: Daisy-Chain bestimmt die Prioritaet (spaeter
instanziiert = hoeher), die Hardware injiziert einen synthetischen
`INT`-Befehl ins Befehlswort, Bedingung
`done & irq_pending & IE & ~inj_active`. Dazu: Vektortabelle,
was INT auf den Stack legt, wie RETI es zuruecknimmt, und dass POPF das
IE-Bit versehentlich umschalten kann (wie bei x86).

Vektoren: `0x01` align_fault, `0x02` KEY, `0x03` Timer, `0x04` Display,
`0x05` Tape.

## 9. Ausfuehrungszeiten

<!-- Quelle: src/cu/cu_decode.sv:10-14 -->

TODO — CPI-Tabelle. Aus dem Dekoder-Kopf: 1 Takt fuer Moves, Frame,
Stores, PUSH, JMP, EI/DI/HALT und ALU mit PTR/IMM; 2 Takte fuer Loads,
MV, POP, RET, CALL und ALU mit Speicheroperand; 3 Takte INT; 4 Takte RETI.
MUL/MULH nachmessen — steht als offener Punkt in den Notizen.

## 10. Reset- und HALT-Verhalten

<!-- Quelle: src/jj262_top.sv:34-38, src/loader/op_loader.sv, src/cu/cu_main.sv:32-45 -->

TODO — Was nach Reset definiert ist und was nicht. HALT friert den PC ein;
laut Notizen (#2) ist noch offen, wie man ihn wieder herausbekommt.

## 11. Assembler-Syntax

<!-- Quelle: tools/jjasm.py -->

TODO — Gehoert strenggenommen nicht in die ISA, ist aber noetig, um die
Beispiele lesen zu koennen. Mnemonics und ALU-Suffixe (`i`/`p`/`s`,
`tools/jjasm.py:46`), Direktiven (`.org .equ .align .text .bss .word
.ascii .asciz .space .vectors`), Pseudo-Befehle (`ldi`, `ldiptr`,
`ldisp`), lokale Labels `.name`, und die automatische
Sprungerweiterung ueber PTR bei zu weiten Zielen
(`tools/jjasm.py:240-252`) — letztere zerstoert PTR, das muss dastehen.

## 12. Offene Punkte und bekannte Abweichungen

Hierher alles, was beim Schreiben auffaellt. Bereits bekannt:

- `src/jj262_pkg.sv:138` sagt `5'h13..5'h1F frei`, aber `ALU_MULH = 5'h13`
  ist belegt. Tatsaechlich frei: `0x14`–`0x1F`.
- `ALU_ASR`-Kommentar sagt "assigned shift right", gemeint ist
  *arithmetic*.
- MUL/MULH: signed/unsigned und Laufzeit ungeklaert (Notizen #1).
- `align_fault` ist nur eine Phase lang kombinatorisch aktiv und koennte
  durchfallen (Notizen #4).
- HALT und PC-Freigabe (Notizen #2).

## Anhang A — Opcode-Matrix

TODO — 16x16-Tabelle ueber das Opcode-Byte. Macht man am Ende, wenn die
Einzeltabellen stehen, und sie deckt Luecken auf, die man sonst uebersieht.

## Anhang B — Quellenverzeichnis

| Thema | Datei |
|---|---|
| Kodierung, Opcode-Tabellen, Flags | `src/jj262_pkg.sv` |
| Semantik und Taktzahl je Befehl | `src/cu/cu_decode.sv` |
| Phasenzaehler | `src/cu/cu_main.sv` |
| ALU-Operationen, Flag-Erzeugung | `src/path/alu.sv` |
| Datenpfad, Offset-Addierer | `src/path/datapath.sv` |
| Register | `src/path/register.sv` |
| Befehls-ROM, IRQ-Injektion | `src/loader/op_loader.sv`, `src/loader/rom.sv` |
| RAM, Alignment, I/O-Fenster | `src/memory/mmu.sv` |
| Peripherie-Basisadressen, Daisy-Chain | `src/memory/io.sv` |
| Peripherie-Register | `src/memory/peripherie/*.sv` |
| Assembler | `tools/jjasm.py` |
| J-Compiler | `tools/jc.py` |
| Referenzprogramm (deckt viel ISA ab) | `programs/selftest.s` |
