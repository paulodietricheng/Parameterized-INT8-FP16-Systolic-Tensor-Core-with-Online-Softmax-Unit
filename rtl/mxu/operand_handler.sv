`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/24/2026 09:54:48 AM
// Design Name: 
// Module Name: operand_handler
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

module operand_handler (
    input  logic clk, rst_n,
    
    // From MXU Control:
    input  dim_t dim_idx,
    input  logic dim_valid,
    
    // From SRAM Word Packer
    input  operand_bus_t in_a,
    input  operand_bus_t in_b,
    
    // To SRAM Controller
    output dim_t dim_to_fetch,
    
    // To operand skewer
    output operand_t a_j [0:N-1],
    output operand_t b_i [0:N-1],
    output logic d_valid
);

    // Generate dimensional base address
    assign dim_to_fetch = dim_idx;
    
    // Assert the validity of the data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_valid <= 1'b0;
        end else begin
            d_valid <= dim_valid;
        end
    end
    
    // slice incoming vectors / output 0 for invalid dimentions
    generate
    genvar lane;
        for (lane = 0; lane < N; lane++) begin : GEN_SLICER
            always_comb begin
                if (d_valid) begin
                    a_j[lane] = in_a [8*lane + 7 : 8*lane];
                    b_i[lane] = in_b [8*lane + 7 : 8*lane];
                end else begin
                    a_j[lane] = '0;
                    b_i[lane] = '0;
                end   
            end
        end        
    endgenerate

endmodule
