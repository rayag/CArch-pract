masm
model	small
stack	256
.data 
; prompts
text_prompt db 'Enter text to encrypt (maximum length 200 symbols): $'
input_prompt db 'Enter text source: F = file, C = console. $'
filename_prompt db 'Enter the name of the file where result will be stored. $'
rfilename_prompt db 'Enter the name of the source file. $'
instructions db 'Enter 1 to encrypt.', 10, 'Enter 2 to decrypt', 10, 'Enter E to exit', 10,'$'
invalid_cmd db 'Invalid command. $'
invalid_decr db 'You cannot decrypt. Text is not encrypted. $'
cipher_text_msg db 'Encrypted text: $'
decipher_text_msg db 'Decrypted text: $'
; variables
filename db 'file1.txt', 0
rfilename db 50 dup(0)
text db 201 dup(0)
vig_keyword db 10 dup (0)
vig_key db 201 dup(0)
text_size dw 2
max_size dw 200
wfile_size dw 0
rfile_size dw 0
encr_cnt db 0
filehandle dw ('?')
rhandle dw ?
new_line db 10
.code
main:	
	mov	ax,@data
	mov	ds,ax
	
	call generate_random_keyword
	
	lea dx, filename_prompt
	mov ah, 09h
	int 21h
	
	lea bx, filename
	lea dx, wfile_size
	call read_input

show_input_prompt:
	lea dx, input_prompt
	mov ah, 09h
	int 21h
	
	mov ah, 1   ; read character
	int 21h
	
	cmp al, 46h ; compare to F
	je read_from_file
	cmp al, 43h ; compare to C
	je read_console
	mov ah, 2 ; print new line
	mov dl, 10
	int 21h
	jmp show_input_prompt
	
read_from_file:	
	mov ah, 2 ; print new line
	mov dl, 10
	int 21h
	mov ah, 9 ; print prompt for read filename
	lea dx, rfilename_prompt
	int 21h
	
	lea bx, rfilename
	lea dx, rfile_size
	call read_input

	mov ah, 3dh ; open file
	mov al, 0   ; for read
	mov dx, offset rfilename
	int 21h
	mov rhandle, ax  
	
	mov ah, 3fh  ; read from file
	lea dx, text
	mov cx, 200
	mov bx, rhandle 
	int 21h
	mov cx, 10
	mov si, 0
	
	call find_text_size ; determine size of text
	mov dx, text_size
	; add dl, 30h
	; mov ah, 2
	; int 21h
	mov ah, 3eh  ; close file
	mov bx, rhandle
	int 21h
	jmp print_instructions
	
read_console:	
	mov ah, 2 ; print new line
	mov dl, 10
	int 21h
	lea dx, text_prompt
	mov ah, 09h
	int 21h
	lea bx, text
	lea dx, text_size
	call read_input
		
print_instructions:	
	mov ah, 09h
	lea dx, instructions
	int 21h
	
	mov ah, 3ch  ; create write file
	mov cx, 0
	mov dx, offset filename
	int 21h
	mov filehandle, ax
	
	call generate_vig_key
	
exec:
	mov ah, 01h
	int 21h
	mov bl, al
	mov ah, 2
	mov dl, 10
	int 21h
	mov al, bl
	cmp al, 31h
	je encryption
	cmp al, 32h
	je decryption
	cmp al, 45h
	je exit
	jmp invalid_command
	
encryption:
	mov ah, 09h
	lea dx, cipher_text_msg
	int 21h
	lea bx, text
	call encrypt_vig
	call xor_en
	call print_text		
	inc encr_cnt ; increment encryption count
	mov ah, 2    ; print new line
	mov dl, 10
	int 21h
	jmp exec
	
decryption:
	mov ah, encr_cnt
	cmp ah, 0
	jle decryption_forbidded
	mov ah, 09h
	lea dx, decipher_text_msg
	int 21h
	lea bx, text
	call xor_en
	call decrypt_vig
	call print_text
	dec encr_cnt
	mov ah, 2h
	mov dl, 10
	int 21h
	jmp exec
	
invalid_command:
	mov ah, 09h
	lea dx, invalid_cmd
	int 21h
	mov ah, 2
	mov dl, 10
	int 21h
	jmp exec
	
decryption_forbidded:
	mov ah, 09h
	lea dx, invalid_decr
	int 21h
	mov ah, 2
	mov dl, 10
	int 21h
	jmp exec
	
exit:
	mov ah, 3eh
	mov bx, filehandle
	int 21h
	mov	ax,4c00h	
	int	21h
	
	

; Reads text from console until
; Enter (Carriege Return) is pressed
; or until 200 symbols are entered
; saves input to the addressed stored
; in bx
read_input proc	
	xor si, si
	mov cx, max_size
	push dx
	lread:
		mov ah, 1h
		int 21h
		cmp al, 0dh ; stop input if Enter pressed
		je end_read	
		mov bx[si], al
		inc si
		loop lread
	end_read:
		pop dx
		mov bx, dx
		mov [bx], si
	ret
endp read_input

; TODO
print_text proc
	xor si, si
	mov cx, text_size
	push bx
	lpr:
		mov ah, 02h
		mov dl, bx[si]
		int 21h
		inc si
		loop lpr
	pop bx
	mov ah, 40h   ; write result in file
	mov dx, bx
	mov bx, filehandle
	mov cx, text_size
	int 21h
	mov ah, 40h
	mov dx, offset new_line
	mov bx, filehandle
	mov cx, 1
	int 21h
	ret
print_text endp
 
xor_en proc
	xor si, si
	mov cx, text_size
	mov ax, 0
	lencr:
		mov al, bx[si]
		xor al, vig_key[si]
		;xchg dx, bx
		mov bx[si], al
		;chg bx, dx
		inc si
		loop lencr
	ret
xor_en endp

; Generates key for the Vignere enrcryption
; by repeating the keyword until the length 
; of the message is reached
generate_vig_key proc
	mov cx, text_size
	xor si, si
	mov bx, 3
	lgen:
		xor dx, dx
		mov ax, si
		div bx
		mov di, dx ; move remainder in di
		mov al, vig_keyword[di]
		mov vig_key[si], al
		inc si
		loop lgen
	ret
generate_vig_key endp

encrypt_vig proc
	mov cx, text_size
	xor si, si
	push bx
	lvingen:
		xor dx, dx
		xor ax, ax
		pop bx              ; load plain text addr in bx
		mov dl, bx[si]
		push bx
		mov al, vig_key[si] ; load key value in al
		add ax, dx          ; add pi and ki
		mov dl, 0   
		mov bx, 255
		div bx              ; mod 255 (result in dx)
		pop bx              ; load encrypted addr in bx
		mov bx[si], dl
		push bx
		inc si
		loop lvingen
	pop bx
	ret
encrypt_vig endp

decrypt_vig proc
	mov cx, text_size
	xor si, si
	push bx
	ldecr:
		xor dx, dx
		xor ax, ax
		pop bx
		mov al, bx[si]
		push bx
		add ax, 255
		mov dl, vig_key[si]
		sub ax, dx
		xor dl, dl
		mov bx, 255
		div bx
		pop bx
		mov bx[si], dl
		push bx
		inc si
		loop ldecr
	pop bx
	ret
decrypt_vig endp

generate_random_keyword:
	mov cx, 5
	xor si, si
	lkey:
		xor ax, ax
		push cx
		int 1ah
		mov ax, dx
		mov vig_keyword[si], al
		inc si
		mov vig_keyword[si], ah
		inc si
		pop cx
		loop lkey
	ret		

find_text_size proc
	xor si, si
	lsize:
		cmp text[si], 0
		je found
		inc si
		jmp lsize
	found:
		mov text_size, si
	ret
find_text_size endp

end main

