// ============================================================================
// ALU.v - RISC-V Arithmetic Logic Unit (RV32IM)
// ============================================================================
// MÃ´ táº£: Thá»±c hiá»‡n cÃ¡c phÃ©p toÃ¡n logic, sá»‘ há»c, so sÃ¡nh, nhÃ¢n vÃ  chia
// Há»— trá»£: RV32I (Integer) + RV32M (Multiply/Divide)
// ============================================================================

module alu (
    input wire [31:0] in1,              // ToÃ¡n háº¡ng 1
    input wire [31:0] in2,              // ToÃ¡n háº¡ng 2
    input wire [3:0] alu_control,       // MÃ£ Ä‘iá»u khiá»ƒn phÃ©p toÃ¡n
    
    output reg [31:0] alu_result,       // Káº¿t quáº£
    output wire zero_flag,              // Flag: káº¿t quáº£ = 0
    output wire less_than,              // Flag: in1 < in2 (signed)
    output wire less_than_u             // Flag: in1 < in2 (unsigned)
);

    // ========================================================================
    // ALU Control Code Definition
    // ========================================================================
    localparam [3:0]
        ALU_ADD   = 4'b0000,    // Cá»™ng: in1 + in2
        ALU_SUB   = 4'b0001,    // Trá»«: in1 - in2
        ALU_AND   = 4'b0010,    // AND: in1 & in2
        ALU_OR    = 4'b0011,    // OR: in1 | in2
        ALU_XOR   = 4'b0100,    // XOR: in1 ^ in2
        ALU_SLL   = 4'b0101,    // Shift Left Logical
        ALU_SRL   = 4'b0110,    // Shift Right Logical
        ALU_SRA   = 4'b0111,    // Shift Right Arithmetic (vá»›i dáº¥u)
        ALU_SLT   = 4'b1000,    // Set Less Than (signed)
        ALU_SLTU  = 4'b1001,    // Set Less Than Unsigned
        ALU_MUL   = 4'b1010,    // Multiply (32-bit tháº¥p)
        ALU_MULH  = 4'b1011,    // Multiply High (32-bit cao, signed)
        ALU_DIV   = 4'b1100,    // Divide (signed)
        ALU_DIVU  = 4'b1101,    // Divide (unsigned)
        ALU_REM   = 4'b1110,    // Remainder (signed)
        ALU_REMU  = 4'b1111;    // Remainder (unsigned)
    
    // Biáº¿n trung gian cho phÃ©p nhÃ¢n 64-bit
    wire signed [63:0] mul_result_signed;
    wire [63:0] mul_result_unsigned;
    
    // Chuyá»ƒn Ä‘á»•i sang signed cho phÃ©p toÃ¡n cÃ³ dáº¥u
    wire signed [31:0] in1_signed = $signed(in1);
    wire signed [31:0] in2_signed = $signed(in2);
    
    // PhÃ©p nhÃ¢n
    assign mul_result_signed = in1_signed * in2_signed;
    assign mul_result_unsigned = in1 * in2;
    
    // ========================================================================
    // ALU Operations
    // ========================================================================
    always @(*) begin
        case (alu_control)
            // ================================================================
            // RV32I: PhÃ©p toÃ¡n sá»‘ há»c cÆ¡ báº£n
            // ================================================================
            ALU_ADD:  alu_result = in1 + in2;
            ALU_SUB:  alu_result = in1 - in2;
            
            // ================================================================
            // RV32I: PhÃ©p toÃ¡n logic
            // ================================================================
            ALU_AND:  alu_result = in1 & in2;
            ALU_OR:   alu_result = in1 | in2;
            ALU_XOR:  alu_result = in1 ^ in2;
            
            // ================================================================
            // RV32I: PhÃ©p dá»‹ch bit
            // ================================================================
            ALU_SLL:  alu_result = in1 << in2[4:0];    // Chá»‰ dÃ¹ng 5 bit tháº¥p
            ALU_SRL:  alu_result = in1 >> in2[4:0];    // Logical shift
            ALU_SRA:  alu_result = $signed(in1) >>> in2[4:0]; // Arithmetic shift
            
            // ================================================================
            // RV32I: PhÃ©p so sÃ¡nh
            // ================================================================
            ALU_SLT:  alu_result = (in1_signed < in2_signed) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (in1 < in2) ? 32'd1 : 32'd0;
            
            // ================================================================
            // RV32M: PhÃ©p nhÃ¢n
            // ================================================================
            ALU_MUL:  alu_result = mul_result_signed[31:0];    // 32-bit tháº¥p
            ALU_MULH: alu_result = mul_result_signed[63:32];   // 32-bit cao
            
            // ================================================================
            // RV32M: PhÃ©p chia vÃ  chia láº¥y dÆ° (signed)
            // ================================================================
            ALU_DIV: begin
                if (in2 == 32'd0) begin
                    // Chia cho 0: tráº£ vá» -1 (theo spec RISC-V)
                    alu_result = 32'hFFFFFFFF;
                end
                else if (in1 == 32'h80000000 && in2 == 32'hFFFFFFFF) begin
                    // Overflow case: -2^31 / -1 = -2^31
                    alu_result = 32'h80000000;
                end
                else begin
                    alu_result = $signed(in1) / $signed(in2);
                end
            end
            
            ALU_REM: begin
                if (in2 == 32'd0) begin
                    // Chia cho 0: tráº£ vá» dividend (theo spec RISC-V)
                    alu_result = in1;
                end
                else if (in1 == 32'h80000000 && in2 == 32'hFFFFFFFF) begin
                    // Overflow case: remainder = 0
                    alu_result = 32'd0;
                end
                else begin
                    alu_result = $signed(in1) % $signed(in2);
                end
            end
            
            // ================================================================
            // RV32M: PhÃ©p chia vÃ  chia láº¥y dÆ° (unsigned)
            // ================================================================
            ALU_DIVU: begin
                if (in2 == 32'd0) begin
                    // Chia cho 0: tráº£ vá» 2^32-1
                    alu_result = 32'hFFFFFFFF;
                end
                else begin
                    alu_result = in1 / in2;
                end
            end
            
            ALU_REMU: begin
                if (in2 == 32'd0) begin
                    // Chia cho 0: tráº£ vá» dividend
                    alu_result = in1;
                end
                else begin
                    alu_result = in1 % in2;
                end
            end
            
            // Default case
            default:  alu_result = 32'd0;
        endcase
    end
    
    // ========================================================================
    // Output Flags
    // ========================================================================
    assign zero_flag = (alu_result == 32'd0);           // Káº¿t quáº£ = 0
    assign less_than = in1_signed < in2_signed;         // So sÃ¡nh cÃ³ dáº¥u
    assign less_than_u = in1 < in2;                     // So sÃ¡nh khÃ´ng dáº¥u

endmodule
