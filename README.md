JJ262 16bit CPU in systemverilog

# JJ262 — a homebrew 16-bit CPU

JJ262 is a custom 16-bit CPU designed from scratch: its own instruction set,
written in SystemVerilog and running on a Terasic DE1 FPGA board (Cyclone II EP2C20).
It comes with its own toolchain, from an assembler up to a small C-like language,
and drives real peripherals like a 64×64 LED matrix.


https://github.com/user-attachments/assets/2c53a4b0-874e-49b0-aa02-243e1a88e130


<p align="center">
  <img width="4000" height="3000" alt="j262" src="https://github.com/user-attachments/assets/469ca7fc-e2da-46fa-a192-5cbea8e07ee5" />
</p>

## Features

- **Custom ISA** — designed from the ground up for this project
- **SystemVerilog RTL** — synthesized for the Cyclone II on the DE1 board
- **Toolchain**
  - `jjasm.py` — two-pass assembler
  - `jc.py` — recursive-descent compiler for **J**, a small C-like language
- **Peripherals**
  - HUB75 driver for a 64×64 RGB LED matrix
  - Tape interface using FSK encoding (decoder done)
- **Standalone boot** — the design is programmed permanently into EPCS4 flash, so the board starts without a PC

## Status

Currently, JJ262 runs **Snake** on the LED matrix (see video above).

Work in progress:
- [ ] Loading programs from cassette tape (FSK decoder works, the WM8731 audio codec still needs its I²C configuration)
- [ ] Analog joystick input
