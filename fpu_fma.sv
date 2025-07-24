`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2025 10:46:11 AM
// Design Name: 
// Module Name: fpu_fma
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


module fpu_fma (
    input logic clk, rst,
    input logic start,
    input logic [31:0] rs1, rs2, rs3, 
    input logic [1:0] opcode,         
    input logic [2:0] frm,            
    output logic [31:0] rd,     
    output logic flag_nx,      
    output logic done
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        MUL = 2'b01,
        ADD_SUB = 2'b10,
        FINISH = 2'b11
    } state_t;

    state_t state, next_state;

    logic [31:0] mul_result, mul_result_neg;
    logic add0_sub1;
    logic [31:0] addA, addB;
    logic mul_flag_nx, mul_done;
    logic add_sub_flag_nx, add_sub_done;

    fpu_mul mul (
        .clk(clk),
        .rst(rst),
        .start(start && state == IDLE), // Start multiplier only in IDLE state
        .operA_float32(rs1),
        .operB_float32(rs2),
        .frm(frm),
        .result(mul_result),
        .flag_nx(mul_flag_nx),
        .done(mul_done)
    );

    // Negate multiplication result for FNMSUB/FNMADD
    always_comb begin
        mul_result_neg = mul_result;
        if (opcode == 2'b10 || opcode == 2'b11)
            mul_result_neg = {~mul_result[31], mul_result[30:0]};
    end

    // Select add/sub and operands for add_sub
    always_comb begin
        addA = mul_result_neg;
        addB = rs3;
        case (opcode)
            2'b00: add0_sub1 = 1'b0; // fmadd: mul + rs3
            2'b01: add0_sub1 = 1'b1; // fmsub: mul - rs3
            2'b10: add0_sub1 = 1'b0; // fnmsub: -mul + rs3
            2'b11: add0_sub1 = 1'b1; // fnmadd: -mul - rs3
            default: add0_sub1 = 1'b0;
        endcase
    end

    fpu_add_sub add_sub (
        .clk(clk),
        .rst(rst),
        .start(mul_done && state == MUL), // Start adder only after multiplier is done
        .add0_sub1(add0_sub1),
        .operA_float32(addA),
        .operB_float32(addB),
        .frm(frm),
        .result(rd),
        .flag_nx(add_sub_flag_nx),
        .done(add_sub_done)
    );

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        done = 1'b0;
        flag_nx = 1'b0;
        case (state)
            IDLE: begin
                if (start)
                    next_state = MUL;
            end
            MUL: begin
                if (mul_done)
                    next_state = ADD_SUB;
                flag_nx = mul_flag_nx;
            end
            ADD_SUB: begin
                if (add_sub_done)
                    next_state = FINISH;
                flag_nx = add_sub_flag_nx;
            end
            FINISH: begin
                done = 1'b1;
                flag_nx = add_sub_flag_nx; // Use adder flag as final flag
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
