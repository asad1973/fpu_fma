`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2025 11:37:13 AM
// Design Name: 
// Module Name: fma_unit_tb
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


module fpu_fma_tb;

    // Inputs
    logic clk;
    logic rst;
    logic start;
    logic [31:0] rs1, rs2, rs3;
    logic [1:0] opcode;
    logic [2:0] frm;
    
    // Outputs
    logic [31:0] rd;
    logic flag_nx;
    logic done;

    // Instantiate the fpu_fma module
    fpu_fma dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .opcode(opcode),
        .frm(frm),
        .rd(rd),
        .flag_nx(flag_nx),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Test procedure
    initial begin
        // Initialize inputs
        rst = 0;
        start = 0;
        rs1 = 32'h0;
        rs2 = 32'h0;
        rs3 = 32'h0;
        opcode = 2'b00;
        frm = 3'b000; // RNE (Round to Nearest, Even)

        // Reset
        #10;
        rst = 1;
        #10;

        // Test Case 1: FMADD (2.0 * 3.0 + 4.0 = 10.0)
        $display("Test Case 1: FMADD (2.0 * 3.0 + 4.0)");
        rs1 = 32'h40000000; // 2.0
        rs2 = 32'h40400000; // 3.0
        rs3 = 32'h40800000; // 4.0
        opcode = 2'b00; // FMADD
        start = 1;
        #10;
        start = 0;

        // Wait for done
        wait(done);
        #10;
        if (rd == 32'h41200000 && flag_nx == 0) // Expected: 10.0
            $display("Test Case 1 PASSED: Result = %h (10.0), flag_nx = %b", rd, flag_nx);
        else
            $display("Test Case 1 FAILED: Result = %h, Expected = 41200000, flag_nx = %b", rd, flag_nx);

        // End simulation
        #10;
        $display("Simulation completed.");
        $finish;
    end

endmodule






