`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 15:03:20
// Design Name: 
// Module Name: tb_mxu_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

import tpu_pkg::*;

module tb_mxu_control;

    // =====================================================
    // CLOCK / RESET
    // =====================================================

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;

    // =====================================================
    // DUT SIGNALS
    // =====================================================

    logic start;
    logic busy;
    logic done;

    logic pe00_valid;
    logic array_en;
    logic clr_acc_n;

    dim_t dim_idx;
    logic dim_valid;

    // =====================================================
    // DUT
    // =====================================================

    mxu_control dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .busy(busy),
        .done(done),

        .pe00_valid(pe00_valid),

        .array_en(array_en),
        .clr_acc_n(clr_acc_n),

        .dim_idx(dim_idx),
        .dim_valid(dim_valid)
    );

    // =====================================================
    // SIMPLE PE TOKEN GENERATOR
    // (simulates systolic completion pressure)
    // =====================================================

    int cycle;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle <= 0;
            pe00_valid <= 0;
        end else begin
            cycle <= cycle + 1;

            // Generate a stream of "valid tokens"
            // starting after STREAM begins
            if (cycle > 5 && cycle < 200)
                pe00_valid <= 1;
            else
                pe00_valid <= 0;
        end
    end

    // =====================================================
    // MONITOR
    // =====================================================

    always_ff @(posedge clk) begin
        $display("t=%0t | start=%0b busy=%0b done=%0b state=%0d dim=%0d pe=%0b",
                 $time, start, busy, done, dut.curr_state, dim_idx, pe00_valid);
    end

    // =====================================================
    // TEST
    // =====================================================

    initial begin
        start = 0;
        rst_n = 0;

        pe00_valid = 0;

        repeat (5) @(posedge clk);

        rst_n = 1;
        @(posedge clk);

        // Pulse start
        start = 1;
        @(posedge clk);
        start = 0;

        // Run long enough to reach DONE if possible
        repeat (300) @(posedge clk);

        if (done)
            $display("\n DONE ASSERTED");
        else
            $display("\n DONE NEVER ASSERTED");

        $finish;
    end

endmodule
