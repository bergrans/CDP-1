;******************************************************************************
; EEPROM read/write routines                                                  *
; Filenaam: P16_EEPROM.asm     (version for MPASM)                            *
;******************************************************************************
; Copyright: Martin van den Berg, Bergrans DIY Audio, The Netherlands
;
; This work (and included software, documentation such as READMEs, or other
; related items) is being provided by the copyright ;holders under the
; following license. By obtaining, using and/or copying this work, you
; (the licensee) agree that you have read, understood, and will comply with
; the following terms and conditions.
;
; Permission to copy, modify, and distribute this software and its
; documentation, with or without modification, for any purpose and without
; fee or royalty is hereby granted, provided that you include the following
; on ALL copies of the software and documentation or portions thereof, including
; modifications:
;
;   1. The full text of this NOTICE in a location viewable to users of the
;      redistributed or derivative work.
;   2. Notice of any changes or modifications to the files, including the date
;      changes were made.
;
; THIS SOFTWARE AND DOCUMENTATION IS PROVIDED "AS IS," AND COPYRIGHT HOLDERS
; MAKE NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT
; LIMITED TO, WARRANTIES OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR
; PURPOSE OR THAT THE USE OF THE SOFTWARE OR DOCUMENTATION WILL NOT INFRINGE
; ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.
;
; COPYRIGHT HOLDERS WILL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, SPECIAL OR
; CONSEQUENTIAL DAMAGES ARISING OUT OF ANY USE OF THE SOFTWARE OR DOCUMENTATION.
;
; The name and trademarks of copyright holders may NOT be used in advertising
; or publicity pertaining to the software without specific, written prior permission.
; Title to copyright in this software and any associated documentation will at
; all times remain with copyright holders.
;
;
;******************************************************************************
;
;   LAST MODIFICATION:  10.20.2006
;
;******************************************************************************
;   VERSION HISTORY                                                           *
;******************************************************************************
;
;   Version		Date		Remark
;	1.00		10/20/2006	Initial release
;
;__ END VERSION HISTORY _______________________________________________________
;       
;   Development system used:    MPLAB with MPASM from Microchip
;==============================================================================
;	Include Files:	P16f871.INC	V1.00
;
;=============================================================================
;
;=============================================================================

	list p=16f871					;list directive to define processor
	#include <p16f871.inc>			;processor specific definitions
	errorlevel -302					;suppress "not in bank 0" message

;P16_LCD.asm
	EXTERN	lcd_character

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------
	CONSTANT	EOS_CHAR	= '^'		;character to indicate the end of the string


eeprom_var		UDATA_SHR;	0x050
;----------------------------------------------------------------------------
; Variables
;----------------------------------------------------------------------------
EEPROM_DATA			res 1
	GLOBAL	EEPROM_DATA


PROG1	CODE
; -------------------------------------------------------------
; Description	: Read data from EEPROM
;
; Reg. IN	: W (holds EEPROM adres)
; Reg. OUT	: EEDATA
; Reg. Changed	: EEADR, EECON1, STATUS
; -------------------------------------------------------------
read_EEPROM:
	GLOBAL	read_EEPROM

	bsf		STATUS, RP1
	bcf		STATUS, RP0		;Bank 2
	movwf	EEADR			;to read from
	bsf		STATUS, RP0		;Bank 3
	bcf		EECON1, EEPGD	;Point to Data memory
	bsf		EECON1, RD		;Start read operation
	bcf		STATUS, RP0		;Bank 2
	movfw	EEDATA			;W = EEDATA
	bcf		STATUS, RP1		;Bank 0		
	return


; -------------------------------------------------------------
; Description	: Write data from EEPROM
;
; Reg. IN	: W (holds EEPROM adres), EEDATA
; Reg. OUT	: -
; Reg. Changed	: EEADR, EECON1, EECON2, STATUS
; -------------------------------------------------------------
write_EEPROM:
	GLOBAL	write_EEPROM

	bsf		STATUS, RP1
	bsf		STATUS, RP0		;Bank 3
	btfsc	EECON1, WR		;Wait for
	goto	$-1				;write to finish

	bcf		STATUS, RP0 	;Bank 2
	movwf	EEADR			;write to
	movfw	EEPROM_DATA		;Data to
	movwf	EEDATA			;write

	bsf		STATUS, RP0		;Bank 3
	bcf		EECON1, EEPGD	;Point to Data memory
	bsf		EECON1, WREN	;Enable writes

	movlw	0x55			;Write 55h to
	movwf	EECON2			;EECON2
	movlw	0xAA			;Write AAh to
	movwf	EECON2			;EECON2
	bsf		EECON1, WR		;Start write operation

	bcf		EECON1, WREN	;Disable writes
	bcf		STATUS, RP0
	bcf		STATUS, RP1		;Bank 0
	return

; -------------------------------------------------------------
	END
