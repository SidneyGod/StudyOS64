/*******************************************************************************
 * 写一个 Hello World 版Boot引导程序
 * Author: Sidney DING
 * Email: sidneyding183@gmail.com
 ******************************************************************************/

/* 引导扇区代码 - FAT12文件系统引导程序 */ 
.code16  # 告诉汇编器生成16位实模式代码
.globl _start  # 定义全局入口点标签

/* 常量定义 不占用内存 等于 #define */
.equ BaseOfStack, 0x7c00  # 栈基地址，栈从0x7c00向下生长
.equ BaseOfLoader, 0x1000  # Loader程序加载的段地址
.equ OffsetOfLoader, 0x00  # Loader程序在段内的偏移地址
.equ RootDirSectors, 14  # 根目录占用的扇区数
.equ SectorNumOfRootDirStart, 19  # 根目录起始扇区号
.equ SectorNumOfFAT1Start, 1  # FAT1表起始扇区号
.equ SectorBalance, 17  # 数据区起始扇区偏移量 保留扇区 + FAT1 + FAT2 - 2(数据区从2开始)

/* 引导程序入口 */
_start:
    jmp Label_Start                     # 跳过文件系统头区域
    nop                                 # 填充字节(FAT12头要求)
/* FAT12文件系统头 */
BS_OEMName:      .string "My  Boot"     # 8字节OEM标识
BPB_BytesPerSec: .word 512              # 每扇区字节数 512B
BPB_SecPerClus:  .byte 1                # 每簇扇区数 1扇区
BPB_RsvdSecCnt:  .word 1                # 保留扇区数 FAT表前扇区数
BPB_NumFATs:     .byte 2                # FAT表数量
BPB_RootEntCnt:  .word 224              # 根目录最大文件数
BPB_TotSec16:    .word 2880             # 总扇区数
BPB_Media:       .byte 0xf0             # 介质描述符
BPB_FATSz16:     .word 9                # 每个FAT表扇区数
BPB_SecPerTrk:   .word 18               # 每个磁道扇区数
BPB_NumHeads:    .word 2                # 磁头数
BPB_HiddSec:     .long 0                # 隐藏扇区数
BPB_TotSec32:    .long 0                # 大容量扇区数
BS_DrvNum:       .byte 0                # 驱动器号
BS_Reserved1:    .byte 0                # 保留字段
BS_BootSig:      .byte 0x29             # 扩展引导标记
BS_VolID:        .long 0                # 卷序列号
BS_VolLab:       .string "boot loader"  # 11字节卷标
BS_FileSysType:  .string "FAT12   "     # 8字节文件系统类型

/* 主程序入口 */
Label_Start:
    movw %cs, %ax  # 最开始cs是等于0的
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $BaseOfStack, %sp  # 栈指针指向栈底 SP=0x7c00

    /* 设置显示模式为 80x25 16色文本模式 */
    movw $0x0003, %ax
    int $0x10
    /* 清屏 */
    movw $0x0600, %ax  # AH=06h(滚动窗口), AL=00h(整个窗口)
    movw $0x0700, %bx  # BH=07h(属性：黑底白字)
    xorw %cx, %cx      # CH=0, CL=0(左上角 行=0 列=0)
    movw $0x184f, %dx  # DH=18h(24行), DL=4Fh(79列)
    int $0x10
    /* 设置光标位置 */
    movw $0x0200, %ax
    xor %bx, %bx
    xor %dx, %dx
    int $0x10
    /* 显示启动消息 */
    movw $0x1301, %ax           # AH=13h(写字符串), AL=01h(光标跟随移动)
    movw $0x000f, %bx           # BH=0(页号), BL=0Fh(黑底白字)
    movw $StartBootMsg, %bp     # 放入字符串
    movw $StartBootMsgLen, %cx  # 字符串长度
    xorw %dx, %dx               # DH=0(行) DL=0(列)
    int $0x10
    /* 重置磁盘系统 */
    xorw %ax, %ax
    xorb %dl, %dl
    int $0x13


/* 查找loader.bin文件 */
    movw $SectorNumOfRootDirStart, SectorNo  # 根目录从第19个扇区开始

Label_SearchInRootDirBegin:
    /* 检查是否已搜索完所有根目录扇区 */
    cmpw $0, RootDirSizeForLoop  # 比较剩余扇区数
    jz Label_NoLoader  # 剩0 表示没找到
    decw RootDirSizeForLoop  # RootDirSizeForLoop--
    /* 设置读取扇区参数 */
    movw $0, %ax
    movw %ax, %es  # ES=0 缓冲区段地址
    movw $0x8000, %bx  # 缓冲区偏移地址
    movw SectorNo, %ax  # 要读取的扇区号
    movb $1, %cl        # CL=1 读取一个扇区
    # 在执行call命令时，IP寄存器已指向 下一条指令(mov $LoaderFileName, %si)位置 这叫返回地址
    # 此时，先将SP-=2(栈向下增长，上面是代码)，再将IP的值存入[SS:SP]，返回地址就保存在栈中了，后面会有ret命令
    # 之后，再将Func_ReadOneSector地址存入IP寄存器中，这样就能跳转到目标地址了
    call Func_ReadOneSector
    /* 设置文件名比较参数 */
    movw $LoaderFileName, %si  # 通过DS:SI指向文件名源地址
    movw $0x8000, %di  # ES:DI 指向扇区内容起始地址
    cld  # DF复位，这样通过LODSB从DS:SI加载内容到AL后，SI就会递增1
    movw $16, %dx  # DX=16 一个扇区最多有 512B/32B=16 个目录项

Label_SearchForLoaderBin:
    cmpw $0, %dx  # 比较剩余目录项数
    jz Label_GotoNextSectorInRootDir  # 如果为0 跳到下一个扇区
    decw %dx  # 目录项数--
    movw $11, %cx  # cs=11 文件名长度11字节

Label_CmpFileName:
    cmpw $0, %cx  # 检查是否比较完所有字符
    jz Label_FileNameFound  # 如果全部匹配 跳转到对应逻辑
    decw %cx  # 字符计数器--
    lodsb  #  从DS:SI加载一个字节到AL，SI++
    cmpb %al, %es:(%di)  # 比较AL和ES:DI指向的字节
    jz Label_GoOn  # 如果相等 继续比较下一个字符
    jmp Label_Different  # 如果不相等 处理不匹配情况

Label_GoOn:
    incw %di  # DI指向下一个字符
    jmp Label_CmpFileName  # 继续比较

Label_Different:
    andw $0xffe0, %di  # DI对齐到当前目录项开头
    addw $0x20, %di  # DI指向下一个目录项 +32字节
    movw $LoaderFileName, %si  # SI重置到文件名开头
    jmp Label_SearchForLoaderBin  # 继续在当前扇区搜索

Label_GotoNextSectorInRootDir:
    incw SectorNo  # 扇区++
    jmp Label_SearchInRootDirBegin  # 回到搜索循环开始

/* 显示未找到loader的错误消息 */
Label_NoLoader:
    movw $0x1301, %ax
    movw $0x008c, %bx
    movw $0x0100, %dx
    movw $NoLoaderMsg, %bp
    movw $NoLoaderMsgLen, %cx
    int $0x10
halt:
    cli
    hlt
    jmp halt

/* 找到loader的处理 */
Label_FileNameFound:
    movw $RootDirSectors, %ax  # AX=根目录扇区数
    andw $0xffe0, %di  # DI对齐到当前目录项开头
    addw $0x1a, %di  # DI指向目录项中的起始簇号字段 DIR_FstClus
    movw %es:(%di), %cx  # CX=文件的起始簇号 DIR_FstClus
    pushw %cx  # 保存DIR_FstClus到栈中
    /* 计算文件第一个簇的扇区号 */
    addw %ax, %cx  # CX=文件起始簇号+根目录扇区数 = 文件第一个簇的扇区号
    addw $SectorBalance, %cx  # CX += 17（FAT1 + FAT2 + 保留扇区 - 2(数据区从2开始)）
    /* 设置加载地址 ES:BX=0x1000:0x0000 */
    movw $BaseOfLoader, %ax  # AX=0x1000
    movw %ax, %es  # ES=0x1000 loader段地址
    movw $OffsetOfLoader, %bx  # BX=0x0000 loader偏移地址
    movw %cx, %ax  # AX=文件起始扇区号

Label_GoOnLoadingFile:
    pushw %ax  # 保存当前扇区号
    pushw %bx  # 保存当前内存偏移

    /* 显示进度点 */
    movb $0x0e, %ah  # AH=0Eh 电传打字机输出
    movb $'.', %al  # AL='.' 要显示的字符
    movb $0x0f, %bl  # BL=0Fh  属性：黑底白字
    int $0x10

    popw %bx
    popw %ax

    movb $1, %cl  # CL=1 读取1个扇区
    call Func_ReadOneSector  # 调用读扇区函数

    popw %ax  # 弹出之前保存的簇号
    call Func_GetFatEntry  # 获取下一个簇号 结果在AX

    cmpw $0x0fff, %ax  # 比较簇号与0FFFh（EOL标志）
    jz Label_FileLoaded  # 如果是结束标记 跳转到加载完成

    pushw %ax  # 保存下一个簇号
    movw $RootDirSectors, %dx  # DX=根目录扇区数
    addw %dx, %ax  # AX+=根目录扇区数
    addw $SectorBalance, %ax  # AX += 17 计算下一个簇的扇区号
    addw BPB_BytesPerSec, %bx  # BX += 512 下一个内存位置
    jmp Label_GoOnLoadingFile  # 继续加载下一个簇

Label_FileLoaded:
    ljmp $BaseOfLoader, $OffsetOfLoader  # 长跳转到0x1000:0x0000 

/* 函数：读取一个扇区 */
/* 参数：AX = 逻辑扇区号，ES:BX = 数据缓冲区，CL = 读取扇区数 */
Func_ReadOneSector:
    pushw %bp  # 将BP保存在栈SP-2位置，接着上面调用，实际上已经-4了 后面会有pop对应的
    movw %sp, %bp  # 将当前的SP存在BP中，BP就是这个函数新的栈帧

    subw $2, %sp  # 在栈上分配2字节的空间，临时变量，这里申请，后面必须得释放 后面会有add对应的
    movb %cl, -2(%bp)  # 将参数 读取的扇区数 存入临时变量

    pushw %bx  # 将参数BX 数据缓冲区 保存到临时变量-4(%bp) 后面会有pop对应的

    # 将逻辑扇区号转换为柱面/磁头/扇区(CHS) 因为BIOS中断 int 13h, AH=02h 只能受理CHS
    movb BPB_SecPerTrk, %bl  # BL = 每磁道扇区数
    divb %bl  # AX/BL=AL(磁道号)...AH(扇区号)
    incb %ah  # 扇区号+1(BIOS从1开始计数)
    movb %ah, %cl  # 扇区S暂存 CL中
    movb %al, %dh  # 磁头H暂存 DL中
    andb $1, %dh  # 磁头要么0 要么1
    shrb $1, %al   # AL >> 1
    movb %al, %ch  # 柱面C暂存 CH中

    popw %bx  # 恢复 BX

    movb BS_DrvNum, %dl  # DL = 驱动器号(0=软盘A)
Label_GoOnReading:
    movb $2, %ah       # AH=02h(读扇区)
    movb -2(%bp), %al  # AL = 要读取的扇区数
    int $0x13         # 调用BIOS磁盘中断

    jc Label_GoOnReading  # 如果出错(CF=1) 一直重试

    addw $2, %sp  # 释放局部变量空间
    popw %bp      # 恢复基址指针
    ret          # 返回 对应着call

/* 函数：获取FAT表项 */
/* 参数：AX = 簇号，返回值：AX = 下一个簇号 */
Func_GetFatEntry:
    pushw %es
    pushw %bx
    pushw %ax

    movw $0, %ax
    movw %ax, %es

    popw %ax

    movb $0, Odd  # 初始化奇偶标志为0(偶数)
    /* 计算FAT表项在FAT中的字节偏移 */
    movw $3, %bx
    mulw %bx  # DX:AX = AX * 3(每个表项1.5字节)
    movw $2, %bx
    divw %bx  # DX:AX / 2 得到 AX=字节偏移 DX=余数

    cmpw $0, %dx  # 检查余数
    jz Label_Even  # 余数为0 是偶数项
    movb $1, Odd  # 否则设置奇偶标志为1
Label_Even:
    xorw %dx, %dx  # 清零DX(刚用于除法了)
    movw BPB_BytesPerSec, %bx  # BX=每扇区字节数 512
    divw %bx  # DX:AX / BX 得到 AX=扇区号 DX=扇内偏移

    pushw %dx
    movw $0x8000, %bx  # BX=0x8000 FAT缓存地址
    addw $SectorNumOfFAT1Start, %ax  # AX += FAT1起始扇区号
    movb $2, %cl  # CL = 2 读取两个扇区 以为你FAT表项可能跨扇区
    call Func_ReadOneSector  # 读取包含FAT表项的扇区

    popw %dx  # 恢复扇内偏移
    addw %dx, %bx  # BX+=偏移 指向FAT表项
    movw %es:(%bx), %ax  # AX=从FAT读取的16位值

    cmpb $1, Odd  # 检查是否位奇数项
    jnz Label_Even2  # 如果不是 跳转
    shrw $4, %ax  # 如果是奇数项 右移4位
Label_Even2:
    andw $0x0fff, %ax  # 屏蔽高4位 保留低12位

    popw %bx
    popw %es
    ret

/* 数据段 */
# 变量
RootDirSizeForLoop: .word RootDirSectors  # 根目录剩余搜索扇区数
SectorNo: .word 0  # 当前搜素扇区号
Odd: .byte 0  # FAT表项奇偶标志
# 字符串
StartBootMsg: .ascii "Sidney DING, Starting Boot!"
StartBootMsgLen = . - StartBootMsg
NoLoaderMsg: .ascii "ERROR: No LOADER Found!"
NoLoaderMsgLen = . - NoLoaderMsg
LoaderFileName: .string "LOADER  BIN"  # 文件名 11字节 8.3格式

/* 填充引导扇区 */
.fill 510 - (. - _start), 1, 0
.byte 0x55, 0xaa
