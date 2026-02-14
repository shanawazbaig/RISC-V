#!/usr/bin/env python3
import re
import argparse

REG_ALIASES = {
    'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,
    't0':5,'t1':6,'t2':7,'s0':8,'fp':8,'s1':9,
    'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,'a6':16,'a7':17,
    's2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,'s8':24,'s9':25,'s10':26,'s11':27,
    't3':28,'t4':29,'t5':30,'t6':31,
}
for i in range(32): REG_ALIASES[f'x{i}']=i

OPCODES = {
    'LUI':0b0110111,'AUIPC':0b0010111,'JAL':0b1101111,'JALR':0b1100111,
    'BRANCH':0b1100011,'LOAD':0b0000011,'STORE':0b0100011,'OPIMM':0b0010011,
    'OP':0b0110011,'SYSTEM':0b1110011,
}

def reg(x):
    k=x.strip().lower()
    if k not in REG_ALIASES: raise ValueError(f'Unknown register {x}')
    return REG_ALIASES[k]

def imm(x):
    x=x.strip()
    return int(x,0)

def enc_r(f7,rs2,rs1,f3,rd,opc): return ((f7&0x7f)<<25)|((rs2&0x1f)<<20)|((rs1&0x1f)<<15)|((f3&7)<<12)|((rd&0x1f)<<7)|(opc&0x7f)
def enc_i(im,rs1,f3,rd,opc): return ((im&0xfff)<<20)|((rs1&0x1f)<<15)|((f3&7)<<12)|((rd&0x1f)<<7)|(opc&0x7f)
def enc_s(im,rs2,rs1,f3,opc): return (((im>>5)&0x7f)<<25)|((rs2&0x1f)<<20)|((rs1&0x1f)<<15)|((f3&7)<<12)|((im&0x1f)<<7)|(opc&0x7f)
def enc_b(im,rs2,rs1,f3,opc): return (((im>>12)&1)<<31)|(((im>>5)&0x3f)<<25)|((rs2&0x1f)<<20)|((rs1&0x1f)<<15)|((f3&7)<<12)|(((im>>1)&0xf)<<8)|(((im>>11)&1)<<7)|(opc&0x7f)
def enc_u(im,rd,opc): return (im&0xfffff000)|((rd&0x1f)<<7)|(opc&0x7f)
def enc_j(im,rd,opc): return (((im>>20)&1)<<31)|(((im>>1)&0x3ff)<<21)|(((im>>11)&1)<<20)|(((im>>12)&0xff)<<12)|((rd&0x1f)<<7)|(opc&0x7f)

def parse_lines(text):
    out=[]
    for raw in text.splitlines():
        line=raw.split('#',1)[0].strip()
        if line: out.append(line)
    return out

def split_op(line):
    m=re.match(r'([A-Za-z_.][A-Za-z0-9_.]*):?\s*(.*)',line)
    if not m: return None,None,None
    label=None
    if line.endswith(':'):
        return line[:-1],None,[]
    if ':' in line:
        label,rest=line.split(':',1)
        line=rest.strip()
    if not line: return label,None,[]
    p=line.split(None,1)
    op=p[0].lower()
    args=[]
    if len(p)>1:
        args=[a.strip() for a in p[1].split(',')]
    return label,op,args

def expand_pseudo(op,args):
    if op=='nop': return [('addi',['x0','x0','0'])]
    if op=='mv': return [('addi',[args[0],args[1],'0'])]
    if op=='j': return [('jal',['x0',args[0]])]
    if op=='ret': return [('jalr',['x0','ra','0'])]
    if op=='li':
        rd=args[0]; val=int(args[1],0)
        lo=((val+0x800)&0xfff)-0x800
        hi=(val-lo)
        seq=[]
        if hi: seq.append(('lui',[rd,str(hi)]))
        seq.append(('addi',[rd,rd if hi else 'x0',str(lo)]))
        return seq
    return [(op,args)]

def assemble(text):
    lines=parse_lines(text)
    items=[]
    pc=0
    labels={}
    for line in lines:
        label,op,args=split_op(line)
        if label: labels[label.strip()]=pc
        if op is None: continue
        for eop,eargs in expand_pseudo(op,args):
            items.append((pc,eop,eargs,line))
            pc+=4

    words=[]
    for pc,op,args,src in items:
        uop=op.upper()
        def rel(lbl): return labels[lbl]-pc
        if op in ('add','sub','sll','slt','sltu','xor','srl','sra','or','and'):
            f3f7={'add':(0,0),'sub':(0,0x20),'sll':(1,0),'slt':(2,0),'sltu':(3,0),'xor':(4,0),'srl':(5,0),'sra':(5,0x20),'or':(6,0),'and':(7,0)}[op]
            w=enc_r(f3f7[1],reg(args[2]),reg(args[1]),f3f7[0],reg(args[0]),OPCODES['OP'])
        elif op in ('addi','slti','sltiu','xori','ori','andi','slli','srli','srai'):
            f3={'addi':0,'slti':2,'sltiu':3,'xori':4,'ori':6,'andi':7,'slli':1,'srli':5,'srai':5}[op]
            im=imm(args[2])
            if op=='srai': im=(0x20<<5)|(im&0x1f)
            w=enc_i(im,reg(args[1]),f3,reg(args[0]),OPCODES['OPIMM'])
        elif op in ('lb','lh','lw','lbu','lhu'):
            f3={'lb':0,'lh':1,'lw':2,'lbu':4,'lhu':5}[op]
            m=re.match(r'(.+)\((.+)\)$',args[1]); off=imm(m.group(1)); base=reg(m.group(2))
            w=enc_i(off,base,f3,reg(args[0]),OPCODES['LOAD'])
        elif op in ('sb','sh','sw'):
            f3={'sb':0,'sh':1,'sw':2}[op]
            m=re.match(r'(.+)\((.+)\)$',args[1]); off=imm(m.group(1)); base=reg(m.group(2))
            w=enc_s(off,reg(args[0]),base,f3,OPCODES['STORE'])
        elif op in ('beq','bne','blt','bge','bltu','bgeu'):
            f3={'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[op]
            off=rel(args[2]) if args[2] in labels else imm(args[2])
            w=enc_b(off,reg(args[1]),reg(args[0]),f3,OPCODES['BRANCH'])
        elif op=='jal':
            off=rel(args[1]) if args[1] in labels else imm(args[1])
            w=enc_j(off,reg(args[0]),OPCODES['JAL'])
        elif op=='jalr':
            w=enc_i(imm(args[2]),reg(args[1]),0,reg(args[0]),OPCODES['JALR'])
        elif op=='lui':
            w=enc_u(imm(args[1]),reg(args[0]),OPCODES['LUI'])
        elif op=='auipc':
            w=enc_u(imm(args[1]),reg(args[0]),OPCODES['AUIPC'])
        elif op=='ecall':
            w=0x00000073
        elif op=='ebreak':
            w=0x00100073
        elif op in ('.text','.globl','.global'):
            continue
        elif op=='.word':
            w=imm(args[0]) & 0xffffffff
        else:
            raise ValueError(f'Unsupported op {op} in: {src}')
        words.append(w & 0xffffffff)
    return words

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input')
    ap.add_argument('-o','--output',required=True)
    args=ap.parse_args()
    with open(args.input) as f: txt=f.read()
    words=assemble(txt)
    with open(args.output,'w') as f:
        for w in words: f.write(f'{w:08x}\n')

if __name__=='__main__':
    main()
