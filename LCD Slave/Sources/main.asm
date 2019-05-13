;Main.s by Spencer Morley-Short, Kyle Melton
;1/30/19
;Slave_LCD
			INCLUDE 'derivative.inc'
			XDEF _Startup, main, _Viic
			XREF __SEG_END_SSTACK	; symbol defined by the linker for the end of the stack

	ORG $0060
	
;----I2C-VARIBLES-----------------------------
	IIC_addr: DS.B 1
	IIC_msg: DS.B 1    ; enable 32 bit transmission
	msgLength: DS.B 1
	current: DS.B 1		
	
	MSG1: DS.B 1
	HOUR: DS.B 1
	MINUTE: DS.B 1
	SECOND: DS.B 1
	MONTH: DS.B 1
	DAY: DS.B 1
	YEAR: DS.B 1
	CURRENT_POSITION: DS.B 1
	IIC_FLAG: DS.B 1
	
	
	ORG $E000
	
E			EQU		0  ;PORTA BIT 0   
RS			EQU		1	;PORTA BIT 1


chars DC.B '0123456789ABCDEF'
time DC.B 'Time is hh/mm/ss'
date  DC.B 'Date is mm/dd/yy'
			
main:
	_Startup:
			  	LDHX #__SEG_END_SSTACK  ;INITIALZE THE STACK POINTER
			  	TXS
				CLI
				
				LDA SOPT1 ;DIABLE WATCHDOG
				AND #$7E
				STA SOPT1
			
				;PTA PINS FOR SDA/SC;
				LDA SOPT2
				AND #%11111101     ;ORA #%00000010 ; 
				STA SOPT2
				
				JSR IIC_Startup_slave
;-----------LCD INITI-------------------------------------------------------
				;SET PTBD TO OUTPUT
  				LDA #%11111111
  				STA PTBDD				
				
				;SET PTAD 1:0 TO OUTPUT, LEAVE THE REST ALONE
				LDA PTADD
				ORA #%00000011
				STA PTADD
				
				;INTIALIZE PORTS
				CLR		PTAD
				CLR		PTBD
				
				LDA #0
				STA $121
				
				JSR LCD_Startup
				JSR LCD_Write_Time_Screen
				JSR USER_TIME_LOOP
;---------------------------------------------------------------------------
mainLoop:

				
				;;TODO load i2x message into x
				
				
				
				
				BRA mainLoop
				
USER_TIME_LOOP:
				LDA IIC_FLAG
				CMP #0
				BEQ USER_TIME_LOOP
				CLR IIC_FLAG 
				CLRH
				LDX CURRENT_POSITION
				
				CPX #$0
				BEQ SET_0
				CPX #$1
				BEQ SET_1
				CPX #$2
				BEQ SET_2
				CPX #$3
				BEQ SET_3
				CPX #$4
				BEQ SET_4
				CPX #$5
				BEQ SET_5
				CPX #$6
				BEQ SET_6
				CPX #$7
				BEQ SET_7
				CPX #$8
				BEQ SET_8
				CPX #$9
				BEQ SET_9
				CPX #$A
				BEQ SET_A
				CPX #$B
				BEQ SET_B
				
				RTS
				
SET_0:				
	LDA #$88
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA HOUR
	BRA USER_TIME_LOOP
	
SET_1:
	LDA #$89
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	LDA HOUR
	ADD X
	BRA USER_TIME_LOOP
	
SET_2:
	LDA #$8A
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA MINUTE
	BRA USER_TIME_LOOP
	
SET_3:
	LDA #$8B
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA MINUTE
	ADD X
	STA MINUTE
	BRA USER_TIME_LOOP
	
SET_4:
	LDA #$8D
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA SECOND
	BRA USER_TIME_LOOP
	
SET_5:
	LDA #$8E
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA SECOND
	ADD X
	STA SECOND
	BRA USER_TIME_LOOP
	
SET_6:
	LDA #$C8
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA MONTH
	BRA USER_TIME_LOOP
	
SET_7:
	LDA #$C9
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA MONTH
	ADD X
	STA MONTH
	BRA USER_TIME_LOOP	
SET_8:
	LDA #$CA
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA DAY
	BRA USER_TIME_LOOP
	
SET_9:
	LDA #$CB
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA DAY
	ADD X
	STA DAY
	BRA USER_TIME_LOOP
	
SET_A:
	LDA #$CD
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA #$A
	MUL
	STA YEAR
	BRA USER_TIME_LOOP
	
SET_B:
	LDA #$CE
	JSR LCD_ADDR
	LDX IIC_msg
	LDA chars,X
	JSR LCD_WRITE
	LDA YEAR
	ADD X
	STA YEAR
	BRA USER_TIME_LOOP
				
LCD_Write_Time_Screen:
				LDA #$80
				JSR LCD_ADDR
				CLRH
				CLRX
				LINE1:
					LDA time,X
					JSR LCD_WRITE
					INCX
					CPX #$10
					BNE LINE1
				LDA #$C0
				JSR LCD_ADDR
				CLRH
				CLRX
				LINE2:
					LDA date,X
					JSR LCD_WRITE
					INCX
					CPX #$10
					BNE LINE2
				RTS
					
				
				
LCD_Startup:	
				;SEND INTIAL COMMAND
				LDA #$30
				JSR LCD_WRITE
				JSR LCD_WRITE
				JSR LCD_WRITE
				
				;send function set command
				;8-bit bus, 2 rows, 5x7 dots
				LDA #$38
				JSR LCD_WRITE
				
				;SEND DISPLAY COMMAND
				;DISPLAY ON, CURSOR OFF, NO BLINKING
				LDA #$0F		;DISPLAY CTRL COMMAND MSB
				JSR LCD_WRITE
				
				;SEND CLEAR DISPLAY COMMAND
				LDA #$01
				JSR LCD_WRITE

				;SEND ENTRY MODE COMMAND
				LDA #$06
				JSR LCD_WRITE
				
				
				LDA #$80
				JSR LCD_ADDR
				LDA #$10
				STA $120
				RTS

;----------LCD SUBROUTINES-------------------------------------------
LCD_WRITE:
				STA PTBD
				NOP
				BCLR E, PTAD
				NOP
				BSET E, PTAD
				JSR DELAYLOOP
				RTS
		
LCD_ADDR:
				BCLR RS, PTAD      ;LCD IN COMMAND MODE
				JSR LCD_WRITE
				BSET RS, PTAD
				RTS
				
LCD_CLEAR:
				BCLR RS, PTAD
				;SEND CLEAR DISPLAY COMMAND
				LDA #$01
				JSR LCD_WRITE
				
				BSET RS, PTAD
				
				LDA #$80
				JSR LCD_ADDR
				
				RTS		

;------------------I2C CODE---------------------------------------------
IIC_Startup_slave:
				;set baud rate 50kbps
				LDA #%10000111
				STA IICF
				;set slave address
				LDA #$20
				STA IICA
				;Enable IIC and Interrupts
				BSET IICC_IICEN, IICC
				BSET IICC_IICIE, IICC
				BCLR IICC_MST, IICC
				RTS

_Viic:
				;clear interrupt
				BSET IICS_IICIF, IICS
				;master mode?
				LDA IICC
				AND #%00100000
				BEQ _Viic_slave ; yes
				;no
				RTI
_Viic_slave:
				;Arbitration lost?
				LDA IICS
				AND #%00010000
				BEQ _Viic_slave_iaas ;No
				BCLR 4, IICS;if yes, clear arbitration lost bit
				BRA _Viic_slave_iaas2
_Viic_slave_iaas:
				;Adressed as Slave?
				LDA IICS 
				AND #%01000000
				BNE _Viic_slave_srw ;yes
				BRA _Viic_slave_txRx ;no
_Viic_slave_iaas2:
				;Adressed as Slave?
				LDA IICS
				AND #%01000000
				BNE _Viic_slave_srw ;yes
				RTI ;if no exit
_Viic_slave_srw:
				;Slave read/write
				LDA IICS
				AND #%00000100
				BEQ _Viic_slave_setRx ;slave reads
				BRA _Viic_slave_setTx ;slave writes
_Viic_slave_setTx:
				;transmits data
				BSET 4, IICC ;transmit mode select
				LDX current 
				LDA IIC_msg, X ;selects current byte of message to send
				STA IICD ; sends message
				INCX 
				STX current ; increments current
				RTI
_Viic_slave_setRx:
				;makes slave ready to receive data
				BCLR 4, IICC ;recieve mode select
				LDA #0
				STA current
				LDA IICD ;dummy read
				RTI
_Viic_slave_txRx:
				;Check if device is in transmit or receive mode
				LDA IICC
				AND #%00010000
				BEQ _Viic_slave_read ;receive
				BRA _Viic_slave_ack ;transmit
_Viic_slave_ack:
				;check if master has acnowledged
				LDA IICS
				AND #%00000001
				BEQ _Viic_slave_setTx ;yes, transmit next byte
				BRA _Viic_slave_setRx ;no, switch to receive mode
_Viic_slave_read:
				CLRH
				LDX current
				LDA IICD
				STA IIC_msg, X ;store recieved data in IIC_MSG
				INCX
				STX current ; increment current
				LDA $121
				INCA
				STA $121
				RTI
				
;--------------
;80 ms delay
DELAYLOOP:  
				LDA #1 ;load highest decimal value into accumulator for outer loop
	            STA $125
LOOP0:
				LDA #100
				STA $126
LOOP1:
				LDA #255
	            STA $127
LOOP2:
				LDA $127
				DECA
				STA $127
				CMP #$0
				BNE LOOP2
				
				LDA $126
				DECA
				STA $126
				CMP #$0
				BNE LOOP1
				STA SRS
				
				LDA $125
				DECA
				STA $125
				CMP #$0
				BNE LOOP0
	           
	            RTS
