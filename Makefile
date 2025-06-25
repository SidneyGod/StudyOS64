################################################################################
# Desc:   学习写一个x64 Toy OS
# Author: Sidney DING
# Email:  sidneyding183@gmail.com
################################################################################

# 目录定义
SRC_DIR := src
OUT_DIR := out
IMAGE_DIR := image

# 工具链前缀：Windows使用 x86_64-elf-gcc
TOOL_PREFIX := x86_64-elf-

# GCC编译参数
# -g 生成调试信息 更详细可用 -g1 -g2 -g3
# -c 只激活 预处理、编译、汇编，也就是只把程序做成obj文件
# -O0 -O1 -O2 -O3 编译器优化选项的四个级别
# -m64 生成64位目标代码 -m32 生成32位目标代码
# -fno-pie 禁用位置无关可执行文件（PIE）
# -fno-stack-protector 禁用栈保护
# -nostdlib 不链接标准库和启动文件
# -nostdinc 不再使用系统默认的头文件目录里面找文件
CFLAGS := -g -c -O0 -m64 -fno-pie -fno-stack-protector -nostdlib -nostdinc -Wall -Iinclude
LDFLAGS := -Ttext=0x7c00 -m elf_x86_64  # elf_x86_64 elf_i386

# 文件路径
ASM_SOURCES := $(foreach dir, $(SRC_DIR), $(wildcard $(dir)/*.S))
C_SOURCES := $(wildcard $(SRC_DIR)/*.c)

ASM_OBJECTS := $(patsubst $(SRC_DIR)/%.S, $(OUT_DIR)/%.o, $(ASM_SOURCES))
C_OBJECTS := $(patsubst $(SRC_DIR)/%.c, $(OUT_DIR)/%.o, $(C_SOURCES))
OBJECTS := $(ASM_OBJECTS) $(C_OBJECTS)
TARGET := $(OUT_DIR)/os.bin

# 调试输出
$(info ASM_SOURCES = $(ASM_SOURCES))
$(info C_SOURCES = $(C_SOURCES))
$(info OBJECTS = $(OBJECTS))

# mingw32-make.exe
all: $(TARGET)
	$(info >>> Make image...)
	@mkdir -p $(IMAGE_DIR)
	dd if=$< of=$(IMAGE_DIR)/disk.img bs=512 count=1 conv=notrunc

# 链接可以执行文件
# $^ Makefile中自动变量 表示依赖所有文件
$(TARGET): $(OBJECTS)
	$(info >>> Output os.bin)
	$(TOOL_PREFIX)ld $(LDFLAGS) $^ -o $(OUT_DIR)/os.elf
	${TOOL_PREFIX}objcopy -O binary $(OUT_DIR)/os.elf $@
	${TOOL_PREFIX}objdump -x -d -S  $(OUT_DIR)/os.elf > $(OUT_DIR)/os_dis.txt	
	${TOOL_PREFIX}readelf -a $(OUT_DIR)/os.elf > $(OUT_DIR)/os_elf.txt


# 编译 .c 到 .o
$(OUT_DIR)/%.o: $(SRC_DIR)/%.c
	$(info >>> Building *.c)
	@mkdir -p $(OUT_DIR)
	$(TOOL_PREFIX)gcc $(CFLAGS) -c $< -o $@

# 编译 .S 到 .o
# $@ 当前规则的目标文件
# $< 当前规则的第一个依赖文件
# $(dir $@) 获取目标文件所在目录
$(OUT_DIR)/%.o: $(SRC_DIR)/%.S
	$(info >>> Building *.S)
	@mkdir -p $(OUT_DIR)
	$(TOOL_PREFIX)gcc $(CFLAGS) -c $< -o $@

clean:
	$(info >>> Cleaning...)
	@rm -rf $(OUT_DIR) $(IMAGE_DIR)

.PHONY: all clean
