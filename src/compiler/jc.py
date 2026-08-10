#!/usr/bin/env python3
"""
jc — Compiler fuer J (abgespecktes C) -> JJ262-Assembler

Aufruf:   ./jc.py prog.j -o prog.s
          python3 jjasm.py prog.s -o boot.hex

Sprachumfang
------------
  Typen        uint8 int8 uint16 int16 void, Zeiger (T*), Arrays (T a[n])
  Konstanten   const uint16 N = 42;
  Global       uint16 x;  uint16 arr[10];
  Funktionen   uint16 f(uint16 a, uint16 b) { ... }
  Interrupts   interrupt(3) void isr() { ... }      <- Vektortabelle automatisch
  Steuerfluss  if/else, while, for, do/while, switch/case/default,
               goto+label, break, continue, return
  Operatoren   + - * / % << >> & | ^ ~ ! && || == != < > <= >=
               = += -= *= /= &= |= ^= <<= >>=   ++ --
  Adressen     &x  *p  p[i]  arr[i]
  Inline-Asm   asm("ldi 5");

Codegenerierung
---------------
  AKK haelt den aktuellen Ausdruckswert, PTR ist Adress-/Zweitoperand.
  Lokale Variablen liegen SP-relativ, Argumente darueber.
  Aufrufkonvention: Caller pusht Argumente rechts-nach-links und raeumt sie
  selbst ab; Rueckgabewert in AKK; alles caller-saved.
"""

import sys, re, argparse

# ===========================================================================
#  Lexer
# ===========================================================================
KEYWORDS = {
    'uint8','int8','uint16','int16','void','const','if','else','while','for',
    'do','switch','case','default','goto','return','break','continue',
    'interrupt','asm','sizeof',
}

TOKEN_RE = re.compile(r'''
    (?P<WS>\s+|//[^\n]*|/\*.*?\*/)
  | (?P<NUM>0[xX][0-9a-fA-F]+|0[bB][01]+|\d+)
  | (?P<CHR>'(?:\\.|[^'\\])')
  | (?P<STR>"(?:\\.|[^"\\])*")
  | (?P<ID>[A-Za-z_]\w*)
  | (?P<OP><<=|>>=|\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||[-+*/%&|^]=|[-+*/%&|^~!<>=?:;,(){}\[\]])
''', re.X | re.S)


class Tok:
    def __init__(self, kind, val, line):
        self.kind, self.val, self.line = kind, val, line
    def __repr__(self): return f"{self.kind}:{self.val}"


def lex(src):
    toks, pos, line = [], 0, 1
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise SyntaxError(f"Zeile {line}: unerwartetes Zeichen {src[pos]!r}")
        pos = m.end()
        kind = m.lastgroup
        text = m.group()
        line += text.count('\n')
        if kind == 'WS':
            continue
        if kind == 'NUM':
            v = int(text, 0) if not text.lower().startswith('0b') else int(text[2:], 2)
            toks.append(Tok('NUM', v, line))
        elif kind == 'CHR':
            body = text[1:-1].encode().decode('unicode_escape')
            toks.append(Tok('NUM', ord(body), line))
        elif kind == 'STR':
            toks.append(Tok('STR', text[1:-1], line))
        elif kind == 'ID':
            toks.append(Tok('KW' if text in KEYWORDS else 'ID', text, line))
        else:
            toks.append(Tok(text, text, line))
    toks.append(Tok('EOF', None, line))
    return toks


# ===========================================================================
#  Typen
# ===========================================================================
class Type:
    def __init__(self, name, size, signed=False, ptr=None, count=None):
        self.name, self.size, self.signed = name, size, signed
        self.ptr, self.count = ptr, count       # ptr: Zieltyp;  count: Arraylaenge
    @property
    def is_ptr(self):   return self.ptr is not None and self.count is None
    @property
    def is_array(self): return self.count is not None
    def __repr__(self): return self.name

T_U8  = Type('uint8', 1)
T_I8  = Type('int8', 1, signed=True)
T_U16 = Type('uint16', 2)
T_I16 = Type('int16', 2, signed=True)
T_VOID= Type('void', 0)
BASE_TYPES = {'uint8':T_U8, 'int8':T_I8, 'uint16':T_U16, 'int16':T_I16, 'void':T_VOID}

def ptr_to(t):        return Type(f"{t.name}*", 2, ptr=t)
def array_of(t, n):   return Type(f"{t.name}[{n}]", t.size*n, ptr=t, count=n)


# ===========================================================================
#  Symbole
# ===========================================================================
class Sym:
    def __init__(self, name, typ, kind, offset=0, value=None):
        self.name, self.type, self.kind = name, typ, kind   # kind: global/local/param/const/func
        self.offset, self.value = offset, value


class Func:
    def __init__(self, name, ret, params, body, irq=None):
        self.name, self.ret, self.params, self.body, self.irq = name, ret, params, body, irq
        self.locals_size = 0


class CompileError(Exception): pass


# ===========================================================================
#  Parser  (rekursiver Abstieg; AST = verschachtelte Tuples)
# ===========================================================================
class Parser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self, k=0): return self.t[self.i + k]
    def at(self, *vals): return self.peek().val in vals
    def atkind(self, k):  return self.peek().kind == k

    def next(self):
        tk = self.t[self.i]; self.i += 1; return tk

    def expect(self, val):
        tk = self.next()
        if tk.val != val:
            raise CompileError(f"Zeile {tk.line}: '{val}' erwartet, '{tk.val}' gefunden")
        return tk

    def accept(self, val):
        if self.at(val): self.next(); return True
        return False

    # ---- Typ ----
    def try_type(self):
        tk = self.peek()
        if tk.kind == 'KW' and tk.val in BASE_TYPES:
            self.next()
            t = BASE_TYPES[tk.val]
            while self.accept('*'):
                t = ptr_to(t)
            return t
        return None

    # ---- Top-Level ----
    def parse(self):
        decls = []
        while not self.atkind('EOF'):
            decls.append(self.top_decl())
        return decls

    def top_decl(self):
        # interrupt(N) void name() { ... }
        if self.at('interrupt'):
            self.next(); self.expect('(')
            vec = self.expect_num(); self.expect(')')
            t = self.try_type()
            if t is None: raise CompileError("Typ nach interrupt(N) erwartet")
            name = self.next().val
            self.expect('('); self.expect(')')
            body = self.block()
            return ('func', Func(name, t, [], body, irq=vec))

        if self.at('const'):
            self.next()
            t = self.try_type()
            name = self.next().val
            self.expect('=')
            val = self.const_expr()
            self.expect(';')
            return ('const', name, t, val)

        t = self.try_type()
        if t is None:
            tk = self.peek()
            raise CompileError(f"Zeile {tk.line}: Deklaration erwartet, '{tk.val}' gefunden")
        name = self.next().val

        if self.at('('):                                   # Funktion
            self.next()
            params = []
            if not self.at(')'):
                while True:
                    pt = self.try_type()
                    if pt is None: raise CompileError("Parametertyp erwartet")
                    pn = self.next().val
                    params.append((pn, pt))
                    if not self.accept(','): break
            self.expect(')')
            body = self.block()
            return ('func', Func(name, t, params, body))

        # globale Variable / Array
        if self.accept('['):
            n = self.const_expr(); self.expect(']')
            t = array_of(t, n)
        init = None
        if self.accept('='):
            init = self.const_expr()
        self.expect(';')
        return ('gvar', name, t, init)

    def expect_num(self):
        tk = self.next()
        if tk.kind != 'NUM': raise CompileError(f"Zeile {tk.line}: Zahl erwartet")
        return tk.val

    def const_expr(self):
        # sehr einfache Konstantenfaltung: Zahl, Bezeichner oder + - * <<
        node = self.expr()
        return node                     # Auswertung uebernimmt der Codegen

    # ---- Anweisungen ----
    def block(self):
        self.expect('{')
        stmts = []
        while not self.at('}'):
            stmts.append(self.stmt())
        self.expect('}')
        return ('block', stmts)

    def stmt(self):
        tk = self.peek()

        if self.at('{'):        return self.block()
        if self.accept(';'):    return ('empty',)

        if self.at('asm'):
            self.next(); self.expect('(')
            s = self.next()
            if s.kind != 'STR': raise CompileError("asm(\"...\") erwartet")
            self.expect(')'); self.expect(';')
            return ('asm', s.val)

        if self.at('if'):
            self.next(); self.expect('(')
            c = self.expr(); self.expect(')')
            then = self.stmt()
            els = self.stmt() if self.accept('else') else None
            return ('if', c, then, els)

        if self.at('while'):
            self.next(); self.expect('(')
            c = self.expr(); self.expect(')')
            return ('while', c, self.stmt())

        if self.at('do'):
            self.next()
            body = self.stmt()
            self.expect('while'); self.expect('(')
            c = self.expr(); self.expect(')'); self.expect(';')
            return ('dowhile', c, body)

        if self.at('for'):
            self.next(); self.expect('(')
            init = None if self.at(';') else self.simple_stmt()
            self.expect(';')
            cond = None if self.at(';') else self.expr()
            self.expect(';')
            step = None if self.at(')') else self.simple_stmt()
            self.expect(')')
            return ('for', init, cond, step, self.stmt())

        if self.at('switch'):
            self.next(); self.expect('(')
            e = self.expr(); self.expect(')'); self.expect('{')
            cases, default = [], None
            while not self.at('}'):
                if self.accept('case'):
                    v = self.expr(); self.expect(':')
                    body = []
                    while not (self.at('case') or self.at('default') or self.at('}')):
                        body.append(self.stmt())
                    cases.append((v, body))
                elif self.accept('default'):
                    self.expect(':')
                    body = []
                    while not (self.at('case') or self.at('default') or self.at('}')):
                        body.append(self.stmt())
                    default = body
                else:
                    raise CompileError(f"Zeile {self.peek().line}: case/default erwartet")
            self.expect('}')
            return ('switch', e, cases, default)

        if self.at('goto'):
            self.next(); name = self.next().val; self.expect(';')
            return ('goto', name)
        if self.at('return'):
            self.next()
            e = None if self.at(';') else self.expr()
            self.expect(';')
            return ('return', e)
        if self.at('break'):    self.next(); self.expect(';'); return ('break',)
        if self.at('continue'): self.next(); self.expect(';'); return ('continue',)

        # Label:
        if tk.kind == 'ID' and self.peek(1).val == ':':
            self.next(); self.next()
            return ('label', tk.val)

        # lokale Deklaration
        t = self.try_type()
        if t is not None:
            name = self.next().val
            if self.accept('['):
                n = self.const_expr(); self.expect(']')
                t = array_of(t, n)
            init = self.expr() if self.accept('=') else None
            self.expect(';')
            return ('vardecl', name, t, init)

        s = self.simple_stmt(); self.expect(';')
        return s

    def simple_stmt(self):
        return ('exprstmt', self.expr())

    # ---- Ausdruecke (Praezedenzkletterei) ----
    ASSIGN_OPS = {'=','+=','-=','*=','/=','%=','&=','|=','^=','<<=','>>='}
    BIN_PREC = {
        '||':1, '&&':2, '|':3, '^':4, '&':5,
        '==':6, '!=':6, '<':7, '>':7, '<=':7, '>=':7,
        '<<':8, '>>':8, '+':9, '-':9, '*':10, '/':10, '%':10,
    }

    def expr(self):  return self.assign()

    def assign(self):
        left = self.binary(1)
        if self.peek().val in self.ASSIGN_OPS:
            op = self.next().val
            right = self.assign()
            if op == '=':
                return ('assign', left, right)
            return ('assign', left, ('bin', op[:-1], left, right))
        return left

    def binary(self, minp):
        left = self.unary()
        while True:
            v = self.peek().val
            p = self.BIN_PREC.get(v)
            if p is None or p < minp: break
            self.next()
            right = self.binary(p + 1)
            left = ('bin', v, left, right)
        return left

    def unary(self):
        # Cast:  (typ) ausdruck
        if self.at('(') and self.peek(1).kind == 'KW' and self.peek(1).val in BASE_TYPES:
            save = self.i
            self.next()
            t = self.try_type()
            if t is not None and self.at(')'):
                self.next()
                return ('cast', t, self.unary())
            self.i = save
        v = self.peek().val
        if v in ('-','~','!','*','&'):
            self.next()
            return ('un', v, self.unary())
        if v in ('++','--'):
            self.next()
            operand = self.unary()
            return ('preinc', v, operand)
        return self.postfix()

    def postfix(self):
        node = self.primary()
        while True:
            if self.accept('['):
                idx = self.expr(); self.expect(']')
                node = ('index', node, idx)
            elif self.at('(') :
                self.next()
                args = []
                if not self.at(')'):
                    while True:
                        args.append(self.expr())
                        if not self.accept(','): break
                self.expect(')')
                node = ('call', node, args)
            elif self.peek().val in ('++','--'):
                op = self.next().val
                node = ('postinc', op, node)
            else:
                break
        return node

    def primary(self):
        tk = self.next()
        if tk.kind == 'NUM': return ('num', tk.val)
        if tk.kind == 'ID':  return ('var', tk.val)
        if tk.val == '(':
            e = self.expr(); self.expect(')'); return e
        if tk.val == 'sizeof':
            self.expect('(')
            t = self.try_type()
            self.expect(')')
            return ('num', t.size)
        raise CompileError(f"Zeile {tk.line}: unerwartetes '{tk.val}'")


# ===========================================================================
#  Codegenerator
# ===========================================================================
class Gen:
    def __init__(self, decls):
        self.decls = decls
        self.out = []
        self.globals = {}
        self.consts  = {}
        self.funcs   = {}
        self.bss     = 0x0100
        self.lbl     = 0
        self.scope   = []          # Liste von dicts (lokale Symbole)
        self.frame   = 0           # Groesse des aktuellen Frames
        self.loops   = []          # (break_label, continue_label)
        self.cur     = None
        self.spd     = 0           # SP-Verschiebung durch temporaere Pushes

    # ---- Hilfen ----
    def emit(self, s=''):  self.out.append(s if s.startswith(('.', ';')) or s.endswith(':') else '        ' + s)
    def raw(self, s):      self.out.append(s)
    def label(self, p='L'):
        self.lbl += 1
        return f".{p}{self.lbl}"

    def push(self, reg='a'):
        self.emit(f"push{reg}"); self.spd += 2
    def pop(self, reg='a'):
        self.emit(f"pop{reg}");  self.spd -= 2
    def spadj(self, n):
        self.emit(f"addsp {n}");  self.spd -= n

    def lookup(self, name):
        for sc in reversed(self.scope):
            if name in sc: return sc[name]
        if name in self.globals: return self.globals[name]
        if name in self.consts:  return self.consts[name]
        if name in self.funcs:   return Sym(name, T_U16, 'func')
        raise CompileError(f"unbekanntes Symbol '{name}'")

    # ---- Konstanten auswerten ----
    def const_val(self, node):
        k = node[0]
        if k == 'num': return node[1]
        if k == 'var':
            s = self.lookup(node[1])
            if s.kind != 'const': raise CompileError(f"'{node[1]}' ist keine Konstante")
            return s.value
        if k == 'bin':
            a, b = self.const_val(node[2]), self.const_val(node[3])
            op = node[1]
            return {'+':a+b,'-':a-b,'*':a*b,'/':a//b if b else 0,'%':a%b if b else 0,
                    '<<':a<<b,'>>':a>>b,'&':a&b,'|':a|b,'^':a^b}[op]
        if k == 'un':
            a = self.const_val(node[2])
            return {'-':-a,'~':~a,'!':int(not a)}[node[1]]
        raise CompileError("konstanter Ausdruck erwartet")

    def fix_type(self, t):
        """Arraylaengen aus AST-Knoten zu Zahlen auswerten."""
        if t.count is not None and not isinstance(t.count, int):
            n = self.const_val(t.count)
            t.count = n
            t.size  = t.ptr.size * n
            t.name  = f"{t.ptr.name}[{n}]"
        return t

    # ===================================================================
    #  Programm
    # ===================================================================
    def run(self):
        # 1. Durchgang: Symbole sammeln
        for d in self.decls:
            if d[0] == 'const':
                _, name, t, expr = d
                self.consts[name] = Sym(name, t, 'const', value=self.const_val(expr))
            elif d[0] == 'gvar':
                _, name, t, init = d
                self.globals[name] = Sym(name, self.fix_type(t), 'global')
            elif d[0] == 'func':
                f = d[1]
                self.funcs[f.name] = f

        if 'main' not in self.funcs:
            raise CompileError("Funktion 'main' fehlt")

        irqs = {f.irq: f for f in self.funcs.values() if f.irq is not None}

        self.raw("; ==========================================================")
        self.raw("; von jc erzeugt — nicht von Hand aendern")
        self.raw("; ==========================================================")
        self.raw(".equ STACKTOP, 0x0800")

        # --- BSS ---
        self.raw("")
        self.raw(f".bss 0x{self.bss:04X}")
        for name, s in self.globals.items():
            s.offset = self.bss
            self.raw(f"{name}:  .space {max(2, s.type.size)}")
            self.bss += max(2, s.type.size)

        # --- Vektortabelle ---
        self.raw("")
        self.raw(".vectors")
        maxvec = max([0] + list(irqs.keys()))
        for v in range(maxvec + 1):
            if v == 0:
                self.raw("        jmpp hi(__start)")
            elif v in irqs:
                self.raw(f"        jmpp hi({irqs[v].name})")
            else:
                self.raw("        jmpp hi(__unhandled)")

        # --- Startcode ---
        self.raw("")
        self.raw(".align 256")
        self.raw("__start:")
        self.emit("ldisp STACKTOP")
        for name, s in self.globals.items():           # Globals nullen
            if s.type.is_array: continue
            self.emit("ldi   0")
            self.emit(f"ldiptr {name}")
            self.emit("sapt  0")
        self.emit("call  main")
        self.emit("halt")
        self.raw("__unhandled:")
        self.emit("reti")

        # --- Funktionen ---
        for f in self.funcs.values():
            self.gen_func(f)

        # --- Laufzeitroutinen ---
        self.raw(RUNTIME)
        return '\n'.join(self.out) + '\n'

    # ===================================================================
    #  Funktion
    # ===================================================================
    def gen_func(self, f):
        self.cur = f
        self.spd = 0
        self.scope = [{}]
        off = 0
        # lokale Variablen einsammeln (flach, ohne Blockverschachtelung)
        locs = []
        self.collect_locals(f.body, locs)
        for name, t in locs:
            t = self.fix_type(t)
            sz = max(2, t.size if t.is_array else 2)
            self.scope[0][name] = Sym(name, t, 'local', offset=off)
            off += sz
        f.locals_size = off
        self.frame = off

        # Parameter liegen oberhalb von Frame + Ruecksprungadresse
        for i, (pn, pt) in enumerate(f.params):
            self.scope[0][pn] = Sym(pn, pt, 'param', offset=off + 2 + 2*i)

        self.raw("")
        if f.irq is not None:
            self.raw(".align 256")
        self.raw(f"{f.name}:")
        if f.irq is not None:
            self.emit("pusha")
            self.emit("pushp")
        if off: self.emit(f"subsp {off}")

        self.epilog = self.label('ret')
        self.gen_stmt(f.body)
        self.raw(f"{self.epilog}:")
        if off: self.emit(f"addsp {off}")
        if f.irq is not None:
            self.emit("popp")
            self.emit("popa")
            self.emit("reti")
        else:
            self.emit("ret")

    def collect_locals(self, node, out):
        if not isinstance(node, tuple): return
        if node[0] == 'vardecl':
            out.append((node[1], node[2]))
        for x in node[1:]:
            if isinstance(x, tuple): self.collect_locals(x, out)
            elif isinstance(x, list):
                for y in x:
                    if isinstance(y, tuple): self.collect_locals(y, out)
                    elif isinstance(y, list):
                        for z in y: self.collect_locals(z, out)

    # ===================================================================
    #  Anweisungen
    # ===================================================================
    def gen_stmt(self, s):
        k = s[0]
        if k == 'block':
            for st in s[1]: self.gen_stmt(st)
        elif k == 'empty':
            pass
        elif k == 'asm':
            self.emit(s[1])
        elif k == 'label':
            self.raw(f"{s[1]}:")
        elif k == 'goto':
            if self.spd: self.emit(f"addsp {self.spd}")
            self.far_jump(s[1])
        elif k == 'vardecl':
            if s[3] is not None:
                self.gen_assign(('var', s[1]), s[3])
        elif k == 'exprstmt':
            self.gen_expr(s[1])
        elif k == 'return':
            if s[1] is not None: self.gen_expr(s[1])
            if self.spd: self.emit(f"addsp {self.spd}")   # Temporaere aufraeumen
            self.emit(f"jmp   {self.epilog}")
        elif k == 'if':
            lf = self.label('else')
            le = self.label('endif')
            self.gen_cond(s[1], lf, False)
            self.gen_stmt(s[2])
            if s[3] is not None:
                self.emit(f"jmp   {le}")
                self.raw(f"{lf}:")
                self.gen_stmt(s[3])
                self.raw(f"{le}:")
            else:
                self.raw(f"{lf}:")
        elif k == 'while':
            lt, lb = self.label('wtop'), self.label('wend')
            self.loops.append((lb, lt, self.spd))
            self.raw(f"{lt}:")
            self.gen_cond(s[1], lb, False)
            self.gen_stmt(s[2])
            self.emit(f"jmp   {lt}")
            self.raw(f"{lb}:")
            self.loops.pop()
        elif k == 'dowhile':
            lt, lb = self.label('dtop'), self.label('dend')
            self.loops.append((lb, lt, self.spd))
            self.raw(f"{lt}:")
            self.gen_stmt(s[2])
            self.gen_cond(s[1], lt, True)
            self.raw(f"{lb}:")
            self.loops.pop()
        elif k == 'for':
            _, init, cond, step, body = s
            lt, lc, lb = self.label('ftop'), self.label('fcont'), self.label('fend')
            if init: self.gen_stmt(init)
            self.loops.append((lb, lc, self.spd))
            self.raw(f"{lt}:")
            if cond: self.gen_cond(cond, lb, False)
            self.gen_stmt(body)
            self.raw(f"{lc}:")
            if step: self.gen_stmt(step)
            self.emit(f"jmp   {lt}")
            self.raw(f"{lb}:")
            self.loops.pop()
        elif k == 'switch':
            _, e, cases, default = s
            lend = self.label('swend')
            self.gen_expr(e)                       # Wert in AKK
            self.push()                            # merken
            self.loops.append((lend, None, self.spd))
            labels = []
            for v, _ in cases:
                lc = self.label('case')
                labels.append(lc)
                self.emit("popa")
                self.emit("pusha")                 # Delta bleibt gleich
                cv = self.const_val(v)
                self.load_const_ptr(cv)
                self.emit("cmp")
                self.emit(f"jz    {lc}")
            ldef = self.label('default')
            self.emit(f"jmp   {ldef}")
            for (v, body), lc in zip(cases, labels):
                self.raw(f"{lc}:")
                for st in body: self.gen_stmt(st)
            self.raw(f"{ldef}:")
            if default:
                for st in default: self.gen_stmt(st)
            self.raw(f"{lend}:")
            self.spadj(2)                          # gemerkten Wert verwerfen
            self.loops.pop()
        elif k == 'break':
            if not self.loops: raise CompileError("break ausserhalb einer Schleife")
            lbl, _, base = self.loops[-1]
            if self.spd > base: self.emit(f"addsp {self.spd - base}")
            self.emit(f"jmp   {lbl}")
        elif k == 'continue':
            _, tgt, base = self.loops[-1]
            if tgt is None: raise CompileError("continue nicht moeglich")
            if self.spd > base: self.emit(f"addsp {self.spd - base}")
            self.emit(f"jmp   {tgt}")
        else:
            raise CompileError(f"unbekannte Anweisung {k}")

    def far_jump(self, lbl):
        """Sprung ohne Reichweitenbeschraenkung."""
        self.emit(f"ldiptr {lbl}")
        self.emit("jmp   ptr")

    # ---- Bedingung: springt nach lbl wenn (cond == want) ----
    REL = {'==':('jz','jnz'), '!=':('jnz','jz'),
           '<':('jlt','jge'), '>':('jgt','jle'),
           '<=':('jle','jgt'), '>=':('jge','jlt')}
    REL_U = {'<':('jc','jnc'), '>':('jhi','jls'),
             '<=':('jls','jhi'), '>=':('jnc','jc')}

    def gen_cond(self, e, lbl, want):
        if e[0] == 'bin' and e[1] in self.REL:
            _, op, a, b = e
            ta = self.type_of(a)
            signed = ta.signed and not ta.is_ptr
            tab = self.REL if (signed or op in ('==','!=')) else self.REL_U
            self.gen_expr(a)
            self.push()
            self.gen_expr(b)
            self.emit("mapt  0")
            self.pop()
            self.emit("cmp")
            j = tab[op][0 if want else 1]
            self.emit(f"{j:5s} {lbl}")
            return
        if e[0] == 'bin' and e[1] == '&&':
            if want:
                lskip = self.label('and')
                self.gen_cond(e[2], lskip, False)
                self.gen_cond(e[3], lbl, True)
                self.raw(f"{lskip}:")
            else:
                self.gen_cond(e[2], lbl, False)
                self.gen_cond(e[3], lbl, False)
            return
        if e[0] == 'bin' and e[1] == '||':
            if want:
                self.gen_cond(e[2], lbl, True)
                self.gen_cond(e[3], lbl, True)
            else:
                lskip = self.label('or')
                self.gen_cond(e[2], lskip, True)
                self.gen_cond(e[3], lbl, False)
                self.raw(f"{lskip}:")
            return
        if e[0] == 'un' and e[1] == '!':
            self.gen_cond(e[2], lbl, not want)
            return
        # allgemein: Wert != 0 pruefen
        self.gen_expr(e)
        self.emit("addi  0")                       # setzt Z
        self.emit(f"{'jnz' if want else 'jz':5s} {lbl}")

    # ===================================================================
    #  Ausdruecke — Ergebnis immer in AKK
    # ===================================================================
    def type_of(self, e):
        k = e[0]
        if k == 'num':   return T_U16
        if k == 'var':
            s = self.lookup(e[1])
            return s.type
        if k == 'index':
            t = self.type_of(e[1])
            return t.ptr if t.ptr else T_U16
        if k == 'un':
            if e[1] == '*':
                t = self.type_of(e[2]); return t.ptr if t.ptr else T_U16
            if e[1] == '&': return ptr_to(self.type_of(e[2]))
            return self.type_of(e[2])
        if k == 'cast':  return e[1]
        if k == 'bin':   return self.type_of(e[2])
        if k == 'call':
            f = self.funcs.get(e[1][1] if e[1][0]=='var' else None)
            return f.ret if f else T_U16
        if k in ('assign','preinc','postinc'): return self.type_of(e[1] if k=='assign' else e[2])
        return T_U16

    def load_const_ptr(self, v):
        self.emit(f"ldiptr {v & 0xFFFF}")

    def gen_expr(self, e):
        k = e[0]

        if k == 'num':
            v = e[1] & 0xFFFF
            if v < 256: self.emit(f"milak {v}")
            else:       self.emit(f"ldi   {v}")
            return

        if k == 'var':
            s = self.lookup(e[1])
            if s.kind == 'const':
                self.gen_expr(('num', s.value)); return
            if s.kind == 'func':
                self.emit(f"ldi   {s.name}"); return
            if s.type.is_array:                    # Array -> Adresse
                self.gen_addr(e); return
            self.load_from(s)
            return

        if k == 'index' or (k == 'un' and e[1] == '*'):
            t = self.type_of(e)
            self.gen_addr(e)                       # Adresse in AKK
            self.emit("mapt  0")                   # PTR = Adresse
            if t.size == 1:
                self.emit("lbpak 0" if t.signed else "lbupak 0")
            else:
                self.emit("lpak  0")
            return

        if k == 'un':
            op = e[1]
            if op == '&':
                self.gen_addr(e[2]); return
            self.gen_expr(e[2])
            if op == '-':   self.emit("neg")
            elif op == '~': self.emit("noti 0") if False else self.emit_not()
            elif op == '!':
                lt, le = self.label('n1'), self.label('n0')
                self.emit("addi  0")
                self.emit(f"jz    {lt}")
                self.emit("milak 0")
                self.emit(f"jmp   {le}")
                self.raw(f"{lt}:")
                self.emit("milak 1")
                self.raw(f"{le}:")
            return

        if k == 'bin':
            op = e[1]
            if op in ('&&','||') or op in self.REL:
                lt, le = self.label('c1'), self.label('c0')
                self.gen_cond(e, lt, True)
                self.emit("milak 0")
                self.emit(f"jmp   {le}")
                self.raw(f"{lt}:")
                self.emit("milak 1")
                self.raw(f"{le}:")
                return
            self.gen_binop(op, e[2], e[3])
            return

        if k == 'cast':
            self.gen_expr(e[2])
            t = e[1]
            if t.size == 1 and not t.is_ptr:
                self.emit("andi  255")            # auf 8 Bit kuerzen
            return

        if k == 'assign':
            self.gen_assign(e[1], e[2]); return

        if k in ('preinc','postinc'):
            op, target = (e[1], e[2])
            delta = 1 if op == '++' else -1
            t = self.type_of(target)
            step = t.ptr.size if t.is_ptr else 1
            if k == 'postinc':
                self.gen_expr(target)              # alter Wert bleibt in AKK
                self.push()
                self.gen_assign(target, ('bin', '+' if delta>0 else '-',
                                         target, ('num', step)))
                self.pop()
            else:
                self.gen_assign(target, ('bin', '+' if delta>0 else '-',
                                         target, ('num', step)))
            return

        if k == 'call':
            fname = e[1][1] if e[1][0] == 'var' else None
            if fname not in self.funcs:
                raise CompileError(f"unbekannte Funktion '{fname}'")
            f = self.funcs[fname]
            args = e[2]
            if len(args) != len(f.params):
                raise CompileError(f"'{fname}': {len(f.params)} Argumente erwartet")
            for a in reversed(args):               # rechts nach links
                self.gen_expr(a)
                self.push()
            self.emit(f"call  {fname}")
            if args: self.spadj(2*len(args))
            return

        raise CompileError(f"unbekannter Ausdruck {k}")

    def emit_not(self):
        # AKK = ~AKK   (NOT arbeitet auf der Quelle -> ueber PTR)
        self.emit("mapt  0")
        self.emit("not")

    # ---- binaere Operation ----
    COMMUTATIVE = {'+','*','&','|','^'}
    OPNAME = {'+':'add','-':'sub','*':'mul','&':'and','|':'or','^':'xor',
              '<<':'shl','>>':'shr'}

    def gen_binop(self, op, a, b):
        ta = self.type_of(a)

        # Zeigerarithmetik skalieren
        if op in ('+','-') and ta.is_ptr and ta.ptr.size > 1:
            b = ('bin', '*', b, ('num', ta.ptr.size))

        if op in ('/','%'):
            signed = ta.signed
            self.gen_expr(b); self.push()
            self.gen_expr(a); self.push()
            self.emit(f"call  {'__divs' if signed else '__divu'}")
            self.spadj(4)
            if op == '%':
                self.emit("ldiptr __rem")
                self.emit("lpak  0")
            return

        # rechte Seite konstant -> Immediate-Form
        if b[0] == 'num' or (b[0]=='var' and self.lookup(b[1]).kind=='const'):
            v = self.const_val(b) & 0xFFFF
            if v < 256:
                name = self.OPNAME[op]
                if op == '>>' and ta.signed: name = 'asr'
                self.gen_expr(a)
                self.emit(f"{name}i {v}")
                return

        # allgemein:  links -> AKK, rechts -> PTR
        self.gen_expr(a)
        self.push()
        self.gen_expr(b)
        self.emit("mapt  0")
        self.pop()
        name = self.OPNAME[op]
        if op == '>>' and ta.signed: name = 'asr'
        self.emit(name)

    # ---- Adresse eines Lvalue nach AKK ----
    def gen_addr(self, e):
        k = e[0]
        if k == 'var':
            s = self.lookup(e[1])
            if s.kind in ('local','param'):
                self.emit(f"msak  {s.offset + self.spd}")
            elif s.kind == 'global':
                self.emit(f"ldi   {s.name}")
            else:
                raise CompileError(f"'{e[1]}' hat keine Adresse")
            return
        if k == 'un' and e[1] == '*':
            self.gen_expr(e[2]); return
        if k == 'index':
            base, idx = e[1], e[2]
            tb = self.type_of(base)
            esz = tb.ptr.size if tb.ptr else 2
            if tb.is_array: self.gen_addr(base)
            else:           self.gen_expr(base)
            self.push()
            self.gen_expr(idx)
            if esz > 1: self.emit(f"muli  {esz}")
            self.emit("mapt  0")
            self.pop()
            self.emit("add")
            return
        raise CompileError(f"kein Lvalue: {k}")

    # ---- Zuweisung ----
    def gen_assign(self, target, value):
        k = target[0]
        if k == 'var':
            s = self.lookup(target[1])
            if s.kind == 'global':
                self.gen_expr(value)
                self.emit(f"ldiptr {s.name}")
                self.store_via_ptr(s.type)
            elif s.kind in ('local','param'):
                self.gen_expr(value)
                self.emit(f"sasp  {s.offset + self.spd}")
            else:
                raise CompileError(f"'{target[1]}' ist nicht zuweisbar")
            return
        if k in ('index',) or (k == 'un' and target[1] == '*'):
            t = self.type_of(target)
            self.gen_expr(value)
            self.push()
            self.gen_addr(target)
            self.emit("mapt  0")
            self.pop()
            self.store_via_ptr(t)
            return
        raise CompileError(f"kein Zuweisungsziel: {k}")

    def store_via_ptr(self, t):
        if t.size == 1 and not t.is_array: self.emit("sbpt  0")
        else:                              self.emit("sapt  0")

    def load_from(self, s):
        t = s.type
        if s.kind == 'global':
            self.emit(f"ldiptr {s.name}")
            if t.size == 1: self.emit("lbpak 0" if t.signed else "lbupak 0")
            else:           self.emit("lpak  0")
        else:
            self.emit(f"lsak  {s.offset + self.spd}")


# ===========================================================================
#  Laufzeitbibliothek
# ===========================================================================
RUNTIME = r'''
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
'''


def main():
    ap = argparse.ArgumentParser(description="J-Compiler fuer JJ262")
    ap.add_argument('input')
    ap.add_argument('-o', '--output', default='out.s')
    a = ap.parse_args()

    src = open(a.input).read()
    try:
        toks  = lex(src)
        decls = Parser(toks).parse()
        asm   = Gen(decls).run()
    except (CompileError, SyntaxError) as e:
        print(f"FEHLER: {e}", file=sys.stderr); sys.exit(1)

    open(a.output, 'w').write(asm)
    print(f"{a.output}: {len(asm.splitlines())} Zeilen Assembler")


if __name__ == '__main__':
    main()
