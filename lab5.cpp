#include <dos.h>
#include <ctype.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <stdlib.h>

int msCounter = 0;

void interrupt far(*old_70h)(...);
void interrupt far new_70h(...)
{
	msCounter++;

	outp(0x70, 0x0C);
	inp(0x71); //RESET BITS AT 0x0C

	outp(0x20, 0x20); //EOI FOR MASTER IC
	outp(0xA0, 0x20); //EOI FOR SLAVE IC
}


unsigned char intToBCD(int val)
{
	return (unsigned char)((val / 10) << 4) | (val % 10);
}

int BCDToInt(int bcd)
{
	return bcd % 16 + bcd / 16 * 10;
}

void waitForAccessClock()
{
	do
	{
		outp(0x70, 0x0A); //SELECT STATE REGISTER A

	} while (inp(0x71) & 0x80);
}

void banUpdateClock()
{
	unsigned char val;
	// WAITING FOR ACCESS
	waitForAccessClock();
	//SETTING 7TH BIT TO 1 - INSTALLATION IS IN PROGRESS
	outp(0x70, 0x0B);
	val = inp(0x71) | 0x80; //0x80 - 10000000

	//SET VALUE IN STATE REGISTER B
	outp(0x70, 0x0B);
	outp(0x71, val);
}

void unbanUpdateClock()
{
	unsigned char val;
	waitForAccessClock();
	outp(0x70, 0x0B);
	val = inp(0x71) & 0x7F; //SET 7TH BIT TO 0 - ALLOW CLOCK UPDATE

	outp(0x70, 0x0B);
	outp(0x71, val);
}
void setTime()
{
	unsigned int seconds, minutes, hours, weekDay, monthDay, month, year;

	printf("Enter hours: ");
	scanf("%d", &hours);
	printf("Enter minutes: ");
	scanf("%d", &minutes);
	printf("Enter seconds: ");
	scanf("%d", &seconds);
	printf("Enter week day: ");
	scanf("%d", &weekDay);
	printf("Enter month day: ");
	scanf("%d", &monthDay);
	printf("Enter month: ");
	scanf("%d", &month);
	printf("Enter year: ");
	scanf("%d", &year);

	banUpdateClock();

	outp(0x70, 0x00);
	outp(0x71, intToBCD(seconds));

	outp(0x70, 0x02);
	outp(0x71, intToBCD(minutes));

	outp(0x70, 0x04);
	outp(0x71, intToBCD(hours));

	outp(0x70, 0x06);
	outp(0x71, intToBCD(weekDay));

	outp(0x70, 0x07);
	outp(0x71, intToBCD(monthDay));

	outp(0x70, 0x08);
	outp(0x71, intToBCD(month));

	outp(0x70, 0x09);
	outp(0x71, intToBCD(year));

	unbanUpdateClock();
}

void getTime()
{
	unsigned char val;

	waitForAccessClock();
	outp(0x70, 0x04); // CHOOSE HOURS REGISTER
	val = inp(0x71);
	printf("%d:", BCDToInt(val));

	waitForAccessClock();
	outp(0x70, 0x02); // CHOOSE MINUTES REGISTER
	val = inp(0x71);
	printf("%d:", BCDToInt(val));

	waitForAccessClock();
	outp(0x0, 0x00); // CHOOSE SECONDS
	val = inp(0x71);
	printf("%d   ", BCDToInt(val));

	waitForAccessClock();
	outp(0x70, 0x07); // MONTH DAY
	val = inp(0x71);
	printf("DATE: %d.", BCDToInt(val));

	waitForAccessClock();
	outp(0x70, 0x08); // MONTH NUMBER
	val = inp(0x71);
	printf("%d.", BCDToInt(val));

	waitForAccessClock();
	outp(0x70, 0x09); // YEAR
	val = inp(0x71);
	printf("%d   ", BCDToInt(val));

	waitForAccessClock();
	outp(0x70, 0x06); // WEEK DAY
	val = inp(0x71);

	switch (BCDToInt(val))
	{
	case 1: printf("Sunday\n"); break;
	case 2: printf("Monday\n"); break;
	case 3: printf("Tuesday\n"); break;
	case 4: printf("Wednesday\n"); break;
	case 5: printf("Thursday\n"); break;
	case 6: printf("Friday\n"); break;
	case 7: printf("Saturday\n"); break;
	default: printf("Error\n"); break;
	}
}

void delay()
{
	unsigned long delayMS;
	unsigned char val;

	disable(); //CLI - DISABLE INTERRUPTS
	old_70h = getvect(0x70);
	setvect(0x70, new_70h);
	enable(); //STI - ENABLE INTERRUPTS

	printf("Enter delay in ms: ");
	scanf("%ld", &delayMS);

	printf("Start time: ");
	outp(0x70, 0x04);
	val = inp(0x71);

	printf("%d:", BCDToInt(val));

	outp(0x70, 0x02);
	val = inp(0x71);
	printf("%d:", BCDToInt(val));

	outp(0x70, 0x00);
	val = inp(0x71);
	printf("%d\n", BCDToInt(val));

	//ALLOW CLOCK INTERRUPTS (MAKE NON-MASKED)
	val = inp(0xA1);
	outp(0xA1, val & 0xFE); //FE - 1111 1110, 0TH BIT TO 0


	//ENABLE PERIODIC INTERRUPTS
	outp(0x70, 0x0B);
	val = inp(0x0B);
	outp(0x70, 0x0B);
	outp(0x71, val | 0x40); // 6TH BIT - 1. ALLOW IRQ8 FOR PERIODIC INTRPT

	msCounter = 0;
	while (msCounter != delayMS); // WAITING FOR MS COUNTER

	printf("\nDelay completed: %ld\n", delayMS);
	setvect(0x70, old_70h);

	printf("End time: ");
	outp(0x70, 0x04);
	val = inp(0x71);

	printf("%d:", BCDToInt(val));

	outp(0x70, 0x02);
	val = inp(0x71);
	printf("%d:", BCDToInt(val));

	outp(0x70, 0x00);
	val = inp(0x71);
	printf("%d\n", BCDToInt(val));

	unbanUpdateClock();
}

int main()
{
	unsigned char c, value;

	clrscr();

	printf("1. Show time\n");
	printf("2. Set time\n");
	printf("3. Make delay\n");
	printf("4. Exit\n");

	while (1)
	{
		c = getch();
		switch (c)
		{
		case '1':getTime(); break;
		case '2':setTime(); break;
		case '3':delay(); break;
		case '4':return 0;
		}
	}
	return 0;
}
