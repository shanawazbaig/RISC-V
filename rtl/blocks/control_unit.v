module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_we,
    output reg        mem_we,
    output reg        mem_re,
    output reg        alu_src_imm,
    output reg [1:0]  wb_sel,
    output reg [1:0]  pc_sel,
    output reg        branch,
    output reg        is_system,
    output reg        is_lui,
    output reg        is_auipc
);
    // wb_sel: 0=alu,1=mem,2=pc+4
    // pc_sel: 0=pc+4,1=branch/jal,2=jalr
    always @(*) begin
        reg_we = 1'b0;
        mem_we = 1'b0;
        mem_re = 1'b0;
        alu_src_imm = 1'b0;
        wb_sel = 2'd0;
        pc_sel = 2'd0;
        branch = 1'b0;
        is_system = 1'b0;
        is_lui = 1'b0;
        is_auipc = 1'b0;

        case (opcode)
            7'b0110011: begin reg_we = 1'b1; end // OP
            7'b0010011: begin reg_we = 1'b1; alu_src_imm = 1'b1; end // OP-IMM
            7'b0000011: begin reg_we = 1'b1; mem_re = 1'b1; alu_src_imm = 1'b1; wb_sel = 2'd1; end // LOAD
            7'b0100011: begin mem_we = 1'b1; alu_src_imm = 1'b1; end // STORE
            7'b1100011: begin branch = 1'b1; pc_sel = 2'd1; end // BRANCH
            7'b1101111: begin reg_we = 1'b1; wb_sel = 2'd2; pc_sel = 2'd1; end // JAL
            7'b1100111: begin reg_we = 1'b1; wb_sel = 2'd2; alu_src_imm = 1'b1; pc_sel = 2'd2; end // JALR
            7'b0110111: begin reg_we = 1'b1; is_lui = 1'b1; end // LUI
            7'b0010111: begin reg_we = 1'b1; is_auipc = 1'b1; end // AUIPC
            7'b1110011: begin is_system = 1'b1; end // SYSTEM
            default: begin end
        endcase
    end
endmodule
