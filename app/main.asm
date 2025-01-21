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
SetupLED:     
        bic.b   #BIT0,&P1OUT            ; Clear P1.0 output
        bis.b   #BIT0,&P1DIR            ; P1.0 output
        bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pins

SetupPorts:     
        bic.b   #BIT0,&P2OUT            ; Clear P2.0 output
        bic.b   #BIT1,&P2OUT            ; Clear P2.1 output
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
        jmp     Main                   ; Jump to timer subroutine

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