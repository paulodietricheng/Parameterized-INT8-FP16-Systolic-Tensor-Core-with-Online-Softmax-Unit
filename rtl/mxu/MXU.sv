`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/26/2026 09:55:26 AM
// Design Name: 
// Module Name: MXU
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

module MXU(
    
    input clk, rst_n,
    
    // External signals for MXU control
    input  logic start,
    output logic busy,
    output logic done,   
    
    // External wires for Operand handler
    input  operand_bus_t in_a,
    input  operand_bus_t in_b,
    output dim_t dim_to_fetch,
    
    // External wires for Systolic Array
    output accumulator_t c [0:N-1][0:N-1]
);

    //-----------------------------------
    // mxu control initialization
    //-----------------------------------
    
    // Internal inputs
    logic pe00_valid;
    
    // Internal outputs
    logic array_en;
    logic clr_acc_n;
    dim_t dim_idx;
    logic dim_valid;
    
    mxu_control U_MXU_CTRL (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .busy      (busy),
        .done      (done),
        .pe00_valid(pe00_valid),
        .array_en  (array_en),
        .clr_acc_n (clr_acc_n),
        .dim_idx   (dim_idx),
        .dim_valid (dim_valid)
    );
    
    //-----------------------------------
    // Operand Handler initialization
    //-----------------------------------
      
    // Internal outputs
    operand_t a_j [0:N-1];
    operand_t b_i [0:N-1];
    logic d_valid;  
      
    operand_handler U_OPH (
        .clk      (clk),
        .rst_n    (rst_n),
        .dim_idx  (dim_idx),
        .dim_valid(dim_valid),
        .in_a     (in_a),
        .in_b     (in_b),
        .dim_to_fetch(dim_to_fetch),
        .a_j      (a_j),
        .b_i      (b_i),
        .d_valid  (d_valid)
    );
    
    //---------------------------------
    // Operand Skewer initialization
    //-----------------------------------
    
    // Internal outputs
    operand_t a_j_skewed [0:N-1];
    operand_t b_i_skewed [0:N-1];
    
    operand_skewer U_OPS (
        .clk       (clk),
        .rst_n     (rst_n),
        .a_j       (a_j),
        .b_i       (b_i),
        .d_valid   (d_valid),
        .a_j_skewed(a_j_skewed),
        .b_i_skewed(b_i_skewed),
        .pe00_valid(pe00_valid)
    );
    
    //-----------------------------------
    // Systolic Array initialization
    //-----------------------------------
    
    systolic_array U_SA (
        .clk       (clk),
        .rst_n     (rst_n),
        .array_en  (array_en),
        .clr_acc_n (clr_acc_n),
        .a_j_skewed(a_j_skewed),
        .b_i_skewed(b_i_skewed),
        .c         (c)
    );

endmodule
