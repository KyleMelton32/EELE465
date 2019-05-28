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
	
	current_replacement_position: DS.B 1
	write_position: DS.B 1
	time_write_position: DS.B 1
	screen_write_position: DS.B 1

	tens_char: DS.B 1
	ones_char: DS.B 1
	
	
	state: DS.B 1
	t92: DS.B 2
	seconds: DS.B 1
	
	state_char: DS.B 6
	t92_char: DS.B 3
	seconds_char: DS.B 3
	
	TIME_FLAG: DS.B 1
	IIC_FLAG: DS.B 1
	
	screen: DS.B 32
	
	
	ORG $E000
	
E			EQU		0  ;PORTA BIT 0   
RS			EQU		1	;PORTA BIT 1

chars DC.B '0123456789ABCDEF'
cool DC.B '  cool'
heat DC.B '  heat'
off DC.B  '   off'
state_replacement DC.B $A, $B, $C, $D, $E, $F
t92_replacement DC.B $14, $15, $16
seconds_replacement DC.B $1B, $1C, $1D
base DC.B 'TEC state:      T92:   K@T=   s '
		
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
				
				JSR resetScreen
				
				LDA #0
				STA IIC_FLAG
				STA current_replacement_position
				STA TIME_FLAG
				STA time_write_position
				STA state
				STA seconds
				STA t92
				STA screen_write_position
				
				JSR LCD_Startup
				JSR writeToScreen
;---------------------------------------------------------------------------
mainLoop:
				LDA IIC_FLAG
				ADD #$0
				CMP #3 ; if this doesn't work, use current instead?
				BLS mainLoop ; no i2c change
				CLR IIC_FLAG
				JSR DELAYLOOP
				JSR DELAYLOOP
				JSR DELAYLOOP
				JSR resetScreen
				CLRX
				CLRH
				LDA IIC_msg,X
				STA state
				INCX
				LDA IIC_msg,X
				DECX
				STA t92,X
				INCX
				INCX
				LDA IIC_msg,X
				DECX
				STA t92,X
				INCX
				INCX
				LDA IIC_msg,X
				STA seconds
				JSR writeToScreen
				LDA seconds
				CMP #0
				BEQ mainLoop
				NOP
				NOP
				BRA mainLoop
				
resetScreen:
				CLRH ;shift the base screen into ram to be modified
				CLRX ;for some reason, this is required if not in debug mode
				;when base message is stored in RAM and not in debug, it prints garbage
				;this fixes that
				loadRAM:
					LDA base,X
					STA screen,X
					INCX
					CPX #$20
					BNE loadRAM 
				RTS
				
writeToScreen:
				JSR resetScreen
				JSR makeCharArrays
				CLRX
				CLRH
				STX current_replacement_position
				replace_state_loop:
					LDX current_replacement_position
					LDA state_char,X
					LDX state_replacement,X
					STA screen,X
					INC current_replacement_position
					LDX current_replacement_position
					CPX #$6
					BNE replace_state_loop
					CLR current_replacement_position
					BRA replace_t92_loop
				replace_t92_loop:
					LDX current_replacement_position
					LDA t92_char,X
					LDX t92_replacement,X
					STA screen,X
					INC current_replacement_position
					LDX current_replacement_position
					CPX #$3
					BNE replace_t92_loop
					CLR current_replacement_position
					BRA replace_seconds_loop
				replace_seconds_loop:
					LDX current_replacement_position
					LDA seconds_char,X
					LDX seconds_replacement,X
					STA screen,X
					INC current_replacement_position
					LDX current_replacement_position
					CPX #$3
					BNE replace_seconds_loop
					CLR current_replacement_position
				JSR LCD_Write_Time_Screen
				RTS 
				
makeCharArrays:
				CLRX
				CLRH
				state_loop:
					LDA state
					CMP #0
					BEQ setOff
					CMP #1
					BEQ setHeat
					CMP #2
					BEQ setCool
					RTS ; should never hit because then we are in an invalid state
					setState:
						STA state_char,X
						INCX
						CPX #6
						BNE state_loop
						CLRX
						CLRH
						BRA t92_loop
					setCool:
						LDA cool,X
						BRA setState
					setHeat:
						LDA heat,X
						BRA setState
					setOff:
						LDA off,X
						BRA setState
				t92_loop:
					CLRX
					CLRH
					LDA t92,X
					STA t92_char,X
					INCX
					LDA t92,X
					STA t92_char,X
					INCX
					LDA #$20
					STA t92_char,X
				
				seconds_loop:
					LDA seconds
					JSR convertDecimalAsHexToChars
					CLRX
					CLRH
					LDA tens_char
					STA seconds_char,X
					INCX
					LDA ones_char
					STA seconds_char,X
					LDA #$20
					INCX
					STA seconds_char,X
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
				LDA screen,X
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
