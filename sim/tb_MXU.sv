`timescale 1ns / 1ps
import tpu_pkg::*;
module tb_MXU;
    // =====================================================
    // Local testbench parameters
    // =====================================================
    localparam int DEPTH = D_MODEL;   // Inner dimension: 8x16 times 16x8
    // Max cycles to wait for `done` before declaring a timeout failure.
    // Stream + drain + some margin, mirroring tb_systolic_array's phase lengths.
    localparam int TIMEOUT_CYCLES = 4 * (DEPTH + 2*N);
    // =====================================================
    // DUT IO
    // =====================================================
    logic clk;
    logic rst_n;
    logic start;
    logic busy;
    logic done;
    operand_bus_t in_a;
    operand_bus_t in_b;
    dim_t dim_to_fetch;
    accumulator_t c [0:N-1][0:N-1];
    // =====================================================
    // DUT
    // =====================================================
    MXU dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .busy         (busy),
        .done         (done),
        .in_a         (in_a),
        .in_b         (in_b),
        .dim_to_fetch (dim_to_fetch),
        .c            (c)
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
    // SRAM MODEL
    // =====================================================
    // operand_handler fetches an entire N-wide column of A and row of B
    // for a given dim_to_fetch (dim_idx). Pack each into an
    // OPERAND_BUS_W-wide word, lane `i` occupying bits [8*i+7:8*i],
    // matching operand_handler's slicer.
    function automatic operand_bus_t pack_a_column(input int k);
        operand_bus_t packed_word;
        begin
            packed_word = '0;
            for (int row = 0; row < N; row++) begin
                packed_word[8*row +: 8] = A[row][k];
            end
            pack_a_column = packed_word;
        end
    endfunction
    function automatic operand_bus_t pack_b_row(input int k);
        operand_bus_t packed_word;
        begin
            packed_word = '0;
            for (int col = 0; col < N; col++) begin
                packed_word[8*col +: 8] = B[k][col];
            end
            pack_b_row = packed_word;
        end
    endfunction
    // Serve whatever dim_to_fetch currently requests. Simulate 1 cycle read BRAM.
    logic [OPERAND_BUS_W-1:0] a_reg, b_reg;
    
    always_ff @(posedge clk) begin
        a_reg <= pack_a_column(dim_to_fetch);
        b_reg <= pack_b_row(dim_to_fetch);
    end
    
    assign in_a = a_reg;
    assign in_b = b_reg;
    // =====================================================
    // DUT IO DRIVE TASKS
    // =====================================================
    task automatic apply_reset;
        begin
            rst_n <= 1'b0;
            start <= 1'b0;
            repeat (3) @(posedge clk);
            rst_n <= 1'b1;
            @(posedge clk);
        end
    endtask
    task automatic pulse_start;
        begin
            @(negedge clk);
            start <= 1'b1;
            @(negedge clk);
            start <= 1'b0;
        end
    endtask
    task automatic wait_for_done;
        int cycle_count;
        begin
            cycle_count = 0;
            while (!done && cycle_count < TIMEOUT_CYCLES) begin
                @(posedge clk);
                cycle_count++;
            end
            if (cycle_count >= TIMEOUT_CYCLES) begin
                $display("\nFAIL: TIMEOUT waiting for done after %0d cycles", cycle_count);
                errors++;
            end
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
    // BUSY/DONE PROTOCOL CHECKS
    // =====================================================
    task automatic check_idle_protocol;
        begin
            if (busy !== 1'b0) begin
                $display("FAIL: busy asserted while idle, before start");
                errors++;
            end
            if (done !== 1'b0) begin
                $display("FAIL: done asserted while idle, before start");
                errors++;
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
        check_idle_protocol();
        $display("\n===== STARTING %0dx%0d x %0dx%0d MXU TEST =====",
                 N, DEPTH, DEPTH, N);
        pulse_start();
        wait_for_done();
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