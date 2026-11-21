.586 ; for using rdtsc instruction
.model flat, C ; define C calling convention 
OPTION CASEMAP:NONE ; ensure case-sensitivity 

CreateFileA PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
WriteFile   PROTO STDCALL :DWORD,:DWORD,:DWORD,:DWORD,:DWORD
CloseHandle PROTO STDCALL :DWORD
includelib kernel32.lib

GENERIC_WRITE         EQU 40000000h
CREATE_ALWAYS         EQU 2
FILE_ATTRIBUTE_NORMAL EQU 80h
INVALID_HANDLE_VALUE  EQU -1

PUBLIC AddTraffic, StepTick, SaveReport

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
;the bit set in each mask indicates the current active state
NORTH_GREEN  EQU 00000001b  
NORTH_YELLOW EQU 00000010b
EAST_GREEN   EQU 00000100b
EAST_YELLOW  EQU 00001000b
SOUTH_GREEN  EQU 00010000b
SOUTH_YELLOW EQU 00100000b
WEST_GREEN   EQU 01000000b
WEST_YELLOW  EQU 10000000b

FOUR_DIRECTIONS EQU 4 ; number of directions
BASE_GREEN_TIME  EQU 10 ; Minimum Time for green light
MAX_GREEN_TIME   EQU 120 ; Maximum Time for green light
BASE_YELLOW_TIME EQU 3 ; Time for yellow light
SINGLE_CAR_TIME  EQU 2 ; Time for single car to pass

;Lookup table with even indicies for green light 
;and odd for yellow light
;Helps save comparing every mask to decide current and next state
state_arr BYTE NORTH_GREEN, NORTH_YELLOW, 
               EAST_GREEN, EAST_YELLOW,
               SOUTH_GREEN, SOUTH_YELLOW,
               WEST_GREEN, WEST_YELLOW

lights_state   BYTE NORTH_GREEN ; Current state of traffic lights
current_phase  BYTE 0 ; Current phase in finite-state machine (FSM)
phase_timer    DWORD (BASE_GREEN_TIME + MAX_GREEN_TIME) / 2 ; Timer for current active traffic light

;Queue lengths for each direction
north_queue    DWORD 0
south_queue    DWORD 0
east_queue     DWORD 0
west_queue     DWORD 0

;metrices to keep track of for filing
total_in       DWORD 0
total_out      DWORD 0
current_cars   DWORD 0
peak_queue     DWORD 0
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

ticks  DWORD 0 ; simualation loop counter(time-stamp)
prev_val DWORD ? 
north_departs  DWORD 0
east_departs   DWORD 0
south_departs  DWORD 0
west_departs   DWORD 0

phase_names BYTE "North Green  ",0
            BYTE "North Yellow ",0
            BYTE "East Green   ",0
            BYTE "East Yellow  ",0
            BYTE "South Green  ",0
            BYTE "South Yellow ",0
            BYTE "West Green   ",0
            BYTE "West Yellow  ",0
;filing labels for formatted output to file
labelnorth BYTE "North Queue ", 0
labelwest BYTE "West Queue ", 0
labeleast  BYTE "East Queue ", 0
labelsouth BYTE "SOUTH Queue ", 0
labelin BYTE "Total Cars Going in ", 0
labelout BYTE "Total Cars Going out ", 0
labelmax BYTE "Max Queue ", 0
labelmaxtime BYTE "Time for Maximum ", 0
labelnorthmaxtime BYTE "Max North time ", 0
labelsouthmaxtime BYTE "Max South time ", 0
labeleastmaxtime BYTE "Max East time ", 0
labelwestmaxtime BYTE "Max West time ", 0
labeltotalnorth BYTE "Total North Cars ", 0
labeltotalwest BYTE "Total West Cars ", 0
labeltotaleast BYTE "Total East Cars ", 0
labeltotalsouth BYTE "Total South Cars ", 0
labelmaxnorth BYTE "Max North Cars ", 0
labelmaxwest BYTE "Max West Cars ", 0
labelmaxeast BYTE "Max East Cars ", 0
labelmaxsouth BYTE "Max South Cars ", 0

bufferlen DWORD 0
buffer  BYTE 2000 DUP(0)
filename BYTE "traffic.txt", 0
filehandle DWORD 0

bytesWritten DWORD 0
rng_set BYTE 0

.code
;uses adpative formuala to return duration of green light in ecx:
;min(Current_Queue_Len*SINGLE_CAR_TIME+BASE_GREEN_TIME,MAX_GREEN_TIME)
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
;updates the current state and light timer if it has ended
updateFSM PROC USES eax ebx ecx edi
    MOV ecx, phase_timer
    DEC ecx
    TEST ecx, ecx ; check if ecx=0 meaning time has ended
    JNZ _out      ; if ecx!=0 leave function

    MOVZX eax, current_phase
    INC eax ; transition to next phase in fsm
    CMP eax, 7 
    JNA _notReset ;if phase<7 then skip 
    XOR eax, eax  ;else wrap it back to 0

_notReset:
 	LEA edi, [state_arr + eax * TYPE state_arr] ;used to interpret current_phase quickly
	MOV bl, [edi] ;
	MOV lights_state, bl ;update current state of lights
	TEST eax, 1 ;checking for even indices
	JZ _greenLight ;even=green light
	MOV ecx, BASE_YELLOW_TIME ;yellow lights have fixed time
	JMP _setPhase

_greenLight:
;check for direction and point esi to it 
	TEST eax, eax 
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
	CALL adaptiveTimer ;update timer with queue passed through esi
_setPhase:
	MOV current_phase, al

_out:
	MOV phase_timer, ecx ;move timer from ecx to variable
	RET
updateFSM ENDP

WriteLabel PROC ; Copies string into buffer
push eax

WriteLoop: loop; if theres letter save it loop until end . if not jump to end
mov al, [esi]
cmp al, 0
je WriteEnd
mov [edi], al
inc esi
inc edi
inc bufferlen
jmp WriteLoop

WriteEnd: ; ENd of write proc
pop eax
ret
WriteLabel ENDP

WriteNumber Proc ; Convets integers in EAX to ASCII characters and saves in buffer
push eax
push ebx
push ecx
push edx
mov ebx, 10
xor ecx, ecx

GetDigits: ; Get digits from right to left
xor edx, edx
div ebx
add dl, '0'
push edx
inc ecx
test eax, eax
jnz GetDigits

SaveDigits:  ; Loop to pop digits from left to right
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

file PROC          ; File Handling
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
_fileDone:  ; End of file handling
    ret
file ENDP

carsdec PROC  ; Dec cars
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

subnorth:  ; subtracts cars from current north queue
    cmp north_queue, 0
    je DONE
    mov esi, OFFSET north_queue
    dec DWORD PTR [esi]
    inc north_departs
    inc total_out
    jmp DONE

subeast:   ; subtracts cars from current east queue
    cmp east_queue, 0
    je DONE
    mov esi, OFFSET east_queue
    dec DWORD PTR [esi]
    inc east_departs
    inc total_out
    jmp DONE

subwest:   ; subtracts cars from current west queue
    cmp west_queue, 0
    je DONE
    mov esi, OFFSET west_queue
    dec DWORD PTR [esi]
    inc west_departs
    inc total_out
    jmp DONE

subsouth:   ; subtracts cars from current south queue
    cmp south_queue, 0
    je DONE
    mov esi, OFFSET south_queue
    dec DWORD PTR [esi]
    inc south_departs
    inc total_out

DONE:  ; End of cars dec function
    pop ebx
    pop eax
    pop ebp
    ret 8
carsdec ENDP

AddNorth PROC  ; Adds a car to north queue
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
_chk_max_q_n:   ; updates peak queue if north more than peak queue
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

AddSouth PROC  ; Adds a car to south queue
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
_chk_max_q_s:  ; updates peak queue if south more than peak queue
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

AddEast PROC  ; Adds a car to east queue
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
_chk_max_q_e:   ; updates peak queue if east more than peak queue
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

AddWest PROC  ; Adds a car to west queue
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
_chk_max_q_w:  ; updates peak queue if west more than peak queue
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

RandomRange PROC     ; Geneates a reandom integer
push ebx
push edx

cmp rng_set, 0
jnz _skip
push eax
rdtsc 
mov prev_val, eax
mov rng_set, 1
pop eax
_skip:
    mov ebx, eax
    mov eax, prev_val
    mov edx, 1664525
    mul edx
    add eax, 13904223
    mov prev_val, eax
    shr eax, 16
    xor edx, edx
    div ebx
    mov eax, edx
pop edx
pop ebx
ret
RandomRange ENDP

AddTraffic PROC C USES ebx esi edi, lane:DWORD   ; Adds a car 
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
_addN:                        ; adds car to north lane
    call AddNorth
    jmp _addDone
_addE:                       ; adds car to east lane
    call AddEast
    jmp _addDone
_addS:                          ; adds car to south lane
    call AddSouth
    jmp _addDone
_addW:                      ; adds car to west lane
    call AddWest
_addDone:
    ret
AddTraffic ENDP

StepTick PROC C USES ebx esi edi             ; advance simulation by 1 tick
    call updateFSM
    inc ticks

    mov eax, north_queue
    mov ebx, south_queue
    cmp eax, ebx
    jbe south_greater
s_check:                 ; compares current max to south queue
    mov ebx, east_queue
    cmp eax, ebx
    jbe east_greater
    jmp e_check
e_check:         ; compares current max to east queue
    mov ebx, west_queue
    cmp eax, ebx
    jbe west_greater
    jmp n_check
w_check:        ; compares current max to west queue
    mov current_cars, ebx
    jmp greater_selected

n_check:                 ; compares current max to north queue
    mov current_cars, eax
    jmp greater_selected

west_greater:             ; west is greater
    mov eax, west_queue
    jmp w_check

south_greater:            ; south is greater
    mov eax, south_queue
    jmp s_check

east_greater:              ; east is greater
    mov eax, east_queue
    jmp e_check

greater_selected:            ; get random number and inc by the corresponding direction for the value
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

inc_north:          ; inc north queue
    call AddNorth
    jmp to_after
inc_south:          ; inc south queue
    call AddSouth
    jmp to_after
inc_east:          ; inc east queue
    call AddEast
    jmp to_after
inc_west:           ; inc west queue
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
