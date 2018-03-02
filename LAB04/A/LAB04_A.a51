; LAB 4A - USING 8051 I/O PORTS

ORG 000H

START:
	MOV A, #1		; PUT 1 INTO A
	MOV P2, A		; INITALIZE P2
	MOV R1, #55H	; Move 0x55 into R1
	MOV R2, #0AAH	; Move 0xAA into R2
	MOV P2, R1
	ACALL DELAY		; Delay for half a second
	
	MOV P2, R2
	ACALL DELAY		; Delay for half a second
	
	SJMP START

; DELAY
; -------------------------------------
; Delays for half a second using loops
; -------------------------------------
; 500,000 / .36169 = 1382399 / 256 = 5399 / 256 = 21.09 -> 22
; 1382399 / 22 = 62836 / 256 = 245
;
DELAY:
	MOV R5, #22
OUTER:
	MOV R4, #0
MIDDL:
	MOV R3, #245
	
INNER:
	DJNZ R3, INNER
	DJNZ R4, MIDDL
	DJNZ R5, OUTER
	
	RET
	
	END
