/*******************************************************************************
 * 写一个 Hello World 版Boot引导程序
 * Author: Sidney DING
 * Email: sidneyding183@gmail.com
 ******************************************************************************/

# 指定以下代码生成16位的机器指令，确保可以在实模式下运行
.code16

# 声明本地以下符号是全局的，在其他源文件中可以访问
.global _start

# 代码段地址开始
.section .text

_start:
    xor %ax, %ax  # ax = 0
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss

    # 设置栈指针sp指向0x7c00 栈向低地址增长 0x7c00 -> 0x0000
    mov $_start, %sp
    
    # 设置显示模式为 80x25 16色文本模式
    mov $0x0003, %ax
    int $0x10

    # clear screen
    mov $0x0600, %ax
    mov $0x0700, %bx
    xor %cx, %cx
    mov $0x184f, %dx
    int $0x10

    # set focus
    mov $0x0200, %ax
    xor %bx, %bx
    xor %dx, %dx
    int $0x10

    # display msg on screen
    mov $0x1301, %ax
    mov $0x0007, %bx
    mov $StartBootMsg, %bp  # 放入字符串
    mov $StartBootMsgLen, %cx  # 字符串长度
    xor %dx, %dx
    int $0x10

    # reset floppy
    xor %ah, %ah
    xor %dl, %dl
    int $0x13    # 重置磁盘

halt:
    cli       # 禁用中断
    hlt       # 暂停CPU
    jmp halt  # 无限循环 双重保险

# 定义一个字符串:
#   .string "..." 定义未自动加0的字符串
#   .asciz "..."  定义以0结尾的字符串
StartBootMsg: .string "Sidney DING, Start Boot......"
# 定义常量表达式，用于保存静态长度. 当前位置计数器减去msg的起始地址，得到字符串长度
StartBootMsgLen = . - StartBootMsg

# 伪指令 跳到 510 字节处，填充 0x55aa 可改成 .byte 0x55, 0xaa
.org 0x01fe
.word 0xaa55
