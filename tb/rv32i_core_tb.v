`timescale 1ns/1ps

module rv32i_core_tb;
    reg clk;
    reg rst_n;
    wire halted;
    wire [31:0] pc;

    rv32i_core #(.IMEM_WORDS(256), .DMEM_WORDS(256)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .pc(pc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        $readmemh("programs/demo_sum.hex", uut.imem);

        #20;
        rst_n = 1'b1;

        wait(halted == 1'b1);
        #10;

        $display("sum register x1=%0d, memory[0]=%0d", uut.u_regfile.regs[1], uut.dmem[0]);
        if (uut.u_regfile.regs[1] == 32'd15 && uut.dmem[0] == 32'd15) begin
            $display("TEST PASS");
        end else begin
            $display("TEST FAIL");
            $fatal(1);
        end

        $finish;
    end
endmodule
