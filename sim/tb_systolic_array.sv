`timescale 1ns / 1ps

import tpu_pkg::*;

module tb_systolic_array;

    // =====================================================
    // Local testbench parameters
    // =====================================================

    localparam int DEPTH = D_MODEL;   // Inner dimension: 8x16 times 16x8

    // Number of cycles where real skewed boundary inputs may appear.
    // Last nonzero boundary input occurs at:
    //     k = DEPTH - 1, row/col = N - 1
    //     t = DEPTH + N - 2
    //
    // Therefore number of stream cycles is:
    //     DEPTH + N - 1
    localparam int STREAM_CYCLES = DEPTH + N - 1;

    // After the last boundary token enters, it needs to propagate through
    // the far side of the array. During these cycles, boundary inputs are zero,
    // but array_en remains high.
    localparam int DRAIN_CYCLES = N;

    // =====================================================
    // DUT IO
    // =====================================================

    logic clk;
    logic rst_n;

    logic array_en;
    logic clr_acc_n;

    operand_t a_j_skewed [0:N-1];
    operand_t b_i_skewed [0:N-1];

    accumulator_t c [0:N-1][0:N-1];

    // =====================================================
    // DUT
    // =====================================================

    systolic_array dut (
        .clk        (clk),
        .rst_n      (rst_n),

        .array_en   (array_en),
        .clr_acc_n  (clr_acc_n),

        .a_j_skewed (a_j_skewed),
        .b_i_skewed (b_i_skewed),

        .c          (c)
    );

    // =====================================================
    // CLOCK
    // =====================================================

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =====================================================
    // MATRICES
    // =====================================================

    operand_t A [0:N-1][0:DEPTH-1];
    operand_t B [0:DEPTH-1][0:N-1];

    accumulator_t golden [0:N-1][0:N-1];

    int errors;

    // =====================================================
    // EXPECTED SKEWED INPUTS
    // =====================================================

    function automatic operand_t expected_a_input(
        input int row,
        input int t
    );
        int k;
        begin
            k = t - row;

            if ((k >= 0) && (k < DEPTH))
                expected_a_input = A[row][k];
            else
                expected_a_input = '0;
        end
    endfunction

    function automatic operand_t expected_b_input(
        input int col,
        input int t
    );
        int k;
        begin
            k = t - col;

            if ((k >= 0) && (k < DEPTH))
                expected_b_input = B[k][col];
            else
                expected_b_input = '0;
        end
    endfunction

    // =====================================================
    // DUT IO DRIVE TASKS
    // =====================================================

    task automatic drive_idle_io;
        begin
            array_en <= 1'b0;

            for (int i = 0; i < N; i++) begin
                a_j_skewed[i] <= '0;
                b_i_skewed[i] <= '0;
            end
        end
    endtask

    task automatic drive_stream_inputs(
        input int t
    );
        begin
            array_en <= 1'b1;

            for (int row = 0; row < N; row++) begin
                a_j_skewed[row] <= expected_a_input(row, t);
            end

            for (int col = 0; col < N; col++) begin
                b_i_skewed[col] <= expected_b_input(col, t);
            end
        end
    endtask

    task automatic drive_drain_inputs;
        begin
            // Important:
            // During drain, the array must keep shifting internal data.
            // Therefore array_en remains high, but boundary inputs are zero.
            array_en <= 1'b1;

            for (int i = 0; i < N; i++) begin
                a_j_skewed[i] <= '0;
                b_i_skewed[i] <= '0;
            end
        end
    endtask

    task automatic apply_reset;
        begin
            rst_n     <= 1'b0;
            clr_acc_n <= 1'b0;
            drive_idle_io();

            repeat (3) @(posedge clk);

            rst_n     <= 1'b1;
            clr_acc_n <= 1'b1;

            @(posedge clk);
        end
    endtask

    task automatic clear_accumulators;
        begin
            @(negedge clk);

            drive_idle_io();
            clr_acc_n <= 1'b0;

            @(posedge clk);

            @(negedge clk);

            clr_acc_n <= 1'b1;

            @(posedge clk);
        end
    endtask

    task automatic run_stream_phase;
        begin
            for (int t = 0; t < STREAM_CYCLES; t++) begin
                @(negedge clk);
                drive_stream_inputs(t);
            end
        end
    endtask

    task automatic run_drain_phase;
        begin
            for (int t = 0; t < DRAIN_CYCLES; t++) begin
                @(negedge clk);
                drive_drain_inputs();
            end

            @(negedge clk);
            drive_idle_io();

            repeat (3) @(posedge clk);
        end
    endtask

    // =====================================================
    // INITIALIZE TEST MATRICES
    // =====================================================

    task automatic init_matrices;
        begin
            for (int row = 0; row < N; row++) begin
                for (int k = 0; k < DEPTH; k++) begin
                    A[row][k] = operand_t'(-4 + row + (k % 5));
                end
            end

            for (int k = 0; k < DEPTH; k++) begin
                for (int col = 0; col < N; col++) begin
                    B[k][col] = operand_t'(3 - col + (k % 7));
                end
            end
        end
    endtask

    // =====================================================
    // GOLDEN MODEL
    // =====================================================

    task automatic compute_golden;
        begin
            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    golden[row][col] = '0;

                    for (int k = 0; k < DEPTH; k++) begin
                        golden[row][col] +=
                            accumulator_t'($signed(A[row][k]) * $signed(B[k][col]));
                    end
                end
            end
        end
    endtask

    // =====================================================
    // PRINT HELPERS
    // =====================================================

    task automatic print_golden;
        begin
            $display("\n===== GOLDEN C TILE =====");

            for (int row = 0; row < N; row++) begin
                $write("row %0d: ", row);

                for (int col = 0; col < N; col++) begin
                    $write("%0d ", golden[row][col]);
                end

                $write("\n");
            end
        end
    endtask

    task automatic print_dut_result;
        begin
            $display("\n===== DUT C TILE =====");

            for (int row = 0; row < N; row++) begin
                $write("row %0d: ", row);

                for (int col = 0; col < N; col++) begin
                    $write("%0d ", c[row][col]);
                end

                $write("\n");
            end
        end
    endtask

    // =====================================================
    // CHECK RESULT
    // =====================================================

    task automatic check_result;
        begin
            $display("\n===== SELF CHECK =====");

            for (int row = 0; row < N; row++) begin
                for (int col = 0; col < N; col++) begin
                    if (c[row][col] !== golden[row][col]) begin
                        $display(
                            "FAIL C[%0d][%0d]: DUT=%0d GOLD=%0d",
                            row,
                            col,
                            c[row][col],
                            golden[row][col]
                        );
                        errors++;
                    end else begin
                        $display(
                            "PASS C[%0d][%0d] = %0d",
                            row,
                            col,
                            c[row][col]
                        );
                    end
                end
            end
        end
    endtask

    // =====================================================
    // MAIN TEST
    // =====================================================

    initial begin
        errors = 0;

        init_matrices();
        compute_golden();

        apply_reset();

        // Optional explicit accumulator clear after reset.
        clear_accumulators();

        $display("\n===== STARTING %0dx%0d x %0dx%0d SYSTOLIC ARRAY TEST =====",
                 N, DEPTH, DEPTH, N);

        run_stream_phase();
        run_drain_phase();

        print_golden();
        print_dut_result();

        check_result();

        if (errors == 0)
            $display("\nTEST PASSED");
        else
            $display("\nTEST FAILED: %0d mismatches", errors);

        $finish;
    end

endmodule