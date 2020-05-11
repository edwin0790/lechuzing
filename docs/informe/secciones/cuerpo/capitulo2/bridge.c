#pragma noiv               // No generar vectores de interrupción
#include "fx2.h"
#include "fx2regs.h"
#include "syncdly.h"            // SYNCDELAY macro
#include "FX2LPSerial.h"
#include "leds.h"

extern BOOL   GotSUD;         // Received setup data flag
extern BOOL   Sleep;
extern BOOL   Rwuen;
extern BOOL   Selfpwr;

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

void TD_Init(void)             // Called once at startup
{
	BYTE dum;
	// apagar los 4 LED's. Realimentación para el desarrollo
	dum = D2OFF;
	dum = D3OFF;
	dum = D4OFF;
	dum = D5OFF;

   	// Colocara la velociad de reloj en 48MHz
	//CPUCS = ((CPUCS & ~bmCLKSPD) | bmCLKSPD1); // 48 MHz //Se comenta ya que se inicia en la función procedente
	FX2LPSerial_Init();
	FX2LPSerial_XmitString("Serial Port Initialized");
	FX2LPSerial_XmitChar('\n');
	FX2LPSerial_XmitChar('\n');
	
	// configurar la fifo
   	// 48MHz, reloj interno, no_salida, no_reloj invertido, no_asincr, no_gstate, fifo esclava(11) = 0xC3
	// 0xCB //igual arriba pero si asincr. ERROR DE DISEÑO
	IFCONFIG = 0xCB;
	SYNCDELAY; //PINFLAGSAB está en la tabla de sincronización

	//Pin Flags Configuration
	PINFLAGSAB = 0xBC;	// FLAGA <- EP2 Full Flag
				// FLAGD <- EP2 Empty Flag
	SYNCDELAY;
	PINFLAGSCD = 0x8F;	// FLAGC <- EP8 Full Flag
				// FLAGB <- EP8 Empty Flag

	// Configurar exxtremos
	EP1OUTCFG = 0xA0;
	SYNCDELAY;
	EP1INCFG = 0xA0;
	SYNCDELAY;
	EP4CFG &= 0x7F;
	SYNCDELAY;
	EP6CFG &= 0x7F;
	SYNCDELAY;
	EP8CFG = 0xA0;	//EP8 is DIR=OUT, TYPE=BULK, SIZE=512, BUF=2x
	SYNCDELAY;
	EP2CFG = 0xD2;	// EP2 is DIR=IN, TYPE=ISOC, SIZE=512, BUF=2x EP2CFG@e612 --> size = 512, buf = 2x
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
	EP8FIFOCFG = 0x11;// & ~bmAUTOOUT; //at the end, auto mode is setted off
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

void TD_Poll(void)             // Called repeatedly while the device is idle  
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
	FX2LPSerial_XmitHex2(EP8BCH);
	FX2LPSerial_XmitHex2(EP8BCL);
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
