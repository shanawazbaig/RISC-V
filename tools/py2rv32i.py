#!/usr/bin/env python3
import ast
import argparse

REG_POOL=['s1','s2','s3','s4','s5','s6','s7','s8','s9','s10','s11']
TMP=['t0','t1','t2','t3','t4','t5','t6']

class Gen:
    def __init__(self):
        self.lines=[]
        self.vars={}
        self.lbl=0
    def emit(self,s): self.lines.append(s)
    def new_lbl(self,p='L'): self.lbl+=1; return f'{p}{self.lbl}'
    def get_var(self,name):
        if name not in self.vars:
            if not REG_POOL: raise RuntimeError('Out of variable registers')
            self.vars[name]=REG_POOL.pop(0)
            self.emit(f'li {self.vars[name]}, 0')
        return self.vars[name]

    def eval_expr(self,node,target='t0'):
        if isinstance(node,ast.Constant):
            self.emit(f'li {target}, {int(node.value)}'); return target
        if isinstance(node,ast.Name):
            r=self.get_var(node.id); self.emit(f'mv {target}, {r}'); return target
        if isinstance(node,ast.BinOp):
            self.eval_expr(node.left,'t0'); self.eval_expr(node.right,'t1')
            op=type(node.op)
            if op is ast.Add: self.emit('add t2, t0, t1')
            elif op is ast.Sub: self.emit('sub t2, t0, t1')
            elif op is ast.BitAnd: self.emit('and t2, t0, t1')
            elif op is ast.BitOr: self.emit('or t2, t0, t1')
            elif op is ast.BitXor: self.emit('xor t2, t0, t1')
            elif op is ast.LShift: self.emit('sll t2, t0, t1')
            elif op is ast.RShift: self.emit('srl t2, t0, t1')
            else: raise RuntimeError(f'Unsupported binop {op}')
            self.emit(f'mv {target}, t2'); return target
        raise RuntimeError(f'Unsupported expr {ast.dump(node)}')

    def gen_cond_branch_false(self,test,false_label):
        if not isinstance(test,ast.Compare) or len(test.ops)!=1 or len(test.comparators)!=1:
            raise RuntimeError('Only single comparisons supported in conditions')
        self.eval_expr(test.left,'t0'); self.eval_expr(test.comparators[0],'t1')
        op=type(test.ops[0])
        mapping={ast.Eq:'bne',ast.NotEq:'beq',ast.Lt:'bge',ast.LtE:'blt',ast.Gt:'ble_hack',ast.GtE:'blt'}
        if op is ast.Gt:
            self.emit(f'blt t0, t1, {false_label}')
            self.emit(f'beq t0, t1, {false_label}')
        elif op is ast.LtE:
            self.emit(f'blt t1, t0, {false_label}')
        else:
            br=mapping.get(op)
            if br is None: raise RuntimeError('Unsupported comparator')
            self.emit(f'{br} t0, t1, {false_label}')

    def gen_stmt(self,s):
        if isinstance(s,ast.Assign):
            if len(s.targets)!=1 or not isinstance(s.targets[0],ast.Name):
                raise RuntimeError('Only simple var assignments supported')
            dst=self.get_var(s.targets[0].id)
            self.eval_expr(s.value,'t0')
            self.emit(f'mv {dst}, t0')
        elif isinstance(s,ast.AugAssign):
            if not isinstance(s.target,ast.Name): raise RuntimeError('Only var augassign')
            dst=self.get_var(s.target.id)
            self.emit(f'mv t0, {dst}')
            self.eval_expr(s.value,'t1')
            if isinstance(s.op,ast.Add): self.emit('add t0, t0, t1')
            elif isinstance(s.op,ast.Sub): self.emit('sub t0, t0, t1')
            else: raise RuntimeError('Unsupported augassign op')
            self.emit(f'mv {dst}, t0')
        elif isinstance(s,ast.While):
            l0=self.new_lbl('while'); l1=self.new_lbl('endw')
            self.emit(f'{l0}:')
            self.gen_cond_branch_false(s.test,l1)
            for b in s.body: self.gen_stmt(b)
            self.emit(f'j {l0}')
            self.emit(f'{l1}:')
        elif isinstance(s,ast.If):
            l0=self.new_lbl('else'); l1=self.new_lbl('endif')
            self.gen_cond_branch_false(s.test,l0)
            for b in s.body: self.gen_stmt(b)
            self.emit(f'j {l1}')
            self.emit(f'{l0}:')
            for b in s.orelse: self.gen_stmt(b)
            self.emit(f'{l1}:')
        else:
            raise RuntimeError(f'Unsupported stmt {type(s).__name__}')

    def compile(self,src):
        mod=ast.parse(src)
        self.emit('.text')
        self.emit('_start:')
        for s in mod.body: self.gen_stmt(s)
        self.emit('sw s1, 0(x0)')
        self.emit('ebreak')
        return '\n'.join(self.lines)+"\n"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input_py')
    ap.add_argument('-o','--output',required=True)
    args=ap.parse_args()
    with open(args.input_py) as f: src=f.read()
    g=Gen(); out=g.compile(src)
    with open(args.output,'w') as f: f.write(out)

if __name__=='__main__':
    main()
