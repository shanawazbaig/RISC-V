module rv32i_core #(
    parameter IMEM_WORDS = 1024,
    parameter DMEM_WORDS = 1024
) (
    input  wire clk,
    input  wire rst_n,
    output reg  halted,
    output wire [31:0] pc
);
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    integer i;

    wire [31:0] instr = imem[pc[31:2]];
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    wire reg_we;
    wire mem_we;
    wire mem_re;
    wire alu_src_imm;
    wire [1:0] wb_sel;
    wire [1:0] pc_sel;
    wire branch;
    wire is_system;
    wire is_lui;
    wire is_auipc;

    wire [31:0] imm;
    wire [31:0] rv1;
    wire [31:0] rv2;
    wire [3:0]  alu_op;
    wire [31:0] alu_b = alu_src_imm ? imm : rv2;
    wire [31:0] alu_y;
    wire branch_take;

    reg [31:0] load_data;
    reg [31:0] wb_data;

    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] pc_branch = pc + imm;
    wire [31:0] pc_jalr = (rv1 + imm) & 32'hffff_fffe;

    reg pc_en;
    reg [31:0] next_pc;

    wire [31:0] mem_addr = rv1 + imm;
    wire [31:0] mem_word = dmem[mem_addr[31:2]];

    control_unit u_ctrl (
        .opcode(opcode), .reg_we(reg_we), .mem_we(mem_we), .mem_re(mem_re),
        .alu_src_imm(alu_src_imm), .wb_sel(wb_sel), .pc_sel(pc_sel), .branch(branch),
        .is_system(is_system), .is_lui(is_lui), .is_auipc(is_auipc)
    );

    imm_gen u_imm (.instr(instr), .imm(imm));

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n), .we(pc_en && reg_we && !halted),
        .rs1(rs1), .rs2(rs2), .rd(rd), .wd(wb_data), .rv1(rv1), .rv2(rv2)
    );

    alu_control u_alu_ctrl (.opcode(opcode), .funct3(funct3), .funct7(funct7), .alu_op(alu_op));
    alu u_alu (.a(rv1), .b(alu_b), .op(alu_op), .y(alu_y));
    branch_unit u_br (.funct3(funct3), .rs1(rv1), .rs2(rv2), .take(branch_take));

    pc_reg u_pc (.clk(clk), .rst_n(rst_n), .en(pc_en), .next_pc(next_pc), .pc(pc));

    initial begin
        halted = 1'b0;
        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h00000013;
        for (i = 0; i < DMEM_WORDS; i = i + 1) dmem[i] = 32'b0;
    end

    always @(*) begin
        load_data = 32'b0;
        case (funct3)
            3'b000: load_data = {{24{mem_word[{mem_addr[1:0],3'b111}]}}, mem_word[{mem_addr[1:0],3'b111} -: 8]}; // LB
            3'b001: begin // LH
                if (!mem_addr[1]) load_data = {{16{mem_word[15]}}, mem_word[15:0]};
                else              load_data = {{16{mem_word[31]}}, mem_word[31:16]};
            end
            3'b010: load_data = mem_word; // LW
            3'b100: load_data = {24'b0, mem_word[{mem_addr[1:0],3'b111} -: 8]}; // LBU
            3'b101: load_data = mem_addr[1] ? {16'b0, mem_word[31:16]} : {16'b0, mem_word[15:0]}; // LHU
            default: load_data = 32'b0;
        endcase
    end

    always @(*) begin
        wb_data = alu_y;
        if (is_lui) wb_data = imm;
        else if (is_auipc) wb_data = pc + imm;
        else if (wb_sel == 2'd1) wb_data = load_data;
        else if (wb_sel == 2'd2) wb_data = pc_plus4;
    end

    always @(*) begin
        next_pc = pc_plus4;
        pc_en = !halted;

        if (pc_sel == 2'd1) begin
            if (opcode == 7'b1101111) next_pc = pc_branch; // JAL
            else if (branch && branch_take) next_pc = pc_branch;
        end else if (pc_sel == 2'd2) begin
            next_pc = pc_jalr;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            halted <= 1'b0;
        end else if (!halted) begin
            if (mem_we) begin
                case (funct3)
                    3'b000: begin // SB
                        case (mem_addr[1:0])
                            2'b00: dmem[mem_addr[31:2]][7:0]   <= rv2[7:0];
                            2'b01: dmem[mem_addr[31:2]][15:8]  <= rv2[7:0];
                            2'b10: dmem[mem_addr[31:2]][23:16] <= rv2[7:0];
                            2'b11: dmem[mem_addr[31:2]][31:24] <= rv2[7:0];
                        endcase
                    end
                    3'b001: begin // SH
                        if (!mem_addr[1]) dmem[mem_addr[31:2]][15:0]  <= rv2[15:0];
                        else              dmem[mem_addr[31:2]][31:16] <= rv2[15:0];
                    end
                    3'b010: dmem[mem_addr[31:2]] <= rv2; // SW
                    default: begin end
                endcase
            end

            if (is_system && instr == 32'h00100073) begin // EBREAK
                halted <= 1'b1;
            end
        end
    end
endmodule
