`timescale 1ns/1ps

module rv32i_core_tb;
    reg clk;
    reg rst_n;
    wire halted;
    wire [31:0] pc;

    rv32i_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .pc(pc)
    );

    function [31:0] enc_addi;
        input [4:0] rd;
        input [4:0] rs1;
        input integer imm;
        reg [11:0] imm12;
        begin
            imm12 = imm[11:0];
            enc_addi = {imm12, rs1, 3'b000, rd, 7'b0010011};
        end
    endfunction

    function [31:0] enc_add;
        input [4:0] rd;
        input [4:0] rs1;
        input [4:0] rs2;
        begin
            enc_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
        end
    endfunction

    function [31:0] enc_blt;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer imm;
        reg [12:0] off;
        begin
            off = imm[12:0];
            enc_blt = {off[12], off[10:5], rs2, rs1, 3'b100, off[4:1], off[11], 7'b1100011};
        end
    endfunction

    function [31:0] enc_sw;
        input [4:0] rs2;
        input [4:0] rs1;
        input integer imm;
        reg [11:0] imm12;
        begin
            imm12 = imm[11:0];
            enc_sw = {imm12[11:5], rs2, rs1, 3'b010, imm12[4:0], 7'b0100011};
        end
    endfunction

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;

        // Program: sum 1+2+3+4+5 and store result (15) at dmem[0]
        // 0x00: addi x1, x0, 0    ; sum = 0
        // 0x04: addi x2, x0, 1    ; i = 1
        // 0x08: addi x3, x0, 6    ; limit = 6
        // 0x0c: add  x1, x1, x2   ; loop: sum += i
        // 0x10: addi x2, x2, 1    ; i++
        // 0x14: blt  x2, x3, -8   ; if i < limit goto 0x0c
        // 0x18: sw   x1, 0(x0)    ; store sum
        // 0x1c: ebreak            ; halt
        uut.imem[0] = enc_addi(5'd1, 5'd0, 0);
        uut.imem[1] = enc_addi(5'd2, 5'd0, 1);
        uut.imem[2] = enc_addi(5'd3, 5'd0, 6);
        uut.imem[3] = enc_add(5'd1, 5'd1, 5'd2);
        uut.imem[4] = enc_addi(5'd2, 5'd2, 1);
        uut.imem[5] = enc_blt(5'd2, 5'd3, -8);
        uut.imem[6] = enc_sw(5'd1, 5'd0, 0);
        uut.imem[7] = 32'h00100073; // EBREAK

        #20;
        rst_n = 1'b1;

        wait(halted == 1'b1);
        #10;

        $display("x1(sum)=%0d, dmem[0]=%0d", uut.regs[1], uut.dmem[0]);

        if (uut.regs[1] == 32'd15 && uut.dmem[0] == 32'd15) begin
            $display("TEST PASS");
        end else begin
            $display("TEST FAIL");
            $fatal(1);
        end

        $finish;
    end
endmodule
