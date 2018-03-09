; IO Port and bits naming
LCD 	EQU P1		; Data lines on LCD connect to this IO Port
					; "LCD" may be changed to another port, if necessary
					
COUNT EQU R7
STORE EQU R6	; Stores data from ADC

SWITCH EQU P0
	

					
ARRAY_START EQU 40H	; start of the array
ARRAY_END EQU 42H	; end of the array
					
	
INTR EQU P2.3	; interrupt pin for ADC
RD_ADC EQU P2.4
WR_ADC EQU P2.5
	
BZYFLG	BIT P1.7  	; Can read this from LCD to see if its still busy
					; ***Change this if data lines not on Port 1!!!***

RS 	BIT P2.0	; Set this control bit high to send data
RW	BIT P2.1	; Set this bit high to read (status) from LCD
EN 	BIT P2.2	; This is the clock into the LCD. Take high to ready 				
				; the LCD
				; Then take low to clock data or cmd onto the data 				
				; lines of LCD

ORG 0000H
	MOV SWITCH, #0FFH
	SETB INTR
	SETB RD_ADC
	SETB WR_ADC
	ACALL PWR_DELAY			; delay on power up
	ACALL INIT				; initalize LCD
	
MAIN:
	MOV A, #80H			; Cursor home command
	ACALL CMD			; init LCD as 4 line x 20 char

	ACALL GET_ADC		; Get data from ADC and STORE it
	ACALL BIN_BCV		; converts BINARY to BCD
	ACALL WRITE_LCD		; Writes to LCD
	
	SJMP MAIN

; GET ADC DATA
; ---------------
; Gets data from and ADC
GET_ADC:
	SETB INTR		; Set intr HIGH (active low)
	CLR WR_ADC		; Clear W/R to start conversion
	NOP
	SETB WR_ADC		; Set W/R for the next time
POLL_INTR:
	JB INTR, POLL_INTR	; poll until INTR goes high
	
	CLR RD_ADC			; clear RD
	NOP
	MOV STORE, SWITCH	; move from switch into store
	RET
	
; BINARY TO BCD - VOLTAGE
; -------------------------
; Takes the voltage and converts it into BCD 
BIN_BCV:
	MOV R0, #ARRAY_START	; Mov the start of the array to R0
	MOV COUNT, #2			; start a count for two
							; this is in order to insert a "."
							; after one number
							
	MOV A, STORE			; Get binary number from ADC
	MOV B, #51				; Move 51 into B
	DIV AB					; Divide binary number by 51
	
	ACALL BCV_HEX			; convert to ascii hex
	
	MOV A, B				; move the remainder into A
	JZ ZERO					; if : the remainder is zero JMP
	
	DEC A					; else : decrement A
ZERO:
	MOV B, #5				; move 5 into B
	DIV AB					; divide remainder by 5

	ACALL BCV_HEX			; convert to ascii hex w/o decrementing
							; zero / anything produces an error, leave at zero
	
	
	MOV A, B				; move the remainder into b
	RLC A					; rotate with carry
	
	ACALL BCV_HEX			; convert to ascii hex
	
	
	RET
	
BCV_HEX:
	DJNZ COUNT, NOT_ZERO	; check if count it not zero
							; this will only occur after the first number is placed
	MOV @R0, #2EH			; move a '.' ascii character into the array
	INC R0					; increment position in the array
NOT_ZERO:
	ADD A, #30H				; add 0x30 to A to conver it to ascii
	MOV @R0, A				; move A into array @R0
	INC R0					; increment R0
	RET
	
	
; WRITE_LCD
; ----------------
; Write array to LCD screen
WRITE_LCD:
	MOV R0, #ARRAY_START	; Start of array
	MOV COUNT, #4				; Init count
WRITE_NZ:
	MOV A, @R0					; Get element of array
	ACALL DAT                   ; send to LCD
	MOV A, #6H                  ; command code to move cursor right
	ACALL CMD                   ; send command
	INC R0                      ; add one to R0
	DJNZ COUNT, WRITE_NZ       
WRITE_LCD_END:
	RET

;** DAT Subroutine. Sends Data byte to LCD because RS is High****
;	Input: ASCII character in register A 
; 	How it works: sets EN hi to prepare; sets RW low to write to LCD
;	RS is high to indicate that this is Data
; 	Places the data byte on Port "LCD" and gives clock the falling edge 
; 	on EN which loads one data byte to the LCD. Need ? time between EN=H and EN=L
          
DAT:	SETB EN		; Prepare for H->L PULSE ON E 
	SETB RS			; RS=1 meand sending DATA
	CLR RW			; RW=0 for WRITE
	MOV LCD,A		; Place data byte onto data pins of LCD; 3 cycles
	NOP
	NOP			; 195 ns LCD setup time nominal
	CLR EN			; Falling edge on EN pin writes data byte in A to LCD
	NOP				; To give a bit of time. Documentation suggested
	LCALL WAIT_LCD	; Allow LCD to digest data byte
	RET

;***** CMD Subroutine.Sends Command byte to LCD because RS is High****
;	Input: a command character in register A 
; 	How it works: sets EN hi to prepare; sets RW low to write to LCD
; 	RS is low to indicate to LCD that this is a command
; 	Places the command byte on Port "LCD" and gives clock the falling edge 
; 	on EN which loads one data byte to the LCD. Need ? time between EN=H and EN=L
 
CMD:	SETB EN
	CLR RS
	CLR RW
	MOV LCD,A
	NOP
	NOP
    	CLR EN
   		NOP
   	LCALL WAIT_LCD
	RET
        
;******Initialize LCD Subroutine****************************
; "The book" says we need to send 38H three times if there 
; are only 4 data lines being used from microcontroller to the LCD.
; BZY_FLAG may not be checkable. Delays added 2/24/18
        
INIT:	MOV A,#038H	; INITIALIZE, 8-bits 2-LINES, 5X7 MATRIX.	
	LCALL  CMD	; Wait 4.1 msec
	LCALL PWR_DELAY	; Is more than 4.1 ms but only at at startup.
        	
	MOV A,#038H	; INITIALIZE, 8-bits 2-LINES, 5X7 MATRIX.
	LCALL  CMD	; Need this 3 times if 4 data lines
	LCALL PWR_DELAY	; Is more than 100 usecs but only at at startup.
        
	MOV A,#038H 	; Multiple sources say need this 3X
	LCALL  CMD	; But no explanation of details.
                
	MOV A,#0EH		;  LCD & VISIBLE CURSOR ON;
	LCALL  CMD
	MOV A,#01H		; CLEAR LCD SCREEN
	LCALL  CMD
	MOV A,#06H		; Cursor home
	LCALL  CMD
	RET
                
;********PWR_Delay (long) Subroutine***************************
; Predko's book says we need 15 msec delay at power on.

PWR_DELAY:	; Power on delay. 361.6896 nS * 42075 = 15.218 mSec
		
          		MOV R4,#165D
OUTER:	MOV R3,#255D
INNER:	DJNZ R3,INNER
		DJNZ R4,OUTER
        RET
    
;*******Wait for Busy Flag to be low Subroutine  ********
; Modified 2/24/18 to add max time to wait using DJNZ
; Should be 1.69 ms DJNZ timeout
; after sending a command or data byte, we can read the LCD's busy 
; flag on P1 pin 7 and wait for it to become zero. This is called by
; the CMD or DAT subroutines.

WAIT_LCD:	; We have sent something to th LCD. Now read the busy
			; flag to see if LCD is done (not busy)
	PUSH 07		; Using R7 for DJNZ; protect it.
	MOV R7, #0	; Max 256 iterations in case flag stuck
	SETB BZYFLG	; enable input on busy flag bit. P1.7 

FLOOP:	CLR RS		; P2.0 low for command
	SETB RW		; P2.1 high to read status. Need 160ns before E hi
	CLR EN		; 
	NOP			; leave EN low for 4 cycles.
	NOP			; 1.44 uSec total
	NOP			; May not need this much
	NOP			; but we had trouble.
	SETB EN		; rising edge on EN reads
	NOP		; some data output delay time
	MOV LCD, #0FFh	; Write command to LCD for Read status
	MOV A, LCD		;	Read the status from LCD
	JNB ACC.7, NOTBZY 	; If ACC.7 is low, LCD is no longer busy
	DJNZ R7, FLOOP		; 1.690 mS timeout in case Busy flag stuck hi

NOTBZY:	CLR RW			; Return to write mode
	POP 07		; Restore R7
				; Otherwise the stack pointer won't return properly
	RET 

	END
 
 
