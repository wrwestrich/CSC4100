.intel_syntax noprefix

.global k_clearScr
.global k_writeScr
.global k_writeScrColor
.global k_writeScrSingleColor
.global k_compareString
.global read_port
.global write_port
.global load_idt
.global keyboard_handler
.extern keyboard_handler_driver

.set SCREEN_START, 0xB8000
.set SCREEN_WIDTH, 80
.set SCREEN_HEIGHT, 25
.set SCREEN_AREA, 80*25*2
.set SCREEN_COLOR, 80*25*2
.set TEXT_COLOR, 0x07

//void k_clearScr(void)
k_clearScr:
    push ebp
    mov ebp,esp

    push eax
    push ebx
    push ecx

    xor eax, eax
    mov ebx, SCREEN_START
    mov ecx, ebx
    add ecx, SCREEN_AREA

    clear:
        mov [ebx], eax
        add ebx, 4
        cmp ebx, ecx
        jne clear

    pop ecx
    pop ebx
    pop eax

    mov esp, ebp
    pop ebp
    ret

//void k_writeScr(char* string, int row, int col)
k_writeScr:
    push ebp
    mov ebp,esp

    push eax
    push ebx
    push ecx

    mov ecx, [ebp+12]
    imul ecx, SCREEN_WIDTH
    mov eax, [ebp+16]
    add ecx, eax
    shl ecx, 1
    add ecx, SCREEN_START

    mov ebx, [ebp+8]
    mov ah, TEXT_COLOR

    start_print:

        mov al, [ebx]
        cmp al, 0
        jz end_print

        mov [ecx], ax
        inc ebx
        add ecx, 2
        jmp start_print

    end_print:

    pop ecx
    pop ebx
    pop eax

    mov esp, ebp
    pop ebp
    ret

//void k_writeScrColor(char* string, int row, int col, int starting_color)
k_writeScrColor:
    push ebp
    mov ebp,esp

    push eax
    push ebx
    push ecx

    mov ecx, [ebp+12]
    imul ecx, SCREEN_WIDTH
    mov eax, [ebp+16]
    add ecx, eax
    shl ecx, 1
    add ecx, SCREEN_START

    mov ebx, [ebp+8]
    mov ah, [ebp+20]	//Text color
    cmp ah, 0x0F
    jl start_print_color
    
    mov ah, 0x01

    start_print_color:

        mov al, [ebx]
        cmp al, 0
        jz end_print_color

        mov [ecx], ax
        inc ebx
        add ecx, 2
        inc ah
        cmp ah, 0x0F
        jl start_print_color
        mov ah, 0x01
        jmp start_print_color

    end_print_color:

    pop ecx
    pop ebx
    pop eax

    mov esp, ebp
    pop ebp
    ret
    
//void k_writeScrSingleColor(char* string, int row, int col, int color)
k_writeScrSingleColor:
    push ebp
    mov ebp,esp

    push eax
    push ebx
    push ecx

    mov ecx, [ebp+12]
    imul ecx, SCREEN_WIDTH
    mov eax, [ebp+16]
    add ecx, eax
    shl ecx, 1
    add ecx, SCREEN_START

    mov ebx, [ebp+8]
    mov ah, [ebp+20]    //Text color
    cmp ah, 0x0F
    jl start_print_single
    
    mov ah, 0x07

    start_print_single:

        mov al, [ebx]
        cmp al, 0
        jz end_print_single

        mov [ecx], ax
        inc ebx
        add ecx, 2
        jmp start_print_single

    end_print_single:

    pop ecx
    pop ebx
    pop eax

    mov esp, ebp
    pop ebp
    ret
    
//uint8_t read_port(uint16_t port)
read_port:
    mov edx, [esp+4]
    in al, dx
    ret

//void write_port(uint16_t port, uint8_t data)
write_port:
    mov edx, [esp+4]
    mov al, [esp+8]
    out dx, al
    ret

//void load_idt(uintptr_t idt_ptr)
load_idt:
    mov edx, [esp+4]
    lidt [edx]
    sti
    ret
    
//void keyboard_handler(void)
keyboard_handler:
    cli
    pushad
    cld
    call keyboard_handler_driver
    popad
    sti
    iretd

