//Definition of Interrupt Descriptor Table
//Currently only has keyboard inturrupt for IO
#ifndef IDT_H
#define IDT_H

#include "keyboard.h"

#define IDT_SIZE 256

void keyboard_handler(void);

struct IDT_def{
    uint16_t    lowerOffset;
    uint16_t    selector;
    uint8_t     zero;
    uint8_t     typeAttr;
    uint16_t    upperOffset;
} __attribute__((packed));

struct IDT_rec{
    uint16_t limit;
    uintptr_t base;
} __attribute__((packed));

struct IDT_def IDT[IDT_SIZE];
struct IDT_rec IDT_record;

void load_idt(struct IDT_rec*);

void idt_init(void){
    uintptr_t kb_addr;
    uintptr_t idt_addr;
    
    kb_addr = (uintptr_t)keyboard_handler;
    IDT[0x21].lowerOffset = (uint16_t)((uintptr_t)(kb_addr & 0xFFFF));
    IDT[0x21].selector = 0x08;
    IDT[0x21].zero = 0x00;
    IDT[0x21].typeAttr = 0x8E;
    IDT[0x21].upperOffset = (uint16_t)((uintptr_t)((kb_addr >> 16) & 0xFFFF));
    
    //Initialize PIC1 and PIC2
    write_port(0x20, 0x11);
    write_port(0xA0, 0x11);
    
    //ICW2
    write_port(0x21, 0x20);
    write_port(0xA1, 0x28);
    
    //ICW3
    write_port(0x21, 0x00);
    write_port(0xA1, 0x00);
    
    //ICW4
    write_port(0x21, 0x01);
    write_port(0xA1, 0x01);
    
    //Block all interrupts. We will initialize when needed.
    write_port(0x21, 0xFF);
    write_port(0xA1, 0xFF);
    
    IDT_record.limit = (sizeof(struct IDT_def) * IDT_SIZE) - 1;
    IDT_record.base = (uintptr_t)&IDT;
    
    load_idt(&IDT_record);
}
#endif
