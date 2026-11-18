INCLUDE irvine32.inc
.data
north_queue DWORD 0
south_queue DWORD 0
east_queue DWORD 0
west_queue DWORD 0
total_in DWORD 0
total_out DWORD 0
TIMER BYTE 0
current_cars DWORD 0
.code
MAIN PROC

call Randomize

MainLoop:
mov eax, north_queue
mov current_cars, eax
mov ebx, south_queue
cmp eax, ebx
jbe south_greater
s_check:
mov ebx, east_queue
cmp eax,ebx
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
cmp eax,3
je inc_south

jmp to_after

inc_north:
mov esi, OFFSET north_queue
inc DWORD PTR [esi]
mov edi, OFFSET total_north_cars
inc DWORD PTR [edi]
inc total_in
inc max_north_queue
jmp to_after

inc_south:
mov esi, OFFSET south_queue
inc DWORD PTR [esi]
mov edi, OFFSET total_south_cars
inc DWORD PTR [edi]
inc total_in
inc max_south_queue
jmp to_after

inc_east:
mov esi, OFFSET east_queue
inc DWORD PTR [esi]
mov edi, OFFSET total_east_cars
inc DWORD PTR [edi]
inc total_in
inc max_east_queue
jmp to_after

inc_west:
mov esi, OFFSET west_queue
inc DWORD PTR [esi]
mov edi, OFFSET total_west_cars
inc DWORD PTR [edi]
inc total_in
inc max_west_queue
jmp to_after

to_after:

movzx eax, lights_state
push phase_timer
push eax

Call carsdec

mov eax, 1000
Call Delay
Jmp MainLoop

exit
MAIN ENDP

carsdec PROC

push ebp
mov ebp, esp
push eax
mov ebx, [ebp + 12]
Push ebp
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
inc total_out
jmp DONE

subeast:
cmp east_queue, 0
je DONE
mov esi, OFFSET east_queue
dec DWORD PTR [esi]
inc total_out
jmp DONE

subwest:
cmp west_queue, 0
je DONE
mov esi, OFFSET west_queue
dec DWORD PTR [esi]
inc total_out
jmp DONE

subsouth:
cmp south_queue, 0
je DONE
mov esi, OFFSET south_queue
dec DWORD PTR [esi]
inc total_out

DONE:
pop ebx
pop eax
pop ebp
ret 8
carsdec ENDP

END MAIN
