; LAB 05 - ADDRESSING MODES AND TABLE LOOKUPS

; VARIABLES
; ---------
SWITCH EQU P1
LED EQU P2
COUNT EQU R7

ORG 000H
	
	; INITALIZE
	;----------
	MOV SWITCH, #0FFH
	MOV DPTR, #400H
START:
	
	MOV A, SWITCH 		; move from port to R0
	ANL A, #00000111B	; Check only to 3rd bit
	ACALL CHK_SEVEN		; Check if number is seven
	
	MOVC A, @A+DPTR		; offset array from input
	MOV LED, A			; send result to port
	
	
	SJMP START
		
; CHK_SEVEN
; -------------------------------
; Checks if the input is seven
; Displays 0xFF if it is seven
CHK_SEVEN:
	CJNE A, #7, CHK_FALSE	; If number is not equal to seven
							
	MOV LED, #0FFH		; Display all lights
	ACALL DELAY			; delay .25 seconds
	MOV LED, #0H		; display no lights
	ACALL DELAY			; delay .25 seconds
	SJMP START			; Go to start
CHK_FALSE:
	RET
		
; DELAY
; -------------------------------------
; Delays for half a second using loops
; -------------------------------------
; 250,000 / .36169 = 691199 / 256 = 2699 = 10.5 -> 11
; 691199 / 11 = 62836 / 256 = 245
DELAY:
	MOV R5, #11
OUTER:
	MOV R4, #255
MIDDL:
	MOV R3, #246
	
INNER:
	DJNZ R3, INNER
	DJNZ R4, MIDDL
	DJNZ R5, OUTER
	
	RET
	
		
ORG 400H
; CUBES
; ------------
; LIST OF CUBES
CUBE: DB 0, 1, 8, 27, 64, 125, 216	


	
	END
