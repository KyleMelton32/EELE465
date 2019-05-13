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
	
	ORG $E000
	
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
				
				;SET PTBD TO OUTPUT
  				LDA #%11111111
  				STA PTBDD				
				
				;INTIALIZE PORTS
				CLR		PTBD
				
				CLR IIC_msg
				
;---------------------------------------------------------------------------
mainLoop:

				LDA IIC_msg
				
				STA PTBD
							
				BRA mainLoop

;------------------I2C CODE---------------------------------------------
IIC_Startup_slave:
				;set baud rate 50kbps
				LDA #%10000111
				STA IICF
				;set slave address
				LDA #$10
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
