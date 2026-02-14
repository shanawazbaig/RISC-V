.text
_start:
    addi x1, x0, 0      # sum
    addi x2, x0, 1      # i
    addi x3, x0, 6      # limit
loop:
    add  x1, x1, x2
    addi x2, x2, 1
    blt  x2, x3, loop
    sw   x1, 0(x0)
    ebreak
