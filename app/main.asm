;-------------------------------------------------------------------------------
; Project 2: Bit-bang I2C
; P.Buckley & D.Jenson, EELE-465
; 01/21/25
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.

;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer


;-------------------------------------------------------------------------------
; Main loop here (Timer or Delay can be move dto the top to pick which method it uses)
;-------------------------------------------------------------------------------
; LED on P1.0
SetupLED:     
        bic.b   #BIT0,&P1OUT            ; Clear P1.0 output
        bis.b   #BIT0,&P1DIR            ; P1.0 output
        bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pins

; SCL on P2.0 and SDA on P2.1
SetupPorts:     
        bis.b   #BIT0,&P2OUT            ; Set P2.0 output
        bis.b   #BIT1,&P2OUT            ; Set P2.1 output
        bis.b   #BIT0,&P2DIR            ; P2.0 output
        bis.b   #BIT1,&P2DIR            ; P2.1 output
        bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pins

SetupHeatbeatTimer:		
        ; Setup Timer TB0
		bis.w	#TBCLR, &TB0CTL
		bis.w	#TBSSEL__ACLK, &TB0CTL
		bis.w	#MC__UP, &TB0CTL

		; Setup Compare Register
		mov.w	#16384, &TB0CCR0

		bis.w	#CCIE, &TB0CCTL0
		bic.w	#CCIFG, &TB0CCTL0

		; Enable global interrupts
		bis.w	#GIE, SR

Main:
        mov.b   #11000001b, R14         ; h60 address with write bit high
        call    #i2c_start
        call    #i2c_tx_byte
        call    #i2c_rx_byte
        call    #i2c_rx_ack
EJECT   call    #i2c_stop
        jmp     Main

;-------------------------------------------------------------------------------
; Subroutines
;-------------------------------------------------------------------------------

; "clock" used for I2C bit banging (low to high)
ClkPeriod:
        mov.w   #1000, R15             ; Outer loop count
        bic.b   #BIT0, &P2OUT          ; drive SCL low
CP1:
        dec.w   R15                    ; Decrement R15
        jnz     CP1                     ;loop done?
        bis.b   #BIT0, &P2OUT          ; drive SCL high
        mov.w   #1000, R15             ; Outer loop count
CP2:
        dec.w   R15                    ; Decrement R15
        jnz     CP2                     ;loop done?
        ret

; "clock" used for I2C bit banging that DRIVES SDA HIGH
ClkDataHigh:
        mov.w   #500, R15               ; Outer loop count
        bic.b   #BIT0, &P2OUT           ; drive SCL low
CDH1:
        dec.w   R15                     ; Decrement R15
        jnz     CDH1                    ; loop done?
        bis.b   #BIT1, &P2OUT           ; drive SDA high
        mov.w   #500, R15               ; Outer loop count
CDH2:
        dec.w   R15                     ; Decrement R15
        jnz     CDH2                    ; loop done?
        bis.b   #BIT0, &P2OUT           ; drive SCL high
        mov.w   #1000, R15              ; Outer loop count
CDH3:
        dec.w   R15                    ; Decrement R15
        jnz     CDH3                    ; loop done?
        ret

; "clock" used for I2C bit banging that DRIVES SDA LOW
ClkDataLow:
        mov.w   #500, R15               ; Outer loop count
        bic.b   #BIT0, &P2OUT           ; drive SCL low
CDL1:
        dec.w   R15                     ; Decrement R15
        jnz     CDL1                    ; loop done?
        bic.b   #BIT1, &P2OUT           ; drive SDA low
        mov.w   #500, R15               ; Outer loop count
CDL2:
        dec.w   R15                     ; Decrement R15
        jnz     CDL2                    ; loop done?
        bis.b   #BIT0, &P2OUT           ; drive SCL high
        mov.w   #1000, R15              ; Outer loop count
CDL3:
        dec.w   R15                     ; Decrement R15
        jnz     CDL3                    ; loop done?
        ret

; send I2C start condition (assumes SCL is high)
i2c_start:
        bis.b   #BIT1,&P2DIR           ; SDA as output
        mov.w   #1000, R15             ; Outer loop count
        bis.b   #BIT1, &P2OUT          ; drive SDA high
START1:
        dec.w   R15                    ; Decrement R15
        jnz     START1                 ; loop done?
        bic.b   #BIT1, &P2OUT          ; drive SDA low
        mov.w   #1000, R15             ; Outer loop count
START2:
        dec.w   R15                    ; Decrement R15
        jnz     START2                 ; loop done?
        ret

; send I2C stop condition (assumes SCL is high)
i2c_stop:
        mov.w   #1000, R15             ; Outer loop count
        bic.b   #BIT1, &P2OUT          ; drive SDA low
        bic.b   #BIT0, &P2OUT          ; drive SCL low
STOP1:
        dec.w   R15                    ; Decrement R15
        jnz     STOP1                  ; loop done?
        bis.b   #BIT0, &P2OUT          ; drive SCL high
        mov.w   #500, R15              ; Outer loop count
STOP2:
        dec.w   R15                    ; Decrement R15
        jnz     STOP2                  ; loop done?
        bis.b   #BIT1, &P2OUT          ; drive SDA high
        mov.w   #500, R15             ; Outer loop count
STOP3:
        dec.w   R15                    ; Decrement R15
        jnz     STOP3                  ; loop done?
        ret

; receive AWK bit (release SDA on 9th clock edge; stays low = AWK; goes high = NAWK)
i2c_tx_ack:
        bic.b   #BIT1,&P2DIR            ; SDA as input
        bis.b   #BIT1, &P2REN           ; enable internal resisitor 
        bis.b   #BIT1, &P2OUT           ; set pullup resistor
        mov.w   #1000, R15              ; Outer loop count
        bic.b   #BIT0, &P2OUT           ; drive SCL low
TXACK1:
        dec.w   R15                     ; Decrement R15
        jnz     TXACK1                  ; loop done?
        bis.b   #BIT0, &P2OUT           ; drive SCL high
        mov.w   #500, R15               ; Outer loop count
TXACK2:
        dec.w   R15                     ; Decrement R15
        jnz     TXACK2                  ; loop done?
        mov.b   #00000010b, R13         ; set SDA mask
        bit.b   &P2IN, R13              ; read SDA
        jnz     TXNAWK1                  ; run thorugh NAWK routine if necessary
        mov.w   #500, R15               ; Outer loop count
TXACK3:  
        dec.w   R15                     ; Decrement R15
        jnz     TXACK3                  ; loop done?
        bic.b   #BIT1,&P2OUT            ; drive SDA low
        bis.b   #BIT1,&P2DIR            ; SDA as output
        ret
TXNAWK1:
        mov.w   #500, R15               ; Outer loop count
TXNAWK2:
        dec.w   R15                     ; Decrement R15
        jnz     TXNAWK2                 ; loop done?
        jmp     EJECT
        ret

; send a byte stored in R14 
i2c_tx_byte:
        mov.b   #10000000, R13
TX1:
        bit.b   R13, R14
        jz      TXCLEAR
        jmp     TXSET
TXCLEAR:
        call    #ClkDataLow
        jmp     TXEND
TXSET:
        call    #ClkDataHigh
        jmp     TXEND
TXEND:
        CLRC
        rrc.b   R13
        jnc     TX1
        ret

; send AWK bit (pull SDA on 9th clock edge; stays low = AWK; goes high = NAWK)
i2c_rx_ack:
        bis.b   #BIT1,&P2DIR            ; SDA as output
        bic.B   #BIT1,&P2OUT            ; drive SDA low
        call    #ClkPeriod
        bic.b   #BIT1,&P2DIR            ; SDA as input
        ret

; receive a byte into R12
i2c_rx_byte:
        mov.w   #1,R13                  ; clear receiving register (1 to check for carry for stop condition)
        bic.b   #BIT1,&P2DIR            ; SDA as input
        bis.b   #BIT1, &P2REN           ; enable internal resisitor 
        bis.b   #BIT1, &P2OUT           ; set pullup resistor
RXSTART:
        mov.w   #1000, R15              ; Outer loop count
        bic.b   #BIT0, &P2OUT           ; drive SCL low
RX1:
        dec.w   R15                     ; Decrement R15
        jnz     RX1                     ; loop done?
        bis.b   #BIT0, &P2OUT           ; drive SCL high
        mov.w   #500, R15               ; Outer loop count
RX2:
        dec.w   R15                     ; Decrement R15
        jnz     RX2                     ; loop done?
        mov.b   #00000010b, R13         ; set SDA mask
        bit.b   &P2IN, R13              ; read SDA
        CLRC                            ; clear carry bit
        rla.b   R13                     ; shift data over to make room for new bit
        jc      RXEND3                  ; stop reading bits
        jnz     RXHIGH       
        jz      RXLOW           
RXHIGH:
        bis.b   #BIT0, R12             ; set
        jmp     RXEND1
RXLOW:
        bic.b   #BIT0, R12             ; set
        jmp     RXEND1
RXEND1:
        mov.w   #500, R15               ; Outer loop count
RXEND2:
        dec.w   R15                     ; Decrement R15
        jnz     RXEND2                  ; loop done?
        jmp     RXSTART
RXEND3:
        ret

;-------------------------------------------------------------------------------
; Interrupt Service Routines
;-------------------------------------------------------------------------------
ISR_TB0_CCR0:
		xor.b	#BIT0, &P1OUT               ; Toggle LED1 (P1.0)
		bic.w	#CCIFG, &TB0CCTL0           ; Clear TB1 interrupt flag
		reti


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET

            .sect   ".int43"                ; Timer B0 Overflow Vector
            .short  ISR_TB0_CCR0