module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wd,
    output wire [31:0] rv1,
    output wire [31:0] rv2
);
    reg [31:0] regs [0:31];
    integer i;

    assign rv1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rv2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            if (we && (rd != 5'd0)) begin
                regs[rd] <= wd;
            end
            regs[0] <= 32'b0;
        end
    end
endmodule
