# Minimal RV32I Core (Verilog)

This repository contains a small educational RV32I processor design and a testbench.

## What is implemented

The core is a simple single-cycle style CPU with:

- 32 general-purpose registers (`x0` forced to zero)
- Instruction memory (`imem`) and data memory (`dmem`) arrays
- Program counter and halt support via `EBREAK`
- A useful subset of RV32I instructions:
  - `ADDI`
  - `ADD`, `SUB`
  - `LW`, `SW`
  - `BEQ`, `BLT`
  - `JAL`
  - `EBREAK` (used by testbench to stop simulation)

## Demo program

The included testbench runs a small loop that computes:

`1 + 2 + 3 + 4 + 5 = 15`

Then it stores the result to `dmem[0]` and halts.

## Run simulation

```bash
iverilog -g2012 -o simv rtl/rv32i_core.v tb/rv32i_core_tb.v
vvp simv
```

Expected output includes `TEST PASS`.
