.386p
.MODEL LARGE


DATA segment para use16
DATA_BEGIN = $


S_DESC struc        ;SEGMENT DESCRIPTOR STRUCTURE
    LIMIT dw 0      ;SEGMENT LIMIT(15:00)
    BASE_LOW dw 0   ;BASE ADDRESS, LOW PART(15:0)
    BASE_MID db 0   ;MIDDLE PART (23:16)
    ACCESS db 0     ;ACCESS BYTE
    ATTRIBS db 0    ;SEGMENT LIMIT(19:16)
    BASE_HIGH db 0  ;BASE ADDRESS, HIGH PART
S_DESC ends

I_DESC struc        ;INTERRUPT DESCRIPTOR TABLE STRUCTURE
    OFFS_LOW dw 0   ;HANDLER ADDRESS(0:15)
    SEL      dw 0   ;CODE SELECTOR
    PARAMS   db 0   ;PARAMETERS 
    ACCESS   db 0   ;ACCESS LEVEL
    OFFS_HIGH dw 0  ;HANDLER ADDRESS(31:16)
I_DESC ends   

R_IDTR struc        ;IDTR STRUCTURE
    LIMIT dw 0      ;INTERRUPT DESCRIPTOR TABLE LIMIT
    IDT_LOW dw 0    ;LINEAR BASE ADDRESS (0:15)
    IDT_HIGH dw 0   ;LINEAR BASE ADDRESS (31:16) 
R_IDTR ends


ACS_PRESENT EQU 10000000B ;PXXXXXXX - БИТ ПРИСУТСТВИЯ
ACS_CSEG    EQU 00011000B ;XXXXIXXX - ТИП СЕГМЕНТА(ДАННЫЕ - 0, КОД - 1)
ACS_DSEG    EQU 00010000B ;XXXSXXXX - БИТ СЕГМЕНТА, ОБЪЕКТ ЯВЛЯЕТСЯ СЕГМЕНТОМ
ACS_READ    EQU 00000010B ;XXXXXXRX - БИТ ЧТЕНИЯ, МОЖНО ЧИТАТЬ СЕГМЕНТ КОДА
ACS_WRITE   EQU 00000010B ;XXXXXXWX - БИТ ЗАПИСИ, МОЖНО ЗАПИСЫВАТЬ В СЕГМЕНТ ДАННЫХ
ACS_CODE    =   ACS_PRESENT or ACS_CSEG ; AR CODE SEG
ACS_DATA    = ACS_PRESENT or ACS_DSEG or ACS_WRITE; AR DATA SEG
ACS_STACK   = ACS_PRESENT or ACS_DSEG or ACS_WRITE; AR STACK SEG
ACS_INT_GATE EQU 00001110B
ACS_TRAP_GATE EQU 00001111B ;XXXXSICR - ПОДЧИНЕННЫЙ СЕГМЕНТ КОДА, ДОСТУПЕН ДЛЯ ЧТЕНИЯ
ACS_IDT         EQU ACS_DATA                    ;AR таблицы IDT    
ACS_INT         EQU ACS_PRESENT or ACS_INT_GATE
ACS_TRAP        EQU ACS_PRESENT or ACS_TRAP_GATE
ACS_DPL_3       EQU 01100000B                   ;X<DPL,DPL>XXXXX - ПРИВИЛЕГИИ ДОСТУПА, ДОСТУП МОЖЕТ ПОЛУЧИТЬ ЛЮБОЙ КОД
;=================================================================================================================================
;GDT - GLOBAL TABLE DESCRIPTOR
GDT_BEGIN   = $
GDT label   word                            ;Метка начала GDT (GDT: не работает)
GDT_0       S_DESC <0,0,0,0,0,0>            ;Не используется                  
GDT_GDT     S_DESC <GDT_SIZE-1,,,ACS_DATA,0,> ;Описывает саму таблицу GDT                 
GDT_CODE_RM S_DESC <SIZE_CODE_REAL_MODE-1,,,ACS_CODE,0,>             
GDT_DATA    S_DESC <SIZE_DATA-1,,,ACS_DATA+ACS_DPL_3,0,>      
GDT_STACK   S_DESC <1000h-1,,,ACS_DATA,0,>                    
GDT_TEXT    S_DESC <2000h-1,8000h,0Bh,ACS_DATA+ACS_DPL_3,0,0> 
GDT_CODE_PM S_DESC <SIZE_CODE_PM-1,,,ACS_CODE+ACS_READ,0,>    
GDT_IDT     S_DESC <SIZE_IDT-1,,,ACS_IDT,0,>                  
GDT_SIZE    = ($ - GDT_BEGIN)               ;Размер GDT
;=================================================================================================================================
;SEGMENTS SELECTORS
CODE_RM_DESC = (GDT_CODE_RM - GDT_0)
DATA_DESC    = (GDT_DATA - GDT_0)      
STACK_DESC   = (GDT_STACK - GDT_0)
TEXT_DESC    = (GDT_TEXT - GDT_0)  
CODE_PM_DESC = (GDT_CODE_PM - GDT_0)
IDT_DESC     = (GDT_IDT - GDT_0)
;=================================================================================================================================
;IDT - INTERRUPT DESCRIPTOR TABLE
IDTR Register_IDTR  <SIZE_IDT,0,0>                           ;Формат регистра ITDR   
IDT label   word                                             ;Метка начала IDT
IDT_BEGIN   = $
IRPC    N, 0123456789ABCDEF
	IDT_0&N I_DESC <0, CODE_PM_DESC,0,ACS_TRAP,0>            ; 00...0F
ENDM

IRPC    N, 0123456789ABCDEF
	IDT_1&N I_DESC <0, CODE_PM_DESC, 0, ACS_TRAP, 0>         ; 10...1F
ENDM

IDT_KEYBOARD I_DESC <0,CODE_PM_DESC,0,ACS_INT,0>             ;IRQ 1 - прерывание клавиатуры

IRPC    N, 23456789ABCDEF
	IDT_2&N         I_DESC <0, CODE_PM_DESC, 0, ACS_INT, 0>  ; 22...2F
ENDM
SIZE_IDT        =       ($ - IDT_BEGIN)
;====================================================================================================================================
;MESSAGES
intro_Message db "Press any key to set protected mode.",10,13,"This key will be used to return to real mode.",10,13,'$'
MSG_EXC db "exception: XX",0
return_Message db "Welcome back to the real mode! ",01h, 10, 13, '$'
real_mode_Message db "Welcome to the protected mode!",0
switch_mode_Message db "Press ", 22h
;RETURN KEY
key db 0
switch_mode_message_ending db 22h, " to set real mode.", 0
key_scan db 0
kbhit_Message db "Scan-code of last key : "
kbhit_key db 8 dup (" ") ,0
;====================================================================================================================================
;значения регистров масок контроллера прерываний
IC_Mask_Slave db 0
IC_Mask_Master db 0
;====================================================================================================================================
SIZE_DATA = ($ - DATA_BEGIN)
DATA ends
;************************************************************************************************************************************
;Сегмент кода реального режима
CODE_PM  segment para use32
CODE_PM_BEGIN   = $
    assume CS:CODE_PM,DS:DATA,ES:DATA           ;Указание сегментов для компиляции
ENTER_PM:                                       ;Точка входа в защищенный режим
    call CLRSCR                                 ;Процедура очистки экрана
    xor  edi,edi                                ;В edi смещение на экране
    lea  esi,real_mode_Message                  ;В esi адрес буфера
    call BUFFER_OUTPUT                          ;Вывести строку-приветствие в защищенном режиме
    
    add  edi,160
    lea esi,  switch_mode_Message
    call BUFFER_OUTPUT
    
    add  edi,320                                ;Перевести курсор на следующую строку
    lea  esi,kbhit_Message
    call BUFFER_OUTPUT                          ;Вывести поле для вывода скан-кода клавиатуры

WAITING_KEY:                                    ;Ожидание нажатия кнопки выхода из защищенного режима
    jmp  WAITING_KEY                            ;Если был нажата не клавиша выхода

EXIT_PM:                                        ;Точка выхода из 32-битного сегмента кода    
    db 66H
    retf    
                                        ;Переход в 16-битный сегмент кода

EXIT_FROM_INTERRUPT:                            ;Точка выхода для выхода напрямую из обработчика прерываний
    popad
    pop es
    pop ds
    pop eax                                     ;Снять со стека старый EIP
    pop eax                                     ;CS  
    pop eax                                     ;И EFLAGS
    sti                                         ;Обязательно, без этого обработка аппаратных прерываний отключена
    db 66H
    retf                                        ;Переход в 16-битный сегмент кода    

WORD_TO_DEC proc near                           ;Процедура перевода слова в строку
    pushad    
    movzx eax,ax
    xor cx,cx              
    mov bx,10              
LOOP1:                                          ;Цикл по извлечению цифры             
    xor dx,dx              
    div bx                 
    add dl,'0'             
    push dx                
    inc cx                 
    test ax,ax             
    jnz LOOP1          
LOOP2:                                          ;Цикл по заполнению буфера                 
    pop dx                 
    mov [di],dl            
    inc di                 
    loop LOOP2         
    popad
    ret
WORD_TO_DEC endp

DIGIT_TO_HEX proc near                          ;Процедура перевода цифры в шеснадцатеричный вид
    add al,'0'            
    cmp al,'9'            
    jle DTH_END           
    add al,7              
DTH_END:
    ret        
DIGIT_TO_HEX endp

BYTE_TO_HEX proc near                           ;Процедура перевода числа в шеснадцатеричный вид
    push ax
    mov ah,al             
    shr al,4              
    call DIGIT_TO_HEX     
    mov [di],al           
    inc di                
    mov al,ah             
    and al,0Fh            
    call DIGIT_TO_HEX     
    mov [di],al           
    inc di                
    pop ax
    ret    
BYTE_TO_HEX endp

M = 0                           
IRPC N0, 0123456789ABCDEF
EXC_0&N0 label word                              ;Обработчики исключений
    cli 
    jmp EXC_HANDLER
endm

M = 010H
IRPC N1, 0123456789ABCDEF                        ;Обработчики исключений
EXC_1&N1 label word                          
    cli
    jmp EXC_HANDLER
endm

EXC_HANDLER proc near                           ;Процедура вывода обработки исключений
    call CLRSCR                                 ;Очистка экрана
    lea  esi, MSG_EXC
    mov  edi, 40*2
    call BUFFER_OUTPUT                          ;Вывод предупреждения
    pop eax                                     ;Снять со стека старый EIP
    pop eax                                     ;CS  
    pop eax                                     ;И EFLAGS
    sti                                         ;Обязательно, без этого обработка аппаратных прерываний отключена
    db 66H
    retf                                        ;Переход в 16-битный сегмент кода    
EXC_HANDLER     ENDP

DUMMY_IRQ_MASTER proc near                      ;Заглушка для аппаратных прерываний ведущего контроллера
    push eax
    mov  al,20h
    out  20h,al
    pop  eax
    iretd
DUMMY_IRQ_MASTER endp

DUMMY_IRQ_SLAVE  proc near                      ;Заглушка для аппаратных прерываний ведомого контроллера
    push eax
    mov  al,20h
    out  20h,al
    out  0A0h,al
    pop  eax
    iretd
DUMMY_IRQ_SLAVE  endp

KEYBOARD_HANDLER proc near                      ;Обработчик прерывания клавиатуры
    push ds
    push es
    pushad                                      ;Сохранить расширенные регистры общего назначения
    in   al,60h                                 ;Считать скан код последней нажатой клавиши                                ;
    
    cmp  al,key_scan                            ;Если была нажата кнопка выхода
    je   KEYBOARD_EXIT                          ;Тогда на выход из защищенного режима   
    
    mov  ds:[kbhit_key],al                      ;Записать его в память
    lea  edi,ds:[kbhit_key]
    mov  al,ds:[kbhit_key]
    xor  ah,ah
    call BYTE_TO_HEX                            ;Преобразовать скан-код в строку
    mov  edi, 530
      
    lea  esi,ds:[kbhit_key];scan_code                   
    call BUFFER_OUTPUT                          ;Вывести строку со скан-кодом
    jmp  KEYBOARD_RETURN  
KEYBOARD_EXIT:
    mov  al,20h
    out  20h,al
    db 0eah
    dd OFFSET EXIT_FROM_INTERRUPT 
    dw CODE_PM_DESC  
KEYBOARD_RETURN:
    mov  al,20h
    out  20h,al                                 ;Отправка сигнала контроллеру прерываний
    popad                                       ;Восстановить значения регистров
    pop es
    pop ds
    iretd                                       ;Выход из прерывания
KEYBOARD_HANDLER endp

CLRSCR  proc near                               ;Процедура очистки консоли
    push es
    pushad
    mov  ax,TEXT_DESC                           ;Поместить в ax дескриптор текста
    mov  es,ax
    xor  edi,edi
    mov  ecx,80*25                              ;Количество символов в окне
    mov  ax,700h
    rep  stosw
    popad
    pop  es
    ret
CLRSCR  endp

BUFFER_OUTPUT proc near                         ;Процедура вывода текстового буфера, оканчивающегося 0
    push es
    PUSHAD
    mov  ax,TEXT_DESC                           ;Поместить в es селектор текста
    mov  es,ax
OUTPUT_LOOP:                                    ;Цикл по выводу буфера
    lodsb                                       
    or   al,al
    jz   OUTPUT_EXIT                            ;Если дошло до 0, то конец выхода
    stosb
    inc  edi
    jmp  OUTPUT_LOOP
OUTPUT_EXIT:                                    ;Выход из процедуры вывода
    popad
    pop  es
    ret
BUFFER_OUTPUT ENDP

SIZE_CODE_PM     =       ($ - CODE_PM_BEGIN)
CODE_PM  ENDS
;*************************************************************************************************************************************************
CODE_REAL_MODE SEGMENT para use16
ASSUME cs : CODE_REAL_MODE, ds : DATA, es : DATA
CODE_REAL_MODE_BEGIN = $

clear_regs proc
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx
    ret    
clear_regs endp 

println proc ;в регистре dx должен находиться адрес выводимой строки
    push ax
    mov ah, 09h
    int 21h
    pop ax
    ret    
println endp 

START:
main proc	
	mov ax, DATA                                 ;Инициализиция сегментных регистров
	mov ds,ax                                   
	mov es,ax  
	call clear_regs

	lea dx, intro_Message
	call println

	mov ah, 07h
	int 21h
	mov key, al
	
	in al, 60h
	mov key_scan, al
	mov al, 00h
	out 60h, al
	
	xor ax,ax

ENABLE_A20:                                     ;Открыть линию A20
    in  al,92h                                                                              
    or  al,2                                    ;Установить бит 1 в 1                                                   
    out 92h,al 
    
SAVE_MASK:                                      ;Сохранить маски прерываний     
    in      al,21h
    mov     IC_Mask_Master,al                  
    in      al,0A1h
    mov     IC_Mask_Slave, al   
    
DISABLE_INTERRUPTS:                             ;Запрет маскируемых и немаскируемых прерываний        
    cli                                         ;Запрет маскирумых прерываний
    in  al,70h	
	or	al,10000000b                            ;Установить 7 бит в 1 для запрета немаскируемых прерываний
	out	70h,al
	nop
	
LOAD_GDT:                                       ;Заполнить глобальную таблицу дескрипторов            
    mov ax,DATA
    mov dl,ah
    xor dh,dh
    shl ax,4
    shr dx,4
    mov si,ax
    mov di,dx
    
WRITE_GDT:                                      ;Заполнить дескриптор GDT
    lea bx,GDT_GDT
    mov ax,si
    mov dx,di
    add ax,offset GDT
    adc dx,0
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_CODE_RM:                                  ;Заполнить дескриптор сегмента кода реального режима
    lea bx,GDT_CODE_RM
    mov ax,cs
    xor dh,dh
    mov dl,ah
    shl ax,4
    shr dx,4
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_DATA:                                     ;Записать дескриптор сегмента данных
    lea bx,GDT_DATA
    mov ax,si
    mov dx,di
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_STACK:                                    ;Записать дескриптор сегмента стека
    lea bx, GDT_STACK
    mov ax,ss
    xor dh,dh
    mov dl,ah
    shl ax,4
    shr dx,4
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_CODE_PM:                                  ;Записать дескриптор кода защищенного режима
    lea bx,GDT_CODE_PM
    mov ax,CODE_PM
    xor dh,dh
    mov dl,ah
    shl ax,4
    shr dx,4
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh        
    or  [bx][I_DESC.ATTRIBS],40h
    
WRITE_IDT:                                      ;Записать дескриптор IDT
    lea bx,GDT_IDT
    mov ax,si
    mov dx,di
    add ax,OFFSET IDT
    adc dx,0
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh        
    mov IDTR.IDT_LOW,ax
    mov IDTR.IDT_HIGH,dx	
	
FILL_IDT:                                        ;Заполнить таблицу дескрипторов шлюзов прерываний
    irpc    N0, 0123456789ABCDEF                 ;Заполнить шлюзы 00-0F исключениями
        lea eax, EXC_0&N0
        mov IDT_0&N0.OFFS_LOW,ax
        shr eax, 16
        mov IDT_0&N0.OFFS_HIGH,ax
    endm
    
    irpc    N1, 0123456789ABCDEF                 ;Заполнить шлюзы 10-1F исключениями
        lea eax, EXC_1&N1
        mov IDT_1&N1.OFFS_LOW,ax
        shr eax, 16
        mov IDT_1&N1.OFFS_HIGH,ax
    endm
    
    lea eax, KEYBOARD_HANDLER                   ;Поместить обработчик прерывания клавиатуры на 21 шлюз
    mov IDT_KEYBOARD.OFFS_LOW,ax
    shr eax, 16
    mov IDT_KEYBOARD.OFFS_HIGH,ax
    
    irpc    N, 234567                           ;Заполнить вектора 22-27 заглушками
        lea eax,DUMMY_IRQ_MASTER
        mov IDT_2&N.OFFS_LOW, AX
        shr eax,16
        mov IDT_2&N.OFFS_HIGH, AX
    endm
    
    irpc    N, 89ABCDEF                         ;Заполнить вектора 28-2F заглушками
        lea eax,DUMMY_IRQ_SLAVE
        mov IDT_2&N.OFFS_LOW,ax
        shr eax,16
        mov IDT_2&N.OFFS_HIGH,ax
    endm
    
    lgdt fword ptr GDT_GDT                      ;Загрузить регистр GDTR
    lidt fword ptr IDTR                         ;Загрузить регистр IDTR
    
    mov eax,cr0                                 ;Получить управляющий регистр cr0
    or  al,00000001b                            ;Установить бит PE в 1
    mov cr0,eax                                 ;Записать измененный cr0 и тем самым включить защищенный режим

OVERLOAD_CS:                                    ;Перезагрузить сегмент кода на его дескриптор
    db  0EAH
    dw  $+4
    dw  CODE_RM_DESC        

OVERLOAD_SEGMENT_REGISTERS:                     ;Переинициализировать остальные сегментные регистры на дескрипторы
    mov ax,DATA_DESC
    mov ds,ax                         
    mov es,ax                         
    mov ax,STACK_DESC
    mov ss,ax                         
    xor ax,ax
    mov fs,ax                                   ;Обнулить регистр fs
    mov gs,ax                                   ;Обнулить регистр gs
    lldt ax                                     ;Обнулить регистр LDTR - не использовать таблицы локальных дескрипторов

PREPARE_TO_RETURN:
    push cs                                     ;Сегмент кода
    push offset BACK_TO_RM                      ;Смещение точки возврата
    lea  edi,ENTER_PM                           ;Получить точку входа в защищенный режим
    mov  eax,CODE_PM_DESC                       ;Получить дескриптор кода защищенного режима
    push eax                                    ;Занести их в стек
    push edi                                    

REINITIALIAZE_CONTROLLER_FOR_PM:                ;Переинициализировать контроллер прерываний на вектора 20h, 28h
    mov al,00010001b                            ;ICW1 - переинициализация контроллера прерываний
    out 20h,al                                  ;Переинициализируем ведущий контроллер
    out 0A0h,al                                 ;Переинициализируем ведомый контроллер
    mov al,20h                                  ;ICW2 - номер базового вектора прерываний
    out 21h,al                                  ;ведущего контроллера
    mov al,28h                                  ;ICW2 - номер базового вектора прерываний
    out 0A1h,al                                 ;ведомого контроллера
    mov al,04h                                  ;ICW3 - ведущий контроллер подключен к 3 линии
    out 21h,al       
    mov al,02h                                  ;ICW3 - ведомый контроллер подключен к 3 линии
    out 0A1h,al      
    mov al,11h                                  ;ICW4 - режим специальной полной вложенности для ведущего контроллера
    out 21h,al        
    mov al,01h                                  ;ICW4 - режим обычной полной вложенности для ведомого контроллера
    out 0A1h,al       
    mov al, 0                                   ;Размаскировать прерывания
    out 21h,al                                  ;Ведущего контроллера
    out 0A1h,al                                 ;Ведомого контроллера

ENABLE_INTERRUPTS_0:                            ;Разрешить маскируемые и немаскируемые прерывания
    in  al,70h	
	and	al,01111111b                            ;Установить 7 бит в 0 для запрета немаскируемых прерываний
	out	70h,al
	nop
    sti                                         ;Разрешить маскируемые прерывания

GO_TO_CODE_PM:                                  ;Переход к сегменту кода защищенного режима
    db 66h                                      
    retf

BACK_TO_RM:                                     ;Точка возврата в реальный режим
    cli                                         ;Запрет маскируемых прерываний
    in  al,70h	                                ;И не маскируемых прерываний
	or	AL,10000000b                            ;Установить 7 бит в 1 для запрета немаскируемых прерываний
	out	70h,AL
	nop

REINITIALISE_CONTROLLER:                        ;Переиницализация контроллера прерываний               
    mov al,00010001b                            ;ICW1 - переинициализация контроллера прерываний
    out 20h,al                                  ;Переинициализируем ведущий контроллер
    out 0A0h,al                                 ;Переинициализируем ведомый контроллер
    mov al,8h                                   ;ICW2 - номер базового вектора прерываний
    out 21h,al                                  ;ведущего контроллера
    mov al,70h                                  ;ICW2 - номер базового вектора прерываний
    out 0A1h,al                                 ;ведомого контроллера
    mov al,04h                                  ;ICW3 - ведущий контроллер подключен к 3 линии
    out 21h,al       
    mov al,02h                                  ;ICW3 - ведомый контроллер подключен к 3 линии
    out 0A1h,al      
    mov al,11h                                  ;ICW4 - режим специальной полной вложенности для ведущего контроллера
    out 21h,al        
    mov al,01h                                  ;ICW4 - режим обычной полной вложенности для ведомого контроллера
    out 0A1h,al

PREPARE_SEGMENTS:                               ;Подготовка сегментных регистров для возврата в реальный режим          
    mov GDT_CODE_RM.LIMIT,0FFFFh                ;Установка лимита сегмента кода в 64KB
    mov GDT_DATA.LIMIT,0FFFFh                   ;Установка лимита сегмента данных в 64KB
    mov GDT_STACK.LIMIT,0FFFFh                  ;Установка лимита сегмента стека в 64KB
    db  0EAH                                    ;Перезагрузить регистр cs
    dw  $+4
    dw  CODE_RM_DESC                            ;На сегмент кода реального режима
    mov ax,DATA_DESC                            ;Загрузим сегментные регистры дескриптором сегмента данных
    mov ds,ax                                   
    mov es,ax                                   
    mov fs,ax                                   
    mov gs,ax                                   
    mov ax,STACK_DESC
    mov ss,ax                                   ;Загрузим регистр стека дескриптором стека

ENABLE_REAL_MODE:                               ;Включим реальный режим
    mov eax,cr0
    and al,11111110b                            ;Обнулим 0 бит регистра cr0
    mov cr0,eax                        
    db  0EAH
    dw  $+4
    dw  CODE_REAL_MODE                          ;Перезагрузим регистр кода
    mov ax,STACK_A
    mov ss,ax                      
    mov ax,DATA
    mov ds,ax                      
    mov es,ax
    xor ax,ax
    mov fs,ax
    mov gs,ax
    mov IDTR.LIMIT, 3FFH                
    mov dword ptr  IDTR+2, 0            
    lidt fword ptr IDTR                 

REPAIR_MASK:                                   ;Восстановить маски прерываний
    mov al,IC_Mask_Master
    out 21h,al                                  ;Ведущего контроллера
    mov al,IC_Mask_Slave
    out 0A1h,al                                 ;Ведомого контроллера

ENABLE_INTERRUPTS:                              ;Разрешить маскируемые и немаскируемые прерывания
    in  al,70h	
	and	al,01111111b                            ;Установить 7 бит в 0 для разрешения немаскируемых прерываний
	out	70h,al
    nop
    sti                                         ;Разрешить маскируемые прерывания

DISABLE_A20:                                    ;Закрыть вентиль A20
    in  al,92h
    and al,11111101b                            ;Обнулить 1 бит - запретить линию A20
    out 92h, al

EXIT:                                           ;Выход из программы
    mov ax,3h
    int 10H                                     ;Очистить видео-режим    
    lea dx, return_Message
    mov ah,9h
    int 21h                                     ;Вывести сообщение
    mov ax,4C00h
    int 21H                                     ;Выход в dos
main endp
                     
SIZE_CODE_REAL_MODE = ($ - CODE_REAL_MODE_BEGIN)                    
CODE_REAL_MODE ENDS 
;***************************************************************************************************************

STACK_A segment para stack
    db  1000h dup(?)
STACK_A  ends

end START

