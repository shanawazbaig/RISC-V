module rv32i_core #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256
) (
    input  wire clk,
    input  wire rst_n,
    output reg  halted,
    output reg [31:0] pc
);
    reg [31:0] regs [0:31];
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    integer i;

    wire [31:0] instr = imem[pc[31:2]];

    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    reg [31:0] next_pc;
    reg [31:0] wb_data;
    reg        wb_en;
    reg        do_store;
    reg [31:0] alu_a;
    reg [31:0] alu_b;

    initial begin
        halted = 1'b0;
        pc = 32'b0;
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'b0;
        end
        for (i = 0; i < IMEM_WORDS; i = i + 1) begin
            imem[i] = 32'h00000013; // NOP = ADDI x0,x0,0
        end
        for (i = 0; i < DMEM_WORDS; i = i + 1) begin
            dmem[i] = 32'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            halted <= 1'b0;
            pc <= 32'b0;
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (!halted) begin
            next_pc = pc + 32'd4;
            wb_data = 32'b0;
            wb_en = 1'b0;
            do_store = 1'b0;
            alu_a = regs[rs1];
            alu_b = regs[rs2];

            case (opcode)
                7'b0010011: begin // OP-IMM
                    if (funct3 == 3'b000) begin // ADDI
                        wb_en = 1'b1;
                        wb_data = regs[rs1] + imm_i;
                    end
                end

                7'b0110011: begin // OP
                    if (funct3 == 3'b000 && funct7 == 7'b0000000) begin // ADD
                        wb_en = 1'b1;
                        wb_data = regs[rs1] + regs[rs2];
                    end else if (funct3 == 3'b000 && funct7 == 7'b0100000) begin // SUB
                        wb_en = 1'b1;
                        wb_data = regs[rs1] - regs[rs2];
                    end
                end

                7'b0000011: begin // LOAD
                    if (funct3 == 3'b010) begin // LW
                        wb_en = 1'b1;
                        wb_data = dmem[(regs[rs1] + imm_i) >> 2];
                    end
                end

                7'b0100011: begin // STORE
                    if (funct3 == 3'b010) begin // SW
                        do_store = 1'b1;
                    end
                end

                7'b1100011: begin // BRANCH
                    case (funct3)
                        3'b000: begin // BEQ
                            if (regs[rs1] == regs[rs2]) begin
                                next_pc = pc + imm_b;
                            end
                        end
                        3'b100: begin // BLT
                            if ($signed(regs[rs1]) < $signed(regs[rs2])) begin
                                next_pc = pc + imm_b;
                            end
                        end
                        default: begin
                        end
                    endcase
                end

                7'b1101111: begin // JAL
                    wb_en = 1'b1;
                    wb_data = pc + 32'd4;
                    next_pc = pc + imm_j;
                end

                7'b1110011: begin // SYSTEM
                    if (instr == 32'h00100073) begin // EBREAK
                        halted <= 1'b1;
                    end
                end

                default: begin
                end
            endcase

            if (do_store) begin
                dmem[(regs[rs1] + imm_s) >> 2] <= regs[rs2];
            end

            if (wb_en && (rd != 5'd0)) begin
                regs[rd] <= wb_data;
            end

            regs[0] <= 32'b0;
            pc <= next_pc;
        end
    end
endmodule
