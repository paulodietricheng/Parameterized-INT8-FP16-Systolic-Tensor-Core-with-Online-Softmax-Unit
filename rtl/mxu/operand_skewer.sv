`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 02:24:39 PM
// Design Name: 
// Module Name: operand_skewer
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

import tpu_pkg::*;

module operand_skewer(
    input logic clk, rst_n,
    
    // From Operand Handler
    input operand_t a_j [0:N-1],
    input operand_t b_i [0:N-1],
    input logic d_valid,    
    
    // To systolic array
    output operand_t a_j_skewed [0:N-1],
    output operand_t b_i_skewed [0:N-1],
    
    // To systolic Control
    output logic pe00_valid
);
    
    // Lane 0 has zero delay.
    always_comb begin
        if (!rst_n) begin
            a_j_skewed[0] = '0;
            b_i_skewed[0] = '0;
        end else begin
            a_j_skewed[0] = a_j[0];
            b_i_skewed[0] = b_i[0];
        end
    end
    
    assign pe00_valid = rst_n && d_valid;

    generate
        genvar lane;

        for (lane = 1; lane < N; lane++) begin : GEN_SKEW_LANE

            // Lane `lane` has exactly `lane` registers.
            operand_t a_shift_regs [0:lane-1];
            operand_t b_shift_regs [0:lane-1];

            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    for (int d = 0; d < lane; d++) begin
                        a_shift_regs[d] <= '0;
                        b_shift_regs[d] <= '0;
                    end
                end else begin
                    a_shift_regs[0] <= a_j[lane];
                    b_shift_regs[0] <= b_i[lane];

                    for (int d = 1; d < lane; d++) begin
                        a_shift_regs[d] <= a_shift_regs[d-1];
                        b_shift_regs[d] <= b_shift_regs[d-1];
                    end
                end
            end

            assign a_j_skewed[lane] = a_shift_regs[lane-1];
            assign b_i_skewed[lane] = b_shift_regs[lane-1];
            
        end
    endgenerate
    
endmodule
