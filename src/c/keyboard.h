//Define keyboard interrupt and other data
#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "key_map.h"
#include <stdint.h>

int8_t read_port(uint16_t);
void write_port(uint16_t, uint8_t);
void k_writeScr(const char* msg, int row, int col);

uint8_t echo_enabled = 1;
char buffer[255] = {0};
uint8_t index = 0;
uint8_t input_length = 0;

void keyboard_handler_driver(void){
    uint8_t status;
    char keycode;
    
    //Signal EOI to master
    write_port(0x20, 0x20);
    
    //Get port status
    status = read_port(0x64);
    
    //If good, read keycode and decode it
    if(status & 0x01){
        keycode = read_port(0x60);
        
        if(keycode < 0) return;
        
        buffer[index++] = key_map[keycode];
        
        if(echo_enabled){
            //k_writeScr(buffer, 2, index2++);
        }
        
        ++input_length;
        
    }
    
    //write_port(0x20, 0x20);
}

void keyboard_init(void){
    //Unmask the keyboard interrupt
    uint8_t mask = read_port(0x21);
    write_port(0x21, mask & 0xFD);
}

//Currently unused
void toggle_echo(uint8_t foo){
    if(foo == 0){
        foo = 1;
    }else{
        foo = 0;
    }
}

//Clear all input buffer data
void clearBuffer(void){
    for(uint8_t i = 0; i < 255; ++i){
        if(buffer[i] == 0) break;
        buffer[i] = 0;
    }
    index = 0;
    input_length = 0;
}
#endif
