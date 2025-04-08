// Physical memory allocator, for user processes,
// kernel stacks, page-table pages,
// and pipe buffers. Allocates whole 4096-byte pages.

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "riscv.h"
#include "defs.h"

void freerange(void *pa_start, void *pa_end);

extern char end[]; // first address after kernel.
                   // defined by kernel.ld.

struct run {
  struct run *next;
};

struct {
  struct spinlock lock;
  struct run *freelist;
  int reference_counts[(PHYSTOP - KERNBASE) / PGSIZE]; 
} kmem;

void
kinit()
{
  initlock(&kmem.lock, "kmem");
  memset(kmem.reference_counts, 0, sizeof(kmem.reference_counts));
  freerange(end, (void*)PHYSTOP);
}

void
freerange(void *pa_start, void *pa_end)
{
  char *p;
  p = (char*)PGROUNDUP((uint64)pa_start);
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    kfree(p);
}

// Free the page of physical memory pointed at by pa,
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)


void
kfree(void *pa)
{
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    panic("kfree");

  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  
  if(kmem.reference_counts[index] > 0) {
    kmem.reference_counts[index]--;
    if(kmem.reference_counts[index] > 0) {
      release(&kmem.lock);
      return;
    }
  }

  memset(pa, 1, PGSIZE);
  r = (struct run*)pa;
  r->next = kmem.freelist;
  kmem.freelist = r;
  release(&kmem.lock);
}

// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.

void*
kalloc(void)
{
  struct run *r;

  acquire(&kmem.lock);
  r = kmem.freelist;
  if(r) {
    kmem.freelist = r->next;
    int index = ((uint64)r - KERNBASE) / PGSIZE;
    kmem.reference_counts[index] = 1;
  }
  release(&kmem.lock);

  if(r)
    memset((char*)r, 5, PGSIZE);
  return (void*)r;
}
void*
cow_alloc()
{
  struct run *r;

  acquire(&kmem.lock);
  r = kmem.freelist;
  if(r) {
    kmem.freelist = r->next;
    int index = ((uint64)r - KERNBASE) / PGSIZE;
    kmem.reference_counts[index] = 1;
  }
  release(&kmem.lock);

  return (void*)r;
}
void
cow_reference(void *pa)
{
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    panic("cow_reference");
    
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  kmem.reference_counts[index]++;
  release(&kmem.lock);
}

void
cow_decrement(void *pa)
{
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    panic("cow_decrement");
    
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  if(kmem.reference_counts[index] > 0)
    kmem.reference_counts[index]--;
  release(&kmem.lock);
}

int
get_refcount(void *pa)
{
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    return 0;
    
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  int count = kmem.reference_counts[index];
  release(&kmem.lock);
  return count;
}

void
increment_refcount(void *pa)
{
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    return;
    
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  kmem.reference_counts[index]++;
  release(&kmem.lock);
}
