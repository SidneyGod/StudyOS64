:: Start a 64-bit emulator.
start qemu-system-x86_64 -m 128M -s -S -drive if=floppy,format=raw,file=../image/disk.img

:: Start a 32-bit emulator.
:: start qemu-system-i386 -m 128M -s -S -drive if=floppy,format=raw,file=../image/disk.img
