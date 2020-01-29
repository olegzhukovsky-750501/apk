#include <stdio.h>
#include <time.h>
#include <math.h>
#include <Windows.h>

#define CALC_COUNT 1000000
#define SIZE 8

int main()
{
	time_t start, end;
	double time;
	int result;
	int matrix[SIZE][SIZE];
	int strRes[SIZE];

	for (int i = 0; i < SIZE; i++)
		for (int j = 0; j < SIZE; j++)
		{
			matrix[i][j] = rand() % 50;
		}

	start = clock();
	for (int c = 0; c < CALC_COUNT; c++)
	{
		for (int i = 0; i < SIZE; i++)
		{
			result = 0;
			for (int j = 0; j < SIZE; j++)
			{
				result += matrix[i][j];
			}
			strRes[i] = result;
		}
	}
	end = clock();
	for (int i = 0; i < SIZE; i++)
	{
		printf("%d ", strRes[i]);
	}

	time = (double)(end - start) / CLOCKS_PER_SEC;
	printf("\nPROCESSING TIME (C): %.6lf\n", time);

	for (int i = 0; i < SIZE; i++)
		strRes[i] = 0;

	start = clock();

	for (int c = 0; c < CALC_COUNT; c++)
	{
		result = 0;
		_asm
		{
			PUSHA
			XOR ESI, ESI
			XOR EDI, EDI
			XOR EDX, EDX
			MOV EBX, SIZE
			IMUL EBX, SIZE
			LOOP_ASM_1 :
				MOV ECX, SIZE
			LOOP_ASM_2 :
				CMP EBX, 0
				JE  EXIT_ASM
				ADD EDX, [matrix + ESI]
				ADD ESI, 4
				DEC EBX
				DEC ECX
				CMP ECX, 0
				JNE LOOP_ASM_2
				MOV [strRes+EDI], EDX
				XOR EDX, EDX
				ADD EDI, 4
				JMP LOOP_ASM_1
			EXIT_ASM:
			POPA
		}
	}

	end = clock();

	for (int i = 0; i < SIZE; i++)
	{
		printf("%d ", strRes[i]);
	}

	time = (double)(end - start) / CLOCKS_PER_SEC;
	printf("\nPROCESSING TIME (asm): %.6lf\n", time);


	start = clock();

	for (int c = 0; c < CALC_COUNT; c++)
	{
		result = 0;
		_asm
		{
			PUSHA
			XOR ESI, ESI
			XOR EDI, EDI
			MOV EBX, SIZE
			IMUL EBX, SIZE
			PXOR MM0, MM0
			PXOR MM7, MM7
			LOOP_MMX_1 :
				MOV ECX, SIZE
			LOOP_MMX_2 :
				CMP EBX, 0
				JE  EXIT_MMX
				PADDD MM0, [matrix + ESI]
				ADD ESI, 8
				SUB EBX, 2
				SUB ECX, 2
				CMP ECX, 0
				JNE LOOP_MMX_2

				MOVD [strRes + EDI], MM0
				PSRLQ MM0, 32
				MOVD MM7, [strRes + EDI]
				PADDD MM7, MM0
				MOVD [strRes + EDI], MM7
				PXOR MM0, MM0
				PXOR MM7, MM7
				ADD EDI, 4
				JMP LOOP_MMX_1
				EXIT_MMX:
				POPA
				EMMS

		}
	}

	end = clock();

	for (int i = 0; i < SIZE; i++)
	{
		printf("%d ", strRes[i]);
	}

	time = (double)(end - start) / CLOCKS_PER_SEC;
	printf("\nPROCESSING TIME (MMX): %.6lf \n", time);


	system("pause");
	return 0;
}