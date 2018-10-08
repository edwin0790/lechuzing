;;-----------------------------------------------------------------------------
;;   File:      dscr.a51
;;   Contents:   This file contains descriptor data tables.  
;;
;;   Copyright (c) 2003 Cypress Semiconductor, Inc. All rights reserved
;;-----------------------------------------------------------------------------

   
DSCR_DEVICE   =   1   ;; Descriptor type: Device
DSCR_CONFIG   =   2   ;; Descriptor type: Configuration
DSCR_STRING   =   3   ;; Descriptor type: String
DSCR_INTRFC   =   4   ;; Descriptor type: Interface
DSCR_ENDPNT   =   5   ;; Descriptor type: Endpoint
DSCR_DEVQUAL  =   6   ;; Descriptor type: Device Qualifier

DSCR_DEVICE_LEN   =   18
DSCR_CONFIG_LEN   =    9
DSCR_INTRFC_LEN   =    9
DSCR_ENDPNT_LEN   =    7
DSCR_DEVQUAL_LEN  =   10

ET_CONTROL   =   0   ;; Endpoint type: Control
ET_ISO       =   1   ;; Endpoint type: Isochronous
ET_BULK      =   2   ;; Endpoint type: Bulk
ET_INT       =   3   ;; Endpoint type: Interrupt

.module DSCR
.globl      _DeviceDscr, _DeviceQualDscr, _HighSpeedConfigDscr, _FullSpeedConfigDscr, _StringDscr, _UserDscr

.area DSCR (CODE,ABS)
.org 0xE000

;DSCR   SEGMENT   CODE

;;-----------------------------------------------------------------------------
;; Global Variables
;;-----------------------------------------------------------------------------
;      rseg DSCR     ;; locate the descriptor table in on-part memory.

;CSEG   AT 100H

.even
_DeviceDscr:
      .db   DSCR_DEVICE_LEN      ;; Descriptor length
      .db   DSCR_DEVICE   ;; Decriptor type
      .dw   0x0002      ;; Specification Version (BCD)
      .db   0x00        ;; Device class
      .db   0x00         ;; Device sub-class
      .db   0x00         ;; Device sub-sub-class
      .db   64         ;; Maximum packet size
      .dw   0x0B404      ;; Vendor ID
      .dw   0x0310      ;; Product ID (Sample Device)
      .dw   0x0000      ;; Product version ID
      .db   1         ;; Manufacturer string index
      .db   2         ;; Product string index
      .db   0         ;; Serial number string index
      .db   1         ;; Number of configurations

;org (($ / 2) +1) * 2
.even
_DeviceQualDscr:
      .db   DSCR_DEVQUAL_LEN   ;; Descriptor length
      .db   DSCR_DEVQUAL   ;; Decriptor type
      .dw   0x0002      ;; Specification Version (BCD)
      .db   0x00        ;; Device class
      .db   0x00         ;; Device sub-class
      .db   0x00         ;; Device sub-sub-class
      .db   64         ;; Maximum packet size
      .db   1         ;; Number of configurations
      .db   0         ;; Reserved

;org (($ / 2) +1) * 2

.even
_HighSpeedConfigDscr:
      .db   DSCR_CONFIG_LEN               ;; Descriptor length
      .db   DSCR_CONFIG                  ;; Descriptor type
      .db   (HighSpeedConfigDscr_End-_HighSpeedConfigDscr) % 256 ;; Total Length (LSB)
      .db   (HighSpeedConfigDscr_End-_HighSpeedConfigDscr)  /  256 ;; Total Length (MSB)
      .db   1      ;; Number of interfaces
      .db   1      ;; Configuration number
      .db   0      ;; Configuration string
      .db   0x80   ;; Attributes (b7 - buspwr, b6 - selfpwr, b5 - rwu)
      .db   50      ;; Power requirement (div 2 ma)

;; Alt Interface 0 Descriptor - Bulk IN
      .db   DSCR_INTRFC_LEN   ;; Descriptor length
      .db   DSCR_INTRFC       ;; Descriptor type
      .db   0                 ;; Zero-based index of this interface
      .db   0                 ;; Alternate setting
      .db   2                 ;; Number of end points
      .db   0x0ff               ;; Interface class
      .db   0x00                ;; Interface sub class
      .db   0x00                ;; Interface sub sub class
      .db   0                 ;; Interface descriptor string index This would be nice to add!

;; Isoc IN Endpoint Descriptor 
      .db   DSCR_ENDPNT_LEN   ;; Descriptor length
      .db   DSCR_ENDPNT       ;; Descriptor type
      .db   0x82                ;; Endpoint 2 and direction IN
      .db   ET_ISO            ;; Endpoint type
      .db   0x00                ;; Maximun packet size (LSB)
      .db   0x14                ;; Max packect size (MSB) 10100b 3x1024 byte packets/uFrame
      .db   0x01                ;; Polling interval
      
;; Bulk OUT Endpoint Descriptor
      .db   DSCR_ENDPNT_LEN   ;; Descriptor length
      .db   DSCR_ENDPNT       ;; Descriptor type
      .db   0x08                ;; Endpoint 8 and direction OUT
      .db   ET_BULK           ;; Endpoint type
      .db   0x00                ;; Maximun packet size (LSB)
      .db   0x02                ;; Max packect size (MSB) 512 byte packets/uFrame
      .db   0x00                ;; Polling interval

HighSpeedConfigDscr_End:



;org (($ / 2) +1) * 2
.even
_FullSpeedConfigDscr:
      .db   DSCR_CONFIG_LEN               ;; Descriptor length
      .db   DSCR_CONFIG                  ;; Descriptor type
      .db   (FullSpeedConfigDscr_End-_FullSpeedConfigDscr) % 256 ;; Total Length (LSB)
      .db   (FullSpeedConfigDscr_End-_FullSpeedConfigDscr)  /  256 ;; Total Length (MSB)
      .db   1      ;; Number of interfaces
      .db   1      ;; Configuration number
      .db   0      ;; Configuration string
      .db   0b10100000   ;; Attributes (b7 - buspwr, b6 - selfpwr, b5 - rwu)
      .db   50      ;; Power requirement (div 2 ma)

;; Interface Descriptor
      .db   DSCR_INTRFC_LEN      ;; Descriptor length
      .db   DSCR_INTRFC         ;; Descriptor type
      .db   0               ;; Zero-based index of this interface
      .db   0               ;; Alternate setting
      .db   2               ;; Number of end points
      .db   0x0ff             ;; Interface class
      .db   0x00                ;; Interface sub class
      .db   0x00                ;; Interface sub sub class
      .db   0               ;; Interface descriptor string index

;; Endpoint Descriptor
      .db   DSCR_ENDPNT_LEN   ;; Descriptor length
      .db   DSCR_ENDPNT       ;; Descriptor type
      .db   0x82               ;; Endpoint number, and direction
      .db   ET_ISO            ;; Endpoint type
      .db   0x0FF               ;; Maximun packet size (LSB)
      .db   0x03               ;; Max packect size (MSB) 1023 byte packets/Frame
      .db   0x01               ;; Polling interval

;; Endpoint Descriptor
      .db   DSCR_ENDPNT_LEN   ;; Descriptor length
      .db   DSCR_ENDPNT       ;; Descriptor type
      .db   0x08                ;; Endpoint number, and direction
      .db   ET_BULK            ;; Endpoint type
      .db   0x040                ;; Maximun packet size (LSB)
      .db   0x00                ;; Max packect size (MSB)
      .db   0x01                ;; Polling interval
      
FullSpeedConfigDscr_End:

;org (($ / 2) +1) * 2
.even
_StringDscr:

.even
_StringDscr0:
      .db   StringDscr0_End-_StringDscr0      ;; String descriptor length
      .db   DSCR_STRING
      .db   0x09,0x04
StringDscr0_End:

.even
_StringDscr1:
      .db   StringDscr1_End-_StringDscr1      ;; String descriptor length
      .db   DSCR_STRING
      .db   'C',00
      .db   'y',00
      .db   'p',00
      .db   'r',00
      .db   'e',00
      .db   's',00
      .db   's',00
StringDscr1_End:

.even
_StringDscr2:
      .db   StringDscr2_End-_StringDscr2      ;; Descriptor length
      .db   DSCR_STRING
      .db   'C',00
      .db   'Y',00
      .db   '-',00
      .db   'S',00
      .db   't',00
      .db   'r',00
      .db   'e',00
      .db   'a',00
      .db   'm',00
StringDscr2_End:

.even
_StringDscr3:
      .db   StringDscr3_End-_StringDscr3      ;; Descriptor length
      .db   DSCR_STRING
      .db   'B',00
      .db   'u',00
      .db   'l',00
      .db   'k',00
      .db   '-',00
      .db   'I',00
      .db   'N',00
StringDscr3_End:

.even
_UserDscr:
      .dw   0x0000
      
