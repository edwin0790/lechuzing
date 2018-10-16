.module timer_jmp


.globl _timer0_isr
.globl _main

.area RESET(CODE,ABS)
.org 0x0000
	ljmp _main

.area TIMER0_INTERRUPT(CODE,ABS)
.org 0x000B
	ljmp	_timer0_isr
