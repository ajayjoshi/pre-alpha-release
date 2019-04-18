#Old command was
#RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T test.ld

#also used Start.S instead of crt.S

#No compiler optimizations were used for these tests

#GCC - compiled as the riscv64i arch with its coresponding abi, medium-any code model, disable printf from the benchmarks, (since riscv privlaged spec 2.2 says can handle c11 don't need std=gnu99 since gnu11 is defaulted)
RISCV_GCC= riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64i -mcmodel=medany -fno-builtin-printf


#Link - static linked, don't use the standard system startup files or libraries when linking, -lm and -lgcc searches the m and gcc libraries for any unexplicitly defined functions, specify the proxey kernel linker script we are using
RISCV_LINK= -static -nostdlib -nostartfiles -lm -lgcc -T common/test.ld

#Common- include the encoding directory libraries and object files, and common files such as our assembler code, proxy kernel linker script, system call library, and util header file

#encoding.h crt.S test.ld syscalls.c util.h
COMMON_FILES = -I../env -Icommon $(wildcard common/*) 

all: dhrystone.elf median.elf multiply.elf towers.elf vvadd.elf qsort.elf rsort.elf

dhrystone.elf: 
	$(RISCV_GCC) $(COMMON_FILES) -o dhrystone.elf $(wildcard dhrystone/*.c) $(RISCV_LINK)

median.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o median.elf $(wildcard median/*.c) $(RISCV_LINK)

multiply.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o multiply.elf $(wildcard multiply/*.c) $(RISCV_LINK)

towers.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o towers.elf $(wildcard towers/*.c) $(RISCV_LINK)

vvadd.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o vvadd.elf $(wildcard vvadd/*.c) $(RISCV_LINK)

qsort.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o qsort.elf $(wildcard qsort/*.c) $(RISCV_LINK)

rsort.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o rsort.elf $(wildcard rsort/*.c) $(RISCV_LINK)

clean:
	rm dhrystone.elf median.elf multiply.elf towers.elf vvadd.elf qsort.elf rsort.elf
