# Voltage Settings
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Clock Signal
set_property PACKAGE_PIN W5 [get_ports sys_clk]							
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports sys_clk]

## Reset Button
set_property PACKAGE_PIN U18 [get_ports sys_rst_btn]						
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_btn]
set_false_path -from [get_ports sys_rst_btn]

## Done LED 
set_property PACKAGE_PIN L1 [get_ports done_led]
set_property IOSTANDARD LVCMOS33 [get_ports done_led]

## Debug LEDs
set_property PACKAGE_PIN U16 [get_ports {debug_led[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[0]}]
set_property PACKAGE_PIN E19 [get_ports {debug_led[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[1]}]
set_property PACKAGE_PIN U19 [get_ports {debug_led[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[2]}]
set_property PACKAGE_PIN V19 [get_ports {debug_led[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {debug_led[3]}]
set_false_path -to [get_ports done_led]
set_false_path -to [get_ports {debug_led[*]}]

## UART RX Pin
set_property PACKAGE_PIN B18 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_input_delay -clock [get_clocks sys_clk_pin] -min 2.000 [get_ports uart_rx_pin]
set_input_delay -clock [get_clocks sys_clk_pin] -max 5.000 [get_ports uart_rx_pin]
