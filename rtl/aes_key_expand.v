/*
 * AES-128 Bidirectional Key Expander
 * Generates round keys on the fly.
 * Supports forward expansion (encryption) and backward expansion (decryption).
 * Uses 4 instances of aes_sbox, shared between forward/backward paths.
 * Reset: Synchronous active-high.
 */

module aes_key_expand (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,        // Load external initial key
    input  wire         en,          // Enable key expansion step
    input  wire         decrypt,     // 0 = forward, 1 = backward
    input  wire [3:0]   round,       // Current round index (1 to 10)
    input  wire [127:0] key_in,      // Key input to load
    output wire [127:0] key_out,     // Current round key output
    output wire [127:0] key_next     // Next round key output
);

    reg [127:0] key_reg;

    // Split current key into 4 words
    wire [31:0] w0 = key_reg[127:96];
    wire [31:0] w1 = key_reg[95:64];
    wire [31:0] w2 = key_reg[63:32];
    wire [31:0] w3 = key_reg[31:0];

    // Compute w_prev words for backward expansion
    wire [31:0] w3_prev = w3 ^ w2;
    wire [31:0] w2_prev = w2 ^ w1;
    wire [31:0] w1_prev = w1 ^ w0;

    // Rcon lookup table (coefficients for AES key expansion)
    reg [7:0] rcon;
    always @(*) begin
        case (round)
            4'd1:  rcon = 8'h01;
            4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04;
            4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10;
            4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40;
            4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1b;
            4'd10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    end

    // Select input to S-Boxes based on direction
    // For forward, we use RotWord(w3)
    // For backward, we use RotWord(w3_prev)
    wire [31:0] rot_word = decrypt ? {w3_prev[23:0], w3_prev[31:24]} 
                                   : {w3[23:0], w3[31:24]};

    // SubWord using 4 S-Box instances (decrypt input is 0, since key expander always uses forward S-box)
    wire [31:0] sub_word;
    aes_sbox sb0 (.din(rot_word[31:24]), .decrypt(1'b0), .dout(sub_word[31:24]));
    aes_sbox sb1 (.din(rot_word[23:16]), .decrypt(1'b0), .dout(sub_word[23:16]));
    aes_sbox sb2 (.din(rot_word[15:8]),  .decrypt(1'b0), .dout(sub_word[15:8]));
    aes_sbox sb3 (.din(rot_word[7:0]),   .decrypt(1'b0), .dout(sub_word[7:0]));

    // XOR Rcon into the first byte of SubWord
    wire [31:0] temp = sub_word ^ {rcon, 24'h0};

    // Next key calculation
    // Forward path
    wire [31:0] w0_next = w0 ^ temp;
    wire [31:0] w1_next = w1 ^ w0_next;
    wire [31:0] w2_next = w2 ^ w1_next;
    wire [31:0] w3_next = w3 ^ w2_next;
    wire [127:0] key_next_forward = {w0_next, w1_next, w2_next, w3_next};

    // Backward path
    wire [31:0] w0_prev = w0 ^ temp;
    wire [127:0] key_next_backward = {w0_prev, w1_prev, w2_prev, w3_prev};

    assign key_next = decrypt ? key_next_backward : key_next_forward;

    // Update key register
    always @(posedge clk) begin
        if (rst) begin
            key_reg <= 128'h0;
        end else if (load) begin
            key_reg <= key_in;
        end else if (en) begin
            key_reg <= key_next;
        end
    end

    // Output current key
    assign key_out = key_reg;

endmodule
