`timescale 1ns/1ps

/*
 * AES-128 Top-Level Wrapper
 * Registers all inputs and outputs to isolate the core from external I/O timing paths.
 * Highly recommended for FPGA timing closure and ASIC tapeout boundary constraints.
 * Reset: Synchronous active-high.
 */

module aes_top (
    input  wire         clk,
    input  wire         rst,
    
    // Control & Config
    input  wire         dec,         // 0 = encrypt, 1 = decrypt
    input  wire         start,       // Start transaction (asserted for 1 cycle when ready is high)
    output wire         ready,       // Core is ready for a new block
    
    // Input Key and Data
    input  wire [127:0] key,         // 128-bit key
    input  wire [127:0] din,         // 128-bit input block (plaintext or ciphertext)
    
    // Output Status and Data
    output reg          out_valid,   // Asserted for 1 cycle when output data is valid
    output reg  [127:0] dout         // 128-bit output block (ciphertext or plaintext)
);

    // Boundary registers for input isolation
    reg          dec_r;
    reg [127:0]  key_r;
    reg [127:0]  din_r;
    reg          start_r;

    // Capture inputs on start when core is ready
    always @(posedge clk) begin
        if (rst) begin
            dec_r   <= 1'b0;
            key_r   <= 128'h0;
            din_r   <= 128'h0;
            start_r <= 1'b0;
        end else if (start && ready) begin
            dec_r   <= dec;
            key_r   <= key;
            din_r   <= din;
            start_r <= 1'b1;
        end else begin
            start_r <= 1'b0; // Single cycle strobe
        end
    end

    // Core outputs
    wire         core_ready;
    wire         core_out_valid;
    wire [127:0] core_dout;

    // Instantiate the AES Core
    aes_core core_inst (
        .clk(clk),
        .rst(rst),
        .init(start_r),
        .dec(dec_r),
        .key(key_r),
        .din(din_r),
        .ready(core_ready),
        .out_valid(core_out_valid),
        .dout(core_dout)
    );

    // Boundary registers for output isolation
    always @(posedge clk) begin
        if (rst) begin
            out_valid <= 1'b0;
            dout      <= 128'h0;
        end else begin
            out_valid <= core_out_valid;
            if (core_out_valid) begin
                dout <= core_dout;
            end
        end
    end

    // Top-level ready is asserted if the core is ready and we aren't starting in the current cycle
    assign ready = core_ready && !start_r;

endmodule
