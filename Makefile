
.PHONY: all clean debug install run

run: install
	qemu-system-i386 -d guest_errors -boot a -fda a.img

debug: install
	qemu-system-i386 -display gtk,gl=on -S -s -boot a -fda a.img

install: boot1 boot2 a.img
	mformat a:
	dd if=boot1 of=a.img bs=1 count=512 conv=notrunc
	mcopy -o boot2 a:BOOT2
	mdir a:

clean:
	rm *.o *.elf boot1 boot2 boot1.list a.img

a.img:
	bximage -q -mode="create" -fd="1.44M" a.img

boot1: boot2 ./src/asm/boot1.asm
	nasm -l boot1.list -DENTRY=`./bin/getaddr.sh main` ./src/asm/boot1.asm
	mv ./src/asm/boot1 ./boot1

boot2: boot2.elf
	objcopy -S -O binary boot2.elf boot2 

boot2.elf: boot2_c.o boot2_S.o IDT.o
	ld -g -melf_i386 -Ttext 0x10000 -e main -o boot2.elf boot2_c.o boot2_S.o IDT.o

boot2_c.o: ./src/c/boot2.c
	gcc -g -ggdb3 -m32 -c -std=c11 -fno-stack-protector -o boot2_c.o ./src/c/boot2.c

IDT.o:	./src/c/IDT.c
	gcc -g -ggdb3 -m32 -c -std=c11 -fno-stack-protector -o IDT.o ./src/c/IDT.c

boot2_S.o: ./src/asm/boot2.S
	gcc -g -ggdb3 -m32 -c -masm=intel -o boot2_S.o ./src/asm/boot2.S

