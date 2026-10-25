// Pin-faithful, clockless behavioral reconstruction of the Datel LZ9FC17.
//
module LZ9FC17 #(
    parameter [9:0] CUSTOM_OUTPUT_MASK = 10'h3ff
) (
    inout  wire [15:0] ad,
    input  wire        ale_h,
    input  wire        ale_l,
    input  wire        read_n,
    input  wire        write_n,
    input  wire        cold_reset_n,
    input  wire        bypass,
    input  wire        button,
    inout  wire [9:0]  custom_io,
    output wire        custom_bit10,
    output wire        secondary_n,
    output wire        read_cart_n,
    output wire        write_cart_n,
    output wire [18:0] sst_address,
    output wire        rom_oe_n,
    output wire        internal_write_n,
    output wire        rom_ce_n,
    output wire        pin36_low
);

  reg [15:0] address_upper;
  reg [15:0] address_lower;
  reg [7:0]  io_base;
  reg [9:0]  custom_direction;
  reg [10:0] custom_data;
  reg        custom_bit10_enable;
  reg        read_block_a;
  reg        read_block_c;

  reg        transaction_tag;
  reg        completed_tag;
  reg [19:0] burst_index;
  wire       cycle_idle = read_n & write_n;
  wire [19:0] current_burst_index =
      (transaction_tag != completed_tag) ? 20'd0 : burst_index;
  wire [31:0] latched_address = {address_upper, address_lower};
  wire [31:0] cycle_address =
      latched_address + {11'd0, current_burst_index, 1'b0};

  always @(negedge ale_h or negedge cold_reset_n) begin
    if (!cold_reset_n)
      address_upper <= 16'd0;
    else
      address_upper <= bypass ? 16'd0 : ad;
  end

  always @(negedge ale_l or negedge cold_reset_n) begin
    if (!cold_reset_n) begin
      address_lower  <= 16'd0;
      transaction_tag <= 1'b0;
    end else begin
      address_lower  <= bypass ? 16'd0 : ad;
      transaction_tag <= ~transaction_tag;
    end
  end

  always @(posedge cycle_idle or negedge cold_reset_n) begin
    if (!cold_reset_n) begin
      completed_tag <= 1'b0;
      burst_index   <= 20'd0;
    end else if (transaction_tag != completed_tag) begin
      completed_tag <= transaction_tag;
      burst_index   <= 20'd1;
    end else begin
      burst_index   <= burst_index + 20'd1;
    end
  end

  wire address_match = !bypass && cycle_address[31:24] == io_base;
  wire [3:0] section = cycle_address[23:20];
  wire [23:0] relative_address = cycle_address[23:0];

  wire boot_header = section == 4'h0 && relative_address <= 24'h00003f;
  wire boot_cart = section == 4'h0 &&
                   relative_address >= 24'h000040 &&
                   relative_address <= 24'h000fff;
  wire boot_code = section == 4'h0 &&
                   relative_address >= 24'h001000 &&
                   relative_address <= 24'h01ffff;
  wire boot_zero = relative_address >= 24'h020000 &&
                   relative_address <= 24'h2fffff;
  wire special_valid = (section == 4'he || section == 4'hf) &&
                       !cycle_address[1];
  wire flash_window = boot_header || boot_code || section == 4'h3 ||
                      section == 4'h9 || section == 4'hb ||
                      section == 4'hc || special_valid;
  wire input_register = section == 4'h4 && cycle_address[13:10] == 4'b0000;
  wire secondary_window = section == 4'h5;

  wire internal_write_window = boot_header || boot_code || section == 4'h3 ||
                               section == 4'h4 || section == 4'h5 ||
                               section == 4'h9 || section == 4'hb ||
                               section == 4'hc || section == 4'he ||
                               section == 4'hf;

  wire block_unmatched_read = !address_match && (read_block_a || read_block_c);
  wire drive_zero_read = address_match && boot_zero;
  wire drive_input_read = address_match && input_register;

  wire ad_output_enable = bypass || (!read_n &&
      (block_unmatched_read || drive_zero_read || drive_input_read));
  wire [15:0] input_word = {5'b11111, button, custom_io};
  wire [15:0] ad_output = (drive_input_read && !bypass) ? input_word : 16'h0000;
  assign ad = ad_output_enable ? ad_output : 16'hzzzz;

  genvar custom_bit;
  generate
    for (custom_bit = 0; custom_bit < 10; custom_bit = custom_bit + 1) begin : g_custom
      assign custom_io[custom_bit] = custom_direction[custom_bit] &&
                                      CUSTOM_OUTPUT_MASK[custom_bit]
                                      ? custom_data[custom_bit] : 1'bz;
    end
  endgenerate
  assign custom_bit10 = custom_bit10_enable ? custom_data[10] : 1'bz;

  always @(posedge write_n or negedge cold_reset_n) begin
    if (!cold_reset_n) begin
      io_base              <= 8'h10;
      custom_direction     <= 10'h000;
      custom_data          <= 11'h000;
      custom_bit10_enable  <= 1'b0;
      read_block_a         <= 1'b0;
      read_block_c         <= 1'b0;
    end else if (!bypass && address_match && section == 4'h4) begin
      case (cycle_address[13:9])
        5'b00010: io_base <= ad[7:0];
        5'b00011: custom_direction <= ad[9:0];
        5'b00100: begin
          custom_data <= ad[10:0];
          custom_bit10_enable <= 1'b1;
        end
        5'b00101: read_block_a <= |ad;
        5'b00110: read_block_c <= (|(ad & 16'h775f)) && !(|(ad & 16'h08a0));
        default: ;
      endcase
    end
  end

  assign read_cart_n = bypass ? read_n :
      ~(!read_n && ((!address_match && !block_unmatched_read) ||
                    (address_match && boot_cart)));
  assign write_cart_n = bypass ? write_n :
      ~(!write_n && !address_match);
  assign secondary_n = ~(!bypass && address_match && secondary_window &&
                         (!read_n || !write_n));
  assign rom_oe_n = ~(!bypass && address_match &&
                      ((!read_n && flash_window) ||
                       (!read_n && secondary_window) ||
                       (!read_n && (section == 4'he || section == 4'hf))));
  assign internal_write_n = ~(!bypass && address_match &&
                              !write_n && internal_write_window);
  assign rom_ce_n = ~(!bypass && address_match && flash_window &&
                      (!read_n || !write_n));
  assign pin36_low = 1'b0;

  function [18:0] direct_address;
    input [31:0] address;
    begin
      direct_address = address[19:1];
    end
  endfunction

  function [18:0] section3_primary;
    input [31:0] a;
    begin
      section3_primary[5] = a[1];
      section3_primary[9] = a[2];
      section3_primary[8] = a[3];
      section3_primary[3] = a[4];
      section3_primary[4] = a[5];
      section3_primary[0] = a[6];
      section3_primary[6] = a[7];
      section3_primary[7] = a[8];
      section3_primary[1] = a[9];
      section3_primary[2] = a[10];
      section3_primary[18:10] = a[19:11];
    end
  endfunction

  function [18:0] section3_secondary;
    input [31:0] a;
    begin
      section3_secondary[0] = a[1];
      section3_secondary[9] = a[2];
      section3_secondary[8] = ~a[3];
      section3_secondary[3] = a[4];
      section3_secondary[4] = a[5];
      section3_secondary[5] = a[6];
      section3_secondary[6] = a[7];
      section3_secondary[7] = a[8];
      section3_secondary[1] = a[9];
      section3_secondary[2] = ~a[10];
      section3_secondary[18:10] = a[19:11];
    end
  endfunction

  function [18:0] section9_primary;
    input [31:0] a;
    begin
      section9_primary[9] = a[1];
      section9_primary[8] = a[2];
      section9_primary[0] = a[3];
      section9_primary[3] = a[4];
      section9_primary[5] = a[5];
      section9_primary[1] = a[6];
      section9_primary[6] = a[7];
      section9_primary[7] = a[8];
      section9_primary[2] = a[9];
      section9_primary[4] = a[10];
      section9_primary[18:10] = a[19:11];
    end
  endfunction

  function [18:0] section9_secondary;
    input [31:0] a;
    begin
      section9_secondary[9] = a[1];
      section9_secondary[8] = a[2];
      section9_secondary[0] = a[3];
      section9_secondary[3] = a[4];
      section9_secondary[5] = a[5];
      section9_secondary[1] = a[6];
      section9_secondary[6] = a[7];
      section9_secondary[7] = a[8];
      section9_secondary[4] = a[9];
      section9_secondary[2] = a[10];
      section9_secondary[18:10] = a[19:11];
    end
  endfunction

  function [18:0] section_b_scramble;
    input [31:0] a;
    begin
      section_b_scramble[5] = a[1];
      section_b_scramble[2] = a[2];
      section_b_scramble[0] = a[3];
      section_b_scramble[3] = a[4];
      section_b_scramble[8] = ~a[5];
      section_b_scramble[4] = a[6];
      section_b_scramble[6] = a[7];
      section_b_scramble[7] = a[8];
      section_b_scramble[1] = ~a[9];
      section_b_scramble[9] = ~a[10];
      section_b_scramble[18:10] = a[19:11];
    end
  endfunction

  reg [18:0] decoded_sst_address;
  always @* begin
    if (section == 4'he || section == 4'hf) begin
      decoded_sst_address[0] = cycle_address[20];
      decoded_sst_address[18:1] = cycle_address[19:2];
    end else if (io_base[6]) begin
      decoded_sst_address = direct_address(cycle_address);
    end else begin
      case (section)
        4'h3: decoded_sst_address = io_base[5]
                    ? section3_secondary(cycle_address)
                    : section3_primary(cycle_address);
        4'h9: decoded_sst_address = io_base[5]
                    ? section9_secondary(cycle_address)
                    : section9_primary(cycle_address);
        4'hb: decoded_sst_address = section_b_scramble(cycle_address);
        default: decoded_sst_address = direct_address(cycle_address);
      endcase
    end
  end

  assign sst_address = bypass ? current_burst_index[18:0]
                              : decoded_sst_address;

endmodule
