ROOT=$(abspath .)
RVCC = riscv64-unknown-elf-gcc
RVAB = riscv64-unknown-elf-as
RVLD = riscv64-unknown-elf-ld
INPUT = test.S
MAIN = $(INPUT).main.S
ROBJ = main test paging.o
LINK_OP = "-T"$(ROOT)/p/link.ld
CP_OP = "-I"$(ROOT)/p/
CP_EX = rv64g
SYS_PROGRAM = sysprogram/rv64ui_p_ld.hex.data
OUTPUT = test.S.riscv
ROMFLD = ../
SPKOP = 

all: compile_vm

wrap_system: 
	cat test.main.template > ${MAIN}
	cat $(SYS_PROGRAM) >> ${MAIN}
	echo "sys_program_end:" >> ${MAIN}

compile_vm: wrap_system $(OUTPUT)

$(OUTPUT) : $(ROBJ)
	$(RVLD) $(LINK_OP) $(ROBJ) -o $(OUTPUT)_vm.elf
	make -C $(ROMFLD) $(OUTPUT)_vm.v BUILD_VMTEST=N
	make -C $(ROMFLD) $(OUTPUT)_vm.trace BUILD_VMTEST=N SPIKE_OPTS="$(SPKOP)"
	rm sysprogram/*.spike sysprogram/*.data sysprogram/*.tr

test : test.S
	$(RVCC) $(CP_OP) -S test.S > test.s
	$(RVAB) -march=rv64g test.s -o test

main: $(MAIN)
	$(RVCC) -S $(MAIN) > main.s
	$(RVAB) -march=$(CP_EX) main.s -o main

paging.o: paging.h paging.c
	${RVCC} -S -march=rv64g paging.c
	${RVAB} -march=${CP_EX} paging.s -o paging.o

clean:
	rm -rf *.o test main *.s vm_tests/*.riscv *~ sysprogram/*.elf
