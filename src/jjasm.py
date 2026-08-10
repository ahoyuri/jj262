#!/usr/bin/env python3
"""
jjasm — Assembler fuer die JJ262-CPU

Aufruf:   ./jjasm.py prog.s -o boot.hex [-l prog.lst]

ISA-Erinnerungen, die hier fest verdrahtet sind:
  * Befehlswort 16 Bit: [15:8] Opcode, [7:0] XY
  * ROM ist WORTadressiert (PC zaehlt Befehle), RAM ist BYTEadressiert
  * Spruenge sind relativ zur EIGENEN Adresse:  disp = ziel - sprung_addr
    (disp=0 springt auf sich selbst, disp=1 ist ein NOP-Sprung)
  * XY ist unsigned bei Adressrechnung, signed bei Spruengen
"""

import sys, re, argparse

# ---------------------------------------------------------------------------
#  ISA-Tabellen  (aus jj262_pkg.sv)
# ---------------------------------------------------------------------------
GRP_MISC, GRP_ALU, GRP_JMP, GRP_ALUX = 0b00, 0b01, 0b10, 0b11

MISC = {
    'nop':0x00,
    'milak':0x01,'mihak':0x02,'milpt':0x03,'mihpt':0x04,'milsp':0x05,'mihsp':0x06,
    'mapt':0x07,'mpak':0x08,'masp':0x09,'mpsp':0x0A,'msak':0x0B,'mspt':0x0C,
    'addsp':0x0D,'subsp':0x0E,'incpt':0x0F,'decpt':0x10,
    'lpak':0x11,'lppt':0x12,'laak':0x13,'lapt':0x14,'lsak':0x15,'lspt':0x16,
    'sapt':0x17,'sppt':0x18,'sasp':0x19,'spsp':0x1A,
    'lbpak':0x1B,'lbupak':0x1C,'sbpt':0x1D,
    'mvap':0x1E,'mvpa':0x1F,
    'pusha':0x20,'popa':0x21,'pushp':0x22,'popp':0x23,'pushf':0x24,'popf':0x25,
    'ret':0x26,'reti':0x27,'int':0x28,'ei':0x29,'di':0x2A,'halt':0x2B,
    'jmpp':0x2C,
}
# Befehle ohne Operand (XY wird 0)
MISC_NOARG = {'nop','ret','reti','ei','di','halt','pusha','popa','pushp','popp','pushf','popf'}

ALU = {
    'add':0x00,'sub':0x01,'adc':0x02,'suc':0x03,
    'and':0x04,'or':0x05,'xor':0x06,'not':0x07,
    'shl':0x08,'shr':0x09,'asr':0x0A,
    'rol':0x0B,'ror':0x0C,'rcl':0x0D,'rcr':0x0E,'neg':0x0F,
    'cmp':0x10,'tst':0x11,'mul':0x12,'mulh':0x13,
}
# Suffix -> ALU-Quelle.  Kein Suffix = PTR.
ALU_SRC = {'':0b00, 'i':0b01, 'p':0b10, 's':0b11}

COND = {
    '':0x0,'al':0x0,'z':0x1,'nz':0x2,'c':0x3,'nc':0x4,'s':0x5,'ns':0x6,
    'v':0x7,'nv':0x8,'ge':0x9,'lt':0xA,'gt':0xB,'le':0xC,'hi':0xD,'ls':0xE,
}


class AsmError(Exception):
    def __init__(self, line_no, msg):
        super().__init__(f"Zeile {line_no}: {msg}")


# ---------------------------------------------------------------------------
#  Kodierung
# ---------------------------------------------------------------------------
def enc_misc(op, xy):     return ((GRP_MISC << 6) | op) << 8 | (xy & 0xFF)
def enc_alu(op, src, xy):
    # {op[4], 1, src[1:0], op[3:0], xy}
    return (((op >> 4) & 1) << 15) | (1 << 14) | (src << 12) | ((op & 0xF) << 8) | (xy & 0xFF)
def enc_jmp(cond, link, tgt_ptr, xy):
    return ((GRP_JMP << 6) | (tgt_ptr << 5) | (link << 4) | cond) << 8 | (xy & 0xFF)


# ---------------------------------------------------------------------------
#  Ausdruecke:  Label, Konstante, Zahl, +/-, hi()/lo()
# ---------------------------------------------------------------------------
def parse_num(tok):
    tok = tok.strip()
    try:
        if   tok.lower().startswith('0x'): return int(tok, 16)
        elif tok.lower().startswith('0b'): return int(tok, 2)
        elif tok.startswith('$'):          return int(tok[1:], 16)
        elif tok.startswith("'") and tok.endswith("'") and len(tok) == 3:
            return ord(tok[1])
        else:                              return int(tok, 10)
    except ValueError:
        return None


def eval_expr(expr, syms, line_no, pass2=True):
    """Wertet einen Ausdruck aus. In Pass 1 duerfen Labels fehlen (-> 0)."""
    expr = expr.strip()

    m = re.fullmatch(r'(hi|lo)\s*\(\s*(.+?)\s*\)', expr, re.I)
    if m:
        v = eval_expr(m.group(2), syms, line_no, pass2)
        return (v >> 8) & 0xFF if m.group(1).lower() == 'hi' else v & 0xFF

    # additive Kette:  a + b - c
    parts = re.split(r'([+\-])', expr)
    total, sign = 0, 1
    for p in parts:
        p = p.strip()
        if p == '+': sign =  1; continue
        if p == '-': sign = -1; continue
        if not p:    continue
        n = parse_num(p)
        if n is None:
            if p in syms:
                n = syms[p]
            elif pass2:
                raise AsmError(line_no, f"unbekanntes Symbol '{p}'")
            else:
                n = 0
        total += sign * n
        sign = 1
    return total


# ---------------------------------------------------------------------------
#  Assembler
# ---------------------------------------------------------------------------
class Assembler:
    def __init__(self):
        self.syms   = {}     # Labels + Konstanten
        self.words  = {}     # addr -> wort
        self.listing = []
        self.bss_top = None

    # -- Zeile in (label, mnemonic, operanden) zerlegen ---------------------
    def split(self, line):
        line = re.sub(r'[;#].*$', '', line)      # Kommentar
        line = re.sub(r'//.*$', '', line).rstrip()
        if not line.strip(): return None, None, []

        label = None
        m = re.match(r'^([A-Za-z_.][\w.]*)\s*:\s*(.*)$', line)
        if m:
            label, line = m.group(1), m.group(2)
        elif not line[0].isspace():
            # Zeile beginnt ohne Einrueckung und ohne ':' -> trotzdem Befehl
            pass

        line = line.strip()
        if not line: return label, None, []
        toks = line.split(None, 1)
        mnem = toks[0].lower()
        args = [a.strip() for a in toks[1].split(',')] if len(toks) > 1 else []
        return label, mnem, args

    # -- ein Pass ----------------------------------------------------------
    def run_pass(self, lines, pass2):
        addr    = 0
        section = 'text'
        bss     = 0
        last_global = ''      # fuer lokale Labels (.name)

        for ln, raw in enumerate(lines, 1):
            label, mnem, args = self.split(raw)

            if label:
                if label.startswith('.'):
                    if not last_global:
                        raise AsmError(ln, f"lokales Label '{label}' ohne globales davor")
                    full = last_global + label          # z.B. "delay.wait"
                else:
                    last_global, full = label, label
                if not pass2:
                    if full in self.syms:
                        raise AsmError(ln, f"Label '{label}' doppelt")
                    self.syms[full] = bss if section == 'bss' else addr
            if mnem is None:
                continue

            def E(e, _lg=lambda: last_global):
                e = re.sub(r'(?<![\w.])\.(\w+)',
                           lambda m: _lg() + '.' + m.group(1), e)
                return eval_expr(e, self.syms, ln, pass2)
            emit = []

            # ---- Direktiven ----------------------------------------------
            if mnem in ('.org', '.at'):
                section = 'text'          # .org beendet einen .bss-Bereich
                addr = E(args[0]); continue
            if mnem == '.equ':
                if not pass2: self.syms[args[0]] = E(args[1])
                continue
            if mnem == '.align':
                n = E(args[0])
                if n and addr % n: addr += n - (addr % n)
                continue
            if mnem in ('.text', '.vectors'):
                section = 'text'
                if mnem == '.vectors': addr = 0
                continue
            if mnem == '.bss':
                section = 'bss'
                if args: bss = E(args[0])
                continue
            if mnem in ('.word', '.dw'):
                for a in args: emit.append(E(a) & 0xFFFF)
            elif mnem == '.space':
                if section == 'bss': bss += E(args[0]); continue
                addr += E(args[0]); continue
            elif mnem in ('.ascii', '.asciz'):
                s = re.fullmatch(r'"(.*)"', args[0].strip())
                if not s: raise AsmError(ln, "String in Anfuehrungszeichen erwartet")
                b = s.group(1).encode().decode('unicode_escape').encode('latin1')
                if mnem == '.asciz': b += b'\0'
                if len(b) % 2: b += b'\0'
                for i in range(0, len(b), 2):
                    emit.append(b[i] | (b[i+1] << 8))     # little endian

            # ---- Pseudo: 16-Bit-Immediate in ein Register -----------------
            elif mnem in ('ldi', 'ldiptr', 'ldisp'):
                v = E(args[0]) & 0xFFFF
                lo_op, hi_op = {'ldi':('milak','mihak'),
                                'ldiptr':('milpt','mihpt'),
                                'ldisp':('milsp','mihsp')}[mnem]
                emit.append(enc_misc(MISC[lo_op], v & 0xFF))
                emit.append(enc_misc(MISC[hi_op], (v >> 8) & 0xFF))

            # ---- Sprung / Call -------------------------------------------
            elif mnem == 'jmpp':                          # Seitensprung
                emit.append(enc_misc(MISC['jmpp'], E(args[0]) & 0xFF))

            elif mnem.startswith('call') or mnem.startswith('j'):
                if mnem.startswith('call'):
                    link, suffix = 1, mnem[4:]
                else:
                    link, suffix = 0, ('' if mnem == 'jmp' else mnem[1:])

                if args and args[0].lower() == 'ptr':        # Ziel in PTR
                    xy = E(args[1]) if len(args) > 1 else 0
                    emit.append(enc_jmp(COND[suffix], link, 1, xy))
                else:
                    if suffix not in COND:
                        raise AsmError(ln, f"unbekannte Bedingung '{suffix}'")
                    disp = E(args[0]) - addr                 # relativ zur EIGENEN Adresse
                    if pass2 and not (-128 <= disp <= 127):
                        raise AsmError(ln, f"Sprung zu weit ({disp}), nutze jmpp/ptr")
                    emit.append(enc_jmp(COND[suffix], link, 0, disp))

            # ---- ALU ------------------------------------------------------
            elif (mnem in ALU) or (mnem[:-1] in ALU and mnem[-1] in 'ips'):
                if mnem in ALU: op, srcs = ALU[mnem], ''
                else:           op, srcs = ALU[mnem[:-1]], mnem[-1]
                xy = E(args[0]) if args else 0
                emit.append(enc_alu(op, ALU_SRC[srcs], xy))

            # ---- Misc -----------------------------------------------------
            elif mnem in MISC:
                if mnem in MISC_NOARG and args:
                    raise AsmError(ln, f"'{mnem}' nimmt keinen Operanden")
                xy = E(args[0]) if args else 0
                emit.append(enc_misc(MISC[mnem], xy))

            else:
                raise AsmError(ln, f"unbekannter Befehl '{mnem}'")

            # ---- ablegen ---------------------------------------------------
            if pass2:
                self.listing.append((addr, list(emit), raw.rstrip()))
                for i, w in enumerate(emit):
                    a = addr + i
                    if a in self.words:
                        raise AsmError(ln, f"Adresse 0x{a:04X} doppelt belegt")
                    self.words[a] = w & 0xFFFF
            addr += len(emit)

        self.bss_top = bss

    def assemble(self, text):
        lines = text.splitlines()
        self.run_pass(lines, pass2=False)
        self.words.clear(); self.listing.clear()
        self.run_pass(lines, pass2=True)

    # -- Ausgabe -----------------------------------------------------------
    def hex_output(self, depth=None):
        top = max(self.words) if self.words else -1
        n = depth if depth else top + 1
        return '\n'.join(f"{self.words.get(a, 0):04X}" for a in range(n)) + '\n'

    def listing_output(self):
        out = ["; addr  wort   quelle"]
        for addr, words, src in self.listing:
            if not words:
                out.append(f";              {src}")
                continue
            out.append(f"{addr:04X}  {words[0]:04X}   {src}")
            for i, w in enumerate(words[1:], 1):
                out.append(f"{addr+i:04X}  {w:04X}")
        out.append("\n; --- Symbole ---")
        for k in sorted(self.syms):
            out.append(f";  {k:<20} = 0x{self.syms[k]:04X}")
        return '\n'.join(out) + '\n'


def main():
    ap = argparse.ArgumentParser(description="JJ262-Assembler")
    ap.add_argument('input')
    ap.add_argument('-o', '--output', default='boot.hex')
    ap.add_argument('-l', '--listing')
    ap.add_argument('-d', '--depth', type=int, help="ROM mit Nullen auffuellen")
    a = ap.parse_args()

    asm = Assembler()
    try:
        asm.assemble(open(a.input).read())
    except AsmError as e:
        print(f"FEHLER: {e}", file=sys.stderr); sys.exit(1)

    open(a.output, 'w').write(asm.hex_output(a.depth))
    if a.listing:
        open(a.listing, 'w').write(asm.listing_output())
    print(f"{a.output}: {len(asm.words)} Woerter, "
          f"hoechste Adresse 0x{max(asm.words):04X}" if asm.words else "leer")


if __name__ == '__main__':
    main()
