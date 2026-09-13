module vg75(
	input wire pixclk,
	input wire hclk,
	input wire rst,
	//HDMI
	output wire[2:0]tmds_p,
    output wire[2:0]tmds_n,
	output wire tmdsc_p,
    output wire tmdsc_n,
	//System bus
	input wire[7:0]DIN,
	input wire[15:0]ADD,
	input wire[15:0]KURSOR,
	input wire WR
);

parameter[15:0]START_VRAM = 16'h77C2; //16'h77C2

wire[7:0]R,G,B;
wire[10:0]HCNT,VCNT;
wire VISIBLE;

hdmi mhd(.pixclk(pixclk),.clk_TMDS(hclk),.n_rst(rst),.TMDSp(tmds_p),.TMDSp_clock(tmdsc_p),
            .TMDSn(tmds_n),.TMDSn_clock(tmdsc_n),
			.red(R),.green(G),.blue(B),.visible(VISIBLE),.HCNT(HCNT),.VCNT(VCNT));

//RAM номеров символов			
wire[11:0]VR_RADD;
wire[15:0]VR_WADD;
wire[7:0]VR_DO;
wire VR_RCLK,VR_WCLK,VR_WREN;	

assign VR_WADD = ADD - START_VRAM;

vram mvr(
        .doutb(VR_DO), //output [7:0] doutb
        .clka(VR_WCLK), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(1'b0), //input reseta
        .wrea(VR_WREN), //input wrea
        .clkb(VR_RCLK), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(1'b0), //input resetb
        .wreb(1'b0), //input wreb
        .ada(VR_WADD[11:0]), //input [11:0] ada
        .dina(DIN), //input [7:0] dina
        .adb(VR_RADD) //input [11:0] adb
    );

//ROM знакогенератора			
wire[9:0]ZR_ADD;
wire[7:0]ZR_DAT;
wire ZR_CLK;

zrom zng(
        .dout(ZR_DAT), //output [7:0] dout
        .clk(ZR_CLK), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(1'b0), //input reset
        .ad(ZR_ADD) //input [9:0] ad
    );

			
/*********************************************************
Разрешение HDMI 									- 800х600						
Разрешение РК86 									- 384x200 с удвоением
Количество знакомест 							- 64х25
Количество байт памяти на 64 знакоместа 	- 78
*********************************************************/

wire BORDER,PREPARE;
wire[7:0]Rb,Gb,Bb,Rr,Gr,Br;
wire[10:0]NHCNT,NVCNT,BVCNT;
wire[10:0]ZNAKOMESTO;

assign BORDER = (VCNT >= (99) && VCNT < (499) && HCNT >= (15) && HCNT < (783))? 1'b1 : 1'b0;
assign NHCNT = HCNT - (15 - 12);
assign NVCNT = VCNT - (99);
assign ZNAKOMESTO = (NHCNT / 12) + ((NVCNT[10:4]) * 78); // -65 вычислено опытным путём

//Бордюр
wire[7:0]Rc,Gc,Bc;
assign Rc = (BORDER)? Rb : 8'h0F;
assign Gc = (BORDER)? Gb : 8'h0F;
assign Bc = (BORDER)? Bb : 8'h0F;

//Гашение
assign R = (VISIBLE)? Rc : 8'h00;	
assign G = (VISIBLE)? Gc : 8'h00;	
assign B = (VISIBLE)? Bc : 8'h00;



//Автомат чтения данных знакоместа и шрифта
reg[11:0]tzd,zd;
reg[7:0]zad;
reg zclk,vclk;
reg kur;
wire[15:0]KUR;

assign KUR = KURSOR - START_VRAM;

always@(negedge pixclk or negedge rst)
	begin
		if(!rst)
			begin	
				zd <= 0;
				tzd <= 0;				
				zclk <= 0;
				vclk <= 0;
				kur <= 0;
			end
		else
			begin
				case(NHCNT % 12)
					1: vclk <= 1'b1;
					2: vclk <= 1'b0;
					3: 
						begin
							zad <= VR_DO;
							if(ZNAKOMESTO == KUR) kur <= 1;
						end
					4: zclk <= 1'b1;
					5: zclk <= 1'b0;
					6: 
						begin
							if(NVCNT[3:1] == 7 && kur == 1) tzd <= 12'b000000000000;
							else tzd[11:0] <= {{2{ZR_DAT[5]}},{2{ZR_DAT[4]}},{2{ZR_DAT[3]}},
														{2{ZR_DAT[2]}},{2{ZR_DAT[1]}},{2{ZR_DAT[0]}}};
						end
					0: 
						begin
							zd <= tzd;
							kur <= 0;
						end
					
				endcase
			end
	end


//
assign VR_RADD = ZNAKOMESTO;
assign VR_RCLK = vclk;
assign ZR_ADD = (zad * 8) + (NVCNT[3:1]);//vcnt; //???
assign ZR_CLK = zclk;
//
assign VR_WREN = (ADD >= 16'h76D0 && ADD < 16'h8000)? 1'b1 : 1'b0;
assign VR_WCLK = ~(WR | pixclk);	


assign Rb = (zd[(11-(NHCNT % 12))])? 8'h00 : 8'hFF;
assign Gb = (zd[(11-(NHCNT % 12))])? 8'h00 : 8'hFF;
assign Bb = (zd[(11-(NHCNT % 12))])? 8'h00 : 8'hFF;

endmodule

