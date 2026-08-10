// ============================================================================
//  snake.j  —  Snake fuer JJ262 + HUB75 64x64
//
//  Steuerung:  KEY0 = hoch   KEY1 = runter   KEY2 = links   KEY3 = rechts
//  HEX-Anzeige zeigt die aktuelle Laenge.
//  Game over, sobald der Kopf das 64x64-Feld verlassen wuerde.
//
//  Farbe: 1 Bit je Kanal (bit0=R bit1=G bit2=B).
//    Apfel = gruen (2),  Schlange = weiss (7),  Loeschen = aus (0).
//
//  ANNAHMEN (ich hatte small_periph.sv nicht) — falls es klemmt, hier drehen:
//    * REG_KEY (0xF012): Bit0..3 = KEY0..3, 1 = gedrueckt.
//      Liefert dein periph_key active-low roh (0 = gedrueckt), dann in
//      readkeys() invertieren:  return (~*(uint16*)REG_KEY) & 0x000F;
//    * REG_HEX (0xF000): 16-Bit-Wert, den periph_hex in 4 Hex-Ziffern
//      zerlegt. Will es rohe 7-Segment-Muster, muss showlen() das umrechnen.
//  Das Display-Interface (0xF040..0xF046) ist gesichert korrekt.
// ============================================================================

// ---- Register --------------------------------------------------------------
const uint16 D_X     = 0xF040;
const uint16 D_Y     = 0xF042;
const uint16 D_COL   = 0xF044;
const uint16 D_CTL   = 0xF046;
const uint16 REG_KEY = 0xF012;
const uint16 REG_HEX = 0xF000;

// ---- Farben ----------------------------------------------------------------
const uint16 C_OFF   = 0;
const uint16 C_GREEN = 2;
const uint16 C_WHITE = 7;

// ---- Spielparameter --------------------------------------------------------
const uint16 MAXLEN = 128;      // max. Schlangenlaenge (Ringpuffergroesse)
const uint16 NAPPLE = 16;       // Eintraege der Apfel-Lookuptabelle
const uint16 SPEED  = 150;      // groesser = langsamer; anpassen bis spielbar

// ---- Zustand ---------------------------------------------------------------
uint8  bx[128];                 // Ringpuffer der Koerperzellen (Spalte)
uint8  by[128];                 // Ringpuffer der Koerperzellen (Zeile)
uint8  apx[16];                 // Apfel-Lookuptabelle (Spalte)
uint8  apy[16];                 // Apfel-Lookuptabelle (Zeile)

uint16 head;                    // Index der neuesten Zelle im Ringpuffer
uint16 tail;                    // Index der aeltesten Zelle
uint16 len;                     // Anzahl belegter Zellen
uint16 hx;                      // aktuelle Kopfposition
uint16 hy;
int16  dx;                      // Richtung (-1/0/1)
int16  dy;
uint16 ai;                      // Index in der Apfeltabelle
uint16 ax;                      // aktuelle Apfelposition
uint16 ay;

// ===========================================================================
//  Hardware-Helfer
// ===========================================================================
void setpix(uint16 x, uint16 y, uint16 c) {
    *(uint16*)D_X   = x;
    *(uint16*)D_Y   = y;
    *(uint16*)D_COL = c;         // Schreiben setzt den Pixel (autoinc aus)
}

uint16 readkeys() {
    return *(uint16*)REG_KEY;
}

void showlen(uint16 n) {
    *(uint16*)REG_HEX = n;
}

// Grobe Warteschleife. Timing haengt an der CPI deiner CPU -> SPEED anpassen.
void delay(uint16 n) {
    uint16 i;
    uint16 k;
    for (i = 0; i < n; i++) {
        k = 0;
        while (k < 500) { k++; }
    }
}

void clear_screen() {
    uint16 t;
    *(uint16*)D_CTL = 2;                          // bit1 = Bildschirm loeschen
    t = *(uint16*)D_CTL;
    while (t & 0x8000) { t = *(uint16*)D_CTL; }    // bit15 = Loeschen laeuft
    *(uint16*)D_CTL = 1;                          // bit0 = an, autoinc aus
}

// ===========================================================================
//  Apfel-Lookuptabelle  (statische Array-Init kann J nicht -> zur Laufzeit)
// ===========================================================================
void init_apples() {
    apx[0]=10;  apy[0]=10;
    apx[1]=50;  apy[1]=12;
    apx[2]=20;  apy[2]=40;
    apx[3]=45;  apy[3]=45;
    apx[4]=8;   apy[4]=55;
    apx[5]=60;  apy[5]=30;
    apx[6]=30;  apy[6]=5;
    apx[7]=15;  apy[7]=25;
    apx[8]=55;  apy[8]=58;
    apx[9]=40;  apy[9]=20;
    apx[10]=5;  apy[10]=40;
    apx[11]=35; apy[11]=50;
    apx[12]=58; apy[12]=8;
    apx[13]=25; apy[13]=60;
    apx[14]=48; apy[14]=35;
    apx[15]=12; apy[15]=45;
}

void spawn_apple() {
    ax = apx[ai];
    ay = apy[ai];
    setpix(ax, ay, C_GREEN);
}

// ===========================================================================
//  Eingabe -> Richtung  (kein direktes 180-Grad-Wenden)
// ===========================================================================
void read_dir() {
    uint16 k;
    k = readkeys();
    if ((k & 1) && (dy != 1))  { dx = 0;  dy = -1; }   // KEY0 hoch
    if ((k & 2) && (dy != -1)) { dx = 0;  dy = 1;  }   // KEY1 runter
    if ((k & 4) && (dx != 1))  { dx = -1; dy = 0;  }   // KEY2 links
    if ((k & 8) && (dx != -1)) { dx = 1;  dy = 0;  }   // KEY3 rechts
}

// ===========================================================================
void main() {
    int16 nx;
    int16 ny;

    clear_screen();
    init_apples();

    // Startschlange: 3 Zellen waagerecht in der Mitte, Blickrichtung rechts
    bx[0]=30; by[0]=32;
    bx[1]=31; by[1]=32;
    bx[2]=32; by[2]=32;
    tail = 0;
    head = 2;
    len  = 3;
    hx = 32; hy = 32;
    dx = 1;  dy = 0;

    setpix(30, 32, C_WHITE);
    setpix(31, 32, C_WHITE);
    setpix(32, 32, C_WHITE);
    showlen(len);

    ai = 0;
    spawn_apple();

    while (1) {
        read_dir();

        nx = (int16)hx + dx;
        ny = (int16)hy + dy;

        // ---- Wand? -> Game over ----
        if (nx < 0 || nx > 63 || ny < 0 || ny > 63) {
            showlen(len);
            while (1) { showlen(len); }            // einfrieren
        }

        // ---- Kopf vorruecken ----
        head = head + 1;
        if (head == MAXLEN) head = 0;
        bx[head] = nx;
        by[head] = ny;
        hx = nx;
        hy = ny;
        setpix(nx, ny, C_WHITE);

        // ---- Apfel gefressen? ----
        if (nx == ax && ny == ay) {
            if (len < MAXLEN - 1) len = len + 1;   // waechst -> Schwanz bleibt
            showlen(len);
            ai = ai + 1;
            if (ai == NAPPLE) ai = 0;
            spawn_apple();
        } else {
            // Schwanz loeschen und Ringpuffer nachziehen
            setpix(bx[tail], by[tail], C_OFF);
            tail = tail + 1;
            if (tail == MAXLEN) tail = 0;
        }

        delay(SPEED);
    }
}
