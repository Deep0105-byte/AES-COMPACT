/*
 * AES-128 Top Self-Checking Testbench
 * Compares encryption and decryption outputs against NIST FIPS 197 and NIST SP 800-38A test vectors.
 */

`timescale 1ns/1ps

module tb_aes_top;

    reg          clk;
    reg          rst;
    reg          dec;
    reg          start;
    wire         ready;
    reg  [127:0] key;
    reg  [127:0] din;
    wire         out_valid;
    wire [127:0] dout;

    // Instantiate UUT
    aes_top uut (
        .clk(clk),
        .rst(rst),
        .dec(dec),
        .start(start),
        .ready(ready),
        .key(key),
        .din(din),
        .out_valid(out_valid),
        .dout(dout)
    );

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    // Test variables
    reg [127:0] expected_out;
    integer tests_passed = 0;
    integer tests_failed = 0;

    initial begin
        `ifdef VCS
            $fsdbDumpfile("tb_aes_top.fsdb");
            $fsdbDumpvars(0, tb_aes_top);
        `else
            $dumpfile("tb_aes_top.vcd");
            $dumpvars(0, tb_aes_top);
        `endif

        $display("==================================================");
        $display("       Starting AES-128 Compact Core Testbench    ");
        $display("==================================================");

        // Initialize signals
        clk   = 0;
        rst   = 1;
        dec   = 0;
        start = 0;
        key   = 128'h0;
        din   = 128'h0;
        expected_out = 128'h0;

        // Reset Sequence
        #20;
        rst = 0;
        #10;

        // ---------------------------------------------------------------------
        // TEST 1: Encryption (NIST FIPS 197 C.1)
        // ---------------------------------------------------------------------
        wait(ready);
        @(posedge clk);
        dec          = 1'b0; // Encrypt
        key          = 128'h000102030405060708090a0b0c0d0e0f;
        din          = 128'h00112233445566778899aabbccddeeff;
        expected_out = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        start        = 1'b1;
        
        @(posedge clk);
        start = 1'b0;

        wait(out_valid);
        @(posedge clk); // Allow register update
        if (dout == expected_out) begin
            $display("[PASS] TEST 1: Encryption (FIPS 197 C.1)");
            $display("  Input Key:  %h", key);
            $display("  Plaintext:  %h", din);
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] TEST 1: Encryption (FIPS 197 C.1)");
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_failed = tests_failed + 1;
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 2: Decryption (NIST FIPS 197 C.1 Inverse)
        // ---------------------------------------------------------------------
        wait(ready);
        @(posedge clk);
        dec          = 1'b1; // Decrypt
        key          = 128'h000102030405060708090a0b0c0d0e0f;
        din          = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        expected_out = 128'h00112233445566778899aabbccddeeff;
        start        = 1'b1;
        
        @(posedge clk);
        start = 1'b0;

        wait(out_valid);
        @(posedge clk); // Allow register update
        if (dout == expected_out) begin
            $display("[PASS] TEST 2: Decryption (FIPS 197 C.1)");
            $display("  Input Key:  %h", key);
            $display("  Ciphertext: %h", din);
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] TEST 2: Decryption (FIPS 197 C.1)");
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_failed = tests_failed + 1;
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 3: Encryption (NIST SP 800-38A F.1.1)
        // ---------------------------------------------------------------------
        wait(ready);
        @(posedge clk);
        dec          = 1'b0; // Encrypt
        key          = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        din          = 128'h6bc1bee22e409f96e93d7e117393172a;
        expected_out = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        start        = 1'b1;
        
        @(posedge clk);
        start = 1'b0;

        wait(out_valid);
        @(posedge clk); // Allow register update
        if (dout == expected_out) begin
            $display("[PASS] TEST 3: Encryption (SP 800-38A F.1.1)");
            $display("  Input Key:  %h", key);
            $display("  Plaintext:  %h", din);
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] TEST 3: Encryption (SP 800-38A F.1.1)");
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_failed = tests_failed + 1;
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 4: Decryption (NIST SP 800-38A F.1.1 Inverse)
        // ---------------------------------------------------------------------
        wait(ready);
        @(posedge clk);
        dec          = 1'b1; // Decrypt
        key          = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        din          = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        expected_out = 128'h6bc1bee22e409f96e93d7e117393172a;
        start        = 1'b1;
        
        @(posedge clk);
        start = 1'b0;

        wait(out_valid);
        @(posedge clk); // Allow register update
        if (dout == expected_out) begin
            $display("[PASS] TEST 4: Decryption (SP 800-38A F.1.1)");
            $display("  Input Key:  %h", key);
            $display("  Ciphertext: %h", din);
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] TEST 4: Decryption (SP 800-38A F.1.1)");
            $display("  Expected:   %h", expected_out);
            $display("  Got:        %h", dout);
            tests_failed = tests_failed + 1;
        end
        #20;

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("                 Test Summary                     ");
        $display("==================================================");
        $display("  Tests Passed: %d", tests_passed);
        $display("  Tests Failed: %d", tests_failed);
        if (tests_failed == 0) begin
            $display("  Result: SUCCESS");
        end else begin
            $display("  Result: FAILURE");
        end
        $display("==================================================");

        $finish;
    end

endmodule
