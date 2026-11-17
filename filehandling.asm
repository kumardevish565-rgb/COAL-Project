labelmax BYTE "Max Queue: ", 0
 
file PROC
mov bufferlen, 0
mov edi, OFFSET buffer
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
