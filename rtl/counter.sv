module counter #(
    parameter int WIDTH = 8
) (
    input  logic clk,
    input  logic reset,
    output logic [WIDTH-1:0] value
);
    timeunit 1ns;
    timeprecision 1ps;
    always_ff @(posedge clk) begin
        if (reset)
            value <= '0;
        else
            value <= value + 1'b1;
    end
endmodule
