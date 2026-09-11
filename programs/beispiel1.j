const uint16 IO_HEX = 0xF000;

uint16 counter;
uint16 arr[8];

uint16 add3(uint16 a, uint16 b, uint16 c) {
    return a + b + c;
}

void main() {
    uint16 i;
    uint16 sum;

    counter = 5;
    counter = counter + 3;

    for (i = 0; i < 8; i = i + 1) {
        arr[i] = i * 2;
    }

    sum = 0;
    for (i = 0; i < 8; i++) {
        sum += arr[i];
    }

    if (sum == 56) {
        sum = add3(1, 2, 3);
    } else {
        sum = 0xBAD;
    }

    while (sum > 0) {
        sum--;
    }

    asm("ldi 0x600D");
    asm("ldiptr 0xF000");
    asm("sapt 0");
}
