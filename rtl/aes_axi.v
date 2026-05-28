`timescale 1ns/1ps

/*
 * AES-128 AXI4-Lite Wrapper
 * Maps control, status, key, input data, and output data to 32-bit registers.
 * Designed for Xilinx Vivado Block Design and integration with the Zynq Processing System (PS) on PYNQ-Z2.
 * Reset: Active-Low (s_axi_aresetn) to align with standard AXI guidelines.
 */

module aes_axi (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    
    // Write Address Channel
    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    
    // Write Data Channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    
    // Write Response Channel
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    
    // Read Address Channel
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    
    // Read Data Channel
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    // Register Registers (Byte offsets)
    // 0x00: ADDR_CTRL     (Bit 0: start pulse, Bit 1: dec)
    // 0x04: ADDR_STATUS   (Bit 0: core ready, Bit 1: out_valid_sticky)
    // 0x08: ADDR_KEY_0    (Key [127:96])
    // 0x0c: ADDR_KEY_1    (Key [95:64])
    // 0x10: ADDR_KEY_2    (Key [63:32])
    // 0x14: ADDR_KEY_3    (Key [31:0])
    // 0x18: ADDR_DIN_0    (Din [127:96])
    // 0x1c: ADDR_DIN_1    (Din [95:64])
    // 0x20: ADDR_DIN_2    (Din [63:32])
    // 0x24: ADDR_DIN_3    (Din [31:0])
    // 0x28: ADDR_DOUT_0   (Dout [127:96])
    // 0x2c: ADDR_DOUT_1   (Dout [95:64])
    // 0x30: ADDR_DOUT_2   (Dout [63:32])
    // 0x34: ADDR_DOUT_3   (Dout [31:0])

    reg [127:0] key_reg;
    reg [127:0] din_reg;
    reg         dec_reg;
    reg         start_pulse;
    reg         out_valid_sticky;
    reg [127:0] dout_reg;

    // Core instantiations
    wire         core_ready;
    wire         core_out_valid;
    wire [127:0] core_dout;

    // Use aes_top to provide boundary registers and timing isolation
    aes_top aes_inst (
        .clk(s_axi_aclk),
        .rst(!s_axi_aresetn),
        .dec(dec_reg),
        .start(start_pulse),
        .ready(core_ready),
        .out_valid(core_out_valid),
        .dout(core_dout)
    );

    // Sticky out_valid latching
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            out_valid_sticky <= 1'b0;
            dout_reg         <= 128'h0;
        end else begin
            if (start_pulse) begin
                out_valid_sticky <= 1'b0;
            end else if (core_out_valid) begin
                out_valid_sticky <= 1'b1;
                dout_reg         <= core_dout;
            end
        end
    end

    // Write Logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            key_reg     <= 128'h0;
            din_reg     <= 128'h0;
            dec_reg     <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0; // Strobe clears automatically
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                case (s_axi_awaddr[5:2])
                    4'h0: begin // ADDR_CTRL (0x00)
                        if (s_axi_wstrb[0]) begin
                            start_pulse <= s_axi_wdata[0];
                            dec_reg     <= s_axi_wdata[1];
                        end
                    end
                    // Key writing (0x08 - 0x14)
                    4'h2: if (s_axi_wstrb[0]) key_reg[127:96] <= s_axi_wdata;
                    4'h3: if (s_axi_wstrb[0]) key_reg[95:64]  <= s_axi_wdata;
                    4'h4: if (s_axi_wstrb[0]) key_reg[63:32]  <= s_axi_wdata;
                    4'h5: if (s_axi_wstrb[0]) key_reg[31:0]   <= s_axi_wdata;
                    // Data writing (0x18 - 0x24)
                    4'h6: if (s_axi_wstrb[0]) din_reg[127:96] <= s_axi_wdata;
                    4'h7: if (s_axi_wstrb[0]) din_reg[95:64]  <= s_axi_wdata;
                    4'h8: if (s_axi_wstrb[0]) din_reg[63:32]  <= s_axi_wdata;
                    4'h9: if (s_axi_wstrb[0]) din_reg[31:0]   <= s_axi_wdata;
                    default: ;
                endcase
            end
        end
    end

    // Write Response Protocol
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                end
            end
        end
    end

    // Read Logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;
                case (s_axi_araddr[5:2])
                    4'h0: s_axi_rdata <= {30'h0, dec_reg, start_pulse};
                    4'h1: s_axi_rdata <= {30'h0, out_valid_sticky, core_ready};
                    4'h2: s_axi_rdata <= key_reg[127:96];
                    4'h3: s_axi_rdata <= key_reg[95:64];
                    4'h4: s_axi_rdata <= key_reg[63:32];
                    4'h5: s_axi_rdata <= key_reg[31:0];
                    4'h6: s_axi_rdata <= din_reg[127:96];
                    4'h7: s_axi_rdata <= din_reg[95:64];
                    4'h8: s_axi_rdata <= din_reg[63:32];
                    4'h9: s_axi_rdata <= din_reg[31:0];
                    4'ha: s_axi_rdata <= dout_reg[127:96];
                    4'hb: s_axi_rdata <= dout_reg[95:64];
                    4'hc: s_axi_rdata <= dout_reg[63:32];
                    4'hd: s_axi_rdata <= dout_reg[31:0];
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                end
            end
        end
    end

endmodule
