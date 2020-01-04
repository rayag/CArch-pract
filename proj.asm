masm
model	small
stack	256
.data 
hello_message db 'Enter text to encrypt (maximum length 200 symbols): $'
cypher_text_msg db 'Cyphered text: $'
decypher_text_msg db 'Decyphered text: $'
text db 201 dup(0)
;text db 'He'
vig_keyword db 'abc'
vig_key db 201 dup(0)
encrypted db 201 dup(0)
temp db 201 dup(0)
text_size dw 2
max_size dw 200
xor_key db 13


.code
main:	
	mov	ax,@data
	mov	ds,ax
	
	lea bx, text
	call read_input
	
	call generate_vig_key	
	
	lea bx, text
	lea dx, encrypted
	call encrypt_vig
	
	mov ah, 02h
	mov dl, 10
	int 21h
	lea bx, encrypted
	call print_text
	
	mov ah, 02h
	mov dl, 10
	int 21h
	
	lea bx, encrypted
	call xor_en
	lea bx, encrypted
	call print_text
	
	mov ah, 02h
	mov dl, 10
	int 21h
	
	lea bx, encrypted
	call xor_en
	lea bx, encrypted
	call print_text
	
	
	lea bx, encrypted
	lea dx, temp
	call decrypt_vig
	
	lea bx, temp
	call print_text
	
	mov	ax,4c00h	
	int	21h
	
	

; Reads text from console until
; Enter (Carriege Return) is pressed
; or until 200 symbols are entered
; saves input to the addressed stored
; in bx
read_input proc
	lea dx, hello_message
	mov ah, 09h
	int 21h
	
	xor si, si
	mov cx, max_size
	lread:
		mov ah, 1h
		int 21h
		cmp al, 0dh ; stop input if Enter pressed
		je end_read	
		mov bx[si], al
		inc si
		loop lread
	end_read:
	mov text_size, si
	ret
endp read_input

; TODO
print_text proc
	xor si, si
	mov cx, text_size
	lpr:
		mov ah, 02h
		mov dl, bx[si]
		int 21h
		inc si
		loop lpr	
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
	push dx ; encrypted
	push bx ; plain
	lvingen:
		xor dx, dx
		xor ax, ax
		pop bx              ; load plain text addr in bx
		mov dl, bx[si]
		mov di, bx
		mov al, vig_key[si] ; load key value in al
		add ax, dx          ; add pi and ki
		mov dl, 0   
		mov bx, 255
		div bx              ; mod 255 (result in dx)
		pop bx              ; load encrypted addr in bx
		mov bx[si], dl
		push bx
		push di
		inc si
		loop lvingen
	pop bx
	pop bx
	ret
encrypt_vig endp

decrypt_vig proc
	mov cx, text_size
	xor si, si
	push dx 
	push bx
	ldecr:
		xor dx, dx
		xor ax, ax
		pop bx
		mov al, bx[si]
		mov di, bx
		add ax, 255
		mov dl, vig_key[si]
		sub ax, dx
		xor dl, dl
		mov bx, 255
		div bx
		pop bx
		mov bx[si], dl
		push bx
		push di
		inc si
		loop ldecr
	pop bx
	pop bx
	ret
decrypt_vig endp

end main