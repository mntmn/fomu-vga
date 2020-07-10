`ifdef EVT
 `define BLUEPWM  RGB0PWM
 `define REDPWM   RGB1PWM
 `define GREENPWM RGB2PWM
`elsif HACKER
 `define BLUEPWM  RGB0PWM
 `define GREENPWM RGB1PWM
 `define REDPWM   RGB2PWM
`elsif PVT
 `define GREENPWM RGB0PWM
 `define REDPWM   RGB1PWM
 `define BLUEPWM  RGB2PWM
`else
`error_board_not_supported
`endif

  module blink (
                // 48MHz Clock input
                // --------
                input clki,
                // LED outputs
                // --------
                output rgb0,
                output rgb1,
                output rgb2,
                output user_1,
                output user_2,
                output user_3,
                output user_4,
                // USB Pins (which should be statically driven if not being used).
                // --------
                inout usb_dp,
                inout usb_dn,
                output usb_dp_pu
                );

  reg[6:0] usb_addr;
  wire usb_setup;
  wire[3:0] usb_endpoint;
  reg[7:0] usb_data_in;
  reg usb_data_in_valid;
  wire[7:0] usb_data_out;
  reg usb_data_strobe;
  wire usb_reset;
  
  wire usb_tx_se0, usb_tx_j, usb_tx_en;
  usb usb0(
           .rst_n(1),
           .clk_48(clki),
           .handshake(2'b01), // not sure how to control this

           .setup(usb_setup),
           .data_out(usb_data_out),
           .data_in(usb_data_in),
           .data_in_valid(usb_data_in_valid),
           .data_strobe(usb_data_strobe),
           .data_toggle(0),
           .usb_rst(usb_reset),
           
           .rx_j(usb_dp),
           .rx_se0(!usb_dp && !usb_dn),

           .tx_se0(usb_tx_se0),
           .tx_j(usb_tx_j),
           .tx_en(usb_tx_en)
           );

  assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
  assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;

  assign usb_dp_pu = 1'b1;

  reg[7:0] usb_data_ptr = 0;

  always @(posedge clki) begin
    if (usb_data_strobe) begin
      usb_data_in_valid <= 1'b1;

      case (usb_data_ptr)
        0: usb_data_in <= 18;
        1: usb_data_in <= 1;
        2: usb_data_in <= 8'h00;
        3: usb_data_in <= 8'h02;
        
        4: usb_data_in <= 8'hff;
        5: usb_data_in <= 8'h00;
        6: usb_data_in <= 8'h00;
        
        7: usb_data_in <= 64;
        
        8: usb_data_in <= 8'hde;
        9: usb_data_in <= 8'had;
        10: usb_data_in <= 8'hbe;
        11: usb_data_in <= 8'hef;

        12: usb_data_in <= 0;
        13: usb_data_in <= 0;
        14: usb_data_in <= 0;
        15: usb_data_in <= 0;
        16: usb_data_in <= 0;
        17: usb_data_in <= 1;

        default: usb_data_in <= 0;
      endcase

      usb_data_ptr <= usb_data_ptr + 1'b1;
    end else
      usb_data_in_valid <= 0;
  end
  
  // Connect to system clock (with buffering)
  wire clk;
  SB_GB clk_gb (
                .USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
                .GLOBAL_BUFFER_OUTPUT(clk)
                );

  wire hs;
  wire vs;
  reg pixel;

  assign user_1 = hs;
  assign user_2 = vs;
  assign user_3 = pixel;
  assign user_4 = usb_data_out[0];

  SB_PLL40_CORE #(
                  .FEEDBACK_PATH("SIMPLE"),
                  .DIVR(4'b0010),
                  .DIVF(7'b0100111),
                  .DIVQ(3'b100),
                  .FILTER_RANGE(3'b001),
                  ) uut (
                         .REFERENCECLK   (clki),
                         .PLLOUTCORE     (pixclk),
                         .BYPASS         (1'b0),
                         .RESETB         (1'b1)
                         );

  localparam SB_IO_TYPE_SIMPLE_INPUT = 6'b000001;

  // Use counter logic to divide system clock.  The clock is 48 MHz,
  // so we divide it down by 2^28.
  reg [10:0] counter_x = 0;
  reg [10:0] counter_y = 0;

  // 800 840 968 1056 600 601 605 628 @ 40MHz
  
  localparam HS_START = 16;
  localparam HS_END = 16+(968-840);
  localparam H_TOTAL = 1056;
  
  localparam VS_START = 601;
  localparam VS_END = 605;
  localparam V_TOTAL = 628;
  
  assign hs = ~((counter_x >= HS_START) & (counter_x < HS_END));
  assign vs = ~((counter_y >= VS_START) & (counter_y < VS_END));
  
  always @(posedge pixclk) begin
    if (counter_x < H_TOTAL)
      counter_x <= counter_x + 1;
    else begin
      counter_x <= 0;
      if (counter_y < V_TOTAL)
        counter_y <= counter_y + 1;
      else
        counter_y <= 0;
    end

    if (counter_x>300 && counter_x<400 && counter_y>200 && counter_y<300)
      pixel = 1;
    else
      pixel = 0;
  end

  // Instantiate iCE40 LED driver hard logic, connecting up
  // latched button state, counter state, and LEDs.
  //
  // Note that it's possible to drive the LEDs directly,
  // however that is not current-limited and results in
  // overvolting the red LED.
  //
  // See also:
  // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668
  SB_RGBA_DRV RGBA_DRIVER (
                           .CURREN(1'b1),
                           .RGBLEDEN(1'b1),
                           .`BLUEPWM(vs),     // Blue
                           .`REDPWM(1'b0),       // Red
                           .`GREENPWM(1'b0),    // Green
                           .RGB0(rgb0),
                           .RGB1(rgb1),
                           .RGB2(rgb2)
                           );

  // Parameters from iCE40 UltraPlus LED Driver Usage Guide, pages 19-20
  localparam RGBA_CURRENT_MODE_FULL = "0b0";
  localparam RGBA_CURRENT_MODE_HALF = "0b1";

  // Current levels in Full / Half mode
  localparam RGBA_CURRENT_04MA_02MA = "0b000001";
  localparam RGBA_CURRENT_08MA_04MA = "0b000011";
  localparam RGBA_CURRENT_12MA_06MA = "0b000111";
  localparam RGBA_CURRENT_16MA_08MA = "0b001111";
  localparam RGBA_CURRENT_20MA_10MA = "0b011111";
  localparam RGBA_CURRENT_24MA_12MA = "0b111111";

  // Set parameters of RGBA_DRIVER (output current)
  //
  // Mapping of RGBn to LED colours determined experimentally
  defparam RGBA_DRIVER.CURRENT_MODE = RGBA_CURRENT_MODE_HALF;
  defparam RGBA_DRIVER.RGB0_CURRENT = RGBA_CURRENT_16MA_08MA;  // Blue - Needs more current.
  defparam RGBA_DRIVER.RGB1_CURRENT = RGBA_CURRENT_08MA_04MA;  // Red
  defparam RGBA_DRIVER.RGB2_CURRENT = RGBA_CURRENT_08MA_04MA;  // Green

endmodule
