; ==========================================
; pm.asm
; 编译方法：nasm pm.asm -o pm.bin
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

org	07c00h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;                                                                         段基址,        段界限     ,                              属性
LABEL_GDT:	                      Descriptor          0,                0,                                         0                  ; 空描述符
LABEL_DESC_CODE32: Descriptor           0,             SegCode32Len - 1,    DA_C + DA_32   ; 非一致代码段
LABEL_DESC_VIDEO:    Descriptor    0B8000h,     0ffffh,                              DA_DRW	       ; 显存首地址
LABEL_DESC_DATA:   Descriptor    0,      DataLen-1, DA_DRW+DA_DPL1    ; Data
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
					dd	0		; GDT基地址

; GDT 选择子
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT + SA_RPL3
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
BootMessage:		db	"Joey, I'm in protected mode!"
OffsetPMMessage		equ	BootMessage - $$		;表示字符串BootMessage相对于本节的开始处（LABEL_DATA）的偏移
StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest		equ	StrTest - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]

[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs,
					; 并跳转到 SelectorCode32:0  处
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov ecx, 28
	xor	esi, esi
	xor	edi, edi
	mov	edi, 0
	mov	esi, OffsetPMMessage
.show:
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, [esi]
	mov	[gs:edi], ax
	inc edi
	inc edi
	inc esi
	loop .show

	; 到此停止
	jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]
