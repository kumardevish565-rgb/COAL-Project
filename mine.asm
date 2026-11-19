include Irvine32.inc

.data
NORTH_GREEN  EQU 00000001b
NORTH_YELLOW EQU 00000010b
EAST_GREEN   EQU 00000100b
EAST_YELLOW  EQU 00001000b
SOUTH_GREEN  EQU 00010000b
SOUTH_YELLOW EQU 00100000b
WEST_GREEN   EQU 01000000b
WEST_YELLOW  EQU 10000000b

BASE_GREEN_TIME  EQU 10 ; Minimum Time for green light
MAX_GREEN_TIME   EQU 120 ; Maximum Time for green light
BASE_YELLOW_TIME EQU 3 ; Time for yellow light
SINGLE_CAR_TIME  EQU 2 ; Time for single car to pass

CLR_RED   EQU 12
CLR_GRN   EQU 10
CLR_YEL   EQU 14
CLR_WHT   EQU 15
CLR_GRY   EQU 7
CLR_TITLE EQU 1Fh

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

lane_names  BYTE "North_Queue  ",0
            BYTE "East_Queue   ",0
            BYTE "South_Queue  ",0
            BYTE "West_Queue   ",0

titleStr  BYTE 17 DUP(' '),"[ ** SMART TRAFFIC GRID SIMULATION v1.0 ** ]",18 DUP(' '),0
sepStr    BYTE 79 DUP('-'),0
timeLbl   BYTE "System Time: ",0
ticksLbl  BYTE " (Ticks: ",0
phaseLbl  BYTE ")  |  Active Phase: ",0

hdrN BYTE "[ NORTH LANE ]",0
hdrE BYTE "[ EAST LANE ] ",0
hdrS BYTE "[ SOUTH LANE ]",0
hdrW BYTE "[ WEST LANE ] ",0

lightsLbl BYTE "Lights: ",0
grnTxt    BYTE "** GREEN ** (Go!)   ",0
yelTxt    BYTE "** YELLOW ** (Slow) ",0
redTxt    BYTE "** RED ** (Wait)    ",0
queueLbl  BYTE "Queue: ",0
vehLbl    BYTE " Vehicles (0x",0
departLbl BYTE "Departures: ",0

bulbStr   BYTE "(O)",0

roadV BYTE "       |  :  |       ",0
roadW BYTE "-------+     +-------",0
roadS BYTE 21 DUP(' '),0
roadC BYTE "- - - -       - - - -",0

pmHdr     BYTE "[ PHASE MANAGER ]",0
nowLbl    BYTE "Now:  ",0
timerLbl  BYTE "Timer: ",0
nextLbl   BYTE "Next: ",0
secStr    BYTE "s  ",0

barStr    BYTE " Space:Tick Esc:Exit NESW:Add Log:PENDING ESI:",0
barTail   BYTE 4 DUP(' '),0

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
    TEST ecx, ecx
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
	CALL adaptiveTimer
_setPhase:
	MOV current_phase, al

_out:
	MOV phase_timer, ecx
	RET
updateFSM ENDP

PrintPad2 PROC USES eax ebx edx
    CMP eax, 99
    JBE _ok
    MOV eax, 99
_ok:
    XOR edx, edx
    MOV ebx, 10
    DIV ebx
    ADD al, '0'
    PUSH edx
    CALL WriteChar
    POP eax
    ADD al, '0'
    CALL WriteChar
    RET
PrintPad2 ENDP

PrintPad3 PROC USES eax ebx edx
    CMP eax, 999
    JBE _ok
    MOV eax, 999
_ok:
    XOR edx, edx
    MOV ebx, 100
    DIV ebx
    ADD al, '0'
    PUSH edx
    CALL WriteChar
    POP eax
    CALL PrintPad2
    RET
PrintPad3 ENDP

PrintPhaseName PROC USES eax edx
    AND eax, 7
    IMUL eax, eax, 14
    LEA edx, [phase_names + eax]
    CALL WriteString
    RET
PrintPhaseName ENDP

SetPhaseColour PROC USES eax ebx
    MOV ebx, CLR_GRN
    TEST al, 1
    JZ _c
    MOV ebx, CLR_YEL
_c:
    MOV eax, ebx
    CALL SetTextColor
    RET
SetPhaseColour ENDP

GetLightInfo PROC
    MOV al, lights_state
    TEST al, bl
    JNZ _g
    TEST al, bh
    JNZ _y
    MOV eax, CLR_RED
    MOV edx, OFFSET redTxt
    RET
_y:
    MOV eax, CLR_YEL
    MOV edx, OFFSET yelTxt
    RET
_g:
    MOV eax, CLR_GRN
    MOV edx, OFFSET grnTxt
    RET
GetLightInfo ENDP

DrawLane PROC USES eax ebx edx esi, yPos:DWORD, hdr:PTR BYTE, masks:DWORD, qPtr:PTR DWORD, dPtr:PTR DWORD
    MOV dl, 1
    MOV dh, BYTE PTR yPos
    CALL Gotoxy
    MOV eax, CLR_YEL
    CALL SetTextColor
    MOV edx, hdr
    CALL WriteString

    MOV dl, 1
    MOV dh, BYTE PTR yPos
    INC dh
    CALL Gotoxy
    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV edx, OFFSET lightsLbl
    CALL WriteString
    MOV ebx, masks
    CALL GetLightInfo
    CALL SetTextColor
    CALL WriteString

    MOV dl, 1
    MOV dh, BYTE PTR yPos
    ADD dh, 2
    CALL Gotoxy
    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV edx, OFFSET queueLbl
    CALL WriteString
    MOV esi, qPtr
    MOV eax, [esi]
    CALL PrintPad3
    MOV edx, OFFSET vehLbl
    CALL WriteString
    MOV eax, qPtr
    CALL WriteHex
    MOV al, ')'
    CALL WriteChar

    MOV dl, 1
    MOV dh, BYTE PTR yPos
    ADD dh, 3
    CALL Gotoxy
    MOV edx, OFFSET departLbl
    CALL WriteString
    MOV esi, dPtr
    MOV eax, [esi]
    CALL PrintPad3
    RET
DrawLane ENDP

DrawLight PROC USES eax ebx edx, x:DWORD, y:DWORD, masks:DWORD, lx:DWORD, ly:DWORD, lbl:DWORD
    MOV ebx, masks
    CALL GetLightInfo
    CALL SetTextColor
    MOV dl, BYTE PTR x
    MOV dh, BYTE PTR y
    CALL Gotoxy
    MOV edx, OFFSET bulbStr
    CALL WriteString
    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV dl, BYTE PTR lx
    MOV dh, BYTE PTR ly
    CALL Gotoxy
    MOV eax, lbl
    CALL WriteChar
    RET
DrawLight ENDP

DrawIntersection PROC USES eax ecx edx
    MOV eax, CLR_GRY
    CALL SetTextColor
    XOR ecx, ecx
_row:
    MOV dl, 37
    MOV dh, cl
    ADD dh, 3
    CALL Gotoxy
    MOV edx, OFFSET roadV
    CMP ecx, 7
    JB _print
    CMP ecx, 11
    JA _print
    MOV edx, OFFSET roadW
    CMP ecx, 7
    JE _print
    CMP ecx, 11
    JE _print
    MOV edx, OFFSET roadS
    CMP ecx, 9
    JNE _print
    MOV edx, OFFSET roadC
_print:
    CALL WriteString
    INC ecx
    CMP ecx, 19
    JB _row
    RET
DrawIntersection ENDP

display PROC USES eax ebx ecx edx
    MOV eax, CLR_TITLE
    CALL SetTextColor
    MOV dl, 0
    MOV dh, 0
    CALL Gotoxy
    MOV edx, OFFSET titleStr
    CALL WriteString

    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV dl, 1
    MOV dh, 1
    CALL Gotoxy
    MOV edx, OFFSET timeLbl
    CALL WriteString

    MOV eax, ticks
    XOR edx, edx
    MOV ebx, 3600
    DIV ebx
    CALL PrintPad2
    PUSH edx
    MOV al, ':'
    CALL WriteChar
    POP edx
    MOV eax, edx
    XOR edx, edx
    MOV ebx, 60
    DIV ebx
    CALL PrintPad2
    PUSH edx
    MOV al, ':'
    CALL WriteChar
    POP edx
    MOV eax, edx
    CALL PrintPad2

    MOV edx, OFFSET ticksLbl
    CALL WriteString
    MOV eax, ticks
    CALL WriteDec
    MOV edx, OFFSET phaseLbl
    CALL WriteString
    MOVZX eax, current_phase
    CALL SetPhaseColour
    CALL PrintPhaseName

    MOV eax, CLR_GRY
    CALL SetTextColor
    MOV dl, 0
    MOV dh, 2
    CALL Gotoxy
    MOV edx, OFFSET sepStr
    CALL WriteString
    MOV dl, 0
    MOV dh, 22
    CALL Gotoxy
    MOV edx, OFFSET sepStr
    CALL WriteString

    INVOKE DrawLane, 3,  ADDR hdrN, (NORTH_YELLOW SHL 8) OR NORTH_GREEN, ADDR north_queue, ADDR north_departs
    INVOKE DrawLane, 8,  ADDR hdrE, (EAST_YELLOW  SHL 8) OR EAST_GREEN,  ADDR east_queue,  ADDR east_departs
    INVOKE DrawLane, 13, ADDR hdrS, (SOUTH_YELLOW SHL 8) OR SOUTH_GREEN, ADDR south_queue, ADDR south_departs
    INVOKE DrawLane, 18, ADDR hdrW, (WEST_YELLOW  SHL 8) OR WEST_GREEN,  ADDR west_queue,  ADDR west_departs

    CALL DrawIntersection
    INVOKE DrawLight, 46, 6,  (NORTH_YELLOW SHL 8) OR NORTH_GREEN, 47, 4,  'N'
    INVOKE DrawLight, 53, 13, (EAST_YELLOW  SHL 8) OR EAST_GREEN,  57, 13, 'E'
    INVOKE DrawLight, 46, 18, (SOUTH_YELLOW SHL 8) OR SOUTH_GREEN, 47, 20, 'S'
    INVOKE DrawLight, 39, 11, (WEST_YELLOW  SHL 8) OR WEST_GREEN,  37, 11, 'W'

    MOV eax, CLR_YEL
    CALL SetTextColor
    MOV dl, 59
    MOV dh, 3
    CALL Gotoxy
    MOV edx, OFFSET pmHdr
    CALL WriteString

    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV dl, 59
    MOV dh, 4
    CALL Gotoxy
    MOV edx, OFFSET nowLbl
    CALL WriteString
    MOVZX eax, current_phase
    CALL SetPhaseColour
    CALL PrintPhaseName

    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV dl, 59
    MOV dh, 5
    CALL Gotoxy
    MOV edx, OFFSET timerLbl
    CALL WriteString
    MOV eax, phase_timer
    CALL PrintPad3
    MOV edx, OFFSET secStr
    CALL WriteString

    MOV dl, 59
    MOV dh, 6
    CALL Gotoxy
    MOV edx, OFFSET nextLbl
    CALL WriteString
    MOVZX eax, current_phase
    INC eax
    CALL PrintPhaseName

    MOV eax, CLR_TITLE
    CALL SetTextColor
    MOV dl, 0
    MOV dh, 23
    CALL Gotoxy
    MOV edx, OFFSET barStr
    CALL WriteString
    MOVZX eax, current_phase
    SHR eax, 1
    IMUL eax, eax, 14
    LEA edx, [lane_names + eax]
    CALL WriteString
    MOV edx, OFFSET barTail
    CALL WriteString

    MOV eax, CLR_WHT
    CALL SetTextColor
    MOV dl, 0
    MOV dh, 24
    CALL Gotoxy
    RET
display ENDP

WriteLabel PROC
push eax

Writeloop:
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

    mov edx, OFFSET filename
    CAll Createoutputfile
    mov filehandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je _fileDone

    mov eax, filehandle
    mov edx, OFFSET buffer
    mov ecx, bufferlen
    Call Writetofile

    mov eax, filehandle
    call Closefile
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

MAIN PROC
    call Randomize
    mov lights_state, NORTH_GREEN

MainLoop:
    call updateFSM
    call display
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
    call ReadKey
    jz no_input
    cmp al, 1Bh
    JE _leave
    and al, 11011111b
    cmp al, 'N'
    je inc_north
    cmp al, 'W'
    je inc_west
    cmp al, 'E'
    je inc_east
    cmp al, 'S'
    je inc_south
    jmp to_after

no_input:
    mov eax, 4
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
    jmp to_after

inc_south:
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
    jmp to_after

inc_east:
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
    jmp to_after

inc_west:
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
    jmp to_after

to_after:
    movzx eax, lights_state
    push phase_timer
    push eax
    call carsdec

    mov eax, 1000
    call Delay
    jmp MainLoop

_leave:
    CALL file
    EXIT
MAIN ENDP
END MAIN
