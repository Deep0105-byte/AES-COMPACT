/*
 * AES MixColumns and InvMixColumns module
 * Fully combinational, processes all four columns (128-bit) in parallel.
 */

module aes_mixcolumns (
    input  wire [127:0] din,
    input  wire         decrypt,
    output wire [127:0] dout
);

    aes_mixcolumns_word col0 (
        .din(din[127:96]),
        .decrypt(decrypt),
        .dout(dout[127:96])
    );

    aes_mixcolumns_word col1 (
        .din(din[95:64]),
        .decrypt(decrypt),
        .dout(dout[95:64])
    );

    aes_mixcolumns_word col2 (
        .din(din[63:32]),
        .decrypt(decrypt),
        .dout(dout[63:32])
    );

    aes_mixcolumns_word col3 (
        .din(din[31:0]),
        .decrypt(decrypt),
        .dout(dout[31:0])
    );

endmodule


module aes_mixcolumns_word (
    input  wire [31:0] din,
    input  wire        decrypt,
    output wire [31:0] dout
);

    // Split input word into 4 bytes
    wire [7:0] w0 = din[31:24];
    wire [7:0] w1 = din[23:16];
    wire [7:0] w2 = din[15:8];
    wire [7:0] w3 = din[7:0];

    // Helper functions for Galois Field GF(2^8) multiplication
    function automatic [7:0] mul2;
        input [7:0] x;
        begin
            mul2 = {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
        end
    endfunction

    function automatic [7:0] mul4;
        input [7:0] x;
        begin
            mul4 = mul2(mul2(x));
        end
    endfunction

    function automatic [7:0] mul8;
        input [7:0] x;
        begin
            mul8 = mul2(mul4(x));
        end
    endfunction

    // AES MixColumns coefficients: 02, 03, 01, 01
    function automatic [7:0] mul3;
        input [7:0] x;
        begin
            mul3 = mul2(x) ^ x;
        end
    endfunction

    // AES InvMixColumns coefficients: 0e, 0b, 0d, 09
    function automatic [7:0] mul9;
        input [7:0] x;
        begin
            mul9 = mul8(x) ^ x;
        end
    endfunction

    function automatic [7:0] mulb;
        input [7:0] x;
        begin
            mulb = mul8(x) ^ mul2(x) ^ x;
        end
    endfunction

    function automatic [7:0] muld;
        input [7:0] x;
        begin
            muld = mul8(x) ^ mul4(x) ^ x;
        end
    endfunction

    function automatic [7:0] mule;
        input [7:0] x;
        begin
            mule = mul8(x) ^ mul4(x) ^ mul2(x);
        end
    endfunction

    // Outputs for encryption (MixColumns)
    wire [7:0] enc0 = mul2(w0) ^ mul3(w1) ^ w2 ^ w3;
    wire [7:0] enc1 = w0 ^ mul2(w1) ^ mul3(w2) ^ w3;
    wire [7:0] enc2 = w0 ^ w1 ^ mul2(w2) ^ mul3(w3);
    wire [7:0] enc3 = mul3(w0) ^ w1 ^ w2 ^ mul2(w3);

    // Outputs for decryption (InvMixColumns)
    wire [7:0] dec0 = mule(w0) ^ mulb(w1) ^ muld(w2) ^ mul9(w3);
    wire [7:0] dec1 = mul9(w0) ^ mule(w1) ^ mulb(w2) ^ muld(w3);
    wire [7:0] dec2 = muld(w0) ^ mul9(w1) ^ mule(w2) ^ mulb(w3);
    wire [7:0] dec3 = mulb(w0) ^ muld(w1) ^ mul9(w2) ^ mule(w3);

    // Mux between encryption and decryption paths
    assign dout[31:24] = decrypt ? dec0 : enc0;
    assign dout[23:16] = decrypt ? dec1 : enc1;
    assign dout[15:8]  = decrypt ? dec2 : enc2;
    assign dout[7:0]   = decrypt ? dec3 : enc3;

endmodule
