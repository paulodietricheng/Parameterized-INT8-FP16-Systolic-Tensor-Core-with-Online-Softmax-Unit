`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/26/2026 10:04:57 AM
// Design Name: 
// Module Name: tpu_pkg
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


package tpu_pkg;

    // ------------------------------------------------------------
    // Public architectural parameters
    // ------------------------------------------------------------
    localparam N          = 8;
    localparam D_MODEL    = 16;
    localparam OPERAND_W  = 8; // INT8
    localparam ACC_W      = 32; // INT32
    localparam SRAM_WORD_W = 32;

    // ------------------------------------------------------------
    // Systolic Array
    // ------------------------------------------------------------

    // DON'T TOUCH
    
    // Words per SRAM address.
    localparam WPA = SRAM_WORD_W / OPERAND_W;

    // Width of a full vector sent into the operand handler.
    localparam OPERAND_BUS_W = N * OPERAND_W;

    // Address width for dimension indexing.
    localparam DIM_ADDR_W = $clog2(D_MODEL);

    // Systolic latency parameter
    localparam DSP_LAT = 4;

    // Total result latency from first PE token to final valid result.
    localparam RESULT_LAT = 2*N + D_MODEL - 2 + DSP_LAT;


    // Scalar data types
    typedef logic signed [OPERAND_W-1:0] operand_t;
    typedef logic signed [ACC_W-1:0]     accumulator_t;
    typedef logic [SRAM_WORD_W-1:0]      sram_word_t;
    typedef logic [DIM_ADDR_W-1:0]       dim_t;

    // Vector with N operands
    typedef logic [OPERAND_BUS_W-1:0] operand_bus_t;

endpackage
