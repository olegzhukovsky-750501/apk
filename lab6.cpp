#include <dos.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>

int ready = 0;

void interrupt(*old09)(...);
void interrupt new09(...)
{
	unsigned char val = inp(0x60);

	if (val != 0xFA)
	{
		printf("\t%X", val);
	}

	(*old09)();

	ready = 1;
}

void highlight(int code)
{
	int i = 0;
	while ((inp(0x64) & 0x02) != 0x00); //WAIT FOR 1 - 0

	for (i = 0; i < 3; i++)
	{
		outp(0x60, 0xED);
		if (inp(0x60) != 0xFE)
		{
			break;
		}
	}

	while ((inp(0x64) & 0x02) != 0x00);

	for (i = 0; i < 3; i++)
	{
		outp(0x60, code);
		if (inp(0x60) != 0xFE)
		{
			break;
		}
	}
}

void main()
{
	int code = 0;

	int lightFlag = 0;
	int quitFlag = 0;
	unsigned char ch;

	old09 = getvect(0x09);
	setvect(0x09, new09);

	while (!quitFlag)
	{
		ready = 0;
		if (kbhit())
		{
			ch = getch();
			if (ch == 27) // 27 - ESC
			{
				quitFlag = 1;
			}
			else if (ch == 'h')
			{
				if (lightFlag == 1)
				{
					lightFlag = 0;
				}
				else
				{
					lightFlag = 1;
				}
			}
		}
		else if (lightFlag == 1)
		{
			for (code = 0; code < 8; code++)
			{
				highlight(code);
				delay(100);
			}
		}

		while (!ready);
	}

	setvect(0x09, old09);
}
