labelnorth BYTE "North Queue: ", 0
labelwest BYTE "West Queue: ", 0
labeleast BYTE "East Queue: ", 0
labelsouth BYTE "SOUTH Queue ", 0
labelin BYTE "Total Cars Going in: ", 0
labelout BYTE "Total Cara Going out: ", 0
labelmax BYTE "Max Queue: ", 0
labelmaxtime BYTE "Time for Maximum: ", 0
labelnorthmaxtime BYTE "Max North time ", 0
labelsouthmaxtime BYTE "Max South time ", 0
labeleastmaxtime BYTE "Max East time ", 0
labelwestmaxtime BYTE "Max West time ", 0
labeltotalnorth BYTE "Total North Cars", 0
labeltotalwest BYTE "Total West Cars", 0
labeltotaleast BYTE "Total East Cars", 0
labeltotalsouth BYTE "Total South Cars", 0


file PROC
mov bufferlen, 0
mov edi, OFFSET buffer

mov esi, OFFSET labeltotalnorth
call WriteLabel
mov eax, total_north_queue
call WriteNumber

mov esi, OFFSET labeltotalwest
call WriteLabel
mov eax, total_west_queue
call WriteNumber

mov esi, OFFSET labeltotaleast
call WriteLabel
mov eax, total_east_queue
call WriteNumber

mov esi, OFFSET labeltotalsouth
call WriteLabel
mov eax, total_south_queue
call WriteNumber

mov esi, OFFSET labelmaxtime
call WriteLabel
mov eax, time_max_queue
call WriteNumber

mov esi, OFFSET labelnorthmaxtime
call WriteLabel
mov eax, time_north_max_queue
call WriteNumber

mov esi, OFFSET labelsouthmaxtime
call WriteLabel
mov eax, time_south_max_queue
call WriteNumber

mov esi, OFFSET labeleastmaxtime
call WriteLabel
mov eax, time_east_max_queue
call WriteNumber

mov esi, OFFSET labelwestmaxtime
call WriteLabel
mov eax, time_west_max_queue
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
CAll Createoutputfile
mov filehandle, eax

mov eax, filehandle
mov edx, OFFSET buffer
mov ecx, bufferlen
Call Writetofile

mov eax, filehandle
call Closefile
ret
File ENDP
