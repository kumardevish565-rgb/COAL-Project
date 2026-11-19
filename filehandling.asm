call file // before main end
filename BYTE "Smart Traffic Grid System.txt" , 0
buffer BYTE 1024 DUP (0)
filehandle HANDLE ?
bufferlen DWORD 0
labelnorth BYTE "North Queue: ", 0
labelwest BYTE "West Queue: ", 0
labeleast BYTE "East Queue: ", 0
labelsouth BYTE "SOUTH Queue ", 0
labelin BYTE "Total Cars Going in: ", 0
labelout BYTE "Total Cars Going out: ", 0
labelmax BYTE "Max Queue: ", 0
labelmaxtime BYTE "Time for Maximum: ", 0
labelnorthmaxtime BYTE "Max North time ", 0
labelsouthmaxtime BYTE "Max South time ", 0
labeleastmaxtime BYTE "Max East time ", 0
labelwestmaxtime BYTE "Max West time ", 0
labeltotalnorth BYTE "Total North Cars ", 0
labeltotalwest BYTE "Total West Cars ", 0
labeltotaleast BYTE "Total East Cars ", 0
labeltotalsouth BYTE "Total South Cars ", 0
labelmaxnorth BYTE "Max North Cars: ", 0
labelmaxwest BYTE "Max West Cars: ", 0
labelmaxeast BYTE "Max East Cars: ", 0
labelmaxsouth BYTE "Max South Cars: ", 0

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
mov eax, current_cars
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
CAll CreateOutputFile
mov filehandle, eax

mov eax, filehandle
mov edx, OFFSET buffer
mov ecx, bufferlen
Call WriteToFile

mov eax, filehandle
call CloseFile
ret
file ENDP

WriteLabel PROC
push eax

Writeloop:
mov al, [esi]
cmp al, 0
je WriteEnd
mov [edi], al
inc esi
inc esi
inc bufferlen
jmp WriteLoop

WriteEnd:
pop eax
ret
WriteLabel ENDP

WriteNumber Proc
puxh eax
puxh ebx
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
pop ebx
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
