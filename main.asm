;
; dataTransmission.asm
;
; Created: 3-11-2019 11:56:30
; Author : Adriaan
;


.org 0x0000

rjmp RESET
rjmp INT0_ISR
rjmp PCINT0_ISR
rjmp TIM1_COMPA_ISR
rjmp TIM1_OVF_ISR
rjmp TIM0_OVF_ISR
rjmp EE_RDY_ISR
rjmp ANA_COMP_ISR
rjmp ADC_ISR
rjmp TIM1_COMPB_ISR
rjmp TIM0_COMPA_ISR
rjmp TIM0_COMPB_ISR
rjmp WDT_ISR
rjmp USI_START_ISR
rjmp USI_OVF_ISR

RESET:
;	Initialize stack pointer:
	ldi r16, $01						; load constant 0x01
	out SPH, r16						; write stack pointer register to bottom of data memory file
	
	ldi r16, $5f						; load constant 0x5f
	out SPL, r16						; write stack pointer

;	Initialize counter 1:
	ldi r16, $c1						; load constant 0xc1 (enable TC1, enable PWM1A, prescaler = system clock frequency)
	out TCCR1, r16						; write Timer/Counter1 Control Register
	
	;in r16, TIMSK						; load Timer/Counter1 Interrupt Mask Register
	;ori r16, $04						; and imediate 0x04 (enable TOIE1)
	;out TIMSK, r16						; write back TIMSK
	
	ldi r16, $68						; load constant 0x68 = 104
	out OCR1C, r16						; write Timer/Counter1 Output Compare Register C

;	Initialize INT0:
	in r16, MCUCR						; load MCU Control Register
	ori r16, $02						; or imediate 0x02 (enable negative edge INT0)
	out MCUCR, r16						; write back MCUCR
	
	in r16, GIMSK						; load General Interrupt Mask Register
	ori r16, $40						; or imediate 0x40 (enable INT0)
	out GIMSK, r16						; write back GIMSK

;	Initialize GIOP:
	ldi r16, $1e						; load constant
	out PORTB, r16						; write PORTB
	ldi r16, $13						; load constant
	out DDRB, r16						; write DDRB

;	enable global interrupts:
	sei									; set interrupt bit in SREG

;	example code:
	ldi r16, $5a
	mov r1, r16
	ldi r16, $12
	mov r2, r16
	rcall WRITE_DATA
CHECK_READY:
	mov r16, r0
	andi r16, $04
	cpi r16, $04
	brne CHECK_READY
LOOP:
	rjmp LOOP

;	Write data subroutine:
;		inputs:		r1		tx_byte
;					r2		DO (0x10) / DO and DM (0x12) /DM (0x02)
;		outputs:	r0[3]	ready
WRITE_DATA:
;	Create mask and put pins low:
	mov r16, r2							; move contents of r2 into r16
	ldi r17, $ff						; load consant 0xff
	eor r16, r17						; invert mask
	in r17, PORTB						; load PORTB register
	and r17, r16						; put output pins low
	out PORTB, r17						; write back PORT register

;	Initialize counter 1:
	ldi r16, $00						; load constant zero
	out TCNT1, r16						; initialize counter 1

;	Initialize counter 1 duration:
	ldi r16, $49						; load constant 73
	out OCR1C, r16						; write 73 to max counter 1

;	Initialize transmit register:
	ldi r16, $00						; load imediate 0x00
	mov r0, r16							; initialize transmit register (bitCnt = 0, R/W = W, ready = 0)

;	Enable counter 1 interrupt:
	in r16, TIMSK						; load Timer/Counter1 Interrupt Mask Register
	ori r16, $04						; or imediate 0x04 (enable TOIE1)
	out TIMSK, r16						; write back TIMSK
	ret
	

;	INT0 ISR:
INT0_ISR:
;	Initialize counter 1:
	ldi r16, $00						; load constant zero
	out TCNT1, r16						; initialize counter 1

;	Initialize transmit register:
	ldi r16, $08						; load imediate 0x08
	mov r0, r16							; initialize transmit register (bitCnt = 0, R/W = R, ready = 0)

;	disable INT0:
	in r16, GIMSK						; load GIMSK
	andi r16, $bf						; disable INT0
	out GIMSK, r16						; write back GIMSK

;	Initialize counter 1 duration:
	ldi r16, $1e						; load constant 30
	out OCR1C, r16						; write 52 to max counter 1

;	Enable counter 1 interrupt:
	in r16, TIMSK						; load Timer/Counter1 Interrupt Mask Register
	ori r16, $04						; or imediate 0x04 (enable TOIE1)
	out TIMSK, r16						; write back TIMSK
	reti

;	Pin change interrupt:
PCINT0_ISR:
;	Counter 1 equal to A:
TIM1_COMPA_ISR:
	reti

;	Timer one overflow ISR:
TIM1_OVF_ISR:
;	Read input:
	in r18, PINB						; store input into r18

;	Reset counter:	
	;ldi r16, $00						; load constant zero
	;out TCNT1, r16						; initialize counter 1

	ldi r16, $67						; load constant 103
	out OCR1C, r16						; write 103 to max counter 1

;	Check bit R/W:
	mov r16, r0							; load r0 into r16
	andi r16, $08						; only keep bit R/W
	cpi r16, $08						; check for R/W bit
	breq READ

WRITE:
;	Check bit count
	mov r16, r0							; load r0 into r16
	andi r16, $f0						; remove lower 4 bits
	cpi r16, $80						; check if this is the last bit
	breq LAST_WRITE

;	write bit to output ports:
	in r16, PORTB						; load PORTB register
	mov r17, r1							; move data register into r17
	andi r17, $01						; remove all bits except for LSB
	cpi r17, $01						; check if bit to write equals 1
	breq WRITE_ONE

WRITE_ZERO:
;	Construct mask:
	mov r17, r2							; move mask into r17
	ldi r18, $ff						; load constant for inverting
	eor r17, r18						; invert mask
;	Write to PORTB:
	and r16, r17						; write zero to pins
	out PORTB, r16						; write back to PORTB register
	rjmp WRITE_INCR

WRITE_ONE:
;	Mask is already in r2, write to PORTB:
	or r16, r2							; set pins high
	out PORTB, r16						; write back PORTB register

WRITE_INCR:
;	If not last write: increment bit count:
	ldi r16, $10						; load 1 for addition to bit count
	add r0, r16							; increment bit count

;	shift tx_byte register (r1) to right:
	lsr r1								; shift for new LSB
	reti

LAST_WRITE:
;	Set output pins high to end the transmission:
	in r16, PORTB						; load PORTB register
	or r16, r2							; set pins high
	out PORTB, r16						; write back PORTB

;	Set ready flag:
	mov r16, r0							; move contents of r0 into r16
	ori r16, $04						; set ready flag high
	mov r0, r16							; move contents of r16 back into r0

;	Disable counter 1 iterrupt:
	in r16, TIMSK						; load Timer/Counter1 Interrupt Mask Register
	andi r16, $fb						; and imediate 0xfb (disable TOIE1)
	out TIMSK, r16						; write back TIMSK
	reti

READ:
;	Mask input bit:
	andi r18, $04						; remove all bits except data in

;	Check bit count:
	mov r16, r0							; load r0 into r16
	andi r16, $f0						; remove lower 4 bits
	cpi r16, $00						; check if this is the first read
	breq FIRST_READ

;	Sample input:
	lsl r18								; shift bit to left (3)
	lsl r18								; shift bit to left (4)
	lsl r18								; shift bit to left (5)
	lsl r18								; shift bit to left (6)
	lsl r18								; shift bit to left (7)
	lsr r1								; make place for new data in r1
	or r1, r18							; place data from r18 into r1

;	Check if last read:
	cpi r16, $80						; check if this was the last read
	breq LAST_READ

INCR_BITCNT:
	ldi r17, $10						; load 1 for addition to bit count
	add r0, r17							; increment bit count
	reti

FIRST_READ:
;	Check if input is still zero:
	cpi r18, $00						; check if input is zero
	breq INCR_BITCNT
;	Invalid start bit:

;	Disable counter 1 interrupt:
	in r16, TIMSK						; load Timer/Counter1 Interrupt Mask Register
	andi r16, $fb						; or imediate 0x04 (disable TOIE1)
	out TIMSK, r16						; write back TIMSK

;	enable INT0:
	in r16, GIMSK						; load GIMSK
	ori r16, $40						; enable INT0
	out GIMSK, r16						; write back GIMSK
	reti

LAST_READ:

	reti

;	Timerzero overwlof ISR:
TIM0_OVF_ISR:
;	EEPROM ready:
EE_RDY_ISR:
;	Analog comparator:
ANA_COMP_ISR:
;	ADC:
ADC_ISR:
;	Counter 1 equal to B:
TIM1_COMPB_ISR:
;	Counter 0 equal to A:
TIM0_COMPA_ISR:
;	Counter 0 equal to B:
TIM0_COMPB_ISR:
;	Watchdog timer:
WDT_ISR:
;	Serial interface start:
USI_START_ISR:
;	Serial interface overflow:
USI_OVF_ISR:
	reti