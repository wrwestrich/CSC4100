//Define keyboard interrupt and other data
#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "key_map.h"
#include <stdint.h>

int8_t read_port(uint16_t);
void write_port(uint16_t, uint8_t);
void k_writeScr(const char *msg, int row, int col);

uint8_t echo_enabled = 1;
char buffer[255] = {0};
uint8_t index = 0;
uint8_t input_length = 0;
uint8_t shift = 0;

void keyboard_handler_driver(void)
{
  uint8_t status;
  char keycode;

  //Signal EOI to master
  write_port(0x20, 0x20);

  //Get port status
  status = read_port(0x64);

  //If good, read keycode and decode it
  if (status & 0x01)
  {
    keycode = read_port(0x60);

    if (keycode < 0)
      return;

    if (keycode & 0x80)
    {
      // If we're here, then a key was just released
      // Left and Right shift = 42, 54 (2A, 36)
      if (keycode == 0x2a || keycode == 0x36)
      {
        shift = 0;
      }
    }
    else
    {
      // If we're here, a key was just pressed
      // Treat shift as caps lock currently because I can't find out how
      // to trigger a release of a key
      if (keycode == 0x2a || keycode == 0x36)
      {
        if (shift != 0)
        {
          shift = 0;
        }
        else
        {
          shift = 1;
        }
        return;
      }

      if (keycode == 0x0e)
      {
        buffer[index--] = 0;
        buffer[index] = 0;
        --input_length;
      }
      else if (shift == 0)
      {
        buffer[index++] = key_map[keycode];
        ++input_length;
      }
      else
      {
        buffer[index++] = key_map_shift[keycode];
        ++input_length;
      }

      if (echo_enabled)
      {
        //k_writeScr(buffer, 2, index2++);
      }
    }
  }

  //write_port(0x20, 0x20);
}

void keyboard_init(void)
{
  //Unmask the keyboard interrupt
  uint8_t mask = read_port(0x21);
  write_port(0x21, mask & 0xFD);
}

//Currently unused
void toggle_echo(uint8_t foo)
{
  if (foo == 0)
  {
    foo = 1;
  }
  else
  {
    foo = 0;
  }
}

//Clear all input buffer data
void clearBuffer(void)
{
  for (uint8_t i = 0; i < 255; ++i)
  {
    if (buffer[i] == 0)
      break;
    buffer[i] = 0;
  }
  index = 0;
  input_length = 0;
}
#endif
