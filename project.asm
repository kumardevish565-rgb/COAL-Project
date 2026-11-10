INCLUDE irvine32.inc
.data
cars_north DWORD 0
cars_south DWORD 0
cars_east DWORD 0
cars_west DWORD 0
TIMER BYTE 0
current_cars DWORD 0
.code
MAIN PROC
mov eax, cars_north
mov current_cars, eax
mov ebx, cars_south
cmp eax, ebx
jbe south_greater
s_is_g:
mov ebx, cars_east
cmp eax,ebx
jbe east_greater
jmp e_is_g
e_is_g:
mov ebx, cars_west
cmp eax, ebx
jbe west_greater
jmp n_is_g
w_is_g:
mov current_cars, ebx
n_is_g:
mov current_cars, eax
jmp greater_selected

west_greater:
mov eax, cars_west
jmp w_is_g

south_greater:
mov eax, cars_south
jmp s_is_g

east_greater:
mov eax, cars_east
jmp e_is_g

greater_selected:
call ReadKey
jz No_input
and al, 11011111b
cmp al, 'N'
je inc_north
cmp al, 'W'
je inc_west
cmp al, 'E'
je inc_east
cmp al, 'S'
je inc_south

no_input:
jmp to_after

inc_north:
inc cars_north
jmp to_after

inc_south:
inc cars_south
jmp to_after

inc_east:
inc cars_east
jmp to_after

inc_west:
inc cars_west
jmp to_after

to_after:
Jmp MAIN


exit
MAIN ENDP
END MAIN
