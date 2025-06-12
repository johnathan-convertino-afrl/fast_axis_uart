//******************************************************************************
// file:    fast_axis_uart.v
//
// author:  JAY CONVERTINO
//
// date:    2025/06/11
//
// about:   Brief
// Fast UART AXIS core that allows for back to back transmissions.
//
// license: License MIT
// Copyright 2025 Jay Convertino
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
//******************************************************************************

`resetall
`timescale 1 ns/10 ps
`default_nettype none

/*
 * Module: fast_axis_uart
 *
 * AXIS UART, fast simple UART with AXI Streaming interface.
 *
 * Parameters:
 *
 *   CLOCK_SPEED      - This is the aclk frequency in Hz
 *   BAUD_RATE        - Serial Baud, this can be any value including non-standard.
 *   PARITY_TYPE      - Set the parity type, 0 = none, 1 = odd, 2 = even, 3 = mark, 4 = space.
 *   STOP_BITS        - Number of stop bits, 1 to crazy non-standard amounts. If you use 0, you will break the protocol.
 *   DATA_BITS        - Number of data bits, 1 to 8.
 *   RX_BAUD_DELAY    - Delay in rx baud enable. This will delay when we sample a bit (default is midpoint when rx delay is 0).
 *   TX_BAUD_DELAY    - Delay in tx baud enable. This will delay the time the bit output starts.
 *
 * Ports:
 *
 *   aclk           - Clock for AXIS
 *   arstn          - Negative reset for AXIS
 *   parity_err     - Indicates error with parity check (active high)
 *   frame_err      - Indicates error with frame (active high)
 *   s_axis_tdata   - Input data for UART TX.
 *   s_axis_tvalid  - When set active high the input data is valid
 *   s_axis_tready  - When active high the device is ready for input data.
 *   m_axis_tdata   - Output data from UART RX
 *   m_axis_tvalid  - When active high the output data is valid
 *   m_axis_tready  - When set active high the output device is ready for data.
 *   tx             - transmit for UART (output to RX)
 *   rx             - receive for UART (input from TX)
 */
module fast_axis_uart #(
    parameter CLOCK_SPEED   = 2000000,
    parameter BAUD_RATE     = 2000000,
    parameter PARITY_TYPE   = 0,
    parameter STOP_BITS     = 1,
    parameter DATA_BITS     = 8,
    parameter RX_BAUD_DELAY = 0,
    parameter TX_BAUD_DELAY = 0
  ) 
  (
    input   wire         aclk,
    input   wire         arstn,
    output  wire         parity_err,
    output  wire         frame_err,
    input   wire [ 7:0]  s_axis_tdata,
    input   wire         s_axis_tvalid,
    output  wire         s_axis_tready,
    output  wire [ 7:0]  m_axis_tdata,
    output  wire         m_axis_tvalid,
    input   wire         m_axis_tready,
    output  wire         tx,
    input   wire         rx
  );
  
  localparam PARITY_LEN = (PARITY_TYPE > 0 ? 1 : 0);
  
  //total bits pre trans including start bit
  localparam BITS_PER_TRANS = DATA_BITS + PARITY_LEN + STOP_BITS + 1;
  
  wire uart_ena_tx;
  wire uart_ena_rx;
  wire uart_clr_rx_clk;
  wire uart_clr_tx_clk;
  
  wire parity_bit;
  
  wire s_tx_ready;
  
  wire [BITS_PER_TRANS-1:0] s_input_data;
  
  wire [ 7:0] s_tx_counter;
  wire [ 7:0] s_rx_counter;
  
  wire [31:0] s_output_data;
  
  reg [ 7:0] r_m_axis_tdata;
  reg        r_m_axis_tvalid;
  
  reg r_rx;
  reg r_rx_clr;
  reg r_rx_load;
  
  assign s_input_data = {{STOP_BITS{1'b1}}, {PARITY_LEN{parity_bit}}, s_axis_tdata[DATA_BITS-1:0], 1'b0};
  
  // only ready for data when the counter has hit 0 and we have not stored valid input. We wait to load data since we want to make sure all pulses are the correct length.
  assign s_axis_tready = s_tx_ready;
  assign s_tx_ready = (s_tx_counter == 0 ? 1'b1 : 1'b0) & arstn;
  
  // output that the current m_axis_tdata is valid.
  assign m_axis_tvalid = r_m_axis_tvalid;
  
  // output data, this doesn't matter till valid is set.
  assign m_axis_tdata = r_m_axis_tdata;
  
  // create parity bit based on selected type
  assign parity_bit = (PARITY_TYPE == 1 ? ^s_axis_tdata[DATA_BITS-1:0] ^ 1'b1 : //odd
                      (PARITY_TYPE == 2 ? ^s_axis_tdata[DATA_BITS-1:0] :        //even
                      (PARITY_TYPE == 3 ? 1'b1 :                                //mark
                      (PARITY_TYPE == 4 ? 1'b0 : 1'b0))));                      //space
  
  // output frame error when valid data is present
  assign frame_err = ~s_output_data[STOP_BITS+PARITY_LEN+DATA_BITS] & r_m_axis_tvalid;
  
  // output parity error when valid data is present.
  assign parity_err = (PARITY_TYPE == 1 ? ^s_output_data[DATA_BITS:1] ^ 1'b1 ^ s_output_data[DATA_BITS+PARITY_LEN] : //odd
                      (PARITY_TYPE == 2 ? ^s_output_data[DATA_BITS:1] ^ s_output_data[DATA_BITS+PARITY_LEN] :        //even
                      (PARITY_TYPE == 3 ? 1'b1 == s_output_data[DATA_BITS+PARITY_LEN]:                               //mark
                      (PARITY_TYPE == 4 ? 1'b0 == s_output_data[DATA_BITS+PARITY_LEN]: 1'b0)))) & r_m_axis_tvalid;   //space

  //Group: Instantiated Modules
  /*
   * Module: uart_baud_gen_tx
   *
   * Generates TX BAUD rate for UART modules using modulo divide method.
   */
  mod_clock_ena_gen #(
    .CLOCK_SPEED(CLOCK_SPEED),
    .DELAY(TX_BAUD_DELAY)
  ) uart_baud_gen_tx (
    .clk(aclk),
    .rstn(arstn),
    .start0(1'b1),
    .clr(s_tx_ready),
    .hold(1'b0),
    .rate(BAUD_RATE),
    .ena(uart_ena_tx)
  );
  
  /*
   * Module: uart_baud_gen_rx
   *
   * Generates RX BAUD rate for UART modules using modulo divide method.
   */
  mod_clock_ena_gen #(
    .CLOCK_SPEED(CLOCK_SPEED),
    .DELAY(RX_BAUD_DELAY)
  ) uart_baud_gen_rx (
    .clk(aclk),
    .rstn(arstn),
    .start0(1'b0),
    .clr(r_rx_clr),
    .hold(1'b0),
    .rate(BAUD_RATE),
    .ena(uart_ena_rx)
  );
  
  /*
   * Module: inst_sipo
   *
   * Captures RX data for uart receive
   */
  sipo #(
    .BUS_WIDTH(4)
  ) inst_sipo (
    .clk(aclk),
    .rstn(arstn),
    .ena(uart_ena_rx),
    .rev(1'b1),
    .load(r_rx_load),
    .pdata(s_output_data),
    .reg_count_amount(BITS_PER_TRANS),
    .sdata(r_rx),
    .dcount(s_rx_counter)
  );
  
  /*
   * Module: inst_piso
   *
   * Generates TX data for uart transmit
   */
  piso #(
    .BUS_WIDTH(4),
    .DEFAULT_RESET_VAL(1),
    .DEFAULT_SHIFT_VAL(1)
  ) inst_piso (
    .clk(aclk),
    .rstn(arstn),
    .ena(uart_ena_tx),
    .rev(1'b1),
    .load(s_axis_tvalid & s_tx_ready),
    .pdata({{32-BITS_PER_TRANS{1'b1}}, s_input_data}),
    .reg_count_amount(BITS_PER_TRANS),
    .sdata(tx),
    .dcount(s_tx_counter)
  );
  
  // for detection of incoming transmissions (RX)
  always @(posedge aclk)
  begin
    if(arstn == 1'b0)
    begin
      r_rx <= 1'b1;
      
      r_rx_clr  <= 1'b1;
      r_rx_load <= 1'b0;
      
      r_m_axis_tdata  <= 0;
      r_m_axis_tvalid <= 1'b0;
    end else begin
      r_rx <= rx;
      
      r_rx_load <= 1'b0;
      
      if(m_axis_tready == 1'b1)
      begin
        r_m_axis_tdata  <= 0;
        r_m_axis_tvalid <= 1'b0;
      end
      
      if(r_rx == 1'b1 && rx == 1'b0 && r_rx_clr == 1'b1)
      begin
        r_rx_clr <= 1'b0;
      end
      
      if(s_rx_counter == BITS_PER_TRANS && r_rx_load != 1'b1)
      begin
        r_m_axis_tdata  <= s_output_data[DATA_BITS:1];
        r_m_axis_tvalid <= 1'b1;
        
        r_rx_load <= 1'b1;
        r_rx_clr  <= 1'b1;
      end
    end
  end
 
endmodule

`resetall
