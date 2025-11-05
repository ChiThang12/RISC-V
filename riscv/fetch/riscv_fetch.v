//-----------------------------------------------------------------
//                         RISC-V Core
//                            V1.0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------

//-------------------------------------------------------------
// Module 1: Branch Buffer
//-------------------------------------------------------------
module fetch_branch_buffer
(
    input           clk_i,
    input           rst_i,
    input           branch_request_i,
    input  [31:0]   branch_pc_i,
    input  [1:0]    branch_priv_i,
    input           icache_rd_i,
    input           icache_accept_i,
    
    output reg      branch_q_o,
    output reg [31:0] branch_pc_q_o,
    output reg [1:0]  branch_priv_q_o,
    output          squash_decode_o
);

`include "riscv_defs.v"

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        branch_q_o      <= 1'b0;
        branch_pc_q_o   <= 32'b0;
        branch_priv_q_o <= `PRIV_MACHINE;
    end
    else if (branch_request_i) begin
        branch_q_o      <= 1'b1;
        branch_pc_q_o   <= branch_pc_i;
        branch_priv_q_o <= branch_priv_i;
    end
    else if (icache_rd_i && icache_accept_i) begin
        branch_q_o      <= 1'b0;
        branch_pc_q_o   <= 32'b0;
    end
end

assign squash_decode_o = branch_request_i;

endmodule

//-------------------------------------------------------------
// Module 2: Fetch State Control
//-------------------------------------------------------------
module fetch_state_control
(
    input           clk_i,
    input           rst_i,
    input           branch_w_i,
    input           stall_w_i,
    
    output reg      active_q_o,
    output reg      stall_q_o
);

// Active flag
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        active_q_o <= 1'b0;
    else if (branch_w_i && ~stall_w_i)
        active_q_o <= 1'b1;
end

// Stall flag
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        stall_q_o <= 1'b0;
    else
        stall_q_o <= stall_w_i;
end

endmodule

//-------------------------------------------------------------
// Module 3: ICache Request Tracker
//-------------------------------------------------------------
module fetch_icache_tracker
(
    input           clk_i,
    input           rst_i,
    input           icache_rd_i,
    input           icache_accept_i,
    input           icache_valid_i,
    input           icache_invalidate_o_i,
    
    output reg      icache_fetch_q_o,
    output reg      icache_invalidate_q_o,
    output          icache_busy_w_o
);

// ICACHE fetch tracking
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        icache_fetch_q_o <= 1'b0;
    else if (icache_rd_i && icache_accept_i)
        icache_fetch_q_o <= 1'b1;
    else if (icache_valid_i)
        icache_fetch_q_o <= 1'b0;
end

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        icache_invalidate_q_o <= 1'b0;
    else if (icache_invalidate_o_i && !icache_accept_i)
        icache_invalidate_q_o <= 1'b1;
    else
        icache_invalidate_q_o <= 1'b0;
end

assign icache_busy_w_o = icache_fetch_q_o && !icache_valid_i;

endmodule

//-------------------------------------------------------------
// Module 4: PC Management
//-------------------------------------------------------------
module fetch_pc_manager
(
    input           clk_i,
    input           rst_i,
    input           branch_w_i,
    input           stall_w_i,
    input  [31:0]   branch_pc_w_i,
    input  [1:0]    branch_priv_w_i,
    input           icache_rd_i,
    input           icache_accept_i,
    
    output reg [31:0] pc_f_q_o,
    output reg [31:0] pc_d_q_o,
    output reg [1:0]  priv_f_q_o,
    output reg        branch_d_q_o,
    output [31:0]     icache_pc_w_o,
    output [1:0]      icache_priv_w_o,
    output            fetch_resp_drop_w_o
);

`include "riscv_defs.v"

// Program Counter F stage
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        pc_f_q_o <= 32'b0;
    else if (branch_w_i && ~stall_w_i)
        pc_f_q_o <= branch_pc_w_i;
    else if (!stall_w_i)
        pc_f_q_o <= {icache_pc_w_o[31:2], 2'b0} + 32'd4;
end

// Privilege level F stage
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        priv_f_q_o <= `PRIV_MACHINE;
    else if (branch_w_i && ~stall_w_i)
        priv_f_q_o <= branch_priv_w_i;
end

// Branch D stage
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        branch_d_q_o <= 1'b0;
    else if (branch_w_i && ~stall_w_i)
        branch_d_q_o <= 1'b1;
    else if (!stall_w_i)
        branch_d_q_o <= 1'b0;
end

// Last fetch address (D stage)
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        pc_d_q_o <= 32'b0;
    else if (icache_rd_i && icache_accept_i)
        pc_d_q_o <= icache_pc_w_o;
end

assign icache_pc_w_o       = pc_f_q_o;
assign icache_priv_w_o     = priv_f_q_o;
assign fetch_resp_drop_w_o = branch_w_i | branch_d_q_o;

endmodule

//-------------------------------------------------------------
// Module 5: Response Skid Buffer
//-------------------------------------------------------------
module fetch_skid_buffer
(
    input           clk_i,
    input           rst_i,
    input           fetch_valid_i,
    input           fetch_accept_i,
    input           fetch_fault_page_i,
    input           fetch_fault_fetch_i,
    input  [31:0]   fetch_pc_i,
    input  [31:0]   fetch_instr_i,
    input           icache_valid_i,
    input           fetch_resp_drop_w_i,
    input  [31:0]   pc_d_q_i,
    input  [31:0]   icache_inst_i,
    input           icache_error_i,
    input           icache_page_fault_i,
    
    output          fetch_valid_o,
    output [31:0]   fetch_pc_o,
    output [31:0]   fetch_instr_o,
    output          fetch_fault_fetch_o,
    output          fetch_fault_page_o
);

reg [65:0] skid_buffer_q;
reg        skid_valid_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        skid_buffer_q <= 66'b0;
        skid_valid_q  <= 1'b0;
    end 
    else if (fetch_valid_i && !fetch_accept_i) begin
        skid_valid_q  <= 1'b1;
        skid_buffer_q <= {fetch_fault_page_i, fetch_fault_fetch_i, fetch_pc_i, fetch_instr_i};
    end
    else begin
        skid_valid_q  <= 1'b0;
        skid_buffer_q <= 66'b0;
    end
end

assign fetch_valid_o       = (icache_valid_i || skid_valid_q) & !fetch_resp_drop_w_i;
assign fetch_pc_o          = skid_valid_q ? skid_buffer_q[63:32] : {pc_d_q_i[31:2], 2'b0};
assign fetch_instr_o       = skid_valid_q ? skid_buffer_q[31:0]  : icache_inst_i;
assign fetch_fault_fetch_o = skid_valid_q ? skid_buffer_q[64]    : icache_error_i;
assign fetch_fault_page_o  = skid_valid_q ? skid_buffer_q[65]    : icache_page_fault_i;

endmodule

//-------------------------------------------------------------
// Top Module: RISC-V Fetch (integrates all sub-modules)
//-------------------------------------------------------------
module riscv_fetch
#(
    parameter SUPPORT_MMU = 1
)
(
    // Inputs
    input           clk_i,
    input           rst_i,
    input           fetch_accept_i,
    input           icache_accept_i,
    input           icache_valid_i,
    input           icache_error_i,
    input  [31:0]   icache_inst_i,
    input           icache_page_fault_i,
    input           fetch_invalidate_i,
    input           branch_request_i,
    input  [31:0]   branch_pc_i,
    input  [1:0]    branch_priv_i,

    // Outputs
    output          fetch_valid_o,
    output [31:0]   fetch_instr_o,
    output [31:0]   fetch_pc_o,
    output          fetch_fault_fetch_o,
    output          fetch_fault_page_o,
    output          icache_rd_o,
    output          icache_flush_o,
    output          icache_invalidate_o,
    output [31:0]   icache_pc_o,
    output [1:0]    icache_priv_o,
    output          squash_decode_o
);

// Internal wires
wire        branch_q_w;
wire [31:0] branch_pc_q_w;
wire [1:0]  branch_priv_q_w;
wire        active_q_w;
wire        stall_q_w;
wire        icache_fetch_q_w;
wire        icache_invalidate_q_w;
wire        icache_busy_w;
wire [31:0] pc_f_q_w;
wire [31:0] pc_d_q_w;
wire [1:0]  priv_f_q_w;
wire        branch_d_q_w;
wire [31:0] icache_pc_w;
wire [1:0]  icache_priv_w;
wire        fetch_resp_drop_w;

// Stall condition
wire stall_w = !fetch_accept_i || icache_busy_w || !icache_accept_i;

//-------------------------------------------------------------
// Instantiate Sub-modules
//-------------------------------------------------------------

// Branch Buffer
fetch_branch_buffer u_branch_buffer (
    .clk_i              (clk_i),
    .rst_i              (rst_i),
    .branch_request_i   (branch_request_i),
    .branch_pc_i        (branch_pc_i),
    .branch_priv_i      (branch_priv_i),
    .icache_rd_i        (icache_rd_o),
    .icache_accept_i    (icache_accept_i),
    .branch_q_o         (branch_q_w),
    .branch_pc_q_o      (branch_pc_q_w),
    .branch_priv_q_o    (branch_priv_q_w),
    .squash_decode_o    (squash_decode_o)
);

// State Control
fetch_state_control u_state_control (
    .clk_i              (clk_i),
    .rst_i              (rst_i),
    .branch_w_i         (branch_q_w),
    .stall_w_i          (stall_w),
    .active_q_o         (active_q_w),
    .stall_q_o          (stall_q_w)
);

// ICache Tracker
fetch_icache_tracker u_icache_tracker (
    .clk_i                  (clk_i),
    .rst_i                  (rst_i),
    .icache_rd_i            (icache_rd_o),
    .icache_accept_i        (icache_accept_i),
    .icache_valid_i         (icache_valid_i),
    .icache_invalidate_o_i  (icache_invalidate_o),
    .icache_fetch_q_o       (icache_fetch_q_w),
    .icache_invalidate_q_o  (icache_invalidate_q_w),
    .icache_busy_w_o        (icache_busy_w)
);

// PC Manager
fetch_pc_manager u_pc_manager (
    .clk_i                  (clk_i),
    .rst_i                  (rst_i),
    .branch_w_i             (branch_q_w),
    .stall_w_i              (stall_w),
    .branch_pc_w_i          (branch_pc_q_w),
    .branch_priv_w_i        (branch_priv_q_w),
    .icache_rd_i            (icache_rd_o),
    .icache_accept_i        (icache_accept_i),
    .pc_f_q_o               (pc_f_q_w),
    .pc_d_q_o               (pc_d_q_w),
    .priv_f_q_o             (priv_f_q_w),
    .branch_d_q_o           (branch_d_q_w),
    .icache_pc_w_o          (icache_pc_w),
    .icache_priv_w_o        (icache_priv_w),
    .fetch_resp_drop_w_o    (fetch_resp_drop_w)
);

// Skid Buffer
fetch_skid_buffer u_skid_buffer (
    .clk_i                  (clk_i),
    .rst_i                  (rst_i),
    .fetch_valid_i          (fetch_valid_o),
    .fetch_accept_i         (fetch_accept_i),
    .fetch_fault_page_i     (fetch_fault_page_o),
    .fetch_fault_fetch_i    (fetch_fault_fetch_o),
    .fetch_pc_i             (fetch_pc_o),
    .fetch_instr_i          (fetch_instr_o),
    .icache_valid_i         (icache_valid_i),
    .fetch_resp_drop_w_i    (fetch_resp_drop_w),
    .pc_d_q_i               (pc_d_q_w),
    .icache_inst_i          (icache_inst_i),
    .icache_error_i         (icache_error_i),
    .icache_page_fault_i    (icache_page_fault_i),
    .fetch_valid_o          (fetch_valid_o),
    .fetch_pc_o             (fetch_pc_o),
    .fetch_instr_o          (fetch_instr_o),
    .fetch_fault_fetch_o    (fetch_fault_fetch_o),
    .fetch_fault_page_o     (fetch_fault_page_o)
);

//-------------------------------------------------------------
// Output Assignments
//-------------------------------------------------------------
assign icache_rd_o          = active_q_w & fetch_accept_i & !icache_busy_w;
assign icache_pc_o          = {icache_pc_w[31:2], 2'b0};
assign icache_priv_o        = icache_priv_w;
assign icache_flush_o       = fetch_invalidate_i | icache_invalidate_q_w;
assign icache_invalidate_o  = 1'b0;

endmodule