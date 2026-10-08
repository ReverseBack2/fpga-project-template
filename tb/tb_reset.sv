module tb_reset;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk = 0;
    logic reset = 1;
    logic [7:0] value;
    counter dut (.clk(clk), .reset(reset), .value(value));
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_reset);
        repeat (3) @(negedge clk);
        if (value !== 0) $fatal(1, "Reset was not held");
        reset = 0;
        repeat (9) @(negedge clk);
        if (value !== 9) $fatal(1, "Counter did not resume");
        reset = 1;
        @(negedge clk);
        if (value !== 0) $fatal(1, "Reset did not clear the counter");
        reset = 0;
        @(negedge clk);
        if (value !== 1) $fatal(1, "Counter did not restart");
        $display("PASS: held reset, reset during counting, and restart");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Simulation timeout");
    end
endmodule
