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
	
	// turn off the 4 LED's
	aux = D2OFF;
	aux = D3OFF;
	aux = D4OFF;
	aux = D5OFF;

   	// Serial_Init configura el reloj
	FX2LPSerial_Init();
	FX2LPSerial_XmitString("Puerto Serie iniciado");
	FX2LPSerial_XmitChar('\n');
	FX2LPSerial_XmitChar('\n');
	
	// Configuración de la interfaz FIFO a 48MHz
   		//fifo con reloj interno, no salida de reloj, 
		//reloj no invertido, asíncrono, fifoesclava(11)
	IFCONFIG = 0xcb;
	SYNCDELAY; //PORTACFG@e670

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

	\resetear la memoria para asegurarse de que está vacía
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