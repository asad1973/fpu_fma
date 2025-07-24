`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2025 07:48:37 PM
// Design Name: 
// Module Name: fpu_mul
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

module fpu_mul(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [31:0] operA_float32,
    input logic [31:0] operB_float32,
    input logic [2:0] frm, 
    output logic [31:0] result,
    output logic flag_nx,
    output logic done
);
    logic [31:0] operA_reg, operB_reg;
    logic start_reg;
    logic [2:0] frm_reg;
    
    logic [31:0] result_reg;
    logic done_reg;
    logic flag_nx_reg;

    // extract sign, exponent, mantissa
    logic sA, sB, sR;
    logic [7:0] eA, eB;
    logic [8:0] eR, eR_reg;
    logic [23:0] mA, mB;
    logic [47:0] mR_full;
    logic [23:0] mR;
    logic [5:0] zero_count;

    // rounding signals
    logic guard, round_bit, sticky;
    logic round_up;
    logic [23:0] mR_rounded;

    // mul_2cycle signals
    logic [31:0] operA_int, operB_int;
    logic [63:0] result_64;
    logic overflow, mul_done;
    logic [2:0] func3;

    // state machine 
    typedef enum logic [1:0] {IDLE, MUL_WAIT, NOfrmALIZE, DONE} state_t;
    state_t state, next_state;

    mul_2cycle multiplier (
        .clk(clk),
        .rst(rst),
        .start(start_reg),
        .operA(operA_int),
        .operB(operB_int),
        .func3(func3),
        .result(), 
        .result_64_out(result_64), // 64-bit output
        .overflow(overflow),
        .done(mul_done)
    );

    // r1
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            operA_reg <= 32'd0;
            operB_reg <= 32'd0;
            start_reg <= 1'b0;
            frm_reg <= 3'b000;
        end else begin
            operA_reg <= operA_float32;
            operB_reg <= operB_float32;
            start_reg <= start;
            frm_reg <= frm;
        end
    end

    // extract components
    always_comb begin
        sA = operA_reg[31];
        sB = operB_reg[31];
        eA = operA_reg[30:23];
        eB = operB_reg[30:23];
        mA = {1'b1, operA_reg[22:0]}; // implicit leading 1
        mB = {1'b1, operB_reg[22:0]};
        sR = sA ^ sB;
        eR = eA + eB - 8'd127; // exponent 
        operA_int = {8'b0, mA}; // pad mantissa to 32 bits
        operB_int = {8'b0, mB};
        func3 = 3'b111; // mulhu with full 64-bit output
    end

    // state machine
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            eR_reg <= 9'd0;
            mR_full <= 48'd0;
            mR <= 24'd0;
            flag_nx_reg <= 1'b0;
        end else begin
            state <= next_state;
            if (state == MUL_WAIT && mul_done) begin
                mR_full <= result_64[47:0]; // extract 48-bit mantissa product
                eR_reg <= eR;
            end else if (state == NOfrmALIZE) begin
                if (mR_full[47]) begin
                    mR_full <= mR_full >> 1; // right shift if leading bit is 1
                    eR_reg <= eR_reg + 1;
                end else begin
                    zero_count = 0;
                    for (int i = 46; i >= 0; i = i - 1) begin
                        if (mR_full[i]) begin
                            zero_count = 46 - i;
                            break;
                        end
                    end
                    mR_full <= mR_full << zero_count;
                    eR_reg <= eR_reg - zero_count;
                end

                // compute rounding bits
                guard = mR_full[22];
                round_bit = mR_full[21];
                sticky = |mR_full[20:0];
                flag_nx_reg = sticky;

                // rounding logic
                case (frm_reg)
                    3'b000: // rne
                        round_up = guard && (round_bit || sticky || (!round_bit && !sticky && mR_full[23]));
                    3'b001: // rtz
                        round_up = 1'b0;
                    3'b010: // rdn
                        round_up = sR && guard && (round_bit || sticky);
                    3'b011: // rup
                        round_up = !sR && guard && (round_bit || sticky);
                    3'b100: // frmm
                        round_up = guard && (round_bit || sticky);
                    default: // default to rtz
                        round_up = 1'b0;
                endcase

                // apply rounding
                mR_rounded = mR_full[46:23] + (round_up ? 24'd1 : 24'd0);
                if (mR_rounded[23] && round_up) begin // rounding overflow
                    mR <= 24'd0; // mantissa becomes 0
                    eR_reg <= eR_reg + 1; // increment exponent
                end else begin
                    mR <= mR_rounded;
                end
            end
        end
    end

    always_comb begin
        next_state = state;
        done_reg = 1'b0;
        case (state)
            IDLE: begin
                if (start_reg) next_state = MUL_WAIT;
            end
            MUL_WAIT: begin
                if (mul_done) next_state = NOfrmALIZE;
            end
            NOfrmALIZE: begin
                next_state = DONE;
            end
            DONE: begin
                done_reg = 1'b1;
                if (!start_reg) next_state = IDLE;
            end
        endcase
    end

    // r2
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            result_reg <= 32'd0;
            done <= 1'b0;
            flag_nx <= 1'b0;
        end else begin
            result_reg <= {sR, eR_reg[7:0], mR[22:0]};
            done <= done_reg;
            flag_nx <= flag_nx_reg;
        end
    end

    assign result = result_reg;

endmodule