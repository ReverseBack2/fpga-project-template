module tb_counter;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk = 0;
    logic reset = 1;
    logic [7:0] value;
    counter dut (.clk(clk), .reset(reset), .value(value));
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_counter);
        repeat (2) @(negedge clk);
        if (value !== 8'd0) $fatal(1, "Reset failed: %0d", value);
        reset = 0;
        for (int expected = 1; expected <= 260; expected++) begin
            @(negedge clk);
            if (value !== 8'(expected))
                $fatal(1, "Counter mismatch: expected %0d, got %0d", 8'(expected), value);
        end
        reset = 1;
        @(negedge clk);
        if (value !== 8'd0) $fatal(1, "Second reset failed: %0d", value);
        $display("PASS: reset, counting, overflow, and second reset");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Simulation timeout");
    end
endmodule
