# RV32I Processor (Verilog, Block-Separated) + Python Toolchain

This repo now contains a **block-level RV32I processor design** in Verilog, plus a Python flow to:

1. Convert a supported subset of Python code into RV32I assembly.
2. Assemble RV32I assembly into machine-code hex.
3. Execute that machine code on a Python RV32I instruction-set simulator (ISS).
4. Load the same hex into the Verilog core testbench.

---

## 1) Hardware block diagram (implemented as separate Verilog modules)

Top level:
- `rtl/rv32i_core.v`

Blocks:
- `rtl/blocks/pc_reg.v` : Program counter register.
- `rtl/blocks/regfile.v` : 32 x 32-bit register file (`x0` hardwired to 0).
- `rtl/blocks/imm_gen.v` : I/S/B/U/J immediate extractor + sign extension.
- `rtl/blocks/control_unit.v` : Main decode/control signals.
- `rtl/blocks/alu_control.v` : ALU operation decode.
- `rtl/blocks/alu.v` : Arithmetic/logic operations.
- `rtl/blocks/branch_unit.v` : Branch compare/take decision.

### Top-level datapath behavior
- Fetches instruction from internal `imem` using `pc`.
- Decodes control + immediate.
- Reads `rs1`/`rs2` from register file.
- Runs ALU for arithmetic/address generation.
- Handles load/store in internal `dmem`.
- Selects writeback source (`ALU`, `MEM`, or `PC+4`).
- Computes next PC (`PC+4`, branch/jump target, or JALR target).
- Halts on `EBREAK`.

---

## 2) Full RV32I instruction coverage in this core

The core supports **all base integer RV32I instructions** listed below.

### U-Type
- `LUI`
- `AUIPC`

### J-Type
- `JAL`

### I-Type (jump)
- `JALR`

### B-Type
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`

### I-Type (loads)
- `LB`, `LH`, `LW`, `LBU`, `LHU`

### S-Type (stores)
- `SB`, `SH`, `SW`

### I-Type (ALU immediate)
- `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`

### R-Type (ALU register)
- `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`

### SYSTEM
- `ECALL` decode path present
- `EBREAK` supported and used for simulation stop/halt

---

## 3) RV32I opcode map (base opcodes)

| Instruction group | Opcode (bin) | Opcode (hex) |
|---|---:|---:|
| LOAD | `0000011` | `0x03` |
| STORE | `0100011` | `0x23` |
| BRANCH | `1100011` | `0x63` |
| JALR | `1100111` | `0x67` |
| JAL | `1101111` | `0x6F` |
| OP-IMM | `0010011` | `0x13` |
| OP | `0110011` | `0x33` |
| LUI | `0110111` | `0x37` |
| AUIPC | `0010111` | `0x17` |
| SYSTEM | `1110011` | `0x73` |

---

## 4) Toolchain scripts

- `tools/py2rv32i.py`
  - Converts a restricted Python subset into RV32I assembly.
  - Supported constructs: simple assignments, `+/-` aug-assign, `if`, `while`, integer constants, variable references, and several binary ops.

- `tools/rv32i_asm.py`
  - Two-pass RV32I assembler.
  - Supports labels, full RV32I mnemonics above, and pseudo-instructions: `nop`, `mv`, `li`, `j`, `ret`.

- `tools/rv32i_iss.py`
  - Python RV32I ISS for executing assembled hex files.

- `tools/run_py_on_rv32i.py`
  - End-to-end wrapper:
    Python -> Assembly -> Hex -> ISS run.

---

## 5) Example programs

- `programs/demo_sum.py` : Python loop sum example.
- `programs/demo_sum.s` : hand-written assembly equivalent.
- `programs/demo_sum.hex` : machine code used by testbench.
- `programs/all_instr_demo.s` : broader RV32I instruction demo sequence.

---

## 6) How to run

### A) Python flow (works without Verilog simulator)
```bash
python3 tools/run_py_on_rv32i.py programs/demo_sum.py --outdir build
```

### B) Assemble assembly directly
```bash
python3 tools/rv32i_asm.py programs/demo_sum.s -o programs/demo_sum.hex
python3 tools/rv32i_iss.py programs/demo_sum.hex
```

### C) Verilog simulation (when simulator is installed)
```bash
iverilog -g2012 -o simv \
  rtl/blocks/pc_reg.v \
  rtl/blocks/regfile.v \
  rtl/blocks/imm_gen.v \
  rtl/blocks/control_unit.v \
  rtl/blocks/alu_control.v \
  rtl/blocks/alu.v \
  rtl/blocks/branch_unit.v \
  rtl/rv32i_core.v \
  tb/rv32i_core_tb.v
vvp simv
```

Testbench loads `programs/demo_sum.hex` and expects final sum = `15`.

---

## 7) Notes

- The Verilog core is intentionally readable and block-separated for learning/extension.
- Internal memories are simple arrays (single-cycle educational model).
- The Python frontend is a subset translator, not a full Python compiler.
