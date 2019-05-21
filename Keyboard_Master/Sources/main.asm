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
	
	year: DS.B 1
	month: DS.B 1
	day: DS.B 1
	hour: DS.B 1
	minute: DS.B 1
	second: DS.B 1
	time_placeholder: DS.B 1
	time_placed_flag: DS.B 1
	time_placed_flag2: DS.B 1
	time_placed_flag3: DS.B 1
	rtc_placeholder: DS.B 1

;code section
	ORG $E000
keyboard_map DC.B %00101000,%00010001,%00100001,%01000001,%00010010,%00100010,%01000010,%00010100,%00100100,%01000100,%10000001,%10000010,%10000100,%10001000,%00011000,%01001000	

main:
	_Startup:
			
				LDHX #__SEG_END_SSTACK  ;INITIALZE THE STACK POINTER
				TXS
				CLI     ;ENABLE INTERUPTS 
	
				LDA SOPT1 ;DISABLE WATCHDOG
				;ORA #$80
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
				
				CLR time_placed_flag
				CLR time_placed_flag2
				CLR time_placed_flag3

mainLoop:

				JSR getTime
				LDA time_placeholder
				STA hour
				
				JSR getTime
				LDA time_placeholder
				STA minute
				
				JSR getTime
				LDA time_placeholder
				STA second
				
				JSR getTime
				LDA time_placeholder
				STA month
				
				JSR getTime
				LDA time_placeholder
				STA day
				
				JSR getTime
				LDA time_placeholder
				STA year
				JSR LONG_DELAY
				
				INC time_placed_flag ; enable rtc
				JSR updateRTC
				
				BRA mainLoop
				
getTime:

				JSR keyboardEnable
				LDA keyboard
				
				LSLA
				LSLA
				LSLA
				LSLA
				
				STA time_placeholder
				
				JSR keyboardEnable
				
				LDA time_placeholder
				
				ORA keyboard
				
				STA time_placeholder
				
				STA IIC_msg
				
				MOV #$10, IIC_addr   ;set slave address
				
				LDA #1   ;set message length to 1 byte
				STA msgLength
				JSR IIC_DataWrite    ;begin data transfer
				
				MOV #$20, IIC_addr   ;set slave address
				
				LDA #1   ;set message length to 1 byte
				STA msgLength
				JSR DELAY
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				rts
				
writeRTCMessage:
					CLRH
					LDX rtc_placeholder
					STA IIC_msg,X
					INC rtc_placeholder
					RTS
				
updateRTC:
				MOV #%11010000, IIC_addr
				
				LDA #8   ;set message length to 7 bytes
				STA msgLength
				
				CLR rtc_placeholder
				
				LDA #$0 ;write to seconds address
				JSR writeRTCMessage
				LDA second
				JSR writeRTCMessage
				LDA minute
				JSR writeRTCMessage
				LDA hour
				JSR writeRTCMessage
				CLRA ;skip day register
				JSR writeRTCMessage
				LDA day
				JSR writeRTCMessage
				LDA month
				JSR writeRTCMessage
				LDA year
				JSR writeRTCMessage
				
				JSR IIC_DataWrite    ;begin data transfer
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				JSR DELAY
				
				JSR resetRTCAddress
				
				RTS
				
keyboardEnable:
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
				BNE keyboardTriggered
				
				LDA time_placed_flag
				CMP #0
				BEQ keyboardEnable ; if time hasn't been set, wait for that
				
				inc time_placed_flag
				JSR updateFromRTC
				BRA keyboardEnable
				
keyboardTriggered:
				JSR LONG_DELAY
				JSR LONG_DELAY
				rts
				
finished:
				RTS
				
resetRTCAddress:
				MOV #%11010000, IIC_addr ;reset address pointer
				LDA #1   ;set message length to 1 bytes
				STA msgLength
				CLRA
				CLRX
				STA IIC_msg,X
				JSR IIC_DataWrite
				
				RTS
				
updateFromRTC:
				LDA time_placed_flag
				CMP #255
				BNE finished ; only update from rtc every 255 * 255 cycles

				CLR time_placed_flag
				INC time_placed_flag ; stay inside timeset state
				
				INC time_placed_flag2
				LDA time_placed_flag2
				CMP #80
				BEQ resetRTCAddress ; reset the address for the upcoming read
				CMP #120
				BNE finished
				CLR time_placed_flag2
				
				LDA #$0F ; we want 16 bytes of data back
				STA msgLength
				MOV #%11010001, IIC_addr
				JSR IIC_DataWrite
				
				JSR LONG_DELAY ;;todo remove the delays once not in debug
				CLRX
				CLRH
				LDA IIC_msg,X
				CMP second
				BEQ finished
				STA second
				
				MOV #$20, IIC_addr   ;set slave address
				
				LDA #1   ;set message length to 1 byte
				STA msgLength
				JSR IIC_DataWrite    ;begin data transfer
				RTS
				
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

