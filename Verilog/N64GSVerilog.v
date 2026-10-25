// EPM240 compatibility wrapper for the recovered LZ9FC17 core.
//
module N64GSVerilog (
    ad, aleh, alel, button, clk, cold_reset,
    pic_gp4, pic_gp5, read,
    remote_d0, remote_d1, remote_d2, remote_d3, remote_data_ready,
    write, cp, dsab, pport_cp, read_top, sst, sst_ce, sst_oe
);

  inout [15:0] ad;
  input aleh;
  input alel;
  input button;
  input clk;                 // retained for PCB/project compatibility; unused
  input cold_reset;
  inout pic_gp4;
  inout pic_gp5;
  input read;
  inout remote_d0;
  inout remote_d1;
  inout remote_d2;
  inout remote_d3;
  inout remote_data_ready;
  input write;
  output cp;
  inout dsab;
  output pport_cp;
  output read_top;
  output [18:0] sst;
  output sst_ce;
  output sst_oe;

  wire [9:0] custom_bus;
  wire unused_write_cart_n;
  wire unused_internal_write_n;
  wire unused_pin36_low;

  tran (custom_bus[0], remote_d0);
  tran (custom_bus[1], remote_d1);
  tran (custom_bus[2], remote_d2);
  tran (custom_bus[3], remote_d3);
  tran (custom_bus[4], remote_data_ready);
  tran (custom_bus[5], pic_gp4);
  tran (custom_bus[6], pic_gp5);
  assign custom_bus[7] = 1'b1;
  assign custom_bus[8] = 1'b1;
  tran (custom_bus[9], dsab);

  LZ9FC17 #(
      .CUSTOM_OUTPUT_MASK(10'h27f)
  ) recovered (
      .ad(ad),
      .ale_h(aleh),
      .ale_l(alel),
      .read_n(read),
      .write_n(write),
      .cold_reset_n(cold_reset),
      .bypass(1'b0),
      .button(button),
      .custom_io(custom_bus),
      .custom_bit10(cp),
      .secondary_n(pport_cp),
      .read_cart_n(read_top),
      .write_cart_n(unused_write_cart_n),
      .sst_address(sst),
      .rom_oe_n(sst_oe),
      .internal_write_n(unused_internal_write_n),
      .rom_ce_n(sst_ce),
      .pin36_low(unused_pin36_low)
  );

endmodule
