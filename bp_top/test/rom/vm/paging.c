#include "paging.h"

uint64_t deloc_used_pages(uint64_t free_start, uint64_t free_end,
			  PPGDIR* pgdir) {
  uint64_t start_num = PGNUM(free_start);
  uint64_t end_num = PGNUM(free_end);
  // free in total
  pgdir->free_num = end_num - start_num;
  
  for (int i = 0; i < start_num >> 6; i++)
    *(pgdir->bits + i) = NEG164;
  
  int left = start_num - (start_num >> 6 << 6);
  *(pgdir->bits + (start_num >> 6)) = NEG164 << (64 - left);

  for (int i = end_num; i <= pgdir->total; i += 64) {
    left = i - (i >> 6 << 6);
    if (left == 0) {
      *(pgdir->bits + (i >> 6)) |= NEG164;
    } else {
      *(pgdir->bits + (i >> 6)) |= (NEG164 >> left);
      i = i - left;
    }
  }
    return 0;
}

int first_zero(uint64_t num) {
  for (int i = 63; i >= 0; i--) {
    if (~(num >> i) & 0x1)
      return i;
  }
  return -1;
}

// alloc a free page from pgdir
uint64_t alloc_page(PPGDIR* pgdir) {
  uint64_t* bits = pgdir->bits;
  uint64_t free_num = pgdir->free_num;
  uint64_t blocks = SHIFTUP(pgdir->total,6);
  
  if (free_num != 0) {
    // decrement
    pgdir->free_num--;
    for (int i = 0; i < blocks; i++) {
      if (bits[i] != NEG164) {
	// free block
	int zpos = first_zero(bits[i]);
	uint64_t pgnum = (i << 6) + (64-zpos-1);
        bits[i] = bits[i] | ((uint64_t) 1 << zpos);

        return PN2PA(pgnum);
      }
    }
  }
  return 0;
}

// map given paddr to vaddr, create additional pages if necessary
void map_addr(pte_t* pgt, uint64_t vaddr, uint64_t paddr,
		  PPGDIR* pgdir) {
  // first level
  pte_t first_pte = pgt[VPN2(vaddr)];
  pte_t* second_pte_ptr;
  pte_t second_pte;
  pte_t* third_pte_ptr;
  pte_t third_pte;

  // first level
  if (first_pte & PTE_V) {
      second_pte_ptr = ((pte_t*) (((first_pte & PTE_PPN) << 2) | (VPN1(vaddr) << 3)));
      second_pte = *second_pte_ptr;
  } else {
    // creating new page
    // get a new page from global ppgdir
    uint64_t newPage = alloc_page(pgdir);
    pgt[VPN2(vaddr)] = ((newPage & ~0xfff) >> 2) | PTE_V;
    second_pte_ptr =  ((pte_t*)(newPage | (VPN1(vaddr) << 3))) ;
    second_pte = *second_pte_ptr;
  }
  // second level
  if (second_pte & PTE_V) {
      third_pte_ptr = ((pte_t*) (((second_pte & PTE_PPN) << 2) | (VPN0(vaddr) << 3)) );
      third_pte = *third_pte_ptr;
      *third_pte_ptr = (((paddr & (PPN << PGOFF)) >> 2) | PTE_V | PTE_BRANCH | PTE_A | PTE_D);
  } else {
    uint64_t newPage = alloc_page(pgdir);
    *second_pte_ptr = ((newPage & ~0xfff) >> 2) | PTE_V;
    third_pte_ptr = &((pte_t*) newPage)[VPN0(vaddr)];
    *third_pte_ptr = (((paddr & (PPN << PGOFF)) >> 2) | PTE_V | PTE_BRANCH | PTE_A | PTE_D);
    third_pte = *third_pte_ptr;
  }
}

uint64_t init_page(uint64_t start, uint64_t end, PPGDIR* pgdir,
		   uint64_t free_start, uint64_t free_end) {
  pgdir->total = (end - start) >> PGOFF;
  pgdir->free_num = pgdir->total;
  pgdir->bits = (uint64_t*) (pgdir + PGDIR_SIZE);
  deloc_used_pages(free_start, free_end, pgdir);
  return pgdir->total;
}

uint64_t setup_sys_paging(uint64_t sys_start, uint64_t sys_end, pte_t* pgtable, PPGDIR* pgdir) {
  // random mapping for system
  uint64_t i;
  for (uint64_t pgnum = PGNUM(sys_start); pgnum < PGNUM(sys_end); pgnum++) {
    map_addr(pgtable,  i << 12, PN2PA(pgnum), pgdir);
    i++;
  }
  return PGNUM(sys_start) << 12;
}

// free starts at PG1 ends at system end
uint64_t setup_machine_paging(uint64_t free_start, uint64_t free_end, pte_t* pgtable, PPGDIR* pgdir) {
  for (uint64_t pgnum = 0; pgnum <  PGNUM(free_start); pgnum++) {
    map_addr(pgtable, PN2PA(pgnum) & 0x7fffffffff, PN2PA(pgnum), pgdir);
  }

  map_addr(pgtable, 0xc00de000, 0xc00de000, pgdir);
  for (uint64_t pgnum = PGNUM(free_end); pgnum < pgdir->total; pgnum++)
    map_addr(pgtable, PN2PA(pgnum) & 0x7fffffffff, PN2PA(pgnum), pgdir);
  return 0;
}
