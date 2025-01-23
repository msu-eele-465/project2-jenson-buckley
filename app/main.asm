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
        mov.b   #00011100b, R14
        call    #i2c_start
        call    #i2c_tx_byte
        call    #i2c_stop
        jmp     Main

;-------------------------------------------------------------------------------
; Subroutines
;-------------------------------------------------------------------------------

; "clock" used for I2C bit banging
ClkPeriod:
        mov.w   #1000, R15             ; Outer loop count
        bis.b   #BIT0, &P2OUT          ; drive SCL high
CP1:
        dec.w   R15                    ; Decrement R15
        jnz     CP1                     ;loop done?
        bic.b   #BIT0, &P2OUT          ; drive SCL high
        mov.w   #1000, R15             ; Outer loop count
CP2:
        dec.w   R15                    ; Decrement R15
        jnz     CP2                     ;loop done?
        ret

; send I2C start condition (assumes both SDA and SCL are high)
i2c_start:
        mov.w   #500, R15              ; Outer loop count
        bis.b   #BIT0, &P2OUT          ; drive SCL high
START1:
        dec.w   R15                    ; Decrement R15
        jnz     START1                 ; loop done?
        bic.b   #BIT1, &P2OUT          ; drive SDA low
        mov.w   #500, R15              ; Outer loop count
START2:
        dec.w   R15                    ; Decrement R15
        jnz     START2                 ;loop done?
        bic.b   #BIT0, &P2OUT          ; drive SCL low
        mov.w   #1000, R15             ; Outer loop count
START3:
        dec.w   R15                    ; Decrement R15
        jnz     START3                  ;loop done?
        ret

; send I2C stop condition (assumes SDA is low and SCL is high)
i2c_stop
        mov.w   #500, R15              ; Outer loop count
        bis.b   #BIT0, &P2OUT          ; drive SCL high
STOP1:
        dec.w   R15                    ; Decrement R15
        jnz     STOP1                  ; loop done?
        bis.b   #BIT1, &P2OUT          ; drive SDA high
        mov.w   #500, R15              ; Outer loop count
STOP2:
        dec.w   R15                    ; Decrement R15
        jnz     STOP2                 ; loop done?
        bic.b   #BIT0, &P2OUT          ; drive SCL low
        mov.w   #1000, R15             ; Outer loop count
STOP3:
        dec.w   R15                    ; Decrement R15
        jnz     STOP3                  ; loop done?
        ret

; send acknowledge bit (drive SDA low on 9th clock edge for AWK; leave high for no AWK)
i2c_tx_ack:
        bic.b   #BIT1,&P2OUT    ; drive SDA low
        call    #ClkPeriod
        ret

; send a byte stored in R14 
i2c_tx_byte:
        mov.b   #10000000, R13
TX2:
        bit.b   R13, R14
        jz      clear
        jmp     set
clear:
        bic.b   #BIT1,&P2OUT
        jmp     end
set:
        bis.b   #BIT1,&P2OUT
        jmp     end
end:
        call    #ClkPeriod
        CLRC
        rrc.b   R13
        jnc     TX2
        ret   

; 
i2c_tx_ack:
i2c_stop
        mov.w   #500, R15              ; Outer loop count
        bis.b   #BIT0, &P2OUT          ; drive SCL high
STOP1:
        dec.w   R15                    ; Decrement R15
        jnz     STOP1                  ; loop done?
        bis.b   #BIT1, &P2OUT          ; drive SDA high
        mov.w   #500, R15              ; Outer loop count
STOP2:
        dec.w   R15                    ; Decrement R15
        jnz     STOP2                 ; loop done?
        bic.b   #BIT0, &P2OUT          ; drive SCL low
        mov.w   #1000, R15             ; Outer loop count
STOP3:
        dec.w   R15                    ; Decrement R15
        jnz     STOP3                  ; loop done?
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