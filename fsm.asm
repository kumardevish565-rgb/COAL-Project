include Irvine32.inc

.data
;Indicators for active states for each traffic light
NORTH_GREEN EQU 00000001b
NORTH_YELLOW EQU 00000010b
EAST_GREEN EQU 00000100b
EAST_YELLOW EQU 00001000b
SOUTH_GREEN EQU 00010000b
SOUTH_YELLOW EQU 00100000b
WEST_GREEN EQU 01000000b
WEST_YELLOW EQU 10000000b

BASE_GREEN_TIME EQU 10 ; Minimum Time for green light
MAX_GREEN_TIME EQU 120 ; Maximum Time for green light
BASE_YELLOW_TIME EQU 3 ; Time for yellow light
SINGLE_CAR_TIME EQU 2 ; Time for single car to pass

state_arr BYTE NORTH_GREEN, NORTH_YELLOW, 
			   EAST_GREEN, EAST_YELLOW,
			   SOUTH_GREEN, SOUTH_YELLOW,
			   WEST_GREEN, WEST_YELLOW 

lights_state BYTE 0 ; Curent state of traffic lights
current_phase BYTE 0 ; Current phase in finite-state machine(fsm)
phase_timer DWORD (BASE_GREEN_TIME + MAX_GREEN_TIME) /2 ; Timer for current active traffic light

; Number of cars waiting in each direction
north_queue DWORD 0 
east_queue DWORD 0
south_queue DWORD 0
west_queue DWORD 0

; Variables to keep track of key metrics to be saved to file
manual_inputs DWORD 0
total_north_cars DWORD 0
total_east_cars DWORD 0
total_south_cars DWORD 0
total_west_cars DWORD 0
max_queue DWORD 0
max_north_queue DWORD 0
max_east_queue DWORD 0
max_south_queue DWORD 0
max_west_queue DWORD 0
time_max_queue DWORD 0
time_max_north_queue DWORD 0
time_max_east_queue DWORD 0
time_max_south_queue DWORD 0
time_max_west_queue DWORD 0

.code

adaptiveTimer PROC USES eax edx
MOV eax, [esi]
PUSH SINGLE_CAR_TIME
MUL DWORD PTR [esp]
ADD esp, 4 
ADD eax, BASE_GREEN_TIME
CMP eax, MAX_GREEN_TIME
JNA _out
MOV eax, MAX_GREEN_TIME

_out:
	MOV ecx, eax
	RET 
adaptiveTimer ENDP
 
updateFSM PROC USES eax ebx ecx edi
MOV ecx, phase_timer
DEC ecx
TEST ecx, 0FFFFFFFFh
JNZ _out

MOVZX eax, current_phase
INC eax
CMP eax, 7
JNA _notReset
XOR eax, eax

_notReset:
 	LEA edi, [state_arr + eax * TYPE state_arr]
	MOV bl, [edi]
	MOV lights_state, bl
	TEST eax, 1
	JZ _greenLight
	MOV phase_timer, BASE_YELLOW_TIME
	JMP _setPhase

_greenLight:
	TEST eax, 0FFFFFFFFh
	JZ _north
	CMP eax, 2
	JE _east
	CMP eax, 4
	JE _south
	MOV esi, OFFSET west_queue
	JMP _setTimer
	
_north:
	MOV esi, OFFSET north_queue
	JMP _setTimer
_east:
	MOV esi, OFFSET east_queue
	JMP _setTimer
_south:
	MOV esi, OFFSET south_queue
_setTimer:
	CALL adaptiveTimer
_setPhase:
	MOV current_phase, al

_out:
	MOV phase_timer, ecx
	RET
updateFSM ENDP 

generateInput PROC USES eax
MOV eax, 4
CALL RandomRange
ADD north_queue, eax
ADD east_queue, eax
ADD south_queue, eax
ADD west_queue, eax
RET
generateInput ENDP

main PROC
MOV ecx, 0 
MOV esi, OFFSET north_queue

CALL updateFSM

EXIT
main ENDP
END main