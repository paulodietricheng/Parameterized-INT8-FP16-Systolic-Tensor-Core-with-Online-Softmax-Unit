`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 03:14:37 PM
// Design Name: 
// Module Name: systolic_controller
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

module mxu_control(
    input  logic clk, rst_n,

    // From/to Central control
    input  logic start,
    output logic busy,
    output logic done,    
    
    // From operand skewer
    input  logic pe00_valid,

    // To systolic array
    output logic array_en,
    output logic clr_acc_n,

    // To operand_handler
    output dim_t dim_idx,
    output logic dim_valid
);

    logic [RESULT_LAT-1:0] result_ready;

    // Controller state type
    typedef enum logic [2:0] {
        m_IDLE,
        m_CLEAR,
        m_STREAM,
        m_DRAIN,
        m_DONE
    } mxu_state_t;

    mxu_state_t curr_state;

    logic token_seen;
    logic first_pe_token;
    
    assign first_pe_token = pe00_valid && !token_seen && ((curr_state == m_STREAM) || (curr_state == m_DRAIN));

    // RESULT READY SHIFT PIPE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_ready <= '0;
            token_seen <= 1'b0;
        end
        else if (curr_state == m_IDLE || curr_state == m_CLEAR || curr_state == m_DONE) begin
            result_ready <= '0;
            token_seen <= 1'b0;
        end
        else if (curr_state == m_STREAM || curr_state == m_DRAIN) begin
            result_ready <= {result_ready[RESULT_LAT-2:0], first_pe_token};
            token_seen <= 1'b1;
        end
    end

    // FSM Controller
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= m_IDLE;

            array_en  <= 1'b0;
            clr_acc_n <= 1'b1;
            done      <= 1'b0;
            busy      <= 1'b0;
            dim_valid <= 1'b0;
            dim_idx   <= '0;
        end
        else begin
        
            // safe defaults
            array_en  <= 1'b0;
            clr_acc_n <= 1'b1;
            done      <= 1'b0;
            busy      <= 1'b0;
            dim_valid <= 1'b0;
            dim_idx   <= dim_idx;

            case (curr_state)

                m_IDLE : begin
                    dim_idx <= '0;
                    curr_state <= start ? m_CLEAR : m_IDLE;
                end

                m_CLEAR : begin
                    busy      <= 1'b1;
                    clr_acc_n <= 1'b0;
                    dim_idx   <= '0;

                    curr_state <= m_STREAM;
                end

                m_STREAM : begin
                    busy      <= 1'b1;
                    array_en  <= 1'b1;
                    clr_acc_n <= 1'b1;
                    dim_valid <= 1'b1;

                    if (dim_idx == D_MODEL-1) begin
                        curr_state <= m_DRAIN;
                    end
                    else begin
                        dim_idx <= dim_idx + 1'b1;
                    end
                end

                m_DRAIN : begin
                    busy      <= 1'b1;
                    array_en  <= 1'b1;
                    clr_acc_n <= 1'b1;
                    dim_valid <= 1'b0;
                    dim_idx   <= '0;

                    curr_state <= (result_ready[RESULT_LAT-1]) ? m_DONE : m_DRAIN;
                end

                m_DONE : begin
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    array_en  <= 1'b0;
                    clr_acc_n <= 1'b1;
                    dim_valid <= 1'b0;
                    dim_idx   <= '0;

                    curr_state <= m_IDLE;
                end

                default : curr_state <= m_IDLE;
            endcase
        end
    end

endmodule
