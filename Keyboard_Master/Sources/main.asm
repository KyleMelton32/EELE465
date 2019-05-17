;Main.s by Spencer Morley-Short, Kyle Melton
;1/30/19
;MASTER
			INCLUDE 'derivative.inc'
			XDEF _Startup, main, _Viic, _vKeyboard
			XREF __SEG_END_SSTACK	; symbol defined by the linker for the end of the stack
		
	ORG $0060
	IIC_addr: DS.B 1   ;TRACK IIC ADRESS
	msgLength: DS.B 1  ; TRACK TOTAL MESSAGE LENGTH
	current: DS.B 1    ; TRACK WHICH BYTE WE HAVE SENT 
	IIC_msg: DS.B 2    ; enable 32 bit transmission 
	
	keyboard: DS.B 1
	
	year: DS.B 1
	month: DS.B 1
	day: DS.B 1
	hour: DS.B 1
	minute: DS.B 1
	second: DS.B 1
	time_placeholder: DS.B 1

;code section
	ORG $E000			
main:
	_Startup:
			
				LDHX #__SEG_END_SSTACK  ;INITIALZE THE STACK POINTER
				CLI     ;ENABLE INTERUPTS 
	
				LDA SOPT1 ;DISABLE WATCHDOG
				AND #$7F
				STA SOPT1
	
	
				LDA SOPT2      ;SET PTB PINS TO BE USED FOR SDA/SCL
				ORA #%00000010
				STA SOPT2
				
				MOV #$10, IIC_addr   ;set slave address 
				MOV #$C1, IIC_msg   ;set actual message
	
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
				
				BRA mainLoop
				CLRH
				CLRX
				MOV #%11010000, IIC_addr
				
				
				LDA #2   ;set message length to 2 byte
				STA msgLength
				LDA #$0
				CLRX
				STA IIC_msg,X
				
				JSR IIC_DataWrite    ;begin data transfer
				
				BRA mainLoop
				
getTime:

				JSR keyboardEnable
				LDA keyboard
				
				LDHX #10
				MUL
				
				STA time_placeholder
				
				JSR keyboardEnable
				
				LDA time_placeholder
				
				ADD keyboard
				
				STA time_placeholder
				
				STA IIC_msg
				
				MOV #$10, IIC_addr   ;set slave address
				
				LDA #1   ;set message length to 1 byte
				STA msgLength
				JSR DELAY
				JSR IIC_DataWrite    ;begin data transfer
				
				MOV #$20, IIC_addr   ;set slave address
				
				LDA #1   ;set message length to 1 byte
				STA msgLength
				JSR DELAY
				JSR IIC_DataWrite    ;begin data transfer
				rts
				

				
keyboardEnable:
				LDA PTBD
				AND #%11000011
				STA PTBD
				
				LDA #%0 ;clear flag
				STA $170
				
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
				
				LDA $170
				CMP #0
				BEQ keyboardEnable
				
				JSR LONG_DELAY
				
				RTS
				
_vKeyboard:
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
				
				CMP #%00101000
				BEQ Send_0
				CMP #%00010001
				BEQ Send_1
				CMP #%00100001
				BEQ Send_2
				CMP #%01000001
				BEQ Send_3
				CMP #%00010010
				BEQ Send_4
				CMP #%00100010
				BEQ Send_5
				CMP #%01000010
				BEQ Send_6
				CMP #%00010100
				BEQ Send_7
				CMP #%00100100
				BEQ Send_8
				CMP #%01000100
				BEQ Send_9
				CMP #%10000001
				BEQ Send_A
				CMP #%10000010
				BEQ Send_B
				CMP #%10000100
				BEQ Send_C
				CMP #%10001000
				BEQ Send_D
				CMP #%00011000
				BEQ Send_E
				CMP #%01001000
				BEQ Send_F
				BRA Clear_Flag
				
Send_0:
				MOV #%00000000, keyboard
				BRA Clear_Flag
				
Send_1:
				MOV #%00000001, keyboard
				BRA Clear_Flag
				
Send_2:
				MOV #%00000010, keyboard
				BRA Clear_Flag
				
Send_3:
				MOV #%00000011, keyboard
				BRA Clear_Flag
				
Send_4:
				MOV #%00000100, keyboard
				BRA Clear_Flag
				
Send_5:
				MOV #%00000101, keyboard
				BRA Clear_Flag
				
Send_6:
				MOV #%00000110, keyboard
				BRA Clear_Flag
				
Send_7:
				MOV #%00000111, keyboard
				BRA Clear_Flag
				
Send_8:
				MOV #%00001000, keyboard
				BRA Clear_Flag
				
Send_9:
				MOV #%00001001, keyboard
				BRA Clear_Flag
				
Send_A:
				MOV #%00001010, keyboard
				BRA Clear_Flag
				
Send_B:
				MOV #%00001011, keyboard
				BRA Clear_Flag
				
Send_C:
				MOV #%00001100, keyboard
				BRA Clear_Flag
				
Send_D:
				MOV #%00001101, keyboard
				BRA Clear_Flag
				
Send_E:
				MOV #%00001110, keyboard
				BRA Clear_Flag
				
Send_F:
				MOV #%00001111, keyboard
				BRA Clear_Flag
				
Clear_Flag:
				LDA $170
				INCA
				STA $170
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
;check if transmitting or reciving 
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
		
		LDA IIC_msg
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
		INCA
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

		;4 

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
		loop:
			JSR DELAY
			LDA $122
			DECA
			STA $122
			BNE loop
		RTS
