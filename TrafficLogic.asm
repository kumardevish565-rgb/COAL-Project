.586
.model flat, C
OPTION CASEMAP:NONE

CreateFileA PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
WriteFile   PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD
CloseHandle PROTO STDCALL :DWORD
includelib kernel32.lib

GENERIC_WRITE         EQU 40000000h
CREATE_ALWAYS         EQU 2
FILE_ATTRIBUTE_NORMAL EQU 80h
INVALID_HANDLE_VALUE  EQU -1

PUBLIC InitSim, AddTraffic, StepTick, SaveReport

PUBLIC lights_state, current_phase, phase_timer
PUBLIC north_queue, south_queue, east_queue, west_queue
PUBLIC total_in, total_out, current_cars, peak_queue
PUBLIC ticks
PUBLIC north_departs, east_departs, south_departs, west_departs
PUBLIC total_north_cars, total_south_cars, total_east_cars, total_west_cars
PUBLIC max_north_queue, max_south_queue, max_east_queue, max_west_queue
PUBLIC time_max_queue
PUBLIC time_max_north_queue, time_max_south_queue, time_max_east_queue, time_max_west_queue
PUBLIC phase_names, state_arr

.data
NORTH_GREEN  EQU 00000001b
NORTH_YELLOW EQU 00000010b
EAST_GREEN   EQU 00000100b
EAST_YELLOW  EQU 00001000b
SOUTH_GREEN  EQU 00010000b
SOUTH_YELLOW EQU 00100000b
WEST_GREEN   EQU 01000000b
WEST_YELLOW  EQU 10000000b

FOUR_DIRECTIONS EQU 4 ; maximum number of cars generate automatically
BASE_GREEN_TIME  EQU 10 ; Minimum Time for green light
MAX_GREEN_TIME   EQU 120 ; Maximum Time for green light
BASE_YELLOW_TIME EQU 3 ; Time for yellow light
SINGLE_CAR_TIME  EQU 2 ; Time for single car to pass

state_arr BYTE NORTH_GREEN, NORTH_YELLOW,
               EAST_GREEN, EAST_YELLOW,
               SOUTH_GREEN, SOUTH_YELLOW,
               WEST_GREEN, WEST_YELLOW

lights_state   BYTE 0 ; Current state of traffic lights
current_phase  BYTE 0 ; Current phase in finite-state machine (FSM)
phase_timer    DWORD (BASE_GREEN_TIME + MAX_GREEN_TIME) / 2 ; Timer for current active traffic light

north_queue    DWORD 0
south_queue    DWORD 0
east_queue     DWORD 0
west_queue     DWORD 0
total_in       DWORD 0
total_out      DWORD 0
current_cars   DWORD 0
peak_queue     DWORD 0

ticks          DWORD 0
north_departs  DWORD 0
east_departs   DWORD 0
south_departs  DWORD 0
west_departs   DWORD 0

total_north_cars     DWORD 0
total_south_cars     DWORD 0
total_east_cars      DWORD 0
total_west_cars      DWORD 0
max_north_queue      DWORD 0
max_south_queue      DWORD 0
max_east_queue       DWORD 0
max_west_queue       DWORD 0
time_max_queue       DWORD 0
time_max_north_queue DWORD 0
time_max_south_queue DWORD 0
time_max_east_queue  DWORD 0
time_max_west_queue  DWORD 0

phase_names BYTE "North Green  ",0
            BYTE "North Yellow ",0
            BYTE "East Green   ",0
            BYTE "East Yellow  ",0
            BYTE "South Green  ",0
            BYTE "South Yellow ",0
            BYTE "West Green   ",0
            BYTE "West Yellow  ",0

labelnorth          BYTE "North Queue: ", 0
labelwest           BYTE "West Queue: ", 0
labeleast           BYTE "East Queue: ", 0
labelsouth          BYTE "SOUTH Queue ", 0
labelin             BYTE "Total Cars Going in: ", 0
labelout            BYTE "Total Cars Going out: ", 0
labelmax            BYTE "Max Queue: ", 0
labelmaxtime        BYTE "Time for Maximum: ", 0
labelnorthmaxtime   BYTE "Max North time ", 0
labelsouthmaxtime   BYTE "Max South time ", 0
labeleastmaxtime    BYTE "Max East time ", 0
labelwestmaxtime    BYTE "Max West time ", 0
labeltotalnorth     BYTE "Total North Cars", 0
labeltotalwest      BYTE "Total West Cars", 0
labeltotaleast      BYTE "Total East Cars", 0
labeltotalsouth     BYTE "Total South Cars", 0
labelmaxnorth       BYTE "Max North Cars:", 0
labelmaxwest        BYTE "Max West Cars:", 0
labelmaxeast        BYTE "Max East Cars:", 0
labelmaxsouth       BYTE "Max South Cars:", 0

bufferlen           DWORD 0
buffer              BYTE 2000 DUP(0)
filename            BYTE "traffic.txt", 0
filehandle          DWORD 0

bytesWritten        DWORD 0
rng_seed            DWORD 0A5C3E1B7h

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
	MOV ecx, BASE_YELLOW_TIME
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

WriteLabel PROC
push eax

WriteLoop:
mov al, [esi]
cmp al, 0
je WriteEnd
mov [edi], al
inc esi
inc edi
inc bufferlen
jmp WriteLoop

WriteEnd:
pop eax
ret
WriteLabel ENDP

WriteNumber Proc
push eax
push ebx
push ecx
push edx
mov ebx, 10
xor ecx, ecx

GetDigits:
xor edx, edx
div ebx
add dl, '0'
push edx
inc ecx
test eax, eax
jnz GetDigits

SaveDigits:
pop edx
mov [edi], dl
inc edi
inc bufferlen
loop SaveDigits
mov BYTE PTR [edi], 0Dh
inc edi
mov BYTE PTR [edi] , 0Ah
inc edi
add bufferlen, 2
pop edx
pop ecx
pop ebx
pop eax
ret
WriteNumber ENDP

file PROC
    mov bufferlen, 0
    mov edi, OFFSET buffer

    mov esi, OFFSET labelmaxnorth
    call WriteLabel
    mov eax, max_north_queue
    call WriteNumber

    mov esi, OFFSET labelmaxwest
    call WriteLabel
    mov eax, max_west_queue
    call WriteNumber

    mov esi, OFFSET labelmaxeast
    call WriteLabel
    mov eax, max_east_queue
    call WriteNumber

    mov esi, OFFSET labelmaxsouth
    call WriteLabel
    mov eax, max_south_queue
    call WriteNumber

    mov esi, OFFSET labeltotalnorth
    call WriteLabel
    mov eax, total_north_cars
    call WriteNumber

    mov esi, OFFSET labeltotalwest
    call WriteLabel
    mov eax, total_west_cars
    call WriteNumber

    mov esi, OFFSET labeltotaleast
    call WriteLabel
    mov eax, total_east_cars
    call WriteNumber

    mov esi, OFFSET labeltotalsouth
    call WriteLabel
    mov eax, total_south_cars
    call WriteNumber

    mov esi, OFFSET labelmaxtime
    call WriteLabel
    mov eax, time_max_queue
    call WriteNumber

    mov esi, OFFSET labelnorthmaxtime
    call WriteLabel
    mov eax, time_max_north_queue
    call WriteNumber

    mov esi, OFFSET labelsouthmaxtime
    call WriteLabel
    mov eax, time_max_south_queue
    call WriteNumber

    mov esi, OFFSET labeleastmaxtime
    call WriteLabel
    mov eax, time_max_east_queue
    call WriteNumber

    mov esi, OFFSET labelwestmaxtime
    call WriteLabel
    mov eax, time_max_west_queue
    call WriteNumber

    mov esi, OFFSET labelin
    call WriteLabel
    mov eax, total_in
    call WriteNumber

    mov esi, OFFSET labelout
    Call WriteLabel
    mov eax, total_out
    CAll WriteNumber

    mov esi, OFFSET labelmax
    CALL WriteLabel
    mov eax, peak_queue
    Call WriteNumber

    mov esi, OFFSET labelnorth
    CALL WriteLabel
    mov eax, north_queue
    Call WriteNumber

    mov esi, OFFSET labelwest
    CALL WriteLabel
    mov eax, west_queue
    Call WriteNumber

    mov esi, OFFSET labeleast
    CALL WriteLabel
    mov eax, east_queue
    Call WriteNumber

    mov esi, OFFSET labelsouth
    CALL WriteLabel
    mov eax, south_queue
    Call WriteNumber

    INVOKE CreateFileA, OFFSET filename, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov filehandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je _fileDone

    INVOKE WriteFile, filehandle, OFFSET buffer, bufferlen, OFFSET bytesWritten, 0
    INVOKE CloseHandle, filehandle
_fileDone:
    ret
file ENDP

carsdec PROC
    push ebp
    mov ebp, esp
    push eax
    push ebx
    mov ebx, [ebp + 12]
    cmp ebx, 0
    je DONE
    test ebx, 1
    jnz DONE

    mov eax, [ebp + 8]
    test eax, NORTH_GREEN
    jnz subnorth
    test eax, EAST_GREEN
    jnz subeast
    test eax, WEST_GREEN
    jnz subwest
    test eax, SOUTH_GREEN
    jnz subsouth
    jmp DONE

subnorth:
    cmp north_queue, 0
    je DONE
    mov esi, OFFSET north_queue
    dec DWORD PTR [esi]
    inc north_departs
    inc total_out
    jmp DONE

subeast:
    cmp east_queue, 0
    je DONE
    mov esi, OFFSET east_queue
    dec DWORD PTR [esi]
    inc east_departs
    inc total_out
    jmp DONE

subwest:
    cmp west_queue, 0
    je DONE
    mov esi, OFFSET west_queue
    dec DWORD PTR [esi]
    inc west_departs
    inc total_out
    jmp DONE

subsouth:
    cmp south_queue, 0
    je DONE
    mov esi, OFFSET south_queue
    dec DWORD PTR [esi]
    inc south_departs
    inc total_out

DONE:
    pop ebx
    pop eax
    pop ebp
    ret 8
carsdec ENDP

AddNorth PROC
    push esi
    mov esi, OFFSET north_queue
    inc DWORD PTR [esi]
    mov edi, OFFSET total_north_cars
    inc DWORD PTR [edi]
    inc total_in
    mov eax, north_queue
    cmp eax, max_north_queue
    jbe _chk_max_q_n
    mov max_north_queue, eax
    mov eax, ticks
    mov time_max_north_queue, eax
_chk_max_q_n:
    mov eax, north_queue
    cmp eax, peak_queue
    jbe to_after
    mov peak_queue, eax
    mov eax, ticks
    mov time_max_queue, eax
to_after:
    pop esi
    ret
AddNorth ENDP

AddSouth PROC
    push esi
    mov esi, OFFSET south_queue
    inc DWORD PTR [esi]
    mov edi, OFFSET total_south_cars
    inc DWORD PTR [edi]
    inc total_in
    mov eax, south_queue
    cmp eax, max_south_queue
    jbe _chk_max_q_s
    mov max_south_queue, eax
    mov eax, ticks
    mov time_max_south_queue, eax
_chk_max_q_s:
    mov eax, south_queue
    cmp eax, peak_queue
    jbe to_after
    mov peak_queue, eax
    mov eax, ticks
    mov time_max_queue, eax
to_after:
    pop esi
    ret
AddSouth ENDP

AddEast PROC
    push esi
    mov esi, OFFSET east_queue
    inc DWORD PTR [esi]
    mov edi, OFFSET total_east_cars
    inc DWORD PTR [edi]
    inc total_in
    mov eax, east_queue
    cmp eax, max_east_queue
    jbe _chk_max_q_e
    mov max_east_queue, eax
    mov eax, ticks
    mov time_max_east_queue, eax
_chk_max_q_e:
    mov eax, east_queue
    cmp eax, peak_queue
    jbe to_after
    mov peak_queue, eax
    mov eax, ticks
    mov time_max_queue, eax
to_after:
    pop esi
    ret
AddEast ENDP

AddWest PROC
    push esi
    mov esi, OFFSET west_queue
    inc DWORD PTR [esi]
    mov edi, OFFSET total_west_cars
    inc DWORD PTR [edi]
    inc total_in
    mov eax, west_queue
    cmp eax, max_west_queue
    jbe _chk_max_q_w
    mov max_west_queue, eax
    mov eax, ticks
    mov time_max_west_queue, eax
_chk_max_q_w:
    mov eax, west_queue
    cmp eax, peak_queue
    jbe to_after
    mov peak_queue, eax
    mov eax, ticks
    mov time_max_queue, eax
to_after:
    pop esi
    ret
AddWest ENDP

RandomRange PROC USES ebx edx
    mov ebx, eax
    mov eax, rng_seed
    mov edx, 1664525
    mul edx
    add eax, 1013904223
    mov rng_seed, eax
    shr eax, 16
    xor edx, edx
    div ebx
    mov eax, edx
    ret
RandomRange ENDP

InitSim PROC C
    mov lights_state, NORTH_GREEN
    mov current_phase, 0
    mov phase_timer, (BASE_GREEN_TIME + MAX_GREEN_TIME) / 2

    xor eax, eax
    mov north_queue, eax
    mov south_queue, eax
    mov east_queue, eax
    mov west_queue, eax
    mov total_in, eax
    mov total_out, eax
    mov current_cars, eax
    mov peak_queue, eax
    mov ticks, eax
    mov north_departs, eax
    mov east_departs, eax
    mov south_departs, eax
    mov west_departs, eax
    mov total_north_cars, eax
    mov total_south_cars, eax
    mov total_east_cars, eax
    mov total_west_cars, eax
    mov max_north_queue, eax
    mov max_south_queue, eax
    mov max_east_queue, eax
    mov max_west_queue, eax
    mov time_max_queue, eax
    mov time_max_north_queue, eax
    mov time_max_south_queue, eax
    mov time_max_east_queue, eax
    mov time_max_west_queue, eax

    rdtsc
    xor eax, edx
    or  eax, 1
    mov rng_seed, eax
    ret
InitSim ENDP

AddTraffic PROC C USES ebx esi edi, lane:DWORD
    mov eax, lane
    cmp eax, 0
    je _addN
    cmp eax, 1
    je _addE
    cmp eax, 2
    je _addS
    cmp eax, 3
    je _addW
    jmp _addDone
_addN:
    call AddNorth
    jmp _addDone
_addE:
    call AddEast
    jmp _addDone
_addS:
    call AddSouth
    jmp _addDone
_addW:
    call AddWest
_addDone:
    ret
AddTraffic ENDP

StepTick PROC C USES ebx esi edi
    call updateFSM
    inc ticks

    mov eax, north_queue
    mov ebx, south_queue
    cmp eax, ebx
    jbe south_greater
s_check:
    mov ebx, east_queue
    cmp eax, ebx
    jbe east_greater
    jmp e_check
e_check:
    mov ebx, west_queue
    cmp eax, ebx
    jbe west_greater
    jmp n_check
w_check:
    mov current_cars, ebx
    jmp greater_selected

n_check:
    mov current_cars, eax
    jmp greater_selected

west_greater:
    mov eax, west_queue
    jmp w_check

south_greater:
    mov eax, south_queue
    jmp s_check

east_greater:
    mov eax, east_queue
    jmp e_check

greater_selected:
    mov eax, FOUR_DIRECTIONS
    call RandomRange
    cmp eax, 0
    je inc_north
    cmp eax, 1
    je inc_west
    cmp eax, 2
    je inc_east
    cmp eax, 3
    je inc_south
    jmp to_after

inc_north:
    call AddNorth
    jmp to_after
inc_south:
    call AddSouth
    jmp to_after
inc_east:
    call AddEast
    jmp to_after
inc_west:
    call AddWest

to_after:
    movzx eax, lights_state
    push phase_timer
    push eax
    call carsdec
    ret
StepTick ENDP

SaveReport PROC C USES ebx esi edi
    call file
    ret
SaveReport ENDP

END