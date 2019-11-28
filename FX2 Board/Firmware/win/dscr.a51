;;-----------------------------------------------------------------------------
;;   File:      dscr.a51
;;   Contents:   This file contains descriptor data tables.  
;;
;;   Copyright (c) 2003 Cypress Semiconductor, Inc. All rights reserved
;;-----------------------------------------------------------------------------

   
DSCR_DEVICE   equ   1   ;; Descriptor type: Device
DSCR_CONFIG   equ   2   ;; Descriptor type: Configuration
DSCR_STRING   equ   3   ;; Descriptor type: String
DSCR_INTRFC   equ   4   ;; Descriptor type: Interface
DSCR_ENDPNT   equ   5   ;; Descriptor type: Endpoint
DSCR_DEVQUAL  equ   6   ;; Descriptor type: Device Qualifier

DSCR_DEVICE_LEN   equ   18
DSCR_CONFIG_LEN   equ    9
DSCR_INTRFC_LEN   equ    9
DSCR_ENDPNT_LEN   equ    7
DSCR_DEVQUAL_LEN  equ   10

ET_CONTROL   equ   0   ;; Endpoint type: Control
ET_ISO       equ   1   ;; Endpoint type: Isochronous
ET_BULK      equ   2   ;; Endpoint type: Bulk
ET_INT       equ   3   ;; Endpoint type: Interrupt

public      DeviceDscr, DeviceQualDscr, HighSpeedConfigDscr, FullSpeedConfigDscr, StringDscr, UserDscr


;DSCR   SEGMENT   CODE

;;-----------------------------------------------------------------------------
;; Global Variables
;;-----------------------------------------------------------------------------
;      rseg DSCR     ;; locate the descriptor table in on-part memory.

;CSEG   AT 100H
            cseg at 100H               ;; TODO: this needs to be changed before release

DeviceDscr:
      db   DSCR_DEVICE_LEN      ;; Descriptor length
      db   DSCR_DEVICE   ;; Decriptor type
      dw   0002H      ;; Specification Version (BCD)
      db   00H        ;; Device class
      db   00H         ;; Device sub-class
      db   00H         ;; Device sub-sub-class
      db   64         ;; Maximum packet size
      dw   0B404H      ;; Vendor ID
      dw   0310H      ;; Product ID (Sample Device)
      dw   0000H      ;; Product version ID
      db   1         ;; Manufacturer string index
      db   2         ;; Product string index
      db   0         ;; Serial number string index
      db   1         ;; Number of configurations

org (($ / 2) +1) * 2
DeviceQualDscr:
      db   DSCR_DEVQUAL_LEN   ;; Descriptor length
      db   DSCR_DEVQUAL   ;; Decriptor type
      dw   0002H      ;; Specification Version (BCD)
      db   00H        ;; Device class
      db   00H         ;; Device sub-class
      db   00H         ;; Device sub-sub-class
      db   64         ;; Maximum packet size
      db   1         ;; Number of configurations
      db   0         ;; Reserved

org (($ / 2) +1) * 2
HighSpeedConfigDscr:
      db   DSCR_CONFIG_LEN               ;; Descriptor length
      db   DSCR_CONFIG                  ;; Descriptor type
      db   (HighSpeedConfigDscr_End-HighSpeedConfigDscr) mod 256 ;; Total Length (LSB)
      db   (HighSpeedConfigDscr_End-HighSpeedConfigDscr)  /  256 ;; Total Length (MSB)
      db   1      ;; Number of interfaces
      db   1      ;; Configuration number
      db   3     ;; Configuration string
      db   80H   ;; Attributes (b7 - buspwr, b6 - selfpwr, b5 - rwu)
      db   50      ;; Power requirement (div 2 ma)

;; Alt Interface 0 Descriptor - Bulk IN
      db   DSCR_INTRFC_LEN   ;; Descriptor length
      db   DSCR_INTRFC       ;; Descriptor type
      db   0                 ;; Zero-based index of this interface
      db   0                 ;; Alternate setting
      db   2                 ;; Number of end points
      db   0ffH               ;; Interface class
      db   00H                ;; Interface sub class
      db   00H                ;; Interface sub sub class
      db   0                 ;; Interface descriptor string index This would be nice to add!

;; Isoc IN Endpoint Descriptor 
      db   DSCR_ENDPNT_LEN   ;; Descriptor length
      db   DSCR_ENDPNT       ;; Descriptor type
      db   82H                ;; Endpoint 2 and direction IN
      db   ET_ISO            ;; Endpoint type
      db   00H                ;; Maximun packet size (LSB)
      db   02H                ;; Max packect size (MSB) 10100b 3x1024 byte packets/uFrame
      db   01H                ;; Polling interval
      
;; Bulk OUT Endpoint Descriptor
      db   DSCR_ENDPNT_LEN   ;; Descriptor length
      db   DSCR_ENDPNT       ;; Descriptor type
      db   08H                ;; Endpoint 8 and direction OUT
      db   ET_BULK           ;; Endpoint type
      db   00H                ;; Maximun packet size (LSB)
      db   02H                ;; Max packect size (MSB) 512 byte packets/uFrame
      db   00H                ;; Polling interval

HighSpeedConfigDscr_End:



org (($ / 2) +1) * 2
FullSpeedConfigDscr:
      db   DSCR_CONFIG_LEN               ;; Descriptor length
      db   DSCR_CONFIG                  ;; Descriptor type
      db   (FullSpeedConfigDscr_End-FullSpeedConfigDscr) mod 256 ;; Total Length (LSB)
      db   (FullSpeedConfigDscr_End-FullSpeedConfigDscr)  /  256 ;; Total Length (MSB)
      db   1      ;; Number of interfaces
      db   1      ;; Configuration number
      db   3      ;; Configuration string
      db   80h   ;; Attributes (b7 - buspwr, b6 - selfpwr, b5 - rwu)
      db   50      ;; Power requirement (div 2 ma)

;; Interface Descriptor
      db   DSCR_INTRFC_LEN      ;; Descriptor length
      db   DSCR_INTRFC         ;; Descriptor type
      db   0               ;; Zero-based index of this interface
      db   0               ;; Alternate setting
      db   2               ;; Number of end points
      db   0ffH             ;; Interface class
      db   00H                ;; Interface sub class
      db   00H                ;; Interface sub sub class
      db   0               ;; Interface descriptor string index

;; Endpoint Descriptor
      db   DSCR_ENDPNT_LEN   ;; Descriptor length
      db   DSCR_ENDPNT       ;; Descriptor type
      db   82H               ;; Endpoint number, and direction
      db   ET_ISO            ;; Endpoint type
      db   0FFH               ;; Maximun packet size (LSB)
      db   02H               ;; Max packect size (MSB) 1023 byte packets/Frame
      db   01H               ;; Polling interval

;; Endpoint Descriptor
      db   DSCR_ENDPNT_LEN   ;; Descriptor length
      db   DSCR_ENDPNT       ;; Descriptor type
      db   08H                ;; Endpoint number, and direction
      db   ET_BULK            ;; Endpoint type
      db   040H                ;; Maximun packet size (LSB)
      db   00H                ;; Max packect size (MSB)
      db   01H                ;; Polling interval
      
FullSpeedConfigDscr_End:

org (($ / 2) +1) * 2
StringDscr:

StringDscr0:
      db   StringDscr0_End-StringDscr0      ;; String descriptor length
      db   DSCR_STRING
      db   09H,04H
StringDscr0_End:

StringDscr1:
      db   StringDscr1_End-StringDscr1      ;; String descriptor length
      db   DSCR_STRING
      db   'E',00
      db   'd',00
      db   'w',00
      db   'i',00
      db   'n',00
      db   ' ',00
      db   'B',00
	  db   'a',00	
	  db   'r',00
	  db   'r',00
	  db   'a',00
	  db   'g',00
	  db   'a',00
	  db   'n',00
StringDscr1_End:

StringDscr2:
      db   StringDscr2_End-StringDscr2      ;; Descriptor length
      db   DSCR_STRING
      db   'L',00
      db   'a',00
      db   '-',00
      db   'T',00
      db   'e',00
      db   's',00
      db   'i',00
      db   's',00
StringDscr2_End:

;StringDscr3:
      ;db   StringDscr3_End-StringDscr3      ;; Descriptor length
      ;db   DSCR_STRING
      ;db   'B',00
      ;db   'u',00
      ;db   'l',00
      ;db   'k',00
      ;db   '-',00
      ;db   'I',00
      ;db   'N',00
;StringDscr3_End:

UserDscr:
	db 00
end
      
