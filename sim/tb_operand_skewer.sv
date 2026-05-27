`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 03:10:30 PM
// Design Name: 
// Module Name: tb_operand_skewer
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

module tb_operand_skewer;

    localparam int N       = 8;
    localparam int DATA_W  = 8;
    localparam int D_MODEL = 16;

    localparam int DEPTH = D_MODEL;

    logic clk;
    logic rst_n;

    // Inputs to DUT
    logic signed [DATA_W-1:0] a_j [0:N-1];
    logic signed [DATA_W-1:0] b_i [0:N-1];
    logic d_valid;

    // Outputs from DUT
    logic signed [DATA_W-1:0] a_j_skewed [0:N-1];
    logic signed [DATA_W-1:0] b_i_skewed [0:N-1];
    logic pe00_valid;

    int errors;

    // -----------------------
    // DUT
    // -----------------------
    operand_skewer #(
        .N(N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .a_j(a_j),
        .b_i(b_i),
        .d_valid(d_valid),

        .a_j_skewed(a_j_skewed),
        .b_i_skewed(b_i_skewed),

        .pe00_valid(pe00_valid)
    );

    // -----------------------
    // CLOCK
    // -----------------------
    always #5 clk = ~clk;

    // -----------------------
    // TEST STREAMS
    // -----------------------
    logic signed [DATA_W-1:0] A_stream [0:N-1][0:DEPTH-1];
    logic signed [DATA_W-1:0] B_stream [0:N-1][0:DEPTH-1];

    // -----------------------
    // EXPECTED VALUE HELPERS
    //
    // Lane i should output the value from i cycles ago.
    // Lane 0 has 0-cycle delay.
    // Lane 1 has 1-cycle delay.
    // Lane 2 has 2-cycle delay.
    // ...
    // -----------------------
    function automatic logic signed [DATA_W-1:0] expected_a(
        input int lane,
        input int t
    );
        int src_t;
        begin
            src_t = t - lane;

            if (src_t >= 0 && src_t < DEPTH)
                expected_a = A_stream[lane][src_t];
            else
                expected_a = '0;
        end
    endfunction

    function automatic logic signed [DATA_W-1:0] expected_b(
        input int lane,
        input int t
    );
        int src_t;
        begin
            src_t = t - lane;

            if (src_t >= 0 && src_t < DEPTH)
                expected_b = B_stream[lane][src_t];
            else
                expected_b = '0;
        end
    endfunction

    function automatic logic expected_pe00_valid(
        input int t
    );
        begin
            expected_pe00_valid = (t < DEPTH);
        end
    endfunction

    // -----------------------
    // DRIVE INPUTS
    //
    // This models the previous operand_handler as registered logic.
    // On valid cycles, it sends real data.
    // On invalid cycles, it sends zeros.
    // -----------------------
    task automatic drive_inputs(
        input int t
    );
        begin
            if (t < DEPTH) begin
                d_valid <= 1'b1;

                for (int lane = 0; lane < N; lane++) begin
                    a_j[lane] <= A_stream[lane][t];
                    b_i[lane] <= B_stream[lane][t];
                end
            end else begin
                d_valid <= 1'b0;

                for (int lane = 0; lane < N; lane++) begin
                    a_j[lane] <= '0;
                    b_i[lane] <= '0;
                end
            end
        end
    endtask

    // -----------------------
    // CHECK OUTPUTS
    // -----------------------
    task automatic check_outputs(
        input int t
    );
        logic exp_pe00_valid;

        begin
            exp_pe00_valid = expected_pe00_valid(t);

            $display("Cycle t=%0d | d_valid=%0b | pe00_valid=%0b",
                     t, d_valid, pe00_valid);

            for (int lane = 0; lane < N; lane++) begin
                if (a_j_skewed[lane] !== expected_a(lane, t)) begin
                    $display(
                        "FAIL A lane %0d at t=%0d: DUT=%0d GOLD=%0d",
                        lane,
                        t,
                        a_j_skewed[lane],
                        expected_a(lane, t)
                    );
                    errors++;
                end else begin
                    $display(
                        "PASS A lane %0d at t=%0d: %0d",
                        lane,
                        t,
                        a_j_skewed[lane]
                    );
                end

                if (b_i_skewed[lane] !== expected_b(lane, t)) begin
                    $display(
                        "FAIL B lane %0d at t=%0d: DUT=%0d GOLD=%0d",
                        lane,
                        t,
                        b_i_skewed[lane],
                        expected_b(lane, t)
                    );
                    errors++;
                end else begin
                    $display(
                        "PASS B lane %0d at t=%0d: %0d",
                        lane,
                        t,
                        b_i_skewed[lane]
                    );
                end
            end

            if (pe00_valid !== exp_pe00_valid) begin
                $display(
                    "FAIL pe00_valid at t=%0d: DUT=%0b GOLD=%0b",
                    t,
                    pe00_valid,
                    exp_pe00_valid
                );
                errors++;
            end else begin
                $display(
                    "PASS pe00_valid at t=%0d: %0b",
                    t,
                    pe00_valid
                );
            end

            $display("----------------------------------------");
        end
    endtask

    // -----------------------
    // RESET CHECK
    // -----------------------
    task automatic check_reset_outputs;
        begin
            for (int lane = 0; lane < N; lane++) begin
                if (a_j_skewed[lane] !== '0) begin
                    $display(
                        "FAIL RESET A lane %0d: DUT=%0d GOLD=0",
                        lane,
                        a_j_skewed[lane]
                    );
                    errors++;
                end

                if (b_i_skewed[lane] !== '0) begin
                    $display(
                        "FAIL RESET B lane %0d: DUT=%0d GOLD=0",
                        lane,
                        b_i_skewed[lane]
                    );
                    errors++;
                end
            end

            if (pe00_valid !== 1'b0) begin
                $display(
                    "FAIL RESET pe00_valid: DUT=%0b GOLD=0",
                    pe00_valid
                );
                errors++;
            end
        end
    endtask

    // -----------------------
    // MAIN TEST
    // -----------------------
    initial begin
        int total_cycles;

        errors = 0;

        clk      = 1'b0;
        rst_n    = 1'b0;
        d_valid  = 1'b0;

        for (int lane = 0; lane < N; lane++) begin
            a_j[lane] = '0;
            b_i[lane] = '0;
        end

        // -------------------------------------------------
        // Test data:
        //
        // Use signed values on purpose.
        // This catches accidental unsigned behavior.
        //
        // A and B use different patterns so swapped signals
        // are easy to catch in the waveform.
        // -------------------------------------------------
        for (int lane = 0; lane < N; lane++) begin
            for (int d = 0; d < DEPTH; d++) begin
                A_stream[lane][d] = -60 + (8 * lane) + d;
                B_stream[lane][d] =  60 - (8 * lane) - d;
            end
        end

        // -----------------------
        // RESET
        // -----------------------
        repeat (3) @(posedge clk);
        #1;

        check_reset_outputs();

        @(posedge clk);
        rst_n <= 1'b1;
        #1;

        $display("\n===== STARTING OPERAND SKEWER TEST =====");

        // DEPTH valid cycles plus enough cycles to drain lane N-1.
        total_cycles = DEPTH + N + 2;

        for (int t = 0; t < total_cycles; t++) begin
            @(posedge clk);

            drive_inputs(t);

            // Let nonblocking assignments and combinational outputs settle.
            #1;

            check_outputs(t);
        end

        // -----------------------
        // FINAL RESULT
        // -----------------------
        if (errors == 0)
            $display("\nTEST PASSED");
        else
            $display("\nTEST FAILED: %0d mismatches", errors);

        $finish;
    end

endmodule

