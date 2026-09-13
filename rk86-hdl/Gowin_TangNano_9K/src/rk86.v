module rk86(
	input wire clk,
	input wire rst,
	input wire HOLD,
	//HDMI
	output wire[2:0]tmds_p,
    output wire[2:0]tmds_n,
	output wire tmdsc_p,
    output wire tmdsc_n,

	//SRAM
	output wire[18:0]ER_ADD,
	inout wire[7:0]ER_D,
	output wire ER_CS,
	output wire ER_OE,
	output wire ER_WE,


	//USB_Keyboard
	input wire KB_CLK,
	input wire KB_DAT,

	
	//SPI Flash
	output wire SPI_CS,
	output wire MOSI,
	output wire SCK,
	input wire MISO,
	
	//Beepper
	output wire BEEP

);

//Clock
wire CLK_28, CLK_50, CLK_500;

main_pll mpl(.clkin(clk),.clkout(CLK_28));

hdmi_pll hpll(.clkin(clk),.clkout(CLK_500),.clkoutd(CLK_50));


reg[3:0] div;
always@(posedge CLK_28) div <= div + 1;

reg hdiv;
always@(posedge CLK_500) hdiv <= hdiv + 1;


//CPU
wire[15:0]CPU_ADD;
wire[7:0]CPU_DI,CPU_DO,IO_DO;
wire MREQ,IORQ;
wire CRST;
//I8080
wire RM,WM,RIO,WIO,DBIN,WO,HLDA,SYNC,F1,F2;

assign CRST = (rst & HOLD & ~PROG);
assign F1 = div[3] & div[2];
assign F2 = ~div[3];

vm80a_core mcp
(
   .pin_clk(clk),
   .pin_f1(F1),
   .pin_f2(F2),
   .pin_reset(~CRST),
   .pin_a(CPU_ADD),
   .pin_dout(CPU_DO),
   .pin_din(CPU_DI),
   .pin_hold(1'b0),
   .pin_ready(1'b1),
   .pin_int(1'b0),
   .pin_wr_n(WO),
   .pin_dbin(DBIN),
   .pin_hlda(HLDA),
   .pin_sync(SYNC),
   .pin_inte(BEEP)
);

reg[7:0]i8080ctrl;
wire[7:0]CCTRL;

always@(negedge F1) if(SYNC == 1) i8080ctrl[7:0] <= CPU_DO[7:0];
	
assign CCTRL = i8080ctrl;

assign RIO = ~(DBIN & CCTRL[6]);
assign WIO = ~(CCTRL[4] & ~WO); 
assign RM = ~(DBIN & CCTRL[7]);
assign WM = ~(~CCTRL[4] & ~WO);


//Video
wire[15:0]KURSOR;


vg75 mvc(.pixclk(CLK_50),
         .hclk(hdiv),
         .rst(rst),
         .tmds_p(tmds_p),
         .tmdsc_p(tmdsc_p),
         .tmds_n(tmds_n),
         .tmdsc_n(tmdsc_n),
		 .ADD(CPU_ADD),
         .DIN(CPU_DO),
         .WR(WM),
         .KURSOR(KURSOR));


//Programmer
wire PROG,PROGWE;
wire[18:0]PROGADD;
wire[7:0]PROGDO;

programmer mpg(
   .clk(clk),	 
   .rst(rst),	 
   .PROG(PROG),
   .SRAMADD(PROGADD),
   .SRAMDO(PROGDO),
   .SRAMWE(PROGWE),
	.SPI_CS(SPI_CS),
	.SPI_MOSI(MOSI),
	.SPI_MISO(MISO),
	.SPI_SCK(SCK)
	);
	
	
//Monitor
wire[18:0]MON_ADD;
wire[7:0]MON_DI;
wire MON_SEL;
reg start;						  

always@(posedge CPU_ADD[11] or negedge CRST)
	begin
		if(!CRST) start <= 0;
		else start <= 1;		
	end
	
assign MON_SEL = (CPU_ADD >= 16'hF800)? 1'b1 : 1'b0;

	
//SRAM
wire[7:0] ER_DI;
wire RAM_WE,MON_WE,CPM_WE;

assign MON_ADD = (start)? {3'b000,CPU_ADD[15:0]} : {8'b00011111,CPU_ADD[10:0]}; //
assign RAM_WE = (CPU_ADD < 16'h8000)?  WM : 1'b1;
assign ER_ADD[18:0] = (PROG)? PROGADD[18:0] : MON_ADD;
assign ER_D = (ER_WE == 0)? ER_DI : 8'bzzzzzzzz;
assign ER_DI = (PROG)? PROGDO : CPU_DO;
assign ER_WE = (PROG)? PROGWE : RAM_WE;
assign ER_OE = (PROG)? 1'b1 : RM;
assign ER_CS = (PROG)? 1'b0 : (((CPU_ADD < 16'h8000) || (CPU_ADD >= 16'hF800))? 1'b0 : 1'b1);

assign ER_BH = 1'b1;
assign ER_BL = 1'b0;

//Keyboard
wire[7:0]KPA;
wire[7:0]KPB;
wire[2:0]KPC;


keyboard  mkb(.clk(CLK_28),.rst(CRST),.clock(KB_CLK),.dat(KB_DAT),.PA(KPA),
						 .PC(KPC),.PB(KPB));


//IO чтение
reg[7:0]dio;


always@(negedge CRST or negedge RM)
	begin
		if(!CRST) dio <= 8'hFF;
		else
			begin
				case(CPU_ADD[15:0])
					16'h8001: dio <= KPB; //Порт клавиатуры основной
					16'h8002: dio <= {KPC[2:0],5'b11111}; //Порт клавиатуры доп., магнитофон
					default:  dio <= 8'hFF;
				endcase
			end
	end
	
//IO запись
reg[7:0]kpa;
reg[15:0]kur;

always@(negedge CRST or negedge WM)
	begin
		if(!CRST)
			begin
				kpa <= 8'hFF;
			end
		else
			begin
				case(CPU_ADD[15:0])
					16'h8000: kpa <= CPU_DO; //Порт сканирования клавиатуры
					16'h7601: kur[15:8] <= CPU_DO; //Положение курсора в памяти 
					16'h7600: kur[7:0] <= CPU_DO; //
				endcase				
			end
	end
	
assign KPA = kpa;
assign KURSOR = kur;
	
//CPU DATA IN	
assign IO_DO = dio;
assign CPU_DI = ((CPU_ADD < 16'h8000) || (CPU_ADD >= 16'hF800))? ER_D : IO_DO;



endmodule








