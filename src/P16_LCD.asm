;******************************************************************************
; LCD dipsplay routines                                                       *
; Filenaam: P16_LCD.ASM     (version for MPASM)                               *
;******************************************************************************
;
;   LAST MODIFICATION:  09.04.2006
;
;******************************************************************************
;   VERSION HISTORY                                                           *
;******************************************************************************
;
;   Version		Date		Remark
;	1.00		09/04/2006	Initial release
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

	list p=16f871				;list directive to define processor
	#include <p16f871.inc>		;processor specific definitions
	#include <CDP-1_IO.inc>		;port definitions
	errorlevel -302				;suppress "not in bank 0" message

	EXTERN	us_delay, ms_delay

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------
	CONSTANT	LCDBUSYWAIT		= 0x18		;wait before LCD busy flag is available


lcd_var		UDATA_SHR	;0x055

COUNT		res	1
VALUE		res	1
LCD_TEMP	res	1
LCD_FLAGS	res 1

	GLOBAL	LCD_FLAGS


#define		LEADINGZERO		LCD_FLAGS,0		;bit indicates dispay leading zero on numbers
#define		NOSPACE			LCD_FLAGS,1		;bit indicates dispay leading zero not taking a character space
#define		LCD_BUSY		LCD_FLAGS,2		;bit indicates dispay is busy

D7	EQU		0x03				; LCD data line 7, for busy flag

LCDEnable	MACRO
	bsf		LCD_EN				;generate enable puls for lcd
	bcf		LCD_EN
	endm

clearLCDdatabits	MACRO
	movlw	b'11110000'
	andwf	LCD_PORT,F			;clearing lower nibble
	endm

Bank0		MACRO				;macro to select data RAM bank 0
	bcf	STATUS,RP0
	bcf	STATUS,RP1
	ENDM

Bank1		MACRO				;macro to select data RAM bank 1
	bsf	STATUS,RP0
	bcf	STATUS,RP1
	ENDM


PROG1	CODE
; -------------------------------------------------------------
; Description: LCD commands
;
; Reg. IN	: W
; Reg. OUT	: -
; Reg. Changed	: LCD_PORT
; -------------------------------------------------------------
lcd_clr:
	GLOBAL	lcd_clr
	movlw	b'00000001'			;clear command
	call	lcd_instruction		;write instruction to the LCD
	movlw	.3					;wait 2ms for instruction to be executed 
	goto	ms_delay

;cursor_home:
;	GLOBAL	cursor_home
;	movlw	b'00000010'			;return home command
;	call	lcd_instruction		;write instruction to the LCD
;	movlw	.2					;wait 2ms for instruction to be executed 
;	goto	ms_delay

cursor_pos_line1:
	GLOBAL	cursor_pos_line1
	addlw	b'10000000'			;cursor line 1 command
	goto	lcd_instruction		;write instruction to the LCD

cursor_pos_line2:
	GLOBAL	cursor_pos_line2
	addlw	b'11000000'			;cursor line 2 command
	goto	lcd_instruction		;write instruction to the LCD

lcd_clr_line1:
	GLOBAL	lcd_clr_line1
	movlw	.0
	call	cursor_pos_line1
	goto	_clr_line
lcd_clr_line2:
	GLOBAL	lcd_clr_line2
	movlw	.0
	call	cursor_pos_line2
_clr_line
	movlw	.16
	movwf	COUNT
	movlw	b'00100000';
	call	lcd_character
	decfsz	COUNT,F
	goto	$-3	
	return


; -------------------------------------------------------------
; Description: Outputs W as instruction to the LCD port
;
; Reg. IN	: W
; Reg. OUT	: -
; Reg. Changed	: LCD_PORT, TEMP
; -------------------------------------------------------------
setCGRAMaddress:
	GLOBAL	setCGRAMaddress
	movwf	LCD_TEMP
	bsf		LCD_TEMP,6
	bcf		LCD_TEMP,7
	movfw	LCD_TEMP

lcd_instruction:
	GLOBAL	lcd_instruction
;	call	checkBusy
	bcf		LCD_EN
	bcf		LCD_RS			;set RegisterSelect for instruction
	goto	_write

lcd_character:
	GLOBAL	lcd_character
;	call	checkBusy
	bcf		LCD_EN
	bsf		LCD_RS				;set RegisterSelect for character
_write:
	bcf		LCD_RW			
	movwf	LCD_TEMP

	bsf		LCD_EN
	clearLCDdatabits
	swapf	LCD_TEMP,W
	andlw	b'00001111'		;clear high nibble W
	iorwf	LCD_PORT,F
	bcf		LCD_EN

	bsf		LCD_EN
	clearLCDdatabits
	movfw	LCD_TEMP
	andlw	b'00001111'		;clear high nibble W
	iorwf	LCD_PORT,F
	bcf		LCD_EN

	movlw	.10				;wait 40uS
	call	us_delay
	return


checkBusy:
	bcf			LCD_RS			;select command registers
	bsf			LCD_BUSY		;init LCD busy flag

	Bank1
;	movlw		b'00011110'
	movlw		b'00001111'
	iorwf		LCD_TRIS,F		;set corresponding ports to inputs
	Bank0

	bsf			LCD_RW			;apply read direction
	nop							;additional safety
_LCDbusy:
	bsf			LCD_EN			;set enable

	; the following busy wait code makes busy flag signalling safe
	call		LCDbusyloop		;(timing relaxation)

	; poll now LCD busy flag
	btfss		LCD_PORT,D7		;check busy flag, skip if busy 
	bcf			LCD_BUSY		;set register flag if not busy
	bcf			LCD_EN

	; the following busy wait code makes busy flag signalling safe
	call		LCDbusyloop		;(timing relaxation)

	; get low nibble, ignore it
;	call		LCDclk
	bsf			LCD_EN
	nop
	bcf			LCD_EN

	btfsc		LCD_BUSY		;skip if register flag is not yet cleared
	goto		_LCDbusy

	bcf			LCD_RW			;re-apply write direction

	Bank1
;	movlw		b'11100001'
	movlw		b'11110000'
	andwf		LCD_TRIS,F	; set ports to output again
	Bank0
	return


	; busy wait loop, makes busy flag signalling safe
LCDbusyloop
	movlw		LCDBUSYWAIT		;pre-defined constant
	movwf		LCD_TEMP
_LCDbusyloop
	decfsz		LCD_TEMP,F
	goto		_LCDbusyloop	;busy loop
	return


; -------------------------------------------------------------
; Description	: Writes HEX number (< 255) to display
;
; Reg. IN	: W
; Reg. OUT	: -
; Reg. Changed	: VALUE
; -------------------------------------------------------------
displayHexNumber:
	GLOBAL	displayHexNumber
	movwf	VALUE
	swapf	VALUE,W
	call	hex_character
	movfw	VALUE
	call	hex_character
	movlw	'h'
	goto	lcd_character
;	return

hex_character
	andlw	b'00001111'
	movwf	LCD_TEMP
	sublw	.9
	btfss	STATUS,C
	goto	_hexNr	
	movfw	LCD_TEMP
	iorlw	0x30
	goto	lcd_character
;	return
_hexNr
	movfw	LCD_TEMP
	addlw	0x37
	goto	lcd_character
;	return


; -------------------------------------------------------------
; Description	: Writes number (< 255) to display
;
; Reg. IN	: W
; Reg. OUT	: -
; Reg. Changed	: VALUE
; -------------------------------------------------------------
displayNumber:
	GLOBAL	displayNumber
	movwf	VALUE
	clrf	COUNT
	movlw	.100
	subwf	VALUE,F
	btfss	STATUS,C
	goto	_displayHundreds
	incf	COUNT,F
	goto	$-4
_displayHundreds:
	addwf	VALUE,F
	movf	COUNT,W
	btfsc	STATUS,Z			;leading zero test
	goto	_tens
	iorlw	0x30
	call	lcd_character		;first character to lcd
	bsf		LEADINGZERO
_tens
	clrf	COUNT
	movlw	.10
	subwf	VALUE,F
	btfss	STATUS,C
	goto	_displayTens
	incf	COUNT,F
	goto	$-4	
_displayTens:
	addwf	VALUE,F
	movf	COUNT,W
	btfsc	STATUS,Z			;zero test
	goto	_tensZero
	iorlw	0x30
	call	lcd_character		;second character to lcd
	goto	_displayUnits
_tensZero:
;	btfsc	NOSPACE
;	goto	_displayUnits
	movlw	' '
	btfsc	LEADINGZERO
	movlw	'0'
	call	lcd_character
_displayUnits:
	movf	VALUE,W	
	iorlw	0x30
	call	lcd_character		;third character to lcd	
	return

; -------------------------------------------------------------
; Description	: Initialize the LCD display
;
; Reg. IN	: -
; Reg. OUT	: -
; Reg. Changed	: LCD_PORT, LCD_RS, LCD_RW, LCD_EN
; -------------------------------------------------------------
initDisplay:
	GLOBAL	initDisplay
	movlw	.15					;wait for LCD to settle after power up
	call	ms_delay			;15ms
	bcf		LCD_RS
	bcf		LCD_RW

	clearLCDdatabits
	movlw	b'00000011'			;lcd reset commands
	iorwf	LCD_PORT,F
	LCDEnable
	movlw	.5					;wait 5ms for LCD to settle
	call	ms_delay

	clearLCDdatabits
	movlw	b'00000011'			;reset
	iorwf	LCD_PORT,F
	LCDEnable
	movlw	.25					;wait 25 x 4us for LCD to settle
	call	us_delay

	clearLCDdatabits
	movlw	b'00000011'			;reset
	iorwf	LCD_PORT,F
	LCDEnable
	movlw	.10					;wait 10 x 4us for LCD to settle
	call	us_delay

	clearLCDdatabits
	movlw	b'00000010'			;function set, 4 bits interface
	iorwf	LCD_PORT,F
	LCDEnable
	movlw	.10					;wait 10 x 4us for LCD to settle
	call	us_delay

	movlw	b'00101000'			;"Function set" instruction
	call	lcd_instruction		;4bit, dual line, 5x8 dots

	movlw	b'00001000'			;"Display On/Off" instruction 
	call	lcd_instruction		;display off, cursor off, blink off

	call	lcd_clr				;"Clear Display" instuction

	movlw	b'00000110'			;"Entry mode set" instruction
	call	lcd_instruction		;increment, Display shift off

	movlw	b'00001100'			;"Display On/Off" instruction
	goto	lcd_instruction		;display on, cursor off, blink off


; -------------------------------------------------------------
	END
