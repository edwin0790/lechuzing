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
// or use of any product or circuit described herein. Cypress� products described
// herein are not authorized for use as components in life-support devices.
//
// This software is protected by and subject to worldwide patent
// coverage, including U.S. and foreign patents. Use may be limited by
// and subject to the Cypress Software License Agreement.
//
//-----------------------------------------------------------------------------
#include "fx2.h"
#include "fx2regs.h"
#include "fx2sdly.h"            // SYNCDELAY macro

extern BOOL   GotSUD;         // Received setup data flag
extern BOOL   Sleep;
extern BOOL   Rwuen;
extern BOOL   Selfpwr;

#define LED_ADDR		0x21

enum {	// Alternate Serttings for HIGH speed operation
    Alt0_BulkIN = 0,
    Alt1_BulkOUT,
    Alt2_BulkINOUT,
    Alt3_IsocIN,
    Alt4_IsocOUT,
    Alt5_IsocIN,
    Alt6_IsocINOUT
};
enum {	// Alternate Settings for FULL speed operation
    Full_Alt0_BulkIN = 0,
    Full_Alt1_BulkOUT,
    Full_Alt2_IsocIN,
    Full_Alt3_IsocOUT
};

BYTE __xdata Digit[] = { 0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 0x80, 0x98, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e };

BYTE    Configuration;      // Current configuration
BYTE    AlternateSetting = Alt0_BulkIN;   // Alternate settings

// Dummy-Read these values to turn LED's on and off
__xdata volatile __at (0x8800) volatile BYTE D2ON;
__xdata volatile __at (0x8000) volatile BYTE D2OFF;
__xdata volatile __at (0x9800) volatile BYTE D3ON;
__xdata volatile __at (0x9000) volatile BYTE D3OFF;
__xdata volatile __at (0xA800) volatile BYTE D4ON;
__xdata volatile __at (0xA000) volatile BYTE D4OFF;
__xdata volatile __at (0xB800) volatile BYTE D5ON;
__xdata volatile __at (0xB000) volatile BYTE D5OFF;

//-----------------------------------------------------------------------------
// Task Dispatcher hooks
//   The following hooks are called by the task dispatcher.
//-----------------------------------------------------------------------------

WORD mycount;
WORD blinktime = 0;
BYTE inblink = 0x00;
BYTE outblink = 0x00;
WORD blinkmask = 0;			// HS/FS blink rate

void TD_Init(void)             // Called once at startup
{
   int j;
   BYTE dum;

   // set the CPU clock to 48MHz
   CPUCS = ((CPUCS & ~bmCLKSPD) | bmCLKSPD1) ;
   SYNCDELAY;

   // set the slave FIFO interface to 48MHz
   IFCONFIG |= 0x40;
   SYNCDELAY;

    // Default interface uses endpoint 2, zero the valid bit on all others
    // Just using endpoint 2, zero the valid bit on all others
    EP1OUTCFG = (EP1OUTCFG & 0x7F);
	SYNCDELAY;
	EP1INCFG = (EP1INCFG & 0x7F);
	SYNCDELAY;
	EP4CFG = (EP4CFG & 0x7F);
	SYNCDELAY;
	EP6CFG = (EP6CFG & 0x7F);
	SYNCDELAY;
	EP8CFG = (EP8CFG & 0x7F);
	SYNCDELAY;
    EP2CFG = 0xE0;  // EP2 is DIR=IN, TYPE=BULK, SIZE=512, BUF=4x

// turn off the 4 LED's
   	dum = D2OFF;
   	dum = D3OFF;
   	dum = D4OFF;
   	dum = D5OFF;

   // We want to get SOF interrupts
   USBIE |= bmSOF;
   
  // Prepare data
      for (j=0;j<512;j++)
      {
         EP2FIFOBUF[j] = (BYTE)j;
      }
      EP2BCH = 0x02;
      EP2BCL = 0x00;

    Rwuen = TRUE;                 // Enable remote-wakeup
}

void TD_Poll(void)             // Called repeatedly while the device is idle
{  
	BYTE dum;
	if( EZUSB_HIGHSPEED( ) )
	{ 
	    // Perform USB activity based upon the Alt. Interface selected 
	     switch (AlternateSetting)
	    {
	        case Alt0_BulkIN:
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	               dum = D4ON;
			       inblink = 0x10;					// keep IN LED lit for this many SOF's
					
	                EP2BCH = 0x02;
	                EP2BCL = 0x00;
	              
	            }
	        break;
	
	        case Alt2_BulkINOUT:
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	                dum = D4ON;
					inblink = 0x10;					// keep IN LED lit for this many SOF's
					
	                EP2BCH = 0x02;
	                EP2BCL = 0x00;
	
	            }
	
	            // check EP6 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	            if(!(EP2468STAT & bmEP6EMPTY))
	            { 
	                dum = D3ON;
				    outblink = 0x10;
				    EP6BCL = 0x80;          // re(arm) EP6OUT
	            }
	        break;
	
	        case Alt3_IsocIN:
	        case Alt5_IsocIN:
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	                dum = D4ON;
					inblink = 0x10;					// keep IN LED lit for this many SOF's
					
					EP2BCH = 0x04;
	                EP2BCL = 0x00;
	            }
	        break;
	
	
	        case Alt1_BulkOUT:
	        case Alt4_IsocOUT:
	            // check EP2 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	            if(!(EP2468STAT & bmEP2EMPTY))
	            { 
	                dum = D3ON;
					outblink = 0x10;

				    EP2BCL = 0x80;          // re(arm) EP2OUT
	            }
	        break;
	
	        case Alt6_IsocINOUT:
	        {
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	                dum = D4ON;
					inblink = 0x10;					// keep IN LED lit for this many SOF's
					
	                EP2BCH = 0x04;
	                EP2BCL = 0x00;
	
	            }
	
	            // check EP6 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	            if(!(EP2468STAT & bmEP6EMPTY))
	            { 
	                dum = D3ON;
					outblink = 0x10;
					
					EP6BCL = 0x80;          // re(arm) EP6OUT
	            }
	        }
	        break;
	   }
	   
	}
	else	// Full Speed
	{
	    // Perform USB activity based upon the Alt. Interface selected 
	     switch (AlternateSetting)
	    {
	        case Full_Alt0_BulkIN:
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	                dum = D4ON;				// Turn on the IN LED
					inblink = 0x10;			// keep IN LED lit for this many SOF's
					
					EP2BCH = 0x00;
	                EP2BCL = 0x40;
	
	            }
	        break;
	
	        case Full_Alt1_BulkOUT:	
	            // check EP2 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	            while(!(EP2468STAT & bmEP2EMPTY))
	            { 
	                EP2BCL = 0x80;          // re(arm) EP2OUT
	            }
	        break;
	
	        case Full_Alt2_IsocIN:
	            // Send data on EP2
	            while(!(EP2468STAT & bmEP2FULL))
	            {
	                dum = D4ON;				// Turn on the IN LED
					inblink = 0x10;			// keep IN LED lit for this many SOF's
					
					EP2BCH = 0x03;	// 1023
	                EP2BCL = 0xFF;
	
	             }
	        break;
	
	        case Full_Alt3_IsocOUT:
	            // check EP2 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
	            while(!(EP2468STAT & bmEP2EMPTY))
	            { 
					dum = D3ON;
					outblink = 0x10;
	                EP2BCL = 0x80;          // re(arm) EP2OUT
	            }
	        break;
	   }	
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
   return(TRUE);
}

BOOL DR_SetConfiguration(void)   // Called when a Set Configuration command is received
{
   Configuration = SETUPDAT[2];
   return(TRUE);            // Handled by user code
}

BOOL DR_GetConfiguration(void)   // Called when a Get Configuration command is received
{
   EP0BUF[0] = Configuration;
   EP0BCH = 0;
   EP0BCL = 1;
   return(TRUE);            // Handled by user code
}

BOOL DR_SetInterface(void)       // Called when a Set Interface command is received
{
	volatile BYTE updateDisplay;

	updateDisplay = TRUE;
	AlternateSetting = SETUPDAT[2];

	// ...FX2 in high speed mode
	if( EZUSB_HIGHSPEED( ) )
	{ 
	    // Change configuration based upon the Alt. Interface selected 
	    switch (AlternateSetting)
	    {
	        case Alt0_BulkIN:
	            // Only using endpoint 2, zero the valid bit on all others
	            // Just using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xE0;  // EP2 is DIR=IN, TYPE=BULK, SIZE=512, BUF=4x
	            SYNCDELAY;
	
	            EP1OUTCFG = (EP1OUTCFG & 0x7F);
	        	SYNCDELAY;
	        	EP1INCFG = (EP1INCFG & 0x7F);
	        	SYNCDELAY;
	        	EP4CFG = (EP4CFG & 0x7F);
	        	SYNCDELAY;
	        	EP6CFG = (EP6CFG & 0x7F);
	        	SYNCDELAY;
	        	EP8CFG = (EP8CFG & 0x7F);
	        	SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
	
	            // Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset
	
	        break;
	
	        case Alt1_BulkOUT:
	            // Only using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xA0;  // EP2 is DIR=OUT, TYPE=BULK, SIZE=512, BUF=4x
	            SYNCDELAY;
	
	            EP1OUTCFG = (EP1OUTCFG & 0x7F);
	        	SYNCDELAY;
	        	EP1INCFG = (EP1INCFG & 0x7F);
	        	SYNCDELAY;
	        	EP4CFG = (EP4CFG & 0x7F);
	        	SYNCDELAY;
	        	EP6CFG = (EP6CFG & 0x7F);
	        	SYNCDELAY;
	        	EP8CFG = (EP8CFG & 0x7F);
	        	SYNCDELAY;
           
				// Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;

	            // Reset data toggle to 0
	            TOGCTL = 0x02;  // EP2 OUT
	            TOGCTL = 0x22;  // EP2 OUT Reset
           
				// OUT endpoints do NOT come up armed
	            EP2BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm second buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm third buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm fourth buffer by writing BC w/skip=1
	            
	        break;
	
	        case Alt2_BulkINOUT:
	            // Using endpoints 2 & 6, zero the valid bit on all others
	            EP2CFG = 0xE0; // EP2 is DIR=IN, TYPE=BULK, SIZE=512, BUF=4x
	        	SYNCDELAY;
	            EP6CFG = 0xA0; // EP6 is DIR=OUT, TYPE=BULK, SIZE=512, BUF=4x   
	        	SYNCDELAY;
	            
	            EP1OUTCFG = (EP1OUTCFG & 0x7F);
	        	SYNCDELAY;
	        	EP1INCFG = (EP1INCFG & 0x7F);
	        	SYNCDELAY;
	        	EP4CFG = (EP4CFG & 0x7F);
	        	SYNCDELAY;
	        	EP8CFG = (EP8CFG & 0x7F);
	        	SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
	
				// Clear out any committed packets for EP6
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x06;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;

	            // Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset

				TOGCTL = 0x06;  // EP6 OUT
	            TOGCTL = 0x26;  // EP6 OUT Reset

	            // OUT endpoints do NOT come up armed
				EP6BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP6BCL = 0x80; // arm second buffer by writing BC w/skip=1
	        	SYNCDELAY;
	        break;
	
	        case Alt3_IsocIN:
	            // Only using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xD8;  // EP2 is DIR=IN, TYPE=ISOC, SIZE=1024, BUF=4x
	            SYNCDELAY;
	            
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP6CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;

				// Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset	
	
	            // This register sets the number of Isoc packets to send per
	            // uFrame.  This register is only valid in high speed.

      			EP2ISOINPKTS = 0x83;
	
	        break;
	
	        case Alt4_IsocOUT:
	        {
	            // Only using endpoint 2, zero the valid bit on all others
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP6CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	            EP2CFG = 0x98;  // EP2 is DIR=OUT, TYPE=ISOC, SIZE=1024, BUF=4x
	            SYNCDELAY;
				
				// Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
	
				// Reset data toggle to 0
	            TOGCTL = 0x02;  // EP2 IN
	            TOGCTL = 0x22;  // EP2 IN Reset
					
	            // OUT endpoints do NOT come up armed
	            EP2BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm second buffer by writing BC w/skip=1  
				
				// This register sets the number of Isoc packets to send per
	            // uFrame.  This register is only valid in high speed.

      			EP2ISOINPKTS = 0x83;      
	
	        }
	        break;
	
	        case Alt5_IsocIN:
	        {
	            // Only using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xD8;  // EP2 is DIR=IN, TYPE=ISOC, SIZE=1024, BUF=4x
	            SYNCDELAY;
	
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP6CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
	
				// Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset

	            // This register sets the number of Isoc packets to send per
	            // uFrame.  This register is only valid in high speed.
	            EP2ISOINPKTS = 0x01;
	        }
	        break;
	
	        case Alt6_IsocINOUT:
	        {
	            // Using endpoints 2 & 6, zero the valid bit on all others
	            EP2CFG = 0xDA; // EP2 is DIR=IN, TYPE=ISOC, SIZE=1024, BUF=2x
	            SYNCDELAY;
	            EP6CFG = 0x9A; // EP6 is DIR=OUT, TYPE=ISOC, SIZE=1024, BUF=2x   
	            SYNCDELAY;
	
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
				

				// Clear out any committed packets for EP6
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x06;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;

	
				// Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset

	            // This register sets the number of Isoc packets to send per
	            // uFrame.  This register is only valid in high speed.
	            EP2ISOINPKTS = 0x01;
	
				// Reset data toggle to 0
	            TOGCTL = 0x06;  // EP2 IN
	            TOGCTL = 0x26;  // EP2 IN Reset

	            // OUT endpoints do NOT come up armed
	            EP6BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP6BCL = 0x80; // arm second buffer by writing BC w/skip=1
	 
	        }
	        break;

	    }
	}
    else
    {
	    // Change configuration based upon the Alt. Interface selected 
	    switch (AlternateSetting)
	    {
	        case Full_Alt0_BulkIN:
	            // Only using endpoint 2, zero the valid bit on all others
	            // Just using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xE0;  // EP2 is DIR=IN, TYPE=BULK, SIZE=512, BUF=4x
	            SYNCDELAY;
	
	            EP1OUTCFG = (EP1OUTCFG & 0x7F);
	        	SYNCDELAY;
	        	EP1INCFG = (EP1INCFG & 0x7F);
	        	SYNCDELAY;
	        	EP4CFG = (EP4CFG & 0x7F);
	        	SYNCDELAY;
	        	EP6CFG = (EP6CFG & 0x7F);
	        	SYNCDELAY;
	        	EP8CFG = (EP8CFG & 0x7F);
	        	SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
	
	            // Reset data toggle to 0
	            TOGCTL = 0x12;  // EP2 IN
	            TOGCTL = 0x32;  // EP2 IN Reset
	
	        break;
	
	        case Full_Alt1_BulkOUT:
	            // Only using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xA0;  // EP2 is DIR=OUT, TYPE=BULK, SIZE=512, BUF=4x
	            SYNCDELAY;
	
	            EP1OUTCFG = (EP1OUTCFG & 0x7F);
	        	SYNCDELAY;
	        	EP1INCFG = (EP1INCFG & 0x7F);
	        	SYNCDELAY;
	        	EP4CFG = (EP4CFG & 0x7F);
	        	SYNCDELAY;
	        	EP6CFG = (EP6CFG & 0x7F);
	        	SYNCDELAY;
	        	EP8CFG = (EP8CFG & 0x7F);
	        	SYNCDELAY;
	           
	            // OUT endpoints do NOT come up armed
	            EP2BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm second buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm third buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm fourth buffer by writing BC w/skip=1
	            
	        break;
	
	
	        case Full_Alt2_IsocIN:
	            // Only using endpoint 2, zero the valid bit on all others
	            EP2CFG = 0xD8;  // EP2 is DIR=IN, TYPE=ISOC, SIZE=1024, BUF=4x
	            SYNCDELAY;
	            
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP6CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	
	            // Clear out any committed packets
	            FIFORESET = 0x80;
	            SYNCDELAY;
	            FIFORESET = 0x02;
	            SYNCDELAY;
	            FIFORESET = 0x00;
	            SYNCDELAY;
		
	        break;
	
	        case Full_Alt3_IsocOUT:
	        {
	            // Only using endpoint 2, zero the valid bit on all others
	            EP1OUTCFG = EP1INCFG = EP4CFG = EP6CFG = EP8CFG = 0x00; 
	            SYNCDELAY;
	            EP2CFG = 0x98;  // EP2 is DIR=OUT, TYPE=ISOC, SIZE=1024, BUF=4x
	            SYNCDELAY;
	
	            // OUT endpoints do NOT come up armed
	            EP2BCL = 0x80; // arm first buffer by writing BC w/skip=1
	            SYNCDELAY;
	            EP2BCL = 0x80; // arm second buffer by writing BC w/skip=1        break;
	
	        }
	        break;	
	
	    }
	}

   // Update the display to indicate the currently selected alt. Interface
	if(updateDisplay)
	{
	   EZUSB_WriteI2C(LED_ADDR, 0x01, &(Digit[AlternateSetting]));
	   EZUSB_WaitForEEPROMWrite(LED_ADDR);
	   updateDisplay = FALSE;
	}

   return(TRUE);            // Handled by user code
}

BOOL DR_GetInterface(void)       // Called when a Set Interface command is received
{
   EP0BUF[0] = AlternateSetting;
   EP0BCH = 0;
   EP0BCL = 1;
   return(TRUE);            // Handled by user code
}

BOOL DR_GetStatus(void)
{
   return(TRUE);
}

BOOL DR_ClearFeature(void)
{
   return(TRUE);
}

BOOL DR_SetFeature(void)
{
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
void ISR_Sudav(void) __interrupt 0
{
   GotSUD = TRUE;            // Set flag
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmSUDAV;         // Clear SUDAV IRQ
}

// Setup Token Interrupt Handler
void ISR_Sutok(void) __interrupt 0
{
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmSUTOK;         // Clear SUTOK IRQ
}

void ISR_Sof(void) __interrupt 0
{
	BYTE dum;
   	EZUSB_IRQ_CLEAR();
   	USBIRQ = bmSOF;            // Clear SOF IRQ
   	blinktime++;
   	if(blinktime&blinkmask)	dum=D5OFF;	// ~1/sec blinking LED
	else					dum=D5ON;

	if(--inblink == 0)
		dum = D4OFF;
	if(--outblink == 0)
		dum = D3OFF;
}

void ISR_Ures(void) __interrupt 0
{
    BYTE dum;
	// Whenever we get a USB Reset, we should revert to full speed mode
    pConfigDscr = pFullSpeedConfigDscr;
    ((CONFIGDSCR __xdata *) pConfigDscr)->type = CONFIG_DSCR;
    pOtherConfigDscr = pHighSpeedConfigDscr;
    ((CONFIGDSCR __xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;
   
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmURES;         // Clear URES IRQ
   dum = D2OFF;				// Turn off high-speed LED
   blinkmask = 0x0400;		// 2 sec period for FS
}

void ISR_Susp(void) __interrupt 0
{
   Sleep = TRUE;
   EZUSB_IRQ_CLEAR();
   USBIRQ = bmSUSP;
}

void ISR_Highspeed(void) __interrupt 0
{
   BYTE dum;
   blinkmask = 0x1000;		// 1 sec period for HS
   if (EZUSB_HIGHSPEED())
   {
      pConfigDscr = pHighSpeedConfigDscr;
      ((CONFIGDSCR __xdata *) pConfigDscr)->type = CONFIG_DSCR;
      pOtherConfigDscr = pFullSpeedConfigDscr;
      ((CONFIGDSCR __xdata *) pOtherConfigDscr)->type = OTHERSPEED_DSCR;

      // This register sets the number of Isoc packets to send per
      // uFrame.  This register is only valid in high speed.
//      EP2ISOINPKTS = 0x03;
      EP2ISOINPKTS = 0x83;	// 3 packets per microframe, AADJ=1
	  dum = D2ON;		// Turn on high-speed LED
   }
   else
   {
      pConfigDscr = pFullSpeedConfigDscr;
      pOtherConfigDscr = pHighSpeedConfigDscr;
   }

   EZUSB_IRQ_CLEAR();
   USBIRQ = bmHSGRANT;
}
void ISR_Ep0ack(void) __interrupt 0
{
}
void ISR_Stub(void) __interrupt 0
{
}
void ISR_Ep0in(void) __interrupt 0
{
}
void ISR_Ep0out(void) __interrupt 0
{
}
void ISR_Ep1in(void) __interrupt 0
{
}
void ISR_Ep1out(void) __interrupt 0
{
}

// ISR_Ep2inout is called on every OUT packet receieved.
// We don't do anything with the data.  We just indicate we are done with the buffer.
void ISR_Ep2inout(void) __interrupt 0
{
    // Perform USB activity based upon the Alt. Interface selected 
     switch (AlternateSetting)
    {
        case Alt1_BulkOUT:
        case Alt4_IsocOUT:
           // check EP2 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
            if(!(EP2468STAT & bmEP2EMPTY))
            { 
                EP2BCL = 0x80;          // re(arm) EP2OUT
            }
        break;

        case Alt2_BulkINOUT:
        case Alt6_IsocINOUT:
            // check EP6 EMPTY(busy) bit in EP2468STAT (SFR), core set's this bit when FIFO is empty
            if(!(EP2468STAT & bmEP6EMPTY))
            { 
                EP6BCL = 0x80;          // re(arm) EP6OUT
            }
        break;
   }

}
void ISR_Ep4inout(void) __interrupt 0
{
}
void ISR_Ep6inout(void) __interrupt 0
{
}
void ISR_Ep8inout(void) __interrupt 0
{
}
void ISR_Ibn(void) __interrupt 0
{
}
void ISR_Ep0pingnak(void) __interrupt 0
{
}
void ISR_Ep1pingnak(void) __interrupt 0
{
}
void ISR_Ep2pingnak(void) __interrupt 0
{
}
void ISR_Ep4pingnak(void) __interrupt 0
{
}
void ISR_Ep6pingnak(void) __interrupt 0
{
}
void ISR_Ep8pingnak(void) __interrupt 0
{
}
void ISR_Errorlimit(void) __interrupt 0
{
}
void ISR_Ep2piderror(void) __interrupt 0
{
}
void ISR_Ep4piderror(void) __interrupt 0
{
}
void ISR_Ep6piderror(void) __interrupt 0
{
}
void ISR_Ep8piderror(void) __interrupt 0
{
}
void ISR_Ep2pflag(void) __interrupt 0
{
}
void ISR_Ep4pflag(void) __interrupt 0
{
}
void ISR_Ep6pflag(void) __interrupt 0
{
}
void ISR_Ep8pflag(void) __interrupt 0
{
}
void ISR_Ep2eflag(void) __interrupt 0
{
}
void ISR_Ep4eflag(void) __interrupt 0
{
}
void ISR_Ep6eflag(void) __interrupt 0
{
}
void ISR_Ep8eflag(void) __interrupt 0
{
}
void ISR_Ep2fflag(void) __interrupt 0
{
}
void ISR_Ep4fflag(void) __interrupt 0
{
}
void ISR_Ep6fflag(void) __interrupt 0
{
}
void ISR_Ep8fflag(void) __interrupt 0
{
}
void ISR_GpifComplete(void) __interrupt 0
{
}
void ISR_GpifWaveform(void) __interrupt 0
{
}
