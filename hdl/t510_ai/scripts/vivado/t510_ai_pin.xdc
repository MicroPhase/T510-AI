# T510 QSFP0 pinout for T510_100g_full_system_top

###############################################################################
# QSFP0 reference clock
###############################################################################

set_property PACKAGE_PIN M28 [get_ports refclk_p]
set_property PACKAGE_PIN M29 [get_ports refclk_n]

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


set_property  -dict {PACKAGE_PIN  A10   IOSTANDARD LVCMOS33} [get_ports qsfp_link_up]
set_property  -dict {PACKAGE_PIN  A9    IOSTANDARD LVCMOS33} [get_ports qsfp_activity]   
set_property  -dict {PACKAGE_PIN  A10   IOSTANDARD LVCMOS33} [get_ports qsfp_link_up]
set_property  -dict {PACKAGE_PIN  C9    IOSTANDARD LVCMOS33} [get_ports sysref_req]  
set_property  -dict {PACKAGE_PIN  G12   IOSTANDARD LVCMOS33} [get_ports i2c_scl_io]   
set_property  -dict {PACKAGE_PIN  F12   IOSTANDARD LVCMOS33} [get_ports i2c_sda_io]  
set_property  -dict {PACKAGE_PIN  D9    IOSTANDARD LVCMOS33} [get_ports i2c_rst_n]  

set_property -dict {PACKAGE_PIN AG17 IOSTANDARD DIFF_SSTL12} [get_ports user_clk_p]
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD DIFF_SSTL12} [get_ports user_clk_n]
set_property -dict {PACKAGE_PIN AG15 IOSTANDARD DIFF_SSTL12} [get_ports pl_sysref_in_p]
set_property -dict {PACKAGE_PIN AH15 IOSTANDARD DIFF_SSTL12} [get_ports pl_sysref_in_n]
