#!/usr/bin/env python3
import argparse

class RV32I:
    def __init__(self, imem_words, dmem_size=4096):
        self.x=[0]*32
        self.pc=0
        self.imem=imem_words[:]
        self.mem=bytearray(dmem_size)
        self.halted=False

    @staticmethod
    def sx(v,b):
        s=1<<(b-1)
        return (v & (s-1)) - (v & s)

    def rw(self,a):
        return int.from_bytes(self.mem[a:a+4],'little')
    def ww(self,a,v):
        self.mem[a:a+4]=int(v&0xffffffff).to_bytes(4,'little')

    def step(self):
        if self.halted: return
        ins=self.imem[self.pc>>2] if (self.pc>>2)<len(self.imem) else 0x00000013
        opc=ins & 0x7f; rd=(ins>>7)&0x1f; f3=(ins>>12)&7; rs1=(ins>>15)&0x1f; rs2=(ins>>20)&0x1f; f7=(ins>>25)&0x7f
        iim=self.sx(ins>>20,12)
        sim=self.sx(((ins>>25)<<5)|((ins>>7)&0x1f),12)
        bim=self.sx((((ins>>31)&1)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&0x3f)<<5)|(((ins>>8)&0xf)<<1),13)
        uim=ins & 0xfffff000
        jim=self.sx((((ins>>31)&1)<<20)|(((ins>>12)&0xff)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&0x3ff)<<1),21)
        nx=(self.pc+4)&0xffffffff

        r1=self.x[rs1]; r2=self.x[rs2]
        wb=None
        if opc==0x33:
            ops={0:(r1+r2),1:(r1<<(r2&31)),2:(1 if self.sx(r1,32)<self.sx(r2,32) else 0),3:(1 if r1<r2 else 0),4:(r1^r2),5:(self.sx(r1,32)>>(r2&31) if f7==0x20 else r1>>(r2&31)),6:(r1|r2),7:(r1&r2)}
            wb=((r1-r2) if (f3==0 and f7==0x20) else ops[f3])&0xffffffff
        elif opc==0x13:
            sh=rs2
            if f3==0: wb=(r1+iim)&0xffffffff
            elif f3==1: wb=(r1<<(sh&31))&0xffffffff
            elif f3==2: wb=1 if self.sx(r1,32)<iim else 0
            elif f3==3: wb=1 if r1<(iim&0xffffffff) else 0
            elif f3==4: wb=(r1^iim)&0xffffffff
            elif f3==5: wb=((self.sx(r1,32)>>(sh&31)) if ((ins>>30)&1) else (r1>>(sh&31)))&0xffffffff
            elif f3==6: wb=(r1|iim)&0xffffffff
            elif f3==7: wb=(r1&iim)&0xffffffff
        elif opc==0x03:
            a=(r1+iim)&0xffffffff
            if f3==0: wb=self.sx(self.mem[a],8)&0xffffffff
            elif f3==1: wb=self.sx(int.from_bytes(self.mem[a:a+2],'little'),16)&0xffffffff
            elif f3==2: wb=self.rw(a)
            elif f3==4: wb=self.mem[a]
            elif f3==5: wb=int.from_bytes(self.mem[a:a+2],'little')
        elif opc==0x23:
            a=(r1+sim)&0xffffffff
            if f3==0: self.mem[a]=r2&0xff
            elif f3==1: self.mem[a:a+2]=int(r2&0xffff).to_bytes(2,'little')
            elif f3==2: self.ww(a,r2)
        elif opc==0x63:
            take={0:r1==r2,1:r1!=r2,4:self.sx(r1,32)<self.sx(r2,32),5:self.sx(r1,32)>=self.sx(r2,32),6:r1<r2,7:r1>=r2}.get(f3,False)
            if take: nx=(self.pc+bim)&0xffffffff
        elif opc==0x6f:
            wb=nx; nx=(self.pc+jim)&0xffffffff
        elif opc==0x67:
            wb=nx; nx=((r1+iim)&~1)&0xffffffff
        elif opc==0x37:
            wb=uim
        elif opc==0x17:
            wb=(self.pc+uim)&0xffffffff
        elif opc==0x73:
            if ins==0x00100073: self.halted=True

        if wb is not None and rd!=0: self.x[rd]=wb&0xffffffff
        self.x[0]=0
        self.pc=nx

    def run(self,max_cycles=10000):
        c=0
        while not self.halted and c<max_cycles:
            self.step(); c+=1
        return c

def load_hex(path):
    with open(path) as f:
        return [int(x.strip(),16) for x in f if x.strip()]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('hex')
    ap.add_argument('--max-cycles',type=int,default=10000)
    args=ap.parse_args()
    cpu=RV32I(load_hex(args.hex))
    cyc=cpu.run(args.max_cycles)
    print(f'cycles={cyc} halted={cpu.halted} pc=0x{cpu.pc:08x} x10(a0)={cpu.x[10]} mem0={cpu.rw(0)}')

if __name__=='__main__':
    main()
