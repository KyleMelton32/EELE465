;Main.s by Spencer Morley-Short, Kyle Melton
;1/30/19
;Slave_LCD
			INCLUDE 'derivative.inc'
			XDEF _Startup, main, _Viic
			XREF __SEG_END_SSTACK	; symbol defined by the linker for the end of the stack

	ORG $0060
	
;----I2C-VARIBLES-----------------------------
	IIC_addr: DS.B 1
	IIC_msg: DS.B 6    ; enable 32 bit transmission
	msgLength: DS.B 1
	current: DS.B 1
	
	current_time_position: DS.B 1
	write_position: DS.B 1
	time_write_position: DS.B 1

	tens_char: DS.B 1
	ones_char: DS.B 1
	
	time_array: DS.B 6 ;second, minute, hour, day, month, year
	
	TIME_FLAG: DS.B 1
	IIC_FLAG: DS.B 1
	
	timedate: DS.B 32
	
	
	ORG $E000
	
E			EQU		0  ;PORTA BIT 0   
RS			EQU		1	;PORTA BIT 1


chars DC.B '0123456789ABCDEF'
base DC.B 'Time is hh:mm:ssDate is mm/dd/yy'
replacement DC.B $E, $F, $B, $C, $8, $9, $1B, $1C, $18, $19, $1E, $1F
default_time_array DC.B $FF, $FF, $FF, $FF, $FF, $FF
		
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
				
				JSR resetTimeDate
					
				CLRH ;shift default_time_array into time_array
				CLRX
				loadTimeRAM:
					LDA default_time_array,X
					STA time_array,X
					INCX
					CPX #$6
					BNE loadTimeRAM 
					
				
				LDA #0
				STA IIC_FLAG
				STA current_time_position
				STA TIME_FLAG
				STA time_write_position
				
				
				JSR LCD_Startup
				JSR LCD_Write_Time_Screen
;---------------------------------------------------------------------------
mainLoop:
				LDA IIC_FLAG
				ADD #$0
				CMP #6 ; if this doesn't work, use current instead?
				BNE mainLoop ; no i2c change
				CLR IIC_FLAG
				JSR resetTimeDate
				CLRX
				CLRH
				readIIC_msg:
					LDA IIC_msg,X
					STA time_array,X
					INCX
					CPX #6
					BNE readIIC_msg
				CLR current_time_position
				JSR writeTimeArray
				BRA mainLoop
				
resetTimeDate:
				CLRH ;shift the base screen into ram to be modified
				CLRX ;for some reason, this is required if not in debug mode
				;when base message is stored in RAM and not in debug, it prints garbage
				;this fixes that
				loadRAM:
					LDA base,X
					STA timedate,X
					INCX
					CPX #$20
					BNE loadRAM 
				RTS
				
writeTimeArray:			
				LDX time_write_position
				LDA time_array,X
				JSR convertDecimalAsHexToChars ; move A into tens and ones
				char1:
					LDX current_time_position
					INC current_time_position
					LDX replacement,X
					LDA tens_char
					CMP #$46 ; char is F and is a flag for don't actually write
					BEQ char2 ;so lets skip to the next char
					STA timedate,X ;tens should be written now
				char2:
					LDX current_time_position
					INC current_time_position
					LDX replacement,X
					LDA ones_char
					CMP #$46 ; char is F and is a flag for don't actually write
					BEQ write ; so lets just write the default
					STA timedate,X
				write:
					INC time_write_position
					LDA time_write_position
					
					CMP #6
					BNE writeTimeArray
					CLR current_time_position ; we have finished, let's write to the LCD and reset
					CLR time_write_position
					JSR LCD_Write_Time_Screen
					RTS

convertDecimalAsHexToChars:
				
				STA tens_char ; store values for now
				STA ones_char 
				CLRH
				AND #%11110000
				LSRA
				LSRA
				LSRA
				LSRA
				TAX ; store A in X
				
				LDA chars,X ;actually convert to the char
				STA tens_char
				
				LDA ones_char
				AND #%00001111
				TAX ; store A in X
				
				LDA chars,X
				STA ones_char
				
				RTS
				
RETURN:
				RTS
				
Write_Line:
				LDX write_position
				LDA timedate,X
				JSR LCD_WRITE
				INCX
				STX write_position
				CPX #$10
				BEQ RETURN
				CPX #$20
				BEQ RETURN
				BRA Write_Line
				
LCD_Write_Time_Screen:
				CLR write_position
				LDA #$80
				JSR LCD_ADDR
				CLRH
				CLRX
				JSR Write_Line
				;Next_Line:
					LDA #$C0
					JSR LCD_ADDR
					CLRH
					CLRX
				JSR Write_Line
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
				LDA IIC_FLAG
				INCA
				STA IIC_FLAG
				RTI
				
;--------------
;80 ms delay
DELAYLOOP:  
				LDA #1 ;load highest decimal value into accumulator for outer loop
	            STA $125
LOOP0:
				LDA #50
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
