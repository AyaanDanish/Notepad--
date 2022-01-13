Include irvine32.inc
include macros.inc
Include winmm.inc
BUFFER_SIZE = 5000

TakeInput PROTO cursor_x:byte, cursor_y:byte
ClearBuffer PROTO, buf:ptr byte
UpdateFile PROTO, charsToWrite:dword

;Useful ASCII codes
BS equ 08h
ESCP equ 1bh
WS equ 20h 
ENT equ 0dh
Newline equ <0dh,0ah>

;For formatting purposes
indent equ "                                 "
separator equ "------------------------------------------------------------------------------------------------------------------------"
clearline equ "                                                                                                                        "

;Max editing space
COLUMNS equ 120
ROWS equ 36
MAX_X equ COLUMNS-1
MAX_Y equ ROWS-1

.data
;Sound file path definitions
startupsound byte "./Sounds/open.wav",0
clicksound byte "./Sounds/click.wav",0
errorsound byte "./Sounds/error.wav",0
quitsound byte "./Sounds/quit.wav",0

;Parameters for ReadConsoleOutputCharacter function
numRead dword ?
numWritten dword ?
loc COORD <0, 1>
hConsole HANDLE ?
nLength dword 10

;Error message definitions
InvalidEntryTitle byte "Your entry was invalid!",0
InvalidEntryMsg byte "You entered an invalid choice. Would you like to enter a different one?",0

invalidnametitle byte "Invalid File Name!",0
invalidnamemsg byte "The file name you entered either contains more than 15 characters or contains an illegal character.",
					" Would you like to enter a different one?",0

Notfoundtitle byte	"File Not Found!",0
Notfoundmsg byte	"File not found. Would you like to enter a different name?",0

InvalidPassTitle byte "Invalid Password!",0
InvalidPassMsg byte "You entered an incorrect password. Would you like to try again?",0

MatchingPassTitle byte "Passwords don't match!",0
MatchingPassMsg byte "The confirmation password did not match. Would you like to try again?",0

;Misc. definitions
searchWord byte 20 DUP (?)
deleteWord byte 20 DUP (?)
buffer byte BUFFER_SIZE DUP (?)
buffer2 byte BUFFER_SIZE DUP (?)
buffer3 byte BUFFER_SIZE DUP (?)
choice byte ?
inputLength dword ?
searchLength dword ?
deleteLength dword ?
numChars dword ?
numchars2 dword ?
filehandle HANDLE ?
fileHandle2 HANDLE ?
filehandle3 HANDLE ?

newname byte 16 DUP (?)
mergename byte 16 DUP (?)
existingname byte 16 DUP (?)
encryptedName byte 16 DUP (?)
password byte 9 DUP (?)
password2 byte 9 DUP (?)
decryptpass byte 9 DUP (?)
decryptpass2 byte 9 DUP (?)

;Menu Definitions
WindowTitle byte "Notepad-- | A Text Editor by Ayaan and Nausherwan",0
TitleScreen byte indent, "     __      _                       _             ",Newline,
indent, "  /\ \ \___ | |_ ___ _ __   __ _  __| |            ",Newline,
indent," /  \/ / _ \| __/ _ \ '_ \ / _` |/ _` | _____ _____ ",Newline,
indent,"/ /\  / (_) | ||  __/ |_) | (_| | (_| ||_____|_____|",Newline,
indent,"\_\ \/ \___/ \__\___| .__/ \__,_|\__,_|            ",Newline,
indent,"                    |_|                            ",Newline,
indent,"                            By Ayaan and Nausherwan",Newline,Newline,0

MainMenu byte	" 1. Create a new text file", Newline,
				" 2. Edit an existing text file",Newline,
				" 0. Exit the program",Newline,Newline,
				" Enter your choice: ",0
	      
EditMenu byte	" File opened successfully. What would you like to do with the file?", Newline,Newline,
				"  1. Search for a substring within the file", Newline,
				"  2. Add text to the file", Newline,
				"  3. Merge two files together", Newline,
				"  4. Change the case of the text", Newline,
				"  5. Delete a character from the file", Newline,
				"  6. Reverse the contents of the file", Newline,
				"  7. File Security", Newline,
				"  0. Return to main menu",Newline,Newline,
				" Enter your choice: ",0

CaseMenu byte "   1. UPPER CASE", Newline,
			  "   2. lower case", NewLine,
			  "   3. Sentence case", Newline,
			  "   4. Title Case",NewLine,
			  " Note: This functionality only works with correct punctuation & spacing!",Newline,
			  " Choose a case: ",0

EncryptMenu byte "   1. Encrypt your file", Newline,
				 "   2. Decrypt your file", Newline,
				 " Enter your choice: ",0

.code
main PROC
	invoke SetConsoleTitle, addr windowtitle
	mov  eax,white+(blue*16)
    call SetTextColor
	Invoke PlaySound, addr startupsound, NULL, 20001H ; startup sound
	begin:
	call clrscr
	mov edx, offset titlescreen
	call writestring
	mov edx, offset mainmenu
	call writestring
	EnterChoice:
	mgotoxy 20,12
	mov al, ' '
	call writechar ; clear previous entry in case of incorrect entry

	mgotoxy 20,12
	call readchar
	call writechar
	mov choice, al
	Invoke PlaySound, addr clicksound, NULL, 20001H
	call crlf
	cmp choice, '1'
	je FirstProc
	cmp choice, '2'
	je SecondProc
	cmp choice, '0'
	je Lexit

	jmp Invalid

	FirstProc:
		call CreateNew
		Invoke ClearBuffer, addr buffer
		Invoke ClearBuffer, addr buffer2
		jmp begin
	SecondProc:
		call ReadExisting
		Invoke ClearBuffer, addr buffer
		Invoke ClearBuffer, addr buffer2
		jmp begin
	Invalid:
		Invoke PlaySound, addr errorsound, NULL, 20001H
		mov ebx, offset InvalidEntryTitle
		mov edx, offset InvalidEntryMsg
		call msgboxask
		cmp eax, 6
		je EnterChoice

	Lexit:
	mWrite "Thank you!"
	exit
main endp

; Clears the buffer variable used to hold user input, so it can be filled with new content next time
ClearBuffer PROC, buf:ptr byte
	cld ; direction = forward
	mov edi, buf
	xor eax, eax ; clear eax so that al = 0
	mov ecx, BUFFER_SIZE
	rep stosb ; stosb moves values from al to [edi]
	ret
ClearBuffer ENDP

;Updates the currently open text file with the contents of the new buffer
UpdateFile PROC, charsToWrite:dword
	mov eax, filehandle
	call closefile ; Close the current file (so we can overwrite it)
	mov edx, offset existingname
	call createoutputfile ; Recreate the same file 
	mov filehandle, eax
	mov edx, offset buffer
	mov ecx, charsToWrite
	mov eax, filehandle
	call writetofile ; Write the updated content to it and close it
	mov eax, filehandle
	call closefile
ret
UpdateFile ENDP

;This function is used to allow the user to type his desired text in the console window
;The console window emulates the behavior of a simple text editor
;Do note that it is subject to the limitations of the console window
TakeInput PROC cursor_x:byte, cursor_y:byte
	set_cursor:
	mGoToXY cursor_x, cursor_y
	read_key:
	call readchar ; reads keyboard input and stores ASCII in AL

	cmp al, ENT ; if ENTER pressed, go to next line
	je move_down

	cmp al, ESCP ; if ESC pressed, exit
	je Lexit

	cmp al, BS ; if Backspace pressed, erase last character
	je Backspace

	cmp cursor_y, MAX_Y
	je read_key

	call writechar ; otherwise print the char
	
	cmp cursor_x, MAX_X ; if max x reached, then set cursor to next line
	je move_down

	inc cursor_x ; else inc cursor_x and set cursor to next position
	jmp set_cursor

	move_down:
	cmp cursor_y, MAX_Y ; if max y reached, then ignore further inputs
	je read_key

	mov cursor_x, 0 ; otherwise go to next line
	inc cursor_y
	jmp set_cursor

	Backspace:
	cmp cursor_x, 0 ; if on beginning of a line, go to end of previous line
	je move_up
	dec cursor_x ; move cursor_x one position back
	jmp erase

	move_up: ; if on first line, then ignore further inputs
	cmp cursor_y, 1
	je read_key
	mov cursor_x, MAX_X
	dec cursor_y

	erase:
	mGoToXY cursor_x, cursor_y ; set cursor one position back
	mov al, WS ; print ' ' in that space
	call writechar
	jmp set_cursor ; continue typing
	
	Lexit:
	; This code calculates the number of characters entered by the user (so no extra chars are written to file)
	movzx eax, cursor_y
	dec eax ; eax = number of compelete lines entered
	mov ebx, COLUMNS
	mul ebx ; eax = number of characters entered up to the last line
	movzx ebx, cursor_x
	add eax, ebx
	mov inputLength, eax ; inputLength = total number of characters entered by user
	ret
TakeInput ENDP


CreateNew PROC
	Yes:
	mWrite "Enter the name of the file to create: "
	mov edx, offset newname
	mov ecx, lengthof newname+1 
	call readstring
	cmp eax, 15 ; If filename exceeds 15 characters
	ja InvalidName
	call createoutputfile
	mov filehandle, eax
	call clrscr
	mWrite "File created. Enter contents of file, and press ESC to save and exit: " 
	Invoke TakeInput, 0, 1 ; Allow the user to enter their desired text, starting from cursor position (0,1)
	invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov hConsole, eax
	invoke ReadConsoleOutputCharacter, hConsole, addr buffer, inputLength, loc, addr numRead
	mov edx, offset buffer
	mov eax, filehandle
	mov ecx, inputLength
	call writetofile
	call crlf
	jmp ExitCreate

	InvalidName:
	mov ebx, offset invalidnametitle ; Error message box in case of invalid file name
	mov edx, offset invalidnamemsg
	call msgboxask
	cmp eax, 6
	je Yes

	ExitCreate:
	call waitmsg
	Invoke PlaySound, addr clicksound, NULL, 20001H
	mov eax, filehandle
	call closefile
	ret
CreateNew ENDP


ReadExisting PROC
	EnterFileName:
	mgotoxy 0, 13
	mov al, ' '
	mov ecx, 120
	L1:
		call writechar ; Clear the current line (in case you're trying to enter file name again)
	loop L1
	mgotoxy 0, 13
	mWrite " Enter the name the text file to open: "
	mov edx, offset existingname
	mov ecx, lengthof existingname+1
	call readstring

	DisplayMenu:
	mov edx, offset existingname
	call openinputfile
	cmp eax, -1
	je NotFound
	mov filehandle, eax
	mov edx, offset buffer
	mov ecx, BUFFER_SIZE
	call readfromfile
	mov numchars, eax ; Number of characters contained in file (very important variable)

	call clrscr
	mov edx, offset titlescreen ; Display the title
	call writestring
	
	mov edx, offset EditMenu ; Display the edit menu
	call writestring
	mgotoxy 90, 8
	mwrite "Current File: "
	mov eax,lightred+(blue*16)
    call SetTextColor
	mov edx, offset existingname
	call writestring ; Print name of current file in the corner, then restore cursor location/text color
	mov eax,white+(blue*16)
    call SetTextColor

	mgotoxy 51,28
	mov eax,lightred+(blue*16)
    call SetTextColor
	mwrite "File Preview:" ; Print file preview by displaying the buffer
	mov eax,white+(blue*16)
    call SetTextColor
	mgotoxy 0,29
	mWrite <Separator,Newline>
	invoke getstdhandle, STD_OUTPUT_HANDLE ; eax = console window handle
	invoke WriteConsole, eax, addr buffer, numchars, addr numwritten, 0 ; Print only the characters written to file, nothing extra
	
	EnterChoice:
	mgotoxy 20,19 ; Clear previous input (in case you entered invalid input)
	mov al, ' '
	call writechar
	mgotoxy 20,19
	call readchar ; Enter choice
	call writechar 
	mov choice, al
	Invoke PlaySound, addr clicksound, NULL, 20001H
	call crlf
	
	cmp choice, '1'
	je Searching
	cmp choice, '2'
	je AddToEnd
	cmp choice, '3'
	je MergeFiles
	cmp choice, '4'
	je ChangeCase
	cmp choice, '5'
	je DeleteChar
	cmp choice, '6'
	je ReverseFile
	cmp choice, '7'
	je EncryptFile
	cmp choice, '0'
	je RetToMain

	jmp Invalid ;If none of the above options were entered

	Searching:
		call SearchProc
		jmp DisplayMenu

	AddToEnd:
		call AddToEndProc
		jmp DisplayMenu

	MergeFiles:
		call MergeProc
		jmp DisplayMenu

	ChangeCase:
		call ChangeCaseProc
		jmp DisplayMenu

	DeleteChar:
		call DeleteCharProc
		jmp DisplayMenu

	ReverseFile:
		call ReverseFileProc
		jmp DisplayMenu
	EncryptFile:
		call Security
		jmp DisplayMenu

	NotFound:
	Invoke PlaySound, addr errorsound, NULL, 20001H ; If entered file name was not found
	mov ebx, offset notfoundtitle
	mov edx, offset notfoundmsg
	call msgboxask
	cmp eax, 6
	je EnterFileName
	jmp ExitRead

	Invalid:
	Invoke PlaySound, addr errorsound, NULL, 20001H ; If menu choice entered was invalid
	mov ebx, offset InvalidEntryTitle
	mov edx, offset InvalidEntryMsg
	call msgboxask
	cmp eax, 6
	je EnterChoice

	ExitRead: 
	call crlf
	call waitmsg
	Invoke PlaySound, addr clicksound, NULL, 20001H
	RetToMain:
	mov eax, filehandle
	call closefile
	ret
ReadExisting ENDP


;Done
SearchProc PROC
	mWrite " Enter your search string: " 
	mov edx, offset searchWord
	mov ecx, lengthof searchword+1
	xor ebx, ebx ; clear ebx (ebx = number of matches)
	call readstring ; Input search key

	mov searchLength, eax ; length of search key
	mov esi, offset buffer
	mov ecx, lengthof buffer
	L1:
		mov al, [esi]
		cmp al, searchword[ebx] ; Compare buffer content with first char of search key
		je MatchFound
		SearchNext:
		inc esi
	Loop L1
	jmp NotFound

	MatchFound:
		inc ebx ; Increment matches found
		cmp searchLength, ebx ; Check if number of matches == searchLength
		je Break ; If all characters matched, we found the search key 
		jmp SearchNext ; Otherwise keep searching
	
	Break:
	sub esi, offset buffer ; ESI now contains the ending index of the found word
	mov eax, esi
	xor edx, edx
	mov ebx, 120
	div ebx ; divide starting index of word by numchars per line (120) to get line number (starting from 0)
	inc eax ; eax = line number (starting from 1)
	mWrite " String found in file at line number: "
	push eax
	mov eax,lightred+(blue*16)
    call SetTextColor
	pop eax
	call writedec ; Print the line number in red for style points
	mov eax,white+(blue*16)
    call SetTextColor
	jmp ExitSearch

	NotFound: ; If search key was not found
	mov eax,lightred+(blue*16)
    call SetTextColor
	mWrite " String not found in file!"
	mov eax,white+(blue*16)
    call SetTextColor
	ExitSearch:
	call crlf
	call waitmsg
	mov eax, filehandle
	call closefile
	ret
SearchProc ENDP

;Done
AddToEndProc PROC
	call clrscr
	invoke clearbuffer, addr buffer2
	
	mwrite "Enter text to add to the end of the file: "
	invoke takeinput, 0, 1
	invoke GetStdHandle, STD_OUTPUT_HANDLE
	invoke ReadConsoleOutputCharacter, eax, addr buffer2, inputLength, loc, addr numRead
	;Buffer2 now contains the text to be concatenated to buffer1
	mov ecx, inputlength
	mov ebx, numchars
	mov esi, offset buffer
	add esi, numchars ; esi = end of buffer1
	mov al, [esi]
	mov al, ' ' 
	mov [esi], al  ; Overwrite null char of buffer1
	inc esi ; Add a space before concatenating
	mov edi, offset buffer2 ; edi = start of buffer2
	L1:
		mov al, [edi]
		mov [esi], al
		inc esi
		inc edi
	Loop L1
	mov ecx, numchars
	add ecx, inputlength
	inc ecx
	invoke UpdateFile, ecx

	call crlf
	mwrite "Your text has been added to the file! "
	call waitmsg
	ret
AddToEndProc ENDP

;Done
ChangeCaseProc PROC
	mov edx, offset casemenu
	call writestring
	EnterChoice:
	mgotoxy 16,26 ; Clear previous input (in case you entered invalid input)
	mov al, ' '
	call writechar
	mgotoxy 16,26
	call readchar
	call writechar
	call crlf
	mov esi, offset buffer
	mov ecx, numchars
	cmp al, '1'
	je UpperCase

	cmp al, '2'
	je LowerCase

	cmp al, '3'
	je SentenceCase

	cmp al, '4'
	je TitleCase

	jmp Invalid

	LowerCase:
	L1:
		mov al, [esi]
		cmp al, 'A'
		jae TargetLower ; check upper bound of ASCII range
		jmp AlreadyLower
		TargetLower:
		cmp al, 'Z'
		ja AlreadyLower
		or al, 00100000b
		mov [esi], al
		AlreadyLower:
		inc esi
	Loop L1
	jmp ExitCase

	UpperCase:
	L2:
		mov al, [esi]
		cmp al, 'a'
		jae TargetUpper
		jmp AlreadyUpper
		TargetUpper:
		cmp al, 'z'
		ja AlreadyUpper
		and al, 11011111b
		mov [esi], al
		AlreadyUpper:
		inc esi
	Loop L2
	jmp ExitCase

	SentenceCase:
	mov al, [esi]
	and al, 11011111b ; Capitalize the very first word
	mov [esi], al
	inc esi
	L3:
		mov al, [esi]
		cmp al, '.'
		je SentenceEnded
		cmp al, '!'
		je SentenceEnded
		cmp al, ':'
		je SentenceEnded
		cmp al, 'i'
		je iDetected
		jmp SentenceNotEnded

		iDetected:
		mov bl, [esi-1] ; Checks if the I is a solo word 
		cmp bl, ' '
		jne CheckNext
		mov bl, [esi+1]
		cmp bl, ' '
		jne CheckNext

		and al, 11011111b ; If it is solo then capitalize the I
		mov [esi], al
		jmp CheckNext

		SentenceEnded: ;If end of sentence reached then capitalize first letter of next word
		add esi, 2 
		mov al, [esi]
		and al, 11011111b
		mov [esi], al
		jmp CheckNext
		
		SentenceNotEnded:
		or al, 00100000b
		mov [esi], al
		CheckNext:
		inc esi
	loop L3
	jmp ExitCase


	TitleCase:
	mov al, [esi]
	and al, 11011111b ; Capitalize the very first word
	mov [esi], al
	inc esi
	L4:
		mov al, [esi]
		cmp al, ' '
		je WordEnded?
		jmp WordNotEnded
		WordEnded?: ; If space encountered, check if next is also a space
		inc esi
		mov al, [esi]
		cmp al, ' ' ; if next also space then make no change (means we're moving to next line)
		je CheckNext2
		and al, 11011111b ; Capitalize first letter of every word
		mov [esi], al
		jmp CheckNext2

		WordNotEnded:
		or al, 00100000b
		mov [esi], al
		CheckNext2:
		inc esi
	loop L4
	jmp ExitCase

	Invalid:
	Invoke PlaySound, addr errorsound, NULL, 20001H
	mov ebx, offset InvalidEntryTitle
	mov edx, offset InvalidEntryMsg
	call msgboxask
	cmp eax, 6
	je EnterChoice

	ExitCase:
	Invoke UpdateFile, numchars
	ret
ChangeCaseProc ENDP

;Done
DeleteCharProc PROC
	mwrite "What word would you like to delete: "
	mov edx, offset deleteWord
	mov ecx, lengthof deleteWord
	call readstring
	mov deleteLength, eax
	mov ecx, lengthof buffer
	mov edx, ecx ; to preserve ecx value
	mov esi, offset buffer
	L1:
		mov ecx, edx ; to restore ecx value
		mov edi, offset deleteWord
		mov al, [esi]
		cmp al, [edi]

		je Target
		inc esi
	Loop L1
	jmp Lexit

	Target:
		mov edx, ecx ; to preserve ecx value
		mov ecx, deleteLength
		dec ecx
		L2:
			inc esi
			inc edi
			mov al, [esi]
			cmp al, [edi]
			jne L1
		Loop L2

		mov al, ' '
		mov ecx, deleteLength
		L3:
			mov [esi], al
			dec esi
		Loop L3

	invoke UpdateFile, numchars
	Lexit:
	ret
DeleteCharProc ENDP

;Done
ReverseFileProc PROC
	mov ecx, numchars
	mov esi, offset buffer
	xor eax, eax
	L3:
		mov al, [esi]
		push eax
		inc esi
	Loop L3
	mov ecx, numchars
	mov esi, offset buffer
	L4:
		pop eax
		mov [esi], al
		inc esi
	Loop L4

	invoke UpdateFile, numchars
	call crlf
	call waitmsg
	ret
ReverseFileProc ENDP

;Done
MergeProc PROC
	invoke clearbuffer, addr buffer2

	EnterFileName:
	mgotoxy 0,20
	mwrite <clearline>
	mgotoxy 0,20
	mwrite " Enter file name of second file: "
	mov edx, offset mergename
	mov ecx, lengthof mergename+1
	call readstring

	mov edx, offset mergename
	call openinputfile
	cmp eax, -1
	je NotFound
	mov filehandle3, eax
	mov edx, offset buffer2
	mov ecx, BUFFER_SIZE
	call readfromfile
	mov numchars2, eax
	mov ecx, lengthof buffer2
	mov esi, offset buffer
	add esi, numchars ; esi = end of buffer1
	mov edi, offset buffer2
	mov al, ' '
	mov [esi], al 
	inc esi
	L1:
		mov al, [edi]
		mov [esi], al
		inc esi
		inc edi
	Loop L1
	mov eax, filehandle3
	call closefile
	jmp Lexit

	NotFound:
	Invoke PlaySound, addr errorsound, NULL, 20001H ; If entered file name was not found
	mov ebx, offset notfoundtitle
	mov edx, offset notfoundmsg
	call msgboxask
	cmp eax, 6
	je EnterFileName

	Lexit:
	invoke deletefile, addr mergename ; delete the file that was merged into the existing one

	mov ecx, numchars
	add ecx, numchars2
	inc ecx
	invoke updatefile, ecx
	call crlf
	call waitmsg
	ret
MergeProc ENDP 

Security PROC
	invoke clearbuffer, addr buffer2
	invoke clearbuffer, addr buffer3
	mwrite " Enter name of encrypted file: "
	mov edx, offset encryptedName
	mov ecx, lengthof encryptedName
	call readstring ; Read name of encrypted file
	mov edx, offset encryptmenu
	call writestring

	EnterChoice:
	mgotoxy 20,23
	mov al, ' '
	call writechar
	mgotoxy 20,23
	call readchar
	call writechar

	cmp al, '1'
	je Encrypt
	cmp al, '2'
	je Decrypt
	jmp Invalid

	Encrypt:
	mov edx, offset encryptedname
	call createoutputfile ; Create empty encrypted file
	mov filehandle2, eax
	call crlf
	ReEnter:
	mgotoxy 0, 24
	mwrite <clearline>
	mwrite <clearline>
	mgotoxy 0,24
	mwrite " Set a password for your file (length MUST be 8 characters): "
	mov edx, offset password
	mov ecx, lengthof password+1
	call readstring
	mwrite " Re-enter your password for confirmation: "
	mov edx, offset password2
	mov ecx, lengthof password2+1
	call readstring

	invoke str_compare, addr password, addr password2
	je PasswordsMatch

	jmp PasswordNotMatch


	PasswordsMatch:
	mov esi, offset password2 ; copy password to first line of buffer2
	mov edi, offset buffer2
	mov ecx, lengthof password2
	cld
	rep movsb

	mov esi, offset buffer ; copy contents of buffer1 to buffer2 (starting from 2nd line) and encrpyt
	mov edi, offset buffer2
	add edi, 120
	mov ecx, numchars
	L1:
		mov al, [esi]
		add al, 3 ; applying Caesar Cipher
		mov [edi], al
		inc esi
		inc edi
	loop L1

	mov edx, offset buffer2
	mov ecx, numchars
	add ecx, 120
	mov eax, filehandle2 ; write encrypted text to file
	call writetofile
	mwrite " File has been encrypted by the Caesar Cipher! "
	jmp Lexit

	Decrypt:
	EnterFileName:
	mov edx, offset encryptedname
	call openinputfile
	cmp eax, -1
	je FileNotFound
	mov filehandle2, eax

	mov ecx, numchars
	add ecx, 120
	mov edx, offset buffer2
	call readfromfile ; buffer2 = encrypted content

	mov eax, filehandle2
	call closefile

	mov edx, offset encryptedname
	call createoutputfile
	mov filehandle2, eax

	EnterPass:
	call crlf
	mgotoxy 0,24
	mwrite <clearline>
	mgotoxy 0,24
	mwrite " Enter the password for this file: "
	mov edx, offset decryptpass
	mov ecx, lengthof decryptpass+1
	call readstring ; Enter the password from user
	
	mov edi, offset decryptpass2
	mov esi, offset buffer2
	mov ecx, 8
	cld
	rep movsb ; Read existing password from buffer2, store in decryptpass2
	
	invoke str_compare, addr decryptpass, addr decryptpass2
	je CorrectPass
	jmp InvalidPass

	
	CorrectPass:
	mov esi, offset buffer2
	add esi, 120
	mov ecx, numchars
	mov edi, offset buffer3
	L2:
		mov al, [esi]
		sub al, 3
		mov [edi], al
		inc esi
		inc edi
	loop L2
	
	mov edx, offset buffer3
	mov eax, filehandle2
	mov ecx, numchars
	call writetofile

	mov eax, filehandle2
	call closefile

	call crlf
	mwrite "File has been decrypted! "
	jmp Lexit

	Invalid: ; If menu choice entered was invalid
	Invoke PlaySound, addr errorsound, NULL, 20001H 
	mov ebx, offset InvalidEntryTitle
	mov edx, offset InvalidEntryMsg
	call msgboxask
	cmp eax, 6
	je EnterChoice
	jmp Lexit
	
	InvalidPass: ; In case incorrect pass was entered when decrypting a file
	Invoke PlaySound, addr errorsound, NULL, 20001H 
	mov ebx, offset InvalidPassTitle
	mov edx, offset InvalidPassMsg
	call msgboxask
	cmp eax, 6
	je EnterPass
	jmp Lexit

	PasswordNotMatch: ; In case confirmation pass doesnt match original pass when encrypting
	Invoke PlaySound, addr errorsound, NULL, 20001H 
	mov ebx, offset MatchingPassTitle
	mov edx, offset MatchingPassMsg
	call msgboxask
	cmp eax, 6
	je ReEnter
	jmp Lexit

	FileNotFound:
	Invoke PlaySound, addr errorsound, NULL, 20001H 
	mov ebx, offset NotFoundTitle
	mov edx, offset NotFoundMsg
	call msgboxask
	cmp eax, 6
	je EnterFileName

	Lexit:
	mov eax, filehandle2
	call closefile
	mov eax, filehandle
	call closefile
	call waitmsg
	ret
Security ENDP


end main