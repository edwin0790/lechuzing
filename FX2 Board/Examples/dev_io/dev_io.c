//-----------------------------------------------------------------------------
//   File:      devio.c
//   Contents:  main module of a simple non-renumerating firmware example
//
// The purpose of this software is to demonstrate how
// to use the buttons and LED on the EZ-USB developer's
// kit.
//
// The device I/O example program uses the LED on the Development board
// to display a running application program on the EZ-USB chip.
// The buttons on the development board may be pressed to count up (F3),
// count down (F2), and reset the seven segment LED to "0" (F1) or "F" (F4).
// The code is written in C and uses several EZ-USB library functions.
// It does not use the FrameWorks.
//
// $Archive: /USB/Examples/FX2LP/dev_io/dev_io.c $
// $Date: 3/23/05 2:57p $
// $Revision: 3 $
//
//
//-----------------------------------------------------------------------------
// Copyright 2003, Cypress Semiconductor Corporation
//-----------------------------------------------------------------------------

#include "fx2.h"
#include "fx2regs.h"
#include "fx2sdly.h"

#define D2_MASK 0x01
#define D3_MASK 0x02
#define D4_MASK 0x04
#define D5_MASK 0x08

#define PF_IDLE			0
#define PF_GETKEYS		1

#define KEY_WAKEUP		0
#define KEY_F1			1
#define KEY_F2			2
#define KEY_F3			3

#define BTN_ADDR		0x20
#define LED_ADDR		0x21

BYTE __xdata Digit[] = { 0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e };

volatile BOOL ledflag;
volatile BYTE counter;

__xdata volatile __at (0x8800) volatile BYTE D2ON;
__xdata volatile __at (0x8000) volatile BYTE D2OFF;
__xdata volatile __at (0x9800) volatile BYTE D3ON;
__xdata volatile __at (0x9000) volatile BYTE D3OFF;
__xdata volatile __at (0xA800) volatile BYTE D4ON;
__xdata volatile __at (0xA000) volatile BYTE D4OFF;
__xdata volatile __at (0xB800) volatile BYTE D5ON;
__xdata volatile __at (0xB000) volatile BYTE D5OFF;

void main()
{

	BYTE	num = 0;
	BYTE __xdata	buttons;
	BYTE	kstates = 0xff;
	BYTE	kdeltas;
	BYTE	key;
	BYTE	display = FALSE;
	BYTE	dum;

	counter = 0x10;
	ledflag = FALSE;

	TMOD = 0x01;
	TH0 = 0x86;
	TL0 = 0xA0;
	ET0 = 1;
//	EA = 1;

	EZUSB_InitI2C();			// Initialize EZ-USB I2C controller
	TR0 = 1;


	while(TRUE)
	{

		EZUSB_ReadI2C(BTN_ADDR,0x01,&buttons);	// Read button states
		dum =  D4OFF;

		kdeltas = kstates ^ buttons;
		kstates = buttons;
		key = 0;


				while(kdeltas)
		{
			if(kdeltas & 0x01)
			{
				if(!((kstates >> key) & 0x01))
					switch(key)
					{
						case KEY_F1:
							if(--num > 0x0f)
								num = 0x0f;
							break;
						case KEY_F2:
							if(++num > 0x0f)
								num = 0;
							break;
						case KEY_WAKEUP:
							num = 0;
							break;
						case KEY_F3:
							num = 0x0f;
							break;
					}
				display = TRUE;
				dum = D3OFF;
			}
			kdeltas = kdeltas >> 1;
			++key;
		}
		if(display)
		{
			dum = D3ON;
			EZUSB_WriteI2C(LED_ADDR, 0x01, &(Digit[num]));
			EZUSB_WaitForEEPROMWrite(LED_ADDR);
			display = FALSE;
		}
	}
}

void timer0_isr() __interrupt TMR0_VECT
{
	BYTE dum;
//	if (!counter)
//	{
		if(ledflag)
			dum = D2ON;
		else
			dum = D2OFF;
		ledflag = !ledflag;
		counter = 0x0a;
//	}
//	counter--;
	TH0 = 0x86;
	TL0 = 0xA0;
}
