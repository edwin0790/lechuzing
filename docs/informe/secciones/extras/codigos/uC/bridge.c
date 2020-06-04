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

BYTE    Configuration;      // Current configuration
BYTE    AlternateSetting = 0;   // Alternate settings

//-----------------------------------------------------------------------------
// Task Dispatcher hooks
//   The following hooks are called by the task dispatcher.
//-----------------------------------------------------------------------------

WORD blinktime = 0;
BYTE inblink = 0x00;
BYTE outblink = 0x00;
WORD blinkmask = 0;			// HS/FS blink rate

void TD_Init(void)             // Called once at startup
{
	BYTE aux;
//	WORD i;
	
	// apago los 4 LED's
	aux = D2OFF;
	aux = D3OFF;
	aux = D4OFF;
	aux = D5OFF;

   	// Serial_Init configura el reloj
	FX2LPSerial_Init();
	FX2LPSerial_XmitString("Serial Port Initialized");
	FX2LPSerial_XmitChar('\n');
	FX2LPSerial_XmitChar('\n');
	
	// Configuración de la interfaz FIFO a 48MHz
   		//fifo con reloj interno, no salida de reloj, 
		//reloj no invertido, asíncrono, fifoesclava(11)
	IFCONFIG = 0xcb;

	SYNCDELAY;

	//Configuraciones de los Flags en los puertos
	PINFLAGSAB = 0xBC;  // FLAGA <- EP2 Full Flag
						// FLAGD <- EP2 Empty Flag
	SYNCDELAY;
	PINFLAGSCD = 0x8F;	// FLAGC <- EP8 Full Flag
						// FLAGB <- EP8 Empty Flag

    // Configuración de los extremos
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
	EP2CFG = 0xD2;  // EP2 is DIR=IN, TYPE=ISOC, SIZE=512, BUF=2x
	SYNCDELAY;

	// resetear la memoria para asegurarse de que está vacía
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

	//Establecer modo automático. Se establece con el flanco ascendente
	EP8FIFOCFG = 0x11;
	SYNCDELAY;
	EP2FIFOCFG = 0x0D;
	SYNCDELAY;

	// Se habilitan las interrupciones de para recibir paquetes SOF
	USBIE |= bmSOF;

	FX2LPSerial_XmitString("Interfaz Configurada\n");
}

void TD_Poll(void)	// Llamada por el lazo principal de forma repetida  
{
	BYTE aux;
	
		if(EP8FIFOFLGS & bmBIT1)//ep8 fifo vacia
		{
			aux = D4ON;
		}
		else
		{
			aux = D4OFF;
		}

		if(EP8FIFOFLGS & bmBIT0)//ep8 fifo llena
		{
			aux = D3ON;
		}
		else
		{
			aux = D3OFF;
		}

		if(EP2FIFOFLGS & bmBIT1)//ep2 fifo vacia
		{
			aux = D2ON;
		}
		else
		{
			aux = D2OFF;
		}
}




BOOL TD_Suspend(void)	// Called before the device goes into suspend mode
{
   return(TRUE);
}

BOOL TD_Resume(void)	// Called after the device resumes
{
   return(TRUE);
}

BOOL DR_GetDescriptor(void)
{
	FX2LPSerial_XmitString("Getting Descriptor: ");
	return(TRUE);
}

BOOL DR_SetConfiguration(void)	// Called when a Set Configuration 
								// command is received
{
	FX2LPSerial_XmitString("Setting Config\n\n");
	Configuration = SETUPDAT[2];
	return(TRUE);	// Handled by user code
}

BOOL DR_GetConfiguration(void)	// Called when a Get Configuration 
								//	command is received
{
	FX2LPSerial_XmitString("Getting Config\n\n");
	EP0BUF[0] = Configuration;
	EP0BCH = 0;
	EP0BCL = 1;
	return(TRUE);            // Handled by user code
}

BOOL DR_SetInterface(void)	// Called when a Set Interface 
							//command is received
{
	FX2LPSerial_XmitString("Setting Interface\n\n");

	AlternateSetting = SETUPDAT[2];
  return(TRUE);            // Handled by user code
}

BOOL DR_GetInterface(void)	// Called when a Set Interface 
							// command is received
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
	BYTE aux;
	EZUSB_IRQ_CLEAR();
	USBIRQ = bmSOF;            // Clear SOF IRQ
	blinktime++;
	if(blinktime&blinkmask)
		aux=D5OFF;	// ~1/sec blinking LED
	else					
		aux=D5ON;

	if(--inblink == 0)
		aux = D4OFF;
	if(--outblink == 0)
		aux = D3OFF;
}

void ISR_Ures(void) interrupt 0
{
	BYTE aux;

	// Whenever we get a USB Reset, we should revert to full speed mode
	FX2LPSerial_XmitString("URst ISR\n");
	pConfigDscr = pFullSpeedConfigDscr;
	((CONFIGDSCR xdata *) pConfigDscr)->type = CONFIG_DSCR;
	pOtherConfigDscr = pHighSpeedConfigDscr;
	((CONFIGDSCR xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;
   
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmURES;         // Clear URES IRQ
   aux = D2ON;				// Turn off high-speed LED
   blinkmask = 0x0400;		// 2 sec period for FS
}

void ISR_Susp(void) interrupt 0
{
   Sleep = TRUE;
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmSUSP;
}

void ISR_Highspeed(void) interrupt 0
{
   blinkmask = 0x1000;		// 1 sec period for HS
   if (EZUSB_HIGHSPEED())
   {
      pConfigDscr = pHighSpeedConfigDscr;
      ((CONFIGDSCR xdata *) pConfigDscr)->type = CONFIG_DSCR;
      pOtherConfigDscr = pFullSpeedConfigDscr;
      ((CONFIGDSCR xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;

      // This register sets the number of Isoc packets to send per
      // uFrame.  This register is only valid in high speed.
      EP2ISOINPKTS = 0x81;//0x83;	// 3 packets per microframe, AADJ=1
			SYNCDELAY;
   }
   else
   {
      pConfigDscr = pFullSpeedConfigDscr;
      pOtherConfigDscr = pHighSpeedConfigDscr;
   }

   EZUSB_IRQ_CLEAR();
   USBIRQ = bmHSGRANT;
}
// Interrupciones no utilizadas fueron borradas
// Para mayor detalle de las interrupciones 
// vectorizadas disponibles, consultar la
// documentacion de Cypress Semiconductor