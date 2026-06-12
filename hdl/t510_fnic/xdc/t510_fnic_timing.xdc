# T510-FNIC basic timing constraints.

###############################################################################
# Debug and CDC helper constraints
###############################################################################

set_false_path -to [get_pins -hierarchical -filter {NAME =~ */synchronizer_false_path/stages[0].value_reg[0][*]/D}]

###############################################################################
# Low-speed status outputs
###############################################################################

set_max_delay -to [get_ports {qsfp_link_up qsfp_activity}] 50.000
set_min_delay -to [get_ports {qsfp_link_up qsfp_activity}] 0.000
