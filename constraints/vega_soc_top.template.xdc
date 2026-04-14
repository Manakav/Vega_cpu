## vega_soc_top XDC template
## Fill pin names based on your FPGA board manual.

## Clock
# set_property PACKAGE_PIN <CLK_PIN> [get_ports clk_in]
# set_property IOSTANDARD LVCMOS18 [get_ports clk_in]
# create_clock -name sys_clk -period 10.000 [get_ports clk_in]

## Reset (active low)
# set_property PACKAGE_PIN <RST_PIN> [get_ports rst_n_in]
# set_property IOSTANDARD LVCMOS18 [get_ports rst_n_in]
# set_property PULLUP true [get_ports rst_n_in]

## UART
# set_property PACKAGE_PIN <UART_TX_PIN> [get_ports uart_tx_o]
# set_property IOSTANDARD LVCMOS18 [get_ports uart_tx_o]
# set_property PACKAGE_PIN <UART_RX_PIN> [get_ports uart_rx_i]
# set_property IOSTANDARD LVCMOS18 [get_ports uart_rx_i]

## LEDs
# set_property PACKAGE_PIN <LED0_PIN> [get_ports {led_o[0]}]
# set_property PACKAGE_PIN <LED1_PIN> [get_ports {led_o[1]}]
# set_property PACKAGE_PIN <LED2_PIN> [get_ports {led_o[2]}]
# set_property PACKAGE_PIN <LED3_PIN> [get_ports {led_o[3]}]
# set_property IOSTANDARD LVCMOS18 [get_ports {led_o[*]}]

## Optional timing exceptions (example only)
# set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks uart_ref]
