USB_Keyboard.bin - это прошивка для платы "Black pill" на STM32F411CEU с кварцем на 25Mhz.
Как таковой схемы адаптера для клавиатуры нет, можно подключить клавиатуру к usb разъёму платы BlackPill через переходник, а плату FPGA к BlackPill - проводами для Ардуино и ей подобных плат.
Подключение к плате BlackPill следующее:
Клавиатура: USB D+ - PA12, USB D- - PA11
FPGA: KB_MOSI - PA7, KB_SCK - PA5, KB_CS - PB0, KB_LATCH - PB1.
