.module i2c_jmp


.globl _i2c_isr

.area I2C_INTERRUPT(CODE,ABS)
.org 0x004B
	ljmp	_i2c_isr
