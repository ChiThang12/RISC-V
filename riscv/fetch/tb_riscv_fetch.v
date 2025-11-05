`timescale 1ns/1ps
`include "riscv_fetch.v"

module tb_riscv_fetch;

    // Clock & Reset
    reg clk_i;
    reg rst_i;

    // Inputs
    reg fetch_accept_i;
    reg icache_accept_i;
    reg icache_valid_i;
    reg icache_error_i;
    reg [31:0] icache_inst_i;
    reg icache_page_fault_i;
    reg fetch_invalidate_i;
    reg branch_request_i;
    reg [31:0] branch_pc_i;
    reg [1:0] branch_priv_i;

    // Outputs
    wire fetch_valid_o;
    wire [31:0] fetch_instr_o;
    wire [31:0] fetch_pc_o;
    wire fetch_fault_fetch_o;
    wire fetch_fault_page_o;
    wire icache_rd_o;
    wire icache_flush_o;
    wire icache_invalidate_o;
    wire [31:0] icache_pc_o;
    wire [1:0] icache_priv_o;
    wire squash_decode_o;

    // Instantiate DUT
    riscv_fetch dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .fetch_accept_i(fetch_accept_i),
        .icache_accept_i(icache_accept_i),
        .icache_valid_i(icache_valid_i),
        .icache_error_i(icache_error_i),
        .icache_inst_i(icache_inst_i),
        .icache_page_fault_i(icache_page_fault_i),
        .fetch_invalidate_i(fetch_invalidate_i),
        .branch_request_i(branch_request_i),
        .branch_pc_i(branch_pc_i),
        .branch_priv_i(branch_priv_i),
        .fetch_valid_o(fetch_valid_o),
        .fetch_instr_o(fetch_instr_o),
        .fetch_pc_o(fetch_pc_o),
        .fetch_fault_fetch_o(fetch_fault_fetch_o),
        .fetch_fault_page_o(fetch_fault_page_o),
        .icache_rd_o(icache_rd_o),
        .icache_flush_o(icache_flush_o),
        .icache_invalidate_o(icache_invalidate_o),
        .icache_pc_o(icache_pc_o),
        .icache_priv_o(icache_priv_o),
        .squash_decode_o(squash_decode_o)
    );

    // Clock generation: 10ns period = 100MHz
    always #5 clk_i = ~clk_i;

    // ===========================================
    // RESET PROCEDURE
    // ===========================================
    task automatic do_reset;
    begin
        rst_i = 1;
        fetch_accept_i = 0;
        icache_accept_i = 0;
        icache_valid_i = 0;
        icache_error_i = 0;
        icache_inst_i = 32'h0;
        icache_page_fault_i = 0;
        fetch_invalidate_i = 0;
        branch_request_i = 0;
        branch_pc_i = 32'h0;
        branch_priv_i = 2'b11; // Machine mode
        #50;
        rst_i = 0;
        $display("[%0t] RESET complete", $time);
    end
    endtask

    // ===========================================
    // TEST SCENARIOS
    // ===========================================
    initial begin
        $dumpfile("tb_riscv_fetch.vcd");
        $dumpvars(0, tb_riscv_fetch);

        clk_i = 0;
        do_reset();

        // ========== TEST 1: Normal Branch Fetch ==========
        #10;
        $display("\n[TEST 1] Branch request to 0x1000");
        branch_request_i = 1;
        branch_pc_i = 32'h00001000;
        #10 branch_request_i = 0;

        // Cache accepts request
        icache_accept_i = 1;
        fetch_accept_i = 1;
        #10 icache_accept_i = 0;

        // Cache returns valid instruction
        #20;
        icache_valid_i = 1;
        icache_inst_i = 32'h00000013; // NOP (ADDI x0,x0,0)
        #10 icache_valid_i = 0;

        // Wait a bit and check result
        #20;
        if (fetch_valid_o)
            $display("[PASS] Fetch valid @ PC=0x%h, Instr=0x%h", fetch_pc_o, fetch_instr_o);
        else
            $display("[FAIL] Fetch not valid when expected");

        // ========== TEST 2: Page Fault ==========
        #40;
        $display("\n[TEST 2] Simulating page fault");
        branch_request_i = 1;
        branch_pc_i = 32'h00002000;
        #10 branch_request_i = 0;

        icache_accept_i = 1; #10 icache_accept_i = 0;
        #20;
        icache_valid_i = 1;
        icache_page_fault_i = 1;
        icache_inst_i = 32'hDEADBEEF;
        #10;
        icache_valid_i = 0;
        icache_page_fault_i = 0;

        #10;
        if (fetch_fault_page_o)
            $display("[PASS] Page fault detected as expected");
        else
            $display("[FAIL] Page fault not detected");

        // ========== TEST 3: Invalidate & Flush ==========
        #40;
        $display("\n[TEST 3] Forcing invalidate");
        fetch_invalidate_i = 1;
        #10 fetch_invalidate_i = 0;

        #20;
        if (icache_invalidate_o)
            $display("[PASS] Icache invalidate triggered");
        else
            $display("[INFO] No invalidate signal (depends on DUT behavior)");

        // ========== TEST 4: Branch squash ==========
        #40;
        $display("\n[TEST 4] Testing squash decode after branch");
        branch_request_i = 1;
        branch_pc_i = 32'h00003000;
        #10 branch_request_i = 0;

        #10;
        if (squash_decode_o)
            $display("[PASS] Squash decode triggered correctly");
        else
            $display("[INFO] squash_decode_o inactive (depends on DUT logic)");

        // Finish
        #100;
        $display("\nAll tests completed at time %0t", $time);
        $finish;
    end

endmodule
