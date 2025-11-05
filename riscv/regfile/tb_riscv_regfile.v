`timescale 1ns/1ps
`include "riscv_regfile.v"
module riscv_regfile_tb;

//-----------------------------------------------------------------
// Tín hiệu testbench
//-----------------------------------------------------------------
reg         clk_i;
reg         rst_i;
reg  [4:0]  rd0_i;
reg  [31:0] rd0_value_i;
reg  [4:0]  ra0_i;
reg  [4:0]  rb0_i;
wire [31:0] ra0_value_o;
wire [31:0] rb0_value_o;
   integer i;
//-----------------------------------------------------------------
// DUT: Device Under Test
//-----------------------------------------------------------------
riscv_regfile uut (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .rd0_i(rd0_i),
    .rd0_value_i(rd0_value_i),
    .ra0_i(ra0_i),
    .rb0_i(rb0_i),
    .ra0_value_o(ra0_value_o),
    .rb0_value_o(rb0_value_o)
);

//-----------------------------------------------------------------
// Clock generator: 10ns period (100MHz)
//-----------------------------------------------------------------
always #5 clk_i = ~clk_i;

//-----------------------------------------------------------------
// Task: write register
//-----------------------------------------------------------------
task write_reg(input [4:0] reg_id, input [31:0] value);
begin
    @(negedge clk_i);
    rd0_i       = reg_id;
    rd0_value_i = value;
    @(negedge clk_i);
    rd0_i       = 0;   // stop writing
end
endtask

//-----------------------------------------------------------------
// Task: read two registers
//-----------------------------------------------------------------
task read_regs(input [4:0] ra, input [4:0] rb);
begin
    ra0_i = ra;
    rb0_i = rb;
    #1; // wait small time for async read
    $display("  Read ra=%0d -> %h | rb=%0d -> %h", ra, ra0_value_o, rb, rb0_value_o);
end
endtask

initial begin
    $dumpfile("tb_riscv_regfile.vcd");
    $dumpvars(0, riscv_regfile_tb);
end

//-----------------------------------------------------------------
// Test sequence
//-----------------------------------------------------------------
initial begin
    $display("========================================");
    $display("     TEST RISC-V REGISTER FILE");
    $display("========================================");

    // Init
    clk_i = 0;
    rst_i = 1;
    rd0_i = 0;
    rd0_value_i = 0;
    ra0_i = 0;
    rb0_i = 0;

    // Reset phase
    repeat (3) @(posedge clk_i);
    rst_i = 0;
    $display("Reset released");

    //-------------------------------------------------------------
    // 1. Check that x0 always 0
    //-------------------------------------------------------------
    write_reg(5'd0, 32'hDEADBEEF);
    read_regs(5'd0, 5'd0);
    if (ra0_value_o !== 32'h00000000)
        $display("ERROR: x0 != 0 (value=%h)", ra0_value_o);
    else
        $display("PASS: x0 is hardwired to zero");

    //-------------------------------------------------------------
    // 2. Write and read registers
    //-------------------------------------------------------------
    write_reg(5'd1, 32'h11111111);
    write_reg(5'd2, 32'h22222222);
    write_reg(5'd3, 32'h33333333);
    write_reg(5'd10, 32'hAAAA5555);

    // Read back
    read_regs(5'd1, 5'd2);
    read_regs(5'd3, 5'd10);

    //-------------------------------------------------------------
    // 3. Overwrite a register and check update
    //-------------------------------------------------------------
    write_reg(5'd1, 32'h12345678);
    read_regs(5'd1, 5'd10);

    //-------------------------------------------------------------
    // 4. Random test
    //-------------------------------------------------------------
    $display("Random test:");
 
    for (i = 4; i < 8; i = i + 1) begin
        write_reg(i, i * 32'h10);
    end
    read_regs(5'd4, 5'd7);

    //-------------------------------------------------------------
    // 5. End simulation
    //-------------------------------------------------------------
    $display("All tests finished.");
    #20;
    $finish;
end

endmodule
