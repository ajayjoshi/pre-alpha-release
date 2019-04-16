#ifndef _PAGING_H_
#define _PAGING_H_

//#include <stdio.h>

typedef unsigned long uint64_t;

typedef struct {
  uint64_t total;
  uint64_t free_num;
  uint64_t* bits;
} PPGDIR;

typedef unsigned long pte_t;

#define PTE_V 0x1
#define PTE_BRANCH 0b1110
#define PTE_PPN 0x3ffffffffffc00
#define PTE_A 0b10000000
#define PTE_D 0b1000000

// 44 bits
#define PPN 0xfffffffffff

#define GETPPN(pte) (((pte) & PTE_PPN) << 2)

#define PGSIZE 4096
#define PGOFF 12
#define PGDIR_SIZE 24

#define BASE_ADDR 0x80000000
#define NEG164 ((uint64_t) (-1))

#define VPN2(vaddr) ((vaddr >> 30) & (~(-1 << 9)))
#define VPN1(vaddr) ((vaddr >> 21) & (~(-1 << 9)))
#define VPN0(vaddr) ((vaddr >> 12) & (~(-1 << 9)))


#define PGNUM(paddr) (((paddr)-BASE_ADDR) >> PGOFF)
#define PN2PA(pgnum) (((pgnum) << PGOFF) + BASE_ADDR)

#define DIVDOWN(num,shift) num >> shift;

#define SHIFTUP(num,shift) (((num >> shift << shift) < num) ? (num >> shift) + 1 : num >> shift)

uint64_t deloc_used_pages(uint64_t free_start, uint64_t free_end, PPGDIR* pgdir);
uint64_t alloc_page(PPGDIR* pgdir);
uint64_t init_page(uint64_t start, uint64_t end, PPGDIR* pgdir, uint64_t free_start, uint64_t free_end);
uint64_t setup_machine_paging(uint64_t free_start, uint64_t free_end, pte_t* pgtable, PPGDIR* pgdir);
uint64_t setup_sys_paging(uint64_t sys_start, uint64_t sys_end, pte_t* pgtable, PPGDIR* pgdir);


#endif
