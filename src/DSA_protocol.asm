;******************************************************************************
; DSA protocol routines for sending and receiving a DSA command/response      *
; Filenaam: DSA_protocol.asm (version for MPASM)                              *
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
;   LAST MODIFICATION:  10.05.2006
;
;******************************************************************************
;   VERSION HISTORY                                                           *
;******************************************************************************
;
;   Version		Date		Remark
;	1.00		09/05/2006	Initial release
;
;__ END VERSION HISTORY _______________________________________________________
;       
;   Development system used:    MPLAB with MPASM from Microchip
;==============================================================================
;	Include Files:	P16f871.INC	V1.00
;
;=============================================================================


	list p=16f871					;list directive to define processor
	#include <p16f871.inc>			;processor specific definitions
	#include <CDP-1_IO.inc>			;port definitions

;CDP-1_main.asm
	extern	startTimeout, endTimeout, DSAResponseTable, displayError
	extern	FLAGS_0

;P16_LCD.asm
	EXTERN	lcd_character, lcd_clr_line1
	EXTERN	cursor_pos_line1, displayNumber

;LCD_strings.asm
	EXTERN	displayString


dsa_var		UDATA_SHR	;0x040
DSA_OPCODE			res 1			;opcode for DSA command
TMP_OPCODE			res 1			;temp opcode register
DSA_PARAM			res 1			;parameter for DSA command
TMP_PARAM			res 1			;temp param register
DSA_RESPONSE_OPCODE	res 1			;received DSA opcode
DSA_RESPONSE_PARAM	res 1			;received DSA parameter
BITCOUNT			res 1			;send/received bit counter
ATTEMPTS			res 1			;attempts counter for DSA communication

	GLOBAL	DSA_OPCODE, DSA_PARAM, DSA_RESPONSE_OPCODE, DSA_RESPONSE_PARAM


#define		TIMEOUT				FLAGS_0,3		;bit indicates timeout
#define		COM_ERROR			FLAGS_0,5		;bit indicates DSA communication error
#define		DSA_RESPONCE		FLAGS_0,6		;bit indicates DSA responce received

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------
	CONSTANT	DSA_TIMEOUT				= .25	;timeout for DSA communication 25 x 10ms
	CONSTANT	DSA_RESPONCE_TIMEOUT	= .100	;timeout for DSA responce after sending command 100 x 10ms
	CONSTANT	MAX_ATTEMPTS			= .2	;max number of attempts to communicate with CD-Pro2

;******************************************************************************
; Macros selection
;******************************************************************************
;Macros to select the register bank

Bank0		MACRO			;macro to select data RAM bank 0
	bcf	STATUS,RP0
	bcf	STATUS,RP1
	ENDM

Bank1		MACRO			;macro to select data RAM bank 1
	bsf	STATUS,RP0
	bcf	STATUS,RP1
	ENDM


PROG1	CODE
; -------------------------------------------------------------
; Description: Receive a DSA  response command from CD-Pro unit
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
waitForDSAresponce:
	GLOBAL	waitForDSAresponce

	movlw	DSA_RESPONCE_TIMEOUT
	call	startTimeout	;start timeout timer

_LOOP
	btfss	DSA_DDA				;check DSA dataline for request from CD-Pro
	goto	_receiveResponce
	btfsc	TIMEOUT
	goto	_responceTimeOut
	goto	_LOOP

_receiveResponce:
	call	endTimeout
	call	receiveDSAresponse
	btfsc	DSA_RESPONCE
	call	DSAResponseTable
	return

_responceTimeOut:
	movlw	.101				;Error #101 "DSA responce timeout"
	call	displayError
	return

; -------------------------------------------------------------
; Description: Receive a DSA  response command from CD-Pro unit
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
receiveDSAresponse:
	GLOBAL	receiveDSAresponse
	clrf	DSA_RESPONSE_OPCODE
	clrf	DSA_RESPONSE_PARAM
	bcf		DSA_RESPONCE
	bsf		DSA_ACK			;set acknowledge
	Bank1
	bsf		DSA_DST			;set strobe as input
	bsf		DSA_DDA			;set data as input
	bcf		DSA_ACK			;set acknowlege as output
	Bank0
	movlw	DSA_TIMEOUT
	call	startTimeout	;start timeout timer
	bcf		DSA_ACK			;clear acknowledge
	btfsc	TIMEOUT
	goto	_endDSAreceive
	btfss	DSA_DDA			;wait for data-line to go high
	goto	$-3
	bsf		DSA_ACK			;set acknowledge
	call	endTimeout		;stop timeout timer
;data Transmision Phase
	movlw	.16
	movwf	BITCOUNT		;set bit counter to 16
	movlw	DSA_TIMEOUT
	call	startTimeout	;start timeout timer
_receiveLoop:
	btfsc	TIMEOUT
	goto	_endDSAreceive
	btfsc	DSA_DST			;wait for stobe-line to low
	goto	$-3
	bcf		STATUS,C
	btfsc	DSA_DDA			;read data-line status
	bsf		STATUS,C
	rlf		DSA_RESPONSE_PARAM,F	;shift received bit into register
	rlf		DSA_RESPONSE_OPCODE,F
	bcf		DSA_ACK			;clear acknowledge
	btfsc	TIMEOUT
	goto	_endDSAreceive
	btfss	DSA_DST			;wait for strobe-line to go high
	goto	$-3
	bsf		DSA_ACK			;set acknowledge
	decfsz	BITCOUNT,F
	goto	_receiveLoop
	call	endTimeout		;stop timeout timer
;Communication acknowledge
	bsf		DSA_DDA			;set data
	Bank1
	bcf		DSA_DST			;set strobe as output
	bcf		DSA_DDA			;set data as output
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	movlw	DSA_TIMEOUT
	call	startTimeout	;start timeout timer
	btfsc	TIMEOUT
	goto	_endDSAreceive
	btfsc	DSA_ACK			;wait for acknowledge-line to go low
	goto	$-3
	movf	BITCOUNT,F
	btfss	STATUS,Z
	bcf		DSA_DDA			;clear data-line when bitcounter is not zero
	bcf		DSA_DST			;clear strobe
	btfsc	TIMEOUT
	goto	_endDSAreceive
	btfss	DSA_ACK			;wait for acknowledge-line to go high
	goto	$-3
	bsf		DSA_DDA			;set data 
	bsf		DSA_DST			;set strobe
	bsf		DSA_RESPONCE	;set response bit to indicate correct responce bits received
_endDSAreceive:
	call	endTimeout		;stop timeout timer
	Bank1
	bsf		DSA_DST			;set strobe as input
	bsf		DSA_DDA			;set data as input
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	return


; -------------------------------------------------------------
; Description: Send a DSA command
;
; Reg. IN:		DSA_OPCODE, DSA_PARAM
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
sendDSACommand:
	GLOBAL	sendDSACommand
	movlw	MAX_ATTEMPTS
	movwf	ATTEMPTS
_synchPhase
	movfw	DSA_OPCODE
	movwf	TMP_OPCODE
	movfw	DSA_PARAM
	movwf	TMP_PARAM
	bcf		COM_ERROR
	bsf		DSA_DDA			;set data high
	Bank1
	bcf		DSA_DDA			;set data as output
	bsf		DSA_DST			;set strobe as input
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	movlw	DSA_TIMEOUT
	call	startTimeout
	bcf		DSA_DDA
	btfsc	TIMEOUT
	goto	_comError
	btfsc	DSA_ACK
	goto	$-3
	bsf		DSA_DDA
	btfsc	TIMEOUT
	goto	_comError
	btfss	DSA_ACK
	goto	$-3
	call	endTimeout

;Data transfer phase
	movlw	.16				;number of bits to send
	movwf	BITCOUNT
	bsf		DSA_DST			;set strobe high
	bsf		DSA_DDA			;set data high
	Bank1
	bcf		DSA_DST			;set strobe as output
	bcf		DSA_DDA			;set data as output
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	movlw	DSA_TIMEOUT
	call	startTimeout
_dataTransferLoop:
 	rlf		TMP_PARAM,F		;shift left parameter register
	rlf		TMP_OPCODE,F	;shift left opcode register
	btfss	STATUS,C
	bcf		DSA_DDA			;if carry is low clear databit
	bcf		DSA_DST			;clear strobe
	btfsc	TIMEOUT
	goto	_comError
	btfsc	DSA_ACK			;wait for ack to go low
	goto	$-3
	bsf		DSA_DST			;set strobe
	bsf		DSA_DDA
	btfsc	TIMEOUT
	goto	_comError
	btfss	DSA_ACK			;wait for ack to go high
	goto	$-3
	decfsz	BITCOUNT,F
	goto	_dataTransferLoop
	call	endTimeout

;Communication acknowledge phase
	bsf		DSA_ACK			;set acknowlege high
	Bank1
	bsf		DSA_DDA			;set data as input
	bsf		DSA_DST			;set strobe as input
	bcf		DSA_ACK			;set acknowlege as output
	Bank0
	movlw	DSA_TIMEOUT
	call	startTimeout
	bcf		DSA_ACK			;clear acknowledge
	btfsc	TIMEOUT
	goto	_comError
	btfsc	DSA_DST			;wait for strobe to go low
	goto	$-3
	btfss	DSA_DDA			;read status data
	bsf		COM_ERROR		;if data is cleared com error
	bsf		DSA_ACK			;set acknowledge
	btfsc	TIMEOUT
	goto	_comError
	btfss	DSA_DST			;wait for strobe to go high
	goto	$-3
	call	endTimeout
	Bank1
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	btfss	COM_ERROR
	return

_comError:
	Bank1
	bsf		DSA_DST			;set strobe as input
	bsf		DSA_DDA			;set data as input
	bsf		DSA_ACK			;set acknowlege as input
	Bank0
	bsf		COM_ERROR
	decfsz	ATTEMPTS,F
	goto	_synchPhase

	movlw	.102			;Error #102 "DSA com error"
	call	displayError

	return

; -------------------------------------------------------------
	END
