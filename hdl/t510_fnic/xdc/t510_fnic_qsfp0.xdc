# T510-FNIC Aurora bring-up pinout.
# This reuses the T510-AI QSFP0 pin mapping and replaces the 100G MAC with
# a 4-lane Aurora 64B/66B link.

###############################################################################
# QSFP0 reference clock, 156.25 MHz
###############################################################################

set_property PACKAGE_PIN M28 [get_ports refclk_p]
set_property PACKAGE_PIN M29 [get_ports refclk_n]
create_clock -name qsfp0_refclk -period 6.400 [get_ports refclk_p]

###############################################################################
# QSFP0 low-speed control pins
###############################################################################

set_property PACKAGE_PIN K10 [get_ports qsfp0_modprs_n]
set_property PACKAGE_PIN J11 [get_ports qsfp0_reset_n]
set_property PACKAGE_PIN K12 [get_ports qsfp0_lpmode_n]
set_property IOSTANDARD LVCMOS33 [get_ports {qsfp0_modprs_n qsfp0_reset_n qsfp0_lpmode_n}]
set_property SLEW       SLOW     [get_ports {qsfp0_reset_n qsfp0_lpmode_n}]

###############################################################################
# QSFP0 high-speed lanes
###############################################################################

set_property PACKAGE_PIN P33 [get_ports {rx_p[0]}]
set_property PACKAGE_PIN P34 [get_ports {rx_n[0]}]
set_property PACKAGE_PIN N30 [get_ports {tx_p[0]}]
set_property PACKAGE_PIN N31 [get_ports {tx_n[0]}]

set_property PACKAGE_PIN M33 [get_ports {rx_p[1]}]
set_property PACKAGE_PIN M34 [get_ports {rx_n[1]}]
set_property PACKAGE_PIN L30 [get_ports {tx_p[1]}]
set_property PACKAGE_PIN L31 [get_ports {tx_n[1]}]

set_property PACKAGE_PIN K33 [get_ports {rx_p[2]}]
set_property PACKAGE_PIN K34 [get_ports {rx_n[2]}]
set_property PACKAGE_PIN J30 [get_ports {tx_p[2]}]
set_property PACKAGE_PIN J31 [get_ports {tx_n[2]}]

set_property PACKAGE_PIN H33 [get_ports {rx_p[3]}]
set_property PACKAGE_PIN H34 [get_ports {rx_n[3]}]
set_property PACKAGE_PIN G30 [get_ports {tx_p[3]}]
set_property PACKAGE_PIN G31 [get_ports {tx_n[3]}]

###############################################################################
# Status outputs
###############################################################################

set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports qsfp_link_up]
set_property -dict {PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports qsfp_activity]
set_property -dict {PACKAGE_PIN C9  IOSTANDARD LVCMOS33} [get_ports sysref_req]

###############################################################################
# PL init clock for Aurora reset/init logic
###############################################################################

set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVCMOS33} [get_ports user_clk]
create_clock -name user_init_clk -period 20.000 [get_ports user_clk]

###############################################################################
# RFDC AXIS/user clock and PL SYSREF monitor input
###############################################################################

set_property -dict {PACKAGE_PIN AG17 IOSTANDARD DIFF_SSTL12} [get_ports rfdc_user_clk_p]
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD DIFF_SSTL12} [get_ports rfdc_user_clk_n]
create_clock -name rfdc_user_clk -period 4.069 [get_ports rfdc_user_clk_p]

set_property -dict {PACKAGE_PIN AG15 IOSTANDARD DIFF_SSTL12} [get_ports pl_sysref_in_p]
set_property -dict {PACKAGE_PIN AH15 IOSTANDARD DIFF_SSTL12} [get_ports pl_sysref_in_n]
