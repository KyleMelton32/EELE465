;Main.s by Spencer Morley-Short, Kyle Melton
;1/30/19
;MASTER
			INCLUDE 'derivative.inc'
			XDEF _Startup, main, _Viic, _vKeyboard
			XREF __SEG_END_SSTACK	; symbol defined by the linker for the end of the stack
		
	ORG $0060
	IIC_addr: DS.B 1   ;TRACK IIC ADDRESS
	msgLength: DS.B 1  ; TRACK TOTAL MESSAGE LENGTH
	current: DS.B 1    ; TRACK WHICH BYTE WE HAVE SENT 
	IIC_msg: DS.B 16    ; enable 32 bit transmission 
	
	keyboard: DS.B 1
	keyboard_placeholder: DS.B 1
	
	time_array: DS.B 6 ;second, minute, hour, day, month, year
	update_seconds: DS.B 1 ; when this is zero, don't set the seconds variable, when it's anything else, update the seconds variable
	counter0: DS.B 1 ; these counters are used in the main loop to only do things every certain number of cycles
	counter1: DS.B 1
	
	state: DS.B 1
	t92: DS.B 2
	seconds: DS.B 1
	
	temp_array: DS.B 2
	bitshift_placeholder: DS.B 1

;code section
	ORG $E000
keyboard_map DC.B %00101000,%00010001,%00100001,%01000001,%00010010,%00100010,%01000010,%00010100,%00100100,%01000100,%10000001,%10000010,%10000100,%10001000,%00011000,%01001000	
default_time_array DC.B $FF, $FF, $FF, $FF, $FF, $FF
chars DC.B '0123456789ABCDEF'

main:
	_Startup:
			
   				LDHX #__SEG_END_SSTACK  ;INITIALZE THE STACK POINTER
				TXS
				CLI     ;ENABLE INTERUPTS 
	
				LDA SOPT1 ;DISABLE WATCHDOG
				AND #$7F
				STA SOPT1
	
				LDA SOPT2      ;SET PTB PINS TO BE USED FOR SDA/SCL
				ORA #%00000010
				STA SOPT2
	
				JSR IIC_Startup_Master
				
				;Enable keyboard interrupt
				LDA #%00001111
				STA KBIPE
				
				;DISABLE PULL UP RESISTORS
				LDA PTAPE
				AND #%11110000
				STA PTAPE
				
				; set PTA to input
				LDA PTADD
				AND #%11110000
				STA PTADD
				
				LDA PTBDD
				ORA #%00111100
				STA PTBDD
				
				; enable keyboard interrupt to falling edge
				LDA #%00001111
				STA KBIES
				
				; Enable Keyboard Interrupt
				BSET 1, KBISC
				BCLR 0, KBISC
				
				CLRH ;shift default_time_array into time_array
				CLRX
				loadRAM:
					LDA default_time_array,X
					STA time_array,X
					INCX
					CPX #$6
					BNE loadRAM 
				
				CLR counter0
				CLR counter1
				CLR state
				CLR seconds
				CLR t92
				JSR setOffState ; put everything in a known state, off just to be safe



mainLoop:
				JSR getKeyboardCommand
				INC counter0
				LDA counter0
				CMP #255
				BNE mainLoop
				CLR counter0
				
				INC counter1
				LDA counter1
				CMP #1
				BEQ on1
				CMP #20
				BEQ on20
				CMP #25
				BEQ on25
				CMP #35
				BEQ on35
				BRA mainLoop ; if it's none of the require, loop again
				on1:
					JSR sendToLCD
					BRA mainLoop
				on20:
					LDA state
					CMP #0
					BEQ mainLoop ; if state 0, we don't need to bother with the RTC
					JSR resetRTCAddress
					BRA mainLoop
				on25:
					LDA state
					CMP #0
					BEQ mainLoop ; if state 0, we don't need to bother with the RTC
					JSR readFromRTC
					BRA mainLoop
				on35:
					JSR getTemperature
					CLR counter1
					BRA mainLoop
				
				BRA mainLoop

getKeyboardCommand:
				JSR getKeyboardInput
				LDA keyboard_placeholder
				CMP #0
				BNE keyboard_triggered ; immediately take care of state change
				
				RTS ; otherwise go back to the main loop
				keyboard_triggered:
					LDA keyboard
					CMP #$0 ; turn off
					BEQ setOffState
					CMP #$1 ; set to heat
					BEQ setHeatState
					CMP #$2 ; set to cool
					BEQ setCoolState
				RTS
				
setOffState:
				CLRA
				STA state
				
				; Turn off heater/cooler
				MOV #$10, IIC_addr   ;set slave address
				LDA #1   ;set message length to 1 byte
				STA msgLength
				CLRA
				CLRX
				STA IIC_msg,X
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				
				; Update LCD
				JSR sendToLCD
				
				RTS	
				
setHeatState:
				LDA #0
				STA seconds ; reset seconds
				JSR resetRTC
				INC update_seconds

				; Turn on heater
				MOV #$10, IIC_addr   ;set slave address
				LDA #1   ;set message length to 1 byte
				STA msgLength
				CLRA
				CLRX
				CLRH
				INCA
				STA state
				LDA #$0F
				STA IIC_msg,X
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				
				; Update LCD
				JSR sendToLCD
				RTS	
				
setCoolState:
				LDA #0
				STA seconds ; reset seconds
				JSR resetRTC
				INC update_seconds
				
				; Turn on cooler
				MOV #$10, IIC_addr   ;set slave address
				LDA #2   ;set message length to 1 byte
				STA msgLength
				CLRA
				CLRX
				CLRH
				INCA
				INCA
				STA state
				LDA #$F0
				STA IIC_msg,X
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				JSR sendToLCD	
				RTS
				
sendToLCD:		
				LDA #4   ;set message length to 6 bytes
				STA msgLength
				
				CLRX
				CLRH
				LDA state
				STA IIC_msg,X
				LDA t92,X
				INCX
				STA IIC_msg,X
				LDA t92,X
				INCX
				STA IIC_msg,X
				INCX
				LDA seconds
				STA IIC_msg,X
				MOV #$20, IIC_addr   ;set slave address
				
				JSR IIC_DataWrite    ;begin data transfer
				RTS

;-------------------------------------------------------------
getTemperature:
				MOV #%10010001, IIC_addr
				LDA #1
				STA msgLength
				JSR IIC_DataWrite
				JSR DELAY
				JSR DELAY
				CLRX
				CLRH
				LDHX IIC_msg
				STHX temp_array
				CLRX
				CLRH
				INCX
				LDA temp_array,X
				AND #%11111000 ; clear the bits
				LSRA
				LSRA
				LSRA ;lower bits shifted right 3
				STA temp_array,X
				CLRX ; move the 3 lsb from the upper register to the lower register
				LDA temp_array,X
				AND #%00000111
				LSLA
				LSLA
				LSLA
				LSLA
				LSLA
				STA bitshift_placeholder
				INCX
				LDA temp_array,X
				ORA bitshift_placeholder
				STA temp_array,X ;lsb from upper bits now moved to msb of lower
				CLRX
				LDA temp_array,X
				AND #%11111000 ; clear the bits
				LSRA
				LSRA
				LSRA
				STA temp_array,X ; the registers should now contain the actual twos complement temperature
				BRSET 4, temp_array, twosComplement
				
				JSR doMultiply
				CLRH
				LDX #10
				DIV ;tens in A
				STHX temp_array ; remainder in temp_array,0
				CLRH
				TAX
				LDA chars,X
				CLRX
				STA t92,X
				
				LDX temp_array
				LDA chars,X
				CLRX
				INCX
				STA t92,X
				
				RTS

; multiply temp_array by 0.0625
multiplyUpperBits:
				CLRX
				CLRH
				STHX t92 ; clear t92
				LDA temp_array,X ; upper bits
				LDX #62
				MUL ; X * A = X:A
				LDX #255
				MUL ; X * A = X:A
				STX t92
				LDHX t92
				LDX #100
				DIV ; H:A / X = A
				CLRH
				LDX #10
				DIV
				INCA
				CLRX
				CLRH
				STA temp_array,X ; store multiplied amount back into temp_array
				RTS

multiplyLowerBits:
				INCX ; lower bits
				LDA temp_array,X
				LDX #62
				MUL ; X * A = X:A
				CLRH
				STX t92
				LDHX t92
				LDX #100
				DIV
				CLRH
				LDX #10
				DIV
				RTS
				
doMultiply:
				JSR multiplyUpperBits
				JSR multiplyLowerBits
				ADD temp_array; temperature is now in A
				RTS
				
twosComplement:
				RTS
;-------------------------------------------------------------
			
;write time_array to rtc and then jsr resetRTC			
writeToRTC:
				MOV #%11010000, IIC_addr
				
				LDA #8   ;set message length to 7 bytes
				STA msgLength
				CLRH
				CLRX
				LDA #$0
				STA IIC_msg,X
				write_loop:
					LDA time_array,X
					INCX
					STA IIC_msg,X
					CPX #$03
					BEQ write_date ; deal with this seperately because skipping a register
					BRA write_loop
				write_date: ; IIC_msg: 0x00, second, minute, hour
					INCX
					CLRA
					STA IIC_msg,X ;IIC_msg: 0x00, second, minute, hour, 0x00
				write_day_month_year:
					DECX
					LDA time_array,X
					INCX
					INCX
					STA IIC_msg,X
					CPX #$7
					BNE write_day_month_year
				; IIC_msg: 0x00, second, minute, hour, 0x00, day, month, year
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				
				JSR resetRTCAddress ; get ready to read
				
				RTS
				
;send read command, wait until data is recieved, then save data into time_array
readFromRTC:
				LDA #$08 ; we want 8 bytes of data back
				STA msgLength
				MOV #%11010001, IIC_addr
				JSR IIC_DataWrite
				JSR DELAY ;wait until data has returned
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY ;this may not work because of timings with ptb registers...
				CLRX
				CLRH
				LDA IIC_msg,X
				STA time_array,X
				STA seconds
				INCX
				LDA IIC_msg,X
				STA time_array,X
				INCX
				LDA IIC_msg,X
				STA time_array,X
				INCX
				INCX
				LDA IIC_msg,X
				DECX
				STA time_array,X
				INCX
				INCX
				LDA IIC_msg,X
				DECX
				STA time_array,X
				INCX
				INCX
				LDA IIC_msg,X
				DECX
				STA time_array,X
				RTS

;set RTC to 00:00:00-00/00/00
resetRTC:
				CLRX
				CLRH
				CLRA
				reset_loop:
					STA time_array,X
					INCX
					CPX #6
					BNE reset_loop
				JSR writeToRTC
				RTS
				
;reset address pointer to 0x00
resetRTCAddress:
				MOV #%11010000, IIC_addr ;reset address pointer
				LDA #1   ;set message length to 1 bytes
				STA msgLength
				CLRA
				CLRX
				STA IIC_msg,X
				JSR IIC_DataWrite
				
				RTS

;-------------------------------------------------------------


				
;-------------------------------------------------------------
;one iteration through powering ptb
getKeyboardInput:
				LDA PTBD
				AND #%11000011
				STA PTBD
				
				LDA #%0 ;clear flag
				STA keyboard_placeholder
				
				BSET 2, PTBD
				JSR KEYBOARD_DELAY
				BCLR 2, PTBD
				
				BSET 3, PTBD
				JSR KEYBOARD_DELAY
				BCLR 3, PTBD
				
				BSET 4, PTBD
				JSR KEYBOARD_DELAY
				BCLR 4, PTBD
				
				BSET 5, PTBD
				JSR KEYBOARD_DELAY
				BCLR 5, PTBD
				
				LDA keyboard_placeholder
				CMP #0
				BNE keyboardTriggeredDelay
				
				RTS
				
;keyboard interrupt
_vKeyboard:
				CLR keyboard
				BSET 2, KBISC ;CLEAR FLAG
				BSET 2, KBISC ;CLEAR FLAG
				LDA PTAD
				AND #%00001111
				LSLA
				LSLA
				LSLA
				LSLA
				STA $172
				LDA PTBD
				AND #%00111100
				LSRA
				LSRA
				ORA $172
				STA $172
				CLRH
				CLRX
				use_keyboard_map:
					CPX #$10
					BEQ Clear_Flag
					LDA keyboard_map,X
					INCX
					CMP $172
					BNE use_keyboard_map
				DECX
				
				STX keyboard	
				
				BRA Clear_Flag
				
;two long delays that get rid of switch bouncing
keyboardTriggeredDelay:
				JSR LONG_DELAY
				JSR LONG_DELAY
				rts			
			
Clear_Flag:
				LDA keyboard_placeholder
				INCA
				STA keyboard_placeholder
				JSR LONG_DELAY
				BSET 2, KBISC ;CLEAR FLAG
				RTI	
				
KEYBOARD_DELAY:
		LDA #5
		STA $171
		keyboard_loop1:
				LDA $171
				DECA
				STA $171
				BNE keyboard_loop1
		RTS
		
;------------------------------------------------
;I2C MASTER
;--------------------------------------------------------------------------------------------
;ACUAL INTERUPT START
_Viic:
		;2
										;CLEAR INTERUPT
		BSET IICS_IICIF, IICS	
										;CHECK IF MASTER 
		BRSET IICC_MST, IICC, _Viic_master    ;yes
										;should never need to be a slave 
		RTI

;------------------------------------------------------------------------------------------
;code to check if master or slave 
_Viic_master:
		;7

		BRSET IICC_TX, IICC, _Viic_master_TX               ;FOR TRANSFER
		BRA _Viic_master_RX                                ;for recive 
		

;-------------------------------------------------------------------------------------------
_Viic_master_TX:
		
		
		;1---

		LDA msgLength
		SUB current 
		BNE _Viic_master_rxAck       ;not last byte
		
		;is last byte
		BCLR IICC_MST, IICC
		BSET IICS_ARBL, IICS    ;ARBITRATION LOST, NO CODE MADE FOR RECOVERY
		
		RTI
		
		
		
;-------------------------------------------------------------------------------------------
;is ther an acknowlege
_Viic_master_rxAck:
		;9

		BRCLR IICS_RXAK, IICS, _Viic_master_EoAC          ;ack from slave recived 
		;BRA _Viic_master_EoAC
		NOP 
		NOP
		NOP
		NOP
		NOP 
		NOP
		NOP
		NOP
		NOP 
		NOP
		NOP
		NOP
		BCLR IICC_MST, IICC                               ; NO ACK FROM SLAVE RECIVED 
		
		RTI
		
;-------------------------------------------------------------------------------------------
;end of address cycle, check for recieve or write data
_Viic_master_EoAC:
		;5

		;read from or transfer to slave 
		LDA IIC_addr                    ;check if read or transfer
		AND #%00000001
		BNE _Viic_master_toRxMode
		
		CLRH
		LDX current
		LDA IIC_msg,X
		STA IICD
		
		LDA current 
		INCA
		STA current
		
		RTI
		
;-------------------------------------------------------------------------------------------
;perform dummy read
_Viic_master_toRxMode:
		;10

		BCLR IICC_TX, IICC                              ;DUMMY READ FOR EoAC
		LDA IICD
		RTI
		
;-------------------------------------------------------------------------------------------
;Receive data and check if nearing message completion 
_Viic_master_RX:
		;8

		;last bye to be read
		LDA msgLength 
		SUB current
		BEQ _Viic_master_rxStop
		
		;2nd to last byte to be read?
		DECA ;this was originally a INCA in the provided code. Without this DECA, the NACK is never sent at the end of the rx.
		BEQ _Viic_master_txACK
		
		BRA _Viic_master_readData
		
;-------------------------------------------------------------------------------------------
;generate stope condition for recive
_Viic_master_rxStop:
		;12

		BCLR IICC_MST, IICC                          ;SEND STOP BIT
		BCLR IICC_TXAK, IICC
		BRA _Viic_master_readData

;------------------------------------------------------------------------------------------
;generate acknowlege signal 
_Viic_master_txACK:
		BSET IICC_TXAK, IICC             ;TRANSER ACKNOWLEGE
		BRA _Viic_master_readData
		
		
;-----------------------------------------------------------------------------------------
;Read and Store data 
_Viic_master_readData:
		;11
		CLRH 
		LDX current
		;read byte fro IICD and store into IIC_msg
		LDA IICD
		STA IIC_msg, X                               ; store message into indexed location
		
		LDA current                                  ;increment current
		INCA
		STA current 
		
		RTI                                          ;leave interrupt


		
;-------------------------------------------------------------------------------------------
;Initial configuration
IIC_Startup_Master:
		;6

		;SET BAUD RATE TO 50KBPS
		LDA #%10000111
		STA IICF
		
		;ENABLE IIC AND INTERUPTS 
		BSET IICC_IICEN, IICC
		BSET IICC_IICIE, IICC
		RTS

;------------------------------------------------------------------------------------------
;generate acknowlege signal 
IIC_DataWrite:
		;3

		LDA #0                             ;INITIALIZE CURRENT
		STA current
		
		BSET 5, IICC;IICC_MST, IICC                        ;IICC_MST  ;SET MASTER MODE
		BSET IICC_TX, IICC                  ;SET TRANSMIT
		
		LDA IIC_addr                        ;SEND SLAVE AD6DRESS
		STA IICD
		

		RTS
		
;-----------------------------------------------------------------------------------------
DELAY:
		LDA #5
		STA $120
		loop1:
				LDA #100
				STA $121
				loop2:
						LDA $121
						DECA
						STA $121
						BNE loop2
				LDA $120
				DECA
				STA $120
				BNE loop1
		RTS
;-------------------------------------------------------------------------------------------
LONG_DELAY:
		LDA #120
		STA $122
		long_loop:
			JSR DELAY
			LDA $122
			DECA
			STA $122
			CMP #0
			BNE long_loop
			RTS
			
RTS
