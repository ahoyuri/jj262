#!/usr/bin/env python3
"""
mktape — .hex  ->  WAV zum Einspielen ueber Line-In

Aufruf:   ./mktape.py boot.hex -o boot.wav
          ./mktape.py boot.hex -o boot.wav --leader 3.0

Kodierung
---------
Frequenzumtastung, ein Bit pro vollständiger Schwingung:
    Bit 0 = 4410 Hz   (10 Samples bei 44100 Hz)
    Bit 1 = 2205 Hz   (20 Samples bei 44100 Hz)

Beide Frequenzen teilen 44100 glatt, dadurch ist jede Periode exakt
gleich lang — kein Jitter durch Rundung.

Byte-Rahmen wie bei UART:  Startbit 0, 8 Datenbits (LSB zuerst), Stoppbit 1.
Damit kann die Hardware sich nach einem Fehler wieder einsynchronisieren.

Bandaufbau
----------
    Vorlauf   ca. 2 s Dauerton (nur 1-Bits)  — Empfaenger einrasten lassen
    Magic     "JJ26"                          — Bandanfang erkennen
    Laenge    2 Byte, little endian           — Anzahl der Woerter
    Daten     Laenge * 2 Byte, little endian
    Summe     2 Byte, little endian           — einfache 16-Bit-Summe
    Magic     "END!"                          — Bandende bestaetigen
    Nachlauf  0,5 s Dauerton

Passende CPU-Parameter bei 25 MHz Systemtakt:
    Periode Bit 0 = 25e6/4410 ≈ 5669 Takte
    Periode Bit 1 = 25e6/2205 ≈ 11338 Takte
    Schwelle      ≈ 8500 Takte   (Vorgabe im Tape-Modul)
"""

import sys, wave, struct, argparse

SR    = 44100
F0    = 4410          # Bit 0
F1    = 2205          # Bit 1
MAGIC_START = b"JJ26"
MAGIC_END   = b"END!"

# Eine Periode als Rechteck: erste Haelfte hoch, zweite tief.
def cycle(freq):
    n = SR // freq
    h = n // 2
    return bytes([0xE0] * h + [0x20] * (n - h))

CYC = {0: cycle(F0), 1: cycle(F1)}


def bits_of_byte(b):
    yield 0                        # Startbit
    for i in range(8):
        yield (b >> i) & 1         # LSB zuerst
    yield 1                        # Stoppbit


def main():
    ap = argparse.ArgumentParser(description="hex -> WAV fuer JJ262-Tape")
    ap.add_argument('input', help="Eingabe .hex (ein 16-Bit-Wort pro Zeile)")
    ap.add_argument('-o', '--output', default='tape.wav')
    ap.add_argument('--leader',  type=float, default=2.0, help="Vorlauf in Sekunden")
    ap.add_argument('--trailer', type=float, default=0.5)
    ap.add_argument('--trim', action='store_true',
                    help="fuehrende Nullwoerter am Ende weglassen")
    ap.add_argument('--sim', metavar='FILE',
                    help="Periodenliste fuer die Simulation ausgeben (Takte)")
    ap.add_argument('--simclk', type=float, default=25e6, help="CPU-Takt fuer --sim")
    ap.add_argument('--simscale', type=int, default=1,
                    help="Perioden fuer --sim verkuerzen (Faktor)")
    a = ap.parse_args()

    # --- .hex einlesen ---
    words = []
    for ln, line in enumerate(open(a.input), 1):
        line = line.split('//')[0].split('#')[0].strip()
        if not line: continue
        try:
            words.append(int(line, 16) & 0xFFFF)
        except ValueError:
            print(f"FEHLER: {a.input}:{ln}: '{line}' ist keine Hexzahl", file=sys.stderr)
            sys.exit(1)

    if a.trim:
        while words and words[-1] == 0:
            words.pop()

    if not words:
        print("FEHLER: keine Daten", file=sys.stderr); sys.exit(1)
    if len(words) > 0xFFFF:
        print("FEHLER: mehr als 65535 Woerter", file=sys.stderr); sys.exit(1)

    # --- Bytestrom aufbauen ---
    payload = bytearray()
    payload += MAGIC_START
    payload += struct.pack('<H', len(words))
    for w in words:
        payload += struct.pack('<H', w)
    checksum = sum(words) & 0xFFFF
    payload += struct.pack('<H', checksum)
    payload += MAGIC_END

    # --- Audio erzeugen ---
    audio = bytearray()
    lead_cycles = int(a.leader * F1)                 # Vorlauf: nur 1-Bits
    audio += CYC[1] * lead_cycles
    for byte in payload:
        for bit in bits_of_byte(byte):
            audio += CYC[bit]
    audio += CYC[1] * int(a.trailer * F1)

    # --- Periodenliste fuer die Simulation ---
    if a.sim:
        p0 = int(a.simclk / F0) // a.simscale
        p1 = int(a.simclk / F1) // a.simscale
        with open(a.sim, 'w') as f:
            for _ in range(20):                      # kurzer Vorlauf
                f.write(f"{p1}\n")
            for byte in payload:
                for bit in bits_of_byte(byte):
                    f.write(f"{p1 if bit else p0}\n")
            for _ in range(4):
                f.write(f"{p1}\n")
        print(f"{a.sim}: Perioden {p0}/{p1} Takte, Schwelle ~{(p0+p1)//2}")

    with wave.open(a.output, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(1)                            # 8 Bit unsigned
        w.setframerate(SR)
        w.writeframes(bytes(audio))

    dur = len(audio) / SR
    print(f"{a.output}: {len(words)} Woerter, {len(payload)} Byte Nutzlast, "
          f"Summe 0x{checksum:04X}, {dur:.1f} s")


if __name__ == '__main__':
    main()
