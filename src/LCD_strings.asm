;******************************************************************************
; LCD dipsplay routines                                                       *
; Filenaam: LCD_strings.asm     (version for MPASM)                           *
;******************************************************************************
;
;   LAST MODIFICATION:  01.12.2006
;
;******************************************************************************
;   VERSION HISTORY                                                           *
;******************************************************************************
;
;   Version		Date		Remark
;	1.00		09/20/2006	Initial release
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

;P16_LCD.asm
	EXTERN	lcd_character, setCGRAMaddress

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------
	CONSTANT	EOS_CHAR	= '^'		;character to indicate the end of the string


string_var		UDATA_SHR	;0x050
;----------------------------------------------------------------------------
; Variables
;----------------------------------------------------------------------------
CHAR			res 1
CHAR_OFFSET		res 1			;offset register for (text sting) lookup table


STRINGS	CODE
; -------------------------------------------------------------
; Description:	Textstrings to be displayed
;
; Reg. IN:		W (sting start, CHAR_OFFSET)
; Reg. OUT:		-
; Reg. Changed:	W, CHAR_OFFSET, PCLATH
; -------------------------------------------------------------
string_table
	addwf	PCL,F
	;	"string^"			;pointer value first character
	dt	"Play^"					;0x00
	dt	"Pause^"				;0x05
	dt	"track^"				;0x0B
	dt	"shuffle^"				;0x11
	dt	"Disc^"					;0x19
	dt	"intro^"				;0x1E
	dt	"Insert disc^"			;0x24
	dt	"No disc^"				;0x30
	dt	" Bergrans CDP-1 ^"		;0x38
;	dt	"Your display txt^"		;0x38
	dt	"Reading disc^"			;0x49
	dt	"Opening^"				;0x56
	dt	"Closing^"				;0x5E
	dt	"Set DAC mode:^"		;0x66
	dt	"Program^"				;0x74

displayString:
	GLOBAL	displayString
	movwf	CHAR_OFFSET
_next_char
	movlw	HIGH string_table
	movwf	PCLATH
	movfw	CHAR_OFFSET			;character table location
	call	string_table		;retrieve 1 character
	movwf	CHAR
	sublw	EOS_CHAR
	btfsc	STATUS,Z			;check for "End Of Sting" character
	return						;return at EOS
	movfw	CHAR				;load character
	call	lcd_character		;write to display
	incf	CHAR_OFFSET,F		;pointer to next character in string
	goto	_next_char			;next character


; -------------------------------------------------------------
; Description:	Loading the pre defined custom characters into the CGRAM
;				of the display unit
;
; row 0		   #		0x02
; row 1		 ####		0x0F
; row 2		#  #		0x12
; row 3		#			0x10
; row 4		 #			0x08
; row 5		  ##		0x06
; row 6					0x00
; row 7					0x00
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed:	PCL, CHAR_OFFSET, PCLATH
; -------------------------------------------------------------
char_table
	addwf	PCL,F
	dt	0x02, 0x0F, 0x12, 0x10, 0x08, 0x06, 0x00, 0x00	;symbol "arrow right" used for REPEAT indication
	dt	0x00, 0x0C, 0x02, 0x01, 0x09, 0x1E, 0x08, 0x00	;symbol "arrow left" used for REPEAT indication

loadCustomCharacters:
	GLOBAL	loadCustomCharacters

	clrf	CHAR_OFFSET
_next_char_row
	movfw	CHAR_OFFSET
	call	setCGRAMaddress

	movlw	HIGH char_table
	movwf	PCLATH
	movfw	CHAR_OFFSET			;character table location
	call	char_table			;retrieve 1 character-row
	call	lcd_character		;write to CGRAM
	incf	CHAR_OFFSET, F		;pointer to next character in string
	movlw	.16
	subwf	CHAR_OFFSET, W
	btfsc	STATUS, Z
	return
	goto	_next_char_row		;next character row

; -------------------------------------------------------------
	END
