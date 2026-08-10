const uint16 IO_HEX = 0xF000;
const uint16 TMR_RELOAD = 0xF020;
const uint16 TMR_COUNT  = 0xF022;
const uint16 TMR_CTRL   = 0xF024;
const uint16 TMR_PRESC  = 0xF026;

uint16 ticks;
uint16 result;
uint8  bytes[4];

uint16 classify(uint16 n) {
    switch (n) {
        case 1:  return 10;
        case 2:  return 20;
        default: return 99;
    }
}

interrupt(3) void on_timer() {
    ticks = ticks + 1;
    *((uint16*) TMR_COUNT) = 0;
}

void main() {
    uint16 a;
    uint16 b;
    uint16* p;

    /* Division und Modulo */
    a = 100 / 7;              /* 14 */
    b = 100 % 7;              /* 2  */
    result = a * 100 + b;     /* 1402 */

    /* Zeiger */
    p = &result;
    *p = *p + 1;              /* 1403 */

    /* Bytes */
    bytes[0] = 0x12;
    bytes[3] = 0x34;
    a = bytes[0] + bytes[3];  /* 0x46 */

    /* switch */
    b = classify(2);          /* 20 */

    if (result == 1403 && a == 0x46 && b == 20) {
        *((uint16*) IO_HEX) = 0x600D;
    } else {
        *((uint16*) IO_HEX) = 0xBAD;
    }
}
