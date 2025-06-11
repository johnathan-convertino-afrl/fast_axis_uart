# FAST AXIS UART
### Minimal UART for fast transmissions

![image](docs/manual/img/AFRL.png)

---

  author: Jay Convertino   
  
  date: 2025.06.11  
  
  details: Interface UART data at some baud to a axi streaming 8 bit interface.   
  
  license: MIT   
   
  Actions:  

  [![Lint Status](../../actions/workflows/lint.yml/badge.svg)](../../actions)  
  [![Manual Status](../../actions/workflows/manual.yml/badge.svg)](../../actions)  
  
---

### Version
#### Current
  - v1.0.0 - initial release

#### Previous
  - none

### DOCUMENTATION
  For detailed usage information, please navigate to one of the following sources. They are the same, just in a different format.

  - [fast_axis_uart.pdf](docs/manual/fast_axis_uart.pdf)
  - [github page](https://johnathan-convertino-afrl.github.io/fast_axis_uart/)

### PARAMETERS

  * CLOCK_SPEED       - Clock speed of the baud clock. Best if it is a integer multiple of the baud rate, but does not have to be.
  * BAUD_RATE         - Baud rate of the input/output data for the core.
  * PARITY_TYPE       - Set the parity type, 0 = none, 1 = odd, 2 = even, 3 = mark, 4 = space.
  * STOP_BITS         - Number of stop bits, 0 to to some amount that is less than the total of: PARITY_BIT + DATA_BITS + START_BIT.
  * DATA_BITS         - Number of data bits, 1 to 8.
  * RX_BAUD_DELAY     - Delay in rx baud enable. This will delay when we sample a bit (default is midpoint when rx delay is 0).
  * TX_BAUD_DELAY     - Delay in tx baud enable. This will delay the time the bit output starts.

### COMPONENTS
#### SRC

* fast_axis_uart.v
  
#### TB

* tb_cocotb_full
  
### FUSESOC

* fusesoc_info.core created.
* Simulation uses icarus to run data through the core.

#### targets

* RUN WITH: (fusesoc run --target=sim VENDER:CORE:NAME:VERSION)
  - default (for IP integration builds)
  - lint
  - sim_cocotb_full

