# Minimal timing constraints ported from the original T510-AI project state.
# These are the constraints that still apply to the standalone 100G + PS system.

###############################################################################
# Misc Constraints
###############################################################################

# Double synchronizer false paths.
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */synchronizer_false_path/stages[0].value_reg[0][*]/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */rf_reset_controller*/*_ms_reg/D}]

###############################################################################
# Asynchronous / misc. I/O constraints
###############################################################################

# Loosely constrain these status outputs to avoid methodology noise. They are
# driven by low-speed logic and are not part of the 100G timing closure target.
# create_clock -name async_status_clk -period 50.000
# set_output_delay -clock [get_clocks async_status_clk] 0.000 [get_ports {qsfp_link_up qsfp_activity}]
# set_max_delay -to [get_ports {qsfp_link_up qsfp_activity}] 50.000
# set_min_delay -to [get_ports {qsfp_link_up qsfp_activity}] 0.000
