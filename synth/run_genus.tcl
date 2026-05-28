# ==============================================================================
# Cadence Genus RTL Synthesis Script for Compact AES-128 Core
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Setup Technology Libraries
# ------------------------------------------------------------------------------
# Define the path to your target standard cell library (.lib file).
# Update these paths to point to your specific foundry library (e.g., TSMC, GF, SkyWater)
set library_path   "/home/patna/cadence/FOUNDRY/digital/45nm/LIBS/lib/min"
set target_library "fast.lib"
set link_library   "fast.lib"

# Set Genus search paths
set_db init_lib_search_path $library_path
set_db init_hdl_search_path "../rtl"
set_db library $target_library

# ------------------------------------------------------------------------------
# 2. Read HDL Source Files
# ------------------------------------------------------------------------------
# Read Verilog source files in 2001 mode
read_hdl -v2001 {
    aes_sbox.v
    aes_mixcolumns.v
    aes_key_expand.v
    aes_core.v
    aes_top.v
}

# ------------------------------------------------------------------------------
# 3. Elabolate Design
# ------------------------------------------------------------------------------
# We synthesize the registered 'aes_top' wrapper to get clean timing reports.
set top_module "aes_top"
elaborate $top_module

# Check design for unresolved modules or issues
check_design -unresolved

# ------------------------------------------------------------------------------
# 4. Define Design Constraints (SDC)
# ------------------------------------------------------------------------------
# Create main clock (e.g., period of 10.0ns = 100MHz target frequency)
set clk_port   "clk"
set clk_period 10.0
create_clock -name clk -period $clk_period [get_ports $clk_port]

# Constrain input and output delays (assumes 20% delay external to core)
set_input_delay  -clock clk 2.0 [all_inputs -no_clocks]
set_output_delay -clock clk 2.0 [all_outputs -no_clocks]

# Set operating conditions and wire load models (optional, vendor dependent)
# set_db operating_conditions "typical"

# ------------------------------------------------------------------------------
# 5. Perform Synthesis
# ------------------------------------------------------------------------------
# Phase 1: Technology-independent logic optimization
syn_generic

# Phase 2: Map design to standard cells
syn_map

# Phase 3: Post-map gate-level timing and area optimization
syn_opt

# ------------------------------------------------------------------------------
# 6. Generate Synthesis Reports
# ------------------------------------------------------------------------------
# Create directories for output database and reports
file mkdir "../synth_out"
file mkdir "../synth_out/reports"

# Generate reports
report_area   > ../synth_out/reports/aes_top_area.rpt
report_timing > ../synth_out/reports/aes_top_timing.rpt
report_gates  > ../synth_out/reports/aes_top_gates.rpt
report_power  > ../synth_out/reports/aes_top_power.rpt

# ------------------------------------------------------------------------------
# 7. Write Outputs
# ------------------------------------------------------------------------------
# Write mapped gate-level netlist (Verilog format)
write_hdl > ../synth_out/aes_top_synth.v

# Write constraints to Synopsys Design Constraints file (SDC)
write_sdc > ../synth_out/aes_top_synth.sdc

# Write database (in case you want to load it back into Genus or Innovus)
write_design -basename ../synth_out/aes_top_mapped

puts "=========================================================================="
puts " Genus RTL Synthesis Completed Successfully!"
puts " Reports and Netlist generated in: ../synth_out"
puts "=========================================================================="
exit
