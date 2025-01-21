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
SetupP1:     
        bic.b   #BIT0,&P1OUT            ; Clear P1.0 output
        bis.b   #BIT0,&P1DIR            ; P1.0 output
        bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pins

Mainloop:
        jmp     Delay                   ; Jump to delay subroutine
        jmp     Timer                   ; Jump to timer subroutine


;-------------------------------------------------------------------------------
; Delay Loop
;-------------------------------------------------------------------------------
Delay:
        xor.b   #BIT0, &P1OUT          ; Toggle P1.0 every 0.5s
        mov.w   #2, R14                ; Outer loop count
OuterLoop:
        mov.w   #65000, R15            ; Inner loop count (0.5 second period maxes out 16bit register)
InnerLoop:
        dec.w   R15                    ; Decrement R15
        jnz     InnerLoop              ; Inner loop done?
        dec.w   R14                    ; Decrement R14
        jnz     OuterLoop              ; Outer loop done?

        mov.w   #44000, R15            ; Remaining cycles
InnerLoop2:
        dec.w   R15                    ; Decrement R15
        jnz     InnerLoop2             ; Finish remaining cycles

        jmp     Delay                  ; Repeat the loop

;-------------------------------------------------------------------------------
; Timer Setup and loop
;-------------------------------------------------------------------------------
Timer:		
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
L2:
        jmp     L2                      ; Infinite Loop

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