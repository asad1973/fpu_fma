`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2025 12:22:40 PM
// Design Name: 
// Module Name: fpu_mul_div_tb
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


module fpu_mul_tb;

    // Inputs
    logic clk;
    logic rst;
    logic start;
    logic [2:0]frm; 
    logic [31:0] operA_float32;
    logic [31:0] operB_float32;

    // Outputs
    logic [31:0] result;
    logic flag_nx;

    logic done;

    // Instantiate the Unit Under Test (UUT)
    fpu_mul uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .operA_float32(operA_float32),
        .operB_float32(operB_float32),
        .frm(frm),
        .result(result),
        .done(done),
        .flag_nx(flag_nx)

        
    );

    // Clock generation: 10 ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test procedure
    initial begin
        // Initialize inputs
        rst = 0;
        start = 0;
        operA_float32 = 32'd0;
        operB_float32 = 32'd0;
        frm = 3'b000;

        // Reset
        #10;
        rst = 1;
        #10;

        // Test Case 1: 2.5 * 3.0 = 7.5
        $display("Test Case 1: 2.5 * 3.0");
        operA_float32 = 32'h40200000; // 2.5
        operB_float32 = 32'h40400000; // 3.0
        frm = 3'b000;
        start = 1;
        #10;
        start = 0;
        wait (done == 1);
        $display("Input A: %b (2.5)", operA_float32);
        $display("Input B: %b (3.0)", operB_float32);
        $display("Result: %b (Expected: 7.5)", result);
        #20;

        // Test Case 2: (-4.0) * 2.0 = -8.0
        $display("\nTest Case 2: -4.0 * 2.0");
        operA_float32 = 32'hc0800000; // -4.0
        operB_float32 = 32'h40000000; // 2.0
        frm = 3'b000;
        start = 1;
        #10;
        start = 0;
        wait (done == 1);
        $display("Input A: %b (-4.0)", operA_float32);
        $display("Input B: %b (2.0)", operB_float32);
        $display("Result: %b (Expected: -8.0)", result);
        #20;
        
        // Test Case 3: (-4.0) * (-4.0) = 16.0
        $display("\nTest Case 2: -4.0 * -4.0");
        operA_float32 = 32'hc0800000; // -4.0
        operB_float32 = 32'hc0800000; // -4.0
        frm = 3'b000;
        start = 1;
        #10;
        start = 0;
        wait (done == 1);
        $display("Input A: %b (-4.0)", operA_float32);
        $display("Input B: %b (-4.0)", operB_float32);
        $display("Result: %b (Expected: 16.0)", result);
        #20;


        // End simulation
        $display("\nSimulation completed.");
        $finish;
    end

endmodule
