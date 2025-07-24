`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2025 03:28:31 PM
// Design Name: 
// Module Name: mul_2cycle
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


module mul_2cycle(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [31:0] operA,
    input  logic [31:0] operB,
    input  logic [2:0] func3,
    output logic [31:0] result,
    output logic [63:0] result_64_out, // New output for full 64-bit result
    output logic overflow,
    output logic done
);
    typedef enum logic [2:0] {IDLE, ABS_CALC, PRE_MID_CALC, LO_MID_HI_CALC, RESULT_CALC, DONE} state_t;
    state_t state, next_state;

    logic [31:0] a_reg, b_reg;
    logic [31:0] a_reg_abs, b_reg_abs;
    logic [63:0] a_hi_b_lo;
    logic [63:0] b_hi_a_lo;
    logic [63:0] lo, mid, hi;
    logic [63:0] result_64;
    logic [63:0] result_64_abs;

    logic a_b_en;
    logic abs_en;
    logic mid_pre_reg_en;
    logic lo_mid_hi_en;
    logic result_64_abs_en;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            a_reg_abs <= 32'd0;
            b_reg_abs <= 32'd0;
        end else if (abs_en) begin
            case (func3[1:0])
                2'b00, 2'b01: begin // MUL, MULH
                    a_reg_abs <= a_reg[31] ? ~a_reg + 1 : a_reg;
                    b_reg_abs <= b_reg[31] ? ~b_reg + 1 : b_reg;
                end
                2'b10: begin // MULHSU
                    a_reg_abs <= a_reg[31] ? ~a_reg + 1 : a_reg;
                    b_reg_abs <= b_reg;
                end
                2'b11: begin // MULHU
                    a_reg_abs <= a_reg;
                    b_reg_abs <= b_reg;
                end
                default: begin
                    a_reg_abs <= 32'd0;
                    b_reg_abs <= 32'd0;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            a_reg <= 32'd0;
            b_reg <= 32'd0;
            a_hi_b_lo <= 64'd0;
            b_hi_a_lo <= 64'd0;
            lo <= 64'd0;
            mid <= 64'd0;
            hi <= 64'd0;
            result_64_abs <= 64'd0;
        end else begin
            state <= next_state;
            if (a_b_en) a_reg <= operA;
            if (a_b_en) b_reg <= operB;
            if (lo_mid_hi_en) lo <= a_reg_abs[15:0] * b_reg_abs[15:0];
            if (mid_pre_reg_en) a_hi_b_lo <= a_reg_abs[31:16] * b_reg_abs[15:0];
            if (mid_pre_reg_en) b_hi_a_lo <= a_reg_abs[15:0] * b_reg_abs[31:16];
            if (lo_mid_hi_en) hi <= a_reg_abs[31:16] * b_reg_abs[31:16];
            if (lo_mid_hi_en) mid <= a_hi_b_lo + b_hi_a_lo;
            if (result_64_abs_en) result_64_abs <= (hi << 32) + (mid << 16) + lo;
        end
    end

    always_comb begin
        done = 1'b0;
        a_b_en = 1'b0;
        mid_pre_reg_en = 1'b0;
        lo_mid_hi_en = 1'b0;
        result_64_abs_en = 1'b0;
        abs_en = 1'b0;
        case (state)
            IDLE: begin
                a_b_en = 1'b1;
                if (start) next_state = ABS_CALC;
                else next_state = IDLE;
            end
            ABS_CALC: begin
                abs_en = 1'b1;
                next_state = PRE_MID_CALC;
            end
            PRE_MID_CALC: begin
                mid_pre_reg_en = 1'b1;
                next_state = LO_MID_HI_CALC;
            end
            LO_MID_HI_CALC: begin
                lo_mid_hi_en = 1'b1;
                next_state = RESULT_CALC;
            end
            RESULT_CALC: begin
                result_64_abs_en = 1'b1;
                next_state = DONE;
            end
            DONE: begin
                done = 1'b1;
                if (!start) next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        overflow = 1'b0;
        if (func3[1:0] == 2'b00 || func3[1:0] == 2'b01) begin // MUL, MULH
            if ((a_reg[31] == b_reg[31]) && (result_64_abs[63] != a_reg[31]))
                overflow = 1'b1;
        end else if (func3[1:0] == 2'b10 || func3[1:0] == 2'b11) begin // MULHSU, MULHU
            if (result_64_abs[63] != 1'b0)
                overflow = 1'b1;
        end

        case (func3[1:0])
            2'b00, 2'b01: begin // MUL, MULH
                if (a_reg[31] ^ b_reg[31])
                    result_64 = ~result_64_abs + 1;
                else
                    result_64 = result_64_abs;
            end
            2'b10: begin // MULHSU
                if (a_reg[31])
                    result_64 = ~result_64_abs + 1;
                else
                    result_64 = result_64_abs;
            end
            2'b11: begin // MULHU
                result_64 = result_64_abs;
            end
            default: begin
                result_64 = 64'd0;
            end
        endcase

        // Output selection
        result = func3[1:0] ? result_64[63:32] : result_64[31:0];
        result_64_out = (func3[2] == 1'b1) ? result_64 : 64'd0; // Full 64-bit output for fpu_mul
    end

endmodule

