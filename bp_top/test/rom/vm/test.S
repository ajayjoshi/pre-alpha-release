#define MODE 0x1
#include "riscv_test.h"
RVTEST_RV64S
RVTEST_CODE_BEGIN
    j test_start
test_start:
program:
	la sp, STACKTOP
        la a0, _start
	la a1, _end
	la a2, PG0
	la a3, PG1
	la a4, PGEND
	call init_page
	
	la a0, PG0
	call alloc_page

	add a2, zero, a0
	// saved page table address
	add s1, zero, a0
	la a0, sys_program
	la a1, sys_program_end
	la a3, PG0
	call setup_machine_paging
	
	
	la a0, sys_program
	la a1, sys_program_end
	add a2, zero, s1
	la a3, PG0
	call setup_sys_paging

	addi t0, zero, 8
	slli t0, t0, 60
	srli s1, s1, 12
	or s1, s1, t0
	csrw satp, s1
	jalr ra, 0x124(a0)
	j test_end
test_end:
    RVTEST_PASS
RVTEST_CODE_END
RVTEST_DATA_BEGIN
STACKEND:
	ZPAGE
	ZPAGE
	ZPAGE
	ZPAGE
	ZPAGE
	ZPAGE
	ZPAGE
	ZPAGE
STACKTOP:
	ZPAGE
RVTEST_DATA_END
