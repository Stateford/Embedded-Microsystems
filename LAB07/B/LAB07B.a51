; IO Port and bits naming
LCD 	EQU P1		; Data lines on LCD connect to this IO Port
					; "LCD" may be changed to another port, if necessary
					
COUNT EQU R7
					
ARRAY_START EQU 40H	; start of the array
ARRAY_END EQU 42H	; end of the array
					
CLOCK BIT P3.4
	
BZYFLG	BIT P1.7  	; Can read this from LCD to see if its still busy
					; ***Change this if data lines not on Port 1!!!***

RS 	BIT P2.0	; Set this control bit high to send data
RW	BIT P2.1	; Set this bit high to read (status) from LCD
EN 	BIT P2.2	; This is the clock into the LCD. Take high to ready 				
				; the LCD
				; Then take low to clock data or cmd onto the data 				
				; lines of LCD

ORG 0000H
	
	ACALL PWR_DELAY	; delay on power up
	ACALL INIT				; initalize LCD
	
MAIN:
	MOV A, #80H		; Cursor home command
	SETB CLOCK
	SETb TR0
	MOV TH0, #0H
	MOV TL0, #0H
	MOV TMOD, #06H
	
LOOP:
	ACALL CMD			; init LCD as 4 line x 20 char
	ACALL BIN_BCD		; converts BINARY to BCD
	ACALL WRITE_LCD	; Writes to LCD
	
	SJMP LOOP


; BINARY TO BCD
; -----------------
; Converts binary number from SWITCH on P0 to BCD
; Stores results starting at MSB at @R0 #ARRAY_START
BIN_BCD:
	JNB TF0, NO_ROLLOVER
	MOV TL0, #00H
	CLR TF0
NO_ROLLOVER:
	MOV R0, #ARRAY_END	; point R0 to array
	MOV COUNT, #3			; Initalize COUNT
	MOV A, TL0 ; get data from port
	MOV B, #10
	DIV AB						; Divide
	
	ACALL BCD_HEX			; Convert to BCD
	
	DEC R0						; Decrement pointer
	MOV B, #10				
	DIV AB						; Divide
	
	ACALL BCD_HEX			; Convert to BCD
	DEC R0
	ACALL BCD_HEX			; Convert to BCD
	RET

; BCD TO ASCII
; --------------
; Converts BCD number to ASCII by adding 0x30
; Store results starting at MSB at @R0 #ARRAY_START
BCD_HEX:
	DJNZ COUNT, NOTZERO		; If count is not zero jump to NOTZERO
	ADD A, #30H					; add 0x30 to BCD
	MOV @R0, A					; mov A to R0
	JMP BCD_HEX_END
NOTZERO:
	PUSH ACC						; store ACC on the stack
	MOV A, B						; mov b into a
	ADD A, #30H					; add 0x30 to A
	MOV @R0, A					; A into array
	POP ACC						; get ACC from stack
BCD_HEX_END:
	RET
	
	
; WRITE_LCD
; ----------------
; Write array to LCD screen
WRITE_LCD:
	MOV R0, #ARRAY_START	; Start of array
	MOV COUNT, #3				; Init count
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
	RET 

	END
 
 
