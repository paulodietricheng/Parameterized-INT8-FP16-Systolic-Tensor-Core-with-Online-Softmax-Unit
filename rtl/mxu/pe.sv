`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2026 04:25:34 PM
// Design Name: 
// Module Name: pe
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

module pe(
    input  logic clk, rst_n, clr_acc_n,

    input  operand_t in_a, in_b,
    input logic array_en,
    
    output operand_t out_a, out_b,   
    output accumulator_t c
);

    // Registers
    operand_t areg, breg;
    always_ff @(posedge clk or negedge clr_acc_n or negedge rst_n) begin
        if (!clr_acc_n || !rst_n) begin
            c <= '0;
            areg <= '0;
            breg <= '0;
        end else if (array_en) begin
            c  <= c + (areg * breg);  
            areg <= in_a;
            breg <= in_b;
        end
    end
    
    assign out_a = areg;
    assign out_b = breg;
    
endmodule
