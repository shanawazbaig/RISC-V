.text
_start:
    lui  x1, 0x12345000
    auipc x2, 0
    addi x3, x0, 10
    addi x4, x0, 3
    add x5, x3, x4
    sub x6, x3, x4
    sll x7, x4, x4
    slt x8, x4, x3
    sltu x9, x3, x4
    xor x10, x3, x4
    srl x11, x3, x4
    sra x12, x6, x4
    or x13, x3, x4
    and x14, x3, x4
    slti x15, x4, 4
    sltiu x16, x4, 4
    xori x17, x3, 5
    ori x18, x3, 5
    andi x19, x3, 7
    slli x20, x4, 2
    srli x21, x3, 1
    srai x22, x6, 1
    sw x5, 0(x0)
    sh x6, 4(x0)
    sb x7, 6(x0)
    lw x23, 0(x0)
    lh x24, 4(x0)
    lb x25, 6(x0)
    lhu x26, 4(x0)
    lbu x27, 6(x0)
    beq x23, x5, ok1
    addi x28, x0, 1
ok1:
    bne x23, x6, ok2
    addi x28, x0, 2
ok2:
    blt x4, x3, ok3
    addi x28, x0, 3
ok3:
    bge x3, x4, ok4
    addi x28, x0, 4
ok4:
    bltu x4, x3, ok5
    addi x28, x0, 5
ok5:
    bgeu x3, x4, ok6
    addi x28, x0, 6
ok6:
    jal x29, done
    addi x30, x0, 99
unused:
    ecall
done:
    jalr x0, x29, 0
    ebreak
