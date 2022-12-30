module N64GSVerilog

(ad, aleh, alel, button, clk, cold_reset, pic_gp4, pic_gp5, read, remote_d0, remote_d1, remote_d2, remote_d3, remote_data_ready, write, cp, dsab, pport_cp, read_top, sst, sst_ce, sst_oe);

inout [15:0] ad;
input aleh;
input alel;
input button;
input clk;
input cold_reset;
input pic_gp4;
input pic_gp5;
input read;
input remote_d0;
input remote_d1;
input remote_d2;
input remote_d3;
input remote_data_ready;
input write;
output cp;
output dsab;
output pport_cp;
output read_top;
output [18:0] sst;
output sst_ce;
output sst_oe;

reg ad_out_en = 0;
reg [12:0] address_inc = 13'b0;
reg [12:0] address_inc_next = 13'b0;
reg ale_out_en = 0;
reg alel_cur;
reg aleh_cur;
reg cnt_reset = 0;
reg first_boot = 1;
reg [31:0] n64_ad_store = 32'b0;
reg [15:0] n64_data_store = 16'b0;
reg press = 0;
reg [15:0] r_ad;
reg [19:0] r_button = 20'hFFFFF;
reg r_cp = 0;
reg r_dsab = 0;
reg r_pport_cp;
reg r_rdr = 0;
reg r_rdr2 = 0;
reg r_read_top = 0;
reg [18:0] sst_address = 0;
reg [18:0] r_sst = 0;
reg r_sst_ce = 1;
reg r_sst_oe = 1;
reg [5:0] rd_cnt = 0;
reg [5:0] rd_cnt_nxt = 0;
reg read_cur;
reg read_prev;
reg seven_seg_enable = 0;
reg [5:0] wr_cnt = 0;
reg [5:0] wr_cnt_nxt = 0;
reg write_cur;
reg write_prev;

assign ad = (ale_out_en && ad_out_en) ? r_ad : 16'hZ;
assign cp = r_cp;
assign dsab = r_dsab;
assign pport_cp = r_pport_cp;
assign read_top = r_read_top;
assign sst = r_sst;
assign sst_ce = r_sst_ce;
assign sst_oe = r_sst_oe;

always @(posedge clk)

begin
	ad_out_en <= 0;
	address_inc_next <= address_inc;
	aleh_cur <= aleh;
	alel_cur <= alel;
	cnt_reset <= 0;
	press <= 0;
	r_button [19:0] <= {r_button [18:0], button};
	r_rdr <= remote_data_ready;
	r_rdr2 <= r_rdr;
	r_read_top <= read_cur;
	r_sst_ce <= 1;
	r_sst_oe <= 1;
	rd_cnt_nxt <= rd_cnt;
	read_cur <= read;
	read_prev <= read_cur;
	wr_cnt_nxt <= wr_cnt;
	write_cur <= write;
	write_prev <= write_cur;

	if (r_button [19:0] == 20'h0)	//Button debouncing
		begin
		press <= 1;
		end

	if (write_prev && !write_cur)	//Grabbing the data at the falling edge of write for internal register purposes
		begin
		n64_data_store [15:0] <= ad;
		end

	if (!read_prev && read_cur)		//Disable the CPLD driving the PI bus and increment the SST address at the rising edge of read
		begin
		address_inc <= (address_inc_next + 1'b1);
		ale_out_en <= 0;
		end

	if (read_prev && !read_cur)		//Set the SST address to the EEPROMs and enable the CPLD driving the PI bus if enabled elsewhere at the falling edge of read
		begin
		sst_address [18:0] <= (n64_ad_store [19:1] + address_inc);
		ale_out_en <= 1;
		end

	if (alel && !aleh)		//Due to the short window to work with the ALE L signal, this is the way I found to reliably grab the lower half of the address from the PI bus
		begin
		n64_ad_store [15:0] <= ad;
		address_inc <= 13'b0;
		end

	if (aleh && alel)		//This reliably grabs the upper half of the address from the PI bus
		begin
		n64_ad_store [31:16] <= ad;
		end

	if (aleh_cur || alel_cur)	//Enables resetting of the counter for pulsing the Chip Enable line during certain EEPROM reads and writes. Real hardware outputs the N64 Read signal for most of the CE and OE functions, however there are certain functions that require one CE pulse instead of the two that normally occur on the read line. Resetting the counter at an address change ensures that only one pulse is issued.
		begin
		cnt_reset <= 1;
		end

//	if ((n64_ad_store [31:20] == 12'h100) && r_cold_reset)	//My non-functioning attempt to implement address mapping that would allow this cart to work with the Sanni Cart Reader for programming. This will be implemented later, but isn't required for the device to operate properly.
//		begin
//		r_sst [18:0] <= sst_address [18:0];
//		r_read_top <= 1;
//		r_sst_oe <= read_cur;
//
//		if (!write_cur)
//			begin
//			r_sst_ce <= 0;
//			end
//
//		if (!read_cur)
//			begin
//			r_sst_ce <= 0;
//			end
//		end

	if ((n64_ad_store >= 32'h10000000) && (n64_ad_store <= 32'h10000020) && first_boot)		//Mirroring actual hardware mapping for initial boot purposes to get the Gameshark ROM into the system
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_read_top <= 1;
		r_sst_oe <= read_cur;

		if (!write)
			begin
			r_sst_ce <= 0;
			end

		if (!read)
			begin
			r_sst_ce <= 0;
			end
		end

	if ((n64_ad_store >= 32'h10001000) && (n64_ad_store <= 32'h1001FFFF) && first_boot)		//Mirroring actual hardware mapping for initial boot purposes to get the Gameshark ROM into the system
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_read_top <= 1;
		r_sst_oe <= read_cur;

		if (!write)
			begin
			r_sst_ce <= 0;
			end

		if (!read)
			begin
			r_sst_ce <= 0;
			end
		end

	if ((n64_ad_store >= 32'h10020000) && (n64_ad_store <= 32'h10100FFF) && first_boot)		//Mirroring actual hardware mapping for initial boot purposes to get the Gameshark ROM into the system
		begin
		ad_out_en <= 1;
		r_ad <= 16'b0;
		r_read_top <= 1;
		end

	if ((n64_ad_store [31:20] == 12'h10C) && first_boot)		//Mirroring actual hardware mapping for initial boot purposes to get the Gameshark ROM into the system
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_read_top <= 1;
		r_sst_oe <= read_cur;

		if (!read)
			begin
			r_sst_ce <= 0;
			end
		end

	if ((n64_ad_store == 32'h10400600) && (n64_data_store [9]) && first_boot)		//7 Segment Display Register
		begin
		seven_seg_enable <= n64_data_store [10];
		end

	if ((n64_ad_store == 32'h10400800) && seven_seg_enable && first_boot)			//7 Segment Display Register
		begin
		r_dsab <= n64_data_store [9];
		r_cp <= n64_data_store [10];
		end

	if (n64_ad_store == 32'h1E400000)		// Parallel port data-in, PIC data in (never fielded copy protection PIC), and button press detection register
		begin
		r_ad [0] <= remote_d0;
		r_ad [1] <= remote_d1;
		r_ad [2] <= remote_d2;
		r_ad [3] <= remote_d3;
		r_ad [4] <= (r_rdr && r_rdr2);
		r_ad [5] <= pic_gp4;
		r_ad [6] <= pic_gp5;
		r_ad [9:7] <= 3'h7;
		r_ad [10] <= !press;
		r_ad [15:11] <= 5'h1F;
		ad_out_en <= 1;
		r_read_top <= 1;
		end

	if ((n64_ad_store == 32'h10400400) && (n64_data_store == 16'h001E))		//This register was a good candidate to disable "first boot" address mapping, enabling game boot after the firmware is loaded. It may actually exist for some other reason, but it causes no issues to be implemented like this.
		begin
		first_boot <= 0;
		end

	if ((n64_ad_store == 32'h1E400600) && (n64_data_store [9]))			//7 Segment display register post-boot address mapping
		begin
		seven_seg_enable <= n64_data_store [10];
		end

	if ((n64_ad_store == 32'h1E400800) && seven_seg_enable)				//7 Segment display register post-boot address mapping
		begin
		r_dsab <= n64_data_store [9];
		r_cp <= n64_data_store [10];
		end

	if (n64_ad_store == 32'h1E5FFFFC)		//Parallel Port and PIC security device output register. This pulses the Clock Pulse line 
		begin
		r_pport_cp <= write_cur;
		end

	if (n64_ad_store [31:20] == 12'h1EC)		//The EEPROM is mapped here
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_sst_oe <= read_cur;
		r_read_top <= 1;

		if (!read_cur)
			begin
			r_sst_ce <= 0;
			end

		if (!write_cur)
			begin
			r_sst_ce <= 0;
			end
		end

	if (n64_ad_store [31:20] == 12'h1EE)			//The EEPROM is mapped here, only even addresses
		begin
		r_read_top <= 1;
		r_sst [18:0] <= (n64_ad_store [19:1]);
		r_sst_oe <= read_cur;

		if (!write_cur && (wr_cnt <= 4'd7) && !cnt_reset)
			begin
			wr_cnt <= (wr_cnt_nxt + 1'b1);
			r_sst_ce <= 0;
			end

		if (!read_cur && (rd_cnt <= 4'd7) && !cnt_reset)
			begin
			rd_cnt <= (rd_cnt_nxt + 1'b1);
			r_sst_ce <= 0;
			end

		if (cnt_reset)
			begin
			rd_cnt <= 0;
			wr_cnt <= 0;
			end
		end

	if (n64_ad_store [31:20] == 12'h1EF)			//The EEPROM is mapped here, only odd addresses
		begin
		r_sst [18:0] <= ((n64_ad_store [19:1]) + 1'b1);
		r_read_top <= 1;
		r_sst_oe <= read_cur;

		if (!write_cur && (wr_cnt <= 4'd7) && !cnt_reset)
			begin
			wr_cnt <= (wr_cnt_nxt + 1'b1);
			r_sst_ce <= 0;
			end

		if (!read_cur && (rd_cnt <= 4'd7) && !cnt_reset)
			begin
			rd_cnt <= (rd_cnt_nxt + 1'b1);
			r_sst_ce <= 0;
			end

		if (cnt_reset)
			begin
			rd_cnt <= 0;
			wr_cnt <= 0;
			end
		end
end
endmodule