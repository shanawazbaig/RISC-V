module alu_control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] alu_op
);
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SLT  = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_OR   = 4'd8;
    localparam ALU_AND  = 4'd9;

    always @(*) begin
        alu_op = ALU_ADD;
        case (opcode)
            7'b0110011: begin // OP
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            7'b0010011: begin // OP-IMM
                case (funct3)
                    3'b000: alu_op = ALU_ADD; // ADDI
                    3'b001: alu_op = ALU_SLL; // SLLI
                    3'b010: alu_op = ALU_SLT; // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b100: alu_op = ALU_XOR; // XORI
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // SRLI/SRAI
                    3'b110: alu_op = ALU_OR; // ORI
                    3'b111: alu_op = ALU_AND; // ANDI
                    default: alu_op = ALU_ADD;
                endcase
            end
            default: alu_op = ALU_ADD;
        endcase
    end
endmodule
