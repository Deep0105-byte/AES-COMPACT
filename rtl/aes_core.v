`timescale 1ns/1ps

/*
 * AES-128 Core (Encryption and Decryption)
 * Single-round iterative datapath.
 * Shares 16 S-Boxes and 1 MixColumns block between encryption and decryption.
 * Includes FSM to handle decryption key pre-calculation (ST_KEY_SETUP) and rounds.
 * Reset: Synchronous active-high.
 */

module aes_core (
    input  wire         clk,
    input  wire         rst,
    input  wire         init,        // Load key and data, start processing
    input  wire         dec,         // 0 = encrypt, 1 = decrypt
    input  wire [127:0] key,         // 128-bit key
    input  wire [127:0] din,         // 128-bit input (plaintext or ciphertext)
    output reg          ready,       // Core is ready/idle
    output reg          out_valid,   // Output is valid
    output wire [127:0] dout         // 128-bit output (ciphertext or plaintext)
);

    // FSM States
    localparam ST_IDLE      = 3'd0;
    localparam ST_KEY_SETUP = 3'd1;
    localparam ST_ROUND_0   = 3'd2;
    localparam ST_ROUNDS    = 3'd3;
    localparam ST_DONE      = 3'd4;

    reg [2:0] state;
    reg [3:0] round_ctr;
    reg [127:0] state_reg;

    // Key expander control signals
    wire         key_load;
    wire         key_en;
    wire         key_decrypt;
    wire [3:0]   key_round;
    wire [127:0] key_out;
    wire [127:0] key_next;

    // Instantiate bidirectional key expander
    aes_key_expand key_unit (
        .clk(clk),
        .rst(rst),
        .load(key_load),
        .en(key_en),
        .decrypt(key_decrypt),
        .round(key_round),
        .key_in(key),
        .key_out(key_out),
        .key_next(key_next)
    );

    assign key_load = (state == ST_IDLE) && init;
    assign key_en   = (state == ST_KEY_SETUP) || (state == ST_ROUNDS);
    assign key_decrypt = (state == ST_ROUNDS) ? dec : 1'b0;
    assign key_round = (state == ST_KEY_SETUP) ? round_ctr : 
                       (state == ST_ROUNDS)    ? (dec ? (4'd11 - round_ctr) : round_ctr) : 
                       4'd0;

    // =========================================================================
    // AES Datapath
    // =========================================================================

    // 1. SubBytes (shared 16 S-Boxes)
    wire [127:0] sub_out;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            aes_sbox sb (
                .din(state_reg[127 - 8*i -: 8]),
                .decrypt(dec),
                .dout(sub_out[127 - 8*i -: 8])
            );
        end
    endgenerate

    // 2. ShiftRows (wiring only)
    wire [7:0] sb0  = sub_out[127:120];
    wire [7:0] sb1  = sub_out[119:112];
    wire [7:0] sb2  = sub_out[111:104];
    wire [7:0] sb3  = sub_out[103:96];
    wire [7:0] sb4  = sub_out[95:88];
    wire [7:0] sb5  = sub_out[87:80];
    wire [7:0] sb6  = sub_out[79:72];
    wire [7:0] sb7  = sub_out[71:64];
    wire [7:0] sb8  = sub_out[63:56];
    wire [7:0] sb9  = sub_out[55:48];
    wire [7:0] sb10 = sub_out[47:40];
    wire [7:0] sb11 = sub_out[39:32];
    wire [7:0] sb12 = sub_out[31:24];
    wire [7:0] sb13 = sub_out[23:16];
    wire [7:0] sb14 = sub_out[15:8];
    wire [7:0] sb15 = sub_out[7:0];

    // ShiftRows (encryption)
    wire [127:0] shift_rows_out = {
        sb0,  sb5,  sb10, sb15,
        sb4,  sb9,  sb14, sb3,
        sb8,  sb13, sb2,  sb7,
        sb12, sb1,  sb6,  sb11
    };

    // InvShiftRows (decryption)
    wire [127:0] inv_shift_rows_out = {
        sb0,  sb13, sb10, sb7,
        sb4,  sb1,  sb14, sb11,
        sb8,  sb5,  sb2,  sb15,
        sb12, sb9,  sb6,  sb3
    };

    wire [127:0] shift_out = dec ? inv_shift_rows_out : shift_rows_out;

    // 3. MixColumns (shared 1 instance)
    // Encryption: MixColumns(ShiftRows)
    // Decryption: InvMixColumns(ShiftRows ^ Key)
    wire [127:0] mix_in = dec ? (shift_out ^ key_next) : shift_out;
    wire [127:0] mix_out;

    aes_mixcolumns mix_unit (
        .din(mix_in),
        .decrypt(dec),
        .dout(mix_out)
    );

    // 4. AddRoundKey and output select
    wire [127:0] state_next;
    assign state_next = (round_ctr == 4'd10) ? (shift_out ^ key_next)
                                             : (dec ? mix_out : (mix_out ^ key_next));

    // =========================================================================
    // FSM Control Logic
    // =========================================================================

    always @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            round_ctr   <= 4'd0;
            state_reg   <= 128'h0;
            ready       <= 1'b1;
            out_valid   <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    out_valid <= 1'b0;
                    ready     <= 1'b1;
                    if (init) begin
                        ready <= 1'b0;
                        if (dec) begin
                            state     <= ST_KEY_SETUP;
                            round_ctr <= 4'd1;
                        end else begin
                            state     <= ST_ROUNDS;
                            state_reg <= din ^ key; // Initial AddRoundKey (K_0)
                            round_ctr <= 4'd1;
                        end
                    end
                end

                ST_KEY_SETUP: begin
                    // Forward key expansion to compute K_10
                    if (round_ctr == 4'd10) begin
                        state     <= ST_ROUND_0;
                        round_ctr <= 4'd0;
                    end else begin
                        round_ctr <= round_ctr + 4'd1;
                    end
                end

                ST_ROUND_0: begin
                    // Decryption Round 0: Initial AddRoundKey (K_10)
                    state     <= ST_ROUNDS;
                    state_reg <= din ^ key_out;
                    round_ctr <= 4'd1;
                end

                ST_ROUNDS: begin
                    state_reg <= state_next;
                    if (round_ctr == 4'd10) begin
                        state     <= ST_DONE;
                        round_ctr <= 4'd0;
                    end else begin
                        round_ctr <= round_ctr + 4'd1;
                    end
                end

                ST_DONE: begin
                    out_valid <= 1'b1;
                    ready     <= 1'b1;
                    if (init) begin
                        out_valid <= 1'b0;
                        ready     <= 1'b0;
                        if (dec) begin
                            state     <= ST_KEY_SETUP;
                            round_ctr <= 4'd1;
                        end else begin
                            state     <= ST_ROUNDS;
                            state_reg <= din ^ key;
                            round_ctr <= 4'd1;
                        end
                    end else begin
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    assign dout = state_reg;

endmodule
