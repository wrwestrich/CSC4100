
#include "keyboard.h"

void k_clearScr(void);
void k_writeScrColor(const char *msg, int row, int col, int starting_color);
void k_writeScrSingleColor(char *string, int row, int col, int color);
void k_writeScr(const char *msg, int row, int col);
int convert_num_h(unsigned int num, char buf[]);
void convert_num(unsigned int num, char buf[]);
uint8_t cmpStr(char *password, char *string, uint8_t password_length, uint8_t length);
void idt_init(void);
int main(void) __attribute__((noreturn));

int main(void)
{

  k_clearScr();

  //Initialize interrupts
  idt_init();
  keyboard_init();

  //Login screen
  k_writeScrColor("Welcome to pOS", 10, 33, 1);
  k_writeScr("Press enter to continue.", 20, 29);

  while (buffer[index - 1] != '\n')
    ;

  clearBuffer();

  k_clearScr();

  //Read unsername
  while (buffer[index - 1] != '\n')
  {
    k_writeScr("Enter Username: ", 1, 0);
    k_writeScr(buffer, 1, 16);
    __asm__("hlt");
    k_clearScr();
  }
  k_writeScr(buffer, 2, 0);
  //Clear input buffer
  clearBuffer();

  k_writeScr("Enter password: ", 3, 0);

  //Read password
  while (buffer[index - 1] != '\n')
  {
    __asm__("hlt");
  }

  //Compare entered password to actual password
  uint8_t match = cmpStr("password", buffer, 8, (input_length - 1));

  if (match == 0)
  {
    k_clearScr();
    k_writeScrSingleColor("YOU ARE NOT AUTHORIZED TO USE THIS OS.", 9, 20, 0x04);
    __asm__("cli");
    __asm__("hlt");
  }

  k_clearScr();

  //If successful login, prime first 20 primes
  k_writeScrColor("First 20 Primes:", 0, 0, 1);

  int j;
  int k = 3;
  int l = 1;
  char buf[5];
  k_writeScr("2", l++, 0);
  for (int i = 2; i <= 20;)
  {

    for (j = 2; j <= k - 1; ++j)
    {
      if (k % j == 0)
      {
        break;
      }
    }
    if (j == k)
    {
      convert_num(k, buf);
      k_writeScr(buf, l++, 0);
      ++i;
    }
    ++k;
  }

  __asm__("cli");
  __asm__("hlt");
}

uint8_t cmpStr(char *password, char *string, uint8_t password_length, uint8_t length)
{
  uint8_t match = 0;

  if (length != password_length)
    return match;

  for (uint8_t i = 0; i < password_length; ++i)
  {
    if (string[i] != password[i])
    {
      return match;
    }
  }

  match = 1;
  return match;
}

void convert_num(unsigned int num, char buf[])
{

  if (num == 0)
  {
    buf[0] = '0';
    buf[1] = '\0';
  }
  else
  {
    convert_num_h(num, buf);
  }
}

int convert_num_h(unsigned int num, char buf[])
{

  if (num == 0)
    return 0;

  int i = convert_num_h(num / 10, buf);
  buf[i] = num % 10 + '0';
  buf[i + 1] = '\0';
  return i + 1;
}
