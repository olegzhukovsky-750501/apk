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


ACS_PRESENT EQU 10000000B ;PXXXXXXX - ��� �����������
ACS_CSEG    EQU 00011000B ;XXXXIXXX - ��� ��������(������ - 0, ��� - 1)
ACS_DSEG    EQU 00010000B ;XXXSXXXX - ��� ��������, ������ �������� ���������
ACS_READ    EQU 00000010B ;XXXXXXRX - ��� ������, ����� ������ ������� ����
ACS_WRITE   EQU 00000010B ;XXXXXXWX - ��� ������, ����� ���������� � ������� ������
ACS_CODE    =   ACS_PRESENT or ACS_CSEG ; AR CODE SEG
ACS_DATA    = ACS_PRESENT or ACS_DSEG or ACS_WRITE; AR DATA SEG
ACS_STACK   = ACS_PRESENT or ACS_DSEG or ACS_WRITE; AR STACK SEG
ACS_INT_GATE EQU 00001110B
ACS_TRAP_GATE EQU 00001111B ;XXXXSICR - ����������� ������� ����, �������� ��� ������
ACS_IDT         EQU ACS_DATA                    ;AR ������� IDT    
ACS_INT         EQU ACS_PRESENT or ACS_INT_GATE
ACS_TRAP        EQU ACS_PRESENT or ACS_TRAP_GATE
ACS_DPL_3       EQU 01100000B                   ;X<DPL,DPL>XXXXX - ���������� �������, ������ ����� �������� ����� ���
;=================================================================================================================================
;GDT - GLOBAL TABLE DESCRIPTOR
GDT_BEGIN   = $
GDT label   word                            ;����� ������ GDT (GDT: �� ��������)
GDT_0       S_DESC <0,0,0,0,0,0>            ;�� ������������                  
GDT_GDT     S_DESC <GDT_SIZE-1,,,ACS_DATA,0,> ;��������� ���� ������� GDT                 
GDT_CODE_RM S_DESC <SIZE_CODE_REAL_MODE-1,,,ACS_CODE,0,>             
GDT_DATA    S_DESC <SIZE_DATA-1,,,ACS_DATA+ACS_DPL_3,0,>      
GDT_STACK   S_DESC <1000h-1,,,ACS_DATA,0,>                    
GDT_TEXT    S_DESC <2000h-1,8000h,0Bh,ACS_DATA+ACS_DPL_3,0,0> 
GDT_CODE_PM S_DESC <SIZE_CODE_PM-1,,,ACS_CODE+ACS_READ,0,>    
GDT_IDT     S_DESC <SIZE_IDT-1,,,ACS_IDT,0,>                  
GDT_SIZE    = ($ - GDT_BEGIN)               ;������ GDT
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
IDTR Register_IDTR  <SIZE_IDT,0,0>                           ;������ �������� ITDR   
IDT label   word                                             ;����� ������ IDT
IDT_BEGIN   = $
IRPC    N, 0123456789ABCDEF
	IDT_0&N I_DESC <0, CODE_PM_DESC,0,ACS_TRAP,0>            ; 00...0F
ENDM

IRPC    N, 0123456789ABCDEF
	IDT_1&N I_DESC <0, CODE_PM_DESC, 0, ACS_TRAP, 0>         ; 10...1F
ENDM

IDT_KEYBOARD I_DESC <0,CODE_PM_DESC,0,ACS_INT,0>             ;IRQ 1 - ���������� ����������

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
;�������� ��������� ����� ����������� ����������
IC_Mask_Slave db 0
IC_Mask_Master db 0
;====================================================================================================================================
SIZE_DATA = ($ - DATA_BEGIN)
DATA ends
;************************************************************************************************************************************
;������� ���� ��������� ������
CODE_PM  segment para use32
CODE_PM_BEGIN   = $
    assume CS:CODE_PM,DS:DATA,ES:DATA           ;�������� ��������� ��� ����������
ENTER_PM:                                       ;����� ����� � ���������� �����
    call CLRSCR                                 ;��������� ������� ������
    xor  edi,edi                                ;� edi �������� �� ������
    lea  esi,real_mode_Message                  ;� esi ����� ������
    call BUFFER_OUTPUT                          ;������� ������-����������� � ���������� ������
    
    add  edi,160
    lea esi,  switch_mode_Message
    call BUFFER_OUTPUT
    
    add  edi,320                                ;��������� ������ �� ��������� ������
    lea  esi,kbhit_Message
    call BUFFER_OUTPUT                          ;������� ���� ��� ������ ����-���� ����������

WAITING_KEY:                                    ;�������� ������� ������ ������ �� ����������� ������
    jmp  WAITING_KEY                            ;���� ��� ������ �� ������� ������

EXIT_PM:                                        ;����� ������ �� 32-������� �������� ����    
    db 66H
    retf    
                                        ;������� � 16-������ ������� ����

EXIT_FROM_INTERRUPT:                            ;����� ������ ��� ������ �������� �� ����������� ����������
    popad
    pop es
    pop ds
    pop eax                                     ;����� �� ����� ������ EIP
    pop eax                                     ;CS  
    pop eax                                     ;� EFLAGS
    sti                                         ;�����������, ��� ����� ��������� ���������� ���������� ���������
    db 66H
    retf                                        ;������� � 16-������ ������� ����    

WORD_TO_DEC proc near                           ;��������� �������� ����� � ������
    pushad    
    movzx eax,ax
    xor cx,cx              
    mov bx,10              
LOOP1:                                          ;���� �� ���������� �����             
    xor dx,dx              
    div bx                 
    add dl,'0'             
    push dx                
    inc cx                 
    test ax,ax             
    jnz LOOP1          
LOOP2:                                          ;���� �� ���������� ������                 
    pop dx                 
    mov [di],dl            
    inc di                 
    loop LOOP2         
    popad
    ret
WORD_TO_DEC endp

DIGIT_TO_HEX proc near                          ;��������� �������� ����� � ���������������� ���
    add al,'0'            
    cmp al,'9'            
    jle DTH_END           
    add al,7              
DTH_END:
    ret        
DIGIT_TO_HEX endp

BYTE_TO_HEX proc near                           ;��������� �������� ����� � ���������������� ���
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
EXC_0&N0 label word                              ;����������� ����������
    cli 
    jmp EXC_HANDLER
endm

M = 010H
IRPC N1, 0123456789ABCDEF                        ;����������� ����������
EXC_1&N1 label word                          
    cli
    jmp EXC_HANDLER
endm

EXC_HANDLER proc near                           ;��������� ������ ��������� ����������
    call CLRSCR                                 ;������� ������
    lea  esi, MSG_EXC
    mov  edi, 40*2
    call BUFFER_OUTPUT                          ;����� ��������������
    pop eax                                     ;����� �� ����� ������ EIP
    pop eax                                     ;CS  
    pop eax                                     ;� EFLAGS
    sti                                         ;�����������, ��� ����� ��������� ���������� ���������� ���������
    db 66H
    retf                                        ;������� � 16-������ ������� ����    
EXC_HANDLER     ENDP

DUMMY_IRQ_MASTER proc near                      ;�������� ��� ���������� ���������� �������� �����������
    push eax
    mov  al,20h
    out  20h,al
    pop  eax
    iretd
DUMMY_IRQ_MASTER endp

DUMMY_IRQ_SLAVE  proc near                      ;�������� ��� ���������� ���������� �������� �����������
    push eax
    mov  al,20h
    out  20h,al
    out  0A0h,al
    pop  eax
    iretd
DUMMY_IRQ_SLAVE  endp

KEYBOARD_HANDLER proc near                      ;���������� ���������� ����������
    push ds
    push es
    pushad                                      ;��������� ����������� �������� ������ ����������
    in   al,60h                                 ;������� ���� ��� ��������� ������� �������                                ;
    
    cmp  al,key_scan                            ;���� ���� ������ ������ ������
    je   KEYBOARD_EXIT                          ;����� �� ����� �� ����������� ������   
    
    mov  ds:[kbhit_key],al                      ;�������� ��� � ������
    lea  edi,ds:[kbhit_key]
    mov  al,ds:[kbhit_key]
    xor  ah,ah
    call BYTE_TO_HEX                            ;������������� ����-��� � ������
    mov  edi, 530
      
    lea  esi,ds:[kbhit_key];scan_code                   
    call BUFFER_OUTPUT                          ;������� ������ �� ����-�����
    jmp  KEYBOARD_RETURN  
KEYBOARD_EXIT:
    mov  al,20h
    out  20h,al
    db 0eah
    dd OFFSET EXIT_FROM_INTERRUPT 
    dw CODE_PM_DESC  
KEYBOARD_RETURN:
    mov  al,20h
    out  20h,al                                 ;�������� ������� ����������� ����������
    popad                                       ;������������ �������� ���������
    pop es
    pop ds
    iretd                                       ;����� �� ����������
KEYBOARD_HANDLER endp

CLRSCR  proc near                               ;��������� ������� �������
    push es
    pushad
    mov  ax,TEXT_DESC                           ;��������� � ax ���������� ������
    mov  es,ax
    xor  edi,edi
    mov  ecx,80*25                              ;���������� �������� � ����
    mov  ax,700h
    rep  stosw
    popad
    pop  es
    ret
CLRSCR  endp

BUFFER_OUTPUT proc near                         ;��������� ������ ���������� ������, ��������������� 0
    push es
    PUSHAD
    mov  ax,TEXT_DESC                           ;��������� � es �������� ������
    mov  es,ax
OUTPUT_LOOP:                                    ;���� �� ������ ������
    lodsb                                       
    or   al,al
    jz   OUTPUT_EXIT                            ;���� ����� �� 0, �� ����� ������
    stosb
    inc  edi
    jmp  OUTPUT_LOOP
OUTPUT_EXIT:                                    ;����� �� ��������� ������
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

println proc ;� �������� dx ������ ���������� ����� ��������� ������
    push ax
    mov ah, 09h
    int 21h
    pop ax
    ret    
println endp 

START:
main proc	
	mov ax, DATA                                 ;������������� ���������� ���������
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

ENABLE_A20:                                     ;������� ����� A20
    in  al,92h                                                                              
    or  al,2                                    ;���������� ��� 1 � 1                                                   
    out 92h,al 
    
SAVE_MASK:                                      ;��������� ����� ����������     
    in      al,21h
    mov     IC_Mask_Master,al                  
    in      al,0A1h
    mov     IC_Mask_Slave, al   
    
DISABLE_INTERRUPTS:                             ;������ ����������� � ������������� ����������        
    cli                                         ;������ ���������� ����������
    in  al,70h	
	or	al,10000000b                            ;���������� 7 ��� � 1 ��� ������� ������������� ����������
	out	70h,al
	nop
	
LOAD_GDT:                                       ;��������� ���������� ������� ������������            
    mov ax,DATA
    mov dl,ah
    xor dh,dh
    shl ax,4
    shr dx,4
    mov si,ax
    mov di,dx
    
WRITE_GDT:                                      ;��������� ���������� GDT
    lea bx,GDT_GDT
    mov ax,si
    mov dx,di
    add ax,offset GDT
    adc dx,0
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_CODE_RM:                                  ;��������� ���������� �������� ���� ��������� ������
    lea bx,GDT_CODE_RM
    mov ax,cs
    xor dh,dh
    mov dl,ah
    shl ax,4
    shr dx,4
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_DATA:                                     ;�������� ���������� �������� ������
    lea bx,GDT_DATA
    mov ax,si
    mov dx,di
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_STACK:                                    ;�������� ���������� �������� �����
    lea bx, GDT_STACK
    mov ax,ss
    xor dh,dh
    mov dl,ah
    shl ax,4
    shr dx,4
    mov [bx][I_DESC.BASE_LOW],ax
    mov [bx][I_DESC.BASE_MID],dl
    mov [bx][I_DESC.BASE_HIGH],dh
    
WRITE_CODE_PM:                                  ;�������� ���������� ���� ����������� ������
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
    
WRITE_IDT:                                      ;�������� ���������� IDT
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
	
FILL_IDT:                                        ;��������� ������� ������������ ������ ����������
    irpc    N0, 0123456789ABCDEF                 ;��������� ����� 00-0F ������������
        lea eax, EXC_0&N0
        mov IDT_0&N0.OFFS_LOW,ax
        shr eax, 16
        mov IDT_0&N0.OFFS_HIGH,ax
    endm
    
    irpc    N1, 0123456789ABCDEF                 ;��������� ����� 10-1F ������������
        lea eax, EXC_1&N1
        mov IDT_1&N1.OFFS_LOW,ax
        shr eax, 16
        mov IDT_1&N1.OFFS_HIGH,ax
    endm
    
    lea eax, KEYBOARD_HANDLER                   ;��������� ���������� ���������� ���������� �� 21 ����
    mov IDT_KEYBOARD.OFFS_LOW,ax
    shr eax, 16
    mov IDT_KEYBOARD.OFFS_HIGH,ax
    
    irpc    N, 234567                           ;��������� ������� 22-27 ����������
        lea eax,DUMMY_IRQ_MASTER
        mov IDT_2&N.OFFS_LOW, AX
        shr eax,16
        mov IDT_2&N.OFFS_HIGH, AX
    endm
    
    irpc    N, 89ABCDEF                         ;��������� ������� 28-2F ����������
        lea eax,DUMMY_IRQ_SLAVE
        mov IDT_2&N.OFFS_LOW,ax
        shr eax,16
        mov IDT_2&N.OFFS_HIGH,ax
    endm
    
    lgdt fword ptr GDT_GDT                      ;��������� ������� GDTR
    lidt fword ptr IDTR                         ;��������� ������� IDTR
    
    mov eax,cr0                                 ;�������� ����������� ������� cr0
    or  al,00000001b                            ;���������� ��� PE � 1
    mov cr0,eax                                 ;�������� ���������� cr0 � ��� ����� �������� ���������� �����

OVERLOAD_CS:                                    ;������������� ������� ���� �� ��� ����������
    db  0EAH
    dw  $+4
    dw  CODE_RM_DESC        

OVERLOAD_SEGMENT_REGISTERS:                     ;�������������������� ��������� ���������� �������� �� �����������
    mov ax,DATA_DESC
    mov ds,ax                         
    mov es,ax                         
    mov ax,STACK_DESC
    mov ss,ax                         
    xor ax,ax
    mov fs,ax                                   ;�������� ������� fs
    mov gs,ax                                   ;�������� ������� gs
    lldt ax                                     ;�������� ������� LDTR - �� ������������ ������� ��������� ������������

PREPARE_TO_RETURN:
    push cs                                     ;������� ����
    push offset BACK_TO_RM                      ;�������� ����� ��������
    lea  edi,ENTER_PM                           ;�������� ����� ����� � ���������� �����
    mov  eax,CODE_PM_DESC                       ;�������� ���������� ���� ����������� ������
    push eax                                    ;������� �� � ����
    push edi                                    

REINITIALIAZE_CONTROLLER_FOR_PM:                ;�������������������� ���������� ���������� �� ������� 20h, 28h
    mov al,00010001b                            ;ICW1 - ����������������� ����������� ����������
    out 20h,al                                  ;������������������ ������� ����������
    out 0A0h,al                                 ;������������������ ������� ����������
    mov al,20h                                  ;ICW2 - ����� �������� ������� ����������
    out 21h,al                                  ;�������� �����������
    mov al,28h                                  ;ICW2 - ����� �������� ������� ����������
    out 0A1h,al                                 ;�������� �����������
    mov al,04h                                  ;ICW3 - ������� ���������� ��������� � 3 �����
    out 21h,al       
    mov al,02h                                  ;ICW3 - ������� ���������� ��������� � 3 �����
    out 0A1h,al      
    mov al,11h                                  ;ICW4 - ����� ����������� ������ ����������� ��� �������� �����������
    out 21h,al        
    mov al,01h                                  ;ICW4 - ����� ������� ������ ����������� ��� �������� �����������
    out 0A1h,al       
    mov al, 0                                   ;�������������� ����������
    out 21h,al                                  ;�������� �����������
    out 0A1h,al                                 ;�������� �����������

ENABLE_INTERRUPTS_0:                            ;��������� ����������� � ������������� ����������
    in  al,70h	
	and	al,01111111b                            ;���������� 7 ��� � 0 ��� ������� ������������� ����������
	out	70h,al
	nop
    sti                                         ;��������� ����������� ����������

GO_TO_CODE_PM:                                  ;������� � �������� ���� ����������� ������
    db 66h                                      
    retf

BACK_TO_RM:                                     ;����� �������� � �������� �����
    cli                                         ;������ ����������� ����������
    in  al,70h	                                ;� �� ����������� ����������
	or	AL,10000000b                            ;���������� 7 ��� � 1 ��� ������� ������������� ����������
	out	70h,AL
	nop

REINITIALISE_CONTROLLER:                        ;���������������� ����������� ����������               
    mov al,00010001b                            ;ICW1 - ����������������� ����������� ����������
    out 20h,al                                  ;������������������ ������� ����������
    out 0A0h,al                                 ;������������������ ������� ����������
    mov al,8h                                   ;ICW2 - ����� �������� ������� ����������
    out 21h,al                                  ;�������� �����������
    mov al,70h                                  ;ICW2 - ����� �������� ������� ����������
    out 0A1h,al                                 ;�������� �����������
    mov al,04h                                  ;ICW3 - ������� ���������� ��������� � 3 �����
    out 21h,al       
    mov al,02h                                  ;ICW3 - ������� ���������� ��������� � 3 �����
    out 0A1h,al      
    mov al,11h                                  ;ICW4 - ����� ����������� ������ ����������� ��� �������� �����������
    out 21h,al        
    mov al,01h                                  ;ICW4 - ����� ������� ������ ����������� ��� �������� �����������
    out 0A1h,al

PREPARE_SEGMENTS:                               ;���������� ���������� ��������� ��� �������� � �������� �����          
    mov GDT_CODE_RM.LIMIT,0FFFFh                ;��������� ������ �������� ���� � 64KB
    mov GDT_DATA.LIMIT,0FFFFh                   ;��������� ������ �������� ������ � 64KB
    mov GDT_STACK.LIMIT,0FFFFh                  ;��������� ������ �������� ����� � 64KB
    db  0EAH                                    ;������������� ������� cs
    dw  $+4
    dw  CODE_RM_DESC                            ;�� ������� ���� ��������� ������
    mov ax,DATA_DESC                            ;�������� ���������� �������� ������������ �������� ������
    mov ds,ax                                   
    mov es,ax                                   
    mov fs,ax                                   
    mov gs,ax                                   
    mov ax,STACK_DESC
    mov ss,ax                                   ;�������� ������� ����� ������������ �����

ENABLE_REAL_MODE:                               ;������� �������� �����
    mov eax,cr0
    and al,11111110b                            ;������� 0 ��� �������� cr0
    mov cr0,eax                        
    db  0EAH
    dw  $+4
    dw  CODE_REAL_MODE                          ;������������ ������� ����
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

REPAIR_MASK:                                   ;������������ ����� ����������
    mov al,IC_Mask_Master
    out 21h,al                                  ;�������� �����������
    mov al,IC_Mask_Slave
    out 0A1h,al                                 ;�������� �����������

ENABLE_INTERRUPTS:                              ;��������� ����������� � ������������� ����������
    in  al,70h	
	and	al,01111111b                            ;���������� 7 ��� � 0 ��� ���������� ������������� ����������
	out	70h,al
    nop
    sti                                         ;��������� ����������� ����������

DISABLE_A20:                                    ;������� ������� A20
    in  al,92h
    and al,11111101b                            ;�������� 1 ��� - ��������� ����� A20
    out 92h, al

EXIT:                                           ;����� �� ���������
    mov ax,3h
    int 10H                                     ;�������� �����-�����    
    lea dx, return_Message
    mov ah,9h
    int 21h                                     ;������� ���������
    mov ax,4C00h
    int 21H                                     ;����� � dos
main endp
                     
SIZE_CODE_REAL_MODE = ($ - CODE_REAL_MODE_BEGIN)                    
CODE_REAL_MODE ENDS 
;***************************************************************************************************************

STACK_A segment para stack
    db  1000h dup(?)
STACK_A  ends

end START

