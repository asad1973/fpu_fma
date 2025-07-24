`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/09/2025 04:07:44 PM
// Design Name: 
// Module Name: fpu_add_sub
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


module fpu_add_sub(
    input  logic clk, rst, start,
    input  logic add0_sub1,
    input  logic [31:0] operA_float32,
    input  logic [31:0] operB_float32,
    input  logic [2:0] frm,           
    output logic [31:0] result,
    output logic flag_nx, done
);

    logic [31:0] operA_float32_reg, operB_float32_reg;
    logic operABreg_en;

    logic sA, sB, sR;
    logic [7:0] eA, eB, eR, eR_combout;
    logic [31:0] mA, mB, mR, mR_reg, mR_final;
    logic cout, cout_reg;
    logic [7:0] exp_diff, abs_exp_diff;
    logic [4:0] zero_count;

    logic [23:0] mantissa_rounded;
    logic guard, round, sticky;
    logic round_up;

    typedef enum logic [2:0] {IDLE, SGN_EXP, MANT, RENORM, DONE} state_t;
    state_t state, next_state;

    always_comb begin
        done = 1'b0;
        operABreg_en = 1'b0;
        case (state)
            // State transitions
            IDLE: begin
                operABreg_en = 1'b1;
                if (start) next_state = SGN_EXP;
                else next_state = IDLE;
            end
            SGN_EXP: next_state = MANT;
            MANT: next_state = RENORM;
            RENORM: next_state = DONE;
            DONE: begin
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

    always_ff @ (posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            operA_float32_reg <= 32'h00000000;
            operB_float32_reg <= 32'h00000000;
        end else begin
            state <= next_state;
            if (operABreg_en) begin
                operA_float32_reg <= operA_float32;
                operB_float32_reg <= operB_float32;
            end
        end
    end

    // Sign and exponent logic
    always_comb begin
        eA = operA_float32_reg[30:23];
        eB = operB_float32_reg[30:23];
        sA = operA_float32_reg[31];
        sB = operB_float32_reg[31] ^ add0_sub1;
        mA = {1'b1, operA_float32_reg[22:0], 8'b0};
        mB = {1'b1, operB_float32_reg[22:0], 8'b0};

        if(eA > eB) begin
            eR_combout = eA;
            sR = sA;
        end else begin 
            eR_combout = eB;
            sR = sB;
            if(eA == eB) begin
                if(mA > mB)
                    sR = sA;
                else
                    sR = sB;
            end
        end
        exp_diff = eA - eB;
    end

    // Register abs_exp_diff
    always_ff @(posedge clk or negedge rst) begin 
        if(!rst) abs_exp_diff <= '0;
        else abs_exp_diff <= exp_diff[7] ? ~exp_diff + 1'b1 : exp_diff;
    end

    // Mantissa add/sub
    always_comb begin
        if(sA ^ sB) begin
            if(eA > eB) {cout, mR} = mA - (mB >> abs_exp_diff);
            else        {cout, mR} = mB - (mA >> abs_exp_diff);
            mR = mR[31] ? ~mR + 1'b1 : mR;
        end else begin
            if(eA > eB) {cout, mR} = mA + (mB >> abs_exp_diff);
            else        {cout, mR} = mB + (mA >> abs_exp_diff);
        end
    end

    // Register mR and cout
    always_ff @(posedge clk or negedge rst) begin 
        if(!rst) begin mR_reg <= '0; cout_reg <= '0; end
        else begin mR_reg <= mR; cout_reg <= cout; end
    end

    // Nofrmalize and round
    always_comb begin
        zero_count = 0;
        if(sA ^ sB) begin
            for(int i = 31; i >= 0; i = i - 1) begin
                if(mR_reg[i] == 1) break;
                zero_count = zero_count + 1'b1;
            end
            mR_final = mR_reg << zero_count;
            eR = eR_combout - zero_count;
        end else if (cout_reg) begin
            mR_final = mR_reg >> 1;
            eR = eR_combout + 1;
        end else begin
            mR_final = mR;
            eR = eR_combout;
        end

        guard  = mR_final[7];
        round  = mR_final[6];
        sticky = |mR_final[5:0];

        round_up = 1'b0;
        case (frm)
            3'b000: round_up = guard & (round | sticky | mR_final[0]); // RNE
            3'b001: round_up = 1'b0; // RTZ
            3'b010: round_up = (sR && (guard | round | sticky)); // RDN
            3'b011: round_up = (!sR && (guard | round | sticky)); // RUP
            3'b100: begin
                    if (guard & (round | sticky)) round_up = 1;   //RMM
            end
            default: round_up = 1'b0;
        endcase

        mantissa_rounded = mR_final[31:8] + round_up;
        flag_nx = |mR_final[7:0];
        result = {sR, eR, mantissa_rounded[22:0]};
    end

endmodule







