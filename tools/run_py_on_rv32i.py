#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path


def run(cmd):
    subprocess.run(cmd,check=True)

def main():
    ap=argparse.ArgumentParser(description='Compile Python subset -> RV32I asm -> hex -> run ISS')
    ap.add_argument('input_py')
    ap.add_argument('--outdir',default='build')
    args=ap.parse_args()

    out=Path(args.outdir)
    out.mkdir(parents=True,exist_ok=True)
    asm=out/'program.s'
    hexf=out/'program.hex'

    run(['python3','tools/py2rv32i.py',args.input_py,'-o',str(asm)])
    run(['python3','tools/rv32i_asm.py',str(asm),'-o',str(hexf)])
    run(['python3','tools/rv32i_iss.py',str(hexf)])

    print(f'ASM: {asm}')
    print(f'HEX: {hexf}')

if __name__=='__main__':
    main()
