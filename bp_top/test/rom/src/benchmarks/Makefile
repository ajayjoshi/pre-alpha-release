
#RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T test.ld
Updated makefile for benchmarks. Included Dhrystone files. Close to working, believe that problem is in toolchain. Updated gnu toolchain configuration for our proper test enviorment since this is what github issue responses seem to be. going to run tool flow after.

#also used Start.S instead of crt.S

#No compiler optimizations were used for these tests

#GCC - compiled as the riscv64i arch with its coresponding abi, medium-any code model, disable printf from the benchmarks, (since riscv privlaged spec 2.2 says can handle c11 don't need std=gnu99 since gnu11 is defaulted)
RISCV_GCC= riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64i -mcmodel=medany -fno-builtin-printf


#Link - static linked, don't use the standard system startup files or libraries when linking, -lm and -lgcc searches the m and gcc libraries for any unexplicitly defined functions, specify the proxey kernel linker script we are using
RISCV_LINK= -static -nostdlib -nostartfiles -lm -lgcc -T test.ld

#Common- include the encoding directory libraries and object files, and common files such as our assembler code, proxy kernel linker script, system call library, and util header file
COMMON_FILES = -I../env crt.S test.ld syscalls.c util2.h

all: dhrystone.elf median.elf multiply.elf towers.elf vvadd.elf

dhrystone.elf: 
	$(RISCV_GCC) $(COMMON_FILES) -o dhrystone.elf dhrystone_main.c dhrystone.c dhrystone.h $(RISCV_LINK)

median.elf: 
	$(RISCV_GCC) $(COMMON_FILES) -o median.elf median.c median.h median_dataset.h median_main.c $(RISCV_LINK)

multiply.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o multiply.elf multiply.c multiply.h multiply_dataset.h multiply_main.c $(RISCV_LINK)

towers.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o towers.elf towers_main.c $(RISCV_LINK)

vvadd.elf:
	$(RISCV_GCC) $(COMMON_FILES) -o vvadd.elf vvadd_main.c vvadd_dataset.h $(RISCV_LINK)

clean:
	rm dhrystone.elf median.elf multiply.elf towers.elf vvadd.elf
