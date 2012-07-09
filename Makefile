# Makefile for MemTest86+
#
# Author:		Chris Brady
# Created:		January 1, 1996

#
# Path for the floppy disk device
#
FDISK=/dev/fd0

AS=as -32
CC=gcc

CFLAGS= -Wall -march=i486 -m32 -O2 -fomit-frame-pointer -fno-builtin -ffreestanding -fPIC -fno-stack-protector

OBJS= head.o reloc.o main.o test.o init.o lib.o patn.o screen_buffer.o \
      config.o linuxbios.o memsize.o pci.o controller.o random.o spd.o \
      error.o dmi.o cpuid.o

all: memtest.bin memtest memtest.0

# Link it statically once so I know I don't have undefined
# symbols and then link it dynamically so I have full
# relocation information
memtest_shared: $(OBJS) memtest_shared.lds Makefile
	$(LD) --warn-constructors --warn-common -static -T memtest_shared.lds \
	-o $@ $(OBJS) && \
	$(LD) -shared -Bsymbolic -T memtest_shared.lds -o $@ $(OBJS)

memtest_shared.bin: memtest_shared
	objcopy -O binary $< memtest_shared.bin

memtest: memtest_shared.bin memtest.lds
	$(LD) -s -T memtest.lds -b binary memtest_shared.bin -o $@

head.s: head.S config.h defs.h test.h
	$(CC) -E -traditional $< -o $@

bootsect.s: bootsect.S config.h defs.h
	$(CC) -E -traditional $< -o $@

setup.s: setup.S config.h defs.h
	$(CC) -E -traditional $< -o $@

pxe.s: pxe.S config.h defs.h
	$(CC) -E -traditional $< -o $@

memtest.bin: memtest_shared.bin bootsect.o setup.o memtest.bin.lds
	$(LD) -T memtest.bin.lds bootsect.o setup.o -b binary \
	memtest_shared.bin -o memtest.bin

memtest.0: memtest_shared.bin pxe.o setup.o memtest.bin.lds
	$(LD) -T memtest.bin.lds pxe.o setup.o -b binary \
	memtest_shared.bin -o memtest.0

reloc.o: reloc.c
	$(CC) -c $(CFLAGS) -fno-strict-aliasing reloc.c

test.o: test.c
	$(CC) -c -Wall -march=i486 -m32 -Os -fomit-frame-pointer -fno-builtin -ffreestanding test.c

clean:
	rm -f *.o *.s *.iso memtest.bin memtest memtest_shared memtest_shared.bin memtest.0

asm:
	@./makedos.sh

iso:
	make all
	./makeiso.sh
	rm -f *.o *.s memtest.bin memtest memtest_shared memtest_shared.bin

install: all
	dd <memtest.bin >$(FDISK) bs=8192

install-precomp:
	dd <precomp.bin >$(FDISK) bs=8192
	
dos: all
	cat mt86+_loader memtest.bin > memtest.exe

