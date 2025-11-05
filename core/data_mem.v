// ============================================================================
// DATA_MEM_PIPELINED.v - Pipelined Data Memory
// ============================================================================
// Cải tiến:
// 1. Read operation là REGISTERED (không phải combinational)
// 2. Tách sign extension thành pipeline stage riêng
// 3. Giảm critical path từ address → data out
// ============================================================================

module data_mem (
    input             clock,
    input      [31:0] address,
    input      [31:0] write_data,
    input             memwrite,
    input             memread,
    input      [1:0]  byte_size,
    input             sign_ext,
    output reg [31:0] read_data       // REGISTERED output
);

    // Memory array
    reg [7:0] memory [0:1023];
    
    // Pipeline registers
    reg [31:0] raw_data;              // Stage 1: Raw data from memory
    reg [1:0]  byte_size_reg;         // Stage 1: Registered control signals
    reg        sign_ext_reg;
    reg        memread_reg;
    
    wire [9:0] byte_addr = address[9:0];
    
    // Initialize memory
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] = 8'h00;
        end
    end
    
    // ========================================================================
    // STAGE 1: Memory Access (SYNCHRONOUS)
    // Critical path: address → memory array → register
    // ========================================================================
    always @(posedge clock) begin
        if (memread) begin
            // Read raw data (no extension yet)
            case (byte_size)
                2'b00: raw_data <= {24'h000000, memory[byte_addr]};
                
                2'b01: raw_data <= {16'h0000, 
                                    memory[byte_addr + 1], 
                                    memory[byte_addr]};
                
                2'b10: raw_data <= {memory[byte_addr + 3],
                                    memory[byte_addr + 2],
                                    memory[byte_addr + 1],
                                    memory[byte_addr]};
                
                default: raw_data <= 32'h00000000;
            endcase
            
            // Register control signals
            byte_size_reg <= byte_size;
            sign_ext_reg <= sign_ext;
            memread_reg <= 1'b1;
        end
        else begin
            memread_reg <= 1'b0;
        end
    end
    
    // ========================================================================
    // STAGE 2: Sign/Zero Extension (COMBINATIONAL - but separate stage)
    // Critical path: raw_data → extension logic → read_data register
    // ========================================================================
    always @(posedge clock) begin
        if (memread_reg) begin
            case (byte_size_reg)
                2'b00: begin  // Byte
                    if (sign_ext_reg)
                        read_data <= {{24{raw_data[7]}}, raw_data[7:0]};
                    else
                        read_data <= {24'h000000, raw_data[7:0]};
                end
                
                2'b01: begin  // Halfword
                    if (sign_ext_reg)
                        read_data <= {{16{raw_data[15]}}, raw_data[15:0]};
                    else
                        read_data <= {16'h0000, raw_data[15:0]};
                end
                
                2'b10: begin  // Word (no extension needed)
                    read_data <= raw_data;
                end
                
                default: read_data <= 32'h00000000;
            endcase
        end
    end
    
    // ========================================================================
    // WRITE OPERATION (unchanged - already synchronous)
    // ========================================================================
    always @(posedge clock) begin
        if (memwrite) begin
            case (byte_size)
                2'b00: memory[byte_addr] <= write_data[7:0];
                
                2'b01: begin
                    memory[byte_addr]     <= write_data[7:0];
                    memory[byte_addr + 1] <= write_data[15:8];
                end
                
                2'b10: begin
                    memory[byte_addr]     <= write_data[7:0];
                    memory[byte_addr + 1] <= write_data[15:8];
                    memory[byte_addr + 2] <= write_data[23:16];
                    memory[byte_addr + 3] <= write_data[31:24];
                end
            endcase
        end
    end

endmodule

// ============================================================================
// LƯU Ý QUAN TRỌNG:
// ============================================================================
// 1. Read latency: 2 cycles (thay vì 0 cycle)
//    - Cycle 1: Memory access → raw_data
//    - Cycle 2: Extension → read_data
//
// 2. Pipeline hazard handling:
//    - Cần thêm 2 NOP sau LOAD instruction nếu instruction tiếp theo
//      phụ thuộc vào load result
//    - Hoặc sử dụng load-use hazard detection để stall
//
// 3. Timing benefit:
//    - Loại bỏ long combinational path: address → memory → extension → output
//    - Chia thành 2 shorter paths: address → memory, extension → output
//    - Fmax improvement: ~30-50%
//
// 4. Trade-off:
//    - Tăng CPI (cycles per instruction) cho LOAD instructions
//    - Nhưng tăng Fmax đáng kể → overall performance có thể tốt hơn
// ============================================================================
