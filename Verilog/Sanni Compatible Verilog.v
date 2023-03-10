module N64GSVerilog

(ad, aleh, alel, clk, cold_reset, read, write, sst, sst_ce, sst_oe);

input [15:0] ad;
input aleh;
input alel;
input clk;
input cold_reset;
input read;
input write;
output [18:0] sst;
output sst_ce;
output sst_oe;

reg [12:0] address_inc = 13'b0;
reg [12:0] address_inc_next = 13'b0;
reg [5:0] alel_stat;
reg [5:0] aleh_stat;
reg [31:0] n64_ad_store = 32'b0;
reg [18:0] sst_address = 0;
reg [18:0] r_sst = 0;
reg r_sst_ce = 1;
reg r_sst_oe = 1;
reg [5:0] read_stat;
reg [5:0] write_stat;

assign sst = r_sst;
assign sst_ce = r_sst_ce;
assign sst_oe = r_sst_oe;

always @(posedge clk)

begin
	address_inc_next <= address_inc;
	aleh_stat [5:0] <= {aleh_stat [4:0], aleh};
	alel_stat [5:0] <= {alel_stat [4:0], alel};
	r_sst_ce <= 1;
	r_sst_oe <= 1;
	read_stat [5:0] <= {read_stat [4:0], read};
	write_stat [5:0] <= {write_stat [4:0], write};

	if (!write_stat [3:2] && write_stat [1:0])
		begin
		address_inc <= (address_inc_next + 1'b1);
		end

	if (write_stat [3:2] && !write_stat [1:0])
		begin
		sst_address [18:0] <= (n64_ad_store [19:1] + address_inc);
		end

	if (!read_stat [3:2] && read_stat [1:0])
		begin
		address_inc <= (address_inc_next + 1'b1);
		end

	if (read_stat [3:2] && !read_stat [1:0])
		begin
		sst_address [18:0] <= (n64_ad_store [19:1] + address_inc);
		end

	if (alel_stat [1:0] && !aleh_stat [1:0])
		begin
		n64_ad_store [15:0] <= ad;
		address_inc <= 13'b0;
		end

	if (alel_stat [1:0] && aleh_stat [1:0])
		begin
		n64_ad_store [31:16] <= ad;
		end

	if (n64_ad_store [31:20] == 12'h100)
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_sst_oe <= (read_stat [5:3] == 3'b0) ? 1'b0 : 1'b1;
		r_sst_ce <= ((write_stat [5:4] == 2'b0) || (read_stat [5:3] == 3'b0)) ? 1'b0 : 1'b1;
		end

	if ((n64_ad_store [31:20] == 12'h10C))
		begin
		r_sst [18:0] <= sst_address [18:0];
		r_sst_oe <= (read_stat [5:3] == 3'b0) ? 1'b0 : 1'b1;
		r_sst_ce <= ((write_stat [5:4] == 2'b0) || (read_stat [5:3] == 3'b0)) ? 1'b0 : 1'b1;
		end
end
endmodule