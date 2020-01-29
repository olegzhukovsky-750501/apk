#include <stdio.h>
#include <conio.h>
#include <Windows.h>
#include <dos.h>

void sound();
void statusWord();
void divRatio();
void randNum();
void initCount(int iMax);
int getRandomValue();

void main()
{
	char a;

	while (1)
	{
		clrscr();
		printf("1 - Generate sound\n2 - Status word\n3 - Frequency division ratio\n4 - Random number generator\n0 - Exit\n");
		fflush(stdin);
		scanf("%c", &a);

		switch (a)
		{
		case '1': clrscr(); sound(); break;
		case '2': clrscr(); statusWord(); break;
		case '3': clrscr(); divRatio(); break;
		case '4': clrscr(); randNum(); break;
		case '0': return;
		default: printf("\nBad input, try again\n");
		}
		printf("Click any key to continue\n");
		getch();
	}
}

void sound()
{
	int freq[9] = { 349,392,440,349,440,440,392,349,392 };
	int sleep[9] = { 600,300,600,300,300,300,300,300,300 };
	int timerClock = 1193180;
	int iValue;

	for (int i = 0; i < 9; ++i)
	{
		outport(0x43, 0xB6);
		iValue = timerClock / freq[i]; //DELITEL CHASTOTY

		outp(0x42, iValue % 256);

		outp(0x42, iValue / 256);

		outp(0x61, inp(0x61) | 3);    //SPEAKER - ON
		delay(sleep[i]);

		outp(0x61, inp(0x61) & 0xFC);    //SPEAKER - OFF

		delay(200); ;
	}
}

void statusWord()
{
	unsigned char controlBytes[3] = { 226, 228, 232 };
	unsigned char state;
	unsigned char ports[3] = { 0x40, 0x41, 0x42 };


	for (int i = 0; i < 3; ++i)
	{
		outp(0x43, controlBytes[i]);

		state = inp(ports[i]);

		printf("Channel %d: ", i);
		for (int j = 7; j >= 0; --j)
		{
			printf("%d", (state >> j) & 1);
		}
		printf("\n");
	}
}

void divRatio()
{
	int ports[3] = { 0x40, 0x41, 0x42 };
	int controlBytes[3] = { 0, 64, 128 };
	int iValue, iHigh, iLow;

	printf("Division ratio:\n");

	for (int i = 0; i < 3; ++i)
	{
		if (i == 2)
		{
			outp(0x61, inp(0x61) | 3); //SPEAKER - ON
		}

		outp(0x43, controlBytes[i]);
		iLow = inp(ports[i]);
		iHigh = inp(ports[i]);
		iValue = iHigh * 256 + iLow;

		if (i == 2)
		{
			outp(0x61, inp(0x61) & 0xFC); //SPEAKER - OFF
		}
		printf("Channel %d: %X\n", i, iValue);
	}
}

void initCount(int iMax)
{
	outp(0x43, 0xB6); //10110110 read/write low then high
	outp(0x42, iMax & 0x00FF);
	outp(0x42, (iMax & 0xFF00) >> 8);

	outp(0x61, inp(0x61) | 1);
}

int getRandomValue()
{
	int number;
	outp(0x43, 0x86); //10000110 block counter
	number = inp(0x42);
	number = (inp(0x42) << 8) + number;
	return number;
}
void randNum()
{
	int iMax;
	do
	{
		clrscr();
		printf("Enter limit: ");
		fflush(stdin);

	} while (!scanf("%d", &iMax) || iMax <= 0);

	initCount(iMax);
	int number = getRandomValue();
	printf("Random number: %d\n", number);
}
