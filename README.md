# Compact AES-128 Encryption/Decryption Core

A synthesizable, high-efficiency, resource-optimized 128-bit AES encryption and decryption engine in Verilog. This core is designed specifically for resource-constrained applications (IoT devices, smart cards, embedded systems) and is ready for both FPGA board implementation and ASIC tapeout.

## Architecture Highlights

1. **Iterative (Single-Round) Datapath**: Computes one AES round per clock cycle. This offers an optimal balance between throughput and area, avoiding the extreme area overhead of pipelined or unrolled architectures.
2. **On-the-fly Bidirectional Key Expansion**: 
   - Generates round keys on the fly using a shared 4-S-Box hardware block.
   - For **encryption**, the key is expanded forward: $K_0 \to K_1 \to \dots \to K_{10}$.
   - For **decryption**, the key is expanded backward: $K_{10} \to K_9 \to \dots \to K_0$.
   - By calculating the round keys dynamically, the design avoids storing the entire key schedule ($11 \times 128 = 1408$ registers). It uses only a single 128-bit register for the active round key, resulting in significant gate count/slice savings.
3. **Maximized Resource Sharing**:
   - Shares the same 16 S-Boxes for both SubBytes (encryption) and InvSubBytes (decryption).
   - Shares a single 128-bit MixColumns block, dynamically reconfigured for InvMixColumns using multiplexers.
4. **Tapeout-Ready Design**:
   - Registered input and output boundaries in the top wrapper (`aes_top`) to isolate internal timing paths from pad delays.
   - Strictly synchronous design (single clock domain, synchronous active-high reset).
   - No latch structures, no multi-driver buses, and no tri-states.

---

## Signal Description

The top-level module is `aes_top.v`.

| Port Name | Width | Direction | Description |
|---|---|---|---|
| `clk` | 1 | Input | System Clock |
| `rst` | 1 | Input | Synchronous Active-High Reset |
| `dec` | 1 | Input | Operation Mode: `0` = Encrypt, `1` = Decrypt. Must be stable when `start` is asserted. |
| `start` | 1 | Input | Strobe signal to start processing. Assert for 1 cycle when `ready` is high. |
| `ready` | 1 | Output | High when the core is idle and ready to accept new key/data. |
| `key` | 128 | Input | 128-bit Cipher Key. Captured on `start`. |
| `din` | 128 | Input | 128-bit Input Block (Plaintext for encryption, Ciphertext for decryption). Captured on `start`. |
| `out_valid` | 1 | Output | Strobe signal indicating `dout` is valid. Asserted for 1 clock cycle. |
| `dout` | 128 | Output | 128-bit Output Block (Ciphertext for encryption, Plaintext for decryption). |

---

## FSM & Latency Profile

The core contains a state machine that controls the key generation and datapath routing:

- **Encryption Latency**: **11 Clock Cycles**
  - Cycle 0: `start` is asserted. Key and Plaintext are loaded.
  - Cycles 1 to 10: The 10 AES-128 rounds are computed.
  - Cycle 11: `out_valid` is asserted, and the ciphertext is available on `dout`.

- **Decryption Latency**: **21 Clock Cycles**
  - Cycle 0: `start` is asserted. The initial key $K_0$ is loaded.
  - Cycles 1 to 10: Key expansion runs forward to pre-calculate $K_{10}$ (stored in the key register).
  - Cycle 11: The ciphertext is loaded and XORed with $K_{10}$ (Decryption Round 0).
  - Cycles 12 to 21: Decryption rounds 1 to 10 are computed while the key expander runs backward to generate $K_9 \dots K_0$.
  - Cycle 22: `out_valid` is asserted, and the plaintext is available on `dout`.

---

## Synthesis and FPGA Implementation Guidelines

### 1. FPGA Implementation (Xilinx Vivado, Intel Quartus)
- The S-Boxes are implemented in `aes_sbox.v` as combinational case statements. Synthesis tools will automatically map these to LUT structures or distributed ROMs.
- Register boundaries in `aes_top` will allow the tool to place the core anywhere on the chip and meet high-frequency timing targets.
- **Clock Constraint**: A clock constraint of 100-200 MHz is easily achievable in modern FPGAs.

### 2. ASIC Tapeout (Yosys, OpenLane, Design Compiler)
- If your standard cell library has specific high-density ROMs or latch-free clock gating cells, you can replace the `aes_sbox` lookup tables with them.
- If your ASIC flow prefers an active-low asynchronous reset, you can easily change the reset declaration in `aes_top.v`, `aes_core.v`, and `aes_key_expand.v`:
  - Change `always @(posedge clk)` with `if (rst)` to `always @(posedge clk or negedge rst_n)` with `if (!rst_n)`.
- Use standard cell mapping for the S-Boxes, or run logic optimization to share logic gates inside the combinational logic.

---

## Repository Structure

- `rtl/aes_sbox.v`: Combined forward/inverse S-Box lookup table.
- `rtl/aes_mixcolumns.v`: Combined MixColumns/InvMixColumns block.
- `rtl/aes_key_expand.v`: Bidirectional key expander.
- `rtl/aes_core.v`: FSM controller and datapath block.
- `rtl/aes_top.v`: Top boundary wrapper with input/output isolation registers.
- `tb/tb_aes_top.v`: Self-checking testbench with NIST FIPS 197 and SP 800-38A known-answer test vectors.
