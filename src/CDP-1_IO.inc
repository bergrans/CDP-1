;******************************************************************************
;* Ports on CD-Pro2M Controller                                               *
;* Filenaam: CD-Pro2M ports.ASM    (version for MPASM)                        *
;******************************************************************************
;
;			 		             PIC16F871
;                         ----------|_|------------
;                    MCLR |  1                 40 | PGD (ICSP)
;                 DSA_ACK |  2                 39 | KEY_COL_3/PGC (ICSP)
;                 DSA_DDA |  3                 38 | KEY_COL_2
;                 DSA_DST |  4                 37 | KEY_COL_1
;                 	 DRST |  5                 36 |	KEY_ROW_3
;               LASER_OFF |  6                 35 | KEY_ROW_2
;              	 SENSOR_1 |  7                 34 | KEY_ROW_1
;                SENSOR_2 |  8                 33 | RC5
;                SENSOR_3 |  9                 32 | VDD (+5V)
;                SENSOR_4 | 10                 31 | VSS (GND)
;               VDD (+5V) | 11                 30 | RELAY_1
;               VSS (GND) | 12                 29 | RELAY_2
;                    OSC1 | 13                 28 | RELAY_3
;					 OSC2 | 14                 27 | RELAY_4
;                  LCD_RS | 15                 26 | RELAY_5
;                  LCD_RW | 16                 25 | RELAY_6
;                  LCD_BN | 17                 24 | LED_REPEAT (RELAY_7)
;                  LCD_EN | 18                 23 | RELAY_POWER
;                 LCD_DB4 | 19                 22 | LCD_DB7
;                 LCD_DB5 | 20                 21 | LCD_DB6
;                         -------------------------

	#define		DSA_PORT		PORTA
	#define		DSA_TRIS		TRISA
	#define		LCD_PORT		PORTD		;(LC)Display data bits on (low nibble) PORTD
	#define		LCD_TRIS		TRISD

	#define		DSA_ACK			PORTA,0		;in/output DSA acknowledge
	#define		DSA_DDA			PORTA,1		;in/output DSA data
	#define		DSA_DST			PORTA,2		;in/output DSA strobe
	#define		DRST			PORTA,3		;output CD-Pro2 reset
	#define     LASER_OFF		PORTA,4		;output CD-Pro2 laser off
	#define     COVER_DIR		PORTA,5		;output

	#define		RC5				PORTB,0		;input RC5 remote control receiver
	#define		KEY_ROW_1		PORTB,1		;output keyboard matrix row 1
	#define		KEY_ROW_2		PORTB,2		;output keyboard matrix row 2
	#define		KEY_ROW_3		PORTB,3		;output keyboard matrix row 3
	#define		KEY_COL_1		PORTB,4		;input  keyboard matrix colum 1
	#define		KEY_COL_2		PORTB,5		;input  keyboard matrix colum 2
	#define		KEY_COL_3		PORTB,6		;input  keyboard matrix colum 3

	#define		LCD_RS			PORTC,0		;output lcd register select
	#define		LCD_RW			PORTC,1		;output lcd read/write
	#define		LCD_BN			PORTC,2		;output lcd brightness
	#define		LCD_EN			PORTC,3		;output lcd enable
	#define		LED_POWER		PORTC,4		;output relay driver POWER LED
;	#define		LED_REPEAT		PORTC,5		;output relay driver LED_REPEAT (REL_7)
	#define		REL_6			PORTC,6		;output relay driver
	#define		REL_5			PORTC,7		;output relay driver

	#define		LCD_DB4			PORTD,0		;output lcd data bit 4
	#define		LCD_DB5			PORTD,1		;output lcd data bit 5
	#define		LCD_DB6			PORTD,2		;output lcd data bit 6
	#define		LCD_DB7			PORTD,3		;output lcd data bit 7
	#define		MOTOR_POWER		PORTD,4		;output relay driver
	#define		MAINS_CDPRO		PORTD,5		;output relay driver
	#define		RELAY_5V_CDPro	PORTD,6		;output relay driver
	#define		RELAY_9V_CDPro	PORTD,7		;output relay driver

	#define     COVER_CLOSED	PORTE,0		;input player cover closed
	#define     COVER_OPEN		PORTE,1		;input player cover open
	#define     MOTOR_STEP		PORTE,2		;output motor step
