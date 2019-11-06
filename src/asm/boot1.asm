%define ROOT_SEG    0x60
%define FAT_SEG     0x800
%define IMAGE_SEG   0x1000
%define IMAGE_START 65536
%define EX_START    0

;Define offsets for used portions of BPB for ease of access
;Based on bp being set to 7C00
%define sectorsPerCluster   bp+0x0D
%define sectorsBeforeFAT    bp+0x0E
%define numFATs             bp+0x10
%define rootEntries         bp+0x11
%define sectorsPerFAT       bp+0x16
%define sectorsPerTrack     bp+0x18
%define headsPerCylinder    bp+0x1A
%define hiddenSectors       bp+0x1C
%define driveNo             bp+0x24

org 0x7C00

entry:  jmp short begin

;--------------------------------------------------------------------------------------
; BPB definition
;--------------------------------------------------------------------------------------

;times 0x0B-$+begin db 0                 ;BIOS parameter block is defined at offest 0x0B

bpbINT13Flag	       db 0x90		   ;0002h - 0EH for INT13 AH=42 READ
bpbOEM                 db "MSDOS5.0"       ;0003h - OEM ID
bpbBytesPerSector      dw 512              ;000Bh - Bytes per sector
bpbSectorsPerCluster   db 1                ;000Dh - Sector per cluster
bpbReservedSectors     dw 1                ;000Eh - Reserved sectors
bpbNumFATs             db 2                ;0010h - FAT copies
bpbRootEntries         dw 224              ;0011h - Root directory entries
bpbTotalSectors        dw 2880             ;0013h - Sectors in volume
bpbMedia               db 0xF0             ;0015h - Media descriptor
bpbSectorsPerFAT       dw 9                ;0016h - Sectors per FAT
bpbSectorsPerTrack     dw 18               ;0018h - Sectors per track
bpbHeadsPerCylinder    dw 2                ;001Ah - Heads per cylinder
bpbHiddenSectors       dd 0                ;001Ch - Hidden sectors
bpbTotalSectorsLarge   dd 0                ;0020h - Total number of sectors
bpbDriveNumber         db 0                ;0024h - Physical drive number
bpbFlags               db 0                ;0025h - Flags (unused)
bpbExtBootSignature    db 0x29             ;0026h - Extended boot record signature
bpbSerialNumber        dd 0xA0A1A2A3       ;0027h - Volume serial number
bpbVolumeLabel         db "pOS Floppy "    ;002Bh - Volume label
bpbFileSystem          db "FAT12   "       ;0036h - File system ID

;--------------------------------------------------------------------------------------

begin:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    mov bp, sp          ;Set bp to 0x7C00
    mov [driveNo], dl

    ;Calculate root directory sector
    mov al, [numFATs]
    mul WORD [sectorsPerFAT]
    add ax, [sectorsBeforeFAT]

    ;Calculate length of root dir in terms of sectors
    mov si, [rootEntries]
    dec si
    mov cl, 4
    shr si, cl
    inc si

    mov di, ROOT_SEG/32     ;Set buffer
    call read16             ;Read the root dir

    ;Save cluster two's sector
    push ax
%define cluster2Sector bp-2 ;Define for later access of this sector

    mov dx, [rootEntries]
    push ds                 ;Assign ds to es
    pop es
    mov di, ROOT_SEG*16

file_search:
    dec dx
    js error

    mov si, filename    ;File we are looking for
    mov cx, 11
    lea ax, [di+0x20]   ;Next entry address
    push ax             ;Save it

    repe cmpsb

    pop di              ;Get next entry
    jnz file_search     ;Repeat until found

    push WORD [di-6]    ;Starting cluster number

    ;Set up to read the FAT
    mov ax, [sectorsBeforeFAT]
    mov si, [sectorsPerFAT]
    mov di, FAT_SEG/32
    ;Read FAT
    call read16

next:
    ;Set up cluster range for this sequence
    pop bx
    mov si, bx  ;First
    mov ax, bx  ;Last

    .0:
        ;Check for end of file
        cmp bx, 0xFF8
        jae .1
    
        inc ax  ;Add one more cluster to sequence

        mov di, bx
        rcr bx, 1   ;c-bit indicates odd cluster

        mov bx, [bx+di+FAT_SEG*16-0x8000]
        jnc .even
        shr bx, 4
    .even:
        and bh, 0xF

        ;Check if contiguous. If so, look ahead
        cmp ax, bx
        je .0

    .1:
        ;Check for end of file
        sub ax, si
        jz eof

        push bx     ;Save next cluster

        mov bl, [sectorsPerCluster]
        mov bh, 0
        mul bx
        xchg ax, si             ;ax is atarting cluster, si is length in sectors

    .2: mov di, IMAGE_SEG/32
        add [.2+1], si          ;Next destination
        dec ax
        dec ax
        mul bx
        add ax, [cluster2Sector]
        adc dl, dh

        call read32
        jmp short next

eof:
    ;Block interrupts
    cli

    ;Load interrupt descriptor table
    lidt [idtr]

    xor ebx, ebx
    lea eax, [gdt+ebx]  ;Get gdt address
    mov [gdtr+2], eax

    ;Load gdt
    lgdt [gdtr]

    ;Go into protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp SYS_CODE_SEG:do_protected

[BITS 32]
do_protected:
    mov ax, SYS_DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ;Start OS
    mov eax, IMAGE_START
    xor esi, esi
    mov esp, IMAGE_START
    add esp, 0xFFFF

    jmp ENTRY

[BITS 16]
read16:
    xor dx, dx

;Convert to CHS format
read32:
    .1:
        push dx     ;High sector
        push ax     ;Low sector

        ;Convert to LBN
        add ax, [hiddenSectors]
        adc dx, [hiddenSectors+2]

        mov bx, [sectorsPerTrack]
        div bx                      ;ax is track, dx is sector - 1
        sub bx, dx                  ;sectors remaining

        ;Check if we have only what we need
        cmp bx, si
        jbe .2

        ;If we have more, move only what's needed
        mov bx, si

    .2:
        ;get sector number
        inc dx

        mov cx, dx
        cwd
        div WORD [headsPerCylinder]
        mov dh, dl

        xchg ch, al
        ror ah, 2
        add cl, ah

        ;Check if on 64kb boundary
        sub ax, di
        and ax, BYTE 0x7F
        jz .3

        ;Take just what we want
        cmp ax, bx
        jbe .4

    .3:
        xchg ax, bx

    .4:
        ;Save length
        push ax

        ;Compute destination segment
        mov bx, di
        push cx
        mov cl, 5
        shl bx, cl
        pop cx

        ;Read at es:bx
        mov es, bx
        xor bx, bx
        mov dl, [driveNo]
        mov ah, 2
        int 0x13
        jc error

        ;Restore and update
        pop bx
        pop ax
        pop dx
        add ax, bx
        adc dl, dh
        add di, bx

        ;Read more if needed
        sub si, bx
        jnz .1

        ;If not, done
        ret

error:
    mov si, err
    mov ax, 0xE0D   ;CR
    mov bx, 7

    .1:
        int 0x10
        lodsb
        test al, al
        jnz .1

        xor ah, ah
        int 0x16    ;Wait for keypress
        int 0x19    ;Reboot

err db 10,"Error loading boot sector",13
    db 10,"Press any key to reboot",13,10,0

;Stuff for protected mode

idtr:
    dw 0
    dd 00

gdtr:
    dw gdt_end - gdt - 1    ;GDT limit
    dd gdt                  ;GDT base

;------------------------------------------------------------------
;Global Descriptor Table
;------------------------------------------------------------------
;null descriptor
gdt:
    dw 0
    dw 0
    db 0
    db 0
    db 0
    db 0

;Linear data segment descriptor
LINEAR_SEG equ $-gdt
    dw 0xFFFF
    dw 0
    db 0
    db 0x92
    db 0xCF
    db 0

;Code segment descriptor
SYS_CODE_SEG equ $-gdt
gdt2:
    dw 0xFFFF
    dw 0
    db 0
    db 0x9A
    db 0xCF
    db 0

;Data segment descriptor
SYS_DATA_SEG equ $-gdt
gdt3:
    dw 0xFFFF
    dw 0
    db 0
    db 0x92
    db 0xCF
    db 0
gdt_end:

codeSize equ $ - entry

%if codeSize+11+2 > 512
    %error "Code is too large for boot sector"
%endif

times (512 - codeSize - 11 - 2) db 0        ;Pad bootloader to be 510 bytes long

filename    db "BOOT2      "
db 0x55, 0xAA                                   ;Make last two bytes be 0x55AA for proper boot signature
