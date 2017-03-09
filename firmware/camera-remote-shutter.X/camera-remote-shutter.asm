;=============================================================================
; @(#)camera-remote-shutter.asm  0.2.2  2014/12/08
;   ________        _________________.________
;  /  _____/  ____ /   _____/   __   \   ____/
; /   \  ___ /  _ \\_____  \\____    /____  \
; \    \_\  (  <_> )        \  /    //       \
;  \______  /\____/_______  / /____//______  /
;         \/              \/               \/
; Copyright (c) 2014 by Alessandro Fraschetti.
; All Rights Reserved.
;
; Description: Camera Remote Shutter/Focus Trigger Controller
; Target.....: Microchip PIC 12F683 Microcontroller
; Compiler...: Microchip Assembler (MPASM)
; Note.......: tested on Canon EOS400D
;=============================================================================

        processor   12f683
        #include    <p12f683.inc>
        __CONFIG    _CP_OFF & _CPD_OFF & _BOREN_OFF & _WDT_OFF & _MCLRE_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
					; _CP_[ON/OFF]    : code protect program memory enable/disable
                    ; _CPD_[ON/OFF]   : code protect data memory enable/disable
					; _BODEN_[ON/OFF] : Brown-Out Reset enable/disable
					; _WDT_[ON/OFF]   : watchdog timer enable/disable
					; _MCLRE_[ON/OFF] : MCLR pin function  digital IO/MCLR
					; _PWRTE_[ON/OFF] : power-up timer enable/disable

;=============================================================================
;  File register use
;=============================================================================
		cblock		h'20'
			w_temp						; variable used for context saving
			status_temp					; variable used for context saving
            pclath_temp                 ; variable used for context saving
			d1, d2, d3					; delay routine vars

            controllerStatus            ; controller status register
            switchStatus                ; switches status register
		endc


;=============================================================================
;  Constants
;=============================================================================
SHUTTER_SW  equ     GP5
FOCUS_SW    equ     GP4
INT_ON_SW   equ     GP3
SHUTTER_OUT equ     GP0
FOCUS_OUT   equ     GP1
ACTIVITY    equ     GP2
SHUTTER     equ     0x00
FOCUS       equ     0x01


;=============================================================================
;  Start of code
;=============================================================================
;start
		org			h'0000'				; processor reset vector
		goto		main				; jump to the main routine

		org			h'0004'				; interrupt vector location
		movwf		w_temp				; save off current W register contents
		swapf		STATUS, W			; move status register into W register
		movwf		status_temp			; save off contents of STATUS register
        swapf       PCLATH, W           ; move pclath register into W register
        movwf       pclath_temp         ; save off contents of PCLATH register

        ; isr code can go here or be located as a call subroutine elsewhere
        clrf		STATUS				; select Bank0
        movf        GPIO, W
        bcf         INTCON, GPIF        ; clear interrupt flag

        swapf       pclath_temp, W      ; retrieve copy of PCLATH register
        movwf       PCLATH              ; restore pre-isr PCLATH register contents
		swapf		status_temp, W		; retrieve copy of STATUS register
		movwf		STATUS				; restore pre-isr STATUS register contents
		swapf		w_temp, F
		swapf		w_temp, W			; restore pre-isr W register contents
		retfie							; return from interrupt


;=============================================================================
;  Init Internal Oscillator
;    set internal clock speed to 31KHz
;=============================================================================
init_osc:

		errorlevel	-302

        bsf			STATUS, RP0				; select Bank1
        movlw       b'00000111'             ; set the clock speed to 31KHz
        movwf       OSCCON
        bcf			STATUS, RP0				; select Bank0

		errorlevel  +302

  		return


;=============================================================================
;  Init I/O ports
;    set GP0, GP1 and GP2 as Output, the others as Input,
;=============================================================================
init_ports:

		errorlevel	-302

        bsf			STATUS, RP0				; select Bank1
        clrf        GPIO                    ; init GPIO

        movlw       0x07                    ; turn comparators off
        movwf       CMCON0
        clrf        ANSEL                   ; make all ports as digital I/O

        movlw		b'111000'				; PORT input/output
        movwf       TRISIO
        
        bcf			STATUS, RP0				; select Bank0

		errorlevel  +302

  		return


;=============================================================================
;  Init Interrupt
;    set interrupt-on-change on INT_ON_SW
;=============================================================================
init_interrupt:

		errorlevel	-302

        bsf			STATUS, RP0				; select Bank1
        bsf         IOC, INT_ON_SW          ; enable int-on-change
        movlw       b'10001000'             ; enable port change and global int
        movwf       INTCON
        bcf			STATUS, RP0				; select Bank0

		errorlevel  +302

  		return


;=============================================================================
;  Delay routines
;    5ms for 31KHz clock speed
;=============================================================================
delay:

        movlw       0x31
        movwf       d1
        nop
        nop

delayLoop
        decfsz      d1, F
        goto        delayLoop

        return


;=============================================================================
;  main routine
;=============================================================================
main
        call 		init_osc
		call 		init_ports
        call        init_interrupt

        clrf        controllerStatus
        clrf        switchStatus
;        bcf         GPIO, SHUTTER_OUT
;        bcf         GPIO, FOCUS_OUT
;        bcf         GPIO, ACTIVITY

mainloop

        sleep

testShutterSwitch
        btfsc       GPIO, SHUTTER_SW
        goto        releasedShutterSwitch
        call        delay
        btfsc       GPIO, SHUTTER_SW
        goto        releasedShutterSwitch

        btfsc       switchStatus, SHUTTER
        goto        endloop
        bsf         switchStatus, SHUTTER
        btfsc       controllerStatus, SHUTTER
        goto        triggerClickUp

triggerClickDown
        bsf         controllerStatus, SHUTTER
        bsf         GPIO, ACTIVITY
        bsf         GPIO, SHUTTER_OUT
        goto        testFocusSwitch

triggerClickUp
        bcf         controllerStatus, SHUTTER
        bcf         GPIO, ACTIVITY
        bcf         GPIO, SHUTTER_OUT
        goto        testFocusSwitch

releasedShutterSwitch
        bcf         switchStatus, SHUTTER


testFocusSwitch
        btfsc       controllerStatus, SHUTTER
        goto        endloop

        btfsc       GPIO, FOCUS_SW
        goto        releasedFocusSwitch
        call        delay
        btfsc       GPIO, FOCUS_SW
        goto        releasedFocusSwitch

        btfsc       switchStatus, FOCUS
        goto        endloop
        bsf         switchStatus, FOCUS
        btfsc       controllerStatus, FOCUS
        goto        endloop

triggerFocusDown
        bsf         controllerStatus, FOCUS
        bsf         GPIO, ACTIVITY
        bsf         GPIO, FOCUS_OUT
        goto        endloop

triggerFocusUp
        bcf         controllerStatus, FOCUS
        bcf         GPIO, ACTIVITY
        bcf         GPIO, FOCUS_OUT
        goto        endloop

releasedFocusSwitch
        bcf         switchStatus, FOCUS
        btfsc       controllerStatus, FOCUS
        goto        triggerFocusUp

endloop
        goto        mainloop


        end
