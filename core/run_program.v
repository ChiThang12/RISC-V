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
    
    integer cycle_count;
    reg program_finished;
    
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
    
    // Clock generation: 10ns period (100MHz)
    initial clock = 0;
    always #5 clock = ~clock;
    
    // Cycle counting
    always @(posedge clock) begin
        if (!reset) begin
            cycle_count = cycle_count + 1;
        end
    end
    
    // Detect program end: PC stops changing (infinite loop)
    reg [31:0] prev_pc;
    integer stable_cycles;
    
    always @(posedge clock) begin
        if (!reset) begin
            if (pc_current == prev_pc) begin
                // PC not changing - likely in halt loop
                stable_cycles = stable_cycles + 1;
                if (stable_cycles >= 10 && !program_finished) begin
                    program_finished = 1;
                    print_results();
                    $finish;
                end
            end else begin
                stable_cycles = 0;
            end
            prev_pc = pc_current;
        end
    end
    
    // Main test sequence
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
        
        cycle_count = 0;
        stable_cycles = 0;
        program_finished = 0;
        prev_pc = 0;
        
        // Reset sequence
        reset = 1;
        #15;
        reset = 0;
        
        $display("\n========================================");
        $display("   RISC-V C Program Execution");
        $display("========================================\n");
        
        // Wait for program to finish (max 5000 cycles)
        #50000;
        
        // If still running after timeout
        if (!program_finished) begin
            $display("\n⚠ WARNING: Program timeout after %0d cycles", cycle_count);
            print_results();
        end
        
        $finish;
    end
    
    // Task to print results
    task print_results;
        integer i;
        reg [31:0] return_value;
        begin
            return_value = dut.register_file.registers[10];  // a0 register
            
            $display("========================================");
            $display("      Program Execution Complete");
            $display("========================================\n");
            
            // Main result
            $display("=== PROGRAM RESULT ===");
            $display("Return Value (x10/a0): %0d (0x%h)", return_value, return_value);
            $display("");
            
            // Register dump
            $display("=== REGISTER FILE ===");
            $display("Reg  | Decimal       | Hex        | Binary");
            $display("-----|---------------|------------|----------------------------------");
            
            // Show important registers
            for (i = 0; i < 32; i = i + 1) begin
                if (dut.register_file.registers[i] != 0 || i == 10) begin
                    $display("x%-3d | %13d | 0x%08h | %032b", 
                             i, 
                             dut.register_file.registers[i],
                             dut.register_file.registers[i],
                             dut.register_file.registers[i]);
                end
            end
            
            // Execution statistics
            $display("");
            $display("=== EXECUTION STATISTICS ===");
            $display("Total Cycles:    %0d", cycle_count);
            $display("Final PC:        0x%08h", pc_current);
            $display("");
            
            $display("========================================\n");
        end
    endtask

endmodule
