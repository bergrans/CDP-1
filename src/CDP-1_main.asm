;******************************************************************************
; CD-Pro2M Controller                                                         *
; Filenaam: CD-Pro2M_main.ASM    (version for MPASM)                          *
;******************************************************************************
;
;   LAST MODIFICATION:  05.19.2008
;
;******************************************************************************
;   VERSION HISTORY                                                           *
;******************************************************************************
;
;   Version		Date		Remark
;	1.00		09/20/2006	Initial release
;	1.01		05/20/2007	Sensorless build option
;
;__ END VERSION HISTORY _______________________________________________________
;       
;   Development system used:    MPLAB with MPASM from Microchip
;==============================================================================
;	Include Files:	P16f871.INC	V1.00
;					CDP-1_IO.inc
;=============================================================================
;
;=============================================================================

	list p=16f871					;list directive to define processor
	#include <p16f871.inc>			;processor specific definitions
	#include <CDP-1_IO.inc>			;port definitions
	errorlevel -302					;suppress "not in bank 0" message

	variable debug = 0				;set when used with ICSP for debugging
	variable displayDSA = 0			;set to display all DSA response
	variable sensorless = 1			;set to build a sensorless (cover) version

	__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON &  _HS_OSC & _LVP_OFF & _DEBUG_OFF & _CPD_OFF


	if (sensorless == 1)
	   messg "You are building a Sensorless code version"
	endif


;----------------------------------------------------------------------------
; External routines & registers
;----------------------------------------------------------------------------
;P16_LCD.asm
	EXTERN	lcd_instruction, lcd_character, lcd_clr, lcd_clr_line1, lcd_clr_line2
	EXTERN	cursor_pos_line1, cursor_pos_line2, initDisplay, displayNumber, displayHexNumber
	EXTERN	LCD_FLAGS

;P16_EEPROM.asm
	EXTERN	read_EEPROM, write_EEPROM
	EXTERN	EEPROM_DATA

;DSA_protocol.asm
	EXTERN	receiveDSAresponse, sendDSACommand, waitForDSAresponce
	EXTERN	DSA_OPCODE, DSA_PARAM, DSA_RESPONSE_OPCODE, DSA_RESPONSE_PARAM

;LCD_strings.asm
	EXTERN	displayString, loadCustomCharacters


;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------
	CONSTANT	TIMEOUT_VAL		= .60		;value to tune timeout TMR0 to 10ms units
	CONSTANT	RC5_SYSTEM		= .20		;RC5 system number (20 for CD player)
	CONSTANT	SCAN_TIME		= .15		;Introscan time in seconds


;----------------------------------------------------------------------------
; I/O definitions
;----------------------------------------------------------------------------
;Port A setting  bit 5 - 0		-- -- out out out in in in
SET_PORTA		EQU		b'11000111'
INIT_PORTA		EQU		b'00000111'

;Port B setting  bit 7 - 0		-- in in in out out out in
SET_PORTB		EQU		b'11110001'
INIT_PORTB		EQU		b'00001110'

;Port C setting  bit 7 - 0		out out out out out in out out
SET_PORTC		EQU		b'00000100'
INIT_PORTC		EQU		b'00000000'

;Port D setting  bit 7 - 0		out out out out out out out out
SET_PORTD		EQU		b'00000000'
INIT_PORTD		EQU		b'00000000'

;Port E setting  bit 2 - 0		-- -- -- -- -- out in in
SET_PORTE		EQU		b'00000011'
INIT_PORTE		EQU		b'00000000'



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


main_var	UDATA_SHR	0x020
;----------------------------------------------------------------------------
; Variables
;----------------------------------------------------------------------------
COUNTER			res 1			;general counter register
TEMP			res 1			;general use register
FLAGS_0			res 1			;byte to store indicator flags
FLAGS_1			res 1			;byte to store indicator flags
RC5_FLAGS		res 1			;byte to store flags related to RC5 remote control
STATBUFFER		res 1
WBUFFER			res 1
KEYS			res 1			;status control keys
KEYS_RELEASED	res 1			;status control released keys
DISC_STATUS		res 1
TOC_STATUS		res 1
TIMEOUT_TIME	res 1			;time counter register
RC5L			res 1			;lower received byte
RC5H			res 1			;higher received byte
RC5L_BF			res 1			;lower received byte
RC5H_BF			res 1			;higher received byte
RC5_BITCOUNT	res 1			;counter for RC5
MIN_TITLE		res 1
MAX_TITLE		res 1
DISC_MINUTES	res 1
DISC_SECONDS	res 1
DISC_FRAMES		res 1
ACTUAL_TITLE	res 1
ACTUAL_MINUTES	res 1
ACTUAL_SECONDS	res 1
TITLE_LENGTH_L	res 1
TITLE_LENGTH_H	res 1
SET_TITLE		res 1
STRING			res 1			;string to be displayed
SPEED			res 1
ACTIONS			res	1
TIMEOUT_COUNT	res 1
DACMODE			res	1
DISC_INFO		res 1			;contains "Get Disc Status" data returned by CD-Pro2M
PROG_LENGTH		res 1			;length of programmed track list
PROG_POINTER	res 1			;pointer for the programmed track list

	GLOBAL	FLAGS_0

track_list	UDATA_SHR	0x0A0
TRACK_LIST		res 20			;list for programmed tracks (32 bytes A0h..BFh)

;----------------------------------------------------------------------------
; Bit definitions
;----------------------------------------------------------------------------
#define		LEADINGZERO			LCD_FLAGS,0		;bit indicates dispay leading zero on numbers

#define		RECEIVED_CR			FLAGS_0,0		;bit indicates <CR> character received
#define		EOS					FLAGS_0,1		;bit indicates End Of String
#define		POWER_SWITCH		FLAGS_0,2		;bit indicates state of the power switch
#define		TIMEOUT				FLAGS_0,3		;bit indicates timeout
#define		DATABIT				FLAGS_0,4		;bit indicates stare of the send/received databit
#define		COM_ERROR			FLAGS_0,5		;bit indicates DSA communication error
#define		DSA_RESPONCE		FLAGS_0,6		;bit indicates DSA responce received
#define		SEARCHTIMEOUT		FLAGS_0,7		;bit indicates search timeout

#define		REM_TIME			FLAGS_1,0		;bit indicates "remaining track time" is to be displayed

#define		RC5_TOGGLE			RC5_FLAGS,0		;bit indicates RC5 toggle bit
#define		RC5_TOGGLED			RC5_FLAGS,1		;bit indicates RC5 toggle bit has changed
#define		RC5_VALID			RC5_FLAGS,2		;bit indicates RC5 commans is valid
#define		RC5_RECEIVED		RC5_FLAGS,3		;bit indicates RC5 command is received
#define		RC5_FIRST			RC5_FLAGS,4		;bit indicates first RC5 command after power-up
#define		RC5_BIFACE			RC5_FLAGS,5		;bit indicates next RC5 sample is the biface (second) part of the bit.
#define		RC5_STARTED			RC5_FLAGS,6		;bit indicates RC5 bit-train has started

#define		PLAYING				DISC_STATUS,0
#define		PAUSED				DISC_STATUS,1
#define		INTROSCAN			DISC_STATUS,2
#define		SHUFFLE				DISC_STATUS,3
#define		REPEAT				DISC_STATUS,4
#define		SEARCHING_FWRD		DISC_STATUS,5
#define		SEARCHING_BWRD		DISC_STATUS,6
#define		PROGRAM				DISC_STATUS,7

#define		TOC_TITLE_MIN		TOC_STATUS,0	;bit indicates <minimum Track number of the CD> is set
#define		TOC_TITLE_MAX		TOC_STATUS,1	;bit indicates <miximum Track number of the CD> is set
#define		TOC_DISC_MINUTES	TOC_STATUS,2	;bit indicates <maximum time minutes of the CD> is set
#define		TOC_DISC_SECONDS	TOC_STATUS,3	;bit indicates <maximum time seconds of the CD> is set
#define		TOC_DISC_FRAMES		TOC_STATUS,4	;bit indicates <maximum time frames of the CD> is set
#define		TOC_VALID			TOC_STATUS,5	;bit indicates all TOC responses are set
#define		TOC_LOADING			TOC_STATUS,6	;bit indicates waiting for TOC values

#define		ACT_VALIDATE_TOC	ACTIONS,0		;bit indicates action "Validate TOC" needs to be executed
#define		ACT_PLAY			ACTIONS,1		;bit indicates action "Play" needs to be executed
#define		ACT_STOP			ACTIONS,2		;bit indicates action "Stop" needs to be executed
#define		ACT_REL_SEARCH		ACTIONS,3		;bit indicates action "Release Search" needs to be executed

#define		PLAY				2
#define		PAUSE				5
#define		STOP				1
#define		NEXT				7
#define		PREV				4
#define		SEARCH_FORWARD		3
#define		SEARCH_BACKWARD		0
#define		OPEN_CLOSE			6


;----------------------------------------------------------------------------
; EEPROM address definitions
;----------------------------------------------------------------------------
EE_DACMODE		EQU		0x00


DEEPROM CODE     ; boot the EEPROM memory
	DE	0x01,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


STARTUP	CODE					;place code at reset vector
; -------------------------------------------------------------
; Start code (This code executes when a reset occurs)
; -------------------------------------------------------------
	clrf    PCLATH				;select program memory page 0
	goto    init				;go to beginning of program
	nop
	nop

; -------------------------------------------------------------
; Routine:		0x0004 (interrupt start address)
; Description:	Interrupt Control, make backup of w and STATUS
;				-RB0  (INTCON,INTF) triggered by RC5 remote sensor
;				-TMR0 (INTCON,T0IF)
;				-TMR1 (PIR1,TMR1IF) used for RC5 bit sample timer (2,25ms)
;
; Reg. IN:		W, STATUS
; Reg. OUT:		W, STATUS
; Reg. Changed: WBUFFER, STATBUFFER, INTCON
; -------------------------------------------------------------
	movwf	WBUFFER					;backup w register
	swapf	STATUS,W				;swap to preserve zero flag
	movwf	STATBUFFER				;backup status register

	btfss	INTCON,INTE
	goto	_checkTMR1Int
	btfsc	INTCON,INTF
	goto	_RC5sync

_checkTMR1Int:
	Bank1
	btfss	PIE1,TMR1IE
	goto	_chechTMR2Int
	Bank0
	btfsc	PIR1,TMR1IF
	goto	_RC5timeout

_chechTMR2Int:
	btfss	PIE1,TMR2IE
	goto	_chechTMR0Int
	Bank0
	btfsc	PIR1,TMR1IF			;?
	goto	_searchTimeout

_chechTMR0Int:
	Bank0
	btfss	INTCON,T0IF
	goto	_endInt
	bcf		INTCON,T0IF			;clear the interrupt flag
	decf	TIMEOUT_TIME,F		;decrease the time counter
	btfss	STATUS,Z			;if zero timeout
	goto	_timeoutNext
	bsf		TIMEOUT				;set timeout flag
	bcf		INTCON,T0IE			;disable overflow interrupt
	goto	_endInt
_timeoutNext
	movlw	TIMEOUT_VAL			;reset timer 0
	movwf	TMR0
	goto	_endInt

_RC5timeout
	movlw	0x4E
	movwf	TMR1L					;reset Timer1 for a timeout of 0.890ms
	movlw	0xF7
	movwf	TMR1H

	btfsc	RC5_BIFACE
	goto	_RC5biface
	nop
	bcf		STATUS,C
	btfsc	RC5	
	bsf		STATUS,C
	rlf		RC5L,F
	rlf		RC5H,F
	bsf		RC5_BIFACE
	goto	_RC5timeoutEnd
_RC5biface:
	bcf		STATUS,C
	btfsc	RC5
	bsf		STATUS,C
	rlf		RC5L_BF,F
	rlf		RC5H_BF,F
	bcf		RC5_BIFACE
_RC5timeoutEnd:
	bcf		PIR1,TMR1IF				;clear Timer1 interrupt flag
	decfsz	RC5_BITCOUNT,F
	goto	_endInt
	Bank1
	bcf		PIE1,TMR1IE				;disable Timer1 interrupt
	Bank0
	bsf		RC5_RECEIVED
	goto	_endInt

_RC5sync
	movlw	0xC0					;sync Timer1 for a timeout of 435ms (halfway the bit period)
	movwf	TMR1L
	movlw	0xFB
	movwf	TMR1H

	btfsc	RC5_STARTED				;if RC5 bit-train has already started
	goto	_RC5syncEnd				;only sync the timer

	clrf	RC5H					;clear both RC5 receive registers
	clrf	RC5L					;
	movlw	.255					;
	movwf	RC5H_BF					;and set both RC5 biphase registers
	movwf	RC5L_BF					;

	bsf		RC5L,0					;set the first pahse of tye first start bit to "1"
	movlw	.27						;still 13.5 bits (27 bifase samples)
	movwf	RC5_BITCOUNT			;to go
	bsf		RC5_BIFACE				;first sample will be a bifase sample

	Bank1	
	bsf		PIE1,TMR1IE				;enable Timer1 interrupt
	Bank0
	bsf		INTCON,PEIE
	bsf		RC5_STARTED

_RC5syncEnd:
	bcf		PIR1,TMR1IF				;clear Timer1 interrupt flag
	bcf		INTCON,INTF				;clear the interrupt flag (RB0/INT = RC5 input)
	goto	_endInt

_searchTimeout:
	decfsz	TIMEOUT_COUNT,F
	goto	_nextSearchTimeout
	bsf		SEARCHTIMEOUT
	Bank1
	bcf		PIE1,TMR2IE			;disable TMR2 interrupt
	Bank0
	goto	_endInt

_nextSearchTimeout
	bcf		PIR1,TMR2IF
	clrf	TMR2

_endInt
	swapf	STATBUFFER,W		;restores the old status register
	movwf	STATUS
	swapf	WBUFFER,F			;swapf used to not change STATUS
	swapf	WBUFFER,W			;restores the old w register    
	bcf		INTCON,T0IF			;clear interrup flag     
	retfie


PROG1	CODE
; -------------------------------------------------------------
; Description:	Initialize and main routine
;
; Reg. IN: 
; Reg. OUT: 
; Reg. Changed: 
; -------------------------------------------------------------
init:
	clrf	FLAGS_0
	clrf	FLAGS_1
	clrf	DISC_STATUS
	clrf	ACTIONS
	clrf	RC5_FLAGS
	bsf		RC5_FIRST			;set flag to indicate that received command is fist after power up

	call	newDisc
	call	initRegisters
	call    initPorts

	bsf		LED_POWER			;turn on the power LED and sensors
	bsf		MAINS_CDPRO			;turn on mains on CD-Pro transformer

	call	initDisplay

	movlw	0x38				;send "trade string" to LCD (see LCD_stings.asm)
 	call	displayString		;line.position 1.0

	movlw	.250				;
	call	ms_delay			;
	movlw	.250				;
	call	ms_delay			;wait a total of 600ms, after turn on the
	movlw	.75					;CD-Pro mains, to let the supply voltages
	call	ms_delay			;stabilize and turning on CD-Pro 5V
	bsf		RELAY_5V_CDPro

	movlw	.150				;wait another 150ms before
	call	ms_delay			;turning on CD-Pro servo-supply (9V)
	bsf		RELAY_9V_CDPro

	bsf		LASER_OFF			;turn laser on

	call	loadCustomCharacters

	bcf		INTCON,INTF			;clear the interrupt flag (RB0/INT = RC5 input)
	bsf		INTCON,INTE			;enable RBO/INT interrupt
	bsf		INTCON,GIE			;enable the Global Interrupts Enable

	call	readKeyboard
	btfsc	KEYS,STOP			;if "STOP" key is pushed during startup
	goto	playerSetup			;program will enter setup mode
	
	movlw	EE_DACMODE			;DAC mode
	call	read_EEPROM
	movwf	DACMODE
	sublw	.1					;if DAC mode is "1" (default)
	btfsc	STATUS, Z			;
	goto	_skipDACmode		;skip setting the DAC mode
	movlw	0x70				;opcode "Set DAC mode"
	movwf	DSA_OPCODE
	movfw	DACMODE				;parameter "mode"
	movwf	DSA_PARAM
	call	sendDSACommand
	call	waitForDSAresponce

_skipDACmode
	if sensorless == 0
		btfss	COVER_CLOSED		;if cover is closed
		goto	_fireUp
		bsf		LED_LIGHT			;turn on the LED lighting
		goto	main
	endif

_fireUp:
	call	readTOC				;spin-up the disc, read TOC and
	bsf		ACT_PLAY			;start playing

main:
	call	readKeyboard

	if debug == 1				;when using the the ICD2 for debugging
		bcf		KEYS,2			;RB6 (COL3) can't be used for keyboard readout.
		bcf		KEYS,5
		bcf		POWER_SWITCH
	endif

	btfsc	KEYS,PLAY
	call	manPlayTitle
	btfsc	KEYS,PAUSE
	call	manPauseDisc
	btfsc	KEYS,STOP
	call	manStopDisc
	btfsc	KEYS,NEXT
	call	manNextTitle
	btfsc	KEYS,PREV
	call	manPrevTitle
	btfsc	KEYS,SEARCH_FORWARD
	call	searchForward
	btfsc	KEYS,SEARCH_BACKWARD
	call	searchBackward
	btfsc	KEYS,OPEN_CLOSE
	call	manMoveCover
	btfsc	POWER_SWITCH
	goto	standby

	btfsc	RC5_RECEIVED		;if remote command received
	call	validateRC5command	;check if this is valid
	btfsc	RC5_VALID			;if so
	call	RC5_commandTable	;execute remote command

	movf	ACTIONS,F			;
	btfss	STATUS,Z			;check if there are any actions
	call	actionsHandler		;if so execute them

	btfss	DSA_DDA				;check DSA dataline for request from CD-Pro
	call	receiveDSAresponse	;if so receive DSA response

	btfss	DSA_RESPONCE		
	goto	main

	call	DSAResponseTable
	if displayDSA == 1			;display all DSA responses for debug
		movlw	.9
		call	cursor_pos_line1
		movfw	DSA_RESPONSE_OPCODE
		call	displayHexNumber
		movlw	':'
		call	lcd_character
		movfw	DSA_RESPONSE_PARAM
		call	displayHexNumber
	endif
	goto	main


; -------------------------------------------------------------
; Description: Action handler executes action which are requested
;				(set) in the ACTIONS register
;
; Reg. IN:		ACTIONS
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
actionsHandler:
	btfsc	ACT_VALIDATE_TOC
	call	actionValidateTOC

	btfsc	ACT_PLAY
	call	actionPlay

	btfsc	ACT_STOP
	call	actionStop
	
	btfsc	ACT_REL_SEARCH
	call	actionReleaseSearch

;	Room for other actions

	return

actionValidateTOC:
	movlw	b'00011111'
	andwf	TOC_STATUS,F		;clear upper 3 "non"TOC response bits
	xorwf	TOC_STATUS,W		;check if all five "readTOC" responses (20h ...24h) are received
	btfss	STATUS,Z
	return

	bsf		TOC_VALID			;mark TOC as valid		
	bcf		ACT_VALIDATE_TOC	;clear action bit

	movlw	0x50				;opcode "Get Disc Status"
	movwf	DSA_OPCODE
	call	sendDSACommand
	call	waitForDSAresponce	

	btfsc	ACT_PLAY
	return
	goto	displayDiscInfo
;	return

actionPlay:
	goto	_playTitle	
;	return

actionStop:
	btfss	TOC_VALID
	return
	goto	_stopDisc
;	return

actionReleaseSearch
	btfss	SEARCHTIMEOUT
	return

	bcf		ACT_REL_SEARCH
	bcf		SEARCHING_FWRD
	bcf		SEARCHING_BWRD
	movlw	0x08				;opcode "Search Release"
	movwf	DSA_OPCODE			;parameter XX
	goto	sendDSACommand
;	return


; -------------------------------------------------------------
; Description: Put player in standby mode
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
standby:
	bcf		LED_POWER			;turn off the power LED and sensors
	movlw	b'00001000'			;"Display On/Off" instruction 
	call	lcd_instruction		;display off, cursor off, blink off

	btfss	PLAYING
	goto	powerDown
	call	_stopDisc
	call	waitForDSAresponce

powerDown:
	bcf		LED_LIGHT			;turn off the LED lighting
	bcf		RELAY_9V_CDPro		;turn off the CD-Pro2M 9V
	movlw	.250				;
	call	ms_delay			;wait another 250ms
	bcf		RELAY_5V_CDPro		;before turning off CD-Pro 5V and
	bcf		MAINS_CDPRO			;mains on CD-Pro transformer

	bsf		KEY_ROW_1			;
	bsf		KEY_ROW_2			;
	bcf		KEY_ROW_3			;
	btfsc	KEY_COL_3			;
	goto	goToSleep				;wait till the POWER is released
	goto	$-2					;

goToSleep:
	movlw	.250				;
	call	ms_delay			;wait another 250ms
	btfsc	KEY_COL_3			;before checking the POWER button
	goto	$-1					;

	clrf	INTCON				;disable all interrups
	bsf		INTCON, GIE

	movlw	.10					;load 100ms
	call	startTimeout		;start timeout timer
_powerUpLoop
	btfsc	KEY_COL_3			;checking the POWER button
	goto	goToSleep			;if released return to sleep
	btfsc	TIMEOUT				;powerup after timeout
	goto	init
	goto	_powerUpLoop


; -------------------------------------------------------------
; Description: Clears all disc related registers when loading a new disc.
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
newDisc:
	clrf	TOC_STATUS
	clrf	SET_TITLE
	clrf	ACTUAL_TITLE
	clrf	MIN_TITLE
	clrf	MAX_TITLE
	clrf	DISC_MINUTES
	clrf	DISC_SECONDS
	clrf	DISC_FRAMES
	clrf	PROG_LENGTH

	call	clearProgramList
	return


; -------------------------------------------------------------
; Description: Clears program list RAM area (0h0A0...0h0BF)
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: COUNTER, FSR
; -------------------------------------------------------------
clearProgramList:
	movlw	.32
	movwf	COUNTER
	movlw	TRACK_LIST
	movwf	FSR
_clearProgramLoop:
	clrf	INDF
	incf	FSR,F
	decfsz	COUNTER,F
	goto	_clearProgramLoop
	return


; -------------------------------------------------------------
; Description: Setup for setting DAC mode
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
playerSetup:
	call	lcd_clr

	movlw	0x66				;send "Set DAC mode:" to LCD (see LCD_stings.asm)
 	call	displayString		;line.position 1.0

	movlw	EE_DACMODE			;DAC mode
	call	read_EEPROM
	movwf	DACMODE

_displayDACvalue
	movlw	.13
	call	cursor_pos_line1
	bcf		LEADINGZERO
	movfw	DACMODE
	call	displayNumber

_loopSetup:
	call	readKeyboard
	btfsc	KEYS,NEXT
	goto	_incDACmode
	btfsc	KEYS,PREV
	goto	_decDACmode
	btfsc	KEYS,OPEN_CLOSE
	goto	_store
	goto	_loopSetup

_incDACmode:
	btfss	KEYS_RELEASED,NEXT
	goto	_loopSetup

	movlw	.9
	subwf	DACMODE,W
	btfss	STATUS,C
	incf	DACMODE,F
	goto	_displayDACvalue

_decDACmode:
	btfss	KEYS_RELEASED,PREV
	goto	_loopSetup

	decf	DACMODE,W
	btfss	STATUS,Z
	movwf	DACMODE
	goto	_displayDACvalue

_store:
	movfw	DACMODE
	movwf	EEPROM_DATA
	movlw	EE_DACMODE
	call	write_EEPROM
	goto	init


; -------------------------------------------------------------
; Description: Opens/Closes the players cover
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
manMoveCover:
	if sensorless == 0			;in the sensorless version the open/close button is completely ignored
		btfss	KEYS_RELEASED,OPEN_CLOSE
	endif
	return
	goto	moveCover

rcMoveCover:
	if sensorless == 0			;in the sensorless version the open/close button is completely ignored
		btfss	RC5_TOGGLED
	endif
	return

moveCover:
	bcf		MOTOR_DIR
	bcf		MOTOR_ENABLE

	btfsc	COVER_CLOSED		;if cover is not closed
	goto	closeCover			;then close
								;else open
	movlw	0x02				;opcode "Stop" parameter xx
	movwf	DSA_OPCODE
	call	sendDSACommand
	call	waitForDSAresponce

	clrf	ACTIONS				;abort all actions

	call	lcd_clr				;clear the display
	movlw	0x56				;send "Opening" to LCD (see LCD_stings.asm)
	call	displayString

	bsf		MOTOR_DIR			;set motor direction to CW (open)
	goto	_move

closeCover:
	bcf		LED_LIGHT			;turn off the LED lighting
	bcf		MOTOR_DIR			;set motor direction to CCW (close)
	bsf		MOTOR_ENABLE

	call	lcd_clr
	movlw	0x5E				;send "Closing" to LCD (see LCD_stings.asm)
	call	displayString

_move:
	btfss	MOTOR_DIR			;check direction
	goto	_testIfClosed		;if closing check if "closed" endswitch
	btfsc	COVER_OPEN			;if opening check if "opened" endswitch
	goto	_move
	goto	_endMove			;end movement at if sensor is activated
_testIfClosed
	btfsc	COVER_CLOSED
	goto	_move

_endMove
	bsf		MOTOR_DIR			;hit the brake
	bsf		MOTOR_ENABLE		;

	call	lcd_clr	

	btfss	COVER_CLOSED
	goto	_isClosed
	btfsc	COVER_OPEN
	return

_isOpen:
	movlw	0x24				;send "Insert disc" to LCD (see LCD_stings.asm)
	call	displayString
	call	clearTOC
	bsf		LED_LIGHT			;turn on the LED lighting
	return

_isClosed:
	movlw	0x49				;send "Reading disk" to LCD (see LCD_stings.asm)
 	call	displayString		;line.position 1.0
	call	readTOC				;spin-up the disc and read TOC when closed
	btfss	ACT_PLAY
	bsf		ACT_STOP
	return

; -------------------------------------------------------------
; Description: Actions
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
manPlayTitle:
	btfss	KEYS_RELEASED,PLAY
	return
	goto	_playTitle
playTitle:
	btfss	RC5_TOGGLED
	return

_playTitle:
	if sensorless == 0
		btfss	COVER_CLOSED
		goto	_playTitleClosed
		bsf		ACT_PLAY			;start to play when cover is closed
		goto	closeCover
_playTitleClosed:
	endif

	btfss	ACT_VALIDATE_TOC	;if TOC read is not completed
	goto	_playTitleTOCcheck
	bsf		ACT_PLAY			;set PLAY action bit
	bcf		ACT_STOP			;and clear STOP action bit

	if sensorless == 1
		return
	endif

_playTitleTOCcheck:

	if sensorless == 0
		btfss	TOC_VALID
		return	
	else
		bsf		ACT_PLAY
		btfsc	TOC_VALID
		goto	_playTitle_sensorless
		call	lcd_clr				;clear the display	
		movlw	0x49				;send "Reading disk" to LCD (see LCD_stings.asm)
	 	call	displayString		;line.position 1.0
		goto	readTOC				;spin-up the disc and read TOC
_playTitle_sensorless:
	endif

	bcf		ACT_PLAY			;clear action "play" bit

	btfss	PROGRAM
	goto	_playThatTitle

	movlw	0x15				;opcode "Set mode"
	movwf	DSA_OPCODE
	movlw	b'01100001'			;speed=1, mode=audio, ATTI=10b, pause at track-end=1
	movwf	DSA_PARAM
	call	sendDSACommand

	movlw	TRACK_LIST			;set pointer to first track
	movwf	PROG_POINTER		;of the program list
	movwf	FSR
	movfw	INDF
	movwf	SET_TITLE

_playThatTitle:
	movfw	SET_TITLE
	subwf	ACTUAL_TITLE,W
	btfss	STATUS,Z
	goto	_play		
	btfsc	PAUSED				;if new title(SET_TITLE) is equal to actual title
	goto	_pauseDisc			;release PAUSE if PAUSED
	return						;or ignore PLAY if already PLAYING
_play:
	btfss	PLAYING
	call	lcd_clr

	movlw	0x01				;opcode "Play Title"
	movwf	DSA_OPCODE
	movfw	SET_TITLE			;parameter track nr
	movwf	DSA_PARAM
	call	sendDSACommand
	goto	displayAction
;	return

; -------------------------------------------------------------	
manPauseDisc:
	btfss	KEYS_RELEASED,PAUSE
	return
	goto	_pauseDisc
rcPauseDisc:
	btfss	RC5_TOGGLED
	return
_pauseDisc:
	btfss	TOC_VALID
	return

	movlw	0x04				;opcode "Pause"
	movwf	DSA_OPCODE
	btfsc	PAUSED
	incf	DSA_OPCODE,F		;opcode "Pause Realease"
	movlw	0x00				;parameter xx
	movwf	DSA_PARAM
	goto	sendDSACommand
;	return

; -------------------------------------------------------------
manStopDisc:
	btfss	KEYS_RELEASED,STOP
	return
	goto	_stopDisc
stopDisc:
	btfss	RC5_TOGGLED
	return
_stopDisc:
	btfss	TOC_VALID
	return

	bcf		ACT_STOP			;clear action "stop" bit

	movlw	0x02				;opcode "Stop"
	movwf	DSA_OPCODE
	movlw	0x00				;parameter xx
	movwf	DSA_PARAM
	call	sendDSACommand
	call	waitForDSAresponce
	
	if	sensorless == 1
		clrf	ACTIONS				;abort all actions
		call	lcd_clr				;clear the display
		movlw	0x24				;send "Insert disc" to LCD (see LCD_stings.asm)
		call	displayString
		movlw	.250				;
		call	ms_delay			;wait 250ms
		movlw	.250				;
		call	ms_delay			;wait 250ms
		goto	clearTOC
	endif

	goto	displayDiscInfo
;	return

; -------------------------------------------------------------
manNextTitle:
	btfss	KEYS_RELEASED,NEXT
	return
	goto	_playNextTitle
playNextTitle:
	btfss	RC5_TOGGLED
	return
_playNextTitle:
	if sensorless == 0
	btfsc	COVER_CLOSED		;ignore
	return						;when cover not closed
	endif
	btfss	TOC_VALID			;or
	return						;TOC is not valid
;
	btfsc	PLAYING
	btfss	PROGRAM
	goto	_playNextCheck
	incf	PROG_POINTER, F
	movfw	PROG_POINTER
	movwf	FSR
	movfw	INDF
	movwf	SET_TITLE
	goto	_playNextNow
;
_playNextCheck:
	movfw	MAX_TITLE
	subwf	SET_TITLE,W
	btfsc	STATUS,Z			;skip if actual title is equal max title
	return
	incf	SET_TITLE,F

_playNextNow:
	movlw	.6
	call	cursor_pos_line2
	movfw	SET_TITLE
	bcf		LEADINGZERO
	call	displayNumber
	btfss	PLAYING
	btfss	PROGRAM
	goto	_play
	return

; -------------------------------------------------------------
manPrevTitle:
	btfss	KEYS_RELEASED,PREV
	return
	goto	_playPrevTitle
playPrevTitle:
	btfss	RC5_TOGGLED
	return
_playPrevTitle:
	if sensorless == 0
	btfsc	COVER_CLOSED		;ignore
	return						;when cover not closed
	endif
	btfss	TOC_VALID			;or
	return						;TOC is not valid

	movf	SET_TITLE,F
	btfsc	STATUS,Z			;if actual track is '0'
	return						;return

	decf	SET_TITLE,W
	btfsc	STATUS,Z			;if actual track is '1'
	goto	_playPrev			;restart the track

	movwf	SET_TITLE
	btfsc	PROGRAM
	goto	_playPrev
	movf	ACTUAL_MINUTES,F
	btfsc	STATUS,Z			;if "minutes" == 0
	goto	_checkSeconds		;check "seconds"
	incf	SET_TITLE,F			;else restart actual track
	goto	_playPrev
_checkSeconds
	movf	ACTUAL_SECONDS,F	;if actual time <0:01
	btfss	STATUS,Z			;play previous track
	incf	SET_TITLE,F			;else restart actual track

_playPrev:
	movf	SET_TITLE,F
	btfsc	STATUS,Z
	return

	movlw	.6
	call	cursor_pos_line2
	movfw	SET_TITLE
	bcf		LEADINGZERO
	call	displayNumber
	btfss	PROGRAM
	goto	_play
	return

; -------------------------------------------------------------
searchForward:
	btfss	PLAYING
	return

	btfsc	SEARCHING_FWRD
	goto	startSearchTimeout	;start the timeout timer

	bsf		ACT_REL_SEARCH		;set action "release search" bit
	bsf		SEARCHING_FWRD
	bcf		SEARCHING_BWRD
	movlw	0x06				;opcode "Search forward at low speed, with Border flag cleared"
	movwf	DSA_OPCODE
	movlw	0x00				;parameter 00
	movwf	DSA_PARAM
	call	sendDSACommand
	goto	startSearchTimeout	;start the timeout timer

; -------------------------------------------------------------
searchBackward:
	btfss	PLAYING
	return

	btfsc	SEARCHING_BWRD
	goto	startSearchTimeout	;(re)start the timeout timer

	bsf		ACT_REL_SEARCH		;set action "release search" bit
	bcf		SEARCHING_FWRD
	bsf		SEARCHING_BWRD
	movlw	0x07				;opcode "Search backward at low speed, with Border flag cleared"
	movwf	DSA_OPCODE
	movlw	0x00				;parameter 00
	movwf	DSA_PARAM
	call	sendDSACommand
	goto	startSearchTimeout	;start the timeout timer

; -------------------------------------------------------------
repeatDisc:
	btfss	RC5_TOGGLED
	return
_repeatDisc:
	btfss	TOC_VALID
	return
	btfss	PLAYING				;don't set/clear repeat flag when not playing
	return
	btfsc	REPEAT
	goto	_releaseRepeat
	bsf		REPEAT
	goto	displayAction
;	return
_releaseRepeat:
	bcf		REPEAT
	goto	displayAction
;	return

; -------------------------------------------------------------
programDisc
	btfss	RC5_TOGGLED
	return
	btfss	TOC_VALID
	return
	btfsc	PLAYING
	return

	btfsc	PROGRAM
	goto	_nextTrackProgram

	bsf		PROGRAM
	clrf	PROG_LENGTH
	clrf	SET_TITLE
;	movlw	TRACK_LIST			;set pointer to first track
;	movwf	PROG_POINTER		;of the program list

_nextTrackProgram:
	call	lcd_clr_line1
	movlw	.0
	call	cursor_pos_line1
	movlw	0x74				;send "Program" to LCD (see LCD_stings.asm)
	call	displayString
	movlw	' ';
	call	lcd_character

	movf	SET_TITLE, F
	btfsc	STATUS, Z
	goto	_clearTrackNr
	movlw	TRACK_LIST
	addwf	PROG_LENGTH,W
	movwf	FSR
	movfw	SET_TITLE
	movwf	INDF
	incf	PROG_LENGTH,F
	clrf	SET_TITLE

	movfw	PROG_LENGTH
	bcf		LEADINGZERO
	call	displayNumber

_clearTrackNr:
	call	lcd_clr_line2
	movlw	.0
	call	cursor_pos_line2
	movlw	0x0B				;send "track" to LCD (see LCD_stings.asm)
	call	displayString

	movlw	' ';
	call	lcd_character
	movlw	'-';
	call	lcd_character
	movlw	'-';
	call	lcd_character

	return
	
; -------------------------------------------------------------
introScan:
	btfss	RC5_TOGGLED
	return

	btfsc	INTROSCAN
	goto	_releaseIntroScan

	bsf		INTROSCAN
	btfsc	PLAYING
	goto	displayAction		;refresh display if already PLAYING
	goto	_playTitle			;else start PLAYING 

_releaseIntroScan:
	bcf		INTROSCAN
	goto	displayAction

; -------------------------------------------------------------
timeMode:
	btfss	RC5_TOGGLED
	return
	btfsc	REM_TIME
	goto	_releaseRemainingTime

	movlw	.20
	subwf	ACTUAL_TITLE,W		;if actual title is >=20
	btfsc	STATUS,C			;remaining time can't be displayed (CD-Pro2M restriction)
	return						;so return
	bsf		REM_TIME			;if <20 set flag and request track time
	movlw	0x09				;opcode "Get title length"
	movwf	DSA_OPCODE
	movfw	ACTUAL_TITLE		;parameter "track number"
	movwf	DSA_PARAM
	call	sendDSACommand
	return
_releaseRemainingTime:
	bcf		REM_TIME
	return

; -------------------------------------------------------------
shuffleDisc:
	nop
	return

; -------------------------------------------------------------
rcKey_0:
	movlw	.10
	goto	handleRemoteKeys
rcKey_1:
	movlw	.1
	goto	handleRemoteKeys
rcKey_2:
	movlw	.2
	goto	handleRemoteKeys
rcKey_3:
	movlw	.3
	goto	handleRemoteKeys
rcKey_4:
	movlw	.4
	goto	handleRemoteKeys
rcKey_5:
	movlw	.5
	goto	handleRemoteKeys
rcKey_6:
	movlw	.6
	goto	handleRemoteKeys
rcKey_7:
	movlw	.7
	goto	handleRemoteKeys
rcKey_8:
	movlw	.8
	goto	handleRemoteKeys
rcKey_9:
	movlw	.9
	goto	handleRemoteKeys

handleRemoteKeys:
	btfss	RC5_TOGGLED
	return
	btfss	TOC_VALID
	return
	movwf	SET_TITLE
	subwf	MAX_TITLE, W
	btfsc	STATUS, C			;return if set title is > max title (highest track on the disc)
	goto	_play
	movfw	ACTUAL_TITLE		;reload actual title to set title
	movwf	SET_TITLE	
	return

; -------------------------------------------------------------
readTOC:
	movlw	0x03				;opcode "Read TOC"
	movwf	DSA_OPCODE
	movlw	0x00				;parameter 00
	movwf	DSA_PARAM
	call	sendDSACommand

	clrf	TOC_STATUS
	bsf		ACT_VALIDATE_TOC	;set "action" for action handler
	return

; -------------------------------------------------------------
clearTOC
	call	newDisc

	movlw	0x6A				;opcode "Clear TOC"
	movwf	DSA_OPCODE
	goto	sendDSACommand
;	return


; -------------------------------------------------------------
; Description:	Start timeout counter in given W x 10ms
;			 	TIMEOUT flag indicates if timeout has occurt,
;			 	this flag is set during TMR0 overflow interrupt.
;
;				This timeout timer is used during DSA communication.
;
; Reg. IN:		W (timeout x 10ms)
; Reg. OUT:		-
; Reg. Changed: TMR0, INTCON
; -------------------------------------------------------------
startTimeout:
	GLOBAL	startTimeout
	bcf		TIMEOUT				;clear timeout flag
	movwf	TIMEOUT_TIME		;set timeout time
	movlw	TIMEOUT_VAL			;load 10ms timeout value (constant)
	movwf	TMR0
	bcf		INTCON,T0IF			;clear TMR0 interrupt flag
	bsf		INTCON,T0IE			;enable TMR0 interrupt
	return

endTimeout:
	GLOBAL	endTimeout
	bcf		INTCON,T0IE			;disable TMR0 interrupt
	return


; -------------------------------------------------------------
; Description:	Start timeout counter for the search functions
;
;		TMR2 is used to generate a timeout after 125ms (max timeout TMR2 is about 26ms)
;		Timeout is tuned to 25ms by loading 0xF3 (243) into the compare register PR2.
;		After 5 (TIMEOUT_COUT) timeouts  the timeout flag is set (in the interrupt routine)
;
;		1/(Focs/4) * prescale * PR2 * postscale = Timeout
;		 1/2.5Mhz  *    16    * 243 *    16     = 24.883ms
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
startSearchTimeout:
	bcf		SEARCHTIMEOUT		;clear timeout flag
	movlw	.5
	movwf	TIMEOUT_COUNT
	clrf	TMR2
	bcf		PIR1,TMR2IF			;clear TMR0 interrupt flag
	Bank1
	movlw	0xF3
	movwf	PR2
	bsf		PIE1,TMR2IE			;enable TMR0 interrupt
	Bank0
	bsf		INTCON,PEIE
	return

endSearchTimeout:
	Bank1
	bcf		PIE1,TMR2IE			;disable TMR0 interrupt
	Bank0
	return


; -------------------------------------------------------------
; Description: Display Error #
;
; Reg. IN:		W (error code)
; Reg. OUT:		-
; Reg. Changed: -
; -------------------------------------------------------------
displayError:
	GLOBAL	displayError
	movwf	TEMP
	call	lcd_clr
	movlw	'E'
	call	lcd_character
	movlw	'-'
	call	lcd_character
	movfw	TEMP
	call	displayHexNumber	
	return


; -------------------------------------------------------------
; Description: Read frontpanel control buttons
;
; Reg. IN:		-
; Reg. OUT:		KEYS, FLAGS(POWER_SWITCH)
; Reg. Changed: PORTB
; -------------------------------------------------------------
readKeyboard:
	comf	KEYS,W
	movwf	KEYS_RELEASED
	call	_scanKeys
	movf	KEYS,F
	btfss	STATUS,Z		;check for zero (no keys pressed)
	goto	_rescan			;rescan for for switch debounce
	btfss	POWER_SWITCH
	return					;return if no keys are pressed
_rescan:
	movfw	KEYS
	movwf	TEMP			;store key status
	movlw	.5				;wait 5ms for instruction to be executed 
	call	ms_delay
	call	_scanKeys
	movfw	TEMP
	andwf	KEYS,F
	return
	
_scanKeys:
	bcf		POWER_SWITCH
	clrf	KEYS
	bcf		KEY_ROW_1
	bsf		KEY_ROW_2
	bsf		KEY_ROW_3

	btfss	KEY_COL_1
	bsf		KEYS,0
	btfss	KEY_COL_2
	bsf		KEYS,1
	btfss	KEY_COL_3
	bsf		KEYS,2

	bsf		KEY_ROW_1
	bcf		KEY_ROW_2

	btfss	KEY_COL_1
	bsf		KEYS,3
	btfss	KEY_COL_2
	bsf		KEYS,4
	btfss	KEY_COL_3
	bsf		KEYS,5

	bsf		KEY_ROW_2
	bcf		KEY_ROW_3

	btfss	KEY_COL_1
	bsf		KEYS,6
	btfss	KEY_COL_2
	bsf		KEYS,7
	btfss	KEY_COL_3
	bsf		POWER_SWITCH

	bsf		KEY_ROW_3
	return

; -------------------------------------------------------------
; Description:	It gives a one milliseconds delay according to the value of W 
;				delay = 1 * W mSec (10MHz clock)
;
; Reg. IN:		W
; Reg. OUT:		-
; Reg. Changed: W, status, timer
; -------------------------------------------------------------
ms_delay:
	GLOBAL	ms_delay
	movwf	COUNTER
_ms_delay:
	movlw	.250
	call	us_delay
	decf	COUNTER,F
	btfss	STATUS,Z
	goto	_ms_delay
	return

; -------------------------------------------------------------
; Description:	It gives a variable delay according to the value of W register:
;				delay = 4 * W uSec (10MHz clock)
;				Note that the value 0 of delay correspondes to 256. 
;
; Reg. IN	: W
; Reg. OUT	: -
; Reg. Changed	: W, STATUS
; -------------------------------------------------------------
us_delay:
	GLOBAL	us_delay
	sublw	0
_us_delay:
	addlw	1
	nop
	nop
	nop
	nop
	nop
	nop
	btfss	STATUS,Z
	goto	_us_delay
	return


; -------------------------------------------------------------
; Description:  Validate the 14 received bits from the (RC5) remote control
;
; Reg. IN:		RC5H, RC5L
; Reg. OUT:		RC5_VALID(bit), RC5_TOGGLED(bit), RC5L(command)
; Reg. Changed: RC5H, RC5L, TEMP, RC5_FLAGS
; -------------------------------------------------------------
validateRC5command:
	bcf		RC5_VALID				;clear "valid RC5 command" flag
	
	comf	RC5H,W					;
	xorwf	RC5H_BF,W				;check if the bifase bit states
	btfss	STATUS,Z				;are complementary (upper byte)
	goto	_resetRC5				;
	comf	RC5L,W					;
	xorwf	RC5L_BF,W				;check if the bifase bit states
	btfss	STATUS,Z				;are complementary (lower byte)
	goto	_resetRC5				;

	btfss	RC5H,5					;check S1 (startbit)
	goto	_resetRC5				;invalid command exit
	btfss	RC5H,4					;check S2 (startbit)
	goto	_resetRC5				;invalid command exit

	rlf		RC5L,F					;
	rlf		RC5H,F					;
	rlf		RC5L,F					;split RC5 sting
	rlf		RC5H,F					;S1, S2, Toggle and System to RC5H
	bcf		STATUS,C				;Command to RC5L
	rrf		RC5L,F					;
	bcf		STATUS,C				;
	rrf		RC5L,F					;

	movfw	RC5H					;
	andlw	b'00011111'				;
	sublw	RC5_SYSTEM				;check for valid System (CD player)
	btfss	STATUS,Z				;
	goto	_resetRC5				;invalid command exit

_checkRange
	movlw	b'11000000'				;
	andwf	RC5L,W					;check if command is within the range 0..63
	btfss	STATUS,Z				;
	goto	_resetRC5				;invalid command exit

	bsf		RC5_VALID				;set "valid RC5 command" flag

	bcf		RC5_TOGGLED				;
	btfss	RC5_TOGGLE				;
	goto	_toggleWasLow			;
	btfss	RC5H,5					;check if Toggle bit has toggled
	bsf		RC5_TOGGLED				;
	goto	_copyToggleBit			;
_toggleWasLow						;
	btfsc	RC5H,5					;
	bsf		RC5_TOGGLED				;
_copyToggleBit
	bcf		RC5_TOGGLE				;
	btfsc	RC5H,5					;set toggle flag to togglebits status
	bsf		RC5_TOGGLE				;

	btfsc	RC5_FIRST				;if this is the first valid command
	bsf		RC5_TOGGLED				;force "toggled" flag
	bcf		RC5_FIRST				;clear the "first" flag

_resetRC5:
	bcf		RC5_RECEIVED			;clear "received" flag
	bcf		INTCON,INTF				;clear RB0 interrupt flag
;	bsf		INTCON,INTE				;enable RB0 interrupt
	bcf		RC5_STARTED
	return


; -------------------------------------------------------------
; Description	: Displays the "action" line (Play, Pause ...) incl. status introscan
;
; Reg. IN	: -
; Reg. OUT	: -
; Reg. Changed	: -
; -------------------------------------------------------------
displayAction:
	call	lcd_clr_line1
	movlw	.0
	call	cursor_pos_line1

	movlw	0x00				;send "Play" to LCD (see LCD_stings.asm)
	btfsc	PAUSED
	movlw	0x05				;send "Pause" to LCD (see LCD_stings.asm)
	call	displayString

	btfss	INTROSCAN
	goto	_skipDisplayIntro

	movlw	' '
	call	lcd_character
	movlw	0x1E				;send "intro" to LCD (see LCD_stings.asm)
	call	displayString

_skipDisplayIntro:
	btfss	REPEAT
	return
	movlw	.14
	call	cursor_pos_line1
	movlw	0x00
	call	lcd_character		;display custom defined character 0 (arrow right)
	movlw	0x01
	call	lcd_character		;display custom defined character 1 (arrow left)
	return


; -------------------------------------------------------------
; Description	: Displays disc info (number of tracks and total disc time)
;
; Reg. IN	: -
; Reg. OUT	: -
; Reg. Changed	: -
; -------------------------------------------------------------
displayDiscInfo:
	call	lcd_clr
	movlw	0x19				;send "Disc" to LCD (see LCD_stings.asm)
	call	displayString

	if debug == 1
		movlw	' '
		call	lcd_character
		movlw	.8
		btfsc	DISC_INFO,2
		addlw	.4
		bcf		LEADINGZERO
		call	displayNumber
		movlw	'c'
		call	lcd_character
		movlw	'm'
		call	lcd_character
	endif

	movlw	.0
	call	cursor_pos_line2
	movfw	MAX_TITLE
	bcf		LEADINGZERO
	call	displayNumber
	movlw	' '
	call	lcd_character
	movlw	0x0B				;send "track" to LCD (see LCD_stings.asm)
	call	displayString
	movlw	's'
	call	lcd_character

	movlw	.11
	call	cursor_pos_line2

	movfw	DISC_MINUTES
	bcf		LEADINGZERO
	call	displayNumber
	movlw	':'
	call	lcd_character
	movfw	DISC_SECONDS
	bsf		LEADINGZERO
	goto	displayNumber
;	return


; -------------------------------------------------------------
; Routine:		initialize
; Description:	To initialize I/O ports and register settings
; -------------------------------------------------------------
initPorts:
	Bank0
	movlw   INIT_PORTA			;initialize PORT A                      
	movwf   PORTA
	movlw   INIT_PORTB			;initialize PORT B                      
	movwf   PORTB
	movlw   INIT_PORTC			;initialize PORT C                     
	movwf   PORTC
	movlw   INIT_PORTD			;initialize PORT D                     
	movwf   PORTD
	movlw   INIT_PORTE			;initialize PORT E                     
	movwf   PORTE

	Bank1
	movlw   0x06
	movwf   ADCON1

	movlw	SET_PORTA			;set PORT A 
	movwf	TRISA
	movlw	SET_PORTB			;set PORT B 
	movwf	TRISB
	movlw	SET_PORTC			;set PORT C
	movwf	TRISC
	movlw	SET_PORTD			;set PORT D
	movwf	TRISD
	movlw	SET_PORTE			;set PORT E
	movwf	TRISE
	Bank0
	return

initRegisters:
	Bank1
	movlw	b'00000110'			;enable pull-up, interrupt RB0 on falling edge
	movwf	OPTION_REG			;internal clock, nvt, prescale TMR0, prescale 128
	movlw	0x06				;set Analog input to digital I/O
	movwf	ADCON1
	Bank0
	movlw	b'00000001'			;Timer1 enabled for internal clock (Fosc/4) prescale 1:1
	movwf	T1CON
	movlw	b'01111111'			;Timer2 postscale 1:16, ON, prescale 1:16
	movwf	T2CON
	return


; -------------------------------------------------------------
; Description:	DSA response actions
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed:	-
; -------------------------------------------------------------
setFound:							;DSA response opcode 01h
	movlw	0x40
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h40] indicates Goto time found
	btfsc	STATUS,Z
	return							;ToDo

	movlw	0x41
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h41] indicates Paused
	btfsc	STATUS,Z
	goto	_foundPause

	movlw	0x42
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h42] indicates Pause Released
	btfsc	STATUS,Z
	goto	_foundPauseReleased

	movlw	0x43
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h43] indicates Spinned Up
	btfsc	STATUS,Z
	return
	
	movlw	0x44
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h44] indicates Play A-B start found
	btfsc	STATUS,Z
	return							;ToDo

	movlw	0x45
	subwf	DSA_RESPONSE_PARAM,W	;[Found][h45] indicates Play A-B end found
	btfsc	STATUS,Z
	return							;ToDO

_found:
	movlw	.0
	call	cursor_pos_line2
	movlw	0x0B				;send "track" to LCD (see LCD_stings.asm)
	call	displayString
	bsf		PLAYING
	return

_foundPause:
	bsf		PAUSED
	btfsc	PROGRAM
	goto	_playNextTitle
	btfss	PLAYING
	goto	_playTitle
	goto	displayAction
;	return

_foundPauseReleased:
	bcf		PAUSED
	btfsc	PROGRAM
	return
	goto	displayAction	
;	return

setStopped:						;DSA response opcode 02h
	bcf		PLAYING
	bcf		PAUSED
	bcf		INTROSCAN
	bcf		REPEAT
	bcf		PROGRAM	
	bcf		SHUFFLE
	movfw	MIN_TITLE
	movwf	SET_TITLE
	clrf	ACTUAL_TITLE
	return

setDiscInfo:					;DSA response opcode 03h
	movfw	DSA_RESPONSE_PARAM
	movwf	DISC_INFO
	return

setError:						;DSA response opcode 04h
	clrf	ACTIONS				;abort all actions
	movfw	DSA_RESPONSE_PARAM
	sublw	0x02
	btfsc	STATUS,Z
	goto	_noDiscError
	goto	displayError
;	return
_noDiscError:
	call	lcd_clr
	movlw	0x30				;send "No disc" to LCD (see LCD_stings.asm)
	goto	displayString
;	return
	
setActualTitle:					;DSA response opcode 10h
	clrf	TITLE_LENGTH_L		;clear last title length
	clrf	TITLE_LENGTH_H		;registers

	movlw	0xAA
	subwf	DSA_RESPONSE_PARAM,W	;value hAA indicates lead-out
	btfss	STATUS,Z
	goto	_setActualTitle
	btfss	REPEAT
	goto	_stopDisc
	movfw	MIN_TITLE
	movwf	SET_TITLE
	goto	_playTitle
;	return

_setActualTitle:
	btfss	PROGRAM
	goto	_setActualTitleNow	
	movfw	SET_TITLE
	subwf	DSA_RESPONSE_PARAM,W
	btfsc	STATUS,Z
	goto	_setActualTitleNow

	movlw	.6
	call	cursor_pos_line2
	movfw	DSA_RESPONSE_PARAM
	bcf		LEADINGZERO			;do not display leading zero
	call	displayNumber

	incf	PROG_POINTER,F
	goto	_playTitle

_setActualTitleNow:
	movfw	DSA_RESPONSE_PARAM
	movwf	ACTUAL_TITLE
	movwf	SET_TITLE

	movlw	.6
	call	cursor_pos_line2
	movfw	DSA_RESPONSE_PARAM
	bcf		LEADINGZERO			;do not display leading zero
	call	displayNumber

	btfss	REM_TIME
	return
	movlw	.20
	subwf	ACTUAL_TITLE,W		;if actual title is >=20
	btfsc	STATUS,C			;remaining time can't be displayed (CD-Pro2M restriction)
	return						;so return
	movlw	0x09				;opcode "Get title length"
	movwf	DSA_OPCODE
	movfw	ACTUAL_TITLE		;parameter "track number"
	movwf	DSA_PARAM
	goto	sendDSACommand
;	return

setLengthLSB:
	movfw	DSA_RESPONSE_PARAM
	movwf	TITLE_LENGTH_L
	if debug == 1
		movlw	.13
		call	cursor_pos_line1
		movfw	DSA_RESPONSE_PARAM
		call	displayHexNumber
	endif
	return

setLengthMSB:
	movfw	DSA_RESPONSE_PARAM
	movwf	TITLE_LENGTH_H
	if debug == 1
		movlw	.10
		call	cursor_pos_line1
		movfw	DSA_RESPONSE_PARAM
		call	displayHexNumber
	endif
	return

setActualMinutes:				;DSA response opcode 12h
	movlw	.11
	call	cursor_pos_line2
	movfw	DSA_RESPONSE_PARAM
	movwf	ACTUAL_MINUTES
	bcf		LEADINGZERO			;do not display leading zero
	call	displayNumber
	movlw	':'
	goto	lcd_character
;	return
	
setActualSeconds:				;DSA response opcode 13h
	movlw	.14
	call	cursor_pos_line2
	movfw	DSA_RESPONSE_PARAM
	movwf	ACTUAL_SECONDS
	btfss	REM_TIME
	goto	_displayActualSeconds
	nop		;ToDo display remaining time
_displayActualSeconds:
	bsf		LEADINGZERO			;display leading zero
	call	displayNumber
	btfss	INTROSCAN			;check introscan flag
	return
	movlw	SCAN_TIME
	subwf	DSA_RESPONSE_PARAM,W
	btfss	STATUS,C
	return
	movfw	ACTUAL_TITLE
	subwf	MAX_TITLE,W
	btfss	STATUS,Z
	goto	_playNextTitle		;play next title after "SCAN_TIME" seconds
	movlw	0xAA
	movwf	DSA_RESPONSE_PARAM	
	goto	setActualTitle		;simulate lead-out

setMinTitle:					;DSA response opcode 20h
	movfw	DSA_RESPONSE_PARAM
	movwf	MIN_TITLE
	movwf	SET_TITLE
	bsf		TOC_TITLE_MIN		;set "title min" bit in TOC status register
	return

setMaxTitle:					;DSA response opcode 21h
	movfw	DSA_RESPONSE_PARAM
	movwf	MAX_TITLE
	bsf		TOC_TITLE_MAX		;set "title max" bit in TOC status register
	return

setDiscMinutes:					;DSA response opcode 22h
	movfw	DSA_RESPONSE_PARAM
	movwf	DISC_MINUTES
	bsf		TOC_DISC_MINUTES	;set "disc minutes" bit in TOC status register
	return

setDiscSeconds:					;DSA response opcode 23h
	movfw	DSA_RESPONSE_PARAM
	movwf	DISC_SECONDS
	bsf		TOC_DISC_SECONDS	;set "disc seconds" bit in TOC status register
	return

setDiscFrames:					;DSA response opcode 24h
	movfw	DSA_RESPONSE_PARAM
	movwf	DISC_FRAMES
	bsf		TOC_DISC_FRAMES		;set "disc frames" bit in TOC status register
	return

setTOCCleared:					;DSA response opcode 31h
	return

setDACmode:
	movfw	DSA_RESPONSE_PARAM
	movwf	DACMODE				;store returned DAC mode
	movlw	.3
	call	cursor_pos_line2
	movlw	0x6A				;send "DAC mode:" to LCD (see LCD_stings.asm)
 	call	displayString		;line.position 2.3
	movlw	.11
	call	cursor_pos_line2
	bcf		LEADINGZERO
	movfw	DACMODE
	call	displayNumber
	return

TABLES	CODE					;Program memory page 7
; -------------------------------------------------------------
; Description:	RC5 (Remote Control) command table
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed:	W, PCLATH
; -------------------------------------------------------------
RC5_commandTable:
	movlw	0x07				;set page 7
	movwf	PCLATH
	call	_commandTable
	bcf		RC5_VALID
	return
_commandTable:
	movfw	RC5L
	addwf	PCL,F
	goto	rcKey_0
	goto	rcKey_1
	goto	rcKey_2
	goto	rcKey_3
	goto	rcKey_4
	goto	rcKey_5
	goto	rcKey_6
	goto	rcKey_7
	goto	rcKey_8
	goto	rcKey_9
	retlw	.10
	retlw	.11
;	goto	timeMode
	goto	standby
	retlw	.13
	retlw	.14
	retlw	.15
	retlw	.16
	retlw	.17
	retlw	.18
	retlw	.19
	retlw	.20
	retlw	.21
	retlw	.22
	retlw	.23
	retlw	.24
	retlw	.25
	retlw	.26
	retlw	.27
	goto	shuffleDisc			;RC5 command SHUFFLE (28)
	goto	repeatDisc			;RC5 command REPEAT (29)
	retlw	.30
	retlw	.31
	goto	playNextTitle		;RC5 command NEXT (32)
	goto	playPrevTitle		;RC5 command PREVIOUS (33)
	retlw	.34
	retlw	.35
	retlw	.36
	retlw	.37
	retlw	.38
	retlw	.39
	retlw	.40
	retlw	.41					;
;	goto	programDisc			;RC5 command PROG (41)
	retlw	.42
	goto	introScan			;RC5 command SCAN (43)
	retlw	.44
	goto	rcMoveCover			;RC5 command DISK (45)
	retlw	.46
	retlw	.47
	goto	rcPauseDisc			;RC5 command PAUSE (48)
	retlw	.49
	goto	searchBackward		;RC5 command FAST REVERSE (50)
	retlw	.51
	goto	searchForward		;RC5 command FAST FORWARD (52)
	goto	playTitle			;RC5 command PLAY (53)
	goto	stopDisc			;RC5 command STOP (54)
	retlw	.55
	retlw	.56
	retlw	.57
	retlw	.58
	retlw	.59
	retlw	.60
	retlw	.61
	retlw	.62
	retlw	.63
	return
	
	
; -------------------------------------------------------------
; Description:	DSA opcode response table
;
; Reg. IN:		-
; Reg. OUT:		-
; Reg. Changed:	W, PCLATH
; -------------------------------------------------------------
DSAResponseTable:
	GLOBAL	DSAResponseTable
	movlw	0x07				;set page 7
	movwf	PCLATH				;
	clrf	COUNTER
	bcf		EOS
	bcf		DSA_RESPONCE		;clear responce flag
_responseLoop:
	call	_responseTable
	btfsc	EOS					;check End Of String(table) flag
	return						;responce reserved or unknown
	subwf	DSA_RESPONSE_OPCODE,W
	btfsc	STATUS,Z
	goto	responseActionTable	;response opcode found goto action table
	incf	COUNTER,F
	goto	_responseLoop
	return
_responseTable:
	movfw	COUNTER
	addwf	PCL,F
	retlw	0x01				; (0) Found
	retlw	0x02				; (1) Stopped
	retlw	0x03				; (2) Disc status
	retlw	0x04				; (3) Error Value
	retlw	0x09				; (4) Length of title lsb
	retlw	0x0A				; (5) Length of title msb
	retlw	0x10				; (6) Actual title
	retlw	0x11				; (7) Actual index
	retlw	0x12				; (8) Actual minutes
	retlw	0x13				; (9) Actual seconds
	retlw	0x14				;(10) Absolute time minutes
	retlw	0x15				;(11) Absolute time seconds
	retlw	0x16				;(12) Absolute time frames
	retlw	0x17				;(13) Mode status
	retlw	0x20				;(14) TOC values Min track number
	retlw	0x21				;(15) TOC values Max track number
	retlw	0x22				;(16) TOC value Start time lead-out minutes
	retlw	0x23				;(17) TOC value Start time lead-out seconds
	retlw	0x24				;(18) TOC value Start time lead-out frames
	retlw	0x26				;(19) A->B Time released
	retlw	0x30				;(20) Disk idendifier 0 of the CD
	retlw	0x31				;(21) Disk idendifier 1 of the CD
	retlw	0x32				;(22) Disk idendifier 2 of the CD
	retlw	0x33				;(23) Disk idendifier 3 of the CD
	retlw	0x34				;(24) Disk idendifier 4 of the CD
	retlw	0x51				;(25) Volume level
	retlw	0x60				;(26) Long TOC value Track number
	retlw	0x61				;(27) Long TOC value Control & Address
	retlw	0x62				;(28) Long TOC value Start time minutes
	retlw	0x63				;(29) Long TOC value Start time sconds 
	retlw	0x64				;(30) Long TOC value Start time frames
	retlw	0x6A				;(31) TOC cleared
	retlw	0x70				;(32) DAC mode
	retlw	0xF0				;(33) Servo version Number
	bsf		EOS					;end of list
	return

responseActionTable:
	movfw	COUNTER
	addwf	PCL,F
	goto	setFound			; (0) Found
	goto	setStopped			; (1) Stopped
	goto	setDiscInfo			; (2) Disc status
	goto	setError			; (3) Error Value
	goto	setLengthLSB		; (4) Length of title lsb
	goto	setLengthMSB		; (5) Length of title msb
	goto	setActualTitle		; (6) Actual title
	return						; (7) Actual index
	goto	setActualMinutes	; (8) Actual minutes
	goto	setActualSeconds	; (9) Actual seconds
	return						;(10) Absolute time minutes
	return						;(11) Absolute time seconds
	return						;(12) Absolute time frames
	return						;(13) Mode status
	goto	setMinTitle			;(14) TOC values Min track number
	goto	setMaxTitle			;(15) TOC values Max track number
	goto	setDiscMinutes		;(16) TOC value Start time lead-out minutes
	goto	setDiscSeconds		;(17) TOC value Start time lead-out seconds
	goto	setDiscFrames		;(18) TOC value Start time lead-out frames
	return						;(19) A->B Time released
	return						;(20) Disk idendifier 0 of the CD
	return						;(21) Disk idendifier 1 of the CD
	return						;(22) Disk idendifier 2 of the CD
	return						;(23) Disk idendifier 3 of the CD
	return						;(24) Disk idendifier 4 of the CD
	return						;(25) Volume level
	return						;(26) Long TOC value Track number
	return						;(27) Long TOC value Control & Address
	return						;(28) Long TOC value Start time minutes
	return						;(29) Long TOC value Start time sconds 
	return						;(30) Long TOC value Start time frames
	goto	setTOCCleared		;(31) TOC cleared
	goto	setDACmode			;(32) DAC mode
	return						;(33) Servo version Number

; -------------------------------------------------------------
	END
