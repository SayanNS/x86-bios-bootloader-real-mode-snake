ASPARAMS = -f elf32
LDPARAMS = -melf_i386 --build-id=none

objects =	bootloader.o

%.o: %.asm
	nasm $(ASPARAMS) -o $@ $<

bootloader.elf: linker.ld $(objects)
	ld $(LDPARAMS) -T $< -o $@ $(objects)

bootloader.img: bootloader.elf
	objcopy -O binary $< $@

run: bootloader.img
	(killall VirtualBoxVM && sleep 1) || true
	VirtualBoxVM --startvm "boot" &

clean:
	rm *.o *.img *.elf
