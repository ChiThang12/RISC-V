`timescale 1ns/1ps

module testbench;
    reg clock;
    reg reset;
    wire [31:0] pc_current;
    wire [31:0] alu_result;
    wire [31:0] mem_out;
    
    datapath dut (
        .clock(clock),
        .reset(reset),
        .pc_current(pc_current),
        .alu_result_debug(alu_result),
        .mem_out_debug(mem_out)
    );
    
    initial clock = 0;
    always #5 clock = ~clock;
    
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
        
        reset = 1;
        #15 reset = 0;
        #5000;
        
        $display("\n=== Done ===");
        $display("PC: 0x%h", pc_current);
        $display("ALU: 0x%h", alu_result);
        $finish;
    end
    
    always @(posedge clock) begin
        if (!reset) begin
            $display("T=%0t | PC=0x%h | ALU=0x%h", $time, pc_current, alu_result);
        end
    end
endmodule
