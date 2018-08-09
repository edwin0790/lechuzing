#pragma noiv               // Do not generate interrupt vectors
//-----------------------------------------------------------------------------
//   File:      CYStream.c
//   Contents:   USB Bulk and Isoc streaming example code.
//
// Copyright (c) 2011, Cypress Semiconductor Corporation All rights reserved
//
// This software is owned by Cypress Semiconductor Corporation
// (Cypress) and is protected by United States copyright laws and
// international treaty provisions.  Therefore, unless otherwise specified in a
// separate license agreement, you must treat this
// software like any other copyrighted material.  Reproduction, modification, translation,
// compilation, or representation of this software in any other form
// (e.g., paper, magnetic, optical, silicon, etc.) is prohibited
// without the express written permission of Cypress.
//
// Disclaimer: Cypress makes no warranty of any kind, express or implied, with
// regard to this material, including, but not limited to, the implied warranties
// of merchantability and fitness for a particular purpose. Cypress reserves the
// right to make changes without further notice to the materials described
// herein. Cypress does not assume any liability arising out of the application
// or use of any product or circuit described herein. Cypress? products described
// herein are not authorized for use as components in life-support devices.
//
// This software is protected by and subject to worldwide patent
// coverage, including U.S. and foreign patents. Use may be limited by
// and subject to the Cypress Software License Agreement.
//
//-----------------------------------------------------------------------------
#include "fx2.h"
#include "fx2regs.h"
#include "syncdly.h"            // SYNCDELAY macro
#include "FX2LPSerial.h"

#include "leds.h"

extern BOOL   GotSUD;         // Received setup data flag
extern BOOL   Sleep;
extern BOOL   Rwuen;
extern BOOL   Selfpwr;

#define BTN_ADDR		0x20
#define LED_ADDR		0x21

BYTE xdata Digit[] = { 0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e };

// Dummy-Read these values to turn LED's on and off
//xdata volatile const BYTE D2ON		_at_ 0x8800;
//xdata volatile const BYTE D2OFF	_at_ 0x8000;
//xdata volatile const BYTE D3ON		_at_ 0x9800;
//xdata volatile const BYTE D3OFF	_at_ 0x9000;
//xdata volatile const BYTE D4ON		_at_ 0xA800;
//xdata volatile const BYTE D4OFF	_at_ 0xA000;
//xdata volatile const BYTE D5ON		_at_ 0xB800;
//xdata volatile const BYTE D5OFF	_at_ 0xB000;

BYTE    Configuration;      // Current configuration
BYTE    AlternateSetting = 0;   // Alternate settings

//-----------------------------------------------------------------------------
// Task Dispatcher hooks
//   The following hooks are called by the task dispatcher.
//-----------------------------------------------------------------------------

WORD mycount = 0;
WORD blinktime = 0;
BYTE inblink = 0x00;
BYTE outblink = 0x00;
WORD blinkmask = 0;			// HS/FS blink rate

BYTE refresh = 0;

void TD_Init(void)             // Called once at startup
{
	BYTE dum;
//	WORD i;
	
	// turn off the 4 LED's
	dum = D2OFF;
	dum = D3OFF;
	dum = D4OFF;
	dum = D5OFF;

   	// set the CPU clock to 48MHz
	//CPUCS = ((CPUCS & ~bmCLKSPD) | bmCLKSPD1); // 48 MHz //comented 'cos are configured by Serial_Init
	FX2LPSerial_Init();
	FX2LPSerial_XmitString("Serial Port Initialized");
	FX2LPSerial_XmitChar('\n');
	FX2LPSerial_XmitChar('\n');
	
	// set the slave FIFO interface to 48MHz <-de nuevo 48... ahora  a 30MHz
   		//set s-fifo to internal clk, no_output, no_inverted clk, no_async, no_gstate, slavefifo(11) = 0xC3
	IFCONFIG = 0xcb;// & ~bm3048MHZ;/*/0xCB; *///para hacerlo async. Error de diseño. Corregir en VHDL previamente

	SYNCDELAY; // IFCONFIG@ef01.... REVCTL writing needs SYNCDELAY

	REVCTL = 0x03; /*Chip Revision Control Register: poniendo esto en 0x01 me deja manipular los paquetes, pero debo mover paquete por paquete a 
										cada buffer... no logro tomar ningún tipo de flag y mucho menos pude mover el buffer a la memoria fifo
										Por otro lado, poniendo el bit 0x02 logro desactivar el auto-armado de los endopints y puedo cambiar de modo autoout a manualout
										sin necesidad de perder datos.
										En mi caso puntual, no quiero modificar los paquetes que recibo ni voy a cambiar de modo automático o manual.
										Se pueden guardar la recomendación fuerte de activar ambos bits (Cypress higly recommends to set both bits).*/

//	PORTACFG = 0x80;
	SYNCDELAY; //PORTACFG@e670


	//Pin Flags Configuration
	PINFLAGSAB = 0xBC;  // FLAGA <- EP2 Full Flag
						// FLAGD <- EP2 Empty Flag
	SYNCDELAY;
	PINFLAGSCD = 0x8F;	// FLAGC <- EP8 Full Flag
						// FLAGB <- EP8 Empty Flag

    // Default interface uses endpoint 2, zero the valid bit on all others
    // Just using endpoint 2, zero the valid bit on all others
	EP1OUTCFG = 0xA0;
	SYNCDELAY;
	EP1INCFG = 0xA0;
	SYNCDELAY;
	EP4CFG &= 0x7F;
	SYNCDELAY;
	EP6CFG &= 0x7F;
	SYNCDELAY;
	EP8CFG = 0xA0; //EP8 is DIR=OUT, TYPE=BULK, SIZE=512, BUF=2x
	SYNCDELAY;
	EP2CFG = 0xDB;  // EP2 is DIR=IN, TYPE=ISOC, SIZE=1024, BUF=3x EP2CFG@e612
	SYNCDELAY;

	FIFORESET = 0x80;
	SYNCDELAY;
	FIFORESET = 0x02;
	SYNCDELAY;
	FIFORESET = 0x04;
	SYNCDELAY;
	FIFORESET = 0x06;
	SYNCDELAY;
	FIFORESET = 0x08;
	SYNCDELAY;
	FIFORESET = 0x00;
	SYNCDELAY;

	EP8FIFOCFG = 0x00;
	SYNCDELAY;
	EP2FIFOCFG = 0x00;
	SYNCDELAY;

	//setting on auto mode. rising edge is necessary
	EP8FIFOCFG = 0x01 & ~bmAUTOOUT; //at the end, auto mode is setted off
	SYNCDELAY;
	EP2FIFOCFG = 0x05;
	SYNCDELAY;


	//being sure that auto mode is off;

	EP2BCH = 0x00;
	SYNCDELAY;
	EP2BCH = 0x00;
	SYNCDELAY;
	EP2BCH = 0x00;
	SYNCDELAY;
	EP2BCL = 0xff;
	SYNCDELAY;
	EP2BCL = 0xff;
	SYNCDELAY;
	EP2BCL = 0xff;
	SYNCDELAY;


	// We want to get SOF interrupts
	USBIE |= bmSOF;
	EIEX4 = 1;
	INTSETUP |= (INT4IN | bmAV4EN);
	EXIF &= ~0x40;
	EP8FIFOIE = 0x03;
	EP2FIFOIE = 0x01;

	FX2LPSerial_XmitString("Bridge Configured\n");
}

void TD_Poll(void)             // Called repeatedly while the device is idle  
{
	BYTE dum;
	
	//debug3
//	WORD viejos, nuevos;
//	
//	nuevos = (EP8BCH << 8) | EP8BCL;
//	if(nuevos != viejos)
//	{
//		viejos = nuevos;
//		FX2LPSerial_XmitHex4(nuevos);
//		FX2LPSerial_XmitChar(' ');
//		FX2LPSerial_XmitHex2(EP8FIFOBCH);
//		FX2LPSerial_XmitHex2(EP8FIFOBCL);

//		FX2LPSerial_XmitChar('\n');
//	}
	//debug3
	if((EP2468STAT & bmEP8FULL))
//	if(!mycount)
	{
		OUTPKTEND = 0x08;
	}
	else
		OUTPKTEND = 0x00;
	
	if((EP24FIFOFLGS & bmBIT0))
	{
		INPKTEND = 0x02;
	}
	else
	{
		INPKTEND = 0x00;
	}
		//debug2
//		FX2LPSerial_XmitString("INTERRUPT: ");
//		FX2LPSerial_XmitHex1(EP8FIFOIRQ);
//		FX2LPSerial_XmitString(" INT4IVEC: ");
//		FX2LPSerial_XmitHex2(INT4IVEC);
//		FX2LPSerial_XmitChar('\n');
		//debug2
		//debug1
//		FX2LPSerial_XmitString("Buffer:\n");
//		for(i = 0; i < 512; i++)
//		{
//			FX2LPSerial_XmitHex2(EP8FIFOBUF[i]);
//			FX2LPSerial_XmitString("  ");
//		}
//		FX2LPSerial_XmitString("\n-----------------\n\n");
		//debug1
	
//	mycount++;
	
		if(EP8FIFOFLGS & bmBIT1)//ep8 fifo empty
		{
			dum = D4ON;
		}
		else
		{
			dum = D4OFF;
		}

		//if(EXIF & bmBIT6)// for debug. InT4 flag
		if(EP8FIFOFLGS & bmBIT0)//ep8 fifo full//(EP2468STAT & bmBIT6)//ep8 empty
		{
			//FX2LPSerial_XmitString("Estoy Aqui y sigo aqui\n\n");
			dum = D3ON;
		}
		else
		{
			dum = D3OFF;
		}

		if(EP2FIFOFLGS & bmBIT1)//ep2 fifo empty
		{
			dum = D2ON;
		}
		else
		{
			dum = D2OFF;
		}

//	EZUSB_WriteI2C(LED_ADDR, 0x01, &(Digit[EP8BCL]));
//	EZUSB_WaitForEEPROMWrite(LED_ADDR);

}




BOOL TD_Suspend(void)          // Called before the device goes into suspend mode
{
   return(TRUE);
}

BOOL TD_Resume(void)          // Called after the device resumes
{
   return(TRUE);
}

//-----------------------------------------------------------------------------
// Device Request hooks
//   The following hooks are called by the end point 0 device request parser.
//-----------------------------------------------------------------------------

BOOL DR_GetDescriptor(void)
{
	FX2LPSerial_XmitString("Getting Descriptor: ");
	return(TRUE);
}

BOOL DR_SetConfiguration(void)   // Called when a Set Configuration command is received
{
	FX2LPSerial_XmitString("Setting Config\n\n");
	Configuration = SETUPDAT[2];
	return(TRUE);            // Handled by user code
}

BOOL DR_GetConfiguration(void)   // Called when a Get Configuration command is received
{
	FX2LPSerial_XmitString("Getting Config\n\n");
	EP0BUF[0] = Configuration;
	EP0BCH = 0;
	EP0BCL = 1;
	return(TRUE);            // Handled by user code
}

BOOL DR_SetInterface(void)       // Called when a Set Interface command is received
{
	FX2LPSerial_XmitString("Setting Interface\n\n");

	AlternateSetting = SETUPDAT[2];
  return(TRUE);            // Handled by user code
}

BOOL DR_GetInterface(void)       // Called when a Set Interface command is received
{
	FX2LPSerial_XmitString("Getting Interface\n\n");
   EP0BUF[0] = AlternateSetting;
   EP0BCH = 0;
   EP0BCL = 1;
   return(TRUE);            // Handled by user code
}

BOOL DR_GetStatus(void)
{
	FX2LPSerial_XmitString("Getting Status\n\n");
	return(TRUE);
}

BOOL DR_ClearFeature(void)
{
	FX2LPSerial_XmitString("Cleraing Features\n\n");
	return(TRUE);
}

BOOL DR_SetFeature(void)
{
	FX2LPSerial_XmitString("Setting Features\n\n");
	return(TRUE);
}

BOOL DR_VendorCmnd(void)
{
   return(TRUE);
}

//-----------------------------------------------------------------------------
// USB Interrupt Handlers
//   The following functions are called by the USB interrupt jump table.
//-----------------------------------------------------------------------------

// Setup Data Available Interrupt Handler
void ISR_Sudav(void) interrupt 0
{

	FX2LPSerial_XmitString("SUDAv ISR\n");
	GotSUD = TRUE;            // Set flag
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSUDAV;         // Clear SUDAV IRQ
}

// Setup Token Interrupt Handler
void ISR_Sutok(void) interrupt 0
{
	FX2LPSerial_XmitString("SUTok ISR\n");
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSUTOK;         // Clear SUTOK IRQ
}

void ISR_Sof(void) interrupt 0
{
	BYTE dum;
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSOF;            // Clear SOF IRQ
	blinktime++;
	if(blinktime&blinkmask)
		dum=D5OFF;	// ~1/sec blinking LED
	else					
		dum=D5ON;

	if(--inblink == 0)
		dum = D4OFF;
	if(--outblink == 0)
		dum = D3OFF;
}

void ISR_Ures(void) interrupt 0
{
	BYTE dum;

	// Whenever we get a USB Reset, we should revert to full speed mode
	FX2LPSerial_XmitString("URst ISR\n");
	pConfigDscr = pFullSpeedConfigDscr;
	((CONFIGDSCR xdata *) pConfigDscr)->type = CONFIG_DSCR;
	pOtherConfigDscr = pHighSpeedConfigDscr;
	((CONFIGDSCR xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;
   
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmURES;         // Clear URES IRQ
   dum = D2OFF;				// Turn off high-speed LED
   blinkmask = 0x0400;		// 2 sec period for FS
//	FX2LPSerial_XmitString("reset done\n");
}

void ISR_Susp(void) interrupt 0
{
   Sleep = TRUE;
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmSUSP;
}

void ISR_Highspeed(void) interrupt 0
{
//	FX2LPSerial_XmitString("Setting HighSpeed...\n\n");
   blinkmask = 0x1000;		// 1 sec period for HS
   if (EZUSB_HIGHSPEED())
   {
      pConfigDscr = pHighSpeedConfigDscr;
      ((CONFIGDSCR xdata *) pConfigDscr)->type = CONFIG_DSCR;
      pOtherConfigDscr = pFullSpeedConfigDscr;
      ((CONFIGDSCR xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;

      // This register sets the number of Isoc packets to send per
      // uFrame.  This register is only valid in high speed.
//      EP2ISOINPKTS = 0x83;	// 3 packets per microframe, AADJ=1
//			EA = 0;
//			SYNCDELAY;
//			EA = 1;
//	  dum = D2ON;		// Turn on high-speed LED
   }
   else
   {
      pConfigDscr = pFullSpeedConfigDscr;
      pOtherConfigDscr = pHighSpeedConfigDscr;
   }

   EZUSB_IRQ_CLEAR();
   USBIRQ = bmHSGRANT;
}
void ISR_Ep0ack(void) interrupt 0
{
}
void ISR_Stub(void) interrupt 0
{
}
void ISR_Ep0in(void) interrupt 0
{
}
void ISR_Ep0out(void) interrupt 0
{
}
void ISR_Ep1in(void) interrupt 0
{
}
void ISR_Ep1out(void) interrupt 0
{
}

// ISR_Ep2inout is called on every OUT packet receieved.
// We don't do anything with the data.  We just indicate we are done with the buffer.
void ISR_Ep2inout(void) interrupt 0
{
	FX2LPSerial_XmitString("EndPoint ISR");
    // Perform USB activity based upon the Alt. Interface selected
           // check EP8 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	if(!(EP2468STAT & bmEP2EMPTY))
	{
		EA = 0;
		EP2BCL = 0x80;          // re(arm) EP2OUT
		SYNCDELAY;
		EA = 1;
	}
}
void ISR_Ep4inout(void) interrupt 0
{
}
void ISR_Ep6inout(void) interrupt 0
{
}
void ISR_Ep8inout(void) interrupt 0
{
	FX2LPSerial_XmitString("EP8: Atendiendo ISR IN/OUT\n");
    // Perform USB activity based upon the Alt. Interface selected
           // check EP8 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
//	if(!(EP2468STAT & bmEP8EMPTY))
//	{
//		EP8BCL = 0x80;          // re(arm) EP2OUT
//		SYNCDELAY;

//		EP8FIFOBCL=0x80;
//		SYNCDELAY;
//	}
}
void ISR_Ibn(void) interrupt 0
{
}
void ISR_Ep0pingnak(void) interrupt 0
{
}
void ISR_Ep1pingnak(void) interrupt 0
{
}
void ISR_Ep2pingnak(void) interrupt 0
{
}
void ISR_Ep4pingnak(void) interrupt 0
{
}
void ISR_Ep6pingnak(void) interrupt 0
{
}
void ISR_Ep8pingnak(void) interrupt 0
{
}
void ISR_Errorlimit(void) interrupt 0
{
}
void ISR_Ep2piderror(void) interrupt 0
{
}
void ISR_Ep4piderror(void) interrupt 0
{
}
void ISR_Ep6piderror(void) interrupt 0
{
}
void ISR_Ep8piderror(void) interrupt 0
{
}
void ISR_Ep2pflag(void) interrupt 0
{
}
void ISR_Ep4pflag(void) interrupt 0
{
}
void ISR_Ep6pflag(void) interrupt 0
{
}
void ISR_Ep8pflag(void) interrupt 0
{
}
void ISR_Ep2eflag(void) interrupt 0
{
}
void ISR_Ep4eflag(void) interrupt 0
{
}
void ISR_Ep6eflag(void) interrupt 0
{
}
void ISR_Ep8eflag(void) interrupt 0
{
	EXIF &= ~bmBIT6;
	EP8FIFOIRQ = 0x02;
//	FX2LPSerial_XmitHex2(EP8BCH);
//	FX2LPSerial_XmitHex2(EP8BCL);
//	FX2LPSerial_XmitString("\n");
//	FX2LPSerial_XmitHex2(EP8FIFOBCH);
//	FX2LPSerial_XmitHex2(EP8FIFOBCL);
	FX2LPSerial_XmitString("\nEP8: Estoy vacío\n");


}
void ISR_Ep2fflag(void) interrupt 0
{
}
void ISR_Ep4fflag(void) interrupt 0
{
}
void ISR_Ep6fflag(void) interrupt 0
{
}
void ISR_Ep8fflag(void) interrupt 0
{
	EXIF &= ~0x40;
	EP8FIFOIRQ = 0x01;
	FX2LPSerial_XmitString("EP8: Estoy lleno\n");
}
void ISR_GpifComplete(void) interrupt 0
{
}
void ISR_GpifWaveform(void) interrupt 0
{
}