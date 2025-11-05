`timescale 1ns/1ps
`include "datapath.v"
module testbench;
    reg clock;
    reg reset;
    wire [31:0] pc_current;
    wire [31:0] instruction_current;
    wire [31:0] alu_result;
    wire [31:0] mem_out;
    wire branch_taken;
    wire [31:0] branch_target;
    wire stall;
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    
    // Statistics
    integer cycle_count;
    integer branch_count;
    integer stall_count;
    
    datapath dut (
        .clock(clock),
        .reset(reset),
        .pc_current(pc_current),
        .instruction_current(instruction_current),
        .alu_result_debug(alu_result),
        .mem_out_debug(mem_out),
        .branch_taken_debug(branch_taken),
        .branch_target_debug(branch_target),
        .stall_debug(stall),
        .forward_a_debug(forward_a),
        .forward_b_debug(forward_b)
    );
    
    // Clock generation
    initial clock = 0;
    always #5 clock = ~clock;
    
    // Branch counting
    always @(posedge clock) begin
        if (!reset && branch_taken) begin
            branch_count = branch_count + 1;
        end
    end
    
    // Stall counting
    always @(posedge clock) begin
        if (!reset && stall) begin
            stall_count = stall_count + 1;
        end
    end
    
    // Cycle counting
    always @(posedge clock) begin
        if (!reset) begin
            cycle_count = cycle_count + 1;
        end
    end
    
    // Main test
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
        
        // Initialize counters
        cycle_count = 0;
        branch_count = 0;
        stall_count = 0;
        
        // Reset
        reset = 1;
        #15 reset = 0;
        
        // Run for sufficient cycles
        #2000;
        
        $display("\n========================================");
        $display("       TESTBENCH COMPLETED");
        $display("========================================");
        
        // Display register file state
        $display("\n=== REGISTER FILE FINAL STATE ===");
        $display("Reg | Hex Value  | Decimal | Description");
        $display("----|------------|---------|---------------------------");
        $display("x0  | 0x%h |   %5d | Zero (always 0)", 
                 dut.register_file.registers[0], 
                 dut.register_file.registers[0]);
        $display("x1  | 0x%h |   %5d | Sum result", 
                 dut.register_file.registers[1], 
                 dut.register_file.registers[1]);
        $display("x2  | 0x%h |   %5d | Counter (should be 10)", 
                 dut.register_file.registers[2], 
                 dut.register_file.registers[2]);
        $display("x3  | 0x%h |   %5d | Limit", 
                 dut.register_file.registers[3], 
                 dut.register_file.registers[3]);
        $display("x10 | 0x%h |   %5d | Final result (a0)", 
                 dut.register_file.registers[10], 
                 dut.register_file.registers[10]);
        
        // Display statistics
        $display("\n=== PIPELINE STATISTICS ===");
        $display("Total Cycles: %0d", cycle_count);
        $display("Branch Count: %0d", branch_count);
        $display("Loop Iterations: %0d (branches + 1)", branch_count + 1);
        $display("Stall Count: %0d", stall_count);
        $display("Final PC: 0x%h", pc_current);
        
        // Verification
        $display("\n=== TEST VERIFICATION ===");
        
        // Check x1 (sum)
        if (dut.register_file.registers[1] == 32'd45)
            $display("✓ PASS: x1 (sum) = 45 as expected");
        else
            $display("✗ FAIL: x1 (sum) = %0d (expected 45)", 
                     dut.register_file.registers[1]);
        
        // Check x2 (counter)
        if (dut.register_file.registers[2] == 32'd10)
            $display("✓ PASS: x2 (counter) = 10 as expected");
        else
            $display("✗ FAIL: x2 (counter) = %0d (expected 10)", 
                     dut.register_file.registers[2]);
        
        // Check x3 (limit)
        if (dut.register_file.registers[3] == 32'd10)
            $display("✓ PASS: x3 (limit) = 10 as expected");
        else
            $display("✗ FAIL: x3 (limit) = %0d (expected 10)", 
                     dut.register_file.registers[3]);
        
        // Check x10 (result)
        if (dut.register_file.registers[10] == 32'd45)
            $display("✓ PASS: x10 (result) = 45 as expected");
        else
            $display("✗ FAIL: x10 (result) = %0d (expected 45)", 
                     dut.register_file.registers[10]);
        
        // FIXED: Check loop iterations (branches + 1)
        // Loop from 1 to 9: 9 iterations = 8 branches + 1 exit
        if (branch_count == 8)
            $display("✓ PASS: Loop executed 9 iterations (8 branches + 1 exit)");
        else
            $display("✗ FAIL: %0d branches taken (expected 8 for 9 iterations)", 
                     branch_count);
        
        // Performance analysis
        $display("\n=== PERFORMANCE ANALYSIS ===");
        $display("Expected Instructions:");
        $display("  - Setup: 3 instructions (init x1, x2, x3)");
        $display("  - Loop body: 3 instructions × 9 iterations = 27");
        $display("  - Cleanup: 2 instructions (move to x10, nop)");
        $display("  - Total: 3 + 27 + 2 = 32 instructions");
        
        $display("Actual Execution:");
        $display("  - Cycles: %0d", cycle_count);
        $display("  - CPI: %.2f", cycle_count / 32.0);
        $display("  - Branch penalty: ~%0d cycles", branch_count * 2);
        $display("  - Stalls: %0d cycles", stall_count);
        
        if (cycle_count / 32.0 < 1.5)
            $display("  ✓ Excellent efficiency (CPI < 1.5)");
        else if (cycle_count / 32.0 < 2.5)
            $display("  ✓ Good efficiency (CPI < 2.5)");
        else if (cycle_count / 32.0 < 3.0)
            $display("  ⚠ Acceptable efficiency (CPI < 3.0)");
        else
            $display("  ✗ Poor efficiency (CPI >= 3.0)");
        
        $display("========================================");
        $display("       TESTBENCH COMPLETED");
        $display("========================================");
        
        $finish;
    end
    
    // Monitor execution
    always @(posedge clock) begin
        if (!reset) begin
            $display("T=%0t | PC=0x%h | Instr=0x%h | ALU=0x%h | Branch=%b | Stall=%b | FwdA=%b FwdB=%b", 
                     $time, pc_current, instruction_current, alu_result, 
                     branch_taken, stall, forward_a, forward_b);
        end
    end
endmodule