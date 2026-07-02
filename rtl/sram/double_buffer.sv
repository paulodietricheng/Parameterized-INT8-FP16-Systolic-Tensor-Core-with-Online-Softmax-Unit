`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.07.2026 16:08:36
// Design Name: 
// Module Name: double_buffer
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

module double_buffer(
    input clk,
    
    // DMA wires
    input sram_word_t din_a,
    input sram_word_t din_b,
    
    // SRAM controller
    input  logic read_buf,     // 0 = reads Buf0, 1 = reads Buf1
    input  logic [ADDR_W-1:0] addr_a,
    input  logic [ADDR_W-1:0] addr_b,
    
    // To Word Packer
    output sram_word_t dout_a,
    output sram_word_t dout_b
);

    // intermediate mux wires
    sram_word_t buf0_dout_a;
    sram_word_t buf0_dout_b;
    sram_word_t buf1_dout_a;
    sram_word_t buf1_dout_b;

    bram U_BUF0 (
        .clk   (clk),
        .din_a (din_a),
        .addr_a(addr_a),
        .we_a  (read_buf),
        .dout_a(buf0_dout_a),
        .din_b (din_b),
        .addr_b(addr_b),
        .we_b  (read_buf),
        .dout_b(buf0_dout_b)
    );
    
    bram U_BUF1 (
        .clk   (clk),
        .din_a (din_a),
        .addr_a(addr_a),
        .we_a  (~read_buf),
        .dout_a(buf1_dout_a),
        .din_b (din_b),
        .addr_b(addr_b),
        .we_b  (~read_buf),
        .dout_b(buf1_dout_b)
    );
    
    always_comb begin
        if (read_buf) begin
            dout_a = buf1_dout_a;
            dout_b = buf1_dout_b;
        end else begin
            dout_a = buf0_dout_a;
            dout_b = buf0_dout_b;
        end
    end
    
endmodule
