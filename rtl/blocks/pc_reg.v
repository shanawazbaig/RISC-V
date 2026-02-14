module pc_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 32'b0;
        end else if (en) begin
            pc <= next_pc;
        end
    end
endmodule
