#pragma noiv               // Do not generate interrupt vectors

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

BYTE xdata Digit[] = {0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82,
		0xf8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86,
		0x8e};

// Dummy-Read these values to turn LED's on and off
//xdata volatile const BYTE D2ON	_at_ 0x8800;
//xdata volatile const BYTE D2OFF	_at_ 0x8000;
//xdata volatile const BYTE D3ON	_at_ 0x9800;
//xdata volatile const BYTE D3OFF	_at_ 0x9000;
//xdata volatile const BYTE D4ON	_at_ 0xA800;
//xdata volatile const BYTE D4OFF	_at_ 0xA000;
//xdata volatile const BYTE D5ON	_at_ 0xB800;
//xdata volatile const BYTE D5OFF	_at_ 0xB000;

BYTE    Configuration;      	// Current configuration
BYTE    AlternateSetting = 0;   // Alternate settings

//-----------------------------------------------------------------
// Task Dispatcher hooks
//   The following hooks are called by the task dispatcher.
//-----------------------------------------------------------------

WORD mycount = 0;
WORD blinktime = 0;
BYTE inblink = 0x00;
BYTE outblink = 0x00;
WORD blinkmask = 0;		// HS/FS blink rate

BYTE refresh = 0;

void TD_Init(void)             	// Called once at startup
{
	BYTE dum;
	
	// turn off the 4 LED's
	dum = D2OFF;
	dum = D3OFF;
	dum = D4OFF;
	dum = D5OFF;

   	// set the CPU clock to 48MHz
	//CPUCS = ((CPUCS & ~bmCLKSPD) | bmCLKSPD1); 
	// 48 MHz //comented 'cos are configured by Serial_Init
	FX2LPSerial_Init();
	FX2LPSerial_XmitString("Serial Port Initialized");
	FX2LPSerial_XmitChar('\n');
	FX2LPSerial_XmitChar('\n');
	
	// set the slave FIFO interface to 48MHz
   		//set s-fifo to internal clk, no_output,
		//no_inverted clk, no_async, no_gstate, 
		//slavefifo(11) = 0xC3
	IFCONFIG = 0xcb;//para hacerlo async.
			//Error de diseno.
			//Corregir en VHDL previamente

	SYNCDELAY;
	REVCTL = 0x00; /*Chip Revision Control Register: poniendo
			esto en 0x01 me deja manipular los
			paquetes, pero debo mover paquete por
			paquete a cada buffer... 
			no logro tomar ningun tipo de flag y mucho
			menos pude mover el buffer a la memoria fifo

			Por otro lado, poniendo el bit 0x02 logro
			desactivar el auto-armado de los endopints
			y puedo cambiar de modo autoout a manualout
			sin necesidad de perder datos.*/
	SYNCDELAY;

	//Pin Flags Configuration
	PINFLAGSAB = 0xBC;	// FLAGA <- EP2 Full Flag
				// FLAGD <- EP2 Empty Flag
	SYNCDELAY;
	PINFLAGSCD = 0x8F;	// FLAGC <- EP8 Full Flag
				// FLAGB <- EP8 Empty Flag

	EP1OUTCFG = 0xA0;
	SYNCDELAY;
	EP1INCFG = 0xA0;
	SYNCDELAY;
	EP4CFG &= 0x7F;
	SYNCDELAY;
	EP6CFG &= 0x7F;
	SYNCDELAY;
	EP8CFG = 0xA0;	//EP8: DIR=OUT, TYPE=BULK, SIZE=512, BUF=2x
	SYNCDELAY;
	EP2CFG = 0xD2;	//EP2: DIR=IN, TYPE=ISOC, SIZE=1024, BUF=3x 
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
	EP8FIFOCFG = 0x11;
	SYNCDELAY;
	EP2FIFOCFG = 0x0D;
	SYNCDELAY;

	// We want to get SOF interrupts
	USBIE |= bmSOF;
	EIEX4 = 1;
	INTSETUP |= (INT4IN | bmAV4EN);
	EXIF &= ~0x40;
	EP8FIFOIE = 0x03;

	FX2LPSerial_XmitString("Bridge Configured\n");
}

void TD_Poll(void)     // Called repeatedly while the device is idle
{
	BYTE dum;
		
	if(EP8FIFOFLGS & bmBIT1)//ep8 fifo empty
	{
		dum = D4ON;
	}
	else
	{
		dum = D4OFF;
	}

	if(EP8FIFOFLGS & bmBIT0)//ep8 fifo full//
	//(EP2468STAT & bmBIT6)//ep8 empty
	{
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

}




BOOL TD_Suspend(void)	//Called before the device goes into
			//suspend mode
{
   return(TRUE);
}

BOOL TD_Resume(void)	// Called after the device resumes
{
   return(TRUE);
}

//------------------------------------------------------------------
// Device Request hooks
//   The following hooks are called by the end point 0 device
//   request parser.
//------------------------------------------------------------------

BOOL DR_GetDescriptor(void)
{
	FX2LPSerial_XmitString("Getting Descriptor: ");
	return(TRUE);
}

BOOL DR_SetConfiguration(void)	//Called when a Set Configuration
				//command is received
{
	FX2LPSerial_XmitString("Setting Config\n\n");
	Configuration = SETUPDAT[2];
	return(TRUE);		// Handled by user code
}

BOOL DR_GetConfiguration(void)	//Called when a Get Configuration
				//command is received
{
	FX2LPSerial_XmitString("Getting Config\n\n");
	EP0BUF[0] = Configuration;
	EP0BCH = 0;
	EP0BCL = 1;
	return(TRUE);		// Handled by user code
}

BOOL DR_SetInterface(void)	//Called when a Set Interface
				//command is received
{
	FX2LPSerial_XmitString("Setting Interface\n\n");

	AlternateSetting = SETUPDAT[2];
  	return(TRUE);		// Handled by user code
}

BOOL DR_GetInterface(void)	//Called when a Set Interface
				//command is received
{
	FX2LPSerial_XmitString("Getting Interface\n\n");
	EP0BUF[0] = AlternateSetting;
	EP0BCH = 0;
	EP0BCL = 1;
	return(TRUE);		// Handled by user code
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

//------------------------------------------------------------------
// USB Interrupt Handlers
//   The following functions are called by the USB interrupt jump
//   table.
//------------------------------------------------------------------

// Setup Data Available Interrupt Handler
void ISR_Sudav(void) interrupt 0
{

	FX2LPSerial_XmitString("SUDAv ISR\n");
	GotSUD = TRUE;		// Set flag
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSUDAV;	// Clear SUDAV IRQ
}

// Setup Token Interrupt Handler
void ISR_Sutok(void) interrupt 0
{
	FX2LPSerial_XmitString("SUTok ISR\n");
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSUTOK;	// Clear SUTOK IRQ
}

void ISR_Sof(void) interrupt 0
{
	BYTE dum;
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSOF;		// Clear SOF IRQ
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

	// Whenever we get a USB Reset, we should revert to
	// full speed mode
	FX2LPSerial_XmitString("URst ISR\n");
	pConfigDscr = pFullSpeedConfigDscr;
	((CONFIGDSCR xdata *)pConfigDscr)->type = CONFIG_DSCR;
	pOtherConfigDscr = pHighSpeedConfigDscr;
	((CONFIGDSCR xdata*)pOtherConfigDscr)->type = 
						OTHERSPEED_DSCR;
   
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmURES;	// Clear URES IRQ
	dum = D2OFF;		// Turn off high-speed LED
	blinkmask = 0x0400;	// 2 sec period for FS
}

void ISR_Susp(void) interrupt 0
{
	Sleep = TRUE;
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSUSP;
}

void ISR_Highspeed(void) interrupt 0
{
	blinkmask = 0x1000;	// 1 sec period for HS
	if (EZUSB_HIGHSPEED())
	{
		pConfigDscr = pHighSpeedConfigDscr;
		((CONFIGDSCR xdata *) pConfigDscr)->type =
						CONFIG_DSCR;
		pOtherConfigDscr = pFullSpeedConfigDscr;
		((CONFIGDSCR xdata *) pOtherConfigDscr)->type =
						OTHERSPEED_DSCR;
	}
	else
	{
	pConfigDscr = pFullSpeedConfigDscr;
	pOtherConfigDscr = pHighSpeedConfigDscr;
	}

	EZUSB_IRQ_CLEAR();
	USBIRQ = bmHSGRANT;
}
void ISR_Ep8eflag(void) interrupt 0
{
	EXIF &= ~bmBIT6;
	EP8FIFOIRQ = 0x02;
	FX2LPSerial_XmitHex2(EP8BCH);
	FX2LPSerial_XmitHex2(EP8BCL);
	FX2LPSerial_XmitString("\nEP8: Estoy vacio\n");


}
void ISR_Ep8fflag(void) interrupt 0
{
	EXIF &= ~0x40;
	EP8FIFOIRQ = 0x01;
	FX2LPSerial_XmitString("EP8: Estoy lleno\n");
}

