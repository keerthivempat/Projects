
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
    80000000:	00009117          	auipc	sp,0x9
    80000004:	a7010113          	addi	sp,sp,-1424 # 80008a70 <stack0>
    80000008:	6505                	lui	a0,0x1
    8000000a:	f14025f3          	csrr	a1,mhartid
    8000000e:	0585                	addi	a1,a1,1
    80000010:	02b50533          	mul	a0,a0,a1
    80000014:	912a                	add	sp,sp,a0
    80000016:	078000ef          	jal	ra,8000008e <start>

000000008000001a <spin>:
    8000001a:	a001                	j	8000001a <spin>

000000008000001c <timerinit>:
// at timervec in kernelvec.S,
// which turns them into software interrupts for
// devintr() in trap.c.
void
timerinit()
{
    8000001c:	1141                	addi	sp,sp,-16
    8000001e:	e422                	sd	s0,8(sp)
    80000020:	0800                	addi	s0,sp,16
// which hart (core) is this?
static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    80000022:	f14027f3          	csrr	a5,mhartid
  // each CPU has a separate source of timer interrupts.
  int id = r_mhartid();
    80000026:	0007869b          	sext.w	a3,a5

  // ask the CLINT for a timer interrupt.
  int interval = 1000000; // cycles; about 1/10th second in qemu.
  *(uint64*)CLINT_MTIMECMP(id) = *(uint64*)CLINT_MTIME + interval;
    8000002a:	0037979b          	slliw	a5,a5,0x3
    8000002e:	02004737          	lui	a4,0x2004
    80000032:	97ba                	add	a5,a5,a4
    80000034:	0200c737          	lui	a4,0x200c
    80000038:	ff873583          	ld	a1,-8(a4) # 200bff8 <_entry-0x7dff4008>
    8000003c:	000f4637          	lui	a2,0xf4
    80000040:	24060613          	addi	a2,a2,576 # f4240 <_entry-0x7ff0bdc0>
    80000044:	95b2                	add	a1,a1,a2
    80000046:	e38c                	sd	a1,0(a5)

  // prepare information in scratch[] for timervec.
  // scratch[0..2] : space for timervec to save registers.
  // scratch[3] : address of CLINT MTIMECMP register.
  // scratch[4] : desired interval (in cycles) between timer interrupts.
  uint64 *scratch = &timer_scratch[id][0];
    80000048:	00269713          	slli	a4,a3,0x2
    8000004c:	9736                	add	a4,a4,a3
    8000004e:	00371693          	slli	a3,a4,0x3
    80000052:	00009717          	auipc	a4,0x9
    80000056:	8de70713          	addi	a4,a4,-1826 # 80008930 <timer_scratch>
    8000005a:	9736                	add	a4,a4,a3
  scratch[3] = CLINT_MTIMECMP(id);
    8000005c:	ef1c                	sd	a5,24(a4)
  scratch[4] = interval;
    8000005e:	f310                	sd	a2,32(a4)
}

static inline void 
w_mscratch(uint64 x)
{
  asm volatile("csrw mscratch, %0" : : "r" (x));
    80000060:	34071073          	csrw	mscratch,a4
  asm volatile("csrw mtvec, %0" : : "r" (x));
    80000064:	00006797          	auipc	a5,0x6
    80000068:	1cc78793          	addi	a5,a5,460 # 80006230 <timervec>
    8000006c:	30579073          	csrw	mtvec,a5
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    80000070:	300027f3          	csrr	a5,mstatus

  // set the machine-mode trap handler.
  w_mtvec((uint64)timervec);

  // enable machine-mode interrupts.
  w_mstatus(r_mstatus() | MSTATUS_MIE);
    80000074:	0087e793          	ori	a5,a5,8
  asm volatile("csrw mstatus, %0" : : "r" (x));
    80000078:	30079073          	csrw	mstatus,a5
  asm volatile("csrr %0, mie" : "=r" (x) );
    8000007c:	304027f3          	csrr	a5,mie

  // enable machine-mode timer interrupts.
  w_mie(r_mie() | MIE_MTIE);
    80000080:	0807e793          	ori	a5,a5,128
  asm volatile("csrw mie, %0" : : "r" (x));
    80000084:	30479073          	csrw	mie,a5
}
    80000088:	6422                	ld	s0,8(sp)
    8000008a:	0141                	addi	sp,sp,16
    8000008c:	8082                	ret

000000008000008e <start>:
{
    8000008e:	1141                	addi	sp,sp,-16
    80000090:	e406                	sd	ra,8(sp)
    80000092:	e022                	sd	s0,0(sp)
    80000094:	0800                	addi	s0,sp,16
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    80000096:	300027f3          	csrr	a5,mstatus
  x &= ~MSTATUS_MPP_MASK;
    8000009a:	7779                	lui	a4,0xffffe
    8000009c:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7ffbc65f>
    800000a0:	8ff9                	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    800000a2:	6705                	lui	a4,0x1
    800000a4:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    800000a8:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    800000aa:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    800000ae:	00001797          	auipc	a5,0x1
    800000b2:	07e78793          	addi	a5,a5,126 # 8000112c <main>
    800000b6:	34179073          	csrw	mepc,a5
  asm volatile("csrw satp, %0" : : "r" (x));
    800000ba:	4781                	li	a5,0
    800000bc:	18079073          	csrw	satp,a5
  asm volatile("csrw medeleg, %0" : : "r" (x));
    800000c0:	67c1                	lui	a5,0x10
    800000c2:	17fd                	addi	a5,a5,-1
    800000c4:	30279073          	csrw	medeleg,a5
  asm volatile("csrw mideleg, %0" : : "r" (x));
    800000c8:	30379073          	csrw	mideleg,a5
  asm volatile("csrr %0, sie" : "=r" (x) );
    800000cc:	104027f3          	csrr	a5,sie
  w_sie(r_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);
    800000d0:	2227e793          	ori	a5,a5,546
  asm volatile("csrw sie, %0" : : "r" (x));
    800000d4:	10479073          	csrw	sie,a5
  asm volatile("csrw pmpaddr0, %0" : : "r" (x));
    800000d8:	57fd                	li	a5,-1
    800000da:	83a9                	srli	a5,a5,0xa
    800000dc:	3b079073          	csrw	pmpaddr0,a5
  asm volatile("csrw pmpcfg0, %0" : : "r" (x));
    800000e0:	47bd                	li	a5,15
    800000e2:	3a079073          	csrw	pmpcfg0,a5
  timerinit();
    800000e6:	00000097          	auipc	ra,0x0
    800000ea:	f36080e7          	jalr	-202(ra) # 8000001c <timerinit>
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    800000ee:	f14027f3          	csrr	a5,mhartid
  w_tp(id);
    800000f2:	2781                	sext.w	a5,a5
}

static inline void 
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r" (x));
    800000f4:	823e                	mv	tp,a5
  asm volatile("mret");
    800000f6:	30200073          	mret
}
    800000fa:	60a2                	ld	ra,8(sp)
    800000fc:	6402                	ld	s0,0(sp)
    800000fe:	0141                	addi	sp,sp,16
    80000100:	8082                	ret

0000000080000102 <consolewrite>:
//
// user write()s to the console go here.
//
int
consolewrite(int user_src, uint64 src, int n)
{
    80000102:	715d                	addi	sp,sp,-80
    80000104:	e486                	sd	ra,72(sp)
    80000106:	e0a2                	sd	s0,64(sp)
    80000108:	fc26                	sd	s1,56(sp)
    8000010a:	f84a                	sd	s2,48(sp)
    8000010c:	f44e                	sd	s3,40(sp)
    8000010e:	f052                	sd	s4,32(sp)
    80000110:	ec56                	sd	s5,24(sp)
    80000112:	0880                	addi	s0,sp,80
  int i;

  for(i = 0; i < n; i++){
    80000114:	04c05663          	blez	a2,80000160 <consolewrite+0x5e>
    80000118:	8a2a                	mv	s4,a0
    8000011a:	84ae                	mv	s1,a1
    8000011c:	89b2                	mv	s3,a2
    8000011e:	4901                	li	s2,0
    char c;
    if(either_copyin(&c, user_src, src+i, 1) == -1)
    80000120:	5afd                	li	s5,-1
    80000122:	4685                	li	a3,1
    80000124:	8626                	mv	a2,s1
    80000126:	85d2                	mv	a1,s4
    80000128:	fbf40513          	addi	a0,s0,-65
    8000012c:	00002097          	auipc	ra,0x2
    80000130:	778080e7          	jalr	1912(ra) # 800028a4 <either_copyin>
    80000134:	01550c63          	beq	a0,s5,8000014c <consolewrite+0x4a>
      break;
    uartputc(c);
    80000138:	fbf44503          	lbu	a0,-65(s0)
    8000013c:	00000097          	auipc	ra,0x0
    80000140:	780080e7          	jalr	1920(ra) # 800008bc <uartputc>
  for(i = 0; i < n; i++){
    80000144:	2905                	addiw	s2,s2,1
    80000146:	0485                	addi	s1,s1,1
    80000148:	fd299de3          	bne	s3,s2,80000122 <consolewrite+0x20>
  }

  return i;
}
    8000014c:	854a                	mv	a0,s2
    8000014e:	60a6                	ld	ra,72(sp)
    80000150:	6406                	ld	s0,64(sp)
    80000152:	74e2                	ld	s1,56(sp)
    80000154:	7942                	ld	s2,48(sp)
    80000156:	79a2                	ld	s3,40(sp)
    80000158:	7a02                	ld	s4,32(sp)
    8000015a:	6ae2                	ld	s5,24(sp)
    8000015c:	6161                	addi	sp,sp,80
    8000015e:	8082                	ret
  for(i = 0; i < n; i++){
    80000160:	4901                	li	s2,0
    80000162:	b7ed                	j	8000014c <consolewrite+0x4a>

0000000080000164 <consoleread>:
// user_dist indicates whether dst is a user
// or kernel address.
//
int
consoleread(int user_dst, uint64 dst, int n)
{
    80000164:	7159                	addi	sp,sp,-112
    80000166:	f486                	sd	ra,104(sp)
    80000168:	f0a2                	sd	s0,96(sp)
    8000016a:	eca6                	sd	s1,88(sp)
    8000016c:	e8ca                	sd	s2,80(sp)
    8000016e:	e4ce                	sd	s3,72(sp)
    80000170:	e0d2                	sd	s4,64(sp)
    80000172:	fc56                	sd	s5,56(sp)
    80000174:	f85a                	sd	s6,48(sp)
    80000176:	f45e                	sd	s7,40(sp)
    80000178:	f062                	sd	s8,32(sp)
    8000017a:	ec66                	sd	s9,24(sp)
    8000017c:	e86a                	sd	s10,16(sp)
    8000017e:	1880                	addi	s0,sp,112
    80000180:	8aaa                	mv	s5,a0
    80000182:	8a2e                	mv	s4,a1
    80000184:	89b2                	mv	s3,a2
  uint target;
  int c;
  char cbuf;

  target = n;
    80000186:	00060b1b          	sext.w	s6,a2
  acquire(&cons.lock);
    8000018a:	00011517          	auipc	a0,0x11
    8000018e:	8e650513          	addi	a0,a0,-1818 # 80010a70 <cons>
    80000192:	00001097          	auipc	ra,0x1
    80000196:	cf8080e7          	jalr	-776(ra) # 80000e8a <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    8000019a:	00011497          	auipc	s1,0x11
    8000019e:	8d648493          	addi	s1,s1,-1834 # 80010a70 <cons>
      if(killed(myproc())){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    800001a2:	00011917          	auipc	s2,0x11
    800001a6:	96690913          	addi	s2,s2,-1690 # 80010b08 <cons+0x98>
    }

    c = cons.buf[cons.r++ % INPUT_BUF_SIZE];

    if(c == C('D')){  // end-of-file
    800001aa:	4b91                	li	s7,4
      break;
    }

    // copy the input byte to the user-space buffer.
    cbuf = c;
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    800001ac:	5c7d                	li	s8,-1
      break;

    dst++;
    --n;

    if(c == '\n'){
    800001ae:	4ca9                	li	s9,10
  while(n > 0){
    800001b0:	07305b63          	blez	s3,80000226 <consoleread+0xc2>
    while(cons.r == cons.w){
    800001b4:	0984a783          	lw	a5,152(s1)
    800001b8:	09c4a703          	lw	a4,156(s1)
    800001bc:	02f71763          	bne	a4,a5,800001ea <consoleread+0x86>
      if(killed(myproc())){
    800001c0:	00002097          	auipc	ra,0x2
    800001c4:	bbe080e7          	jalr	-1090(ra) # 80001d7e <myproc>
    800001c8:	00002097          	auipc	ra,0x2
    800001cc:	526080e7          	jalr	1318(ra) # 800026ee <killed>
    800001d0:	e535                	bnez	a0,8000023c <consoleread+0xd8>
      sleep(&cons.r, &cons.lock);
    800001d2:	85a6                	mv	a1,s1
    800001d4:	854a                	mv	a0,s2
    800001d6:	00002097          	auipc	ra,0x2
    800001da:	264080e7          	jalr	612(ra) # 8000243a <sleep>
    while(cons.r == cons.w){
    800001de:	0984a783          	lw	a5,152(s1)
    800001e2:	09c4a703          	lw	a4,156(s1)
    800001e6:	fcf70de3          	beq	a4,a5,800001c0 <consoleread+0x5c>
    c = cons.buf[cons.r++ % INPUT_BUF_SIZE];
    800001ea:	0017871b          	addiw	a4,a5,1
    800001ee:	08e4ac23          	sw	a4,152(s1)
    800001f2:	07f7f713          	andi	a4,a5,127
    800001f6:	9726                	add	a4,a4,s1
    800001f8:	01874703          	lbu	a4,24(a4)
    800001fc:	00070d1b          	sext.w	s10,a4
    if(c == C('D')){  // end-of-file
    80000200:	077d0563          	beq	s10,s7,8000026a <consoleread+0x106>
    cbuf = c;
    80000204:	f8e40fa3          	sb	a4,-97(s0)
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    80000208:	4685                	li	a3,1
    8000020a:	f9f40613          	addi	a2,s0,-97
    8000020e:	85d2                	mv	a1,s4
    80000210:	8556                	mv	a0,s5
    80000212:	00002097          	auipc	ra,0x2
    80000216:	63c080e7          	jalr	1596(ra) # 8000284e <either_copyout>
    8000021a:	01850663          	beq	a0,s8,80000226 <consoleread+0xc2>
    dst++;
    8000021e:	0a05                	addi	s4,s4,1
    --n;
    80000220:	39fd                	addiw	s3,s3,-1
    if(c == '\n'){
    80000222:	f99d17e3          	bne	s10,s9,800001b0 <consoleread+0x4c>
      // a whole line has arrived, return to
      // the user-level read().
      break;
    }
  }
  release(&cons.lock);
    80000226:	00011517          	auipc	a0,0x11
    8000022a:	84a50513          	addi	a0,a0,-1974 # 80010a70 <cons>
    8000022e:	00001097          	auipc	ra,0x1
    80000232:	d10080e7          	jalr	-752(ra) # 80000f3e <release>

  return target - n;
    80000236:	413b053b          	subw	a0,s6,s3
    8000023a:	a811                	j	8000024e <consoleread+0xea>
        release(&cons.lock);
    8000023c:	00011517          	auipc	a0,0x11
    80000240:	83450513          	addi	a0,a0,-1996 # 80010a70 <cons>
    80000244:	00001097          	auipc	ra,0x1
    80000248:	cfa080e7          	jalr	-774(ra) # 80000f3e <release>
        return -1;
    8000024c:	557d                	li	a0,-1
}
    8000024e:	70a6                	ld	ra,104(sp)
    80000250:	7406                	ld	s0,96(sp)
    80000252:	64e6                	ld	s1,88(sp)
    80000254:	6946                	ld	s2,80(sp)
    80000256:	69a6                	ld	s3,72(sp)
    80000258:	6a06                	ld	s4,64(sp)
    8000025a:	7ae2                	ld	s5,56(sp)
    8000025c:	7b42                	ld	s6,48(sp)
    8000025e:	7ba2                	ld	s7,40(sp)
    80000260:	7c02                	ld	s8,32(sp)
    80000262:	6ce2                	ld	s9,24(sp)
    80000264:	6d42                	ld	s10,16(sp)
    80000266:	6165                	addi	sp,sp,112
    80000268:	8082                	ret
      if(n < target){
    8000026a:	0009871b          	sext.w	a4,s3
    8000026e:	fb677ce3          	bgeu	a4,s6,80000226 <consoleread+0xc2>
        cons.r--;
    80000272:	00011717          	auipc	a4,0x11
    80000276:	88f72b23          	sw	a5,-1898(a4) # 80010b08 <cons+0x98>
    8000027a:	b775                	j	80000226 <consoleread+0xc2>

000000008000027c <consputc>:
{
    8000027c:	1141                	addi	sp,sp,-16
    8000027e:	e406                	sd	ra,8(sp)
    80000280:	e022                	sd	s0,0(sp)
    80000282:	0800                	addi	s0,sp,16
  if(c == BACKSPACE){
    80000284:	10000793          	li	a5,256
    80000288:	00f50a63          	beq	a0,a5,8000029c <consputc+0x20>
    uartputc_sync(c);
    8000028c:	00000097          	auipc	ra,0x0
    80000290:	55e080e7          	jalr	1374(ra) # 800007ea <uartputc_sync>
}
    80000294:	60a2                	ld	ra,8(sp)
    80000296:	6402                	ld	s0,0(sp)
    80000298:	0141                	addi	sp,sp,16
    8000029a:	8082                	ret
    uartputc_sync('\b'); uartputc_sync(' '); uartputc_sync('\b');
    8000029c:	4521                	li	a0,8
    8000029e:	00000097          	auipc	ra,0x0
    800002a2:	54c080e7          	jalr	1356(ra) # 800007ea <uartputc_sync>
    800002a6:	02000513          	li	a0,32
    800002aa:	00000097          	auipc	ra,0x0
    800002ae:	540080e7          	jalr	1344(ra) # 800007ea <uartputc_sync>
    800002b2:	4521                	li	a0,8
    800002b4:	00000097          	auipc	ra,0x0
    800002b8:	536080e7          	jalr	1334(ra) # 800007ea <uartputc_sync>
    800002bc:	bfe1                	j	80000294 <consputc+0x18>

00000000800002be <consoleintr>:
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
void
consoleintr(int c)
{
    800002be:	1101                	addi	sp,sp,-32
    800002c0:	ec06                	sd	ra,24(sp)
    800002c2:	e822                	sd	s0,16(sp)
    800002c4:	e426                	sd	s1,8(sp)
    800002c6:	e04a                	sd	s2,0(sp)
    800002c8:	1000                	addi	s0,sp,32
    800002ca:	84aa                	mv	s1,a0
  acquire(&cons.lock);
    800002cc:	00010517          	auipc	a0,0x10
    800002d0:	7a450513          	addi	a0,a0,1956 # 80010a70 <cons>
    800002d4:	00001097          	auipc	ra,0x1
    800002d8:	bb6080e7          	jalr	-1098(ra) # 80000e8a <acquire>

  switch(c){
    800002dc:	47d5                	li	a5,21
    800002de:	0af48663          	beq	s1,a5,8000038a <consoleintr+0xcc>
    800002e2:	0297ca63          	blt	a5,s1,80000316 <consoleintr+0x58>
    800002e6:	47a1                	li	a5,8
    800002e8:	0ef48763          	beq	s1,a5,800003d6 <consoleintr+0x118>
    800002ec:	47c1                	li	a5,16
    800002ee:	10f49a63          	bne	s1,a5,80000402 <consoleintr+0x144>
  case C('P'):  // Print process list.
    procdump();
    800002f2:	00002097          	auipc	ra,0x2
    800002f6:	608080e7          	jalr	1544(ra) # 800028fa <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    800002fa:	00010517          	auipc	a0,0x10
    800002fe:	77650513          	addi	a0,a0,1910 # 80010a70 <cons>
    80000302:	00001097          	auipc	ra,0x1
    80000306:	c3c080e7          	jalr	-964(ra) # 80000f3e <release>
}
    8000030a:	60e2                	ld	ra,24(sp)
    8000030c:	6442                	ld	s0,16(sp)
    8000030e:	64a2                	ld	s1,8(sp)
    80000310:	6902                	ld	s2,0(sp)
    80000312:	6105                	addi	sp,sp,32
    80000314:	8082                	ret
  switch(c){
    80000316:	07f00793          	li	a5,127
    8000031a:	0af48e63          	beq	s1,a5,800003d6 <consoleintr+0x118>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    8000031e:	00010717          	auipc	a4,0x10
    80000322:	75270713          	addi	a4,a4,1874 # 80010a70 <cons>
    80000326:	0a072783          	lw	a5,160(a4)
    8000032a:	09872703          	lw	a4,152(a4)
    8000032e:	9f99                	subw	a5,a5,a4
    80000330:	07f00713          	li	a4,127
    80000334:	fcf763e3          	bltu	a4,a5,800002fa <consoleintr+0x3c>
      c = (c == '\r') ? '\n' : c;
    80000338:	47b5                	li	a5,13
    8000033a:	0cf48763          	beq	s1,a5,80000408 <consoleintr+0x14a>
      consputc(c);
    8000033e:	8526                	mv	a0,s1
    80000340:	00000097          	auipc	ra,0x0
    80000344:	f3c080e7          	jalr	-196(ra) # 8000027c <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    80000348:	00010797          	auipc	a5,0x10
    8000034c:	72878793          	addi	a5,a5,1832 # 80010a70 <cons>
    80000350:	0a07a683          	lw	a3,160(a5)
    80000354:	0016871b          	addiw	a4,a3,1
    80000358:	0007061b          	sext.w	a2,a4
    8000035c:	0ae7a023          	sw	a4,160(a5)
    80000360:	07f6f693          	andi	a3,a3,127
    80000364:	97b6                	add	a5,a5,a3
    80000366:	00978c23          	sb	s1,24(a5)
      if(c == '\n' || c == C('D') || cons.e-cons.r == INPUT_BUF_SIZE){
    8000036a:	47a9                	li	a5,10
    8000036c:	0cf48563          	beq	s1,a5,80000436 <consoleintr+0x178>
    80000370:	4791                	li	a5,4
    80000372:	0cf48263          	beq	s1,a5,80000436 <consoleintr+0x178>
    80000376:	00010797          	auipc	a5,0x10
    8000037a:	7927a783          	lw	a5,1938(a5) # 80010b08 <cons+0x98>
    8000037e:	9f1d                	subw	a4,a4,a5
    80000380:	08000793          	li	a5,128
    80000384:	f6f71be3          	bne	a4,a5,800002fa <consoleintr+0x3c>
    80000388:	a07d                	j	80000436 <consoleintr+0x178>
    while(cons.e != cons.w &&
    8000038a:	00010717          	auipc	a4,0x10
    8000038e:	6e670713          	addi	a4,a4,1766 # 80010a70 <cons>
    80000392:	0a072783          	lw	a5,160(a4)
    80000396:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    8000039a:	00010497          	auipc	s1,0x10
    8000039e:	6d648493          	addi	s1,s1,1750 # 80010a70 <cons>
    while(cons.e != cons.w &&
    800003a2:	4929                	li	s2,10
    800003a4:	f4f70be3          	beq	a4,a5,800002fa <consoleintr+0x3c>
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    800003a8:	37fd                	addiw	a5,a5,-1
    800003aa:	07f7f713          	andi	a4,a5,127
    800003ae:	9726                	add	a4,a4,s1
    while(cons.e != cons.w &&
    800003b0:	01874703          	lbu	a4,24(a4)
    800003b4:	f52703e3          	beq	a4,s2,800002fa <consoleintr+0x3c>
      cons.e--;
    800003b8:	0af4a023          	sw	a5,160(s1)
      consputc(BACKSPACE);
    800003bc:	10000513          	li	a0,256
    800003c0:	00000097          	auipc	ra,0x0
    800003c4:	ebc080e7          	jalr	-324(ra) # 8000027c <consputc>
    while(cons.e != cons.w &&
    800003c8:	0a04a783          	lw	a5,160(s1)
    800003cc:	09c4a703          	lw	a4,156(s1)
    800003d0:	fcf71ce3          	bne	a4,a5,800003a8 <consoleintr+0xea>
    800003d4:	b71d                	j	800002fa <consoleintr+0x3c>
    if(cons.e != cons.w){
    800003d6:	00010717          	auipc	a4,0x10
    800003da:	69a70713          	addi	a4,a4,1690 # 80010a70 <cons>
    800003de:	0a072783          	lw	a5,160(a4)
    800003e2:	09c72703          	lw	a4,156(a4)
    800003e6:	f0f70ae3          	beq	a4,a5,800002fa <consoleintr+0x3c>
      cons.e--;
    800003ea:	37fd                	addiw	a5,a5,-1
    800003ec:	00010717          	auipc	a4,0x10
    800003f0:	72f72223          	sw	a5,1828(a4) # 80010b10 <cons+0xa0>
      consputc(BACKSPACE);
    800003f4:	10000513          	li	a0,256
    800003f8:	00000097          	auipc	ra,0x0
    800003fc:	e84080e7          	jalr	-380(ra) # 8000027c <consputc>
    80000400:	bded                	j	800002fa <consoleintr+0x3c>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    80000402:	ee048ce3          	beqz	s1,800002fa <consoleintr+0x3c>
    80000406:	bf21                	j	8000031e <consoleintr+0x60>
      consputc(c);
    80000408:	4529                	li	a0,10
    8000040a:	00000097          	auipc	ra,0x0
    8000040e:	e72080e7          	jalr	-398(ra) # 8000027c <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    80000412:	00010797          	auipc	a5,0x10
    80000416:	65e78793          	addi	a5,a5,1630 # 80010a70 <cons>
    8000041a:	0a07a703          	lw	a4,160(a5)
    8000041e:	0017069b          	addiw	a3,a4,1
    80000422:	0006861b          	sext.w	a2,a3
    80000426:	0ad7a023          	sw	a3,160(a5)
    8000042a:	07f77713          	andi	a4,a4,127
    8000042e:	97ba                	add	a5,a5,a4
    80000430:	4729                	li	a4,10
    80000432:	00e78c23          	sb	a4,24(a5)
        cons.w = cons.e;
    80000436:	00010797          	auipc	a5,0x10
    8000043a:	6cc7ab23          	sw	a2,1750(a5) # 80010b0c <cons+0x9c>
        wakeup(&cons.r);
    8000043e:	00010517          	auipc	a0,0x10
    80000442:	6ca50513          	addi	a0,a0,1738 # 80010b08 <cons+0x98>
    80000446:	00002097          	auipc	ra,0x2
    8000044a:	058080e7          	jalr	88(ra) # 8000249e <wakeup>
    8000044e:	b575                	j	800002fa <consoleintr+0x3c>

0000000080000450 <consoleinit>:

void
consoleinit(void)
{
    80000450:	1141                	addi	sp,sp,-16
    80000452:	e406                	sd	ra,8(sp)
    80000454:	e022                	sd	s0,0(sp)
    80000456:	0800                	addi	s0,sp,16
  initlock(&cons.lock, "cons");
    80000458:	00008597          	auipc	a1,0x8
    8000045c:	bb858593          	addi	a1,a1,-1096 # 80008010 <etext+0x10>
    80000460:	00010517          	auipc	a0,0x10
    80000464:	61050513          	addi	a0,a0,1552 # 80010a70 <cons>
    80000468:	00001097          	auipc	ra,0x1
    8000046c:	992080e7          	jalr	-1646(ra) # 80000dfa <initlock>

  uartinit();
    80000470:	00000097          	auipc	ra,0x0
    80000474:	32a080e7          	jalr	810(ra) # 8000079a <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    80000478:	00041797          	auipc	a5,0x41
    8000047c:	b9078793          	addi	a5,a5,-1136 # 80041008 <devsw>
    80000480:	00000717          	auipc	a4,0x0
    80000484:	ce470713          	addi	a4,a4,-796 # 80000164 <consoleread>
    80000488:	eb98                	sd	a4,16(a5)
  devsw[CONSOLE].write = consolewrite;
    8000048a:	00000717          	auipc	a4,0x0
    8000048e:	c7870713          	addi	a4,a4,-904 # 80000102 <consolewrite>
    80000492:	ef98                	sd	a4,24(a5)
}
    80000494:	60a2                	ld	ra,8(sp)
    80000496:	6402                	ld	s0,0(sp)
    80000498:	0141                	addi	sp,sp,16
    8000049a:	8082                	ret

000000008000049c <printint>:

static char digits[] = "0123456789abcdef";

static void
printint(int xx, int base, int sign)
{
    8000049c:	7179                	addi	sp,sp,-48
    8000049e:	f406                	sd	ra,40(sp)
    800004a0:	f022                	sd	s0,32(sp)
    800004a2:	ec26                	sd	s1,24(sp)
    800004a4:	e84a                	sd	s2,16(sp)
    800004a6:	1800                	addi	s0,sp,48
  char buf[16];
  int i;
  uint x;

  if(sign && (sign = xx < 0))
    800004a8:	c219                	beqz	a2,800004ae <printint+0x12>
    800004aa:	08054663          	bltz	a0,80000536 <printint+0x9a>
    x = -xx;
  else
    x = xx;
    800004ae:	2501                	sext.w	a0,a0
    800004b0:	4881                	li	a7,0
    800004b2:	fd040693          	addi	a3,s0,-48

  i = 0;
    800004b6:	4701                	li	a4,0
  do {
    buf[i++] = digits[x % base];
    800004b8:	2581                	sext.w	a1,a1
    800004ba:	00008617          	auipc	a2,0x8
    800004be:	b8660613          	addi	a2,a2,-1146 # 80008040 <digits>
    800004c2:	883a                	mv	a6,a4
    800004c4:	2705                	addiw	a4,a4,1
    800004c6:	02b577bb          	remuw	a5,a0,a1
    800004ca:	1782                	slli	a5,a5,0x20
    800004cc:	9381                	srli	a5,a5,0x20
    800004ce:	97b2                	add	a5,a5,a2
    800004d0:	0007c783          	lbu	a5,0(a5)
    800004d4:	00f68023          	sb	a5,0(a3)
  } while((x /= base) != 0);
    800004d8:	0005079b          	sext.w	a5,a0
    800004dc:	02b5553b          	divuw	a0,a0,a1
    800004e0:	0685                	addi	a3,a3,1
    800004e2:	feb7f0e3          	bgeu	a5,a1,800004c2 <printint+0x26>

  if(sign)
    800004e6:	00088b63          	beqz	a7,800004fc <printint+0x60>
    buf[i++] = '-';
    800004ea:	fe040793          	addi	a5,s0,-32
    800004ee:	973e                	add	a4,a4,a5
    800004f0:	02d00793          	li	a5,45
    800004f4:	fef70823          	sb	a5,-16(a4)
    800004f8:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
    800004fc:	02e05763          	blez	a4,8000052a <printint+0x8e>
    80000500:	fd040793          	addi	a5,s0,-48
    80000504:	00e784b3          	add	s1,a5,a4
    80000508:	fff78913          	addi	s2,a5,-1
    8000050c:	993a                	add	s2,s2,a4
    8000050e:	377d                	addiw	a4,a4,-1
    80000510:	1702                	slli	a4,a4,0x20
    80000512:	9301                	srli	a4,a4,0x20
    80000514:	40e90933          	sub	s2,s2,a4
    consputc(buf[i]);
    80000518:	fff4c503          	lbu	a0,-1(s1)
    8000051c:	00000097          	auipc	ra,0x0
    80000520:	d60080e7          	jalr	-672(ra) # 8000027c <consputc>
  while(--i >= 0)
    80000524:	14fd                	addi	s1,s1,-1
    80000526:	ff2499e3          	bne	s1,s2,80000518 <printint+0x7c>
}
    8000052a:	70a2                	ld	ra,40(sp)
    8000052c:	7402                	ld	s0,32(sp)
    8000052e:	64e2                	ld	s1,24(sp)
    80000530:	6942                	ld	s2,16(sp)
    80000532:	6145                	addi	sp,sp,48
    80000534:	8082                	ret
    x = -xx;
    80000536:	40a0053b          	negw	a0,a0
  if(sign && (sign = xx < 0))
    8000053a:	4885                	li	a7,1
    x = -xx;
    8000053c:	bf9d                	j	800004b2 <printint+0x16>

000000008000053e <panic>:
    release(&pr.lock);
}

void
panic(char *s)
{
    8000053e:	1101                	addi	sp,sp,-32
    80000540:	ec06                	sd	ra,24(sp)
    80000542:	e822                	sd	s0,16(sp)
    80000544:	e426                	sd	s1,8(sp)
    80000546:	1000                	addi	s0,sp,32
    80000548:	84aa                	mv	s1,a0
  pr.locking = 0;
    8000054a:	00010797          	auipc	a5,0x10
    8000054e:	5e07a323          	sw	zero,1510(a5) # 80010b30 <pr+0x18>
  printf("panic: ");
    80000552:	00008517          	auipc	a0,0x8
    80000556:	ac650513          	addi	a0,a0,-1338 # 80008018 <etext+0x18>
    8000055a:	00000097          	auipc	ra,0x0
    8000055e:	02e080e7          	jalr	46(ra) # 80000588 <printf>
  printf(s);
    80000562:	8526                	mv	a0,s1
    80000564:	00000097          	auipc	ra,0x0
    80000568:	024080e7          	jalr	36(ra) # 80000588 <printf>
  printf("\n");
    8000056c:	00008517          	auipc	a0,0x8
    80000570:	b7c50513          	addi	a0,a0,-1156 # 800080e8 <digits+0xa8>
    80000574:	00000097          	auipc	ra,0x0
    80000578:	014080e7          	jalr	20(ra) # 80000588 <printf>
  panicked = 1; // freeze uart output from other CPUs
    8000057c:	4785                	li	a5,1
    8000057e:	00008717          	auipc	a4,0x8
    80000582:	36f72923          	sw	a5,882(a4) # 800088f0 <panicked>
  for(;;)
    80000586:	a001                	j	80000586 <panic+0x48>

0000000080000588 <printf>:
{
    80000588:	7131                	addi	sp,sp,-192
    8000058a:	fc86                	sd	ra,120(sp)
    8000058c:	f8a2                	sd	s0,112(sp)
    8000058e:	f4a6                	sd	s1,104(sp)
    80000590:	f0ca                	sd	s2,96(sp)
    80000592:	ecce                	sd	s3,88(sp)
    80000594:	e8d2                	sd	s4,80(sp)
    80000596:	e4d6                	sd	s5,72(sp)
    80000598:	e0da                	sd	s6,64(sp)
    8000059a:	fc5e                	sd	s7,56(sp)
    8000059c:	f862                	sd	s8,48(sp)
    8000059e:	f466                	sd	s9,40(sp)
    800005a0:	f06a                	sd	s10,32(sp)
    800005a2:	ec6e                	sd	s11,24(sp)
    800005a4:	0100                	addi	s0,sp,128
    800005a6:	8a2a                	mv	s4,a0
    800005a8:	e40c                	sd	a1,8(s0)
    800005aa:	e810                	sd	a2,16(s0)
    800005ac:	ec14                	sd	a3,24(s0)
    800005ae:	f018                	sd	a4,32(s0)
    800005b0:	f41c                	sd	a5,40(s0)
    800005b2:	03043823          	sd	a6,48(s0)
    800005b6:	03143c23          	sd	a7,56(s0)
  locking = pr.locking;
    800005ba:	00010d97          	auipc	s11,0x10
    800005be:	576dad83          	lw	s11,1398(s11) # 80010b30 <pr+0x18>
  if(locking)
    800005c2:	020d9b63          	bnez	s11,800005f8 <printf+0x70>
  if (fmt == 0)
    800005c6:	040a0263          	beqz	s4,8000060a <printf+0x82>
  va_start(ap, fmt);
    800005ca:	00840793          	addi	a5,s0,8
    800005ce:	f8f43423          	sd	a5,-120(s0)
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    800005d2:	000a4503          	lbu	a0,0(s4)
    800005d6:	14050f63          	beqz	a0,80000734 <printf+0x1ac>
    800005da:	4981                	li	s3,0
    if(c != '%'){
    800005dc:	02500a93          	li	s5,37
    switch(c){
    800005e0:	07000b93          	li	s7,112
  consputc('x');
    800005e4:	4d41                	li	s10,16
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800005e6:	00008b17          	auipc	s6,0x8
    800005ea:	a5ab0b13          	addi	s6,s6,-1446 # 80008040 <digits>
    switch(c){
    800005ee:	07300c93          	li	s9,115
    800005f2:	06400c13          	li	s8,100
    800005f6:	a82d                	j	80000630 <printf+0xa8>
    acquire(&pr.lock);
    800005f8:	00010517          	auipc	a0,0x10
    800005fc:	52050513          	addi	a0,a0,1312 # 80010b18 <pr>
    80000600:	00001097          	auipc	ra,0x1
    80000604:	88a080e7          	jalr	-1910(ra) # 80000e8a <acquire>
    80000608:	bf7d                	j	800005c6 <printf+0x3e>
    panic("null fmt");
    8000060a:	00008517          	auipc	a0,0x8
    8000060e:	a1e50513          	addi	a0,a0,-1506 # 80008028 <etext+0x28>
    80000612:	00000097          	auipc	ra,0x0
    80000616:	f2c080e7          	jalr	-212(ra) # 8000053e <panic>
      consputc(c);
    8000061a:	00000097          	auipc	ra,0x0
    8000061e:	c62080e7          	jalr	-926(ra) # 8000027c <consputc>
  for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
    80000622:	2985                	addiw	s3,s3,1
    80000624:	013a07b3          	add	a5,s4,s3
    80000628:	0007c503          	lbu	a0,0(a5)
    8000062c:	10050463          	beqz	a0,80000734 <printf+0x1ac>
    if(c != '%'){
    80000630:	ff5515e3          	bne	a0,s5,8000061a <printf+0x92>
    c = fmt[++i] & 0xff;
    80000634:	2985                	addiw	s3,s3,1
    80000636:	013a07b3          	add	a5,s4,s3
    8000063a:	0007c783          	lbu	a5,0(a5)
    8000063e:	0007849b          	sext.w	s1,a5
    if(c == 0)
    80000642:	cbed                	beqz	a5,80000734 <printf+0x1ac>
    switch(c){
    80000644:	05778a63          	beq	a5,s7,80000698 <printf+0x110>
    80000648:	02fbf663          	bgeu	s7,a5,80000674 <printf+0xec>
    8000064c:	09978863          	beq	a5,s9,800006dc <printf+0x154>
    80000650:	07800713          	li	a4,120
    80000654:	0ce79563          	bne	a5,a4,8000071e <printf+0x196>
      printint(va_arg(ap, int), 16, 1);
    80000658:	f8843783          	ld	a5,-120(s0)
    8000065c:	00878713          	addi	a4,a5,8
    80000660:	f8e43423          	sd	a4,-120(s0)
    80000664:	4605                	li	a2,1
    80000666:	85ea                	mv	a1,s10
    80000668:	4388                	lw	a0,0(a5)
    8000066a:	00000097          	auipc	ra,0x0
    8000066e:	e32080e7          	jalr	-462(ra) # 8000049c <printint>
      break;
    80000672:	bf45                	j	80000622 <printf+0x9a>
    switch(c){
    80000674:	09578f63          	beq	a5,s5,80000712 <printf+0x18a>
    80000678:	0b879363          	bne	a5,s8,8000071e <printf+0x196>
      printint(va_arg(ap, int), 10, 1);
    8000067c:	f8843783          	ld	a5,-120(s0)
    80000680:	00878713          	addi	a4,a5,8
    80000684:	f8e43423          	sd	a4,-120(s0)
    80000688:	4605                	li	a2,1
    8000068a:	45a9                	li	a1,10
    8000068c:	4388                	lw	a0,0(a5)
    8000068e:	00000097          	auipc	ra,0x0
    80000692:	e0e080e7          	jalr	-498(ra) # 8000049c <printint>
      break;
    80000696:	b771                	j	80000622 <printf+0x9a>
      printptr(va_arg(ap, uint64));
    80000698:	f8843783          	ld	a5,-120(s0)
    8000069c:	00878713          	addi	a4,a5,8
    800006a0:	f8e43423          	sd	a4,-120(s0)
    800006a4:	0007b903          	ld	s2,0(a5)
  consputc('0');
    800006a8:	03000513          	li	a0,48
    800006ac:	00000097          	auipc	ra,0x0
    800006b0:	bd0080e7          	jalr	-1072(ra) # 8000027c <consputc>
  consputc('x');
    800006b4:	07800513          	li	a0,120
    800006b8:	00000097          	auipc	ra,0x0
    800006bc:	bc4080e7          	jalr	-1084(ra) # 8000027c <consputc>
    800006c0:	84ea                	mv	s1,s10
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    800006c2:	03c95793          	srli	a5,s2,0x3c
    800006c6:	97da                	add	a5,a5,s6
    800006c8:	0007c503          	lbu	a0,0(a5)
    800006cc:	00000097          	auipc	ra,0x0
    800006d0:	bb0080e7          	jalr	-1104(ra) # 8000027c <consputc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    800006d4:	0912                	slli	s2,s2,0x4
    800006d6:	34fd                	addiw	s1,s1,-1
    800006d8:	f4ed                	bnez	s1,800006c2 <printf+0x13a>
    800006da:	b7a1                	j	80000622 <printf+0x9a>
      if((s = va_arg(ap, char*)) == 0)
    800006dc:	f8843783          	ld	a5,-120(s0)
    800006e0:	00878713          	addi	a4,a5,8
    800006e4:	f8e43423          	sd	a4,-120(s0)
    800006e8:	6384                	ld	s1,0(a5)
    800006ea:	cc89                	beqz	s1,80000704 <printf+0x17c>
      for(; *s; s++)
    800006ec:	0004c503          	lbu	a0,0(s1)
    800006f0:	d90d                	beqz	a0,80000622 <printf+0x9a>
        consputc(*s);
    800006f2:	00000097          	auipc	ra,0x0
    800006f6:	b8a080e7          	jalr	-1142(ra) # 8000027c <consputc>
      for(; *s; s++)
    800006fa:	0485                	addi	s1,s1,1
    800006fc:	0004c503          	lbu	a0,0(s1)
    80000700:	f96d                	bnez	a0,800006f2 <printf+0x16a>
    80000702:	b705                	j	80000622 <printf+0x9a>
        s = "(null)";
    80000704:	00008497          	auipc	s1,0x8
    80000708:	91c48493          	addi	s1,s1,-1764 # 80008020 <etext+0x20>
      for(; *s; s++)
    8000070c:	02800513          	li	a0,40
    80000710:	b7cd                	j	800006f2 <printf+0x16a>
      consputc('%');
    80000712:	8556                	mv	a0,s5
    80000714:	00000097          	auipc	ra,0x0
    80000718:	b68080e7          	jalr	-1176(ra) # 8000027c <consputc>
      break;
    8000071c:	b719                	j	80000622 <printf+0x9a>
      consputc('%');
    8000071e:	8556                	mv	a0,s5
    80000720:	00000097          	auipc	ra,0x0
    80000724:	b5c080e7          	jalr	-1188(ra) # 8000027c <consputc>
      consputc(c);
    80000728:	8526                	mv	a0,s1
    8000072a:	00000097          	auipc	ra,0x0
    8000072e:	b52080e7          	jalr	-1198(ra) # 8000027c <consputc>
      break;
    80000732:	bdc5                	j	80000622 <printf+0x9a>
  if(locking)
    80000734:	020d9163          	bnez	s11,80000756 <printf+0x1ce>
}
    80000738:	70e6                	ld	ra,120(sp)
    8000073a:	7446                	ld	s0,112(sp)
    8000073c:	74a6                	ld	s1,104(sp)
    8000073e:	7906                	ld	s2,96(sp)
    80000740:	69e6                	ld	s3,88(sp)
    80000742:	6a46                	ld	s4,80(sp)
    80000744:	6aa6                	ld	s5,72(sp)
    80000746:	6b06                	ld	s6,64(sp)
    80000748:	7be2                	ld	s7,56(sp)
    8000074a:	7c42                	ld	s8,48(sp)
    8000074c:	7ca2                	ld	s9,40(sp)
    8000074e:	7d02                	ld	s10,32(sp)
    80000750:	6de2                	ld	s11,24(sp)
    80000752:	6129                	addi	sp,sp,192
    80000754:	8082                	ret
    release(&pr.lock);
    80000756:	00010517          	auipc	a0,0x10
    8000075a:	3c250513          	addi	a0,a0,962 # 80010b18 <pr>
    8000075e:	00000097          	auipc	ra,0x0
    80000762:	7e0080e7          	jalr	2016(ra) # 80000f3e <release>
}
    80000766:	bfc9                	j	80000738 <printf+0x1b0>

0000000080000768 <printfinit>:
    ;
}

void
printfinit(void)
{
    80000768:	1101                	addi	sp,sp,-32
    8000076a:	ec06                	sd	ra,24(sp)
    8000076c:	e822                	sd	s0,16(sp)
    8000076e:	e426                	sd	s1,8(sp)
    80000770:	1000                	addi	s0,sp,32
  initlock(&pr.lock, "pr");
    80000772:	00010497          	auipc	s1,0x10
    80000776:	3a648493          	addi	s1,s1,934 # 80010b18 <pr>
    8000077a:	00008597          	auipc	a1,0x8
    8000077e:	8be58593          	addi	a1,a1,-1858 # 80008038 <etext+0x38>
    80000782:	8526                	mv	a0,s1
    80000784:	00000097          	auipc	ra,0x0
    80000788:	676080e7          	jalr	1654(ra) # 80000dfa <initlock>
  pr.locking = 1;
    8000078c:	4785                	li	a5,1
    8000078e:	cc9c                	sw	a5,24(s1)
}
    80000790:	60e2                	ld	ra,24(sp)
    80000792:	6442                	ld	s0,16(sp)
    80000794:	64a2                	ld	s1,8(sp)
    80000796:	6105                	addi	sp,sp,32
    80000798:	8082                	ret

000000008000079a <uartinit>:

void uartstart();

void
uartinit(void)
{
    8000079a:	1141                	addi	sp,sp,-16
    8000079c:	e406                	sd	ra,8(sp)
    8000079e:	e022                	sd	s0,0(sp)
    800007a0:	0800                	addi	s0,sp,16
  // disable interrupts.
  WriteReg(IER, 0x00);
    800007a2:	100007b7          	lui	a5,0x10000
    800007a6:	000780a3          	sb	zero,1(a5) # 10000001 <_entry-0x6fffffff>

  // special mode to set baud rate.
  WriteReg(LCR, LCR_BAUD_LATCH);
    800007aa:	f8000713          	li	a4,-128
    800007ae:	00e781a3          	sb	a4,3(a5)

  // LSB for baud rate of 38.4K.
  WriteReg(0, 0x03);
    800007b2:	470d                	li	a4,3
    800007b4:	00e78023          	sb	a4,0(a5)

  // MSB for baud rate of 38.4K.
  WriteReg(1, 0x00);
    800007b8:	000780a3          	sb	zero,1(a5)

  // leave set-baud mode,
  // and set word length to 8 bits, no parity.
  WriteReg(LCR, LCR_EIGHT_BITS);
    800007bc:	00e781a3          	sb	a4,3(a5)

  // reset and enable FIFOs.
  WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    800007c0:	469d                	li	a3,7
    800007c2:	00d78123          	sb	a3,2(a5)

  // enable transmit and receive interrupts.
  WriteReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
    800007c6:	00e780a3          	sb	a4,1(a5)

  initlock(&uart_tx_lock, "uart");
    800007ca:	00008597          	auipc	a1,0x8
    800007ce:	88e58593          	addi	a1,a1,-1906 # 80008058 <digits+0x18>
    800007d2:	00010517          	auipc	a0,0x10
    800007d6:	36650513          	addi	a0,a0,870 # 80010b38 <uart_tx_lock>
    800007da:	00000097          	auipc	ra,0x0
    800007de:	620080e7          	jalr	1568(ra) # 80000dfa <initlock>
}
    800007e2:	60a2                	ld	ra,8(sp)
    800007e4:	6402                	ld	s0,0(sp)
    800007e6:	0141                	addi	sp,sp,16
    800007e8:	8082                	ret

00000000800007ea <uartputc_sync>:
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
    800007ea:	1101                	addi	sp,sp,-32
    800007ec:	ec06                	sd	ra,24(sp)
    800007ee:	e822                	sd	s0,16(sp)
    800007f0:	e426                	sd	s1,8(sp)
    800007f2:	1000                	addi	s0,sp,32
    800007f4:	84aa                	mv	s1,a0
  push_off();
    800007f6:	00000097          	auipc	ra,0x0
    800007fa:	648080e7          	jalr	1608(ra) # 80000e3e <push_off>

  if(panicked){
    800007fe:	00008797          	auipc	a5,0x8
    80000802:	0f27a783          	lw	a5,242(a5) # 800088f0 <panicked>
    for(;;)
      ;
  }

  // wait for Transmit Holding Empty to be set in LSR.
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    80000806:	10000737          	lui	a4,0x10000
  if(panicked){
    8000080a:	c391                	beqz	a5,8000080e <uartputc_sync+0x24>
    for(;;)
    8000080c:	a001                	j	8000080c <uartputc_sync+0x22>
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    8000080e:	00574783          	lbu	a5,5(a4) # 10000005 <_entry-0x6ffffffb>
    80000812:	0207f793          	andi	a5,a5,32
    80000816:	dfe5                	beqz	a5,8000080e <uartputc_sync+0x24>
    ;
  WriteReg(THR, c);
    80000818:	0ff4f513          	andi	a0,s1,255
    8000081c:	100007b7          	lui	a5,0x10000
    80000820:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>

  pop_off();
    80000824:	00000097          	auipc	ra,0x0
    80000828:	6ba080e7          	jalr	1722(ra) # 80000ede <pop_off>
}
    8000082c:	60e2                	ld	ra,24(sp)
    8000082e:	6442                	ld	s0,16(sp)
    80000830:	64a2                	ld	s1,8(sp)
    80000832:	6105                	addi	sp,sp,32
    80000834:	8082                	ret

0000000080000836 <uartstart>:
// called from both the top- and bottom-half.
void
uartstart()
{
  while(1){
    if(uart_tx_w == uart_tx_r){
    80000836:	00008797          	auipc	a5,0x8
    8000083a:	0c27b783          	ld	a5,194(a5) # 800088f8 <uart_tx_r>
    8000083e:	00008717          	auipc	a4,0x8
    80000842:	0c273703          	ld	a4,194(a4) # 80008900 <uart_tx_w>
    80000846:	06f70a63          	beq	a4,a5,800008ba <uartstart+0x84>
{
    8000084a:	7139                	addi	sp,sp,-64
    8000084c:	fc06                	sd	ra,56(sp)
    8000084e:	f822                	sd	s0,48(sp)
    80000850:	f426                	sd	s1,40(sp)
    80000852:	f04a                	sd	s2,32(sp)
    80000854:	ec4e                	sd	s3,24(sp)
    80000856:	e852                	sd	s4,16(sp)
    80000858:	e456                	sd	s5,8(sp)
    8000085a:	0080                	addi	s0,sp,64
      // transmit buffer is empty.
      return;
    }
    
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    8000085c:	10000937          	lui	s2,0x10000
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      return;
    }
    
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    80000860:	00010a17          	auipc	s4,0x10
    80000864:	2d8a0a13          	addi	s4,s4,728 # 80010b38 <uart_tx_lock>
    uart_tx_r += 1;
    80000868:	00008497          	auipc	s1,0x8
    8000086c:	09048493          	addi	s1,s1,144 # 800088f8 <uart_tx_r>
    if(uart_tx_w == uart_tx_r){
    80000870:	00008997          	auipc	s3,0x8
    80000874:	09098993          	addi	s3,s3,144 # 80008900 <uart_tx_w>
    if((ReadReg(LSR) & LSR_TX_IDLE) == 0){
    80000878:	00594703          	lbu	a4,5(s2) # 10000005 <_entry-0x6ffffffb>
    8000087c:	02077713          	andi	a4,a4,32
    80000880:	c705                	beqz	a4,800008a8 <uartstart+0x72>
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    80000882:	01f7f713          	andi	a4,a5,31
    80000886:	9752                	add	a4,a4,s4
    80000888:	01874a83          	lbu	s5,24(a4)
    uart_tx_r += 1;
    8000088c:	0785                	addi	a5,a5,1
    8000088e:	e09c                	sd	a5,0(s1)
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    80000890:	8526                	mv	a0,s1
    80000892:	00002097          	auipc	ra,0x2
    80000896:	c0c080e7          	jalr	-1012(ra) # 8000249e <wakeup>
    
    WriteReg(THR, c);
    8000089a:	01590023          	sb	s5,0(s2)
    if(uart_tx_w == uart_tx_r){
    8000089e:	609c                	ld	a5,0(s1)
    800008a0:	0009b703          	ld	a4,0(s3)
    800008a4:	fcf71ae3          	bne	a4,a5,80000878 <uartstart+0x42>
  }
}
    800008a8:	70e2                	ld	ra,56(sp)
    800008aa:	7442                	ld	s0,48(sp)
    800008ac:	74a2                	ld	s1,40(sp)
    800008ae:	7902                	ld	s2,32(sp)
    800008b0:	69e2                	ld	s3,24(sp)
    800008b2:	6a42                	ld	s4,16(sp)
    800008b4:	6aa2                	ld	s5,8(sp)
    800008b6:	6121                	addi	sp,sp,64
    800008b8:	8082                	ret
    800008ba:	8082                	ret

00000000800008bc <uartputc>:
{
    800008bc:	7179                	addi	sp,sp,-48
    800008be:	f406                	sd	ra,40(sp)
    800008c0:	f022                	sd	s0,32(sp)
    800008c2:	ec26                	sd	s1,24(sp)
    800008c4:	e84a                	sd	s2,16(sp)
    800008c6:	e44e                	sd	s3,8(sp)
    800008c8:	e052                	sd	s4,0(sp)
    800008ca:	1800                	addi	s0,sp,48
    800008cc:	8a2a                	mv	s4,a0
  acquire(&uart_tx_lock);
    800008ce:	00010517          	auipc	a0,0x10
    800008d2:	26a50513          	addi	a0,a0,618 # 80010b38 <uart_tx_lock>
    800008d6:	00000097          	auipc	ra,0x0
    800008da:	5b4080e7          	jalr	1460(ra) # 80000e8a <acquire>
  if(panicked){
    800008de:	00008797          	auipc	a5,0x8
    800008e2:	0127a783          	lw	a5,18(a5) # 800088f0 <panicked>
    800008e6:	e7c9                	bnez	a5,80000970 <uartputc+0xb4>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    800008e8:	00008717          	auipc	a4,0x8
    800008ec:	01873703          	ld	a4,24(a4) # 80008900 <uart_tx_w>
    800008f0:	00008797          	auipc	a5,0x8
    800008f4:	0087b783          	ld	a5,8(a5) # 800088f8 <uart_tx_r>
    800008f8:	02078793          	addi	a5,a5,32
    sleep(&uart_tx_r, &uart_tx_lock);
    800008fc:	00010997          	auipc	s3,0x10
    80000900:	23c98993          	addi	s3,s3,572 # 80010b38 <uart_tx_lock>
    80000904:	00008497          	auipc	s1,0x8
    80000908:	ff448493          	addi	s1,s1,-12 # 800088f8 <uart_tx_r>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    8000090c:	00008917          	auipc	s2,0x8
    80000910:	ff490913          	addi	s2,s2,-12 # 80008900 <uart_tx_w>
    80000914:	00e79f63          	bne	a5,a4,80000932 <uartputc+0x76>
    sleep(&uart_tx_r, &uart_tx_lock);
    80000918:	85ce                	mv	a1,s3
    8000091a:	8526                	mv	a0,s1
    8000091c:	00002097          	auipc	ra,0x2
    80000920:	b1e080e7          	jalr	-1250(ra) # 8000243a <sleep>
  while(uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE){
    80000924:	00093703          	ld	a4,0(s2)
    80000928:	609c                	ld	a5,0(s1)
    8000092a:	02078793          	addi	a5,a5,32
    8000092e:	fee785e3          	beq	a5,a4,80000918 <uartputc+0x5c>
  uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    80000932:	00010497          	auipc	s1,0x10
    80000936:	20648493          	addi	s1,s1,518 # 80010b38 <uart_tx_lock>
    8000093a:	01f77793          	andi	a5,a4,31
    8000093e:	97a6                	add	a5,a5,s1
    80000940:	01478c23          	sb	s4,24(a5)
  uart_tx_w += 1;
    80000944:	0705                	addi	a4,a4,1
    80000946:	00008797          	auipc	a5,0x8
    8000094a:	fae7bd23          	sd	a4,-70(a5) # 80008900 <uart_tx_w>
  uartstart();
    8000094e:	00000097          	auipc	ra,0x0
    80000952:	ee8080e7          	jalr	-280(ra) # 80000836 <uartstart>
  release(&uart_tx_lock);
    80000956:	8526                	mv	a0,s1
    80000958:	00000097          	auipc	ra,0x0
    8000095c:	5e6080e7          	jalr	1510(ra) # 80000f3e <release>
}
    80000960:	70a2                	ld	ra,40(sp)
    80000962:	7402                	ld	s0,32(sp)
    80000964:	64e2                	ld	s1,24(sp)
    80000966:	6942                	ld	s2,16(sp)
    80000968:	69a2                	ld	s3,8(sp)
    8000096a:	6a02                	ld	s4,0(sp)
    8000096c:	6145                	addi	sp,sp,48
    8000096e:	8082                	ret
    for(;;)
    80000970:	a001                	j	80000970 <uartputc+0xb4>

0000000080000972 <uartgetc>:

// read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
    80000972:	1141                	addi	sp,sp,-16
    80000974:	e422                	sd	s0,8(sp)
    80000976:	0800                	addi	s0,sp,16
  if(ReadReg(LSR) & 0x01){
    80000978:	100007b7          	lui	a5,0x10000
    8000097c:	0057c783          	lbu	a5,5(a5) # 10000005 <_entry-0x6ffffffb>
    80000980:	8b85                	andi	a5,a5,1
    80000982:	cb91                	beqz	a5,80000996 <uartgetc+0x24>
    // input data is ready.
    return ReadReg(RHR);
    80000984:	100007b7          	lui	a5,0x10000
    80000988:	0007c503          	lbu	a0,0(a5) # 10000000 <_entry-0x70000000>
    8000098c:	0ff57513          	andi	a0,a0,255
  } else {
    return -1;
  }
}
    80000990:	6422                	ld	s0,8(sp)
    80000992:	0141                	addi	sp,sp,16
    80000994:	8082                	ret
    return -1;
    80000996:	557d                	li	a0,-1
    80000998:	bfe5                	j	80000990 <uartgetc+0x1e>

000000008000099a <uartintr>:
// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from devintr().
void
uartintr(void)
{
    8000099a:	1101                	addi	sp,sp,-32
    8000099c:	ec06                	sd	ra,24(sp)
    8000099e:	e822                	sd	s0,16(sp)
    800009a0:	e426                	sd	s1,8(sp)
    800009a2:	1000                	addi	s0,sp,32
  // read and process incoming characters.
  while(1){
    int c = uartgetc();
    if(c == -1)
    800009a4:	54fd                	li	s1,-1
    800009a6:	a029                	j	800009b0 <uartintr+0x16>
      break;
    consoleintr(c);
    800009a8:	00000097          	auipc	ra,0x0
    800009ac:	916080e7          	jalr	-1770(ra) # 800002be <consoleintr>
    int c = uartgetc();
    800009b0:	00000097          	auipc	ra,0x0
    800009b4:	fc2080e7          	jalr	-62(ra) # 80000972 <uartgetc>
    if(c == -1)
    800009b8:	fe9518e3          	bne	a0,s1,800009a8 <uartintr+0xe>
  }

  // send buffered characters.
  acquire(&uart_tx_lock);
    800009bc:	00010497          	auipc	s1,0x10
    800009c0:	17c48493          	addi	s1,s1,380 # 80010b38 <uart_tx_lock>
    800009c4:	8526                	mv	a0,s1
    800009c6:	00000097          	auipc	ra,0x0
    800009ca:	4c4080e7          	jalr	1220(ra) # 80000e8a <acquire>
  uartstart();
    800009ce:	00000097          	auipc	ra,0x0
    800009d2:	e68080e7          	jalr	-408(ra) # 80000836 <uartstart>
  release(&uart_tx_lock);
    800009d6:	8526                	mv	a0,s1
    800009d8:	00000097          	auipc	ra,0x0
    800009dc:	566080e7          	jalr	1382(ra) # 80000f3e <release>
}
    800009e0:	60e2                	ld	ra,24(sp)
    800009e2:	6442                	ld	s0,16(sp)
    800009e4:	64a2                	ld	s1,8(sp)
    800009e6:	6105                	addi	sp,sp,32
    800009e8:	8082                	ret

00000000800009ea <kfree>:
// initializing the allocator; see kinit above.)


void
kfree(void *pa)
{
    800009ea:	1101                	addi	sp,sp,-32
    800009ec:	ec06                	sd	ra,24(sp)
    800009ee:	e822                	sd	s0,16(sp)
    800009f0:	e426                	sd	s1,8(sp)
    800009f2:	1000                	addi	s0,sp,32
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    800009f4:	03451793          	slli	a5,a0,0x34
    800009f8:	ebc1                	bnez	a5,80000a88 <kfree+0x9e>
    800009fa:	84aa                	mv	s1,a0
    800009fc:	00041797          	auipc	a5,0x41
    80000a00:	7a478793          	addi	a5,a5,1956 # 800421a0 <end>
    80000a04:	08f56263          	bltu	a0,a5,80000a88 <kfree+0x9e>
    80000a08:	47c5                	li	a5,17
    80000a0a:	07ee                	slli	a5,a5,0x1b
    80000a0c:	06f57e63          	bgeu	a0,a5,80000a88 <kfree+0x9e>
    panic("kfree");

  acquire(&kmem.lock);
    80000a10:	00010517          	auipc	a0,0x10
    80000a14:	16050513          	addi	a0,a0,352 # 80010b70 <kmem>
    80000a18:	00000097          	auipc	ra,0x0
    80000a1c:	472080e7          	jalr	1138(ra) # 80000e8a <acquire>
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
    80000a20:	800007b7          	lui	a5,0x80000
    80000a24:	97a6                	add	a5,a5,s1
    80000a26:	83b1                	srli	a5,a5,0xc
    80000a28:	2781                	sext.w	a5,a5
  
  if(kmem.reference_counts[index] > 0) {
    80000a2a:	00878713          	addi	a4,a5,8 # ffffffff80000008 <end+0xfffffffefffbde68>
    80000a2e:	00271693          	slli	a3,a4,0x2
    80000a32:	00010717          	auipc	a4,0x10
    80000a36:	13e70713          	addi	a4,a4,318 # 80010b70 <kmem>
    80000a3a:	9736                	add	a4,a4,a3
    80000a3c:	4318                	lw	a4,0(a4)
    80000a3e:	00e05e63          	blez	a4,80000a5a <kfree+0x70>
    kmem.reference_counts[index]--;
    80000a42:	377d                	addiw	a4,a4,-1
    80000a44:	0007061b          	sext.w	a2,a4
    80000a48:	87b6                	mv	a5,a3
    80000a4a:	00010697          	auipc	a3,0x10
    80000a4e:	12668693          	addi	a3,a3,294 # 80010b70 <kmem>
    80000a52:	97b6                	add	a5,a5,a3
    80000a54:	c398                	sw	a4,0(a5)
    if(kmem.reference_counts[index] > 0) {
    80000a56:	04c04163          	bgtz	a2,80000a98 <kfree+0xae>
      release(&kmem.lock);
      return;
    }
  }

  memset(pa, 1, PGSIZE);
    80000a5a:	6605                	lui	a2,0x1
    80000a5c:	4585                	li	a1,1
    80000a5e:	8526                	mv	a0,s1
    80000a60:	00000097          	auipc	ra,0x0
    80000a64:	526080e7          	jalr	1318(ra) # 80000f86 <memset>
  r = (struct run*)pa;
  r->next = kmem.freelist;
    80000a68:	00010517          	auipc	a0,0x10
    80000a6c:	10850513          	addi	a0,a0,264 # 80010b70 <kmem>
    80000a70:	6d1c                	ld	a5,24(a0)
    80000a72:	e09c                	sd	a5,0(s1)
  kmem.freelist = r;
    80000a74:	ed04                	sd	s1,24(a0)
  release(&kmem.lock);
    80000a76:	00000097          	auipc	ra,0x0
    80000a7a:	4c8080e7          	jalr	1224(ra) # 80000f3e <release>
}
    80000a7e:	60e2                	ld	ra,24(sp)
    80000a80:	6442                	ld	s0,16(sp)
    80000a82:	64a2                	ld	s1,8(sp)
    80000a84:	6105                	addi	sp,sp,32
    80000a86:	8082                	ret
    panic("kfree");
    80000a88:	00007517          	auipc	a0,0x7
    80000a8c:	5d850513          	addi	a0,a0,1496 # 80008060 <digits+0x20>
    80000a90:	00000097          	auipc	ra,0x0
    80000a94:	aae080e7          	jalr	-1362(ra) # 8000053e <panic>
      release(&kmem.lock);
    80000a98:	8536                	mv	a0,a3
    80000a9a:	00000097          	auipc	ra,0x0
    80000a9e:	4a4080e7          	jalr	1188(ra) # 80000f3e <release>
      return;
    80000aa2:	bff1                	j	80000a7e <kfree+0x94>

0000000080000aa4 <freerange>:
{
    80000aa4:	7179                	addi	sp,sp,-48
    80000aa6:	f406                	sd	ra,40(sp)
    80000aa8:	f022                	sd	s0,32(sp)
    80000aaa:	ec26                	sd	s1,24(sp)
    80000aac:	e84a                	sd	s2,16(sp)
    80000aae:	e44e                	sd	s3,8(sp)
    80000ab0:	e052                	sd	s4,0(sp)
    80000ab2:	1800                	addi	s0,sp,48
  p = (char*)PGROUNDUP((uint64)pa_start);
    80000ab4:	6785                	lui	a5,0x1
    80000ab6:	fff78493          	addi	s1,a5,-1 # fff <_entry-0x7ffff001>
    80000aba:	94aa                	add	s1,s1,a0
    80000abc:	757d                	lui	a0,0xfffff
    80000abe:	8ce9                	and	s1,s1,a0
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000ac0:	94be                	add	s1,s1,a5
    80000ac2:	0095ee63          	bltu	a1,s1,80000ade <freerange+0x3a>
    80000ac6:	892e                	mv	s2,a1
    kfree(p);
    80000ac8:	7a7d                	lui	s4,0xfffff
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000aca:	6985                	lui	s3,0x1
    kfree(p);
    80000acc:	01448533          	add	a0,s1,s4
    80000ad0:	00000097          	auipc	ra,0x0
    80000ad4:	f1a080e7          	jalr	-230(ra) # 800009ea <kfree>
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000ad8:	94ce                	add	s1,s1,s3
    80000ada:	fe9979e3          	bgeu	s2,s1,80000acc <freerange+0x28>
}
    80000ade:	70a2                	ld	ra,40(sp)
    80000ae0:	7402                	ld	s0,32(sp)
    80000ae2:	64e2                	ld	s1,24(sp)
    80000ae4:	6942                	ld	s2,16(sp)
    80000ae6:	69a2                	ld	s3,8(sp)
    80000ae8:	6a02                	ld	s4,0(sp)
    80000aea:	6145                	addi	sp,sp,48
    80000aec:	8082                	ret

0000000080000aee <kinit>:
{
    80000aee:	1141                	addi	sp,sp,-16
    80000af0:	e406                	sd	ra,8(sp)
    80000af2:	e022                	sd	s0,0(sp)
    80000af4:	0800                	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000af6:	00007597          	auipc	a1,0x7
    80000afa:	57258593          	addi	a1,a1,1394 # 80008068 <digits+0x28>
    80000afe:	00010517          	auipc	a0,0x10
    80000b02:	07250513          	addi	a0,a0,114 # 80010b70 <kmem>
    80000b06:	00000097          	auipc	ra,0x0
    80000b0a:	2f4080e7          	jalr	756(ra) # 80000dfa <initlock>
  memset(kmem.reference_counts, 0, sizeof(kmem.reference_counts));
    80000b0e:	00020637          	lui	a2,0x20
    80000b12:	4581                	li	a1,0
    80000b14:	00010517          	auipc	a0,0x10
    80000b18:	07c50513          	addi	a0,a0,124 # 80010b90 <kmem+0x20>
    80000b1c:	00000097          	auipc	ra,0x0
    80000b20:	46a080e7          	jalr	1130(ra) # 80000f86 <memset>
  freerange(end, (void*)PHYSTOP);
    80000b24:	45c5                	li	a1,17
    80000b26:	05ee                	slli	a1,a1,0x1b
    80000b28:	00041517          	auipc	a0,0x41
    80000b2c:	67850513          	addi	a0,a0,1656 # 800421a0 <end>
    80000b30:	00000097          	auipc	ra,0x0
    80000b34:	f74080e7          	jalr	-140(ra) # 80000aa4 <freerange>
}
    80000b38:	60a2                	ld	ra,8(sp)
    80000b3a:	6402                	ld	s0,0(sp)
    80000b3c:	0141                	addi	sp,sp,16
    80000b3e:	8082                	ret

0000000080000b40 <kalloc>:
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.

void*
kalloc(void)
{
    80000b40:	1101                	addi	sp,sp,-32
    80000b42:	ec06                	sd	ra,24(sp)
    80000b44:	e822                	sd	s0,16(sp)
    80000b46:	e426                	sd	s1,8(sp)
    80000b48:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000b4a:	00010517          	auipc	a0,0x10
    80000b4e:	02650513          	addi	a0,a0,38 # 80010b70 <kmem>
    80000b52:	00000097          	auipc	ra,0x0
    80000b56:	338080e7          	jalr	824(ra) # 80000e8a <acquire>
  r = kmem.freelist;
    80000b5a:	00010497          	auipc	s1,0x10
    80000b5e:	02e4b483          	ld	s1,46(s1) # 80010b88 <kmem+0x18>
  if(r) {
    80000b62:	c0b1                	beqz	s1,80000ba6 <kalloc+0x66>
    kmem.freelist = r->next;
    80000b64:	609c                	ld	a5,0(s1)
    80000b66:	00010517          	auipc	a0,0x10
    80000b6a:	00a50513          	addi	a0,a0,10 # 80010b70 <kmem>
    80000b6e:	ed1c                	sd	a5,24(a0)
    int index = ((uint64)r - KERNBASE) / PGSIZE;
    80000b70:	800007b7          	lui	a5,0x80000
    80000b74:	97a6                	add	a5,a5,s1
    80000b76:	83b1                	srli	a5,a5,0xc
    kmem.reference_counts[index] = 1;
    80000b78:	2781                	sext.w	a5,a5
    80000b7a:	07a1                	addi	a5,a5,8
    80000b7c:	078a                	slli	a5,a5,0x2
    80000b7e:	97aa                	add	a5,a5,a0
    80000b80:	4705                	li	a4,1
    80000b82:	c398                	sw	a4,0(a5)
  }
  release(&kmem.lock);
    80000b84:	00000097          	auipc	ra,0x0
    80000b88:	3ba080e7          	jalr	954(ra) # 80000f3e <release>

  if(r)
    memset((char*)r, 5, PGSIZE);
    80000b8c:	6605                	lui	a2,0x1
    80000b8e:	4595                	li	a1,5
    80000b90:	8526                	mv	a0,s1
    80000b92:	00000097          	auipc	ra,0x0
    80000b96:	3f4080e7          	jalr	1012(ra) # 80000f86 <memset>
  return (void*)r;
}
    80000b9a:	8526                	mv	a0,s1
    80000b9c:	60e2                	ld	ra,24(sp)
    80000b9e:	6442                	ld	s0,16(sp)
    80000ba0:	64a2                	ld	s1,8(sp)
    80000ba2:	6105                	addi	sp,sp,32
    80000ba4:	8082                	ret
  release(&kmem.lock);
    80000ba6:	00010517          	auipc	a0,0x10
    80000baa:	fca50513          	addi	a0,a0,-54 # 80010b70 <kmem>
    80000bae:	00000097          	auipc	ra,0x0
    80000bb2:	390080e7          	jalr	912(ra) # 80000f3e <release>
  if(r)
    80000bb6:	b7d5                	j	80000b9a <kalloc+0x5a>

0000000080000bb8 <cow_alloc>:
void*
cow_alloc()
{
    80000bb8:	1101                	addi	sp,sp,-32
    80000bba:	ec06                	sd	ra,24(sp)
    80000bbc:	e822                	sd	s0,16(sp)
    80000bbe:	e426                	sd	s1,8(sp)
    80000bc0:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000bc2:	00010517          	auipc	a0,0x10
    80000bc6:	fae50513          	addi	a0,a0,-82 # 80010b70 <kmem>
    80000bca:	00000097          	auipc	ra,0x0
    80000bce:	2c0080e7          	jalr	704(ra) # 80000e8a <acquire>
  r = kmem.freelist;
    80000bd2:	00010497          	auipc	s1,0x10
    80000bd6:	fb64b483          	ld	s1,-74(s1) # 80010b88 <kmem+0x18>
  if(r) {
    80000bda:	c08d                	beqz	s1,80000bfc <cow_alloc+0x44>
    kmem.freelist = r->next;
    80000bdc:	609c                	ld	a5,0(s1)
    80000bde:	00010717          	auipc	a4,0x10
    80000be2:	f9270713          	addi	a4,a4,-110 # 80010b70 <kmem>
    80000be6:	ef1c                	sd	a5,24(a4)
    int index = ((uint64)r - KERNBASE) / PGSIZE;
    80000be8:	800007b7          	lui	a5,0x80000
    80000bec:	97a6                	add	a5,a5,s1
    80000bee:	83b1                	srli	a5,a5,0xc
    kmem.reference_counts[index] = 1;
    80000bf0:	2781                	sext.w	a5,a5
    80000bf2:	07a1                	addi	a5,a5,8
    80000bf4:	078a                	slli	a5,a5,0x2
    80000bf6:	97ba                	add	a5,a5,a4
    80000bf8:	4705                	li	a4,1
    80000bfa:	c398                	sw	a4,0(a5)
  }
  release(&kmem.lock);
    80000bfc:	00010517          	auipc	a0,0x10
    80000c00:	f7450513          	addi	a0,a0,-140 # 80010b70 <kmem>
    80000c04:	00000097          	auipc	ra,0x0
    80000c08:	33a080e7          	jalr	826(ra) # 80000f3e <release>

  return (void*)r;
}
    80000c0c:	8526                	mv	a0,s1
    80000c0e:	60e2                	ld	ra,24(sp)
    80000c10:	6442                	ld	s0,16(sp)
    80000c12:	64a2                	ld	s1,8(sp)
    80000c14:	6105                	addi	sp,sp,32
    80000c16:	8082                	ret

0000000080000c18 <cow_reference>:
void
cow_reference(void *pa)
{
    80000c18:	1101                	addi	sp,sp,-32
    80000c1a:	ec06                	sd	ra,24(sp)
    80000c1c:	e822                	sd	s0,16(sp)
    80000c1e:	e426                	sd	s1,8(sp)
    80000c20:	1000                	addi	s0,sp,32
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000c22:	03451793          	slli	a5,a0,0x34
    80000c26:	efa1                	bnez	a5,80000c7e <cow_reference+0x66>
    80000c28:	84aa                	mv	s1,a0
    80000c2a:	00041797          	auipc	a5,0x41
    80000c2e:	57678793          	addi	a5,a5,1398 # 800421a0 <end>
    80000c32:	04f56663          	bltu	a0,a5,80000c7e <cow_reference+0x66>
    80000c36:	47c5                	li	a5,17
    80000c38:	07ee                	slli	a5,a5,0x1b
    80000c3a:	04f57263          	bgeu	a0,a5,80000c7e <cow_reference+0x66>
    panic("cow_reference");
    
  acquire(&kmem.lock);
    80000c3e:	00010517          	auipc	a0,0x10
    80000c42:	f3250513          	addi	a0,a0,-206 # 80010b70 <kmem>
    80000c46:	00000097          	auipc	ra,0x0
    80000c4a:	244080e7          	jalr	580(ra) # 80000e8a <acquire>
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
    80000c4e:	800007b7          	lui	a5,0x80000
    80000c52:	97a6                	add	a5,a5,s1
    80000c54:	83b1                	srli	a5,a5,0xc
    80000c56:	2781                	sext.w	a5,a5
  kmem.reference_counts[index]++;
    80000c58:	00010517          	auipc	a0,0x10
    80000c5c:	f1850513          	addi	a0,a0,-232 # 80010b70 <kmem>
    80000c60:	07a1                	addi	a5,a5,8
    80000c62:	078a                	slli	a5,a5,0x2
    80000c64:	97aa                	add	a5,a5,a0
    80000c66:	4398                	lw	a4,0(a5)
    80000c68:	2705                	addiw	a4,a4,1
    80000c6a:	c398                	sw	a4,0(a5)
  release(&kmem.lock);
    80000c6c:	00000097          	auipc	ra,0x0
    80000c70:	2d2080e7          	jalr	722(ra) # 80000f3e <release>
}
    80000c74:	60e2                	ld	ra,24(sp)
    80000c76:	6442                	ld	s0,16(sp)
    80000c78:	64a2                	ld	s1,8(sp)
    80000c7a:	6105                	addi	sp,sp,32
    80000c7c:	8082                	ret
    panic("cow_reference");
    80000c7e:	00007517          	auipc	a0,0x7
    80000c82:	3f250513          	addi	a0,a0,1010 # 80008070 <digits+0x30>
    80000c86:	00000097          	auipc	ra,0x0
    80000c8a:	8b8080e7          	jalr	-1864(ra) # 8000053e <panic>

0000000080000c8e <cow_decrement>:

void
cow_decrement(void *pa)
{
    80000c8e:	1101                	addi	sp,sp,-32
    80000c90:	ec06                	sd	ra,24(sp)
    80000c92:	e822                	sd	s0,16(sp)
    80000c94:	e426                	sd	s1,8(sp)
    80000c96:	1000                	addi	s0,sp,32
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000c98:	03451793          	slli	a5,a0,0x34
    80000c9c:	ebb5                	bnez	a5,80000d10 <cow_decrement+0x82>
    80000c9e:	84aa                	mv	s1,a0
    80000ca0:	00041797          	auipc	a5,0x41
    80000ca4:	50078793          	addi	a5,a5,1280 # 800421a0 <end>
    80000ca8:	06f56463          	bltu	a0,a5,80000d10 <cow_decrement+0x82>
    80000cac:	47c5                	li	a5,17
    80000cae:	07ee                	slli	a5,a5,0x1b
    80000cb0:	06f57063          	bgeu	a0,a5,80000d10 <cow_decrement+0x82>
    panic("cow_decrement");
    
  acquire(&kmem.lock);
    80000cb4:	00010517          	auipc	a0,0x10
    80000cb8:	ebc50513          	addi	a0,a0,-324 # 80010b70 <kmem>
    80000cbc:	00000097          	auipc	ra,0x0
    80000cc0:	1ce080e7          	jalr	462(ra) # 80000e8a <acquire>
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
    80000cc4:	80000537          	lui	a0,0x80000
    80000cc8:	94aa                	add	s1,s1,a0
    80000cca:	80b1                	srli	s1,s1,0xc
    80000ccc:	2481                	sext.w	s1,s1
  if(kmem.reference_counts[index] > 0)
    80000cce:	00848793          	addi	a5,s1,8
    80000cd2:	00279713          	slli	a4,a5,0x2
    80000cd6:	00010797          	auipc	a5,0x10
    80000cda:	e9a78793          	addi	a5,a5,-358 # 80010b70 <kmem>
    80000cde:	97ba                	add	a5,a5,a4
    80000ce0:	439c                	lw	a5,0(a5)
    80000ce2:	00f05a63          	blez	a5,80000cf6 <cow_decrement+0x68>
    kmem.reference_counts[index]--;
    80000ce6:	84ba                	mv	s1,a4
    80000ce8:	00010717          	auipc	a4,0x10
    80000cec:	e8870713          	addi	a4,a4,-376 # 80010b70 <kmem>
    80000cf0:	94ba                	add	s1,s1,a4
    80000cf2:	37fd                	addiw	a5,a5,-1
    80000cf4:	c09c                	sw	a5,0(s1)
  release(&kmem.lock);
    80000cf6:	00010517          	auipc	a0,0x10
    80000cfa:	e7a50513          	addi	a0,a0,-390 # 80010b70 <kmem>
    80000cfe:	00000097          	auipc	ra,0x0
    80000d02:	240080e7          	jalr	576(ra) # 80000f3e <release>
}
    80000d06:	60e2                	ld	ra,24(sp)
    80000d08:	6442                	ld	s0,16(sp)
    80000d0a:	64a2                	ld	s1,8(sp)
    80000d0c:	6105                	addi	sp,sp,32
    80000d0e:	8082                	ret
    panic("cow_decrement");
    80000d10:	00007517          	auipc	a0,0x7
    80000d14:	37050513          	addi	a0,a0,880 # 80008080 <digits+0x40>
    80000d18:	00000097          	auipc	ra,0x0
    80000d1c:	826080e7          	jalr	-2010(ra) # 8000053e <panic>

0000000080000d20 <get_refcount>:

int
get_refcount(void *pa)
{
    80000d20:	1101                	addi	sp,sp,-32
    80000d22:	ec06                	sd	ra,24(sp)
    80000d24:	e822                	sd	s0,16(sp)
    80000d26:	e426                	sd	s1,8(sp)
    80000d28:	e04a                	sd	s2,0(sp)
    80000d2a:	1000                	addi	s0,sp,32
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000d2c:	03451793          	slli	a5,a0,0x34
    return 0;
    80000d30:	4901                	li	s2,0
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000d32:	ef89                	bnez	a5,80000d4c <get_refcount+0x2c>
    80000d34:	84aa                	mv	s1,a0
    80000d36:	00041797          	auipc	a5,0x41
    80000d3a:	46a78793          	addi	a5,a5,1130 # 800421a0 <end>
    return 0;
    80000d3e:	4901                	li	s2,0
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000d40:	00f56663          	bltu	a0,a5,80000d4c <get_refcount+0x2c>
    80000d44:	47c5                	li	a5,17
    80000d46:	07ee                	slli	a5,a5,0x1b
    80000d48:	00f56963          	bltu	a0,a5,80000d5a <get_refcount+0x3a>
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  int count = kmem.reference_counts[index];
  release(&kmem.lock);
  return count;
}
    80000d4c:	854a                	mv	a0,s2
    80000d4e:	60e2                	ld	ra,24(sp)
    80000d50:	6442                	ld	s0,16(sp)
    80000d52:	64a2                	ld	s1,8(sp)
    80000d54:	6902                	ld	s2,0(sp)
    80000d56:	6105                	addi	sp,sp,32
    80000d58:	8082                	ret
  acquire(&kmem.lock);
    80000d5a:	00010517          	auipc	a0,0x10
    80000d5e:	e1650513          	addi	a0,a0,-490 # 80010b70 <kmem>
    80000d62:	00000097          	auipc	ra,0x0
    80000d66:	128080e7          	jalr	296(ra) # 80000e8a <acquire>
  int count = kmem.reference_counts[index];
    80000d6a:	00010517          	auipc	a0,0x10
    80000d6e:	e0650513          	addi	a0,a0,-506 # 80010b70 <kmem>
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
    80000d72:	800007b7          	lui	a5,0x80000
    80000d76:	97a6                	add	a5,a5,s1
    80000d78:	83b1                	srli	a5,a5,0xc
  int count = kmem.reference_counts[index];
    80000d7a:	2781                	sext.w	a5,a5
    80000d7c:	07a1                	addi	a5,a5,8
    80000d7e:	078a                	slli	a5,a5,0x2
    80000d80:	97aa                	add	a5,a5,a0
    80000d82:	0007a903          	lw	s2,0(a5) # ffffffff80000000 <end+0xfffffffefffbde60>
  release(&kmem.lock);
    80000d86:	00000097          	auipc	ra,0x0
    80000d8a:	1b8080e7          	jalr	440(ra) # 80000f3e <release>
  return count;
    80000d8e:	bf7d                	j	80000d4c <get_refcount+0x2c>

0000000080000d90 <increment_refcount>:

void
increment_refcount(void *pa)
{
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000d90:	03451793          	slli	a5,a0,0x34
    80000d94:	e3b5                	bnez	a5,80000df8 <increment_refcount+0x68>
{
    80000d96:	1101                	addi	sp,sp,-32
    80000d98:	ec06                	sd	ra,24(sp)
    80000d9a:	e822                	sd	s0,16(sp)
    80000d9c:	e426                	sd	s1,8(sp)
    80000d9e:	1000                	addi	s0,sp,32
    80000da0:	84aa                	mv	s1,a0
  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000da2:	00041797          	auipc	a5,0x41
    80000da6:	3fe78793          	addi	a5,a5,1022 # 800421a0 <end>
    80000daa:	00f56663          	bltu	a0,a5,80000db6 <increment_refcount+0x26>
    80000dae:	47c5                	li	a5,17
    80000db0:	07ee                	slli	a5,a5,0x1b
    80000db2:	00f56763          	bltu	a0,a5,80000dc0 <increment_refcount+0x30>
    
  acquire(&kmem.lock);
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
  kmem.reference_counts[index]++;
  release(&kmem.lock);
}
    80000db6:	60e2                	ld	ra,24(sp)
    80000db8:	6442                	ld	s0,16(sp)
    80000dba:	64a2                	ld	s1,8(sp)
    80000dbc:	6105                	addi	sp,sp,32
    80000dbe:	8082                	ret
  acquire(&kmem.lock);
    80000dc0:	00010517          	auipc	a0,0x10
    80000dc4:	db050513          	addi	a0,a0,-592 # 80010b70 <kmem>
    80000dc8:	00000097          	auipc	ra,0x0
    80000dcc:	0c2080e7          	jalr	194(ra) # 80000e8a <acquire>
  int index = ((uint64)pa - KERNBASE) / PGSIZE;
    80000dd0:	800007b7          	lui	a5,0x80000
    80000dd4:	97a6                	add	a5,a5,s1
    80000dd6:	83b1                	srli	a5,a5,0xc
    80000dd8:	2781                	sext.w	a5,a5
  kmem.reference_counts[index]++;
    80000dda:	00010517          	auipc	a0,0x10
    80000dde:	d9650513          	addi	a0,a0,-618 # 80010b70 <kmem>
    80000de2:	07a1                	addi	a5,a5,8
    80000de4:	078a                	slli	a5,a5,0x2
    80000de6:	97aa                	add	a5,a5,a0
    80000de8:	4398                	lw	a4,0(a5)
    80000dea:	2705                	addiw	a4,a4,1
    80000dec:	c398                	sw	a4,0(a5)
  release(&kmem.lock);
    80000dee:	00000097          	auipc	ra,0x0
    80000df2:	150080e7          	jalr	336(ra) # 80000f3e <release>
    80000df6:	b7c1                	j	80000db6 <increment_refcount+0x26>
    80000df8:	8082                	ret

0000000080000dfa <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000dfa:	1141                	addi	sp,sp,-16
    80000dfc:	e422                	sd	s0,8(sp)
    80000dfe:	0800                	addi	s0,sp,16
  lk->name = name;
    80000e00:	e50c                	sd	a1,8(a0)
  lk->locked = 0;
    80000e02:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000e06:	00053823          	sd	zero,16(a0)
}
    80000e0a:	6422                	ld	s0,8(sp)
    80000e0c:	0141                	addi	sp,sp,16
    80000e0e:	8082                	ret

0000000080000e10 <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000e10:	411c                	lw	a5,0(a0)
    80000e12:	e399                	bnez	a5,80000e18 <holding+0x8>
    80000e14:	4501                	li	a0,0
  return r;
}
    80000e16:	8082                	ret
{
    80000e18:	1101                	addi	sp,sp,-32
    80000e1a:	ec06                	sd	ra,24(sp)
    80000e1c:	e822                	sd	s0,16(sp)
    80000e1e:	e426                	sd	s1,8(sp)
    80000e20:	1000                	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000e22:	6904                	ld	s1,16(a0)
    80000e24:	00001097          	auipc	ra,0x1
    80000e28:	f3e080e7          	jalr	-194(ra) # 80001d62 <mycpu>
    80000e2c:	40a48533          	sub	a0,s1,a0
    80000e30:	00153513          	seqz	a0,a0
}
    80000e34:	60e2                	ld	ra,24(sp)
    80000e36:	6442                	ld	s0,16(sp)
    80000e38:	64a2                	ld	s1,8(sp)
    80000e3a:	6105                	addi	sp,sp,32
    80000e3c:	8082                	ret

0000000080000e3e <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000e3e:	1101                	addi	sp,sp,-32
    80000e40:	ec06                	sd	ra,24(sp)
    80000e42:	e822                	sd	s0,16(sp)
    80000e44:	e426                	sd	s1,8(sp)
    80000e46:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000e48:	100024f3          	csrr	s1,sstatus
    80000e4c:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000e50:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000e52:	10079073          	csrw	sstatus,a5
  int old = intr_get();

  intr_off();
  if(mycpu()->noff == 0)
    80000e56:	00001097          	auipc	ra,0x1
    80000e5a:	f0c080e7          	jalr	-244(ra) # 80001d62 <mycpu>
    80000e5e:	5d3c                	lw	a5,120(a0)
    80000e60:	cf89                	beqz	a5,80000e7a <push_off+0x3c>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000e62:	00001097          	auipc	ra,0x1
    80000e66:	f00080e7          	jalr	-256(ra) # 80001d62 <mycpu>
    80000e6a:	5d3c                	lw	a5,120(a0)
    80000e6c:	2785                	addiw	a5,a5,1
    80000e6e:	dd3c                	sw	a5,120(a0)
}
    80000e70:	60e2                	ld	ra,24(sp)
    80000e72:	6442                	ld	s0,16(sp)
    80000e74:	64a2                	ld	s1,8(sp)
    80000e76:	6105                	addi	sp,sp,32
    80000e78:	8082                	ret
    mycpu()->intena = old;
    80000e7a:	00001097          	auipc	ra,0x1
    80000e7e:	ee8080e7          	jalr	-280(ra) # 80001d62 <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000e82:	8085                	srli	s1,s1,0x1
    80000e84:	8885                	andi	s1,s1,1
    80000e86:	dd64                	sw	s1,124(a0)
    80000e88:	bfe9                	j	80000e62 <push_off+0x24>

0000000080000e8a <acquire>:
{
    80000e8a:	1101                	addi	sp,sp,-32
    80000e8c:	ec06                	sd	ra,24(sp)
    80000e8e:	e822                	sd	s0,16(sp)
    80000e90:	e426                	sd	s1,8(sp)
    80000e92:	1000                	addi	s0,sp,32
    80000e94:	84aa                	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000e96:	00000097          	auipc	ra,0x0
    80000e9a:	fa8080e7          	jalr	-88(ra) # 80000e3e <push_off>
  if(holding(lk))
    80000e9e:	8526                	mv	a0,s1
    80000ea0:	00000097          	auipc	ra,0x0
    80000ea4:	f70080e7          	jalr	-144(ra) # 80000e10 <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000ea8:	4705                	li	a4,1
  if(holding(lk))
    80000eaa:	e115                	bnez	a0,80000ece <acquire+0x44>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000eac:	87ba                	mv	a5,a4
    80000eae:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80000eb2:	2781                	sext.w	a5,a5
    80000eb4:	ffe5                	bnez	a5,80000eac <acquire+0x22>
  __sync_synchronize();
    80000eb6:	0ff0000f          	fence
  lk->cpu = mycpu();
    80000eba:	00001097          	auipc	ra,0x1
    80000ebe:	ea8080e7          	jalr	-344(ra) # 80001d62 <mycpu>
    80000ec2:	e888                	sd	a0,16(s1)
}
    80000ec4:	60e2                	ld	ra,24(sp)
    80000ec6:	6442                	ld	s0,16(sp)
    80000ec8:	64a2                	ld	s1,8(sp)
    80000eca:	6105                	addi	sp,sp,32
    80000ecc:	8082                	ret
    panic("acquire");
    80000ece:	00007517          	auipc	a0,0x7
    80000ed2:	1c250513          	addi	a0,a0,450 # 80008090 <digits+0x50>
    80000ed6:	fffff097          	auipc	ra,0xfffff
    80000eda:	668080e7          	jalr	1640(ra) # 8000053e <panic>

0000000080000ede <pop_off>:

void
pop_off(void)
{
    80000ede:	1141                	addi	sp,sp,-16
    80000ee0:	e406                	sd	ra,8(sp)
    80000ee2:	e022                	sd	s0,0(sp)
    80000ee4:	0800                	addi	s0,sp,16
  struct cpu *c = mycpu();
    80000ee6:	00001097          	auipc	ra,0x1
    80000eea:	e7c080e7          	jalr	-388(ra) # 80001d62 <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000eee:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80000ef2:	8b89                	andi	a5,a5,2
  if(intr_get())
    80000ef4:	e78d                	bnez	a5,80000f1e <pop_off+0x40>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80000ef6:	5d3c                	lw	a5,120(a0)
    80000ef8:	02f05b63          	blez	a5,80000f2e <pop_off+0x50>
    panic("pop_off");
  c->noff -= 1;
    80000efc:	37fd                	addiw	a5,a5,-1
    80000efe:	0007871b          	sext.w	a4,a5
    80000f02:	dd3c                	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    80000f04:	eb09                	bnez	a4,80000f16 <pop_off+0x38>
    80000f06:	5d7c                	lw	a5,124(a0)
    80000f08:	c799                	beqz	a5,80000f16 <pop_off+0x38>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000f0a:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80000f0e:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000f12:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80000f16:	60a2                	ld	ra,8(sp)
    80000f18:	6402                	ld	s0,0(sp)
    80000f1a:	0141                	addi	sp,sp,16
    80000f1c:	8082                	ret
    panic("pop_off - interruptible");
    80000f1e:	00007517          	auipc	a0,0x7
    80000f22:	17a50513          	addi	a0,a0,378 # 80008098 <digits+0x58>
    80000f26:	fffff097          	auipc	ra,0xfffff
    80000f2a:	618080e7          	jalr	1560(ra) # 8000053e <panic>
    panic("pop_off");
    80000f2e:	00007517          	auipc	a0,0x7
    80000f32:	18250513          	addi	a0,a0,386 # 800080b0 <digits+0x70>
    80000f36:	fffff097          	auipc	ra,0xfffff
    80000f3a:	608080e7          	jalr	1544(ra) # 8000053e <panic>

0000000080000f3e <release>:
{
    80000f3e:	1101                	addi	sp,sp,-32
    80000f40:	ec06                	sd	ra,24(sp)
    80000f42:	e822                	sd	s0,16(sp)
    80000f44:	e426                	sd	s1,8(sp)
    80000f46:	1000                	addi	s0,sp,32
    80000f48:	84aa                	mv	s1,a0
  if(!holding(lk))
    80000f4a:	00000097          	auipc	ra,0x0
    80000f4e:	ec6080e7          	jalr	-314(ra) # 80000e10 <holding>
    80000f52:	c115                	beqz	a0,80000f76 <release+0x38>
  lk->cpu = 0;
    80000f54:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    80000f58:	0ff0000f          	fence
  __sync_lock_release(&lk->locked);
    80000f5c:	0f50000f          	fence	iorw,ow
    80000f60:	0804a02f          	amoswap.w	zero,zero,(s1)
  pop_off();
    80000f64:	00000097          	auipc	ra,0x0
    80000f68:	f7a080e7          	jalr	-134(ra) # 80000ede <pop_off>
}
    80000f6c:	60e2                	ld	ra,24(sp)
    80000f6e:	6442                	ld	s0,16(sp)
    80000f70:	64a2                	ld	s1,8(sp)
    80000f72:	6105                	addi	sp,sp,32
    80000f74:	8082                	ret
    panic("release");
    80000f76:	00007517          	auipc	a0,0x7
    80000f7a:	14250513          	addi	a0,a0,322 # 800080b8 <digits+0x78>
    80000f7e:	fffff097          	auipc	ra,0xfffff
    80000f82:	5c0080e7          	jalr	1472(ra) # 8000053e <panic>

0000000080000f86 <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80000f86:	1141                	addi	sp,sp,-16
    80000f88:	e422                	sd	s0,8(sp)
    80000f8a:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80000f8c:	ca19                	beqz	a2,80000fa2 <memset+0x1c>
    80000f8e:	87aa                	mv	a5,a0
    80000f90:	1602                	slli	a2,a2,0x20
    80000f92:	9201                	srli	a2,a2,0x20
    80000f94:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80000f98:	00b78023          	sb	a1,0(a5) # ffffffff80000000 <end+0xfffffffefffbde60>
  for(i = 0; i < n; i++){
    80000f9c:	0785                	addi	a5,a5,1
    80000f9e:	fee79de3          	bne	a5,a4,80000f98 <memset+0x12>
  }
  return dst;
}
    80000fa2:	6422                	ld	s0,8(sp)
    80000fa4:	0141                	addi	sp,sp,16
    80000fa6:	8082                	ret

0000000080000fa8 <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    80000fa8:	1141                	addi	sp,sp,-16
    80000faa:	e422                	sd	s0,8(sp)
    80000fac:	0800                	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80000fae:	ca05                	beqz	a2,80000fde <memcmp+0x36>
    80000fb0:	fff6069b          	addiw	a3,a2,-1
    80000fb4:	1682                	slli	a3,a3,0x20
    80000fb6:	9281                	srli	a3,a3,0x20
    80000fb8:	0685                	addi	a3,a3,1
    80000fba:	96aa                	add	a3,a3,a0
    if(*s1 != *s2)
    80000fbc:	00054783          	lbu	a5,0(a0)
    80000fc0:	0005c703          	lbu	a4,0(a1)
    80000fc4:	00e79863          	bne	a5,a4,80000fd4 <memcmp+0x2c>
      return *s1 - *s2;
    s1++, s2++;
    80000fc8:	0505                	addi	a0,a0,1
    80000fca:	0585                	addi	a1,a1,1
  while(n-- > 0){
    80000fcc:	fed518e3          	bne	a0,a3,80000fbc <memcmp+0x14>
  }

  return 0;
    80000fd0:	4501                	li	a0,0
    80000fd2:	a019                	j	80000fd8 <memcmp+0x30>
      return *s1 - *s2;
    80000fd4:	40e7853b          	subw	a0,a5,a4
}
    80000fd8:	6422                	ld	s0,8(sp)
    80000fda:	0141                	addi	sp,sp,16
    80000fdc:	8082                	ret
  return 0;
    80000fde:	4501                	li	a0,0
    80000fe0:	bfe5                	j	80000fd8 <memcmp+0x30>

0000000080000fe2 <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    80000fe2:	1141                	addi	sp,sp,-16
    80000fe4:	e422                	sd	s0,8(sp)
    80000fe6:	0800                	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    80000fe8:	c205                	beqz	a2,80001008 <memmove+0x26>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    80000fea:	02a5e263          	bltu	a1,a0,8000100e <memmove+0x2c>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    80000fee:	1602                	slli	a2,a2,0x20
    80000ff0:	9201                	srli	a2,a2,0x20
    80000ff2:	00c587b3          	add	a5,a1,a2
{
    80000ff6:	872a                	mv	a4,a0
      *d++ = *s++;
    80000ff8:	0585                	addi	a1,a1,1
    80000ffa:	0705                	addi	a4,a4,1
    80000ffc:	fff5c683          	lbu	a3,-1(a1)
    80001000:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    80001004:	fef59ae3          	bne	a1,a5,80000ff8 <memmove+0x16>

  return dst;
}
    80001008:	6422                	ld	s0,8(sp)
    8000100a:	0141                	addi	sp,sp,16
    8000100c:	8082                	ret
  if(s < d && s + n > d){
    8000100e:	02061693          	slli	a3,a2,0x20
    80001012:	9281                	srli	a3,a3,0x20
    80001014:	00d58733          	add	a4,a1,a3
    80001018:	fce57be3          	bgeu	a0,a4,80000fee <memmove+0xc>
    d += n;
    8000101c:	96aa                	add	a3,a3,a0
    while(n-- > 0)
    8000101e:	fff6079b          	addiw	a5,a2,-1
    80001022:	1782                	slli	a5,a5,0x20
    80001024:	9381                	srli	a5,a5,0x20
    80001026:	fff7c793          	not	a5,a5
    8000102a:	97ba                	add	a5,a5,a4
      *--d = *--s;
    8000102c:	177d                	addi	a4,a4,-1
    8000102e:	16fd                	addi	a3,a3,-1
    80001030:	00074603          	lbu	a2,0(a4)
    80001034:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80001038:	fee79ae3          	bne	a5,a4,8000102c <memmove+0x4a>
    8000103c:	b7f1                	j	80001008 <memmove+0x26>

000000008000103e <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    8000103e:	1141                	addi	sp,sp,-16
    80001040:	e406                	sd	ra,8(sp)
    80001042:	e022                	sd	s0,0(sp)
    80001044:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
    80001046:	00000097          	auipc	ra,0x0
    8000104a:	f9c080e7          	jalr	-100(ra) # 80000fe2 <memmove>
}
    8000104e:	60a2                	ld	ra,8(sp)
    80001050:	6402                	ld	s0,0(sp)
    80001052:	0141                	addi	sp,sp,16
    80001054:	8082                	ret

0000000080001056 <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80001056:	1141                	addi	sp,sp,-16
    80001058:	e422                	sd	s0,8(sp)
    8000105a:	0800                	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    8000105c:	ce11                	beqz	a2,80001078 <strncmp+0x22>
    8000105e:	00054783          	lbu	a5,0(a0)
    80001062:	cf89                	beqz	a5,8000107c <strncmp+0x26>
    80001064:	0005c703          	lbu	a4,0(a1)
    80001068:	00f71a63          	bne	a4,a5,8000107c <strncmp+0x26>
    n--, p++, q++;
    8000106c:	367d                	addiw	a2,a2,-1
    8000106e:	0505                	addi	a0,a0,1
    80001070:	0585                	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80001072:	f675                	bnez	a2,8000105e <strncmp+0x8>
  if(n == 0)
    return 0;
    80001074:	4501                	li	a0,0
    80001076:	a809                	j	80001088 <strncmp+0x32>
    80001078:	4501                	li	a0,0
    8000107a:	a039                	j	80001088 <strncmp+0x32>
  if(n == 0)
    8000107c:	ca09                	beqz	a2,8000108e <strncmp+0x38>
  return (uchar)*p - (uchar)*q;
    8000107e:	00054503          	lbu	a0,0(a0)
    80001082:	0005c783          	lbu	a5,0(a1)
    80001086:	9d1d                	subw	a0,a0,a5
}
    80001088:	6422                	ld	s0,8(sp)
    8000108a:	0141                	addi	sp,sp,16
    8000108c:	8082                	ret
    return 0;
    8000108e:	4501                	li	a0,0
    80001090:	bfe5                	j	80001088 <strncmp+0x32>

0000000080001092 <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    80001092:	1141                	addi	sp,sp,-16
    80001094:	e422                	sd	s0,8(sp)
    80001096:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    80001098:	872a                	mv	a4,a0
    8000109a:	8832                	mv	a6,a2
    8000109c:	367d                	addiw	a2,a2,-1
    8000109e:	01005963          	blez	a6,800010b0 <strncpy+0x1e>
    800010a2:	0705                	addi	a4,a4,1
    800010a4:	0005c783          	lbu	a5,0(a1)
    800010a8:	fef70fa3          	sb	a5,-1(a4)
    800010ac:	0585                	addi	a1,a1,1
    800010ae:	f7f5                	bnez	a5,8000109a <strncpy+0x8>
    ;
  while(n-- > 0)
    800010b0:	86ba                	mv	a3,a4
    800010b2:	00c05c63          	blez	a2,800010ca <strncpy+0x38>
    *s++ = 0;
    800010b6:	0685                	addi	a3,a3,1
    800010b8:	fe068fa3          	sb	zero,-1(a3)
  while(n-- > 0)
    800010bc:	fff6c793          	not	a5,a3
    800010c0:	9fb9                	addw	a5,a5,a4
    800010c2:	010787bb          	addw	a5,a5,a6
    800010c6:	fef048e3          	bgtz	a5,800010b6 <strncpy+0x24>
  return os;
}
    800010ca:	6422                	ld	s0,8(sp)
    800010cc:	0141                	addi	sp,sp,16
    800010ce:	8082                	ret

00000000800010d0 <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    800010d0:	1141                	addi	sp,sp,-16
    800010d2:	e422                	sd	s0,8(sp)
    800010d4:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    800010d6:	02c05363          	blez	a2,800010fc <safestrcpy+0x2c>
    800010da:	fff6069b          	addiw	a3,a2,-1
    800010de:	1682                	slli	a3,a3,0x20
    800010e0:	9281                	srli	a3,a3,0x20
    800010e2:	96ae                	add	a3,a3,a1
    800010e4:	87aa                	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    800010e6:	00d58963          	beq	a1,a3,800010f8 <safestrcpy+0x28>
    800010ea:	0585                	addi	a1,a1,1
    800010ec:	0785                	addi	a5,a5,1
    800010ee:	fff5c703          	lbu	a4,-1(a1)
    800010f2:	fee78fa3          	sb	a4,-1(a5)
    800010f6:	fb65                	bnez	a4,800010e6 <safestrcpy+0x16>
    ;
  *s = 0;
    800010f8:	00078023          	sb	zero,0(a5)
  return os;
}
    800010fc:	6422                	ld	s0,8(sp)
    800010fe:	0141                	addi	sp,sp,16
    80001100:	8082                	ret

0000000080001102 <strlen>:

int
strlen(const char *s)
{
    80001102:	1141                	addi	sp,sp,-16
    80001104:	e422                	sd	s0,8(sp)
    80001106:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    80001108:	00054783          	lbu	a5,0(a0)
    8000110c:	cf91                	beqz	a5,80001128 <strlen+0x26>
    8000110e:	0505                	addi	a0,a0,1
    80001110:	87aa                	mv	a5,a0
    80001112:	4685                	li	a3,1
    80001114:	9e89                	subw	a3,a3,a0
    80001116:	00f6853b          	addw	a0,a3,a5
    8000111a:	0785                	addi	a5,a5,1
    8000111c:	fff7c703          	lbu	a4,-1(a5)
    80001120:	fb7d                	bnez	a4,80001116 <strlen+0x14>
    ;
  return n;
}
    80001122:	6422                	ld	s0,8(sp)
    80001124:	0141                	addi	sp,sp,16
    80001126:	8082                	ret
  for(n = 0; s[n]; n++)
    80001128:	4501                	li	a0,0
    8000112a:	bfe5                	j	80001122 <strlen+0x20>

000000008000112c <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    8000112c:	1141                	addi	sp,sp,-16
    8000112e:	e406                	sd	ra,8(sp)
    80001130:	e022                	sd	s0,0(sp)
    80001132:	0800                	addi	s0,sp,16
  if(cpuid() == 0){
    80001134:	00001097          	auipc	ra,0x1
    80001138:	c1e080e7          	jalr	-994(ra) # 80001d52 <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    8000113c:	00007717          	auipc	a4,0x7
    80001140:	7cc70713          	addi	a4,a4,1996 # 80008908 <started>
  if(cpuid() == 0){
    80001144:	c139                	beqz	a0,8000118a <main+0x5e>
    while(started == 0)
    80001146:	431c                	lw	a5,0(a4)
    80001148:	2781                	sext.w	a5,a5
    8000114a:	dff5                	beqz	a5,80001146 <main+0x1a>
      ;
    __sync_synchronize();
    8000114c:	0ff0000f          	fence
    printf("hart %d starting\n", cpuid());
    80001150:	00001097          	auipc	ra,0x1
    80001154:	c02080e7          	jalr	-1022(ra) # 80001d52 <cpuid>
    80001158:	85aa                	mv	a1,a0
    8000115a:	00007517          	auipc	a0,0x7
    8000115e:	f7e50513          	addi	a0,a0,-130 # 800080d8 <digits+0x98>
    80001162:	fffff097          	auipc	ra,0xfffff
    80001166:	426080e7          	jalr	1062(ra) # 80000588 <printf>
    kvminithart();    // turn on paging
    8000116a:	00000097          	auipc	ra,0x0
    8000116e:	0d8080e7          	jalr	216(ra) # 80001242 <kvminithart>
    trapinithart();   // install kernel trap vector
    80001172:	00002097          	auipc	ra,0x2
    80001176:	a72080e7          	jalr	-1422(ra) # 80002be4 <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    8000117a:	00005097          	auipc	ra,0x5
    8000117e:	0f6080e7          	jalr	246(ra) # 80006270 <plicinithart>
  }

  scheduler();        
    80001182:	00001097          	auipc	ra,0x1
    80001186:	106080e7          	jalr	262(ra) # 80002288 <scheduler>
    consoleinit();
    8000118a:	fffff097          	auipc	ra,0xfffff
    8000118e:	2c6080e7          	jalr	710(ra) # 80000450 <consoleinit>
    printfinit();
    80001192:	fffff097          	auipc	ra,0xfffff
    80001196:	5d6080e7          	jalr	1494(ra) # 80000768 <printfinit>
    printf("\n");
    8000119a:	00007517          	auipc	a0,0x7
    8000119e:	f4e50513          	addi	a0,a0,-178 # 800080e8 <digits+0xa8>
    800011a2:	fffff097          	auipc	ra,0xfffff
    800011a6:	3e6080e7          	jalr	998(ra) # 80000588 <printf>
    printf("xv6 kernel is booting\n");
    800011aa:	00007517          	auipc	a0,0x7
    800011ae:	f1650513          	addi	a0,a0,-234 # 800080c0 <digits+0x80>
    800011b2:	fffff097          	auipc	ra,0xfffff
    800011b6:	3d6080e7          	jalr	982(ra) # 80000588 <printf>
    printf("\n");
    800011ba:	00007517          	auipc	a0,0x7
    800011be:	f2e50513          	addi	a0,a0,-210 # 800080e8 <digits+0xa8>
    800011c2:	fffff097          	auipc	ra,0xfffff
    800011c6:	3c6080e7          	jalr	966(ra) # 80000588 <printf>
    kinit();         // physical page allocator
    800011ca:	00000097          	auipc	ra,0x0
    800011ce:	924080e7          	jalr	-1756(ra) # 80000aee <kinit>
    kvminit();       // create kernel page table
    800011d2:	00000097          	auipc	ra,0x0
    800011d6:	326080e7          	jalr	806(ra) # 800014f8 <kvminit>
    kvminithart();   // turn on paging
    800011da:	00000097          	auipc	ra,0x0
    800011de:	068080e7          	jalr	104(ra) # 80001242 <kvminithart>
    procinit();      // process table
    800011e2:	00001097          	auipc	ra,0x1
    800011e6:	abc080e7          	jalr	-1348(ra) # 80001c9e <procinit>
    trapinit();      // trap vectors
    800011ea:	00002097          	auipc	ra,0x2
    800011ee:	9d2080e7          	jalr	-1582(ra) # 80002bbc <trapinit>
    trapinithart();  // install kernel trap vector
    800011f2:	00002097          	auipc	ra,0x2
    800011f6:	9f2080e7          	jalr	-1550(ra) # 80002be4 <trapinithart>
    plicinit();      // set up interrupt controller
    800011fa:	00005097          	auipc	ra,0x5
    800011fe:	060080e7          	jalr	96(ra) # 8000625a <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    80001202:	00005097          	auipc	ra,0x5
    80001206:	06e080e7          	jalr	110(ra) # 80006270 <plicinithart>
    binit();         // buffer cache
    8000120a:	00002097          	auipc	ra,0x2
    8000120e:	218080e7          	jalr	536(ra) # 80003422 <binit>
    iinit();         // inode table
    80001212:	00003097          	auipc	ra,0x3
    80001216:	8bc080e7          	jalr	-1860(ra) # 80003ace <iinit>
    fileinit();      // file table
    8000121a:	00004097          	auipc	ra,0x4
    8000121e:	85a080e7          	jalr	-1958(ra) # 80004a74 <fileinit>
    virtio_disk_init(); // emulated hard disk
    80001222:	00005097          	auipc	ra,0x5
    80001226:	156080e7          	jalr	342(ra) # 80006378 <virtio_disk_init>
    userinit();      // first user process
    8000122a:	00001097          	auipc	ra,0x1
    8000122e:	e40080e7          	jalr	-448(ra) # 8000206a <userinit>
    __sync_synchronize();
    80001232:	0ff0000f          	fence
    started = 1;
    80001236:	4785                	li	a5,1
    80001238:	00007717          	auipc	a4,0x7
    8000123c:	6cf72823          	sw	a5,1744(a4) # 80008908 <started>
    80001240:	b789                	j	80001182 <main+0x56>

0000000080001242 <kvminithart>:

// Switch h/w page table register to the kernel's page table,
// and enable paging.
void
kvminithart()
{
    80001242:	1141                	addi	sp,sp,-16
    80001244:	e422                	sd	s0,8(sp)
    80001246:	0800                	addi	s0,sp,16
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80001248:	12000073          	sfence.vma
  // wait for any previous writes to the page table memory to finish.
  sfence_vma();

  w_satp(MAKE_SATP(kernel_pagetable));
    8000124c:	00007797          	auipc	a5,0x7
    80001250:	6c47b783          	ld	a5,1732(a5) # 80008910 <kernel_pagetable>
    80001254:	83b1                	srli	a5,a5,0xc
    80001256:	577d                	li	a4,-1
    80001258:	177e                	slli	a4,a4,0x3f
    8000125a:	8fd9                	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    8000125c:	18079073          	csrw	satp,a5
  asm volatile("sfence.vma zero, zero");
    80001260:	12000073          	sfence.vma

  // flush stale entries from the TLB.
  sfence_vma();
}
    80001264:	6422                	ld	s0,8(sp)
    80001266:	0141                	addi	sp,sp,16
    80001268:	8082                	ret

000000008000126a <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    8000126a:	7139                	addi	sp,sp,-64
    8000126c:	fc06                	sd	ra,56(sp)
    8000126e:	f822                	sd	s0,48(sp)
    80001270:	f426                	sd	s1,40(sp)
    80001272:	f04a                	sd	s2,32(sp)
    80001274:	ec4e                	sd	s3,24(sp)
    80001276:	e852                	sd	s4,16(sp)
    80001278:	e456                	sd	s5,8(sp)
    8000127a:	e05a                	sd	s6,0(sp)
    8000127c:	0080                	addi	s0,sp,64
    8000127e:	84aa                	mv	s1,a0
    80001280:	89ae                	mv	s3,a1
    80001282:	8ab2                	mv	s5,a2
  if(va >= MAXVA)
    80001284:	57fd                	li	a5,-1
    80001286:	83e9                	srli	a5,a5,0x1a
    80001288:	4a79                	li	s4,30
    panic("walk");

  for(int level = 2; level > 0; level--) {
    8000128a:	4b31                	li	s6,12
  if(va >= MAXVA)
    8000128c:	04b7f263          	bgeu	a5,a1,800012d0 <walk+0x66>
    panic("walk");
    80001290:	00007517          	auipc	a0,0x7
    80001294:	e6050513          	addi	a0,a0,-416 # 800080f0 <digits+0xb0>
    80001298:	fffff097          	auipc	ra,0xfffff
    8000129c:	2a6080e7          	jalr	678(ra) # 8000053e <panic>
    pte_t *pte = &pagetable[PX(level, va)];
    if(*pte & PTE_V) {
      pagetable = (pagetable_t)PTE2PA(*pte);
    } else {
      if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
    800012a0:	060a8663          	beqz	s5,8000130c <walk+0xa2>
    800012a4:	00000097          	auipc	ra,0x0
    800012a8:	89c080e7          	jalr	-1892(ra) # 80000b40 <kalloc>
    800012ac:	84aa                	mv	s1,a0
    800012ae:	c529                	beqz	a0,800012f8 <walk+0x8e>
        return 0;
      memset(pagetable, 0, PGSIZE);
    800012b0:	6605                	lui	a2,0x1
    800012b2:	4581                	li	a1,0
    800012b4:	00000097          	auipc	ra,0x0
    800012b8:	cd2080e7          	jalr	-814(ra) # 80000f86 <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    800012bc:	00c4d793          	srli	a5,s1,0xc
    800012c0:	07aa                	slli	a5,a5,0xa
    800012c2:	0017e793          	ori	a5,a5,1
    800012c6:	00f93023          	sd	a5,0(s2)
  for(int level = 2; level > 0; level--) {
    800012ca:	3a5d                	addiw	s4,s4,-9
    800012cc:	036a0063          	beq	s4,s6,800012ec <walk+0x82>
    pte_t *pte = &pagetable[PX(level, va)];
    800012d0:	0149d933          	srl	s2,s3,s4
    800012d4:	1ff97913          	andi	s2,s2,511
    800012d8:	090e                	slli	s2,s2,0x3
    800012da:	9926                	add	s2,s2,s1
    if(*pte & PTE_V) {
    800012dc:	00093483          	ld	s1,0(s2)
    800012e0:	0014f793          	andi	a5,s1,1
    800012e4:	dfd5                	beqz	a5,800012a0 <walk+0x36>
      pagetable = (pagetable_t)PTE2PA(*pte);
    800012e6:	80a9                	srli	s1,s1,0xa
    800012e8:	04b2                	slli	s1,s1,0xc
    800012ea:	b7c5                	j	800012ca <walk+0x60>
    }
  }
  return &pagetable[PX(0, va)];
    800012ec:	00c9d513          	srli	a0,s3,0xc
    800012f0:	1ff57513          	andi	a0,a0,511
    800012f4:	050e                	slli	a0,a0,0x3
    800012f6:	9526                	add	a0,a0,s1
}
    800012f8:	70e2                	ld	ra,56(sp)
    800012fa:	7442                	ld	s0,48(sp)
    800012fc:	74a2                	ld	s1,40(sp)
    800012fe:	7902                	ld	s2,32(sp)
    80001300:	69e2                	ld	s3,24(sp)
    80001302:	6a42                	ld	s4,16(sp)
    80001304:	6aa2                	ld	s5,8(sp)
    80001306:	6b02                	ld	s6,0(sp)
    80001308:	6121                	addi	sp,sp,64
    8000130a:	8082                	ret
        return 0;
    8000130c:	4501                	li	a0,0
    8000130e:	b7ed                	j	800012f8 <walk+0x8e>

0000000080001310 <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if(va >= MAXVA)
    80001310:	57fd                	li	a5,-1
    80001312:	83e9                	srli	a5,a5,0x1a
    80001314:	00b7f463          	bgeu	a5,a1,8000131c <walkaddr+0xc>
    return 0;
    80001318:	4501                	li	a0,0
    return 0;
  if((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    8000131a:	8082                	ret
{
    8000131c:	1141                	addi	sp,sp,-16
    8000131e:	e406                	sd	ra,8(sp)
    80001320:	e022                	sd	s0,0(sp)
    80001322:	0800                	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    80001324:	4601                	li	a2,0
    80001326:	00000097          	auipc	ra,0x0
    8000132a:	f44080e7          	jalr	-188(ra) # 8000126a <walk>
  if(pte == 0)
    8000132e:	c105                	beqz	a0,8000134e <walkaddr+0x3e>
  if((*pte & PTE_V) == 0)
    80001330:	611c                	ld	a5,0(a0)
  if((*pte & PTE_U) == 0)
    80001332:	0117f693          	andi	a3,a5,17
    80001336:	4745                	li	a4,17
    return 0;
    80001338:	4501                	li	a0,0
  if((*pte & PTE_U) == 0)
    8000133a:	00e68663          	beq	a3,a4,80001346 <walkaddr+0x36>
}
    8000133e:	60a2                	ld	ra,8(sp)
    80001340:	6402                	ld	s0,0(sp)
    80001342:	0141                	addi	sp,sp,16
    80001344:	8082                	ret
  pa = PTE2PA(*pte);
    80001346:	00a7d513          	srli	a0,a5,0xa
    8000134a:	0532                	slli	a0,a0,0xc
  return pa;
    8000134c:	bfcd                	j	8000133e <walkaddr+0x2e>
    return 0;
    8000134e:	4501                	li	a0,0
    80001350:	b7fd                	j	8000133e <walkaddr+0x2e>

0000000080001352 <mappages>:
// physical addresses starting at pa. va and size might not
// be page-aligned. Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int
mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    80001352:	715d                	addi	sp,sp,-80
    80001354:	e486                	sd	ra,72(sp)
    80001356:	e0a2                	sd	s0,64(sp)
    80001358:	fc26                	sd	s1,56(sp)
    8000135a:	f84a                	sd	s2,48(sp)
    8000135c:	f44e                	sd	s3,40(sp)
    8000135e:	f052                	sd	s4,32(sp)
    80001360:	ec56                	sd	s5,24(sp)
    80001362:	e85a                	sd	s6,16(sp)
    80001364:	e45e                	sd	s7,8(sp)
    80001366:	0880                	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if(size == 0)
    80001368:	c639                	beqz	a2,800013b6 <mappages+0x64>
    8000136a:	8aaa                	mv	s5,a0
    8000136c:	8b3a                	mv	s6,a4
    panic("mappages: size");
  
  a = PGROUNDDOWN(va);
    8000136e:	77fd                	lui	a5,0xfffff
    80001370:	00f5fa33          	and	s4,a1,a5
  last = PGROUNDDOWN(va + size - 1);
    80001374:	15fd                	addi	a1,a1,-1
    80001376:	00c589b3          	add	s3,a1,a2
    8000137a:	00f9f9b3          	and	s3,s3,a5
  a = PGROUNDDOWN(va);
    8000137e:	8952                	mv	s2,s4
    80001380:	41468a33          	sub	s4,a3,s4
    if(*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if(a == last)
      break;
    a += PGSIZE;
    80001384:	6b85                	lui	s7,0x1
    80001386:	012a04b3          	add	s1,s4,s2
    if((pte = walk(pagetable, a, 1)) == 0)
    8000138a:	4605                	li	a2,1
    8000138c:	85ca                	mv	a1,s2
    8000138e:	8556                	mv	a0,s5
    80001390:	00000097          	auipc	ra,0x0
    80001394:	eda080e7          	jalr	-294(ra) # 8000126a <walk>
    80001398:	cd1d                	beqz	a0,800013d6 <mappages+0x84>
    if(*pte & PTE_V)
    8000139a:	611c                	ld	a5,0(a0)
    8000139c:	8b85                	andi	a5,a5,1
    8000139e:	e785                	bnez	a5,800013c6 <mappages+0x74>
    *pte = PA2PTE(pa) | perm | PTE_V;
    800013a0:	80b1                	srli	s1,s1,0xc
    800013a2:	04aa                	slli	s1,s1,0xa
    800013a4:	0164e4b3          	or	s1,s1,s6
    800013a8:	0014e493          	ori	s1,s1,1
    800013ac:	e104                	sd	s1,0(a0)
    if(a == last)
    800013ae:	05390063          	beq	s2,s3,800013ee <mappages+0x9c>
    a += PGSIZE;
    800013b2:	995e                	add	s2,s2,s7
    if((pte = walk(pagetable, a, 1)) == 0)
    800013b4:	bfc9                	j	80001386 <mappages+0x34>
    panic("mappages: size");
    800013b6:	00007517          	auipc	a0,0x7
    800013ba:	d4250513          	addi	a0,a0,-702 # 800080f8 <digits+0xb8>
    800013be:	fffff097          	auipc	ra,0xfffff
    800013c2:	180080e7          	jalr	384(ra) # 8000053e <panic>
      panic("mappages: remap");
    800013c6:	00007517          	auipc	a0,0x7
    800013ca:	d4250513          	addi	a0,a0,-702 # 80008108 <digits+0xc8>
    800013ce:	fffff097          	auipc	ra,0xfffff
    800013d2:	170080e7          	jalr	368(ra) # 8000053e <panic>
      return -1;
    800013d6:	557d                	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    800013d8:	60a6                	ld	ra,72(sp)
    800013da:	6406                	ld	s0,64(sp)
    800013dc:	74e2                	ld	s1,56(sp)
    800013de:	7942                	ld	s2,48(sp)
    800013e0:	79a2                	ld	s3,40(sp)
    800013e2:	7a02                	ld	s4,32(sp)
    800013e4:	6ae2                	ld	s5,24(sp)
    800013e6:	6b42                	ld	s6,16(sp)
    800013e8:	6ba2                	ld	s7,8(sp)
    800013ea:	6161                	addi	sp,sp,80
    800013ec:	8082                	ret
  return 0;
    800013ee:	4501                	li	a0,0
    800013f0:	b7e5                	j	800013d8 <mappages+0x86>

00000000800013f2 <kvmmap>:
{
    800013f2:	1141                	addi	sp,sp,-16
    800013f4:	e406                	sd	ra,8(sp)
    800013f6:	e022                	sd	s0,0(sp)
    800013f8:	0800                	addi	s0,sp,16
    800013fa:	87b6                	mv	a5,a3
  if(mappages(kpgtbl, va, sz, pa, perm) != 0)
    800013fc:	86b2                	mv	a3,a2
    800013fe:	863e                	mv	a2,a5
    80001400:	00000097          	auipc	ra,0x0
    80001404:	f52080e7          	jalr	-174(ra) # 80001352 <mappages>
    80001408:	e509                	bnez	a0,80001412 <kvmmap+0x20>
}
    8000140a:	60a2                	ld	ra,8(sp)
    8000140c:	6402                	ld	s0,0(sp)
    8000140e:	0141                	addi	sp,sp,16
    80001410:	8082                	ret
    panic("kvmmap");
    80001412:	00007517          	auipc	a0,0x7
    80001416:	d0650513          	addi	a0,a0,-762 # 80008118 <digits+0xd8>
    8000141a:	fffff097          	auipc	ra,0xfffff
    8000141e:	124080e7          	jalr	292(ra) # 8000053e <panic>

0000000080001422 <kvmmake>:
{
    80001422:	1101                	addi	sp,sp,-32
    80001424:	ec06                	sd	ra,24(sp)
    80001426:	e822                	sd	s0,16(sp)
    80001428:	e426                	sd	s1,8(sp)
    8000142a:	e04a                	sd	s2,0(sp)
    8000142c:	1000                	addi	s0,sp,32
  kpgtbl = (pagetable_t) kalloc();
    8000142e:	fffff097          	auipc	ra,0xfffff
    80001432:	712080e7          	jalr	1810(ra) # 80000b40 <kalloc>
    80001436:	84aa                	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    80001438:	6605                	lui	a2,0x1
    8000143a:	4581                	li	a1,0
    8000143c:	00000097          	auipc	ra,0x0
    80001440:	b4a080e7          	jalr	-1206(ra) # 80000f86 <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    80001444:	4719                	li	a4,6
    80001446:	6685                	lui	a3,0x1
    80001448:	10000637          	lui	a2,0x10000
    8000144c:	100005b7          	lui	a1,0x10000
    80001450:	8526                	mv	a0,s1
    80001452:	00000097          	auipc	ra,0x0
    80001456:	fa0080e7          	jalr	-96(ra) # 800013f2 <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    8000145a:	4719                	li	a4,6
    8000145c:	6685                	lui	a3,0x1
    8000145e:	10001637          	lui	a2,0x10001
    80001462:	100015b7          	lui	a1,0x10001
    80001466:	8526                	mv	a0,s1
    80001468:	00000097          	auipc	ra,0x0
    8000146c:	f8a080e7          	jalr	-118(ra) # 800013f2 <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W);
    80001470:	4719                	li	a4,6
    80001472:	004006b7          	lui	a3,0x400
    80001476:	0c000637          	lui	a2,0xc000
    8000147a:	0c0005b7          	lui	a1,0xc000
    8000147e:	8526                	mv	a0,s1
    80001480:	00000097          	auipc	ra,0x0
    80001484:	f72080e7          	jalr	-142(ra) # 800013f2 <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    80001488:	00007917          	auipc	s2,0x7
    8000148c:	b7890913          	addi	s2,s2,-1160 # 80008000 <etext>
    80001490:	4729                	li	a4,10
    80001492:	80007697          	auipc	a3,0x80007
    80001496:	b6e68693          	addi	a3,a3,-1170 # 8000 <_entry-0x7fff8000>
    8000149a:	4605                	li	a2,1
    8000149c:	067e                	slli	a2,a2,0x1f
    8000149e:	85b2                	mv	a1,a2
    800014a0:	8526                	mv	a0,s1
    800014a2:	00000097          	auipc	ra,0x0
    800014a6:	f50080e7          	jalr	-176(ra) # 800013f2 <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    800014aa:	4719                	li	a4,6
    800014ac:	46c5                	li	a3,17
    800014ae:	06ee                	slli	a3,a3,0x1b
    800014b0:	412686b3          	sub	a3,a3,s2
    800014b4:	864a                	mv	a2,s2
    800014b6:	85ca                	mv	a1,s2
    800014b8:	8526                	mv	a0,s1
    800014ba:	00000097          	auipc	ra,0x0
    800014be:	f38080e7          	jalr	-200(ra) # 800013f2 <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    800014c2:	4729                	li	a4,10
    800014c4:	6685                	lui	a3,0x1
    800014c6:	00006617          	auipc	a2,0x6
    800014ca:	b3a60613          	addi	a2,a2,-1222 # 80007000 <_trampoline>
    800014ce:	040005b7          	lui	a1,0x4000
    800014d2:	15fd                	addi	a1,a1,-1
    800014d4:	05b2                	slli	a1,a1,0xc
    800014d6:	8526                	mv	a0,s1
    800014d8:	00000097          	auipc	ra,0x0
    800014dc:	f1a080e7          	jalr	-230(ra) # 800013f2 <kvmmap>
  proc_mapstacks(kpgtbl);
    800014e0:	8526                	mv	a0,s1
    800014e2:	00000097          	auipc	ra,0x0
    800014e6:	726080e7          	jalr	1830(ra) # 80001c08 <proc_mapstacks>
}
    800014ea:	8526                	mv	a0,s1
    800014ec:	60e2                	ld	ra,24(sp)
    800014ee:	6442                	ld	s0,16(sp)
    800014f0:	64a2                	ld	s1,8(sp)
    800014f2:	6902                	ld	s2,0(sp)
    800014f4:	6105                	addi	sp,sp,32
    800014f6:	8082                	ret

00000000800014f8 <kvminit>:
{
    800014f8:	1141                	addi	sp,sp,-16
    800014fa:	e406                	sd	ra,8(sp)
    800014fc:	e022                	sd	s0,0(sp)
    800014fe:	0800                	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    80001500:	00000097          	auipc	ra,0x0
    80001504:	f22080e7          	jalr	-222(ra) # 80001422 <kvmmake>
    80001508:	00007797          	auipc	a5,0x7
    8000150c:	40a7b423          	sd	a0,1032(a5) # 80008910 <kernel_pagetable>
}
    80001510:	60a2                	ld	ra,8(sp)
    80001512:	6402                	ld	s0,0(sp)
    80001514:	0141                	addi	sp,sp,16
    80001516:	8082                	ret

0000000080001518 <uvmunmap>:
// Remove npages of mappings starting from va. va must be
// page-aligned. The mappings must exist.
// Optionally free the physical memory.
void
uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    80001518:	715d                	addi	sp,sp,-80
    8000151a:	e486                	sd	ra,72(sp)
    8000151c:	e0a2                	sd	s0,64(sp)
    8000151e:	fc26                	sd	s1,56(sp)
    80001520:	f84a                	sd	s2,48(sp)
    80001522:	f44e                	sd	s3,40(sp)
    80001524:	f052                	sd	s4,32(sp)
    80001526:	ec56                	sd	s5,24(sp)
    80001528:	e85a                	sd	s6,16(sp)
    8000152a:	e45e                	sd	s7,8(sp)
    8000152c:	0880                	addi	s0,sp,80
  uint64 a;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    8000152e:	03459793          	slli	a5,a1,0x34
    80001532:	e795                	bnez	a5,8000155e <uvmunmap+0x46>
    80001534:	8a2a                	mv	s4,a0
    80001536:	892e                	mv	s2,a1
    80001538:	8ab6                	mv	s5,a3
    panic("uvmunmap: not aligned");

  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    8000153a:	0632                	slli	a2,a2,0xc
    8000153c:	00b609b3          	add	s3,a2,a1
    if((pte = walk(pagetable, a, 0)) == 0)
      panic("uvmunmap: walk");
    if((*pte & PTE_V) == 0)
      panic("uvmunmap: not mapped");
    if(PTE_FLAGS(*pte) == PTE_V)
    80001540:	4b85                	li	s7,1
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    80001542:	6b05                	lui	s6,0x1
    80001544:	0735e263          	bltu	a1,s3,800015a8 <uvmunmap+0x90>
      uint64 pa = PTE2PA(*pte);
      kfree((void*)pa);
    }
    *pte = 0;
  }
}
    80001548:	60a6                	ld	ra,72(sp)
    8000154a:	6406                	ld	s0,64(sp)
    8000154c:	74e2                	ld	s1,56(sp)
    8000154e:	7942                	ld	s2,48(sp)
    80001550:	79a2                	ld	s3,40(sp)
    80001552:	7a02                	ld	s4,32(sp)
    80001554:	6ae2                	ld	s5,24(sp)
    80001556:	6b42                	ld	s6,16(sp)
    80001558:	6ba2                	ld	s7,8(sp)
    8000155a:	6161                	addi	sp,sp,80
    8000155c:	8082                	ret
    panic("uvmunmap: not aligned");
    8000155e:	00007517          	auipc	a0,0x7
    80001562:	bc250513          	addi	a0,a0,-1086 # 80008120 <digits+0xe0>
    80001566:	fffff097          	auipc	ra,0xfffff
    8000156a:	fd8080e7          	jalr	-40(ra) # 8000053e <panic>
      panic("uvmunmap: walk");
    8000156e:	00007517          	auipc	a0,0x7
    80001572:	bca50513          	addi	a0,a0,-1078 # 80008138 <digits+0xf8>
    80001576:	fffff097          	auipc	ra,0xfffff
    8000157a:	fc8080e7          	jalr	-56(ra) # 8000053e <panic>
      panic("uvmunmap: not mapped");
    8000157e:	00007517          	auipc	a0,0x7
    80001582:	bca50513          	addi	a0,a0,-1078 # 80008148 <digits+0x108>
    80001586:	fffff097          	auipc	ra,0xfffff
    8000158a:	fb8080e7          	jalr	-72(ra) # 8000053e <panic>
      panic("uvmunmap: not a leaf");
    8000158e:	00007517          	auipc	a0,0x7
    80001592:	bd250513          	addi	a0,a0,-1070 # 80008160 <digits+0x120>
    80001596:	fffff097          	auipc	ra,0xfffff
    8000159a:	fa8080e7          	jalr	-88(ra) # 8000053e <panic>
    *pte = 0;
    8000159e:	0004b023          	sd	zero,0(s1)
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800015a2:	995a                	add	s2,s2,s6
    800015a4:	fb3972e3          	bgeu	s2,s3,80001548 <uvmunmap+0x30>
    if((pte = walk(pagetable, a, 0)) == 0)
    800015a8:	4601                	li	a2,0
    800015aa:	85ca                	mv	a1,s2
    800015ac:	8552                	mv	a0,s4
    800015ae:	00000097          	auipc	ra,0x0
    800015b2:	cbc080e7          	jalr	-836(ra) # 8000126a <walk>
    800015b6:	84aa                	mv	s1,a0
    800015b8:	d95d                	beqz	a0,8000156e <uvmunmap+0x56>
    if((*pte & PTE_V) == 0)
    800015ba:	6108                	ld	a0,0(a0)
    800015bc:	00157793          	andi	a5,a0,1
    800015c0:	dfdd                	beqz	a5,8000157e <uvmunmap+0x66>
    if(PTE_FLAGS(*pte) == PTE_V)
    800015c2:	3ff57793          	andi	a5,a0,1023
    800015c6:	fd7784e3          	beq	a5,s7,8000158e <uvmunmap+0x76>
    if(do_free){
    800015ca:	fc0a8ae3          	beqz	s5,8000159e <uvmunmap+0x86>
      uint64 pa = PTE2PA(*pte);
    800015ce:	8129                	srli	a0,a0,0xa
      kfree((void*)pa);
    800015d0:	0532                	slli	a0,a0,0xc
    800015d2:	fffff097          	auipc	ra,0xfffff
    800015d6:	418080e7          	jalr	1048(ra) # 800009ea <kfree>
    800015da:	b7d1                	j	8000159e <uvmunmap+0x86>

00000000800015dc <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    800015dc:	1101                	addi	sp,sp,-32
    800015de:	ec06                	sd	ra,24(sp)
    800015e0:	e822                	sd	s0,16(sp)
    800015e2:	e426                	sd	s1,8(sp)
    800015e4:	1000                	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t) kalloc();
    800015e6:	fffff097          	auipc	ra,0xfffff
    800015ea:	55a080e7          	jalr	1370(ra) # 80000b40 <kalloc>
    800015ee:	84aa                	mv	s1,a0
  if(pagetable == 0)
    800015f0:	c519                	beqz	a0,800015fe <uvmcreate+0x22>
    return 0;
  memset(pagetable, 0, PGSIZE);
    800015f2:	6605                	lui	a2,0x1
    800015f4:	4581                	li	a1,0
    800015f6:	00000097          	auipc	ra,0x0
    800015fa:	990080e7          	jalr	-1648(ra) # 80000f86 <memset>
  return pagetable;
}
    800015fe:	8526                	mv	a0,s1
    80001600:	60e2                	ld	ra,24(sp)
    80001602:	6442                	ld	s0,16(sp)
    80001604:	64a2                	ld	s1,8(sp)
    80001606:	6105                	addi	sp,sp,32
    80001608:	8082                	ret

000000008000160a <uvmfirst>:
// Load the user initcode into address 0 of pagetable,
// for the very first process.
// sz must be less than a page.
void
uvmfirst(pagetable_t pagetable, uchar *src, uint sz)
{
    8000160a:	7179                	addi	sp,sp,-48
    8000160c:	f406                	sd	ra,40(sp)
    8000160e:	f022                	sd	s0,32(sp)
    80001610:	ec26                	sd	s1,24(sp)
    80001612:	e84a                	sd	s2,16(sp)
    80001614:	e44e                	sd	s3,8(sp)
    80001616:	e052                	sd	s4,0(sp)
    80001618:	1800                	addi	s0,sp,48
  char *mem;

  if(sz >= PGSIZE)
    8000161a:	6785                	lui	a5,0x1
    8000161c:	04f67863          	bgeu	a2,a5,8000166c <uvmfirst+0x62>
    80001620:	8a2a                	mv	s4,a0
    80001622:	89ae                	mv	s3,a1
    80001624:	84b2                	mv	s1,a2
    panic("uvmfirst: more than a page");
  mem = kalloc();
    80001626:	fffff097          	auipc	ra,0xfffff
    8000162a:	51a080e7          	jalr	1306(ra) # 80000b40 <kalloc>
    8000162e:	892a                	mv	s2,a0
  memset(mem, 0, PGSIZE);
    80001630:	6605                	lui	a2,0x1
    80001632:	4581                	li	a1,0
    80001634:	00000097          	auipc	ra,0x0
    80001638:	952080e7          	jalr	-1710(ra) # 80000f86 <memset>
  mappages(pagetable, 0, PGSIZE, (uint64)mem, PTE_W|PTE_R|PTE_X|PTE_U);
    8000163c:	4779                	li	a4,30
    8000163e:	86ca                	mv	a3,s2
    80001640:	6605                	lui	a2,0x1
    80001642:	4581                	li	a1,0
    80001644:	8552                	mv	a0,s4
    80001646:	00000097          	auipc	ra,0x0
    8000164a:	d0c080e7          	jalr	-756(ra) # 80001352 <mappages>
  memmove(mem, src, sz);
    8000164e:	8626                	mv	a2,s1
    80001650:	85ce                	mv	a1,s3
    80001652:	854a                	mv	a0,s2
    80001654:	00000097          	auipc	ra,0x0
    80001658:	98e080e7          	jalr	-1650(ra) # 80000fe2 <memmove>
}
    8000165c:	70a2                	ld	ra,40(sp)
    8000165e:	7402                	ld	s0,32(sp)
    80001660:	64e2                	ld	s1,24(sp)
    80001662:	6942                	ld	s2,16(sp)
    80001664:	69a2                	ld	s3,8(sp)
    80001666:	6a02                	ld	s4,0(sp)
    80001668:	6145                	addi	sp,sp,48
    8000166a:	8082                	ret
    panic("uvmfirst: more than a page");
    8000166c:	00007517          	auipc	a0,0x7
    80001670:	b0c50513          	addi	a0,a0,-1268 # 80008178 <digits+0x138>
    80001674:	fffff097          	auipc	ra,0xfffff
    80001678:	eca080e7          	jalr	-310(ra) # 8000053e <panic>

000000008000167c <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    8000167c:	1101                	addi	sp,sp,-32
    8000167e:	ec06                	sd	ra,24(sp)
    80001680:	e822                	sd	s0,16(sp)
    80001682:	e426                	sd	s1,8(sp)
    80001684:	1000                	addi	s0,sp,32
  if(newsz >= oldsz)
    return oldsz;
    80001686:	84ae                	mv	s1,a1
  if(newsz >= oldsz)
    80001688:	00b67d63          	bgeu	a2,a1,800016a2 <uvmdealloc+0x26>
    8000168c:	84b2                	mv	s1,a2

  if(PGROUNDUP(newsz) < PGROUNDUP(oldsz)){
    8000168e:	6785                	lui	a5,0x1
    80001690:	17fd                	addi	a5,a5,-1
    80001692:	00f60733          	add	a4,a2,a5
    80001696:	767d                	lui	a2,0xfffff
    80001698:	8f71                	and	a4,a4,a2
    8000169a:	97ae                	add	a5,a5,a1
    8000169c:	8ff1                	and	a5,a5,a2
    8000169e:	00f76863          	bltu	a4,a5,800016ae <uvmdealloc+0x32>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    800016a2:	8526                	mv	a0,s1
    800016a4:	60e2                	ld	ra,24(sp)
    800016a6:	6442                	ld	s0,16(sp)
    800016a8:	64a2                	ld	s1,8(sp)
    800016aa:	6105                	addi	sp,sp,32
    800016ac:	8082                	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    800016ae:	8f99                	sub	a5,a5,a4
    800016b0:	83b1                	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    800016b2:	4685                	li	a3,1
    800016b4:	0007861b          	sext.w	a2,a5
    800016b8:	85ba                	mv	a1,a4
    800016ba:	00000097          	auipc	ra,0x0
    800016be:	e5e080e7          	jalr	-418(ra) # 80001518 <uvmunmap>
    800016c2:	b7c5                	j	800016a2 <uvmdealloc+0x26>

00000000800016c4 <uvmalloc>:
  if(newsz < oldsz)
    800016c4:	0ab66563          	bltu	a2,a1,8000176e <uvmalloc+0xaa>
{
    800016c8:	7139                	addi	sp,sp,-64
    800016ca:	fc06                	sd	ra,56(sp)
    800016cc:	f822                	sd	s0,48(sp)
    800016ce:	f426                	sd	s1,40(sp)
    800016d0:	f04a                	sd	s2,32(sp)
    800016d2:	ec4e                	sd	s3,24(sp)
    800016d4:	e852                	sd	s4,16(sp)
    800016d6:	e456                	sd	s5,8(sp)
    800016d8:	e05a                	sd	s6,0(sp)
    800016da:	0080                	addi	s0,sp,64
    800016dc:	8aaa                	mv	s5,a0
    800016de:	8a32                	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    800016e0:	6985                	lui	s3,0x1
    800016e2:	19fd                	addi	s3,s3,-1
    800016e4:	95ce                	add	a1,a1,s3
    800016e6:	79fd                	lui	s3,0xfffff
    800016e8:	0135f9b3          	and	s3,a1,s3
  for(a = oldsz; a < newsz; a += PGSIZE){
    800016ec:	08c9f363          	bgeu	s3,a2,80001772 <uvmalloc+0xae>
    800016f0:	894e                	mv	s2,s3
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    800016f2:	0126eb13          	ori	s6,a3,18
    mem = kalloc();
    800016f6:	fffff097          	auipc	ra,0xfffff
    800016fa:	44a080e7          	jalr	1098(ra) # 80000b40 <kalloc>
    800016fe:	84aa                	mv	s1,a0
    if(mem == 0){
    80001700:	c51d                	beqz	a0,8000172e <uvmalloc+0x6a>
    memset(mem, 0, PGSIZE);
    80001702:	6605                	lui	a2,0x1
    80001704:	4581                	li	a1,0
    80001706:	00000097          	auipc	ra,0x0
    8000170a:	880080e7          	jalr	-1920(ra) # 80000f86 <memset>
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    8000170e:	875a                	mv	a4,s6
    80001710:	86a6                	mv	a3,s1
    80001712:	6605                	lui	a2,0x1
    80001714:	85ca                	mv	a1,s2
    80001716:	8556                	mv	a0,s5
    80001718:	00000097          	auipc	ra,0x0
    8000171c:	c3a080e7          	jalr	-966(ra) # 80001352 <mappages>
    80001720:	e90d                	bnez	a0,80001752 <uvmalloc+0x8e>
  for(a = oldsz; a < newsz; a += PGSIZE){
    80001722:	6785                	lui	a5,0x1
    80001724:	993e                	add	s2,s2,a5
    80001726:	fd4968e3          	bltu	s2,s4,800016f6 <uvmalloc+0x32>
  return newsz;
    8000172a:	8552                	mv	a0,s4
    8000172c:	a809                	j	8000173e <uvmalloc+0x7a>
      uvmdealloc(pagetable, a, oldsz);
    8000172e:	864e                	mv	a2,s3
    80001730:	85ca                	mv	a1,s2
    80001732:	8556                	mv	a0,s5
    80001734:	00000097          	auipc	ra,0x0
    80001738:	f48080e7          	jalr	-184(ra) # 8000167c <uvmdealloc>
      return 0;
    8000173c:	4501                	li	a0,0
}
    8000173e:	70e2                	ld	ra,56(sp)
    80001740:	7442                	ld	s0,48(sp)
    80001742:	74a2                	ld	s1,40(sp)
    80001744:	7902                	ld	s2,32(sp)
    80001746:	69e2                	ld	s3,24(sp)
    80001748:	6a42                	ld	s4,16(sp)
    8000174a:	6aa2                	ld	s5,8(sp)
    8000174c:	6b02                	ld	s6,0(sp)
    8000174e:	6121                	addi	sp,sp,64
    80001750:	8082                	ret
      kfree(mem);
    80001752:	8526                	mv	a0,s1
    80001754:	fffff097          	auipc	ra,0xfffff
    80001758:	296080e7          	jalr	662(ra) # 800009ea <kfree>
      uvmdealloc(pagetable, a, oldsz);
    8000175c:	864e                	mv	a2,s3
    8000175e:	85ca                	mv	a1,s2
    80001760:	8556                	mv	a0,s5
    80001762:	00000097          	auipc	ra,0x0
    80001766:	f1a080e7          	jalr	-230(ra) # 8000167c <uvmdealloc>
      return 0;
    8000176a:	4501                	li	a0,0
    8000176c:	bfc9                	j	8000173e <uvmalloc+0x7a>
    return oldsz;
    8000176e:	852e                	mv	a0,a1
}
    80001770:	8082                	ret
  return newsz;
    80001772:	8532                	mv	a0,a2
    80001774:	b7e9                	j	8000173e <uvmalloc+0x7a>

0000000080001776 <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void
freewalk(pagetable_t pagetable)
{
    80001776:	7179                	addi	sp,sp,-48
    80001778:	f406                	sd	ra,40(sp)
    8000177a:	f022                	sd	s0,32(sp)
    8000177c:	ec26                	sd	s1,24(sp)
    8000177e:	e84a                	sd	s2,16(sp)
    80001780:	e44e                	sd	s3,8(sp)
    80001782:	e052                	sd	s4,0(sp)
    80001784:	1800                	addi	s0,sp,48
    80001786:	8a2a                	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for(int i = 0; i < 512; i++){
    80001788:	84aa                	mv	s1,a0
    8000178a:	6905                	lui	s2,0x1
    8000178c:	992a                	add	s2,s2,a0
    pte_t pte = pagetable[i];
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    8000178e:	4985                	li	s3,1
    80001790:	a821                	j	800017a8 <freewalk+0x32>
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    80001792:	8129                	srli	a0,a0,0xa
      freewalk((pagetable_t)child);
    80001794:	0532                	slli	a0,a0,0xc
    80001796:	00000097          	auipc	ra,0x0
    8000179a:	fe0080e7          	jalr	-32(ra) # 80001776 <freewalk>
      pagetable[i] = 0;
    8000179e:	0004b023          	sd	zero,0(s1)
  for(int i = 0; i < 512; i++){
    800017a2:	04a1                	addi	s1,s1,8
    800017a4:	03248163          	beq	s1,s2,800017c6 <freewalk+0x50>
    pte_t pte = pagetable[i];
    800017a8:	6088                	ld	a0,0(s1)
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    800017aa:	00f57793          	andi	a5,a0,15
    800017ae:	ff3782e3          	beq	a5,s3,80001792 <freewalk+0x1c>
    } else if(pte & PTE_V){
    800017b2:	8905                	andi	a0,a0,1
    800017b4:	d57d                	beqz	a0,800017a2 <freewalk+0x2c>
      panic("freewalk: leaf");
    800017b6:	00007517          	auipc	a0,0x7
    800017ba:	9e250513          	addi	a0,a0,-1566 # 80008198 <digits+0x158>
    800017be:	fffff097          	auipc	ra,0xfffff
    800017c2:	d80080e7          	jalr	-640(ra) # 8000053e <panic>
    }
  }
  kfree((void*)pagetable);
    800017c6:	8552                	mv	a0,s4
    800017c8:	fffff097          	auipc	ra,0xfffff
    800017cc:	222080e7          	jalr	546(ra) # 800009ea <kfree>
}
    800017d0:	70a2                	ld	ra,40(sp)
    800017d2:	7402                	ld	s0,32(sp)
    800017d4:	64e2                	ld	s1,24(sp)
    800017d6:	6942                	ld	s2,16(sp)
    800017d8:	69a2                	ld	s3,8(sp)
    800017da:	6a02                	ld	s4,0(sp)
    800017dc:	6145                	addi	sp,sp,48
    800017de:	8082                	ret

00000000800017e0 <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void
uvmfree(pagetable_t pagetable, uint64 sz)
{
    800017e0:	1101                	addi	sp,sp,-32
    800017e2:	ec06                	sd	ra,24(sp)
    800017e4:	e822                	sd	s0,16(sp)
    800017e6:	e426                	sd	s1,8(sp)
    800017e8:	1000                	addi	s0,sp,32
    800017ea:	84aa                	mv	s1,a0
  if(sz > 0)
    800017ec:	e999                	bnez	a1,80001802 <uvmfree+0x22>
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
  freewalk(pagetable);
    800017ee:	8526                	mv	a0,s1
    800017f0:	00000097          	auipc	ra,0x0
    800017f4:	f86080e7          	jalr	-122(ra) # 80001776 <freewalk>
}
    800017f8:	60e2                	ld	ra,24(sp)
    800017fa:	6442                	ld	s0,16(sp)
    800017fc:	64a2                	ld	s1,8(sp)
    800017fe:	6105                	addi	sp,sp,32
    80001800:	8082                	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
    80001802:	6605                	lui	a2,0x1
    80001804:	167d                	addi	a2,a2,-1
    80001806:	962e                	add	a2,a2,a1
    80001808:	4685                	li	a3,1
    8000180a:	8231                	srli	a2,a2,0xc
    8000180c:	4581                	li	a1,0
    8000180e:	00000097          	auipc	ra,0x0
    80001812:	d0a080e7          	jalr	-758(ra) # 80001518 <uvmunmap>
    80001816:	bfe1                	j	800017ee <uvmfree+0xe>

0000000080001818 <uvmcopy>:
// physical memory.
// returns 0 on success, -1 on failure.
// frees any allocated pages on failure.
int
uvmcopy(pagetable_t old, pagetable_t new, uint64 sz)
{
    80001818:	715d                	addi	sp,sp,-80
    8000181a:	e486                	sd	ra,72(sp)
    8000181c:	e0a2                	sd	s0,64(sp)
    8000181e:	fc26                	sd	s1,56(sp)
    80001820:	f84a                	sd	s2,48(sp)
    80001822:	f44e                	sd	s3,40(sp)
    80001824:	f052                	sd	s4,32(sp)
    80001826:	ec56                	sd	s5,24(sp)
    80001828:	e85a                	sd	s6,16(sp)
    8000182a:	e45e                	sd	s7,8(sp)
    8000182c:	0880                	addi	s0,sp,80
  pte_t *pte;
  uint64 pa, i;
  uint flags;

  for(i = 0; i < sz; i += PGSIZE){
    8000182e:	c269                	beqz	a2,800018f0 <uvmcopy+0xd8>
    80001830:	8aaa                	mv	s5,a0
    80001832:	8a2e                	mv	s4,a1
    80001834:	89b2                	mv	s3,a2
    80001836:	4481                	li	s1,0
    flags = PTE_FLAGS(*pte);
    
    if(flags & PTE_W) {
      flags &= ~PTE_W;
      flags |= PTE_COW;
      *pte = PA2PTE(pa) | flags;
    80001838:	7b7d                	lui	s6,0xfffff
    8000183a:	002b5b13          	srli	s6,s6,0x2
    8000183e:	a8a1                	j	80001896 <uvmcopy+0x7e>
      panic("uvmcopy: pte should exist");
    80001840:	00007517          	auipc	a0,0x7
    80001844:	96850513          	addi	a0,a0,-1688 # 800081a8 <digits+0x168>
    80001848:	fffff097          	auipc	ra,0xfffff
    8000184c:	cf6080e7          	jalr	-778(ra) # 8000053e <panic>
      panic("uvmcopy: page not present");
    80001850:	00007517          	auipc	a0,0x7
    80001854:	97850513          	addi	a0,a0,-1672 # 800081c8 <digits+0x188>
    80001858:	fffff097          	auipc	ra,0xfffff
    8000185c:	ce6080e7          	jalr	-794(ra) # 8000053e <panic>
      flags &= ~PTE_W;
    80001860:	3fb77693          	andi	a3,a4,1019
      flags |= PTE_COW;
    80001864:	1006e713          	ori	a4,a3,256
      *pte = PA2PTE(pa) | flags;
    80001868:	0167f7b3          	and	a5,a5,s6
    8000186c:	8fd9                	or	a5,a5,a4
    8000186e:	e11c                	sd	a5,0(a0)
    }
    
    if(mappages(new, i, PGSIZE, pa, flags) != 0) {
    80001870:	86ca                	mv	a3,s2
    80001872:	6605                	lui	a2,0x1
    80001874:	85a6                	mv	a1,s1
    80001876:	8552                	mv	a0,s4
    80001878:	00000097          	auipc	ra,0x0
    8000187c:	ada080e7          	jalr	-1318(ra) # 80001352 <mappages>
    80001880:	8baa                	mv	s7,a0
    80001882:	e129                	bnez	a0,800018c4 <uvmcopy+0xac>
      goto err;
    }
    
    increment_refcount((void*)pa);
    80001884:	854a                	mv	a0,s2
    80001886:	fffff097          	auipc	ra,0xfffff
    8000188a:	50a080e7          	jalr	1290(ra) # 80000d90 <increment_refcount>
  for(i = 0; i < sz; i += PGSIZE){
    8000188e:	6785                	lui	a5,0x1
    80001890:	94be                	add	s1,s1,a5
    80001892:	0534f363          	bgeu	s1,s3,800018d8 <uvmcopy+0xc0>
    if((pte = walk(old, i, 0)) == 0)
    80001896:	4601                	li	a2,0
    80001898:	85a6                	mv	a1,s1
    8000189a:	8556                	mv	a0,s5
    8000189c:	00000097          	auipc	ra,0x0
    800018a0:	9ce080e7          	jalr	-1586(ra) # 8000126a <walk>
    800018a4:	dd51                	beqz	a0,80001840 <uvmcopy+0x28>
    if((*pte & PTE_V) == 0)
    800018a6:	611c                	ld	a5,0(a0)
    800018a8:	0017f713          	andi	a4,a5,1
    800018ac:	d355                	beqz	a4,80001850 <uvmcopy+0x38>
    pa = PTE2PA(*pte);
    800018ae:	00a7d913          	srli	s2,a5,0xa
    800018b2:	0932                	slli	s2,s2,0xc
    flags = PTE_FLAGS(*pte);
    800018b4:	0007871b          	sext.w	a4,a5
    if(flags & PTE_W) {
    800018b8:	0047f693          	andi	a3,a5,4
    800018bc:	f2d5                	bnez	a3,80001860 <uvmcopy+0x48>
    flags = PTE_FLAGS(*pte);
    800018be:	3ff77713          	andi	a4,a4,1023
    800018c2:	b77d                	j	80001870 <uvmcopy+0x58>
  }
  return 0;

 err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    800018c4:	4685                	li	a3,1
    800018c6:	00c4d613          	srli	a2,s1,0xc
    800018ca:	4581                	li	a1,0
    800018cc:	8552                	mv	a0,s4
    800018ce:	00000097          	auipc	ra,0x0
    800018d2:	c4a080e7          	jalr	-950(ra) # 80001518 <uvmunmap>
  return -1;
    800018d6:	5bfd                	li	s7,-1
}
    800018d8:	855e                	mv	a0,s7
    800018da:	60a6                	ld	ra,72(sp)
    800018dc:	6406                	ld	s0,64(sp)
    800018de:	74e2                	ld	s1,56(sp)
    800018e0:	7942                	ld	s2,48(sp)
    800018e2:	79a2                	ld	s3,40(sp)
    800018e4:	7a02                	ld	s4,32(sp)
    800018e6:	6ae2                	ld	s5,24(sp)
    800018e8:	6b42                	ld	s6,16(sp)
    800018ea:	6ba2                	ld	s7,8(sp)
    800018ec:	6161                	addi	sp,sp,80
    800018ee:	8082                	ret
  return 0;
    800018f0:	4b81                	li	s7,0
    800018f2:	b7dd                	j	800018d8 <uvmcopy+0xc0>

00000000800018f4 <uvmclear>:
// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void
uvmclear(pagetable_t pagetable, uint64 va)
{
    800018f4:	1141                	addi	sp,sp,-16
    800018f6:	e406                	sd	ra,8(sp)
    800018f8:	e022                	sd	s0,0(sp)
    800018fa:	0800                	addi	s0,sp,16
  pte_t *pte;
  
  pte = walk(pagetable, va, 0);
    800018fc:	4601                	li	a2,0
    800018fe:	00000097          	auipc	ra,0x0
    80001902:	96c080e7          	jalr	-1684(ra) # 8000126a <walk>
  if(pte == 0)
    80001906:	c901                	beqz	a0,80001916 <uvmclear+0x22>
    panic("uvmclear");
  *pte &= ~PTE_U;
    80001908:	611c                	ld	a5,0(a0)
    8000190a:	9bbd                	andi	a5,a5,-17
    8000190c:	e11c                	sd	a5,0(a0)
}
    8000190e:	60a2                	ld	ra,8(sp)
    80001910:	6402                	ld	s0,0(sp)
    80001912:	0141                	addi	sp,sp,16
    80001914:	8082                	ret
    panic("uvmclear");
    80001916:	00007517          	auipc	a0,0x7
    8000191a:	8d250513          	addi	a0,a0,-1838 # 800081e8 <digits+0x1a8>
    8000191e:	fffff097          	auipc	ra,0xfffff
    80001922:	c20080e7          	jalr	-992(ra) # 8000053e <panic>

0000000080001926 <copyin>:
int
copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{
  uint64 n, va0, pa0;

  while(len > 0){
    80001926:	caa5                	beqz	a3,80001996 <copyin+0x70>
{
    80001928:	715d                	addi	sp,sp,-80
    8000192a:	e486                	sd	ra,72(sp)
    8000192c:	e0a2                	sd	s0,64(sp)
    8000192e:	fc26                	sd	s1,56(sp)
    80001930:	f84a                	sd	s2,48(sp)
    80001932:	f44e                	sd	s3,40(sp)
    80001934:	f052                	sd	s4,32(sp)
    80001936:	ec56                	sd	s5,24(sp)
    80001938:	e85a                	sd	s6,16(sp)
    8000193a:	e45e                	sd	s7,8(sp)
    8000193c:	e062                	sd	s8,0(sp)
    8000193e:	0880                	addi	s0,sp,80
    80001940:	8b2a                	mv	s6,a0
    80001942:	8a2e                	mv	s4,a1
    80001944:	8c32                	mv	s8,a2
    80001946:	89b6                	mv	s3,a3
    va0 = PGROUNDDOWN(srcva);
    80001948:	7bfd                	lui	s7,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    8000194a:	6a85                	lui	s5,0x1
    8000194c:	a01d                	j	80001972 <copyin+0x4c>
    if(n > len)
      n = len;
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    8000194e:	018505b3          	add	a1,a0,s8
    80001952:	0004861b          	sext.w	a2,s1
    80001956:	412585b3          	sub	a1,a1,s2
    8000195a:	8552                	mv	a0,s4
    8000195c:	fffff097          	auipc	ra,0xfffff
    80001960:	686080e7          	jalr	1670(ra) # 80000fe2 <memmove>

    len -= n;
    80001964:	409989b3          	sub	s3,s3,s1
    dst += n;
    80001968:	9a26                	add	s4,s4,s1
    srcva = va0 + PGSIZE;
    8000196a:	01590c33          	add	s8,s2,s5
  while(len > 0){
    8000196e:	02098263          	beqz	s3,80001992 <copyin+0x6c>
    va0 = PGROUNDDOWN(srcva);
    80001972:	017c7933          	and	s2,s8,s7
    pa0 = walkaddr(pagetable, va0);
    80001976:	85ca                	mv	a1,s2
    80001978:	855a                	mv	a0,s6
    8000197a:	00000097          	auipc	ra,0x0
    8000197e:	996080e7          	jalr	-1642(ra) # 80001310 <walkaddr>
    if(pa0 == 0)
    80001982:	cd01                	beqz	a0,8000199a <copyin+0x74>
    n = PGSIZE - (srcva - va0);
    80001984:	418904b3          	sub	s1,s2,s8
    80001988:	94d6                	add	s1,s1,s5
    if(n > len)
    8000198a:	fc99f2e3          	bgeu	s3,s1,8000194e <copyin+0x28>
    8000198e:	84ce                	mv	s1,s3
    80001990:	bf7d                	j	8000194e <copyin+0x28>
  }
  return 0;
    80001992:	4501                	li	a0,0
    80001994:	a021                	j	8000199c <copyin+0x76>
    80001996:	4501                	li	a0,0
}
    80001998:	8082                	ret
      return -1;
    8000199a:	557d                	li	a0,-1
}
    8000199c:	60a6                	ld	ra,72(sp)
    8000199e:	6406                	ld	s0,64(sp)
    800019a0:	74e2                	ld	s1,56(sp)
    800019a2:	7942                	ld	s2,48(sp)
    800019a4:	79a2                	ld	s3,40(sp)
    800019a6:	7a02                	ld	s4,32(sp)
    800019a8:	6ae2                	ld	s5,24(sp)
    800019aa:	6b42                	ld	s6,16(sp)
    800019ac:	6ba2                	ld	s7,8(sp)
    800019ae:	6c02                	ld	s8,0(sp)
    800019b0:	6161                	addi	sp,sp,80
    800019b2:	8082                	ret

00000000800019b4 <copyinstr>:
copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while(got_null == 0 && max > 0){
    800019b4:	c6c5                	beqz	a3,80001a5c <copyinstr+0xa8>
{
    800019b6:	715d                	addi	sp,sp,-80
    800019b8:	e486                	sd	ra,72(sp)
    800019ba:	e0a2                	sd	s0,64(sp)
    800019bc:	fc26                	sd	s1,56(sp)
    800019be:	f84a                	sd	s2,48(sp)
    800019c0:	f44e                	sd	s3,40(sp)
    800019c2:	f052                	sd	s4,32(sp)
    800019c4:	ec56                	sd	s5,24(sp)
    800019c6:	e85a                	sd	s6,16(sp)
    800019c8:	e45e                	sd	s7,8(sp)
    800019ca:	0880                	addi	s0,sp,80
    800019cc:	8a2a                	mv	s4,a0
    800019ce:	8b2e                	mv	s6,a1
    800019d0:	8bb2                	mv	s7,a2
    800019d2:	84b6                	mv	s1,a3
    va0 = PGROUNDDOWN(srcva);
    800019d4:	7afd                	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    800019d6:	6985                	lui	s3,0x1
    800019d8:	a035                	j	80001a04 <copyinstr+0x50>
      n = max;

    char *p = (char *) (pa0 + (srcva - va0));
    while(n > 0){
      if(*p == '\0'){
        *dst = '\0';
    800019da:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    800019de:	4785                	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if(got_null){
    800019e0:	0017b793          	seqz	a5,a5
    800019e4:	40f00533          	neg	a0,a5
    return 0;
  } else {
    return -1;
  }
}
    800019e8:	60a6                	ld	ra,72(sp)
    800019ea:	6406                	ld	s0,64(sp)
    800019ec:	74e2                	ld	s1,56(sp)
    800019ee:	7942                	ld	s2,48(sp)
    800019f0:	79a2                	ld	s3,40(sp)
    800019f2:	7a02                	ld	s4,32(sp)
    800019f4:	6ae2                	ld	s5,24(sp)
    800019f6:	6b42                	ld	s6,16(sp)
    800019f8:	6ba2                	ld	s7,8(sp)
    800019fa:	6161                	addi	sp,sp,80
    800019fc:	8082                	ret
    srcva = va0 + PGSIZE;
    800019fe:	01390bb3          	add	s7,s2,s3
  while(got_null == 0 && max > 0){
    80001a02:	c8a9                	beqz	s1,80001a54 <copyinstr+0xa0>
    va0 = PGROUNDDOWN(srcva);
    80001a04:	015bf933          	and	s2,s7,s5
    pa0 = walkaddr(pagetable, va0);
    80001a08:	85ca                	mv	a1,s2
    80001a0a:	8552                	mv	a0,s4
    80001a0c:	00000097          	auipc	ra,0x0
    80001a10:	904080e7          	jalr	-1788(ra) # 80001310 <walkaddr>
    if(pa0 == 0)
    80001a14:	c131                	beqz	a0,80001a58 <copyinstr+0xa4>
    n = PGSIZE - (srcva - va0);
    80001a16:	41790833          	sub	a6,s2,s7
    80001a1a:	984e                	add	a6,a6,s3
    if(n > max)
    80001a1c:	0104f363          	bgeu	s1,a6,80001a22 <copyinstr+0x6e>
    80001a20:	8826                	mv	a6,s1
    char *p = (char *) (pa0 + (srcva - va0));
    80001a22:	955e                	add	a0,a0,s7
    80001a24:	41250533          	sub	a0,a0,s2
    while(n > 0){
    80001a28:	fc080be3          	beqz	a6,800019fe <copyinstr+0x4a>
    80001a2c:	985a                	add	a6,a6,s6
    80001a2e:	87da                	mv	a5,s6
      if(*p == '\0'){
    80001a30:	41650633          	sub	a2,a0,s6
    80001a34:	14fd                	addi	s1,s1,-1
    80001a36:	9b26                	add	s6,s6,s1
    80001a38:	00f60733          	add	a4,a2,a5
    80001a3c:	00074703          	lbu	a4,0(a4)
    80001a40:	df49                	beqz	a4,800019da <copyinstr+0x26>
        *dst = *p;
    80001a42:	00e78023          	sb	a4,0(a5)
      --max;
    80001a46:	40fb04b3          	sub	s1,s6,a5
      dst++;
    80001a4a:	0785                	addi	a5,a5,1
    while(n > 0){
    80001a4c:	ff0796e3          	bne	a5,a6,80001a38 <copyinstr+0x84>
      dst++;
    80001a50:	8b42                	mv	s6,a6
    80001a52:	b775                	j	800019fe <copyinstr+0x4a>
    80001a54:	4781                	li	a5,0
    80001a56:	b769                	j	800019e0 <copyinstr+0x2c>
      return -1;
    80001a58:	557d                	li	a0,-1
    80001a5a:	b779                	j	800019e8 <copyinstr+0x34>
  int got_null = 0;
    80001a5c:	4781                	li	a5,0
  if(got_null){
    80001a5e:	0017b793          	seqz	a5,a5
    80001a62:	40f00533          	neg	a0,a5
}
    80001a66:	8082                	ret

0000000080001a68 <cow_handler>:
int
cow_handler(pagetable_t pagetable, uint64 va)
{
  
  if(va >= MAXVA)
    80001a68:	57fd                	li	a5,-1
    80001a6a:	83e9                	srli	a5,a5,0x1a
    80001a6c:	0ab7e963          	bltu	a5,a1,80001b1e <cow_handler+0xb6>
{
    80001a70:	7179                	addi	sp,sp,-48
    80001a72:	f406                	sd	ra,40(sp)
    80001a74:	f022                	sd	s0,32(sp)
    80001a76:	ec26                	sd	s1,24(sp)
    80001a78:	e84a                	sd	s2,16(sp)
    80001a7a:	e44e                	sd	s3,8(sp)
    80001a7c:	1800                	addi	s0,sp,48
    return -1;

  pte_t *pte = walk(pagetable, va, 0);
    80001a7e:	4601                	li	a2,0
    80001a80:	fffff097          	auipc	ra,0xfffff
    80001a84:	7ea080e7          	jalr	2026(ra) # 8000126a <walk>
    80001a88:	84aa                	mv	s1,a0
  if(pte == 0)
    80001a8a:	cd41                	beqz	a0,80001b22 <cow_handler+0xba>
    return -1;

  uint64 pa = PTE2PA(*pte);
    80001a8c:	00053903          	ld	s2,0(a0)
    80001a90:	00a95993          	srli	s3,s2,0xa
    80001a94:	09b2                	slli	s3,s3,0xc
  
  if((*pte & PTE_V) == 0 || (*pte & PTE_U) == 0)
    80001a96:	01197713          	andi	a4,s2,17
    80001a9a:	47c5                	li	a5,17
    80001a9c:	08f71563          	bne	a4,a5,80001b26 <cow_handler+0xbe>
    return -1;

  // If it's not a COW page, return error
  if((*pte & PTE_COW) == 0)
    80001aa0:	10097793          	andi	a5,s2,256
    80001aa4:	c3d9                	beqz	a5,80001b2a <cow_handler+0xc2>
    return -1;

  // Check if we really need to copy (refcount > 1)
  if(get_refcount((void*)pa) == 1) {
    80001aa6:	854e                	mv	a0,s3
    80001aa8:	fffff097          	auipc	ra,0xfffff
    80001aac:	278080e7          	jalr	632(ra) # 80000d20 <get_refcount>
    80001ab0:	4785                	li	a5,1
    80001ab2:	04f50763          	beq	a0,a5,80001b00 <cow_handler+0x98>
    *pte = PA2PTE(pa) | flags;
    return 0;
  }

  // Allocate new page without memset
  char *mem = cow_alloc();
    80001ab6:	fffff097          	auipc	ra,0xfffff
    80001aba:	102080e7          	jalr	258(ra) # 80000bb8 <cow_alloc>
    80001abe:	892a                	mv	s2,a0
  if(mem == 0)
    80001ac0:	c53d                	beqz	a0,80001b2e <cow_handler+0xc6>
    return -1;

  // Copy the old page
  memmove(mem, (char*)pa, PGSIZE);
    80001ac2:	6605                	lui	a2,0x1
    80001ac4:	85ce                	mv	a1,s3
    80001ac6:	fffff097          	auipc	ra,0xfffff
    80001aca:	51c080e7          	jalr	1308(ra) # 80000fe2 <memmove>

  // Update the mapping
  uint64 flags = (PTE_FLAGS(*pte) | PTE_W) & ~PTE_COW;
    80001ace:	609c                	ld	a5,0(s1)
    80001ad0:	2fb7f793          	andi	a5,a5,763
  *pte = PA2PTE((uint64)mem) | flags;
    80001ad4:	00c95913          	srli	s2,s2,0xc
    80001ad8:	092a                	slli	s2,s2,0xa
    80001ada:	0127e933          	or	s2,a5,s2
    80001ade:	00496913          	ori	s2,s2,4
    80001ae2:	0124b023          	sd	s2,0(s1)

  // Decrease reference count of old page
  kfree((void*)pa);
    80001ae6:	854e                	mv	a0,s3
    80001ae8:	fffff097          	auipc	ra,0xfffff
    80001aec:	f02080e7          	jalr	-254(ra) # 800009ea <kfree>

  return 0;
    80001af0:	4501                	li	a0,0
}
    80001af2:	70a2                	ld	ra,40(sp)
    80001af4:	7402                	ld	s0,32(sp)
    80001af6:	64e2                	ld	s1,24(sp)
    80001af8:	6942                	ld	s2,16(sp)
    80001afa:	69a2                	ld	s3,8(sp)
    80001afc:	6145                	addi	sp,sp,48
    80001afe:	8082                	ret
    *pte = PA2PTE(pa) | flags;
    80001b00:	609c                	ld	a5,0(s1)
    80001b02:	2ff7f793          	andi	a5,a5,767
    80001b06:	777d                	lui	a4,0xfffff
    80001b08:	8309                	srli	a4,a4,0x2
    80001b0a:	00e97933          	and	s2,s2,a4
    80001b0e:	0127e933          	or	s2,a5,s2
    80001b12:	00496913          	ori	s2,s2,4
    80001b16:	0124b023          	sd	s2,0(s1)
    return 0;
    80001b1a:	4501                	li	a0,0
    80001b1c:	bfd9                	j	80001af2 <cow_handler+0x8a>
    return -1;
    80001b1e:	557d                	li	a0,-1
}
    80001b20:	8082                	ret
    return -1;
    80001b22:	557d                	li	a0,-1
    80001b24:	b7f9                	j	80001af2 <cow_handler+0x8a>
    return -1;
    80001b26:	557d                	li	a0,-1
    80001b28:	b7e9                	j	80001af2 <cow_handler+0x8a>
    return -1;
    80001b2a:	557d                	li	a0,-1
    80001b2c:	b7d9                	j	80001af2 <cow_handler+0x8a>
    return -1;
    80001b2e:	557d                	li	a0,-1
    80001b30:	b7c9                	j	80001af2 <cow_handler+0x8a>

0000000080001b32 <copyout>:
  while(len > 0){
    80001b32:	cac5                	beqz	a3,80001be2 <copyout+0xb0>
{
    80001b34:	711d                	addi	sp,sp,-96
    80001b36:	ec86                	sd	ra,88(sp)
    80001b38:	e8a2                	sd	s0,80(sp)
    80001b3a:	e4a6                	sd	s1,72(sp)
    80001b3c:	e0ca                	sd	s2,64(sp)
    80001b3e:	fc4e                	sd	s3,56(sp)
    80001b40:	f852                	sd	s4,48(sp)
    80001b42:	f456                	sd	s5,40(sp)
    80001b44:	f05a                	sd	s6,32(sp)
    80001b46:	ec5e                	sd	s7,24(sp)
    80001b48:	e862                	sd	s8,16(sp)
    80001b4a:	e466                	sd	s9,8(sp)
    80001b4c:	e06a                	sd	s10,0(sp)
    80001b4e:	1080                	addi	s0,sp,96
    80001b50:	8baa                	mv	s7,a0
    80001b52:	89ae                	mv	s3,a1
    80001b54:	8b32                	mv	s6,a2
    80001b56:	8ab6                	mv	s5,a3
    va0 = PGROUNDDOWN(dstva);
    80001b58:	7cfd                	lui	s9,0xfffff
    if(pte && (*pte & PTE_V) && (*pte & PTE_COW)) {
    80001b5a:	10100d13          	li	s10,257
    n = PGSIZE - (dstva - va0);
    80001b5e:	6c05                	lui	s8,0x1
    80001b60:	a089                	j	80001ba2 <copyout+0x70>
      if(cow_handler(pagetable, va0) != 0)
    80001b62:	85ca                	mv	a1,s2
    80001b64:	855e                	mv	a0,s7
    80001b66:	00000097          	auipc	ra,0x0
    80001b6a:	f02080e7          	jalr	-254(ra) # 80001a68 <cow_handler>
    80001b6e:	e959                	bnez	a0,80001c04 <copyout+0xd2>
      pa0 = walkaddr(pagetable, va0);
    80001b70:	85ca                	mv	a1,s2
    80001b72:	855e                	mv	a0,s7
    80001b74:	fffff097          	auipc	ra,0xfffff
    80001b78:	79c080e7          	jalr	1948(ra) # 80001310 <walkaddr>
    80001b7c:	8a2a                	mv	s4,a0
    80001b7e:	a889                	j	80001bd0 <copyout+0x9e>
    memmove((void *)(pa0 + (dstva - va0)), src, n);
    80001b80:	41298533          	sub	a0,s3,s2
    80001b84:	0004861b          	sext.w	a2,s1
    80001b88:	85da                	mv	a1,s6
    80001b8a:	9552                	add	a0,a0,s4
    80001b8c:	fffff097          	auipc	ra,0xfffff
    80001b90:	456080e7          	jalr	1110(ra) # 80000fe2 <memmove>
    len -= n;
    80001b94:	409a8ab3          	sub	s5,s5,s1
    src += n;
    80001b98:	9b26                	add	s6,s6,s1
    dstva = va0 + PGSIZE;
    80001b9a:	018909b3          	add	s3,s2,s8
  while(len > 0){
    80001b9e:	040a8063          	beqz	s5,80001bde <copyout+0xac>
    va0 = PGROUNDDOWN(dstva);
    80001ba2:	0199f933          	and	s2,s3,s9
    pa0 = walkaddr(pagetable, va0);
    80001ba6:	85ca                	mv	a1,s2
    80001ba8:	855e                	mv	a0,s7
    80001baa:	fffff097          	auipc	ra,0xfffff
    80001bae:	766080e7          	jalr	1894(ra) # 80001310 <walkaddr>
    80001bb2:	8a2a                	mv	s4,a0
    if(pa0 == 0)
    80001bb4:	c90d                	beqz	a0,80001be6 <copyout+0xb4>
    pte_t *pte = walk(pagetable, va0, 0);
    80001bb6:	4601                	li	a2,0
    80001bb8:	85ca                	mv	a1,s2
    80001bba:	855e                	mv	a0,s7
    80001bbc:	fffff097          	auipc	ra,0xfffff
    80001bc0:	6ae080e7          	jalr	1710(ra) # 8000126a <walk>
    if(pte && (*pte & PTE_V) && (*pte & PTE_COW)) {
    80001bc4:	c511                	beqz	a0,80001bd0 <copyout+0x9e>
    80001bc6:	611c                	ld	a5,0(a0)
    80001bc8:	1017f793          	andi	a5,a5,257
    80001bcc:	f9a78be3          	beq	a5,s10,80001b62 <copyout+0x30>
    n = PGSIZE - (dstva - va0);
    80001bd0:	413904b3          	sub	s1,s2,s3
    80001bd4:	94e2                	add	s1,s1,s8
    if(n > len)
    80001bd6:	fa9af5e3          	bgeu	s5,s1,80001b80 <copyout+0x4e>
    80001bda:	84d6                	mv	s1,s5
    80001bdc:	b755                	j	80001b80 <copyout+0x4e>
  return 0;
    80001bde:	4501                	li	a0,0
    80001be0:	a021                	j	80001be8 <copyout+0xb6>
    80001be2:	4501                	li	a0,0
}
    80001be4:	8082                	ret
      return -1;
    80001be6:	557d                	li	a0,-1
}
    80001be8:	60e6                	ld	ra,88(sp)
    80001bea:	6446                	ld	s0,80(sp)
    80001bec:	64a6                	ld	s1,72(sp)
    80001bee:	6906                	ld	s2,64(sp)
    80001bf0:	79e2                	ld	s3,56(sp)
    80001bf2:	7a42                	ld	s4,48(sp)
    80001bf4:	7aa2                	ld	s5,40(sp)
    80001bf6:	7b02                	ld	s6,32(sp)
    80001bf8:	6be2                	ld	s7,24(sp)
    80001bfa:	6c42                	ld	s8,16(sp)
    80001bfc:	6ca2                	ld	s9,8(sp)
    80001bfe:	6d02                	ld	s10,0(sp)
    80001c00:	6125                	addi	sp,sp,96
    80001c02:	8082                	ret
        return -1;
    80001c04:	557d                	li	a0,-1
    80001c06:	b7cd                	j	80001be8 <copyout+0xb6>

0000000080001c08 <proc_mapstacks>:

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void proc_mapstacks(pagetable_t kpgtbl)
{
    80001c08:	7139                	addi	sp,sp,-64
    80001c0a:	fc06                	sd	ra,56(sp)
    80001c0c:	f822                	sd	s0,48(sp)
    80001c0e:	f426                	sd	s1,40(sp)
    80001c10:	f04a                	sd	s2,32(sp)
    80001c12:	ec4e                	sd	s3,24(sp)
    80001c14:	e852                	sd	s4,16(sp)
    80001c16:	e456                	sd	s5,8(sp)
    80001c18:	e05a                	sd	s6,0(sp)
    80001c1a:	0080                	addi	s0,sp,64
    80001c1c:	89aa                	mv	s3,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80001c1e:	0002f497          	auipc	s1,0x2f
    80001c22:	3a248493          	addi	s1,s1,930 # 80030fc0 <proc>
  {
    char *pa = kalloc();
    if (pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int)(p - proc));
    80001c26:	8b26                	mv	s6,s1
    80001c28:	00006a97          	auipc	s5,0x6
    80001c2c:	3d8a8a93          	addi	s5,s5,984 # 80008000 <etext>
    80001c30:	04000937          	lui	s2,0x4000
    80001c34:	197d                	addi	s2,s2,-1
    80001c36:	0932                	slli	s2,s2,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001c38:	00035a17          	auipc	s4,0x35
    80001c3c:	188a0a13          	addi	s4,s4,392 # 80036dc0 <tickslock>
    char *pa = kalloc();
    80001c40:	fffff097          	auipc	ra,0xfffff
    80001c44:	f00080e7          	jalr	-256(ra) # 80000b40 <kalloc>
    80001c48:	862a                	mv	a2,a0
    if (pa == 0)
    80001c4a:	c131                	beqz	a0,80001c8e <proc_mapstacks+0x86>
    uint64 va = KSTACK((int)(p - proc));
    80001c4c:	416485b3          	sub	a1,s1,s6
    80001c50:	858d                	srai	a1,a1,0x3
    80001c52:	000ab783          	ld	a5,0(s5)
    80001c56:	02f585b3          	mul	a1,a1,a5
    80001c5a:	2585                	addiw	a1,a1,1
    80001c5c:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    80001c60:	4719                	li	a4,6
    80001c62:	6685                	lui	a3,0x1
    80001c64:	40b905b3          	sub	a1,s2,a1
    80001c68:	854e                	mv	a0,s3
    80001c6a:	fffff097          	auipc	ra,0xfffff
    80001c6e:	788080e7          	jalr	1928(ra) # 800013f2 <kvmmap>
  for (p = proc; p < &proc[NPROC]; p++)
    80001c72:	17848493          	addi	s1,s1,376
    80001c76:	fd4495e3          	bne	s1,s4,80001c40 <proc_mapstacks+0x38>
  }
}
    80001c7a:	70e2                	ld	ra,56(sp)
    80001c7c:	7442                	ld	s0,48(sp)
    80001c7e:	74a2                	ld	s1,40(sp)
    80001c80:	7902                	ld	s2,32(sp)
    80001c82:	69e2                	ld	s3,24(sp)
    80001c84:	6a42                	ld	s4,16(sp)
    80001c86:	6aa2                	ld	s5,8(sp)
    80001c88:	6b02                	ld	s6,0(sp)
    80001c8a:	6121                	addi	sp,sp,64
    80001c8c:	8082                	ret
      panic("kalloc");
    80001c8e:	00006517          	auipc	a0,0x6
    80001c92:	56a50513          	addi	a0,a0,1386 # 800081f8 <digits+0x1b8>
    80001c96:	fffff097          	auipc	ra,0xfffff
    80001c9a:	8a8080e7          	jalr	-1880(ra) # 8000053e <panic>

0000000080001c9e <procinit>:

// initialize the proc table.
void procinit(void)
{
    80001c9e:	7139                	addi	sp,sp,-64
    80001ca0:	fc06                	sd	ra,56(sp)
    80001ca2:	f822                	sd	s0,48(sp)
    80001ca4:	f426                	sd	s1,40(sp)
    80001ca6:	f04a                	sd	s2,32(sp)
    80001ca8:	ec4e                	sd	s3,24(sp)
    80001caa:	e852                	sd	s4,16(sp)
    80001cac:	e456                	sd	s5,8(sp)
    80001cae:	e05a                	sd	s6,0(sp)
    80001cb0:	0080                	addi	s0,sp,64
  struct proc *p;

  initlock(&pid_lock, "nextpid");
    80001cb2:	00006597          	auipc	a1,0x6
    80001cb6:	54e58593          	addi	a1,a1,1358 # 80008200 <digits+0x1c0>
    80001cba:	0002f517          	auipc	a0,0x2f
    80001cbe:	ed650513          	addi	a0,a0,-298 # 80030b90 <pid_lock>
    80001cc2:	fffff097          	auipc	ra,0xfffff
    80001cc6:	138080e7          	jalr	312(ra) # 80000dfa <initlock>
  initlock(&wait_lock, "wait_lock");
    80001cca:	00006597          	auipc	a1,0x6
    80001cce:	53e58593          	addi	a1,a1,1342 # 80008208 <digits+0x1c8>
    80001cd2:	0002f517          	auipc	a0,0x2f
    80001cd6:	ed650513          	addi	a0,a0,-298 # 80030ba8 <wait_lock>
    80001cda:	fffff097          	auipc	ra,0xfffff
    80001cde:	120080e7          	jalr	288(ra) # 80000dfa <initlock>
  for (p = proc; p < &proc[NPROC]; p++)
    80001ce2:	0002f497          	auipc	s1,0x2f
    80001ce6:	2de48493          	addi	s1,s1,734 # 80030fc0 <proc>
  {
    initlock(&p->lock, "proc");
    80001cea:	00006b17          	auipc	s6,0x6
    80001cee:	52eb0b13          	addi	s6,s6,1326 # 80008218 <digits+0x1d8>
    p->state = UNUSED;
    p->kstack = KSTACK((int)(p - proc));
    80001cf2:	8aa6                	mv	s5,s1
    80001cf4:	00006a17          	auipc	s4,0x6
    80001cf8:	30ca0a13          	addi	s4,s4,780 # 80008000 <etext>
    80001cfc:	04000937          	lui	s2,0x4000
    80001d00:	197d                	addi	s2,s2,-1
    80001d02:	0932                	slli	s2,s2,0xc
  for (p = proc; p < &proc[NPROC]; p++)
    80001d04:	00035997          	auipc	s3,0x35
    80001d08:	0bc98993          	addi	s3,s3,188 # 80036dc0 <tickslock>
    initlock(&p->lock, "proc");
    80001d0c:	85da                	mv	a1,s6
    80001d0e:	8526                	mv	a0,s1
    80001d10:	fffff097          	auipc	ra,0xfffff
    80001d14:	0ea080e7          	jalr	234(ra) # 80000dfa <initlock>
    p->state = UNUSED;
    80001d18:	0004ac23          	sw	zero,24(s1)
    p->kstack = KSTACK((int)(p - proc));
    80001d1c:	415487b3          	sub	a5,s1,s5
    80001d20:	878d                	srai	a5,a5,0x3
    80001d22:	000a3703          	ld	a4,0(s4)
    80001d26:	02e787b3          	mul	a5,a5,a4
    80001d2a:	2785                	addiw	a5,a5,1
    80001d2c:	00d7979b          	slliw	a5,a5,0xd
    80001d30:	40f907b3          	sub	a5,s2,a5
    80001d34:	e0bc                	sd	a5,64(s1)
  for (p = proc; p < &proc[NPROC]; p++)
    80001d36:	17848493          	addi	s1,s1,376
    80001d3a:	fd3499e3          	bne	s1,s3,80001d0c <procinit+0x6e>
  }
}
    80001d3e:	70e2                	ld	ra,56(sp)
    80001d40:	7442                	ld	s0,48(sp)
    80001d42:	74a2                	ld	s1,40(sp)
    80001d44:	7902                	ld	s2,32(sp)
    80001d46:	69e2                	ld	s3,24(sp)
    80001d48:	6a42                	ld	s4,16(sp)
    80001d4a:	6aa2                	ld	s5,8(sp)
    80001d4c:	6b02                	ld	s6,0(sp)
    80001d4e:	6121                	addi	sp,sp,64
    80001d50:	8082                	ret

0000000080001d52 <cpuid>:

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int cpuid()
{
    80001d52:	1141                	addi	sp,sp,-16
    80001d54:	e422                	sd	s0,8(sp)
    80001d56:	0800                	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    80001d58:	8512                	mv	a0,tp
  int id = r_tp();
  return id;
}
    80001d5a:	2501                	sext.w	a0,a0
    80001d5c:	6422                	ld	s0,8(sp)
    80001d5e:	0141                	addi	sp,sp,16
    80001d60:	8082                	ret

0000000080001d62 <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu *
mycpu(void)
{
    80001d62:	1141                	addi	sp,sp,-16
    80001d64:	e422                	sd	s0,8(sp)
    80001d66:	0800                	addi	s0,sp,16
    80001d68:	8792                	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    80001d6a:	2781                	sext.w	a5,a5
    80001d6c:	079e                	slli	a5,a5,0x7
  return c;
}
    80001d6e:	0002f517          	auipc	a0,0x2f
    80001d72:	e5250513          	addi	a0,a0,-430 # 80030bc0 <cpus>
    80001d76:	953e                	add	a0,a0,a5
    80001d78:	6422                	ld	s0,8(sp)
    80001d7a:	0141                	addi	sp,sp,16
    80001d7c:	8082                	ret

0000000080001d7e <myproc>:

// Return the current struct proc *, or zero if none.
struct proc *
myproc(void)
{
    80001d7e:	1101                	addi	sp,sp,-32
    80001d80:	ec06                	sd	ra,24(sp)
    80001d82:	e822                	sd	s0,16(sp)
    80001d84:	e426                	sd	s1,8(sp)
    80001d86:	1000                	addi	s0,sp,32
  push_off();
    80001d88:	fffff097          	auipc	ra,0xfffff
    80001d8c:	0b6080e7          	jalr	182(ra) # 80000e3e <push_off>
    80001d90:	8792                	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    80001d92:	2781                	sext.w	a5,a5
    80001d94:	079e                	slli	a5,a5,0x7
    80001d96:	0002f717          	auipc	a4,0x2f
    80001d9a:	dfa70713          	addi	a4,a4,-518 # 80030b90 <pid_lock>
    80001d9e:	97ba                	add	a5,a5,a4
    80001da0:	7b84                	ld	s1,48(a5)
  pop_off();
    80001da2:	fffff097          	auipc	ra,0xfffff
    80001da6:	13c080e7          	jalr	316(ra) # 80000ede <pop_off>
  return p;
}
    80001daa:	8526                	mv	a0,s1
    80001dac:	60e2                	ld	ra,24(sp)
    80001dae:	6442                	ld	s0,16(sp)
    80001db0:	64a2                	ld	s1,8(sp)
    80001db2:	6105                	addi	sp,sp,32
    80001db4:	8082                	ret

0000000080001db6 <forkret>:
}

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void forkret(void)
{
    80001db6:	1141                	addi	sp,sp,-16
    80001db8:	e406                	sd	ra,8(sp)
    80001dba:	e022                	sd	s0,0(sp)
    80001dbc:	0800                	addi	s0,sp,16
  static int first = 1;

  // Still holding p->lock from scheduler.
  release(&myproc()->lock);
    80001dbe:	00000097          	auipc	ra,0x0
    80001dc2:	fc0080e7          	jalr	-64(ra) # 80001d7e <myproc>
    80001dc6:	fffff097          	auipc	ra,0xfffff
    80001dca:	178080e7          	jalr	376(ra) # 80000f3e <release>

  if (first)
    80001dce:	00007797          	auipc	a5,0x7
    80001dd2:	ad27a783          	lw	a5,-1326(a5) # 800088a0 <first.1>
    80001dd6:	eb89                	bnez	a5,80001de8 <forkret+0x32>
    // be run from main().
    first = 0;
    fsinit(ROOTDEV);
  }

  usertrapret();
    80001dd8:	00001097          	auipc	ra,0x1
    80001ddc:	e24080e7          	jalr	-476(ra) # 80002bfc <usertrapret>
}
    80001de0:	60a2                	ld	ra,8(sp)
    80001de2:	6402                	ld	s0,0(sp)
    80001de4:	0141                	addi	sp,sp,16
    80001de6:	8082                	ret
    first = 0;
    80001de8:	00007797          	auipc	a5,0x7
    80001dec:	aa07ac23          	sw	zero,-1352(a5) # 800088a0 <first.1>
    fsinit(ROOTDEV);
    80001df0:	4505                	li	a0,1
    80001df2:	00002097          	auipc	ra,0x2
    80001df6:	c5c080e7          	jalr	-932(ra) # 80003a4e <fsinit>
    80001dfa:	bff9                	j	80001dd8 <forkret+0x22>

0000000080001dfc <allocpid>:
{
    80001dfc:	1101                	addi	sp,sp,-32
    80001dfe:	ec06                	sd	ra,24(sp)
    80001e00:	e822                	sd	s0,16(sp)
    80001e02:	e426                	sd	s1,8(sp)
    80001e04:	e04a                	sd	s2,0(sp)
    80001e06:	1000                	addi	s0,sp,32
  acquire(&pid_lock);
    80001e08:	0002f917          	auipc	s2,0x2f
    80001e0c:	d8890913          	addi	s2,s2,-632 # 80030b90 <pid_lock>
    80001e10:	854a                	mv	a0,s2
    80001e12:	fffff097          	auipc	ra,0xfffff
    80001e16:	078080e7          	jalr	120(ra) # 80000e8a <acquire>
  pid = nextpid;
    80001e1a:	00007797          	auipc	a5,0x7
    80001e1e:	a8a78793          	addi	a5,a5,-1398 # 800088a4 <nextpid>
    80001e22:	4384                	lw	s1,0(a5)
  nextpid = nextpid + 1;
    80001e24:	0014871b          	addiw	a4,s1,1
    80001e28:	c398                	sw	a4,0(a5)
  release(&pid_lock);
    80001e2a:	854a                	mv	a0,s2
    80001e2c:	fffff097          	auipc	ra,0xfffff
    80001e30:	112080e7          	jalr	274(ra) # 80000f3e <release>
}
    80001e34:	8526                	mv	a0,s1
    80001e36:	60e2                	ld	ra,24(sp)
    80001e38:	6442                	ld	s0,16(sp)
    80001e3a:	64a2                	ld	s1,8(sp)
    80001e3c:	6902                	ld	s2,0(sp)
    80001e3e:	6105                	addi	sp,sp,32
    80001e40:	8082                	ret

0000000080001e42 <proc_pagetable>:
{
    80001e42:	1101                	addi	sp,sp,-32
    80001e44:	ec06                	sd	ra,24(sp)
    80001e46:	e822                	sd	s0,16(sp)
    80001e48:	e426                	sd	s1,8(sp)
    80001e4a:	e04a                	sd	s2,0(sp)
    80001e4c:	1000                	addi	s0,sp,32
    80001e4e:	892a                	mv	s2,a0
  pagetable = uvmcreate();
    80001e50:	fffff097          	auipc	ra,0xfffff
    80001e54:	78c080e7          	jalr	1932(ra) # 800015dc <uvmcreate>
    80001e58:	84aa                	mv	s1,a0
  if (pagetable == 0)
    80001e5a:	c121                	beqz	a0,80001e9a <proc_pagetable+0x58>
  if (mappages(pagetable, TRAMPOLINE, PGSIZE,
    80001e5c:	4729                	li	a4,10
    80001e5e:	00005697          	auipc	a3,0x5
    80001e62:	1a268693          	addi	a3,a3,418 # 80007000 <_trampoline>
    80001e66:	6605                	lui	a2,0x1
    80001e68:	040005b7          	lui	a1,0x4000
    80001e6c:	15fd                	addi	a1,a1,-1
    80001e6e:	05b2                	slli	a1,a1,0xc
    80001e70:	fffff097          	auipc	ra,0xfffff
    80001e74:	4e2080e7          	jalr	1250(ra) # 80001352 <mappages>
    80001e78:	02054863          	bltz	a0,80001ea8 <proc_pagetable+0x66>
  if (mappages(pagetable, TRAPFRAME, PGSIZE,
    80001e7c:	4719                	li	a4,6
    80001e7e:	05893683          	ld	a3,88(s2)
    80001e82:	6605                	lui	a2,0x1
    80001e84:	020005b7          	lui	a1,0x2000
    80001e88:	15fd                	addi	a1,a1,-1
    80001e8a:	05b6                	slli	a1,a1,0xd
    80001e8c:	8526                	mv	a0,s1
    80001e8e:	fffff097          	auipc	ra,0xfffff
    80001e92:	4c4080e7          	jalr	1220(ra) # 80001352 <mappages>
    80001e96:	02054163          	bltz	a0,80001eb8 <proc_pagetable+0x76>
}
    80001e9a:	8526                	mv	a0,s1
    80001e9c:	60e2                	ld	ra,24(sp)
    80001e9e:	6442                	ld	s0,16(sp)
    80001ea0:	64a2                	ld	s1,8(sp)
    80001ea2:	6902                	ld	s2,0(sp)
    80001ea4:	6105                	addi	sp,sp,32
    80001ea6:	8082                	ret
    uvmfree(pagetable, 0);
    80001ea8:	4581                	li	a1,0
    80001eaa:	8526                	mv	a0,s1
    80001eac:	00000097          	auipc	ra,0x0
    80001eb0:	934080e7          	jalr	-1740(ra) # 800017e0 <uvmfree>
    return 0;
    80001eb4:	4481                	li	s1,0
    80001eb6:	b7d5                	j	80001e9a <proc_pagetable+0x58>
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001eb8:	4681                	li	a3,0
    80001eba:	4605                	li	a2,1
    80001ebc:	040005b7          	lui	a1,0x4000
    80001ec0:	15fd                	addi	a1,a1,-1
    80001ec2:	05b2                	slli	a1,a1,0xc
    80001ec4:	8526                	mv	a0,s1
    80001ec6:	fffff097          	auipc	ra,0xfffff
    80001eca:	652080e7          	jalr	1618(ra) # 80001518 <uvmunmap>
    uvmfree(pagetable, 0);
    80001ece:	4581                	li	a1,0
    80001ed0:	8526                	mv	a0,s1
    80001ed2:	00000097          	auipc	ra,0x0
    80001ed6:	90e080e7          	jalr	-1778(ra) # 800017e0 <uvmfree>
    return 0;
    80001eda:	4481                	li	s1,0
    80001edc:	bf7d                	j	80001e9a <proc_pagetable+0x58>

0000000080001ede <proc_freepagetable>:
{
    80001ede:	1101                	addi	sp,sp,-32
    80001ee0:	ec06                	sd	ra,24(sp)
    80001ee2:	e822                	sd	s0,16(sp)
    80001ee4:	e426                	sd	s1,8(sp)
    80001ee6:	e04a                	sd	s2,0(sp)
    80001ee8:	1000                	addi	s0,sp,32
    80001eea:	84aa                	mv	s1,a0
    80001eec:	892e                	mv	s2,a1
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001eee:	4681                	li	a3,0
    80001ef0:	4605                	li	a2,1
    80001ef2:	040005b7          	lui	a1,0x4000
    80001ef6:	15fd                	addi	a1,a1,-1
    80001ef8:	05b2                	slli	a1,a1,0xc
    80001efa:	fffff097          	auipc	ra,0xfffff
    80001efe:	61e080e7          	jalr	1566(ra) # 80001518 <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    80001f02:	4681                	li	a3,0
    80001f04:	4605                	li	a2,1
    80001f06:	020005b7          	lui	a1,0x2000
    80001f0a:	15fd                	addi	a1,a1,-1
    80001f0c:	05b6                	slli	a1,a1,0xd
    80001f0e:	8526                	mv	a0,s1
    80001f10:	fffff097          	auipc	ra,0xfffff
    80001f14:	608080e7          	jalr	1544(ra) # 80001518 <uvmunmap>
  uvmfree(pagetable, sz);
    80001f18:	85ca                	mv	a1,s2
    80001f1a:	8526                	mv	a0,s1
    80001f1c:	00000097          	auipc	ra,0x0
    80001f20:	8c4080e7          	jalr	-1852(ra) # 800017e0 <uvmfree>
}
    80001f24:	60e2                	ld	ra,24(sp)
    80001f26:	6442                	ld	s0,16(sp)
    80001f28:	64a2                	ld	s1,8(sp)
    80001f2a:	6902                	ld	s2,0(sp)
    80001f2c:	6105                	addi	sp,sp,32
    80001f2e:	8082                	ret

0000000080001f30 <freeproc>:
{
    80001f30:	1101                	addi	sp,sp,-32
    80001f32:	ec06                	sd	ra,24(sp)
    80001f34:	e822                	sd	s0,16(sp)
    80001f36:	e426                	sd	s1,8(sp)
    80001f38:	1000                	addi	s0,sp,32
    80001f3a:	84aa                	mv	s1,a0
  if (p->trapframe)
    80001f3c:	6d28                	ld	a0,88(a0)
    80001f3e:	c509                	beqz	a0,80001f48 <freeproc+0x18>
    kfree((void *)p->trapframe);
    80001f40:	fffff097          	auipc	ra,0xfffff
    80001f44:	aaa080e7          	jalr	-1366(ra) # 800009ea <kfree>
  p->trapframe = 0;
    80001f48:	0404bc23          	sd	zero,88(s1)
  if (p->pagetable)
    80001f4c:	68a8                	ld	a0,80(s1)
    80001f4e:	c511                	beqz	a0,80001f5a <freeproc+0x2a>
    proc_freepagetable(p->pagetable, p->sz);
    80001f50:	64ac                	ld	a1,72(s1)
    80001f52:	00000097          	auipc	ra,0x0
    80001f56:	f8c080e7          	jalr	-116(ra) # 80001ede <proc_freepagetable>
  p->pagetable = 0;
    80001f5a:	0404b823          	sd	zero,80(s1)
  p->sz = 0;
    80001f5e:	0404b423          	sd	zero,72(s1)
  p->pid = 0;
    80001f62:	0204a823          	sw	zero,48(s1)
  p->parent = 0;
    80001f66:	0204bc23          	sd	zero,56(s1)
  p->name[0] = 0;
    80001f6a:	14048c23          	sb	zero,344(s1)
  p->chan = 0;
    80001f6e:	0204b023          	sd	zero,32(s1)
  p->killed = 0;
    80001f72:	0204a423          	sw	zero,40(s1)
  p->xstate = 0;
    80001f76:	0204a623          	sw	zero,44(s1)
  p->state = UNUSED;
    80001f7a:	0004ac23          	sw	zero,24(s1)
}
    80001f7e:	60e2                	ld	ra,24(sp)
    80001f80:	6442                	ld	s0,16(sp)
    80001f82:	64a2                	ld	s1,8(sp)
    80001f84:	6105                	addi	sp,sp,32
    80001f86:	8082                	ret

0000000080001f88 <allocproc>:
{
    80001f88:	1101                	addi	sp,sp,-32
    80001f8a:	ec06                	sd	ra,24(sp)
    80001f8c:	e822                	sd	s0,16(sp)
    80001f8e:	e426                	sd	s1,8(sp)
    80001f90:	e04a                	sd	s2,0(sp)
    80001f92:	1000                	addi	s0,sp,32
  for (p = proc; p < &proc[NPROC]; p++)
    80001f94:	0002f497          	auipc	s1,0x2f
    80001f98:	02c48493          	addi	s1,s1,44 # 80030fc0 <proc>
    80001f9c:	00035917          	auipc	s2,0x35
    80001fa0:	e2490913          	addi	s2,s2,-476 # 80036dc0 <tickslock>
    acquire(&p->lock);
    80001fa4:	8526                	mv	a0,s1
    80001fa6:	fffff097          	auipc	ra,0xfffff
    80001faa:	ee4080e7          	jalr	-284(ra) # 80000e8a <acquire>
    if (p->state == UNUSED)
    80001fae:	4c9c                	lw	a5,24(s1)
    80001fb0:	cf81                	beqz	a5,80001fc8 <allocproc+0x40>
      release(&p->lock);
    80001fb2:	8526                	mv	a0,s1
    80001fb4:	fffff097          	auipc	ra,0xfffff
    80001fb8:	f8a080e7          	jalr	-118(ra) # 80000f3e <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80001fbc:	17848493          	addi	s1,s1,376
    80001fc0:	ff2492e3          	bne	s1,s2,80001fa4 <allocproc+0x1c>
  return 0;
    80001fc4:	4481                	li	s1,0
    80001fc6:	a09d                	j	8000202c <allocproc+0xa4>
  p->pid = allocpid();
    80001fc8:	00000097          	auipc	ra,0x0
    80001fcc:	e34080e7          	jalr	-460(ra) # 80001dfc <allocpid>
    80001fd0:	d888                	sw	a0,48(s1)
  p->state = USED;
    80001fd2:	4785                	li	a5,1
    80001fd4:	cc9c                	sw	a5,24(s1)
  if ((p->trapframe = (struct trapframe *)kalloc()) == 0)
    80001fd6:	fffff097          	auipc	ra,0xfffff
    80001fda:	b6a080e7          	jalr	-1174(ra) # 80000b40 <kalloc>
    80001fde:	892a                	mv	s2,a0
    80001fe0:	eca8                	sd	a0,88(s1)
    80001fe2:	cd21                	beqz	a0,8000203a <allocproc+0xb2>
  p->pagetable = proc_pagetable(p);
    80001fe4:	8526                	mv	a0,s1
    80001fe6:	00000097          	auipc	ra,0x0
    80001fea:	e5c080e7          	jalr	-420(ra) # 80001e42 <proc_pagetable>
    80001fee:	892a                	mv	s2,a0
    80001ff0:	e8a8                	sd	a0,80(s1)
  if (p->pagetable == 0)
    80001ff2:	c125                	beqz	a0,80002052 <allocproc+0xca>
  memset(&p->context, 0, sizeof(p->context));
    80001ff4:	07000613          	li	a2,112
    80001ff8:	4581                	li	a1,0
    80001ffa:	06048513          	addi	a0,s1,96
    80001ffe:	fffff097          	auipc	ra,0xfffff
    80002002:	f88080e7          	jalr	-120(ra) # 80000f86 <memset>
  p->context.ra = (uint64)forkret;
    80002006:	00000797          	auipc	a5,0x0
    8000200a:	db078793          	addi	a5,a5,-592 # 80001db6 <forkret>
    8000200e:	f0bc                	sd	a5,96(s1)
  p->context.sp = p->kstack + PGSIZE;
    80002010:	60bc                	ld	a5,64(s1)
    80002012:	6705                	lui	a4,0x1
    80002014:	97ba                	add	a5,a5,a4
    80002016:	f4bc                	sd	a5,104(s1)
  p->rtime = 0;
    80002018:	1604a423          	sw	zero,360(s1)
  p->etime = 0;
    8000201c:	1604a823          	sw	zero,368(s1)
  p->ctime = ticks;
    80002020:	00007797          	auipc	a5,0x7
    80002024:	9007a783          	lw	a5,-1792(a5) # 80008920 <ticks>
    80002028:	16f4a623          	sw	a5,364(s1)
}
    8000202c:	8526                	mv	a0,s1
    8000202e:	60e2                	ld	ra,24(sp)
    80002030:	6442                	ld	s0,16(sp)
    80002032:	64a2                	ld	s1,8(sp)
    80002034:	6902                	ld	s2,0(sp)
    80002036:	6105                	addi	sp,sp,32
    80002038:	8082                	ret
    freeproc(p);
    8000203a:	8526                	mv	a0,s1
    8000203c:	00000097          	auipc	ra,0x0
    80002040:	ef4080e7          	jalr	-268(ra) # 80001f30 <freeproc>
    release(&p->lock);
    80002044:	8526                	mv	a0,s1
    80002046:	fffff097          	auipc	ra,0xfffff
    8000204a:	ef8080e7          	jalr	-264(ra) # 80000f3e <release>
    return 0;
    8000204e:	84ca                	mv	s1,s2
    80002050:	bff1                	j	8000202c <allocproc+0xa4>
    freeproc(p);
    80002052:	8526                	mv	a0,s1
    80002054:	00000097          	auipc	ra,0x0
    80002058:	edc080e7          	jalr	-292(ra) # 80001f30 <freeproc>
    release(&p->lock);
    8000205c:	8526                	mv	a0,s1
    8000205e:	fffff097          	auipc	ra,0xfffff
    80002062:	ee0080e7          	jalr	-288(ra) # 80000f3e <release>
    return 0;
    80002066:	84ca                	mv	s1,s2
    80002068:	b7d1                	j	8000202c <allocproc+0xa4>

000000008000206a <userinit>:
{
    8000206a:	1101                	addi	sp,sp,-32
    8000206c:	ec06                	sd	ra,24(sp)
    8000206e:	e822                	sd	s0,16(sp)
    80002070:	e426                	sd	s1,8(sp)
    80002072:	1000                	addi	s0,sp,32
  p = allocproc();
    80002074:	00000097          	auipc	ra,0x0
    80002078:	f14080e7          	jalr	-236(ra) # 80001f88 <allocproc>
    8000207c:	84aa                	mv	s1,a0
  initproc = p;
    8000207e:	00007797          	auipc	a5,0x7
    80002082:	88a7bd23          	sd	a0,-1894(a5) # 80008918 <initproc>
  uvmfirst(p->pagetable, initcode, sizeof(initcode));
    80002086:	03400613          	li	a2,52
    8000208a:	00007597          	auipc	a1,0x7
    8000208e:	82658593          	addi	a1,a1,-2010 # 800088b0 <initcode>
    80002092:	6928                	ld	a0,80(a0)
    80002094:	fffff097          	auipc	ra,0xfffff
    80002098:	576080e7          	jalr	1398(ra) # 8000160a <uvmfirst>
  p->sz = PGSIZE;
    8000209c:	6785                	lui	a5,0x1
    8000209e:	e4bc                	sd	a5,72(s1)
  p->trapframe->epc = 0;     // user program counter
    800020a0:	6cb8                	ld	a4,88(s1)
    800020a2:	00073c23          	sd	zero,24(a4) # 1018 <_entry-0x7fffefe8>
  p->trapframe->sp = PGSIZE; // user stack pointer
    800020a6:	6cb8                	ld	a4,88(s1)
    800020a8:	fb1c                	sd	a5,48(a4)
  safestrcpy(p->name, "initcode", sizeof(p->name));
    800020aa:	4641                	li	a2,16
    800020ac:	00006597          	auipc	a1,0x6
    800020b0:	17458593          	addi	a1,a1,372 # 80008220 <digits+0x1e0>
    800020b4:	15848513          	addi	a0,s1,344
    800020b8:	fffff097          	auipc	ra,0xfffff
    800020bc:	018080e7          	jalr	24(ra) # 800010d0 <safestrcpy>
  p->cwd = namei("/");
    800020c0:	00006517          	auipc	a0,0x6
    800020c4:	17050513          	addi	a0,a0,368 # 80008230 <digits+0x1f0>
    800020c8:	00002097          	auipc	ra,0x2
    800020cc:	3a8080e7          	jalr	936(ra) # 80004470 <namei>
    800020d0:	14a4b823          	sd	a0,336(s1)
  p->state = RUNNABLE;
    800020d4:	478d                	li	a5,3
    800020d6:	cc9c                	sw	a5,24(s1)
  release(&p->lock);
    800020d8:	8526                	mv	a0,s1
    800020da:	fffff097          	auipc	ra,0xfffff
    800020de:	e64080e7          	jalr	-412(ra) # 80000f3e <release>
}
    800020e2:	60e2                	ld	ra,24(sp)
    800020e4:	6442                	ld	s0,16(sp)
    800020e6:	64a2                	ld	s1,8(sp)
    800020e8:	6105                	addi	sp,sp,32
    800020ea:	8082                	ret

00000000800020ec <growproc>:
{
    800020ec:	1101                	addi	sp,sp,-32
    800020ee:	ec06                	sd	ra,24(sp)
    800020f0:	e822                	sd	s0,16(sp)
    800020f2:	e426                	sd	s1,8(sp)
    800020f4:	e04a                	sd	s2,0(sp)
    800020f6:	1000                	addi	s0,sp,32
    800020f8:	892a                	mv	s2,a0
  struct proc *p = myproc();
    800020fa:	00000097          	auipc	ra,0x0
    800020fe:	c84080e7          	jalr	-892(ra) # 80001d7e <myproc>
    80002102:	84aa                	mv	s1,a0
  sz = p->sz;
    80002104:	652c                	ld	a1,72(a0)
  if (n > 0)
    80002106:	01204c63          	bgtz	s2,8000211e <growproc+0x32>
  else if (n < 0)
    8000210a:	02094663          	bltz	s2,80002136 <growproc+0x4a>
  p->sz = sz;
    8000210e:	e4ac                	sd	a1,72(s1)
  return 0;
    80002110:	4501                	li	a0,0
}
    80002112:	60e2                	ld	ra,24(sp)
    80002114:	6442                	ld	s0,16(sp)
    80002116:	64a2                	ld	s1,8(sp)
    80002118:	6902                	ld	s2,0(sp)
    8000211a:	6105                	addi	sp,sp,32
    8000211c:	8082                	ret
    if ((sz = uvmalloc(p->pagetable, sz, sz + n, PTE_W)) == 0)
    8000211e:	4691                	li	a3,4
    80002120:	00b90633          	add	a2,s2,a1
    80002124:	6928                	ld	a0,80(a0)
    80002126:	fffff097          	auipc	ra,0xfffff
    8000212a:	59e080e7          	jalr	1438(ra) # 800016c4 <uvmalloc>
    8000212e:	85aa                	mv	a1,a0
    80002130:	fd79                	bnez	a0,8000210e <growproc+0x22>
      return -1;
    80002132:	557d                	li	a0,-1
    80002134:	bff9                	j	80002112 <growproc+0x26>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    80002136:	00b90633          	add	a2,s2,a1
    8000213a:	6928                	ld	a0,80(a0)
    8000213c:	fffff097          	auipc	ra,0xfffff
    80002140:	540080e7          	jalr	1344(ra) # 8000167c <uvmdealloc>
    80002144:	85aa                	mv	a1,a0
    80002146:	b7e1                	j	8000210e <growproc+0x22>

0000000080002148 <fork>:
{
    80002148:	7139                	addi	sp,sp,-64
    8000214a:	fc06                	sd	ra,56(sp)
    8000214c:	f822                	sd	s0,48(sp)
    8000214e:	f426                	sd	s1,40(sp)
    80002150:	f04a                	sd	s2,32(sp)
    80002152:	ec4e                	sd	s3,24(sp)
    80002154:	e852                	sd	s4,16(sp)
    80002156:	e456                	sd	s5,8(sp)
    80002158:	0080                	addi	s0,sp,64
  struct proc *p = myproc();
    8000215a:	00000097          	auipc	ra,0x0
    8000215e:	c24080e7          	jalr	-988(ra) # 80001d7e <myproc>
    80002162:	8aaa                	mv	s5,a0
  if ((np = allocproc()) == 0)
    80002164:	00000097          	auipc	ra,0x0
    80002168:	e24080e7          	jalr	-476(ra) # 80001f88 <allocproc>
    8000216c:	10050c63          	beqz	a0,80002284 <fork+0x13c>
    80002170:	8a2a                	mv	s4,a0
  if (uvmcopy(p->pagetable, np->pagetable, p->sz) < 0)
    80002172:	048ab603          	ld	a2,72(s5)
    80002176:	692c                	ld	a1,80(a0)
    80002178:	050ab503          	ld	a0,80(s5)
    8000217c:	fffff097          	auipc	ra,0xfffff
    80002180:	69c080e7          	jalr	1692(ra) # 80001818 <uvmcopy>
    80002184:	04054863          	bltz	a0,800021d4 <fork+0x8c>
  np->sz = p->sz;
    80002188:	048ab783          	ld	a5,72(s5)
    8000218c:	04fa3423          	sd	a5,72(s4)
  *(np->trapframe) = *(p->trapframe);
    80002190:	058ab683          	ld	a3,88(s5)
    80002194:	87b6                	mv	a5,a3
    80002196:	058a3703          	ld	a4,88(s4)
    8000219a:	12068693          	addi	a3,a3,288
    8000219e:	0007b803          	ld	a6,0(a5) # 1000 <_entry-0x7ffff000>
    800021a2:	6788                	ld	a0,8(a5)
    800021a4:	6b8c                	ld	a1,16(a5)
    800021a6:	6f90                	ld	a2,24(a5)
    800021a8:	01073023          	sd	a6,0(a4)
    800021ac:	e708                	sd	a0,8(a4)
    800021ae:	eb0c                	sd	a1,16(a4)
    800021b0:	ef10                	sd	a2,24(a4)
    800021b2:	02078793          	addi	a5,a5,32
    800021b6:	02070713          	addi	a4,a4,32
    800021ba:	fed792e3          	bne	a5,a3,8000219e <fork+0x56>
  np->trapframe->a0 = 0;
    800021be:	058a3783          	ld	a5,88(s4)
    800021c2:	0607b823          	sd	zero,112(a5)
  for (i = 0; i < NOFILE; i++)
    800021c6:	0d0a8493          	addi	s1,s5,208
    800021ca:	0d0a0913          	addi	s2,s4,208
    800021ce:	150a8993          	addi	s3,s5,336
    800021d2:	a00d                	j	800021f4 <fork+0xac>
    freeproc(np);
    800021d4:	8552                	mv	a0,s4
    800021d6:	00000097          	auipc	ra,0x0
    800021da:	d5a080e7          	jalr	-678(ra) # 80001f30 <freeproc>
    release(&np->lock);
    800021de:	8552                	mv	a0,s4
    800021e0:	fffff097          	auipc	ra,0xfffff
    800021e4:	d5e080e7          	jalr	-674(ra) # 80000f3e <release>
    return -1;
    800021e8:	597d                	li	s2,-1
    800021ea:	a059                	j	80002270 <fork+0x128>
  for (i = 0; i < NOFILE; i++)
    800021ec:	04a1                	addi	s1,s1,8
    800021ee:	0921                	addi	s2,s2,8
    800021f0:	01348b63          	beq	s1,s3,80002206 <fork+0xbe>
    if (p->ofile[i])
    800021f4:	6088                	ld	a0,0(s1)
    800021f6:	d97d                	beqz	a0,800021ec <fork+0xa4>
      np->ofile[i] = filedup(p->ofile[i]);
    800021f8:	00003097          	auipc	ra,0x3
    800021fc:	90e080e7          	jalr	-1778(ra) # 80004b06 <filedup>
    80002200:	00a93023          	sd	a0,0(s2)
    80002204:	b7e5                	j	800021ec <fork+0xa4>
  np->cwd = idup(p->cwd);
    80002206:	150ab503          	ld	a0,336(s5)
    8000220a:	00002097          	auipc	ra,0x2
    8000220e:	a82080e7          	jalr	-1406(ra) # 80003c8c <idup>
    80002212:	14aa3823          	sd	a0,336(s4)
  safestrcpy(np->name, p->name, sizeof(p->name));
    80002216:	4641                	li	a2,16
    80002218:	158a8593          	addi	a1,s5,344
    8000221c:	158a0513          	addi	a0,s4,344
    80002220:	fffff097          	auipc	ra,0xfffff
    80002224:	eb0080e7          	jalr	-336(ra) # 800010d0 <safestrcpy>
  pid = np->pid;
    80002228:	030a2903          	lw	s2,48(s4)
  release(&np->lock);
    8000222c:	8552                	mv	a0,s4
    8000222e:	fffff097          	auipc	ra,0xfffff
    80002232:	d10080e7          	jalr	-752(ra) # 80000f3e <release>
  acquire(&wait_lock);
    80002236:	0002f497          	auipc	s1,0x2f
    8000223a:	97248493          	addi	s1,s1,-1678 # 80030ba8 <wait_lock>
    8000223e:	8526                	mv	a0,s1
    80002240:	fffff097          	auipc	ra,0xfffff
    80002244:	c4a080e7          	jalr	-950(ra) # 80000e8a <acquire>
  np->parent = p;
    80002248:	035a3c23          	sd	s5,56(s4)
  release(&wait_lock);
    8000224c:	8526                	mv	a0,s1
    8000224e:	fffff097          	auipc	ra,0xfffff
    80002252:	cf0080e7          	jalr	-784(ra) # 80000f3e <release>
  acquire(&np->lock);
    80002256:	8552                	mv	a0,s4
    80002258:	fffff097          	auipc	ra,0xfffff
    8000225c:	c32080e7          	jalr	-974(ra) # 80000e8a <acquire>
  np->state = RUNNABLE;
    80002260:	478d                	li	a5,3
    80002262:	00fa2c23          	sw	a5,24(s4)
  release(&np->lock);
    80002266:	8552                	mv	a0,s4
    80002268:	fffff097          	auipc	ra,0xfffff
    8000226c:	cd6080e7          	jalr	-810(ra) # 80000f3e <release>
}
    80002270:	854a                	mv	a0,s2
    80002272:	70e2                	ld	ra,56(sp)
    80002274:	7442                	ld	s0,48(sp)
    80002276:	74a2                	ld	s1,40(sp)
    80002278:	7902                	ld	s2,32(sp)
    8000227a:	69e2                	ld	s3,24(sp)
    8000227c:	6a42                	ld	s4,16(sp)
    8000227e:	6aa2                	ld	s5,8(sp)
    80002280:	6121                	addi	sp,sp,64
    80002282:	8082                	ret
    return -1;
    80002284:	597d                	li	s2,-1
    80002286:	b7ed                	j	80002270 <fork+0x128>

0000000080002288 <scheduler>:
{
    80002288:	7139                	addi	sp,sp,-64
    8000228a:	fc06                	sd	ra,56(sp)
    8000228c:	f822                	sd	s0,48(sp)
    8000228e:	f426                	sd	s1,40(sp)
    80002290:	f04a                	sd	s2,32(sp)
    80002292:	ec4e                	sd	s3,24(sp)
    80002294:	e852                	sd	s4,16(sp)
    80002296:	e456                	sd	s5,8(sp)
    80002298:	e05a                	sd	s6,0(sp)
    8000229a:	0080                	addi	s0,sp,64
    8000229c:	8792                	mv	a5,tp
  int id = r_tp();
    8000229e:	2781                	sext.w	a5,a5
  c->proc = 0;
    800022a0:	00779a93          	slli	s5,a5,0x7
    800022a4:	0002f717          	auipc	a4,0x2f
    800022a8:	8ec70713          	addi	a4,a4,-1812 # 80030b90 <pid_lock>
    800022ac:	9756                	add	a4,a4,s5
    800022ae:	02073823          	sd	zero,48(a4)
        swtch(&c->context, &p->context);
    800022b2:	0002f717          	auipc	a4,0x2f
    800022b6:	91670713          	addi	a4,a4,-1770 # 80030bc8 <cpus+0x8>
    800022ba:	9aba                	add	s5,s5,a4
      if (p->state == RUNNABLE)
    800022bc:	498d                	li	s3,3
        p->state = RUNNING;
    800022be:	4b11                	li	s6,4
        c->proc = p;
    800022c0:	079e                	slli	a5,a5,0x7
    800022c2:	0002fa17          	auipc	s4,0x2f
    800022c6:	8cea0a13          	addi	s4,s4,-1842 # 80030b90 <pid_lock>
    800022ca:	9a3e                	add	s4,s4,a5
    for (p = proc; p < &proc[NPROC]; p++)
    800022cc:	00035917          	auipc	s2,0x35
    800022d0:	af490913          	addi	s2,s2,-1292 # 80036dc0 <tickslock>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800022d4:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    800022d8:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800022dc:	10079073          	csrw	sstatus,a5
    800022e0:	0002f497          	auipc	s1,0x2f
    800022e4:	ce048493          	addi	s1,s1,-800 # 80030fc0 <proc>
    800022e8:	a811                	j	800022fc <scheduler+0x74>
      release(&p->lock);
    800022ea:	8526                	mv	a0,s1
    800022ec:	fffff097          	auipc	ra,0xfffff
    800022f0:	c52080e7          	jalr	-942(ra) # 80000f3e <release>
    for (p = proc; p < &proc[NPROC]; p++)
    800022f4:	17848493          	addi	s1,s1,376
    800022f8:	fd248ee3          	beq	s1,s2,800022d4 <scheduler+0x4c>
      acquire(&p->lock);
    800022fc:	8526                	mv	a0,s1
    800022fe:	fffff097          	auipc	ra,0xfffff
    80002302:	b8c080e7          	jalr	-1140(ra) # 80000e8a <acquire>
      if (p->state == RUNNABLE)
    80002306:	4c9c                	lw	a5,24(s1)
    80002308:	ff3791e3          	bne	a5,s3,800022ea <scheduler+0x62>
        p->state = RUNNING;
    8000230c:	0164ac23          	sw	s6,24(s1)
        c->proc = p;
    80002310:	029a3823          	sd	s1,48(s4)
        swtch(&c->context, &p->context);
    80002314:	06048593          	addi	a1,s1,96
    80002318:	8556                	mv	a0,s5
    8000231a:	00001097          	auipc	ra,0x1
    8000231e:	838080e7          	jalr	-1992(ra) # 80002b52 <swtch>
        c->proc = 0;
    80002322:	020a3823          	sd	zero,48(s4)
    80002326:	b7d1                	j	800022ea <scheduler+0x62>

0000000080002328 <sched>:
{
    80002328:	7179                	addi	sp,sp,-48
    8000232a:	f406                	sd	ra,40(sp)
    8000232c:	f022                	sd	s0,32(sp)
    8000232e:	ec26                	sd	s1,24(sp)
    80002330:	e84a                	sd	s2,16(sp)
    80002332:	e44e                	sd	s3,8(sp)
    80002334:	1800                	addi	s0,sp,48
  struct proc *p = myproc();
    80002336:	00000097          	auipc	ra,0x0
    8000233a:	a48080e7          	jalr	-1464(ra) # 80001d7e <myproc>
    8000233e:	84aa                	mv	s1,a0
  if (!holding(&p->lock))
    80002340:	fffff097          	auipc	ra,0xfffff
    80002344:	ad0080e7          	jalr	-1328(ra) # 80000e10 <holding>
    80002348:	c93d                	beqz	a0,800023be <sched+0x96>
  asm volatile("mv %0, tp" : "=r" (x) );
    8000234a:	8792                	mv	a5,tp
  if (mycpu()->noff != 1)
    8000234c:	2781                	sext.w	a5,a5
    8000234e:	079e                	slli	a5,a5,0x7
    80002350:	0002f717          	auipc	a4,0x2f
    80002354:	84070713          	addi	a4,a4,-1984 # 80030b90 <pid_lock>
    80002358:	97ba                	add	a5,a5,a4
    8000235a:	0a87a703          	lw	a4,168(a5)
    8000235e:	4785                	li	a5,1
    80002360:	06f71763          	bne	a4,a5,800023ce <sched+0xa6>
  if (p->state == RUNNING)
    80002364:	4c98                	lw	a4,24(s1)
    80002366:	4791                	li	a5,4
    80002368:	06f70b63          	beq	a4,a5,800023de <sched+0xb6>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000236c:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002370:	8b89                	andi	a5,a5,2
  if (intr_get())
    80002372:	efb5                	bnez	a5,800023ee <sched+0xc6>
  asm volatile("mv %0, tp" : "=r" (x) );
    80002374:	8792                	mv	a5,tp
  intena = mycpu()->intena;
    80002376:	0002f917          	auipc	s2,0x2f
    8000237a:	81a90913          	addi	s2,s2,-2022 # 80030b90 <pid_lock>
    8000237e:	2781                	sext.w	a5,a5
    80002380:	079e                	slli	a5,a5,0x7
    80002382:	97ca                	add	a5,a5,s2
    80002384:	0ac7a983          	lw	s3,172(a5)
    80002388:	8792                	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    8000238a:	2781                	sext.w	a5,a5
    8000238c:	079e                	slli	a5,a5,0x7
    8000238e:	0002f597          	auipc	a1,0x2f
    80002392:	83a58593          	addi	a1,a1,-1990 # 80030bc8 <cpus+0x8>
    80002396:	95be                	add	a1,a1,a5
    80002398:	06048513          	addi	a0,s1,96
    8000239c:	00000097          	auipc	ra,0x0
    800023a0:	7b6080e7          	jalr	1974(ra) # 80002b52 <swtch>
    800023a4:	8792                	mv	a5,tp
  mycpu()->intena = intena;
    800023a6:	2781                	sext.w	a5,a5
    800023a8:	079e                	slli	a5,a5,0x7
    800023aa:	97ca                	add	a5,a5,s2
    800023ac:	0b37a623          	sw	s3,172(a5)
}
    800023b0:	70a2                	ld	ra,40(sp)
    800023b2:	7402                	ld	s0,32(sp)
    800023b4:	64e2                	ld	s1,24(sp)
    800023b6:	6942                	ld	s2,16(sp)
    800023b8:	69a2                	ld	s3,8(sp)
    800023ba:	6145                	addi	sp,sp,48
    800023bc:	8082                	ret
    panic("sched p->lock");
    800023be:	00006517          	auipc	a0,0x6
    800023c2:	e7a50513          	addi	a0,a0,-390 # 80008238 <digits+0x1f8>
    800023c6:	ffffe097          	auipc	ra,0xffffe
    800023ca:	178080e7          	jalr	376(ra) # 8000053e <panic>
    panic("sched locks");
    800023ce:	00006517          	auipc	a0,0x6
    800023d2:	e7a50513          	addi	a0,a0,-390 # 80008248 <digits+0x208>
    800023d6:	ffffe097          	auipc	ra,0xffffe
    800023da:	168080e7          	jalr	360(ra) # 8000053e <panic>
    panic("sched running");
    800023de:	00006517          	auipc	a0,0x6
    800023e2:	e7a50513          	addi	a0,a0,-390 # 80008258 <digits+0x218>
    800023e6:	ffffe097          	auipc	ra,0xffffe
    800023ea:	158080e7          	jalr	344(ra) # 8000053e <panic>
    panic("sched interruptible");
    800023ee:	00006517          	auipc	a0,0x6
    800023f2:	e7a50513          	addi	a0,a0,-390 # 80008268 <digits+0x228>
    800023f6:	ffffe097          	auipc	ra,0xffffe
    800023fa:	148080e7          	jalr	328(ra) # 8000053e <panic>

00000000800023fe <yield>:
{
    800023fe:	1101                	addi	sp,sp,-32
    80002400:	ec06                	sd	ra,24(sp)
    80002402:	e822                	sd	s0,16(sp)
    80002404:	e426                	sd	s1,8(sp)
    80002406:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    80002408:	00000097          	auipc	ra,0x0
    8000240c:	976080e7          	jalr	-1674(ra) # 80001d7e <myproc>
    80002410:	84aa                	mv	s1,a0
  acquire(&p->lock);
    80002412:	fffff097          	auipc	ra,0xfffff
    80002416:	a78080e7          	jalr	-1416(ra) # 80000e8a <acquire>
  p->state = RUNNABLE;
    8000241a:	478d                	li	a5,3
    8000241c:	cc9c                	sw	a5,24(s1)
  sched();
    8000241e:	00000097          	auipc	ra,0x0
    80002422:	f0a080e7          	jalr	-246(ra) # 80002328 <sched>
  release(&p->lock);
    80002426:	8526                	mv	a0,s1
    80002428:	fffff097          	auipc	ra,0xfffff
    8000242c:	b16080e7          	jalr	-1258(ra) # 80000f3e <release>
}
    80002430:	60e2                	ld	ra,24(sp)
    80002432:	6442                	ld	s0,16(sp)
    80002434:	64a2                	ld	s1,8(sp)
    80002436:	6105                	addi	sp,sp,32
    80002438:	8082                	ret

000000008000243a <sleep>:

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
void sleep(void *chan, struct spinlock *lk)
{
    8000243a:	7179                	addi	sp,sp,-48
    8000243c:	f406                	sd	ra,40(sp)
    8000243e:	f022                	sd	s0,32(sp)
    80002440:	ec26                	sd	s1,24(sp)
    80002442:	e84a                	sd	s2,16(sp)
    80002444:	e44e                	sd	s3,8(sp)
    80002446:	1800                	addi	s0,sp,48
    80002448:	89aa                	mv	s3,a0
    8000244a:	892e                	mv	s2,a1
  struct proc *p = myproc();
    8000244c:	00000097          	auipc	ra,0x0
    80002450:	932080e7          	jalr	-1742(ra) # 80001d7e <myproc>
    80002454:	84aa                	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock); // DOC: sleeplock1
    80002456:	fffff097          	auipc	ra,0xfffff
    8000245a:	a34080e7          	jalr	-1484(ra) # 80000e8a <acquire>
  release(lk);
    8000245e:	854a                	mv	a0,s2
    80002460:	fffff097          	auipc	ra,0xfffff
    80002464:	ade080e7          	jalr	-1314(ra) # 80000f3e <release>

  // Go to sleep.
  p->chan = chan;
    80002468:	0334b023          	sd	s3,32(s1)
  p->state = SLEEPING;
    8000246c:	4789                	li	a5,2
    8000246e:	cc9c                	sw	a5,24(s1)

  sched();
    80002470:	00000097          	auipc	ra,0x0
    80002474:	eb8080e7          	jalr	-328(ra) # 80002328 <sched>

  // Tidy up.
  p->chan = 0;
    80002478:	0204b023          	sd	zero,32(s1)

  // Reacquire original lock.
  release(&p->lock);
    8000247c:	8526                	mv	a0,s1
    8000247e:	fffff097          	auipc	ra,0xfffff
    80002482:	ac0080e7          	jalr	-1344(ra) # 80000f3e <release>
  acquire(lk);
    80002486:	854a                	mv	a0,s2
    80002488:	fffff097          	auipc	ra,0xfffff
    8000248c:	a02080e7          	jalr	-1534(ra) # 80000e8a <acquire>
}
    80002490:	70a2                	ld	ra,40(sp)
    80002492:	7402                	ld	s0,32(sp)
    80002494:	64e2                	ld	s1,24(sp)
    80002496:	6942                	ld	s2,16(sp)
    80002498:	69a2                	ld	s3,8(sp)
    8000249a:	6145                	addi	sp,sp,48
    8000249c:	8082                	ret

000000008000249e <wakeup>:

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
void wakeup(void *chan)
{
    8000249e:	7139                	addi	sp,sp,-64
    800024a0:	fc06                	sd	ra,56(sp)
    800024a2:	f822                	sd	s0,48(sp)
    800024a4:	f426                	sd	s1,40(sp)
    800024a6:	f04a                	sd	s2,32(sp)
    800024a8:	ec4e                	sd	s3,24(sp)
    800024aa:	e852                	sd	s4,16(sp)
    800024ac:	e456                	sd	s5,8(sp)
    800024ae:	0080                	addi	s0,sp,64
    800024b0:	8a2a                	mv	s4,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    800024b2:	0002f497          	auipc	s1,0x2f
    800024b6:	b0e48493          	addi	s1,s1,-1266 # 80030fc0 <proc>
  {
    if (p != myproc())
    {
      acquire(&p->lock);
      if (p->state == SLEEPING && p->chan == chan)
    800024ba:	4989                	li	s3,2
      {
        p->state = RUNNABLE;
    800024bc:	4a8d                	li	s5,3
  for (p = proc; p < &proc[NPROC]; p++)
    800024be:	00035917          	auipc	s2,0x35
    800024c2:	90290913          	addi	s2,s2,-1790 # 80036dc0 <tickslock>
    800024c6:	a811                	j	800024da <wakeup+0x3c>
      }
      release(&p->lock);
    800024c8:	8526                	mv	a0,s1
    800024ca:	fffff097          	auipc	ra,0xfffff
    800024ce:	a74080e7          	jalr	-1420(ra) # 80000f3e <release>
  for (p = proc; p < &proc[NPROC]; p++)
    800024d2:	17848493          	addi	s1,s1,376
    800024d6:	03248663          	beq	s1,s2,80002502 <wakeup+0x64>
    if (p != myproc())
    800024da:	00000097          	auipc	ra,0x0
    800024de:	8a4080e7          	jalr	-1884(ra) # 80001d7e <myproc>
    800024e2:	fea488e3          	beq	s1,a0,800024d2 <wakeup+0x34>
      acquire(&p->lock);
    800024e6:	8526                	mv	a0,s1
    800024e8:	fffff097          	auipc	ra,0xfffff
    800024ec:	9a2080e7          	jalr	-1630(ra) # 80000e8a <acquire>
      if (p->state == SLEEPING && p->chan == chan)
    800024f0:	4c9c                	lw	a5,24(s1)
    800024f2:	fd379be3          	bne	a5,s3,800024c8 <wakeup+0x2a>
    800024f6:	709c                	ld	a5,32(s1)
    800024f8:	fd4798e3          	bne	a5,s4,800024c8 <wakeup+0x2a>
        p->state = RUNNABLE;
    800024fc:	0154ac23          	sw	s5,24(s1)
    80002500:	b7e1                	j	800024c8 <wakeup+0x2a>
    }
  }
}
    80002502:	70e2                	ld	ra,56(sp)
    80002504:	7442                	ld	s0,48(sp)
    80002506:	74a2                	ld	s1,40(sp)
    80002508:	7902                	ld	s2,32(sp)
    8000250a:	69e2                	ld	s3,24(sp)
    8000250c:	6a42                	ld	s4,16(sp)
    8000250e:	6aa2                	ld	s5,8(sp)
    80002510:	6121                	addi	sp,sp,64
    80002512:	8082                	ret

0000000080002514 <reparent>:
{
    80002514:	7179                	addi	sp,sp,-48
    80002516:	f406                	sd	ra,40(sp)
    80002518:	f022                	sd	s0,32(sp)
    8000251a:	ec26                	sd	s1,24(sp)
    8000251c:	e84a                	sd	s2,16(sp)
    8000251e:	e44e                	sd	s3,8(sp)
    80002520:	e052                	sd	s4,0(sp)
    80002522:	1800                	addi	s0,sp,48
    80002524:	892a                	mv	s2,a0
  for (pp = proc; pp < &proc[NPROC]; pp++)
    80002526:	0002f497          	auipc	s1,0x2f
    8000252a:	a9a48493          	addi	s1,s1,-1382 # 80030fc0 <proc>
      pp->parent = initproc;
    8000252e:	00006a17          	auipc	s4,0x6
    80002532:	3eaa0a13          	addi	s4,s4,1002 # 80008918 <initproc>
  for (pp = proc; pp < &proc[NPROC]; pp++)
    80002536:	00035997          	auipc	s3,0x35
    8000253a:	88a98993          	addi	s3,s3,-1910 # 80036dc0 <tickslock>
    8000253e:	a029                	j	80002548 <reparent+0x34>
    80002540:	17848493          	addi	s1,s1,376
    80002544:	01348d63          	beq	s1,s3,8000255e <reparent+0x4a>
    if (pp->parent == p)
    80002548:	7c9c                	ld	a5,56(s1)
    8000254a:	ff279be3          	bne	a5,s2,80002540 <reparent+0x2c>
      pp->parent = initproc;
    8000254e:	000a3503          	ld	a0,0(s4)
    80002552:	fc88                	sd	a0,56(s1)
      wakeup(initproc);
    80002554:	00000097          	auipc	ra,0x0
    80002558:	f4a080e7          	jalr	-182(ra) # 8000249e <wakeup>
    8000255c:	b7d5                	j	80002540 <reparent+0x2c>
}
    8000255e:	70a2                	ld	ra,40(sp)
    80002560:	7402                	ld	s0,32(sp)
    80002562:	64e2                	ld	s1,24(sp)
    80002564:	6942                	ld	s2,16(sp)
    80002566:	69a2                	ld	s3,8(sp)
    80002568:	6a02                	ld	s4,0(sp)
    8000256a:	6145                	addi	sp,sp,48
    8000256c:	8082                	ret

000000008000256e <exit>:
{
    8000256e:	7179                	addi	sp,sp,-48
    80002570:	f406                	sd	ra,40(sp)
    80002572:	f022                	sd	s0,32(sp)
    80002574:	ec26                	sd	s1,24(sp)
    80002576:	e84a                	sd	s2,16(sp)
    80002578:	e44e                	sd	s3,8(sp)
    8000257a:	e052                	sd	s4,0(sp)
    8000257c:	1800                	addi	s0,sp,48
    8000257e:	8a2a                	mv	s4,a0
  struct proc *p = myproc();
    80002580:	fffff097          	auipc	ra,0xfffff
    80002584:	7fe080e7          	jalr	2046(ra) # 80001d7e <myproc>
    80002588:	89aa                	mv	s3,a0
  if (p == initproc)
    8000258a:	00006797          	auipc	a5,0x6
    8000258e:	38e7b783          	ld	a5,910(a5) # 80008918 <initproc>
    80002592:	0d050493          	addi	s1,a0,208
    80002596:	15050913          	addi	s2,a0,336
    8000259a:	02a79363          	bne	a5,a0,800025c0 <exit+0x52>
    panic("init exiting");
    8000259e:	00006517          	auipc	a0,0x6
    800025a2:	ce250513          	addi	a0,a0,-798 # 80008280 <digits+0x240>
    800025a6:	ffffe097          	auipc	ra,0xffffe
    800025aa:	f98080e7          	jalr	-104(ra) # 8000053e <panic>
      fileclose(f);
    800025ae:	00002097          	auipc	ra,0x2
    800025b2:	5aa080e7          	jalr	1450(ra) # 80004b58 <fileclose>
      p->ofile[fd] = 0;
    800025b6:	0004b023          	sd	zero,0(s1)
  for (int fd = 0; fd < NOFILE; fd++)
    800025ba:	04a1                	addi	s1,s1,8
    800025bc:	01248563          	beq	s1,s2,800025c6 <exit+0x58>
    if (p->ofile[fd])
    800025c0:	6088                	ld	a0,0(s1)
    800025c2:	f575                	bnez	a0,800025ae <exit+0x40>
    800025c4:	bfdd                	j	800025ba <exit+0x4c>
  begin_op();
    800025c6:	00002097          	auipc	ra,0x2
    800025ca:	0c6080e7          	jalr	198(ra) # 8000468c <begin_op>
  iput(p->cwd);
    800025ce:	1509b503          	ld	a0,336(s3)
    800025d2:	00002097          	auipc	ra,0x2
    800025d6:	8b2080e7          	jalr	-1870(ra) # 80003e84 <iput>
  end_op();
    800025da:	00002097          	auipc	ra,0x2
    800025de:	132080e7          	jalr	306(ra) # 8000470c <end_op>
  p->cwd = 0;
    800025e2:	1409b823          	sd	zero,336(s3)
  acquire(&wait_lock);
    800025e6:	0002e497          	auipc	s1,0x2e
    800025ea:	5c248493          	addi	s1,s1,1474 # 80030ba8 <wait_lock>
    800025ee:	8526                	mv	a0,s1
    800025f0:	fffff097          	auipc	ra,0xfffff
    800025f4:	89a080e7          	jalr	-1894(ra) # 80000e8a <acquire>
  reparent(p);
    800025f8:	854e                	mv	a0,s3
    800025fa:	00000097          	auipc	ra,0x0
    800025fe:	f1a080e7          	jalr	-230(ra) # 80002514 <reparent>
  wakeup(p->parent);
    80002602:	0389b503          	ld	a0,56(s3)
    80002606:	00000097          	auipc	ra,0x0
    8000260a:	e98080e7          	jalr	-360(ra) # 8000249e <wakeup>
  acquire(&p->lock);
    8000260e:	854e                	mv	a0,s3
    80002610:	fffff097          	auipc	ra,0xfffff
    80002614:	87a080e7          	jalr	-1926(ra) # 80000e8a <acquire>
  p->xstate = status;
    80002618:	0349a623          	sw	s4,44(s3)
  p->state = ZOMBIE;
    8000261c:	4795                	li	a5,5
    8000261e:	00f9ac23          	sw	a5,24(s3)
  p->etime = ticks;
    80002622:	00006797          	auipc	a5,0x6
    80002626:	2fe7a783          	lw	a5,766(a5) # 80008920 <ticks>
    8000262a:	16f9a823          	sw	a5,368(s3)
  release(&wait_lock);
    8000262e:	8526                	mv	a0,s1
    80002630:	fffff097          	auipc	ra,0xfffff
    80002634:	90e080e7          	jalr	-1778(ra) # 80000f3e <release>
  sched();
    80002638:	00000097          	auipc	ra,0x0
    8000263c:	cf0080e7          	jalr	-784(ra) # 80002328 <sched>
  panic("zombie exit");
    80002640:	00006517          	auipc	a0,0x6
    80002644:	c5050513          	addi	a0,a0,-944 # 80008290 <digits+0x250>
    80002648:	ffffe097          	auipc	ra,0xffffe
    8000264c:	ef6080e7          	jalr	-266(ra) # 8000053e <panic>

0000000080002650 <kill>:

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int kill(int pid)
{
    80002650:	7179                	addi	sp,sp,-48
    80002652:	f406                	sd	ra,40(sp)
    80002654:	f022                	sd	s0,32(sp)
    80002656:	ec26                	sd	s1,24(sp)
    80002658:	e84a                	sd	s2,16(sp)
    8000265a:	e44e                	sd	s3,8(sp)
    8000265c:	1800                	addi	s0,sp,48
    8000265e:	892a                	mv	s2,a0
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++)
    80002660:	0002f497          	auipc	s1,0x2f
    80002664:	96048493          	addi	s1,s1,-1696 # 80030fc0 <proc>
    80002668:	00034997          	auipc	s3,0x34
    8000266c:	75898993          	addi	s3,s3,1880 # 80036dc0 <tickslock>
  {
    acquire(&p->lock);
    80002670:	8526                	mv	a0,s1
    80002672:	fffff097          	auipc	ra,0xfffff
    80002676:	818080e7          	jalr	-2024(ra) # 80000e8a <acquire>
    if (p->pid == pid)
    8000267a:	589c                	lw	a5,48(s1)
    8000267c:	01278d63          	beq	a5,s2,80002696 <kill+0x46>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    80002680:	8526                	mv	a0,s1
    80002682:	fffff097          	auipc	ra,0xfffff
    80002686:	8bc080e7          	jalr	-1860(ra) # 80000f3e <release>
  for (p = proc; p < &proc[NPROC]; p++)
    8000268a:	17848493          	addi	s1,s1,376
    8000268e:	ff3491e3          	bne	s1,s3,80002670 <kill+0x20>
  }
  return -1;
    80002692:	557d                	li	a0,-1
    80002694:	a829                	j	800026ae <kill+0x5e>
      p->killed = 1;
    80002696:	4785                	li	a5,1
    80002698:	d49c                	sw	a5,40(s1)
      if (p->state == SLEEPING)
    8000269a:	4c98                	lw	a4,24(s1)
    8000269c:	4789                	li	a5,2
    8000269e:	00f70f63          	beq	a4,a5,800026bc <kill+0x6c>
      release(&p->lock);
    800026a2:	8526                	mv	a0,s1
    800026a4:	fffff097          	auipc	ra,0xfffff
    800026a8:	89a080e7          	jalr	-1894(ra) # 80000f3e <release>
      return 0;
    800026ac:	4501                	li	a0,0
}
    800026ae:	70a2                	ld	ra,40(sp)
    800026b0:	7402                	ld	s0,32(sp)
    800026b2:	64e2                	ld	s1,24(sp)
    800026b4:	6942                	ld	s2,16(sp)
    800026b6:	69a2                	ld	s3,8(sp)
    800026b8:	6145                	addi	sp,sp,48
    800026ba:	8082                	ret
        p->state = RUNNABLE;
    800026bc:	478d                	li	a5,3
    800026be:	cc9c                	sw	a5,24(s1)
    800026c0:	b7cd                	j	800026a2 <kill+0x52>

00000000800026c2 <setkilled>:

void setkilled(struct proc *p)
{
    800026c2:	1101                	addi	sp,sp,-32
    800026c4:	ec06                	sd	ra,24(sp)
    800026c6:	e822                	sd	s0,16(sp)
    800026c8:	e426                	sd	s1,8(sp)
    800026ca:	1000                	addi	s0,sp,32
    800026cc:	84aa                	mv	s1,a0
  acquire(&p->lock);
    800026ce:	ffffe097          	auipc	ra,0xffffe
    800026d2:	7bc080e7          	jalr	1980(ra) # 80000e8a <acquire>
  p->killed = 1;
    800026d6:	4785                	li	a5,1
    800026d8:	d49c                	sw	a5,40(s1)
  release(&p->lock);
    800026da:	8526                	mv	a0,s1
    800026dc:	fffff097          	auipc	ra,0xfffff
    800026e0:	862080e7          	jalr	-1950(ra) # 80000f3e <release>
}
    800026e4:	60e2                	ld	ra,24(sp)
    800026e6:	6442                	ld	s0,16(sp)
    800026e8:	64a2                	ld	s1,8(sp)
    800026ea:	6105                	addi	sp,sp,32
    800026ec:	8082                	ret

00000000800026ee <killed>:

int killed(struct proc *p)
{
    800026ee:	1101                	addi	sp,sp,-32
    800026f0:	ec06                	sd	ra,24(sp)
    800026f2:	e822                	sd	s0,16(sp)
    800026f4:	e426                	sd	s1,8(sp)
    800026f6:	e04a                	sd	s2,0(sp)
    800026f8:	1000                	addi	s0,sp,32
    800026fa:	84aa                	mv	s1,a0
  int k;

  acquire(&p->lock);
    800026fc:	ffffe097          	auipc	ra,0xffffe
    80002700:	78e080e7          	jalr	1934(ra) # 80000e8a <acquire>
  k = p->killed;
    80002704:	0284a903          	lw	s2,40(s1)
  release(&p->lock);
    80002708:	8526                	mv	a0,s1
    8000270a:	fffff097          	auipc	ra,0xfffff
    8000270e:	834080e7          	jalr	-1996(ra) # 80000f3e <release>
  return k;
}
    80002712:	854a                	mv	a0,s2
    80002714:	60e2                	ld	ra,24(sp)
    80002716:	6442                	ld	s0,16(sp)
    80002718:	64a2                	ld	s1,8(sp)
    8000271a:	6902                	ld	s2,0(sp)
    8000271c:	6105                	addi	sp,sp,32
    8000271e:	8082                	ret

0000000080002720 <wait>:
{
    80002720:	715d                	addi	sp,sp,-80
    80002722:	e486                	sd	ra,72(sp)
    80002724:	e0a2                	sd	s0,64(sp)
    80002726:	fc26                	sd	s1,56(sp)
    80002728:	f84a                	sd	s2,48(sp)
    8000272a:	f44e                	sd	s3,40(sp)
    8000272c:	f052                	sd	s4,32(sp)
    8000272e:	ec56                	sd	s5,24(sp)
    80002730:	e85a                	sd	s6,16(sp)
    80002732:	e45e                	sd	s7,8(sp)
    80002734:	e062                	sd	s8,0(sp)
    80002736:	0880                	addi	s0,sp,80
    80002738:	8b2a                	mv	s6,a0
  struct proc *p = myproc();
    8000273a:	fffff097          	auipc	ra,0xfffff
    8000273e:	644080e7          	jalr	1604(ra) # 80001d7e <myproc>
    80002742:	892a                	mv	s2,a0
  acquire(&wait_lock);
    80002744:	0002e517          	auipc	a0,0x2e
    80002748:	46450513          	addi	a0,a0,1124 # 80030ba8 <wait_lock>
    8000274c:	ffffe097          	auipc	ra,0xffffe
    80002750:	73e080e7          	jalr	1854(ra) # 80000e8a <acquire>
    havekids = 0;
    80002754:	4b81                	li	s7,0
        if (pp->state == ZOMBIE)
    80002756:	4a15                	li	s4,5
        havekids = 1;
    80002758:	4a85                	li	s5,1
    for (pp = proc; pp < &proc[NPROC]; pp++)
    8000275a:	00034997          	auipc	s3,0x34
    8000275e:	66698993          	addi	s3,s3,1638 # 80036dc0 <tickslock>
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002762:	0002ec17          	auipc	s8,0x2e
    80002766:	446c0c13          	addi	s8,s8,1094 # 80030ba8 <wait_lock>
    havekids = 0;
    8000276a:	875e                	mv	a4,s7
    for (pp = proc; pp < &proc[NPROC]; pp++)
    8000276c:	0002f497          	auipc	s1,0x2f
    80002770:	85448493          	addi	s1,s1,-1964 # 80030fc0 <proc>
    80002774:	a0bd                	j	800027e2 <wait+0xc2>
          pid = pp->pid;
    80002776:	0304a983          	lw	s3,48(s1)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&pp->xstate,
    8000277a:	000b0e63          	beqz	s6,80002796 <wait+0x76>
    8000277e:	4691                	li	a3,4
    80002780:	02c48613          	addi	a2,s1,44
    80002784:	85da                	mv	a1,s6
    80002786:	05093503          	ld	a0,80(s2)
    8000278a:	fffff097          	auipc	ra,0xfffff
    8000278e:	3a8080e7          	jalr	936(ra) # 80001b32 <copyout>
    80002792:	02054563          	bltz	a0,800027bc <wait+0x9c>
          freeproc(pp);
    80002796:	8526                	mv	a0,s1
    80002798:	fffff097          	auipc	ra,0xfffff
    8000279c:	798080e7          	jalr	1944(ra) # 80001f30 <freeproc>
          release(&pp->lock);
    800027a0:	8526                	mv	a0,s1
    800027a2:	ffffe097          	auipc	ra,0xffffe
    800027a6:	79c080e7          	jalr	1948(ra) # 80000f3e <release>
          release(&wait_lock);
    800027aa:	0002e517          	auipc	a0,0x2e
    800027ae:	3fe50513          	addi	a0,a0,1022 # 80030ba8 <wait_lock>
    800027b2:	ffffe097          	auipc	ra,0xffffe
    800027b6:	78c080e7          	jalr	1932(ra) # 80000f3e <release>
          return pid;
    800027ba:	a0b5                	j	80002826 <wait+0x106>
            release(&pp->lock);
    800027bc:	8526                	mv	a0,s1
    800027be:	ffffe097          	auipc	ra,0xffffe
    800027c2:	780080e7          	jalr	1920(ra) # 80000f3e <release>
            release(&wait_lock);
    800027c6:	0002e517          	auipc	a0,0x2e
    800027ca:	3e250513          	addi	a0,a0,994 # 80030ba8 <wait_lock>
    800027ce:	ffffe097          	auipc	ra,0xffffe
    800027d2:	770080e7          	jalr	1904(ra) # 80000f3e <release>
            return -1;
    800027d6:	59fd                	li	s3,-1
    800027d8:	a0b9                	j	80002826 <wait+0x106>
    for (pp = proc; pp < &proc[NPROC]; pp++)
    800027da:	17848493          	addi	s1,s1,376
    800027de:	03348463          	beq	s1,s3,80002806 <wait+0xe6>
      if (pp->parent == p)
    800027e2:	7c9c                	ld	a5,56(s1)
    800027e4:	ff279be3          	bne	a5,s2,800027da <wait+0xba>
        acquire(&pp->lock);
    800027e8:	8526                	mv	a0,s1
    800027ea:	ffffe097          	auipc	ra,0xffffe
    800027ee:	6a0080e7          	jalr	1696(ra) # 80000e8a <acquire>
        if (pp->state == ZOMBIE)
    800027f2:	4c9c                	lw	a5,24(s1)
    800027f4:	f94781e3          	beq	a5,s4,80002776 <wait+0x56>
        release(&pp->lock);
    800027f8:	8526                	mv	a0,s1
    800027fa:	ffffe097          	auipc	ra,0xffffe
    800027fe:	744080e7          	jalr	1860(ra) # 80000f3e <release>
        havekids = 1;
    80002802:	8756                	mv	a4,s5
    80002804:	bfd9                	j	800027da <wait+0xba>
    if (!havekids || killed(p))
    80002806:	c719                	beqz	a4,80002814 <wait+0xf4>
    80002808:	854a                	mv	a0,s2
    8000280a:	00000097          	auipc	ra,0x0
    8000280e:	ee4080e7          	jalr	-284(ra) # 800026ee <killed>
    80002812:	c51d                	beqz	a0,80002840 <wait+0x120>
      release(&wait_lock);
    80002814:	0002e517          	auipc	a0,0x2e
    80002818:	39450513          	addi	a0,a0,916 # 80030ba8 <wait_lock>
    8000281c:	ffffe097          	auipc	ra,0xffffe
    80002820:	722080e7          	jalr	1826(ra) # 80000f3e <release>
      return -1;
    80002824:	59fd                	li	s3,-1
}
    80002826:	854e                	mv	a0,s3
    80002828:	60a6                	ld	ra,72(sp)
    8000282a:	6406                	ld	s0,64(sp)
    8000282c:	74e2                	ld	s1,56(sp)
    8000282e:	7942                	ld	s2,48(sp)
    80002830:	79a2                	ld	s3,40(sp)
    80002832:	7a02                	ld	s4,32(sp)
    80002834:	6ae2                	ld	s5,24(sp)
    80002836:	6b42                	ld	s6,16(sp)
    80002838:	6ba2                	ld	s7,8(sp)
    8000283a:	6c02                	ld	s8,0(sp)
    8000283c:	6161                	addi	sp,sp,80
    8000283e:	8082                	ret
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002840:	85e2                	mv	a1,s8
    80002842:	854a                	mv	a0,s2
    80002844:	00000097          	auipc	ra,0x0
    80002848:	bf6080e7          	jalr	-1034(ra) # 8000243a <sleep>
    havekids = 0;
    8000284c:	bf39                	j	8000276a <wait+0x4a>

000000008000284e <either_copyout>:

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    8000284e:	7179                	addi	sp,sp,-48
    80002850:	f406                	sd	ra,40(sp)
    80002852:	f022                	sd	s0,32(sp)
    80002854:	ec26                	sd	s1,24(sp)
    80002856:	e84a                	sd	s2,16(sp)
    80002858:	e44e                	sd	s3,8(sp)
    8000285a:	e052                	sd	s4,0(sp)
    8000285c:	1800                	addi	s0,sp,48
    8000285e:	84aa                	mv	s1,a0
    80002860:	892e                	mv	s2,a1
    80002862:	89b2                	mv	s3,a2
    80002864:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    80002866:	fffff097          	auipc	ra,0xfffff
    8000286a:	518080e7          	jalr	1304(ra) # 80001d7e <myproc>
  if (user_dst)
    8000286e:	c08d                	beqz	s1,80002890 <either_copyout+0x42>
  {
    return copyout(p->pagetable, dst, src, len);
    80002870:	86d2                	mv	a3,s4
    80002872:	864e                	mv	a2,s3
    80002874:	85ca                	mv	a1,s2
    80002876:	6928                	ld	a0,80(a0)
    80002878:	fffff097          	auipc	ra,0xfffff
    8000287c:	2ba080e7          	jalr	698(ra) # 80001b32 <copyout>
  else
  {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    80002880:	70a2                	ld	ra,40(sp)
    80002882:	7402                	ld	s0,32(sp)
    80002884:	64e2                	ld	s1,24(sp)
    80002886:	6942                	ld	s2,16(sp)
    80002888:	69a2                	ld	s3,8(sp)
    8000288a:	6a02                	ld	s4,0(sp)
    8000288c:	6145                	addi	sp,sp,48
    8000288e:	8082                	ret
    memmove((char *)dst, src, len);
    80002890:	000a061b          	sext.w	a2,s4
    80002894:	85ce                	mv	a1,s3
    80002896:	854a                	mv	a0,s2
    80002898:	ffffe097          	auipc	ra,0xffffe
    8000289c:	74a080e7          	jalr	1866(ra) # 80000fe2 <memmove>
    return 0;
    800028a0:	8526                	mv	a0,s1
    800028a2:	bff9                	j	80002880 <either_copyout+0x32>

00000000800028a4 <either_copyin>:

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    800028a4:	7179                	addi	sp,sp,-48
    800028a6:	f406                	sd	ra,40(sp)
    800028a8:	f022                	sd	s0,32(sp)
    800028aa:	ec26                	sd	s1,24(sp)
    800028ac:	e84a                	sd	s2,16(sp)
    800028ae:	e44e                	sd	s3,8(sp)
    800028b0:	e052                	sd	s4,0(sp)
    800028b2:	1800                	addi	s0,sp,48
    800028b4:	892a                	mv	s2,a0
    800028b6:	84ae                	mv	s1,a1
    800028b8:	89b2                	mv	s3,a2
    800028ba:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    800028bc:	fffff097          	auipc	ra,0xfffff
    800028c0:	4c2080e7          	jalr	1218(ra) # 80001d7e <myproc>
  if (user_src)
    800028c4:	c08d                	beqz	s1,800028e6 <either_copyin+0x42>
  {
    return copyin(p->pagetable, dst, src, len);
    800028c6:	86d2                	mv	a3,s4
    800028c8:	864e                	mv	a2,s3
    800028ca:	85ca                	mv	a1,s2
    800028cc:	6928                	ld	a0,80(a0)
    800028ce:	fffff097          	auipc	ra,0xfffff
    800028d2:	058080e7          	jalr	88(ra) # 80001926 <copyin>
  else
  {
    memmove(dst, (char *)src, len);
    return 0;
  }
}
    800028d6:	70a2                	ld	ra,40(sp)
    800028d8:	7402                	ld	s0,32(sp)
    800028da:	64e2                	ld	s1,24(sp)
    800028dc:	6942                	ld	s2,16(sp)
    800028de:	69a2                	ld	s3,8(sp)
    800028e0:	6a02                	ld	s4,0(sp)
    800028e2:	6145                	addi	sp,sp,48
    800028e4:	8082                	ret
    memmove(dst, (char *)src, len);
    800028e6:	000a061b          	sext.w	a2,s4
    800028ea:	85ce                	mv	a1,s3
    800028ec:	854a                	mv	a0,s2
    800028ee:	ffffe097          	auipc	ra,0xffffe
    800028f2:	6f4080e7          	jalr	1780(ra) # 80000fe2 <memmove>
    return 0;
    800028f6:	8526                	mv	a0,s1
    800028f8:	bff9                	j	800028d6 <either_copyin+0x32>

00000000800028fa <procdump>:

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void procdump(void)
{
    800028fa:	715d                	addi	sp,sp,-80
    800028fc:	e486                	sd	ra,72(sp)
    800028fe:	e0a2                	sd	s0,64(sp)
    80002900:	fc26                	sd	s1,56(sp)
    80002902:	f84a                	sd	s2,48(sp)
    80002904:	f44e                	sd	s3,40(sp)
    80002906:	f052                	sd	s4,32(sp)
    80002908:	ec56                	sd	s5,24(sp)
    8000290a:	e85a                	sd	s6,16(sp)
    8000290c:	e45e                	sd	s7,8(sp)
    8000290e:	0880                	addi	s0,sp,80
      [RUNNING] "run   ",
      [ZOMBIE] "zombie"};
  struct proc *p;
  char *state;

  printf("\n");
    80002910:	00005517          	auipc	a0,0x5
    80002914:	7d850513          	addi	a0,a0,2008 # 800080e8 <digits+0xa8>
    80002918:	ffffe097          	auipc	ra,0xffffe
    8000291c:	c70080e7          	jalr	-912(ra) # 80000588 <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    80002920:	0002e497          	auipc	s1,0x2e
    80002924:	7f848493          	addi	s1,s1,2040 # 80031118 <proc+0x158>
    80002928:	00034917          	auipc	s2,0x34
    8000292c:	5f090913          	addi	s2,s2,1520 # 80036f18 <bcache+0x140>
  {
    if (p->state == UNUSED)
      continue;
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002930:	4b15                	li	s6,5
      state = states[p->state];
    else
      state = "???";
    80002932:	00006997          	auipc	s3,0x6
    80002936:	96e98993          	addi	s3,s3,-1682 # 800082a0 <digits+0x260>
    printf("%d %s %s", p->pid, state, p->name);
    8000293a:	00006a97          	auipc	s5,0x6
    8000293e:	96ea8a93          	addi	s5,s5,-1682 # 800082a8 <digits+0x268>
    printf("\n");
    80002942:	00005a17          	auipc	s4,0x5
    80002946:	7a6a0a13          	addi	s4,s4,1958 # 800080e8 <digits+0xa8>
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000294a:	00006b97          	auipc	s7,0x6
    8000294e:	99eb8b93          	addi	s7,s7,-1634 # 800082e8 <states.0>
    80002952:	a00d                	j	80002974 <procdump+0x7a>
    printf("%d %s %s", p->pid, state, p->name);
    80002954:	ed86a583          	lw	a1,-296(a3)
    80002958:	8556                	mv	a0,s5
    8000295a:	ffffe097          	auipc	ra,0xffffe
    8000295e:	c2e080e7          	jalr	-978(ra) # 80000588 <printf>
    printf("\n");
    80002962:	8552                	mv	a0,s4
    80002964:	ffffe097          	auipc	ra,0xffffe
    80002968:	c24080e7          	jalr	-988(ra) # 80000588 <printf>
  for (p = proc; p < &proc[NPROC]; p++)
    8000296c:	17848493          	addi	s1,s1,376
    80002970:	03248163          	beq	s1,s2,80002992 <procdump+0x98>
    if (p->state == UNUSED)
    80002974:	86a6                	mv	a3,s1
    80002976:	ec04a783          	lw	a5,-320(s1)
    8000297a:	dbed                	beqz	a5,8000296c <procdump+0x72>
      state = "???";
    8000297c:	864e                	mv	a2,s3
    if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000297e:	fcfb6be3          	bltu	s6,a5,80002954 <procdump+0x5a>
    80002982:	1782                	slli	a5,a5,0x20
    80002984:	9381                	srli	a5,a5,0x20
    80002986:	078e                	slli	a5,a5,0x3
    80002988:	97de                	add	a5,a5,s7
    8000298a:	6390                	ld	a2,0(a5)
    8000298c:	f661                	bnez	a2,80002954 <procdump+0x5a>
      state = "???";
    8000298e:	864e                	mv	a2,s3
    80002990:	b7d1                	j	80002954 <procdump+0x5a>
  }
}
    80002992:	60a6                	ld	ra,72(sp)
    80002994:	6406                	ld	s0,64(sp)
    80002996:	74e2                	ld	s1,56(sp)
    80002998:	7942                	ld	s2,48(sp)
    8000299a:	79a2                	ld	s3,40(sp)
    8000299c:	7a02                	ld	s4,32(sp)
    8000299e:	6ae2                	ld	s5,24(sp)
    800029a0:	6b42                	ld	s6,16(sp)
    800029a2:	6ba2                	ld	s7,8(sp)
    800029a4:	6161                	addi	sp,sp,80
    800029a6:	8082                	ret

00000000800029a8 <waitx>:

// waitx
int waitx(uint64 addr, uint *wtime, uint *rtime)
{
    800029a8:	711d                	addi	sp,sp,-96
    800029aa:	ec86                	sd	ra,88(sp)
    800029ac:	e8a2                	sd	s0,80(sp)
    800029ae:	e4a6                	sd	s1,72(sp)
    800029b0:	e0ca                	sd	s2,64(sp)
    800029b2:	fc4e                	sd	s3,56(sp)
    800029b4:	f852                	sd	s4,48(sp)
    800029b6:	f456                	sd	s5,40(sp)
    800029b8:	f05a                	sd	s6,32(sp)
    800029ba:	ec5e                	sd	s7,24(sp)
    800029bc:	e862                	sd	s8,16(sp)
    800029be:	e466                	sd	s9,8(sp)
    800029c0:	e06a                	sd	s10,0(sp)
    800029c2:	1080                	addi	s0,sp,96
    800029c4:	8b2a                	mv	s6,a0
    800029c6:	8bae                	mv	s7,a1
    800029c8:	8c32                	mv	s8,a2
  struct proc *np;
  int havekids, pid;
  struct proc *p = myproc();
    800029ca:	fffff097          	auipc	ra,0xfffff
    800029ce:	3b4080e7          	jalr	948(ra) # 80001d7e <myproc>
    800029d2:	892a                	mv	s2,a0

  acquire(&wait_lock);
    800029d4:	0002e517          	auipc	a0,0x2e
    800029d8:	1d450513          	addi	a0,a0,468 # 80030ba8 <wait_lock>
    800029dc:	ffffe097          	auipc	ra,0xffffe
    800029e0:	4ae080e7          	jalr	1198(ra) # 80000e8a <acquire>

  for (;;)
  {
    // Scan through table looking for exited children.
    havekids = 0;
    800029e4:	4c81                	li	s9,0
      {
        // make sure the child isn't still in exit() or swtch().
        acquire(&np->lock);

        havekids = 1;
        if (np->state == ZOMBIE)
    800029e6:	4a15                	li	s4,5
        havekids = 1;
    800029e8:	4a85                	li	s5,1
    for (np = proc; np < &proc[NPROC]; np++)
    800029ea:	00034997          	auipc	s3,0x34
    800029ee:	3d698993          	addi	s3,s3,982 # 80036dc0 <tickslock>
      release(&wait_lock);
      return -1;
    }

    // Wait for a child to exit.
    sleep(p, &wait_lock); // DOC: wait-sleep
    800029f2:	0002ed17          	auipc	s10,0x2e
    800029f6:	1b6d0d13          	addi	s10,s10,438 # 80030ba8 <wait_lock>
    havekids = 0;
    800029fa:	8766                	mv	a4,s9
    for (np = proc; np < &proc[NPROC]; np++)
    800029fc:	0002e497          	auipc	s1,0x2e
    80002a00:	5c448493          	addi	s1,s1,1476 # 80030fc0 <proc>
    80002a04:	a059                	j	80002a8a <waitx+0xe2>
          pid = np->pid;
    80002a06:	0304a983          	lw	s3,48(s1)
          *rtime = np->rtime;
    80002a0a:	1684a703          	lw	a4,360(s1)
    80002a0e:	00ec2023          	sw	a4,0(s8)
          *wtime = np->etime - np->ctime - np->rtime;
    80002a12:	16c4a783          	lw	a5,364(s1)
    80002a16:	9f3d                	addw	a4,a4,a5
    80002a18:	1704a783          	lw	a5,368(s1)
    80002a1c:	9f99                	subw	a5,a5,a4
    80002a1e:	00fba023          	sw	a5,0(s7)
          if (addr != 0 && copyout(p->pagetable, addr, (char *)&np->xstate,
    80002a22:	000b0e63          	beqz	s6,80002a3e <waitx+0x96>
    80002a26:	4691                	li	a3,4
    80002a28:	02c48613          	addi	a2,s1,44
    80002a2c:	85da                	mv	a1,s6
    80002a2e:	05093503          	ld	a0,80(s2)
    80002a32:	fffff097          	auipc	ra,0xfffff
    80002a36:	100080e7          	jalr	256(ra) # 80001b32 <copyout>
    80002a3a:	02054563          	bltz	a0,80002a64 <waitx+0xbc>
          freeproc(np);
    80002a3e:	8526                	mv	a0,s1
    80002a40:	fffff097          	auipc	ra,0xfffff
    80002a44:	4f0080e7          	jalr	1264(ra) # 80001f30 <freeproc>
          release(&np->lock);
    80002a48:	8526                	mv	a0,s1
    80002a4a:	ffffe097          	auipc	ra,0xffffe
    80002a4e:	4f4080e7          	jalr	1268(ra) # 80000f3e <release>
          release(&wait_lock);
    80002a52:	0002e517          	auipc	a0,0x2e
    80002a56:	15650513          	addi	a0,a0,342 # 80030ba8 <wait_lock>
    80002a5a:	ffffe097          	auipc	ra,0xffffe
    80002a5e:	4e4080e7          	jalr	1252(ra) # 80000f3e <release>
          return pid;
    80002a62:	a09d                	j	80002ac8 <waitx+0x120>
            release(&np->lock);
    80002a64:	8526                	mv	a0,s1
    80002a66:	ffffe097          	auipc	ra,0xffffe
    80002a6a:	4d8080e7          	jalr	1240(ra) # 80000f3e <release>
            release(&wait_lock);
    80002a6e:	0002e517          	auipc	a0,0x2e
    80002a72:	13a50513          	addi	a0,a0,314 # 80030ba8 <wait_lock>
    80002a76:	ffffe097          	auipc	ra,0xffffe
    80002a7a:	4c8080e7          	jalr	1224(ra) # 80000f3e <release>
            return -1;
    80002a7e:	59fd                	li	s3,-1
    80002a80:	a0a1                	j	80002ac8 <waitx+0x120>
    for (np = proc; np < &proc[NPROC]; np++)
    80002a82:	17848493          	addi	s1,s1,376
    80002a86:	03348463          	beq	s1,s3,80002aae <waitx+0x106>
      if (np->parent == p)
    80002a8a:	7c9c                	ld	a5,56(s1)
    80002a8c:	ff279be3          	bne	a5,s2,80002a82 <waitx+0xda>
        acquire(&np->lock);
    80002a90:	8526                	mv	a0,s1
    80002a92:	ffffe097          	auipc	ra,0xffffe
    80002a96:	3f8080e7          	jalr	1016(ra) # 80000e8a <acquire>
        if (np->state == ZOMBIE)
    80002a9a:	4c9c                	lw	a5,24(s1)
    80002a9c:	f74785e3          	beq	a5,s4,80002a06 <waitx+0x5e>
        release(&np->lock);
    80002aa0:	8526                	mv	a0,s1
    80002aa2:	ffffe097          	auipc	ra,0xffffe
    80002aa6:	49c080e7          	jalr	1180(ra) # 80000f3e <release>
        havekids = 1;
    80002aaa:	8756                	mv	a4,s5
    80002aac:	bfd9                	j	80002a82 <waitx+0xda>
    if (!havekids || p->killed)
    80002aae:	c701                	beqz	a4,80002ab6 <waitx+0x10e>
    80002ab0:	02892783          	lw	a5,40(s2)
    80002ab4:	cb8d                	beqz	a5,80002ae6 <waitx+0x13e>
      release(&wait_lock);
    80002ab6:	0002e517          	auipc	a0,0x2e
    80002aba:	0f250513          	addi	a0,a0,242 # 80030ba8 <wait_lock>
    80002abe:	ffffe097          	auipc	ra,0xffffe
    80002ac2:	480080e7          	jalr	1152(ra) # 80000f3e <release>
      return -1;
    80002ac6:	59fd                	li	s3,-1
  }
}
    80002ac8:	854e                	mv	a0,s3
    80002aca:	60e6                	ld	ra,88(sp)
    80002acc:	6446                	ld	s0,80(sp)
    80002ace:	64a6                	ld	s1,72(sp)
    80002ad0:	6906                	ld	s2,64(sp)
    80002ad2:	79e2                	ld	s3,56(sp)
    80002ad4:	7a42                	ld	s4,48(sp)
    80002ad6:	7aa2                	ld	s5,40(sp)
    80002ad8:	7b02                	ld	s6,32(sp)
    80002ada:	6be2                	ld	s7,24(sp)
    80002adc:	6c42                	ld	s8,16(sp)
    80002ade:	6ca2                	ld	s9,8(sp)
    80002ae0:	6d02                	ld	s10,0(sp)
    80002ae2:	6125                	addi	sp,sp,96
    80002ae4:	8082                	ret
    sleep(p, &wait_lock); // DOC: wait-sleep
    80002ae6:	85ea                	mv	a1,s10
    80002ae8:	854a                	mv	a0,s2
    80002aea:	00000097          	auipc	ra,0x0
    80002aee:	950080e7          	jalr	-1712(ra) # 8000243a <sleep>
    havekids = 0;
    80002af2:	b721                	j	800029fa <waitx+0x52>

0000000080002af4 <update_time>:

void update_time()
{
    80002af4:	7179                	addi	sp,sp,-48
    80002af6:	f406                	sd	ra,40(sp)
    80002af8:	f022                	sd	s0,32(sp)
    80002afa:	ec26                	sd	s1,24(sp)
    80002afc:	e84a                	sd	s2,16(sp)
    80002afe:	e44e                	sd	s3,8(sp)
    80002b00:	1800                	addi	s0,sp,48
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++)
    80002b02:	0002e497          	auipc	s1,0x2e
    80002b06:	4be48493          	addi	s1,s1,1214 # 80030fc0 <proc>
  {
    acquire(&p->lock);
    if (p->state == RUNNING)
    80002b0a:	4991                	li	s3,4
  for (p = proc; p < &proc[NPROC]; p++)
    80002b0c:	00034917          	auipc	s2,0x34
    80002b10:	2b490913          	addi	s2,s2,692 # 80036dc0 <tickslock>
    80002b14:	a811                	j	80002b28 <update_time+0x34>
    {
      p->rtime++;
    }
    release(&p->lock);
    80002b16:	8526                	mv	a0,s1
    80002b18:	ffffe097          	auipc	ra,0xffffe
    80002b1c:	426080e7          	jalr	1062(ra) # 80000f3e <release>
  for (p = proc; p < &proc[NPROC]; p++)
    80002b20:	17848493          	addi	s1,s1,376
    80002b24:	03248063          	beq	s1,s2,80002b44 <update_time+0x50>
    acquire(&p->lock);
    80002b28:	8526                	mv	a0,s1
    80002b2a:	ffffe097          	auipc	ra,0xffffe
    80002b2e:	360080e7          	jalr	864(ra) # 80000e8a <acquire>
    if (p->state == RUNNING)
    80002b32:	4c9c                	lw	a5,24(s1)
    80002b34:	ff3791e3          	bne	a5,s3,80002b16 <update_time+0x22>
      p->rtime++;
    80002b38:	1684a783          	lw	a5,360(s1)
    80002b3c:	2785                	addiw	a5,a5,1
    80002b3e:	16f4a423          	sw	a5,360(s1)
    80002b42:	bfd1                	j	80002b16 <update_time+0x22>
  }
    80002b44:	70a2                	ld	ra,40(sp)
    80002b46:	7402                	ld	s0,32(sp)
    80002b48:	64e2                	ld	s1,24(sp)
    80002b4a:	6942                	ld	s2,16(sp)
    80002b4c:	69a2                	ld	s3,8(sp)
    80002b4e:	6145                	addi	sp,sp,48
    80002b50:	8082                	ret

0000000080002b52 <swtch>:
    80002b52:	00153023          	sd	ra,0(a0)
    80002b56:	00253423          	sd	sp,8(a0)
    80002b5a:	e900                	sd	s0,16(a0)
    80002b5c:	ed04                	sd	s1,24(a0)
    80002b5e:	03253023          	sd	s2,32(a0)
    80002b62:	03353423          	sd	s3,40(a0)
    80002b66:	03453823          	sd	s4,48(a0)
    80002b6a:	03553c23          	sd	s5,56(a0)
    80002b6e:	05653023          	sd	s6,64(a0)
    80002b72:	05753423          	sd	s7,72(a0)
    80002b76:	05853823          	sd	s8,80(a0)
    80002b7a:	05953c23          	sd	s9,88(a0)
    80002b7e:	07a53023          	sd	s10,96(a0)
    80002b82:	07b53423          	sd	s11,104(a0)
    80002b86:	0005b083          	ld	ra,0(a1)
    80002b8a:	0085b103          	ld	sp,8(a1)
    80002b8e:	6980                	ld	s0,16(a1)
    80002b90:	6d84                	ld	s1,24(a1)
    80002b92:	0205b903          	ld	s2,32(a1)
    80002b96:	0285b983          	ld	s3,40(a1)
    80002b9a:	0305ba03          	ld	s4,48(a1)
    80002b9e:	0385ba83          	ld	s5,56(a1)
    80002ba2:	0405bb03          	ld	s6,64(a1)
    80002ba6:	0485bb83          	ld	s7,72(a1)
    80002baa:	0505bc03          	ld	s8,80(a1)
    80002bae:	0585bc83          	ld	s9,88(a1)
    80002bb2:	0605bd03          	ld	s10,96(a1)
    80002bb6:	0685bd83          	ld	s11,104(a1)
    80002bba:	8082                	ret

0000000080002bbc <trapinit>:
void kernelvec();

extern int devintr();

void trapinit(void)
{
    80002bbc:	1141                	addi	sp,sp,-16
    80002bbe:	e406                	sd	ra,8(sp)
    80002bc0:	e022                	sd	s0,0(sp)
    80002bc2:	0800                	addi	s0,sp,16
  initlock(&tickslock, "time");
    80002bc4:	00005597          	auipc	a1,0x5
    80002bc8:	75458593          	addi	a1,a1,1876 # 80008318 <states.0+0x30>
    80002bcc:	00034517          	auipc	a0,0x34
    80002bd0:	1f450513          	addi	a0,a0,500 # 80036dc0 <tickslock>
    80002bd4:	ffffe097          	auipc	ra,0xffffe
    80002bd8:	226080e7          	jalr	550(ra) # 80000dfa <initlock>
}
    80002bdc:	60a2                	ld	ra,8(sp)
    80002bde:	6402                	ld	s0,0(sp)
    80002be0:	0141                	addi	sp,sp,16
    80002be2:	8082                	ret

0000000080002be4 <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void trapinithart(void)
{
    80002be4:	1141                	addi	sp,sp,-16
    80002be6:	e422                	sd	s0,8(sp)
    80002be8:	0800                	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002bea:	00003797          	auipc	a5,0x3
    80002bee:	5b678793          	addi	a5,a5,1462 # 800061a0 <kernelvec>
    80002bf2:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    80002bf6:	6422                	ld	s0,8(sp)
    80002bf8:	0141                	addi	sp,sp,16
    80002bfa:	8082                	ret

0000000080002bfc <usertrapret>:

//
// return to user space
//
void usertrapret(void)
{
    80002bfc:	1141                	addi	sp,sp,-16
    80002bfe:	e406                	sd	ra,8(sp)
    80002c00:	e022                	sd	s0,0(sp)
    80002c02:	0800                	addi	s0,sp,16
  struct proc *p = myproc();
    80002c04:	fffff097          	auipc	ra,0xfffff
    80002c08:	17a080e7          	jalr	378(ra) # 80001d7e <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002c0c:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80002c10:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002c12:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(), so turn off interrupts until
  // we're back in user space, where usertrap() is correct.
  intr_off();

  // send syscalls, interrupts, and exceptions to uservec in trampoline.S
  uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
    80002c16:	00004617          	auipc	a2,0x4
    80002c1a:	3ea60613          	addi	a2,a2,1002 # 80007000 <_trampoline>
    80002c1e:	00004697          	auipc	a3,0x4
    80002c22:	3e268693          	addi	a3,a3,994 # 80007000 <_trampoline>
    80002c26:	8e91                	sub	a3,a3,a2
    80002c28:	040007b7          	lui	a5,0x4000
    80002c2c:	17fd                	addi	a5,a5,-1
    80002c2e:	07b2                	slli	a5,a5,0xc
    80002c30:	96be                	add	a3,a3,a5
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002c32:	10569073          	csrw	stvec,a3
  w_stvec(trampoline_uservec);

  // set up trapframe values that uservec will need when
  // the process next traps into the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    80002c36:	6d38                	ld	a4,88(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    80002c38:	180026f3          	csrr	a3,satp
    80002c3c:	e314                	sd	a3,0(a4)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    80002c3e:	6d38                	ld	a4,88(a0)
    80002c40:	6134                	ld	a3,64(a0)
    80002c42:	6585                	lui	a1,0x1
    80002c44:	96ae                	add	a3,a3,a1
    80002c46:	e714                	sd	a3,8(a4)
  p->trapframe->kernel_trap = (uint64)usertrap;
    80002c48:	6d38                	ld	a4,88(a0)
    80002c4a:	00000697          	auipc	a3,0x0
    80002c4e:	13e68693          	addi	a3,a3,318 # 80002d88 <usertrap>
    80002c52:	eb14                	sd	a3,16(a4)
  p->trapframe->kernel_hartid = r_tp(); // hartid for cpuid()
    80002c54:	6d38                	ld	a4,88(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    80002c56:	8692                	mv	a3,tp
    80002c58:	f314                	sd	a3,32(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002c5a:	100026f3          	csrr	a3,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.

  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    80002c5e:	eff6f693          	andi	a3,a3,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    80002c62:	0206e693          	ori	a3,a3,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002c66:	10069073          	csrw	sstatus,a3
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    80002c6a:	6d38                	ld	a4,88(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002c6c:	6f18                	ld	a4,24(a4)
    80002c6e:	14171073          	csrw	sepc,a4

  // tell trampoline.S the user page table to switch to.
  uint64 satp = MAKE_SATP(p->pagetable);
    80002c72:	6928                	ld	a0,80(a0)
    80002c74:	8131                	srli	a0,a0,0xc

  // jump to userret in trampoline.S at the top of memory, which
  // switches to the user page table, restores user registers,
  // and switches to user mode with sret.
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
    80002c76:	00004717          	auipc	a4,0x4
    80002c7a:	42670713          	addi	a4,a4,1062 # 8000709c <userret>
    80002c7e:	8f11                	sub	a4,a4,a2
    80002c80:	97ba                	add	a5,a5,a4
  ((void (*)(uint64))trampoline_userret)(satp);
    80002c82:	577d                	li	a4,-1
    80002c84:	177e                	slli	a4,a4,0x3f
    80002c86:	8d59                	or	a0,a0,a4
    80002c88:	9782                	jalr	a5
}
    80002c8a:	60a2                	ld	ra,8(sp)
    80002c8c:	6402                	ld	s0,0(sp)
    80002c8e:	0141                	addi	sp,sp,16
    80002c90:	8082                	ret

0000000080002c92 <clockintr>:
  w_sepc(sepc);
  w_sstatus(sstatus);
}

void clockintr()
{
    80002c92:	1101                	addi	sp,sp,-32
    80002c94:	ec06                	sd	ra,24(sp)
    80002c96:	e822                	sd	s0,16(sp)
    80002c98:	e426                	sd	s1,8(sp)
    80002c9a:	e04a                	sd	s2,0(sp)
    80002c9c:	1000                	addi	s0,sp,32
  acquire(&tickslock);
    80002c9e:	00034917          	auipc	s2,0x34
    80002ca2:	12290913          	addi	s2,s2,290 # 80036dc0 <tickslock>
    80002ca6:	854a                	mv	a0,s2
    80002ca8:	ffffe097          	auipc	ra,0xffffe
    80002cac:	1e2080e7          	jalr	482(ra) # 80000e8a <acquire>
  ticks++;
    80002cb0:	00006497          	auipc	s1,0x6
    80002cb4:	c7048493          	addi	s1,s1,-912 # 80008920 <ticks>
    80002cb8:	409c                	lw	a5,0(s1)
    80002cba:	2785                	addiw	a5,a5,1
    80002cbc:	c09c                	sw	a5,0(s1)
  update_time();
    80002cbe:	00000097          	auipc	ra,0x0
    80002cc2:	e36080e7          	jalr	-458(ra) # 80002af4 <update_time>
  //   // {
  //   //   p->wtime++;
  //   // }
  //   release(&p->lock);
  // }
  wakeup(&ticks);
    80002cc6:	8526                	mv	a0,s1
    80002cc8:	fffff097          	auipc	ra,0xfffff
    80002ccc:	7d6080e7          	jalr	2006(ra) # 8000249e <wakeup>
  release(&tickslock);
    80002cd0:	854a                	mv	a0,s2
    80002cd2:	ffffe097          	auipc	ra,0xffffe
    80002cd6:	26c080e7          	jalr	620(ra) # 80000f3e <release>
}
    80002cda:	60e2                	ld	ra,24(sp)
    80002cdc:	6442                	ld	s0,16(sp)
    80002cde:	64a2                	ld	s1,8(sp)
    80002ce0:	6902                	ld	s2,0(sp)
    80002ce2:	6105                	addi	sp,sp,32
    80002ce4:	8082                	ret

0000000080002ce6 <devintr>:
// and handle it.
// returns 2 if timer interrupt,
// 1 if other device,
// 0 if not recognized.
int devintr()
{
    80002ce6:	1101                	addi	sp,sp,-32
    80002ce8:	ec06                	sd	ra,24(sp)
    80002cea:	e822                	sd	s0,16(sp)
    80002cec:	e426                	sd	s1,8(sp)
    80002cee:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002cf0:	14202773          	csrr	a4,scause
  uint64 scause = r_scause();

  if ((scause & 0x8000000000000000L) &&
    80002cf4:	00074d63          	bltz	a4,80002d0e <devintr+0x28>
    if (irq)
      plic_complete(irq);

    return 1;
  }
  else if (scause == 0x8000000000000001L)
    80002cf8:	57fd                	li	a5,-1
    80002cfa:	17fe                	slli	a5,a5,0x3f
    80002cfc:	0785                	addi	a5,a5,1

    return 2;
  }
  else
  {
    return 0;
    80002cfe:	4501                	li	a0,0
  else if (scause == 0x8000000000000001L)
    80002d00:	06f70363          	beq	a4,a5,80002d66 <devintr+0x80>
  }
}
    80002d04:	60e2                	ld	ra,24(sp)
    80002d06:	6442                	ld	s0,16(sp)
    80002d08:	64a2                	ld	s1,8(sp)
    80002d0a:	6105                	addi	sp,sp,32
    80002d0c:	8082                	ret
      (scause & 0xff) == 9)
    80002d0e:	0ff77793          	andi	a5,a4,255
  if ((scause & 0x8000000000000000L) &&
    80002d12:	46a5                	li	a3,9
    80002d14:	fed792e3          	bne	a5,a3,80002cf8 <devintr+0x12>
    int irq = plic_claim();
    80002d18:	00003097          	auipc	ra,0x3
    80002d1c:	590080e7          	jalr	1424(ra) # 800062a8 <plic_claim>
    80002d20:	84aa                	mv	s1,a0
    if (irq == UART0_IRQ)
    80002d22:	47a9                	li	a5,10
    80002d24:	02f50763          	beq	a0,a5,80002d52 <devintr+0x6c>
    else if (irq == VIRTIO0_IRQ)
    80002d28:	4785                	li	a5,1
    80002d2a:	02f50963          	beq	a0,a5,80002d5c <devintr+0x76>
    return 1;
    80002d2e:	4505                	li	a0,1
    else if (irq)
    80002d30:	d8f1                	beqz	s1,80002d04 <devintr+0x1e>
      printf("unexpected interrupt irq=%d\n", irq);
    80002d32:	85a6                	mv	a1,s1
    80002d34:	00005517          	auipc	a0,0x5
    80002d38:	5ec50513          	addi	a0,a0,1516 # 80008320 <states.0+0x38>
    80002d3c:	ffffe097          	auipc	ra,0xffffe
    80002d40:	84c080e7          	jalr	-1972(ra) # 80000588 <printf>
      plic_complete(irq);
    80002d44:	8526                	mv	a0,s1
    80002d46:	00003097          	auipc	ra,0x3
    80002d4a:	586080e7          	jalr	1414(ra) # 800062cc <plic_complete>
    return 1;
    80002d4e:	4505                	li	a0,1
    80002d50:	bf55                	j	80002d04 <devintr+0x1e>
      uartintr();
    80002d52:	ffffe097          	auipc	ra,0xffffe
    80002d56:	c48080e7          	jalr	-952(ra) # 8000099a <uartintr>
    80002d5a:	b7ed                	j	80002d44 <devintr+0x5e>
      virtio_disk_intr();
    80002d5c:	00004097          	auipc	ra,0x4
    80002d60:	a3c080e7          	jalr	-1476(ra) # 80006798 <virtio_disk_intr>
    80002d64:	b7c5                	j	80002d44 <devintr+0x5e>
    if (cpuid() == 0)
    80002d66:	fffff097          	auipc	ra,0xfffff
    80002d6a:	fec080e7          	jalr	-20(ra) # 80001d52 <cpuid>
    80002d6e:	c901                	beqz	a0,80002d7e <devintr+0x98>
  asm volatile("csrr %0, sip" : "=r" (x) );
    80002d70:	144027f3          	csrr	a5,sip
    w_sip(r_sip() & ~2);
    80002d74:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sip, %0" : : "r" (x));
    80002d76:	14479073          	csrw	sip,a5
    return 2;
    80002d7a:	4509                	li	a0,2
    80002d7c:	b761                	j	80002d04 <devintr+0x1e>
      clockintr();
    80002d7e:	00000097          	auipc	ra,0x0
    80002d82:	f14080e7          	jalr	-236(ra) # 80002c92 <clockintr>
    80002d86:	b7ed                	j	80002d70 <devintr+0x8a>

0000000080002d88 <usertrap>:
{
    80002d88:	1101                	addi	sp,sp,-32
    80002d8a:	ec06                	sd	ra,24(sp)
    80002d8c:	e822                	sd	s0,16(sp)
    80002d8e:	e426                	sd	s1,8(sp)
    80002d90:	e04a                	sd	s2,0(sp)
    80002d92:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002d94:	100027f3          	csrr	a5,sstatus
  if((r_sstatus() & SSTATUS_SPP) != 0)
    80002d98:	1007f793          	andi	a5,a5,256
    80002d9c:	ebd1                	bnez	a5,80002e30 <usertrap+0xa8>
  asm volatile("csrw stvec, %0" : : "r" (x));
    80002d9e:	00003797          	auipc	a5,0x3
    80002da2:	40278793          	addi	a5,a5,1026 # 800061a0 <kernelvec>
    80002da6:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    80002daa:	fffff097          	auipc	ra,0xfffff
    80002dae:	fd4080e7          	jalr	-44(ra) # 80001d7e <myproc>
    80002db2:	84aa                	mv	s1,a0
  p->trapframe->epc = r_sepc();
    80002db4:	6d3c                	ld	a5,88(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002db6:	14102773          	csrr	a4,sepc
    80002dba:	ef98                	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002dbc:	14202773          	csrr	a4,scause
  if(r_scause() == 8){
    80002dc0:	47a1                	li	a5,8
    80002dc2:	06f70f63          	beq	a4,a5,80002e40 <usertrap+0xb8>
  } else if((which_dev = devintr()) != 0){
    80002dc6:	00000097          	auipc	ra,0x0
    80002dca:	f20080e7          	jalr	-224(ra) # 80002ce6 <devintr>
    80002dce:	892a                	mv	s2,a0
    80002dd0:	e97d                	bnez	a0,80002ec6 <usertrap+0x13e>
    80002dd2:	14202773          	csrr	a4,scause
  } else if(r_scause() == 13 || r_scause() == 15) {
    80002dd6:	47b5                	li	a5,13
    80002dd8:	00f70763          	beq	a4,a5,80002de6 <usertrap+0x5e>
    80002ddc:	14202773          	csrr	a4,scause
    80002de0:	47bd                	li	a5,15
    80002de2:	0af71863          	bne	a4,a5,80002e92 <usertrap+0x10a>
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002de6:	143025f3          	csrr	a1,stval
    if(va < p->sz && cow_handler(p->pagetable, va) == 0) {
    80002dea:	64bc                	ld	a5,72(s1)
    80002dec:	00f5f863          	bgeu	a1,a5,80002dfc <usertrap+0x74>
    80002df0:	68a8                	ld	a0,80(s1)
    80002df2:	fffff097          	auipc	ra,0xfffff
    80002df6:	c76080e7          	jalr	-906(ra) # 80001a68 <cow_handler>
    80002dfa:	c535                	beqz	a0,80002e66 <usertrap+0xde>
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002dfc:	142025f3          	csrr	a1,scause
      printf("usertrap(): unexpected page fault %p pid=%d\n", r_scause(), p->pid);
    80002e00:	5890                	lw	a2,48(s1)
    80002e02:	00005517          	auipc	a0,0x5
    80002e06:	55e50513          	addi	a0,a0,1374 # 80008360 <states.0+0x78>
    80002e0a:	ffffd097          	auipc	ra,0xffffd
    80002e0e:	77e080e7          	jalr	1918(ra) # 80000588 <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002e12:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002e16:	14302673          	csrr	a2,stval
      printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002e1a:	00005517          	auipc	a0,0x5
    80002e1e:	57650513          	addi	a0,a0,1398 # 80008390 <states.0+0xa8>
    80002e22:	ffffd097          	auipc	ra,0xffffd
    80002e26:	766080e7          	jalr	1894(ra) # 80000588 <printf>
      p->killed = 1;
    80002e2a:	4785                	li	a5,1
    80002e2c:	d49c                	sw	a5,40(s1)
    80002e2e:	a825                	j	80002e66 <usertrap+0xde>
    panic("usertrap: not from user mode");
    80002e30:	00005517          	auipc	a0,0x5
    80002e34:	51050513          	addi	a0,a0,1296 # 80008340 <states.0+0x58>
    80002e38:	ffffd097          	auipc	ra,0xffffd
    80002e3c:	706080e7          	jalr	1798(ra) # 8000053e <panic>
    if(killed(p))
    80002e40:	00000097          	auipc	ra,0x0
    80002e44:	8ae080e7          	jalr	-1874(ra) # 800026ee <killed>
    80002e48:	ed1d                	bnez	a0,80002e86 <usertrap+0xfe>
    p->trapframe->epc += 4;
    80002e4a:	6cb8                	ld	a4,88(s1)
    80002e4c:	6f1c                	ld	a5,24(a4)
    80002e4e:	0791                	addi	a5,a5,4
    80002e50:	ef1c                	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002e52:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80002e56:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002e5a:	10079073          	csrw	sstatus,a5
    syscall();
    80002e5e:	00000097          	auipc	ra,0x0
    80002e62:	2dc080e7          	jalr	732(ra) # 8000313a <syscall>
  if(killed(p))
    80002e66:	8526                	mv	a0,s1
    80002e68:	00000097          	auipc	ra,0x0
    80002e6c:	886080e7          	jalr	-1914(ra) # 800026ee <killed>
    80002e70:	e135                	bnez	a0,80002ed4 <usertrap+0x14c>
  usertrapret();
    80002e72:	00000097          	auipc	ra,0x0
    80002e76:	d8a080e7          	jalr	-630(ra) # 80002bfc <usertrapret>
}
    80002e7a:	60e2                	ld	ra,24(sp)
    80002e7c:	6442                	ld	s0,16(sp)
    80002e7e:	64a2                	ld	s1,8(sp)
    80002e80:	6902                	ld	s2,0(sp)
    80002e82:	6105                	addi	sp,sp,32
    80002e84:	8082                	ret
      exit(-1);
    80002e86:	557d                	li	a0,-1
    80002e88:	fffff097          	auipc	ra,0xfffff
    80002e8c:	6e6080e7          	jalr	1766(ra) # 8000256e <exit>
    80002e90:	bf6d                	j	80002e4a <usertrap+0xc2>
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002e92:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause %p pid=%d\n", r_scause(), p->pid);
    80002e96:	5890                	lw	a2,48(s1)
    80002e98:	00005517          	auipc	a0,0x5
    80002e9c:	51850513          	addi	a0,a0,1304 # 800083b0 <states.0+0xc8>
    80002ea0:	ffffd097          	auipc	ra,0xffffd
    80002ea4:	6e8080e7          	jalr	1768(ra) # 80000588 <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002ea8:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002eac:	14302673          	csrr	a2,stval
    printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002eb0:	00005517          	auipc	a0,0x5
    80002eb4:	4e050513          	addi	a0,a0,1248 # 80008390 <states.0+0xa8>
    80002eb8:	ffffd097          	auipc	ra,0xffffd
    80002ebc:	6d0080e7          	jalr	1744(ra) # 80000588 <printf>
    p->killed = 1;
    80002ec0:	4785                	li	a5,1
    80002ec2:	d49c                	sw	a5,40(s1)
    80002ec4:	b74d                	j	80002e66 <usertrap+0xde>
  if(killed(p))
    80002ec6:	8526                	mv	a0,s1
    80002ec8:	00000097          	auipc	ra,0x0
    80002ecc:	826080e7          	jalr	-2010(ra) # 800026ee <killed>
    80002ed0:	c901                	beqz	a0,80002ee0 <usertrap+0x158>
    80002ed2:	a011                	j	80002ed6 <usertrap+0x14e>
    80002ed4:	4901                	li	s2,0
    exit(-1);
    80002ed6:	557d                	li	a0,-1
    80002ed8:	fffff097          	auipc	ra,0xfffff
    80002edc:	696080e7          	jalr	1686(ra) # 8000256e <exit>
  if(which_dev == 2)
    80002ee0:	4789                	li	a5,2
    80002ee2:	f8f918e3          	bne	s2,a5,80002e72 <usertrap+0xea>
    yield();
    80002ee6:	fffff097          	auipc	ra,0xfffff
    80002eea:	518080e7          	jalr	1304(ra) # 800023fe <yield>
    80002eee:	b751                	j	80002e72 <usertrap+0xea>

0000000080002ef0 <kerneltrap>:
{
    80002ef0:	7179                	addi	sp,sp,-48
    80002ef2:	f406                	sd	ra,40(sp)
    80002ef4:	f022                	sd	s0,32(sp)
    80002ef6:	ec26                	sd	s1,24(sp)
    80002ef8:	e84a                	sd	s2,16(sp)
    80002efa:	e44e                	sd	s3,8(sp)
    80002efc:	1800                	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002efe:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002f02:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002f06:	142029f3          	csrr	s3,scause
  if ((sstatus & SSTATUS_SPP) == 0)
    80002f0a:	1004f793          	andi	a5,s1,256
    80002f0e:	cb85                	beqz	a5,80002f3e <kerneltrap+0x4e>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002f10:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002f14:	8b89                	andi	a5,a5,2
  if (intr_get() != 0)
    80002f16:	ef85                	bnez	a5,80002f4e <kerneltrap+0x5e>
  if ((which_dev = devintr()) == 0)
    80002f18:	00000097          	auipc	ra,0x0
    80002f1c:	dce080e7          	jalr	-562(ra) # 80002ce6 <devintr>
    80002f20:	cd1d                	beqz	a0,80002f5e <kerneltrap+0x6e>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002f22:	4789                	li	a5,2
    80002f24:	06f50a63          	beq	a0,a5,80002f98 <kerneltrap+0xa8>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002f28:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002f2c:	10049073          	csrw	sstatus,s1
}
    80002f30:	70a2                	ld	ra,40(sp)
    80002f32:	7402                	ld	s0,32(sp)
    80002f34:	64e2                	ld	s1,24(sp)
    80002f36:	6942                	ld	s2,16(sp)
    80002f38:	69a2                	ld	s3,8(sp)
    80002f3a:	6145                	addi	sp,sp,48
    80002f3c:	8082                	ret
    panic("kerneltrap: not from supervisor mode");
    80002f3e:	00005517          	auipc	a0,0x5
    80002f42:	4a250513          	addi	a0,a0,1186 # 800083e0 <states.0+0xf8>
    80002f46:	ffffd097          	auipc	ra,0xffffd
    80002f4a:	5f8080e7          	jalr	1528(ra) # 8000053e <panic>
    panic("kerneltrap: interrupts enabled");
    80002f4e:	00005517          	auipc	a0,0x5
    80002f52:	4ba50513          	addi	a0,a0,1210 # 80008408 <states.0+0x120>
    80002f56:	ffffd097          	auipc	ra,0xffffd
    80002f5a:	5e8080e7          	jalr	1512(ra) # 8000053e <panic>
    printf("scause %p\n", scause);
    80002f5e:	85ce                	mv	a1,s3
    80002f60:	00005517          	auipc	a0,0x5
    80002f64:	4c850513          	addi	a0,a0,1224 # 80008428 <states.0+0x140>
    80002f68:	ffffd097          	auipc	ra,0xffffd
    80002f6c:	620080e7          	jalr	1568(ra) # 80000588 <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002f70:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002f74:	14302673          	csrr	a2,stval
    printf("sepc=%p stval=%p\n", r_sepc(), r_stval());
    80002f78:	00005517          	auipc	a0,0x5
    80002f7c:	4c050513          	addi	a0,a0,1216 # 80008438 <states.0+0x150>
    80002f80:	ffffd097          	auipc	ra,0xffffd
    80002f84:	608080e7          	jalr	1544(ra) # 80000588 <printf>
    panic("kerneltrap");
    80002f88:	00005517          	auipc	a0,0x5
    80002f8c:	4c850513          	addi	a0,a0,1224 # 80008450 <states.0+0x168>
    80002f90:	ffffd097          	auipc	ra,0xffffd
    80002f94:	5ae080e7          	jalr	1454(ra) # 8000053e <panic>
  if (which_dev == 2 && myproc() != 0 && myproc()->state == RUNNING)
    80002f98:	fffff097          	auipc	ra,0xfffff
    80002f9c:	de6080e7          	jalr	-538(ra) # 80001d7e <myproc>
    80002fa0:	d541                	beqz	a0,80002f28 <kerneltrap+0x38>
    80002fa2:	fffff097          	auipc	ra,0xfffff
    80002fa6:	ddc080e7          	jalr	-548(ra) # 80001d7e <myproc>
    80002faa:	4d18                	lw	a4,24(a0)
    80002fac:	4791                	li	a5,4
    80002fae:	f6f71de3          	bne	a4,a5,80002f28 <kerneltrap+0x38>
    yield();
    80002fb2:	fffff097          	auipc	ra,0xfffff
    80002fb6:	44c080e7          	jalr	1100(ra) # 800023fe <yield>
    80002fba:	b7bd                	j	80002f28 <kerneltrap+0x38>

0000000080002fbc <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    80002fbc:	1101                	addi	sp,sp,-32
    80002fbe:	ec06                	sd	ra,24(sp)
    80002fc0:	e822                	sd	s0,16(sp)
    80002fc2:	e426                	sd	s1,8(sp)
    80002fc4:	1000                	addi	s0,sp,32
    80002fc6:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80002fc8:	fffff097          	auipc	ra,0xfffff
    80002fcc:	db6080e7          	jalr	-586(ra) # 80001d7e <myproc>
  switch (n) {
    80002fd0:	4795                	li	a5,5
    80002fd2:	0497e163          	bltu	a5,s1,80003014 <argraw+0x58>
    80002fd6:	048a                	slli	s1,s1,0x2
    80002fd8:	00005717          	auipc	a4,0x5
    80002fdc:	4b070713          	addi	a4,a4,1200 # 80008488 <states.0+0x1a0>
    80002fe0:	94ba                	add	s1,s1,a4
    80002fe2:	409c                	lw	a5,0(s1)
    80002fe4:	97ba                	add	a5,a5,a4
    80002fe6:	8782                	jr	a5
  case 0:
    return p->trapframe->a0;
    80002fe8:	6d3c                	ld	a5,88(a0)
    80002fea:	7ba8                	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80002fec:	60e2                	ld	ra,24(sp)
    80002fee:	6442                	ld	s0,16(sp)
    80002ff0:	64a2                	ld	s1,8(sp)
    80002ff2:	6105                	addi	sp,sp,32
    80002ff4:	8082                	ret
    return p->trapframe->a1;
    80002ff6:	6d3c                	ld	a5,88(a0)
    80002ff8:	7fa8                	ld	a0,120(a5)
    80002ffa:	bfcd                	j	80002fec <argraw+0x30>
    return p->trapframe->a2;
    80002ffc:	6d3c                	ld	a5,88(a0)
    80002ffe:	63c8                	ld	a0,128(a5)
    80003000:	b7f5                	j	80002fec <argraw+0x30>
    return p->trapframe->a3;
    80003002:	6d3c                	ld	a5,88(a0)
    80003004:	67c8                	ld	a0,136(a5)
    80003006:	b7dd                	j	80002fec <argraw+0x30>
    return p->trapframe->a4;
    80003008:	6d3c                	ld	a5,88(a0)
    8000300a:	6bc8                	ld	a0,144(a5)
    8000300c:	b7c5                	j	80002fec <argraw+0x30>
    return p->trapframe->a5;
    8000300e:	6d3c                	ld	a5,88(a0)
    80003010:	6fc8                	ld	a0,152(a5)
    80003012:	bfe9                	j	80002fec <argraw+0x30>
  panic("argraw");
    80003014:	00005517          	auipc	a0,0x5
    80003018:	44c50513          	addi	a0,a0,1100 # 80008460 <states.0+0x178>
    8000301c:	ffffd097          	auipc	ra,0xffffd
    80003020:	522080e7          	jalr	1314(ra) # 8000053e <panic>

0000000080003024 <fetchaddr>:
{
    80003024:	1101                	addi	sp,sp,-32
    80003026:	ec06                	sd	ra,24(sp)
    80003028:	e822                	sd	s0,16(sp)
    8000302a:	e426                	sd	s1,8(sp)
    8000302c:	e04a                	sd	s2,0(sp)
    8000302e:	1000                	addi	s0,sp,32
    80003030:	84aa                	mv	s1,a0
    80003032:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80003034:	fffff097          	auipc	ra,0xfffff
    80003038:	d4a080e7          	jalr	-694(ra) # 80001d7e <myproc>
  if(addr >= p->sz || addr+sizeof(uint64) > p->sz) // both tests needed, in case of overflow
    8000303c:	653c                	ld	a5,72(a0)
    8000303e:	02f4f863          	bgeu	s1,a5,8000306e <fetchaddr+0x4a>
    80003042:	00848713          	addi	a4,s1,8
    80003046:	02e7e663          	bltu	a5,a4,80003072 <fetchaddr+0x4e>
  if(copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    8000304a:	46a1                	li	a3,8
    8000304c:	8626                	mv	a2,s1
    8000304e:	85ca                	mv	a1,s2
    80003050:	6928                	ld	a0,80(a0)
    80003052:	fffff097          	auipc	ra,0xfffff
    80003056:	8d4080e7          	jalr	-1836(ra) # 80001926 <copyin>
    8000305a:	00a03533          	snez	a0,a0
    8000305e:	40a00533          	neg	a0,a0
}
    80003062:	60e2                	ld	ra,24(sp)
    80003064:	6442                	ld	s0,16(sp)
    80003066:	64a2                	ld	s1,8(sp)
    80003068:	6902                	ld	s2,0(sp)
    8000306a:	6105                	addi	sp,sp,32
    8000306c:	8082                	ret
    return -1;
    8000306e:	557d                	li	a0,-1
    80003070:	bfcd                	j	80003062 <fetchaddr+0x3e>
    80003072:	557d                	li	a0,-1
    80003074:	b7fd                	j	80003062 <fetchaddr+0x3e>

0000000080003076 <fetchstr>:
{
    80003076:	7179                	addi	sp,sp,-48
    80003078:	f406                	sd	ra,40(sp)
    8000307a:	f022                	sd	s0,32(sp)
    8000307c:	ec26                	sd	s1,24(sp)
    8000307e:	e84a                	sd	s2,16(sp)
    80003080:	e44e                	sd	s3,8(sp)
    80003082:	1800                	addi	s0,sp,48
    80003084:	892a                	mv	s2,a0
    80003086:	84ae                	mv	s1,a1
    80003088:	89b2                	mv	s3,a2
  struct proc *p = myproc();
    8000308a:	fffff097          	auipc	ra,0xfffff
    8000308e:	cf4080e7          	jalr	-780(ra) # 80001d7e <myproc>
  if(copyinstr(p->pagetable, buf, addr, max) < 0)
    80003092:	86ce                	mv	a3,s3
    80003094:	864a                	mv	a2,s2
    80003096:	85a6                	mv	a1,s1
    80003098:	6928                	ld	a0,80(a0)
    8000309a:	fffff097          	auipc	ra,0xfffff
    8000309e:	91a080e7          	jalr	-1766(ra) # 800019b4 <copyinstr>
    800030a2:	00054e63          	bltz	a0,800030be <fetchstr+0x48>
  return strlen(buf);
    800030a6:	8526                	mv	a0,s1
    800030a8:	ffffe097          	auipc	ra,0xffffe
    800030ac:	05a080e7          	jalr	90(ra) # 80001102 <strlen>
}
    800030b0:	70a2                	ld	ra,40(sp)
    800030b2:	7402                	ld	s0,32(sp)
    800030b4:	64e2                	ld	s1,24(sp)
    800030b6:	6942                	ld	s2,16(sp)
    800030b8:	69a2                	ld	s3,8(sp)
    800030ba:	6145                	addi	sp,sp,48
    800030bc:	8082                	ret
    return -1;
    800030be:	557d                	li	a0,-1
    800030c0:	bfc5                	j	800030b0 <fetchstr+0x3a>

00000000800030c2 <argint>:

// Fetch the nth 32-bit system call argument.
void
argint(int n, int *ip)
{
    800030c2:	1101                	addi	sp,sp,-32
    800030c4:	ec06                	sd	ra,24(sp)
    800030c6:	e822                	sd	s0,16(sp)
    800030c8:	e426                	sd	s1,8(sp)
    800030ca:	1000                	addi	s0,sp,32
    800030cc:	84ae                	mv	s1,a1
  *ip = argraw(n);
    800030ce:	00000097          	auipc	ra,0x0
    800030d2:	eee080e7          	jalr	-274(ra) # 80002fbc <argraw>
    800030d6:	c088                	sw	a0,0(s1)
}
    800030d8:	60e2                	ld	ra,24(sp)
    800030da:	6442                	ld	s0,16(sp)
    800030dc:	64a2                	ld	s1,8(sp)
    800030de:	6105                	addi	sp,sp,32
    800030e0:	8082                	ret

00000000800030e2 <argaddr>:
// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
void
argaddr(int n, uint64 *ip)
{
    800030e2:	1101                	addi	sp,sp,-32
    800030e4:	ec06                	sd	ra,24(sp)
    800030e6:	e822                	sd	s0,16(sp)
    800030e8:	e426                	sd	s1,8(sp)
    800030ea:	1000                	addi	s0,sp,32
    800030ec:	84ae                	mv	s1,a1
  *ip = argraw(n);
    800030ee:	00000097          	auipc	ra,0x0
    800030f2:	ece080e7          	jalr	-306(ra) # 80002fbc <argraw>
    800030f6:	e088                	sd	a0,0(s1)
}
    800030f8:	60e2                	ld	ra,24(sp)
    800030fa:	6442                	ld	s0,16(sp)
    800030fc:	64a2                	ld	s1,8(sp)
    800030fe:	6105                	addi	sp,sp,32
    80003100:	8082                	ret

0000000080003102 <argstr>:
// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int
argstr(int n, char *buf, int max)
{
    80003102:	7179                	addi	sp,sp,-48
    80003104:	f406                	sd	ra,40(sp)
    80003106:	f022                	sd	s0,32(sp)
    80003108:	ec26                	sd	s1,24(sp)
    8000310a:	e84a                	sd	s2,16(sp)
    8000310c:	1800                	addi	s0,sp,48
    8000310e:	84ae                	mv	s1,a1
    80003110:	8932                	mv	s2,a2
  uint64 addr;
  argaddr(n, &addr);
    80003112:	fd840593          	addi	a1,s0,-40
    80003116:	00000097          	auipc	ra,0x0
    8000311a:	fcc080e7          	jalr	-52(ra) # 800030e2 <argaddr>
  return fetchstr(addr, buf, max);
    8000311e:	864a                	mv	a2,s2
    80003120:	85a6                	mv	a1,s1
    80003122:	fd843503          	ld	a0,-40(s0)
    80003126:	00000097          	auipc	ra,0x0
    8000312a:	f50080e7          	jalr	-176(ra) # 80003076 <fetchstr>
}
    8000312e:	70a2                	ld	ra,40(sp)
    80003130:	7402                	ld	s0,32(sp)
    80003132:	64e2                	ld	s1,24(sp)
    80003134:	6942                	ld	s2,16(sp)
    80003136:	6145                	addi	sp,sp,48
    80003138:	8082                	ret

000000008000313a <syscall>:
[SYS_waitx]   sys_waitx,
};

void
syscall(void)
{
    8000313a:	1101                	addi	sp,sp,-32
    8000313c:	ec06                	sd	ra,24(sp)
    8000313e:	e822                	sd	s0,16(sp)
    80003140:	e426                	sd	s1,8(sp)
    80003142:	e04a                	sd	s2,0(sp)
    80003144:	1000                	addi	s0,sp,32
  int num;
  struct proc *p = myproc();
    80003146:	fffff097          	auipc	ra,0xfffff
    8000314a:	c38080e7          	jalr	-968(ra) # 80001d7e <myproc>
    8000314e:	84aa                	mv	s1,a0

  num = p->trapframe->a7;
    80003150:	05853903          	ld	s2,88(a0)
    80003154:	0a893783          	ld	a5,168(s2)
    80003158:	0007869b          	sext.w	a3,a5
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    8000315c:	37fd                	addiw	a5,a5,-1
    8000315e:	4755                	li	a4,21
    80003160:	00f76f63          	bltu	a4,a5,8000317e <syscall+0x44>
    80003164:	00369713          	slli	a4,a3,0x3
    80003168:	00005797          	auipc	a5,0x5
    8000316c:	33878793          	addi	a5,a5,824 # 800084a0 <syscalls>
    80003170:	97ba                	add	a5,a5,a4
    80003172:	639c                	ld	a5,0(a5)
    80003174:	c789                	beqz	a5,8000317e <syscall+0x44>
    // Use num to lookup the system call function for num, call it,
    // and store its return value in p->trapframe->a0
    p->trapframe->a0 = syscalls[num]();
    80003176:	9782                	jalr	a5
    80003178:	06a93823          	sd	a0,112(s2)
    8000317c:	a839                	j	8000319a <syscall+0x60>
  } else {
    printf("%d %s: unknown sys call %d\n",
    8000317e:	15848613          	addi	a2,s1,344
    80003182:	588c                	lw	a1,48(s1)
    80003184:	00005517          	auipc	a0,0x5
    80003188:	2e450513          	addi	a0,a0,740 # 80008468 <states.0+0x180>
    8000318c:	ffffd097          	auipc	ra,0xffffd
    80003190:	3fc080e7          	jalr	1020(ra) # 80000588 <printf>
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
    80003194:	6cbc                	ld	a5,88(s1)
    80003196:	577d                	li	a4,-1
    80003198:	fbb8                	sd	a4,112(a5)
  }
}
    8000319a:	60e2                	ld	ra,24(sp)
    8000319c:	6442                	ld	s0,16(sp)
    8000319e:	64a2                	ld	s1,8(sp)
    800031a0:	6902                	ld	s2,0(sp)
    800031a2:	6105                	addi	sp,sp,32
    800031a4:	8082                	ret

00000000800031a6 <sys_exit>:
#include "spinlock.h"
#include "proc.h"

uint64
sys_exit(void)
{
    800031a6:	1101                	addi	sp,sp,-32
    800031a8:	ec06                	sd	ra,24(sp)
    800031aa:	e822                	sd	s0,16(sp)
    800031ac:	1000                	addi	s0,sp,32
  int n;
  argint(0, &n);
    800031ae:	fec40593          	addi	a1,s0,-20
    800031b2:	4501                	li	a0,0
    800031b4:	00000097          	auipc	ra,0x0
    800031b8:	f0e080e7          	jalr	-242(ra) # 800030c2 <argint>
  exit(n);
    800031bc:	fec42503          	lw	a0,-20(s0)
    800031c0:	fffff097          	auipc	ra,0xfffff
    800031c4:	3ae080e7          	jalr	942(ra) # 8000256e <exit>
  return 0; // not reached
}
    800031c8:	4501                	li	a0,0
    800031ca:	60e2                	ld	ra,24(sp)
    800031cc:	6442                	ld	s0,16(sp)
    800031ce:	6105                	addi	sp,sp,32
    800031d0:	8082                	ret

00000000800031d2 <sys_getpid>:

uint64
sys_getpid(void)
{
    800031d2:	1141                	addi	sp,sp,-16
    800031d4:	e406                	sd	ra,8(sp)
    800031d6:	e022                	sd	s0,0(sp)
    800031d8:	0800                	addi	s0,sp,16
  return myproc()->pid;
    800031da:	fffff097          	auipc	ra,0xfffff
    800031de:	ba4080e7          	jalr	-1116(ra) # 80001d7e <myproc>
}
    800031e2:	5908                	lw	a0,48(a0)
    800031e4:	60a2                	ld	ra,8(sp)
    800031e6:	6402                	ld	s0,0(sp)
    800031e8:	0141                	addi	sp,sp,16
    800031ea:	8082                	ret

00000000800031ec <sys_fork>:

uint64
sys_fork(void)
{
    800031ec:	1141                	addi	sp,sp,-16
    800031ee:	e406                	sd	ra,8(sp)
    800031f0:	e022                	sd	s0,0(sp)
    800031f2:	0800                	addi	s0,sp,16
  return fork();
    800031f4:	fffff097          	auipc	ra,0xfffff
    800031f8:	f54080e7          	jalr	-172(ra) # 80002148 <fork>
}
    800031fc:	60a2                	ld	ra,8(sp)
    800031fe:	6402                	ld	s0,0(sp)
    80003200:	0141                	addi	sp,sp,16
    80003202:	8082                	ret

0000000080003204 <sys_wait>:

uint64
sys_wait(void)
{
    80003204:	1101                	addi	sp,sp,-32
    80003206:	ec06                	sd	ra,24(sp)
    80003208:	e822                	sd	s0,16(sp)
    8000320a:	1000                	addi	s0,sp,32
  uint64 p;
  argaddr(0, &p);
    8000320c:	fe840593          	addi	a1,s0,-24
    80003210:	4501                	li	a0,0
    80003212:	00000097          	auipc	ra,0x0
    80003216:	ed0080e7          	jalr	-304(ra) # 800030e2 <argaddr>
  return wait(p);
    8000321a:	fe843503          	ld	a0,-24(s0)
    8000321e:	fffff097          	auipc	ra,0xfffff
    80003222:	502080e7          	jalr	1282(ra) # 80002720 <wait>
}
    80003226:	60e2                	ld	ra,24(sp)
    80003228:	6442                	ld	s0,16(sp)
    8000322a:	6105                	addi	sp,sp,32
    8000322c:	8082                	ret

000000008000322e <sys_sbrk>:

uint64
sys_sbrk(void)
{
    8000322e:	7179                	addi	sp,sp,-48
    80003230:	f406                	sd	ra,40(sp)
    80003232:	f022                	sd	s0,32(sp)
    80003234:	ec26                	sd	s1,24(sp)
    80003236:	1800                	addi	s0,sp,48
  uint64 addr;
  int n;

  argint(0, &n);
    80003238:	fdc40593          	addi	a1,s0,-36
    8000323c:	4501                	li	a0,0
    8000323e:	00000097          	auipc	ra,0x0
    80003242:	e84080e7          	jalr	-380(ra) # 800030c2 <argint>
  addr = myproc()->sz;
    80003246:	fffff097          	auipc	ra,0xfffff
    8000324a:	b38080e7          	jalr	-1224(ra) # 80001d7e <myproc>
    8000324e:	6524                	ld	s1,72(a0)
  if (growproc(n) < 0)
    80003250:	fdc42503          	lw	a0,-36(s0)
    80003254:	fffff097          	auipc	ra,0xfffff
    80003258:	e98080e7          	jalr	-360(ra) # 800020ec <growproc>
    8000325c:	00054863          	bltz	a0,8000326c <sys_sbrk+0x3e>
    return -1;
  return addr;
}
    80003260:	8526                	mv	a0,s1
    80003262:	70a2                	ld	ra,40(sp)
    80003264:	7402                	ld	s0,32(sp)
    80003266:	64e2                	ld	s1,24(sp)
    80003268:	6145                	addi	sp,sp,48
    8000326a:	8082                	ret
    return -1;
    8000326c:	54fd                	li	s1,-1
    8000326e:	bfcd                	j	80003260 <sys_sbrk+0x32>

0000000080003270 <sys_sleep>:

uint64
sys_sleep(void)
{
    80003270:	7139                	addi	sp,sp,-64
    80003272:	fc06                	sd	ra,56(sp)
    80003274:	f822                	sd	s0,48(sp)
    80003276:	f426                	sd	s1,40(sp)
    80003278:	f04a                	sd	s2,32(sp)
    8000327a:	ec4e                	sd	s3,24(sp)
    8000327c:	0080                	addi	s0,sp,64
  int n;
  uint ticks0;

  argint(0, &n);
    8000327e:	fcc40593          	addi	a1,s0,-52
    80003282:	4501                	li	a0,0
    80003284:	00000097          	auipc	ra,0x0
    80003288:	e3e080e7          	jalr	-450(ra) # 800030c2 <argint>
  acquire(&tickslock);
    8000328c:	00034517          	auipc	a0,0x34
    80003290:	b3450513          	addi	a0,a0,-1228 # 80036dc0 <tickslock>
    80003294:	ffffe097          	auipc	ra,0xffffe
    80003298:	bf6080e7          	jalr	-1034(ra) # 80000e8a <acquire>
  ticks0 = ticks;
    8000329c:	00005917          	auipc	s2,0x5
    800032a0:	68492903          	lw	s2,1668(s2) # 80008920 <ticks>
  while (ticks - ticks0 < n)
    800032a4:	fcc42783          	lw	a5,-52(s0)
    800032a8:	cf9d                	beqz	a5,800032e6 <sys_sleep+0x76>
    if (killed(myproc()))
    {
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    800032aa:	00034997          	auipc	s3,0x34
    800032ae:	b1698993          	addi	s3,s3,-1258 # 80036dc0 <tickslock>
    800032b2:	00005497          	auipc	s1,0x5
    800032b6:	66e48493          	addi	s1,s1,1646 # 80008920 <ticks>
    if (killed(myproc()))
    800032ba:	fffff097          	auipc	ra,0xfffff
    800032be:	ac4080e7          	jalr	-1340(ra) # 80001d7e <myproc>
    800032c2:	fffff097          	auipc	ra,0xfffff
    800032c6:	42c080e7          	jalr	1068(ra) # 800026ee <killed>
    800032ca:	ed15                	bnez	a0,80003306 <sys_sleep+0x96>
    sleep(&ticks, &tickslock);
    800032cc:	85ce                	mv	a1,s3
    800032ce:	8526                	mv	a0,s1
    800032d0:	fffff097          	auipc	ra,0xfffff
    800032d4:	16a080e7          	jalr	362(ra) # 8000243a <sleep>
  while (ticks - ticks0 < n)
    800032d8:	409c                	lw	a5,0(s1)
    800032da:	412787bb          	subw	a5,a5,s2
    800032de:	fcc42703          	lw	a4,-52(s0)
    800032e2:	fce7ece3          	bltu	a5,a4,800032ba <sys_sleep+0x4a>
  }
  release(&tickslock);
    800032e6:	00034517          	auipc	a0,0x34
    800032ea:	ada50513          	addi	a0,a0,-1318 # 80036dc0 <tickslock>
    800032ee:	ffffe097          	auipc	ra,0xffffe
    800032f2:	c50080e7          	jalr	-944(ra) # 80000f3e <release>
  return 0;
    800032f6:	4501                	li	a0,0
}
    800032f8:	70e2                	ld	ra,56(sp)
    800032fa:	7442                	ld	s0,48(sp)
    800032fc:	74a2                	ld	s1,40(sp)
    800032fe:	7902                	ld	s2,32(sp)
    80003300:	69e2                	ld	s3,24(sp)
    80003302:	6121                	addi	sp,sp,64
    80003304:	8082                	ret
      release(&tickslock);
    80003306:	00034517          	auipc	a0,0x34
    8000330a:	aba50513          	addi	a0,a0,-1350 # 80036dc0 <tickslock>
    8000330e:	ffffe097          	auipc	ra,0xffffe
    80003312:	c30080e7          	jalr	-976(ra) # 80000f3e <release>
      return -1;
    80003316:	557d                	li	a0,-1
    80003318:	b7c5                	j	800032f8 <sys_sleep+0x88>

000000008000331a <sys_kill>:

uint64
sys_kill(void)
{
    8000331a:	1101                	addi	sp,sp,-32
    8000331c:	ec06                	sd	ra,24(sp)
    8000331e:	e822                	sd	s0,16(sp)
    80003320:	1000                	addi	s0,sp,32
  int pid;

  argint(0, &pid);
    80003322:	fec40593          	addi	a1,s0,-20
    80003326:	4501                	li	a0,0
    80003328:	00000097          	auipc	ra,0x0
    8000332c:	d9a080e7          	jalr	-614(ra) # 800030c2 <argint>
  return kill(pid);
    80003330:	fec42503          	lw	a0,-20(s0)
    80003334:	fffff097          	auipc	ra,0xfffff
    80003338:	31c080e7          	jalr	796(ra) # 80002650 <kill>
}
    8000333c:	60e2                	ld	ra,24(sp)
    8000333e:	6442                	ld	s0,16(sp)
    80003340:	6105                	addi	sp,sp,32
    80003342:	8082                	ret

0000000080003344 <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    80003344:	1101                	addi	sp,sp,-32
    80003346:	ec06                	sd	ra,24(sp)
    80003348:	e822                	sd	s0,16(sp)
    8000334a:	e426                	sd	s1,8(sp)
    8000334c:	1000                	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    8000334e:	00034517          	auipc	a0,0x34
    80003352:	a7250513          	addi	a0,a0,-1422 # 80036dc0 <tickslock>
    80003356:	ffffe097          	auipc	ra,0xffffe
    8000335a:	b34080e7          	jalr	-1228(ra) # 80000e8a <acquire>
  xticks = ticks;
    8000335e:	00005497          	auipc	s1,0x5
    80003362:	5c24a483          	lw	s1,1474(s1) # 80008920 <ticks>
  release(&tickslock);
    80003366:	00034517          	auipc	a0,0x34
    8000336a:	a5a50513          	addi	a0,a0,-1446 # 80036dc0 <tickslock>
    8000336e:	ffffe097          	auipc	ra,0xffffe
    80003372:	bd0080e7          	jalr	-1072(ra) # 80000f3e <release>
  return xticks;
}
    80003376:	02049513          	slli	a0,s1,0x20
    8000337a:	9101                	srli	a0,a0,0x20
    8000337c:	60e2                	ld	ra,24(sp)
    8000337e:	6442                	ld	s0,16(sp)
    80003380:	64a2                	ld	s1,8(sp)
    80003382:	6105                	addi	sp,sp,32
    80003384:	8082                	ret

0000000080003386 <sys_waitx>:

uint64
sys_waitx(void)
{
    80003386:	7139                	addi	sp,sp,-64
    80003388:	fc06                	sd	ra,56(sp)
    8000338a:	f822                	sd	s0,48(sp)
    8000338c:	f426                	sd	s1,40(sp)
    8000338e:	f04a                	sd	s2,32(sp)
    80003390:	0080                	addi	s0,sp,64
  uint64 addr, addr1, addr2;
  uint wtime, rtime;
  argaddr(0, &addr);
    80003392:	fd840593          	addi	a1,s0,-40
    80003396:	4501                	li	a0,0
    80003398:	00000097          	auipc	ra,0x0
    8000339c:	d4a080e7          	jalr	-694(ra) # 800030e2 <argaddr>
  argaddr(1, &addr1); // user virtual memory
    800033a0:	fd040593          	addi	a1,s0,-48
    800033a4:	4505                	li	a0,1
    800033a6:	00000097          	auipc	ra,0x0
    800033aa:	d3c080e7          	jalr	-708(ra) # 800030e2 <argaddr>
  argaddr(2, &addr2);
    800033ae:	fc840593          	addi	a1,s0,-56
    800033b2:	4509                	li	a0,2
    800033b4:	00000097          	auipc	ra,0x0
    800033b8:	d2e080e7          	jalr	-722(ra) # 800030e2 <argaddr>
  int ret = waitx(addr, &wtime, &rtime);
    800033bc:	fc040613          	addi	a2,s0,-64
    800033c0:	fc440593          	addi	a1,s0,-60
    800033c4:	fd843503          	ld	a0,-40(s0)
    800033c8:	fffff097          	auipc	ra,0xfffff
    800033cc:	5e0080e7          	jalr	1504(ra) # 800029a8 <waitx>
    800033d0:	892a                	mv	s2,a0
  struct proc *p = myproc();
    800033d2:	fffff097          	auipc	ra,0xfffff
    800033d6:	9ac080e7          	jalr	-1620(ra) # 80001d7e <myproc>
    800033da:	84aa                	mv	s1,a0
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    800033dc:	4691                	li	a3,4
    800033de:	fc440613          	addi	a2,s0,-60
    800033e2:	fd043583          	ld	a1,-48(s0)
    800033e6:	6928                	ld	a0,80(a0)
    800033e8:	ffffe097          	auipc	ra,0xffffe
    800033ec:	74a080e7          	jalr	1866(ra) # 80001b32 <copyout>
    return -1;
    800033f0:	57fd                	li	a5,-1
  if (copyout(p->pagetable, addr1, (char *)&wtime, sizeof(int)) < 0)
    800033f2:	00054f63          	bltz	a0,80003410 <sys_waitx+0x8a>
  if (copyout(p->pagetable, addr2, (char *)&rtime, sizeof(int)) < 0)
    800033f6:	4691                	li	a3,4
    800033f8:	fc040613          	addi	a2,s0,-64
    800033fc:	fc843583          	ld	a1,-56(s0)
    80003400:	68a8                	ld	a0,80(s1)
    80003402:	ffffe097          	auipc	ra,0xffffe
    80003406:	730080e7          	jalr	1840(ra) # 80001b32 <copyout>
    8000340a:	00054a63          	bltz	a0,8000341e <sys_waitx+0x98>
    return -1;
  return ret;
    8000340e:	87ca                	mv	a5,s2
    80003410:	853e                	mv	a0,a5
    80003412:	70e2                	ld	ra,56(sp)
    80003414:	7442                	ld	s0,48(sp)
    80003416:	74a2                	ld	s1,40(sp)
    80003418:	7902                	ld	s2,32(sp)
    8000341a:	6121                	addi	sp,sp,64
    8000341c:	8082                	ret
    return -1;
    8000341e:	57fd                	li	a5,-1
    80003420:	bfc5                	j	80003410 <sys_waitx+0x8a>

0000000080003422 <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    80003422:	7179                	addi	sp,sp,-48
    80003424:	f406                	sd	ra,40(sp)
    80003426:	f022                	sd	s0,32(sp)
    80003428:	ec26                	sd	s1,24(sp)
    8000342a:	e84a                	sd	s2,16(sp)
    8000342c:	e44e                	sd	s3,8(sp)
    8000342e:	e052                	sd	s4,0(sp)
    80003430:	1800                	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    80003432:	00005597          	auipc	a1,0x5
    80003436:	12658593          	addi	a1,a1,294 # 80008558 <syscalls+0xb8>
    8000343a:	00034517          	auipc	a0,0x34
    8000343e:	99e50513          	addi	a0,a0,-1634 # 80036dd8 <bcache>
    80003442:	ffffe097          	auipc	ra,0xffffe
    80003446:	9b8080e7          	jalr	-1608(ra) # 80000dfa <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    8000344a:	0003c797          	auipc	a5,0x3c
    8000344e:	98e78793          	addi	a5,a5,-1650 # 8003edd8 <bcache+0x8000>
    80003452:	0003c717          	auipc	a4,0x3c
    80003456:	bee70713          	addi	a4,a4,-1042 # 8003f040 <bcache+0x8268>
    8000345a:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    8000345e:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80003462:	00034497          	auipc	s1,0x34
    80003466:	98e48493          	addi	s1,s1,-1650 # 80036df0 <bcache+0x18>
    b->next = bcache.head.next;
    8000346a:	893e                	mv	s2,a5
    b->prev = &bcache.head;
    8000346c:	89ba                	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    8000346e:	00005a17          	auipc	s4,0x5
    80003472:	0f2a0a13          	addi	s4,s4,242 # 80008560 <syscalls+0xc0>
    b->next = bcache.head.next;
    80003476:	2b893783          	ld	a5,696(s2)
    8000347a:	e8bc                	sd	a5,80(s1)
    b->prev = &bcache.head;
    8000347c:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    80003480:	85d2                	mv	a1,s4
    80003482:	01048513          	addi	a0,s1,16
    80003486:	00001097          	auipc	ra,0x1
    8000348a:	4c4080e7          	jalr	1220(ra) # 8000494a <initsleeplock>
    bcache.head.next->prev = b;
    8000348e:	2b893783          	ld	a5,696(s2)
    80003492:	e7a4                	sd	s1,72(a5)
    bcache.head.next = b;
    80003494:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80003498:	45848493          	addi	s1,s1,1112
    8000349c:	fd349de3          	bne	s1,s3,80003476 <binit+0x54>
  }
}
    800034a0:	70a2                	ld	ra,40(sp)
    800034a2:	7402                	ld	s0,32(sp)
    800034a4:	64e2                	ld	s1,24(sp)
    800034a6:	6942                	ld	s2,16(sp)
    800034a8:	69a2                	ld	s3,8(sp)
    800034aa:	6a02                	ld	s4,0(sp)
    800034ac:	6145                	addi	sp,sp,48
    800034ae:	8082                	ret

00000000800034b0 <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    800034b0:	7179                	addi	sp,sp,-48
    800034b2:	f406                	sd	ra,40(sp)
    800034b4:	f022                	sd	s0,32(sp)
    800034b6:	ec26                	sd	s1,24(sp)
    800034b8:	e84a                	sd	s2,16(sp)
    800034ba:	e44e                	sd	s3,8(sp)
    800034bc:	1800                	addi	s0,sp,48
    800034be:	892a                	mv	s2,a0
    800034c0:	89ae                	mv	s3,a1
  acquire(&bcache.lock);
    800034c2:	00034517          	auipc	a0,0x34
    800034c6:	91650513          	addi	a0,a0,-1770 # 80036dd8 <bcache>
    800034ca:	ffffe097          	auipc	ra,0xffffe
    800034ce:	9c0080e7          	jalr	-1600(ra) # 80000e8a <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    800034d2:	0003c497          	auipc	s1,0x3c
    800034d6:	bbe4b483          	ld	s1,-1090(s1) # 8003f090 <bcache+0x82b8>
    800034da:	0003c797          	auipc	a5,0x3c
    800034de:	b6678793          	addi	a5,a5,-1178 # 8003f040 <bcache+0x8268>
    800034e2:	02f48f63          	beq	s1,a5,80003520 <bread+0x70>
    800034e6:	873e                	mv	a4,a5
    800034e8:	a021                	j	800034f0 <bread+0x40>
    800034ea:	68a4                	ld	s1,80(s1)
    800034ec:	02e48a63          	beq	s1,a4,80003520 <bread+0x70>
    if(b->dev == dev && b->blockno == blockno){
    800034f0:	449c                	lw	a5,8(s1)
    800034f2:	ff279ce3          	bne	a5,s2,800034ea <bread+0x3a>
    800034f6:	44dc                	lw	a5,12(s1)
    800034f8:	ff3799e3          	bne	a5,s3,800034ea <bread+0x3a>
      b->refcnt++;
    800034fc:	40bc                	lw	a5,64(s1)
    800034fe:	2785                	addiw	a5,a5,1
    80003500:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80003502:	00034517          	auipc	a0,0x34
    80003506:	8d650513          	addi	a0,a0,-1834 # 80036dd8 <bcache>
    8000350a:	ffffe097          	auipc	ra,0xffffe
    8000350e:	a34080e7          	jalr	-1484(ra) # 80000f3e <release>
      acquiresleep(&b->lock);
    80003512:	01048513          	addi	a0,s1,16
    80003516:	00001097          	auipc	ra,0x1
    8000351a:	46e080e7          	jalr	1134(ra) # 80004984 <acquiresleep>
      return b;
    8000351e:	a8b9                	j	8000357c <bread+0xcc>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80003520:	0003c497          	auipc	s1,0x3c
    80003524:	b684b483          	ld	s1,-1176(s1) # 8003f088 <bcache+0x82b0>
    80003528:	0003c797          	auipc	a5,0x3c
    8000352c:	b1878793          	addi	a5,a5,-1256 # 8003f040 <bcache+0x8268>
    80003530:	00f48863          	beq	s1,a5,80003540 <bread+0x90>
    80003534:	873e                	mv	a4,a5
    if(b->refcnt == 0) {
    80003536:	40bc                	lw	a5,64(s1)
    80003538:	cf81                	beqz	a5,80003550 <bread+0xa0>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    8000353a:	64a4                	ld	s1,72(s1)
    8000353c:	fee49de3          	bne	s1,a4,80003536 <bread+0x86>
  panic("bget: no buffers");
    80003540:	00005517          	auipc	a0,0x5
    80003544:	02850513          	addi	a0,a0,40 # 80008568 <syscalls+0xc8>
    80003548:	ffffd097          	auipc	ra,0xffffd
    8000354c:	ff6080e7          	jalr	-10(ra) # 8000053e <panic>
      b->dev = dev;
    80003550:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    80003554:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    80003558:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    8000355c:	4785                	li	a5,1
    8000355e:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80003560:	00034517          	auipc	a0,0x34
    80003564:	87850513          	addi	a0,a0,-1928 # 80036dd8 <bcache>
    80003568:	ffffe097          	auipc	ra,0xffffe
    8000356c:	9d6080e7          	jalr	-1578(ra) # 80000f3e <release>
      acquiresleep(&b->lock);
    80003570:	01048513          	addi	a0,s1,16
    80003574:	00001097          	auipc	ra,0x1
    80003578:	410080e7          	jalr	1040(ra) # 80004984 <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    8000357c:	409c                	lw	a5,0(s1)
    8000357e:	cb89                	beqz	a5,80003590 <bread+0xe0>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    80003580:	8526                	mv	a0,s1
    80003582:	70a2                	ld	ra,40(sp)
    80003584:	7402                	ld	s0,32(sp)
    80003586:	64e2                	ld	s1,24(sp)
    80003588:	6942                	ld	s2,16(sp)
    8000358a:	69a2                	ld	s3,8(sp)
    8000358c:	6145                	addi	sp,sp,48
    8000358e:	8082                	ret
    virtio_disk_rw(b, 0);
    80003590:	4581                	li	a1,0
    80003592:	8526                	mv	a0,s1
    80003594:	00003097          	auipc	ra,0x3
    80003598:	fd0080e7          	jalr	-48(ra) # 80006564 <virtio_disk_rw>
    b->valid = 1;
    8000359c:	4785                	li	a5,1
    8000359e:	c09c                	sw	a5,0(s1)
  return b;
    800035a0:	b7c5                	j	80003580 <bread+0xd0>

00000000800035a2 <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    800035a2:	1101                	addi	sp,sp,-32
    800035a4:	ec06                	sd	ra,24(sp)
    800035a6:	e822                	sd	s0,16(sp)
    800035a8:	e426                	sd	s1,8(sp)
    800035aa:	1000                	addi	s0,sp,32
    800035ac:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    800035ae:	0541                	addi	a0,a0,16
    800035b0:	00001097          	auipc	ra,0x1
    800035b4:	46e080e7          	jalr	1134(ra) # 80004a1e <holdingsleep>
    800035b8:	cd01                	beqz	a0,800035d0 <bwrite+0x2e>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    800035ba:	4585                	li	a1,1
    800035bc:	8526                	mv	a0,s1
    800035be:	00003097          	auipc	ra,0x3
    800035c2:	fa6080e7          	jalr	-90(ra) # 80006564 <virtio_disk_rw>
}
    800035c6:	60e2                	ld	ra,24(sp)
    800035c8:	6442                	ld	s0,16(sp)
    800035ca:	64a2                	ld	s1,8(sp)
    800035cc:	6105                	addi	sp,sp,32
    800035ce:	8082                	ret
    panic("bwrite");
    800035d0:	00005517          	auipc	a0,0x5
    800035d4:	fb050513          	addi	a0,a0,-80 # 80008580 <syscalls+0xe0>
    800035d8:	ffffd097          	auipc	ra,0xffffd
    800035dc:	f66080e7          	jalr	-154(ra) # 8000053e <panic>

00000000800035e0 <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    800035e0:	1101                	addi	sp,sp,-32
    800035e2:	ec06                	sd	ra,24(sp)
    800035e4:	e822                	sd	s0,16(sp)
    800035e6:	e426                	sd	s1,8(sp)
    800035e8:	e04a                	sd	s2,0(sp)
    800035ea:	1000                	addi	s0,sp,32
    800035ec:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    800035ee:	01050913          	addi	s2,a0,16
    800035f2:	854a                	mv	a0,s2
    800035f4:	00001097          	auipc	ra,0x1
    800035f8:	42a080e7          	jalr	1066(ra) # 80004a1e <holdingsleep>
    800035fc:	c92d                	beqz	a0,8000366e <brelse+0x8e>
    panic("brelse");

  releasesleep(&b->lock);
    800035fe:	854a                	mv	a0,s2
    80003600:	00001097          	auipc	ra,0x1
    80003604:	3da080e7          	jalr	986(ra) # 800049da <releasesleep>

  acquire(&bcache.lock);
    80003608:	00033517          	auipc	a0,0x33
    8000360c:	7d050513          	addi	a0,a0,2000 # 80036dd8 <bcache>
    80003610:	ffffe097          	auipc	ra,0xffffe
    80003614:	87a080e7          	jalr	-1926(ra) # 80000e8a <acquire>
  b->refcnt--;
    80003618:	40bc                	lw	a5,64(s1)
    8000361a:	37fd                	addiw	a5,a5,-1
    8000361c:	0007871b          	sext.w	a4,a5
    80003620:	c0bc                	sw	a5,64(s1)
  if (b->refcnt == 0) {
    80003622:	eb05                	bnez	a4,80003652 <brelse+0x72>
    // no one is waiting for it.
    b->next->prev = b->prev;
    80003624:	68bc                	ld	a5,80(s1)
    80003626:	64b8                	ld	a4,72(s1)
    80003628:	e7b8                	sd	a4,72(a5)
    b->prev->next = b->next;
    8000362a:	64bc                	ld	a5,72(s1)
    8000362c:	68b8                	ld	a4,80(s1)
    8000362e:	ebb8                	sd	a4,80(a5)
    b->next = bcache.head.next;
    80003630:	0003b797          	auipc	a5,0x3b
    80003634:	7a878793          	addi	a5,a5,1960 # 8003edd8 <bcache+0x8000>
    80003638:	2b87b703          	ld	a4,696(a5)
    8000363c:	e8b8                	sd	a4,80(s1)
    b->prev = &bcache.head;
    8000363e:	0003c717          	auipc	a4,0x3c
    80003642:	a0270713          	addi	a4,a4,-1534 # 8003f040 <bcache+0x8268>
    80003646:	e4b8                	sd	a4,72(s1)
    bcache.head.next->prev = b;
    80003648:	2b87b703          	ld	a4,696(a5)
    8000364c:	e724                	sd	s1,72(a4)
    bcache.head.next = b;
    8000364e:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    80003652:	00033517          	auipc	a0,0x33
    80003656:	78650513          	addi	a0,a0,1926 # 80036dd8 <bcache>
    8000365a:	ffffe097          	auipc	ra,0xffffe
    8000365e:	8e4080e7          	jalr	-1820(ra) # 80000f3e <release>
}
    80003662:	60e2                	ld	ra,24(sp)
    80003664:	6442                	ld	s0,16(sp)
    80003666:	64a2                	ld	s1,8(sp)
    80003668:	6902                	ld	s2,0(sp)
    8000366a:	6105                	addi	sp,sp,32
    8000366c:	8082                	ret
    panic("brelse");
    8000366e:	00005517          	auipc	a0,0x5
    80003672:	f1a50513          	addi	a0,a0,-230 # 80008588 <syscalls+0xe8>
    80003676:	ffffd097          	auipc	ra,0xffffd
    8000367a:	ec8080e7          	jalr	-312(ra) # 8000053e <panic>

000000008000367e <bpin>:

void
bpin(struct buf *b) {
    8000367e:	1101                	addi	sp,sp,-32
    80003680:	ec06                	sd	ra,24(sp)
    80003682:	e822                	sd	s0,16(sp)
    80003684:	e426                	sd	s1,8(sp)
    80003686:	1000                	addi	s0,sp,32
    80003688:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    8000368a:	00033517          	auipc	a0,0x33
    8000368e:	74e50513          	addi	a0,a0,1870 # 80036dd8 <bcache>
    80003692:	ffffd097          	auipc	ra,0xffffd
    80003696:	7f8080e7          	jalr	2040(ra) # 80000e8a <acquire>
  b->refcnt++;
    8000369a:	40bc                	lw	a5,64(s1)
    8000369c:	2785                	addiw	a5,a5,1
    8000369e:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    800036a0:	00033517          	auipc	a0,0x33
    800036a4:	73850513          	addi	a0,a0,1848 # 80036dd8 <bcache>
    800036a8:	ffffe097          	auipc	ra,0xffffe
    800036ac:	896080e7          	jalr	-1898(ra) # 80000f3e <release>
}
    800036b0:	60e2                	ld	ra,24(sp)
    800036b2:	6442                	ld	s0,16(sp)
    800036b4:	64a2                	ld	s1,8(sp)
    800036b6:	6105                	addi	sp,sp,32
    800036b8:	8082                	ret

00000000800036ba <bunpin>:

void
bunpin(struct buf *b) {
    800036ba:	1101                	addi	sp,sp,-32
    800036bc:	ec06                	sd	ra,24(sp)
    800036be:	e822                	sd	s0,16(sp)
    800036c0:	e426                	sd	s1,8(sp)
    800036c2:	1000                	addi	s0,sp,32
    800036c4:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    800036c6:	00033517          	auipc	a0,0x33
    800036ca:	71250513          	addi	a0,a0,1810 # 80036dd8 <bcache>
    800036ce:	ffffd097          	auipc	ra,0xffffd
    800036d2:	7bc080e7          	jalr	1980(ra) # 80000e8a <acquire>
  b->refcnt--;
    800036d6:	40bc                	lw	a5,64(s1)
    800036d8:	37fd                	addiw	a5,a5,-1
    800036da:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    800036dc:	00033517          	auipc	a0,0x33
    800036e0:	6fc50513          	addi	a0,a0,1788 # 80036dd8 <bcache>
    800036e4:	ffffe097          	auipc	ra,0xffffe
    800036e8:	85a080e7          	jalr	-1958(ra) # 80000f3e <release>
}
    800036ec:	60e2                	ld	ra,24(sp)
    800036ee:	6442                	ld	s0,16(sp)
    800036f0:	64a2                	ld	s1,8(sp)
    800036f2:	6105                	addi	sp,sp,32
    800036f4:	8082                	ret

00000000800036f6 <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    800036f6:	1101                	addi	sp,sp,-32
    800036f8:	ec06                	sd	ra,24(sp)
    800036fa:	e822                	sd	s0,16(sp)
    800036fc:	e426                	sd	s1,8(sp)
    800036fe:	e04a                	sd	s2,0(sp)
    80003700:	1000                	addi	s0,sp,32
    80003702:	84ae                	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    80003704:	00d5d59b          	srliw	a1,a1,0xd
    80003708:	0003c797          	auipc	a5,0x3c
    8000370c:	dac7a783          	lw	a5,-596(a5) # 8003f4b4 <sb+0x1c>
    80003710:	9dbd                	addw	a1,a1,a5
    80003712:	00000097          	auipc	ra,0x0
    80003716:	d9e080e7          	jalr	-610(ra) # 800034b0 <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    8000371a:	0074f713          	andi	a4,s1,7
    8000371e:	4785                	li	a5,1
    80003720:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    80003724:	14ce                	slli	s1,s1,0x33
    80003726:	90d9                	srli	s1,s1,0x36
    80003728:	00950733          	add	a4,a0,s1
    8000372c:	05874703          	lbu	a4,88(a4)
    80003730:	00e7f6b3          	and	a3,a5,a4
    80003734:	c69d                	beqz	a3,80003762 <bfree+0x6c>
    80003736:	892a                	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    80003738:	94aa                	add	s1,s1,a0
    8000373a:	fff7c793          	not	a5,a5
    8000373e:	8ff9                	and	a5,a5,a4
    80003740:	04f48c23          	sb	a5,88(s1)
  log_write(bp);
    80003744:	00001097          	auipc	ra,0x1
    80003748:	120080e7          	jalr	288(ra) # 80004864 <log_write>
  brelse(bp);
    8000374c:	854a                	mv	a0,s2
    8000374e:	00000097          	auipc	ra,0x0
    80003752:	e92080e7          	jalr	-366(ra) # 800035e0 <brelse>
}
    80003756:	60e2                	ld	ra,24(sp)
    80003758:	6442                	ld	s0,16(sp)
    8000375a:	64a2                	ld	s1,8(sp)
    8000375c:	6902                	ld	s2,0(sp)
    8000375e:	6105                	addi	sp,sp,32
    80003760:	8082                	ret
    panic("freeing free block");
    80003762:	00005517          	auipc	a0,0x5
    80003766:	e2e50513          	addi	a0,a0,-466 # 80008590 <syscalls+0xf0>
    8000376a:	ffffd097          	auipc	ra,0xffffd
    8000376e:	dd4080e7          	jalr	-556(ra) # 8000053e <panic>

0000000080003772 <balloc>:
{
    80003772:	711d                	addi	sp,sp,-96
    80003774:	ec86                	sd	ra,88(sp)
    80003776:	e8a2                	sd	s0,80(sp)
    80003778:	e4a6                	sd	s1,72(sp)
    8000377a:	e0ca                	sd	s2,64(sp)
    8000377c:	fc4e                	sd	s3,56(sp)
    8000377e:	f852                	sd	s4,48(sp)
    80003780:	f456                	sd	s5,40(sp)
    80003782:	f05a                	sd	s6,32(sp)
    80003784:	ec5e                	sd	s7,24(sp)
    80003786:	e862                	sd	s8,16(sp)
    80003788:	e466                	sd	s9,8(sp)
    8000378a:	1080                	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    8000378c:	0003c797          	auipc	a5,0x3c
    80003790:	d107a783          	lw	a5,-752(a5) # 8003f49c <sb+0x4>
    80003794:	10078163          	beqz	a5,80003896 <balloc+0x124>
    80003798:	8baa                	mv	s7,a0
    8000379a:	4a81                	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    8000379c:	0003cb17          	auipc	s6,0x3c
    800037a0:	cfcb0b13          	addi	s6,s6,-772 # 8003f498 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800037a4:	4c01                	li	s8,0
      m = 1 << (bi % 8);
    800037a6:	4985                	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800037a8:	6a09                	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    800037aa:	6c89                	lui	s9,0x2
    800037ac:	a061                	j	80003834 <balloc+0xc2>
        bp->data[bi/8] |= m;  // Mark block in use.
    800037ae:	974a                	add	a4,a4,s2
    800037b0:	8fd5                	or	a5,a5,a3
    800037b2:	04f70c23          	sb	a5,88(a4)
        log_write(bp);
    800037b6:	854a                	mv	a0,s2
    800037b8:	00001097          	auipc	ra,0x1
    800037bc:	0ac080e7          	jalr	172(ra) # 80004864 <log_write>
        brelse(bp);
    800037c0:	854a                	mv	a0,s2
    800037c2:	00000097          	auipc	ra,0x0
    800037c6:	e1e080e7          	jalr	-482(ra) # 800035e0 <brelse>
  bp = bread(dev, bno);
    800037ca:	85a6                	mv	a1,s1
    800037cc:	855e                	mv	a0,s7
    800037ce:	00000097          	auipc	ra,0x0
    800037d2:	ce2080e7          	jalr	-798(ra) # 800034b0 <bread>
    800037d6:	892a                	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    800037d8:	40000613          	li	a2,1024
    800037dc:	4581                	li	a1,0
    800037de:	05850513          	addi	a0,a0,88
    800037e2:	ffffd097          	auipc	ra,0xffffd
    800037e6:	7a4080e7          	jalr	1956(ra) # 80000f86 <memset>
  log_write(bp);
    800037ea:	854a                	mv	a0,s2
    800037ec:	00001097          	auipc	ra,0x1
    800037f0:	078080e7          	jalr	120(ra) # 80004864 <log_write>
  brelse(bp);
    800037f4:	854a                	mv	a0,s2
    800037f6:	00000097          	auipc	ra,0x0
    800037fa:	dea080e7          	jalr	-534(ra) # 800035e0 <brelse>
}
    800037fe:	8526                	mv	a0,s1
    80003800:	60e6                	ld	ra,88(sp)
    80003802:	6446                	ld	s0,80(sp)
    80003804:	64a6                	ld	s1,72(sp)
    80003806:	6906                	ld	s2,64(sp)
    80003808:	79e2                	ld	s3,56(sp)
    8000380a:	7a42                	ld	s4,48(sp)
    8000380c:	7aa2                	ld	s5,40(sp)
    8000380e:	7b02                	ld	s6,32(sp)
    80003810:	6be2                	ld	s7,24(sp)
    80003812:	6c42                	ld	s8,16(sp)
    80003814:	6ca2                	ld	s9,8(sp)
    80003816:	6125                	addi	sp,sp,96
    80003818:	8082                	ret
    brelse(bp);
    8000381a:	854a                	mv	a0,s2
    8000381c:	00000097          	auipc	ra,0x0
    80003820:	dc4080e7          	jalr	-572(ra) # 800035e0 <brelse>
  for(b = 0; b < sb.size; b += BPB){
    80003824:	015c87bb          	addw	a5,s9,s5
    80003828:	00078a9b          	sext.w	s5,a5
    8000382c:	004b2703          	lw	a4,4(s6)
    80003830:	06eaf363          	bgeu	s5,a4,80003896 <balloc+0x124>
    bp = bread(dev, BBLOCK(b, sb));
    80003834:	41fad79b          	sraiw	a5,s5,0x1f
    80003838:	0137d79b          	srliw	a5,a5,0x13
    8000383c:	015787bb          	addw	a5,a5,s5
    80003840:	40d7d79b          	sraiw	a5,a5,0xd
    80003844:	01cb2583          	lw	a1,28(s6)
    80003848:	9dbd                	addw	a1,a1,a5
    8000384a:	855e                	mv	a0,s7
    8000384c:	00000097          	auipc	ra,0x0
    80003850:	c64080e7          	jalr	-924(ra) # 800034b0 <bread>
    80003854:	892a                	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003856:	004b2503          	lw	a0,4(s6)
    8000385a:	000a849b          	sext.w	s1,s5
    8000385e:	8662                	mv	a2,s8
    80003860:	faa4fde3          	bgeu	s1,a0,8000381a <balloc+0xa8>
      m = 1 << (bi % 8);
    80003864:	41f6579b          	sraiw	a5,a2,0x1f
    80003868:	01d7d69b          	srliw	a3,a5,0x1d
    8000386c:	00c6873b          	addw	a4,a3,a2
    80003870:	00777793          	andi	a5,a4,7
    80003874:	9f95                	subw	a5,a5,a3
    80003876:	00f997bb          	sllw	a5,s3,a5
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    8000387a:	4037571b          	sraiw	a4,a4,0x3
    8000387e:	00e906b3          	add	a3,s2,a4
    80003882:	0586c683          	lbu	a3,88(a3)
    80003886:	00d7f5b3          	and	a1,a5,a3
    8000388a:	d195                	beqz	a1,800037ae <balloc+0x3c>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    8000388c:	2605                	addiw	a2,a2,1
    8000388e:	2485                	addiw	s1,s1,1
    80003890:	fd4618e3          	bne	a2,s4,80003860 <balloc+0xee>
    80003894:	b759                	j	8000381a <balloc+0xa8>
  printf("balloc: out of blocks\n");
    80003896:	00005517          	auipc	a0,0x5
    8000389a:	d1250513          	addi	a0,a0,-750 # 800085a8 <syscalls+0x108>
    8000389e:	ffffd097          	auipc	ra,0xffffd
    800038a2:	cea080e7          	jalr	-790(ra) # 80000588 <printf>
  return 0;
    800038a6:	4481                	li	s1,0
    800038a8:	bf99                	j	800037fe <balloc+0x8c>

00000000800038aa <bmap>:
// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
// returns 0 if out of disk space.
static uint
bmap(struct inode *ip, uint bn)
{
    800038aa:	7179                	addi	sp,sp,-48
    800038ac:	f406                	sd	ra,40(sp)
    800038ae:	f022                	sd	s0,32(sp)
    800038b0:	ec26                	sd	s1,24(sp)
    800038b2:	e84a                	sd	s2,16(sp)
    800038b4:	e44e                	sd	s3,8(sp)
    800038b6:	e052                	sd	s4,0(sp)
    800038b8:	1800                	addi	s0,sp,48
    800038ba:	89aa                	mv	s3,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    800038bc:	47ad                	li	a5,11
    800038be:	02b7e763          	bltu	a5,a1,800038ec <bmap+0x42>
    if((addr = ip->addrs[bn]) == 0){
    800038c2:	02059493          	slli	s1,a1,0x20
    800038c6:	9081                	srli	s1,s1,0x20
    800038c8:	048a                	slli	s1,s1,0x2
    800038ca:	94aa                	add	s1,s1,a0
    800038cc:	0504a903          	lw	s2,80(s1)
    800038d0:	06091e63          	bnez	s2,8000394c <bmap+0xa2>
      addr = balloc(ip->dev);
    800038d4:	4108                	lw	a0,0(a0)
    800038d6:	00000097          	auipc	ra,0x0
    800038da:	e9c080e7          	jalr	-356(ra) # 80003772 <balloc>
    800038de:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    800038e2:	06090563          	beqz	s2,8000394c <bmap+0xa2>
        return 0;
      ip->addrs[bn] = addr;
    800038e6:	0524a823          	sw	s2,80(s1)
    800038ea:	a08d                	j	8000394c <bmap+0xa2>
    }
    return addr;
  }
  bn -= NDIRECT;
    800038ec:	ff45849b          	addiw	s1,a1,-12
    800038f0:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    800038f4:	0ff00793          	li	a5,255
    800038f8:	08e7e563          	bltu	a5,a4,80003982 <bmap+0xd8>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0){
    800038fc:	08052903          	lw	s2,128(a0)
    80003900:	00091d63          	bnez	s2,8000391a <bmap+0x70>
      addr = balloc(ip->dev);
    80003904:	4108                	lw	a0,0(a0)
    80003906:	00000097          	auipc	ra,0x0
    8000390a:	e6c080e7          	jalr	-404(ra) # 80003772 <balloc>
    8000390e:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003912:	02090d63          	beqz	s2,8000394c <bmap+0xa2>
        return 0;
      ip->addrs[NDIRECT] = addr;
    80003916:	0929a023          	sw	s2,128(s3)
    }
    bp = bread(ip->dev, addr);
    8000391a:	85ca                	mv	a1,s2
    8000391c:	0009a503          	lw	a0,0(s3)
    80003920:	00000097          	auipc	ra,0x0
    80003924:	b90080e7          	jalr	-1136(ra) # 800034b0 <bread>
    80003928:	8a2a                	mv	s4,a0
    a = (uint*)bp->data;
    8000392a:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    8000392e:	02049593          	slli	a1,s1,0x20
    80003932:	9181                	srli	a1,a1,0x20
    80003934:	058a                	slli	a1,a1,0x2
    80003936:	00b784b3          	add	s1,a5,a1
    8000393a:	0004a903          	lw	s2,0(s1)
    8000393e:	02090063          	beqz	s2,8000395e <bmap+0xb4>
      if(addr){
        a[bn] = addr;
        log_write(bp);
      }
    }
    brelse(bp);
    80003942:	8552                	mv	a0,s4
    80003944:	00000097          	auipc	ra,0x0
    80003948:	c9c080e7          	jalr	-868(ra) # 800035e0 <brelse>
    return addr;
  }

  panic("bmap: out of range");
}
    8000394c:	854a                	mv	a0,s2
    8000394e:	70a2                	ld	ra,40(sp)
    80003950:	7402                	ld	s0,32(sp)
    80003952:	64e2                	ld	s1,24(sp)
    80003954:	6942                	ld	s2,16(sp)
    80003956:	69a2                	ld	s3,8(sp)
    80003958:	6a02                	ld	s4,0(sp)
    8000395a:	6145                	addi	sp,sp,48
    8000395c:	8082                	ret
      addr = balloc(ip->dev);
    8000395e:	0009a503          	lw	a0,0(s3)
    80003962:	00000097          	auipc	ra,0x0
    80003966:	e10080e7          	jalr	-496(ra) # 80003772 <balloc>
    8000396a:	0005091b          	sext.w	s2,a0
      if(addr){
    8000396e:	fc090ae3          	beqz	s2,80003942 <bmap+0x98>
        a[bn] = addr;
    80003972:	0124a023          	sw	s2,0(s1)
        log_write(bp);
    80003976:	8552                	mv	a0,s4
    80003978:	00001097          	auipc	ra,0x1
    8000397c:	eec080e7          	jalr	-276(ra) # 80004864 <log_write>
    80003980:	b7c9                	j	80003942 <bmap+0x98>
  panic("bmap: out of range");
    80003982:	00005517          	auipc	a0,0x5
    80003986:	c3e50513          	addi	a0,a0,-962 # 800085c0 <syscalls+0x120>
    8000398a:	ffffd097          	auipc	ra,0xffffd
    8000398e:	bb4080e7          	jalr	-1100(ra) # 8000053e <panic>

0000000080003992 <iget>:
{
    80003992:	7179                	addi	sp,sp,-48
    80003994:	f406                	sd	ra,40(sp)
    80003996:	f022                	sd	s0,32(sp)
    80003998:	ec26                	sd	s1,24(sp)
    8000399a:	e84a                	sd	s2,16(sp)
    8000399c:	e44e                	sd	s3,8(sp)
    8000399e:	e052                	sd	s4,0(sp)
    800039a0:	1800                	addi	s0,sp,48
    800039a2:	89aa                	mv	s3,a0
    800039a4:	8a2e                	mv	s4,a1
  acquire(&itable.lock);
    800039a6:	0003c517          	auipc	a0,0x3c
    800039aa:	b1250513          	addi	a0,a0,-1262 # 8003f4b8 <itable>
    800039ae:	ffffd097          	auipc	ra,0xffffd
    800039b2:	4dc080e7          	jalr	1244(ra) # 80000e8a <acquire>
  empty = 0;
    800039b6:	4901                	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    800039b8:	0003c497          	auipc	s1,0x3c
    800039bc:	b1848493          	addi	s1,s1,-1256 # 8003f4d0 <itable+0x18>
    800039c0:	0003d697          	auipc	a3,0x3d
    800039c4:	5a068693          	addi	a3,a3,1440 # 80040f60 <log>
    800039c8:	a039                	j	800039d6 <iget+0x44>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    800039ca:	02090b63          	beqz	s2,80003a00 <iget+0x6e>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    800039ce:	08848493          	addi	s1,s1,136
    800039d2:	02d48a63          	beq	s1,a3,80003a06 <iget+0x74>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    800039d6:	449c                	lw	a5,8(s1)
    800039d8:	fef059e3          	blez	a5,800039ca <iget+0x38>
    800039dc:	4098                	lw	a4,0(s1)
    800039de:	ff3716e3          	bne	a4,s3,800039ca <iget+0x38>
    800039e2:	40d8                	lw	a4,4(s1)
    800039e4:	ff4713e3          	bne	a4,s4,800039ca <iget+0x38>
      ip->ref++;
    800039e8:	2785                	addiw	a5,a5,1
    800039ea:	c49c                	sw	a5,8(s1)
      release(&itable.lock);
    800039ec:	0003c517          	auipc	a0,0x3c
    800039f0:	acc50513          	addi	a0,a0,-1332 # 8003f4b8 <itable>
    800039f4:	ffffd097          	auipc	ra,0xffffd
    800039f8:	54a080e7          	jalr	1354(ra) # 80000f3e <release>
      return ip;
    800039fc:	8926                	mv	s2,s1
    800039fe:	a03d                	j	80003a2c <iget+0x9a>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003a00:	f7f9                	bnez	a5,800039ce <iget+0x3c>
    80003a02:	8926                	mv	s2,s1
    80003a04:	b7e9                	j	800039ce <iget+0x3c>
  if(empty == 0)
    80003a06:	02090c63          	beqz	s2,80003a3e <iget+0xac>
  ip->dev = dev;
    80003a0a:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    80003a0e:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    80003a12:	4785                	li	a5,1
    80003a14:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    80003a18:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    80003a1c:	0003c517          	auipc	a0,0x3c
    80003a20:	a9c50513          	addi	a0,a0,-1380 # 8003f4b8 <itable>
    80003a24:	ffffd097          	auipc	ra,0xffffd
    80003a28:	51a080e7          	jalr	1306(ra) # 80000f3e <release>
}
    80003a2c:	854a                	mv	a0,s2
    80003a2e:	70a2                	ld	ra,40(sp)
    80003a30:	7402                	ld	s0,32(sp)
    80003a32:	64e2                	ld	s1,24(sp)
    80003a34:	6942                	ld	s2,16(sp)
    80003a36:	69a2                	ld	s3,8(sp)
    80003a38:	6a02                	ld	s4,0(sp)
    80003a3a:	6145                	addi	sp,sp,48
    80003a3c:	8082                	ret
    panic("iget: no inodes");
    80003a3e:	00005517          	auipc	a0,0x5
    80003a42:	b9a50513          	addi	a0,a0,-1126 # 800085d8 <syscalls+0x138>
    80003a46:	ffffd097          	auipc	ra,0xffffd
    80003a4a:	af8080e7          	jalr	-1288(ra) # 8000053e <panic>

0000000080003a4e <fsinit>:
fsinit(int dev) {
    80003a4e:	7179                	addi	sp,sp,-48
    80003a50:	f406                	sd	ra,40(sp)
    80003a52:	f022                	sd	s0,32(sp)
    80003a54:	ec26                	sd	s1,24(sp)
    80003a56:	e84a                	sd	s2,16(sp)
    80003a58:	e44e                	sd	s3,8(sp)
    80003a5a:	1800                	addi	s0,sp,48
    80003a5c:	892a                	mv	s2,a0
  bp = bread(dev, 1);
    80003a5e:	4585                	li	a1,1
    80003a60:	00000097          	auipc	ra,0x0
    80003a64:	a50080e7          	jalr	-1456(ra) # 800034b0 <bread>
    80003a68:	84aa                	mv	s1,a0
  memmove(sb, bp->data, sizeof(*sb));
    80003a6a:	0003c997          	auipc	s3,0x3c
    80003a6e:	a2e98993          	addi	s3,s3,-1490 # 8003f498 <sb>
    80003a72:	02000613          	li	a2,32
    80003a76:	05850593          	addi	a1,a0,88
    80003a7a:	854e                	mv	a0,s3
    80003a7c:	ffffd097          	auipc	ra,0xffffd
    80003a80:	566080e7          	jalr	1382(ra) # 80000fe2 <memmove>
  brelse(bp);
    80003a84:	8526                	mv	a0,s1
    80003a86:	00000097          	auipc	ra,0x0
    80003a8a:	b5a080e7          	jalr	-1190(ra) # 800035e0 <brelse>
  if(sb.magic != FSMAGIC)
    80003a8e:	0009a703          	lw	a4,0(s3)
    80003a92:	102037b7          	lui	a5,0x10203
    80003a96:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    80003a9a:	02f71263          	bne	a4,a5,80003abe <fsinit+0x70>
  initlog(dev, &sb);
    80003a9e:	0003c597          	auipc	a1,0x3c
    80003aa2:	9fa58593          	addi	a1,a1,-1542 # 8003f498 <sb>
    80003aa6:	854a                	mv	a0,s2
    80003aa8:	00001097          	auipc	ra,0x1
    80003aac:	b40080e7          	jalr	-1216(ra) # 800045e8 <initlog>
}
    80003ab0:	70a2                	ld	ra,40(sp)
    80003ab2:	7402                	ld	s0,32(sp)
    80003ab4:	64e2                	ld	s1,24(sp)
    80003ab6:	6942                	ld	s2,16(sp)
    80003ab8:	69a2                	ld	s3,8(sp)
    80003aba:	6145                	addi	sp,sp,48
    80003abc:	8082                	ret
    panic("invalid file system");
    80003abe:	00005517          	auipc	a0,0x5
    80003ac2:	b2a50513          	addi	a0,a0,-1238 # 800085e8 <syscalls+0x148>
    80003ac6:	ffffd097          	auipc	ra,0xffffd
    80003aca:	a78080e7          	jalr	-1416(ra) # 8000053e <panic>

0000000080003ace <iinit>:
{
    80003ace:	7179                	addi	sp,sp,-48
    80003ad0:	f406                	sd	ra,40(sp)
    80003ad2:	f022                	sd	s0,32(sp)
    80003ad4:	ec26                	sd	s1,24(sp)
    80003ad6:	e84a                	sd	s2,16(sp)
    80003ad8:	e44e                	sd	s3,8(sp)
    80003ada:	1800                	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    80003adc:	00005597          	auipc	a1,0x5
    80003ae0:	b2458593          	addi	a1,a1,-1244 # 80008600 <syscalls+0x160>
    80003ae4:	0003c517          	auipc	a0,0x3c
    80003ae8:	9d450513          	addi	a0,a0,-1580 # 8003f4b8 <itable>
    80003aec:	ffffd097          	auipc	ra,0xffffd
    80003af0:	30e080e7          	jalr	782(ra) # 80000dfa <initlock>
  for(i = 0; i < NINODE; i++) {
    80003af4:	0003c497          	auipc	s1,0x3c
    80003af8:	9ec48493          	addi	s1,s1,-1556 # 8003f4e0 <itable+0x28>
    80003afc:	0003d997          	auipc	s3,0x3d
    80003b00:	47498993          	addi	s3,s3,1140 # 80040f70 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    80003b04:	00005917          	auipc	s2,0x5
    80003b08:	b0490913          	addi	s2,s2,-1276 # 80008608 <syscalls+0x168>
    80003b0c:	85ca                	mv	a1,s2
    80003b0e:	8526                	mv	a0,s1
    80003b10:	00001097          	auipc	ra,0x1
    80003b14:	e3a080e7          	jalr	-454(ra) # 8000494a <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    80003b18:	08848493          	addi	s1,s1,136
    80003b1c:	ff3498e3          	bne	s1,s3,80003b0c <iinit+0x3e>
}
    80003b20:	70a2                	ld	ra,40(sp)
    80003b22:	7402                	ld	s0,32(sp)
    80003b24:	64e2                	ld	s1,24(sp)
    80003b26:	6942                	ld	s2,16(sp)
    80003b28:	69a2                	ld	s3,8(sp)
    80003b2a:	6145                	addi	sp,sp,48
    80003b2c:	8082                	ret

0000000080003b2e <ialloc>:
{
    80003b2e:	715d                	addi	sp,sp,-80
    80003b30:	e486                	sd	ra,72(sp)
    80003b32:	e0a2                	sd	s0,64(sp)
    80003b34:	fc26                	sd	s1,56(sp)
    80003b36:	f84a                	sd	s2,48(sp)
    80003b38:	f44e                	sd	s3,40(sp)
    80003b3a:	f052                	sd	s4,32(sp)
    80003b3c:	ec56                	sd	s5,24(sp)
    80003b3e:	e85a                	sd	s6,16(sp)
    80003b40:	e45e                	sd	s7,8(sp)
    80003b42:	0880                	addi	s0,sp,80
  for(inum = 1; inum < sb.ninodes; inum++){
    80003b44:	0003c717          	auipc	a4,0x3c
    80003b48:	96072703          	lw	a4,-1696(a4) # 8003f4a4 <sb+0xc>
    80003b4c:	4785                	li	a5,1
    80003b4e:	04e7fa63          	bgeu	a5,a4,80003ba2 <ialloc+0x74>
    80003b52:	8aaa                	mv	s5,a0
    80003b54:	8bae                	mv	s7,a1
    80003b56:	4485                	li	s1,1
    bp = bread(dev, IBLOCK(inum, sb));
    80003b58:	0003ca17          	auipc	s4,0x3c
    80003b5c:	940a0a13          	addi	s4,s4,-1728 # 8003f498 <sb>
    80003b60:	00048b1b          	sext.w	s6,s1
    80003b64:	0044d793          	srli	a5,s1,0x4
    80003b68:	018a2583          	lw	a1,24(s4)
    80003b6c:	9dbd                	addw	a1,a1,a5
    80003b6e:	8556                	mv	a0,s5
    80003b70:	00000097          	auipc	ra,0x0
    80003b74:	940080e7          	jalr	-1728(ra) # 800034b0 <bread>
    80003b78:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    80003b7a:	05850993          	addi	s3,a0,88
    80003b7e:	00f4f793          	andi	a5,s1,15
    80003b82:	079a                	slli	a5,a5,0x6
    80003b84:	99be                	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    80003b86:	00099783          	lh	a5,0(s3)
    80003b8a:	c3a1                	beqz	a5,80003bca <ialloc+0x9c>
    brelse(bp);
    80003b8c:	00000097          	auipc	ra,0x0
    80003b90:	a54080e7          	jalr	-1452(ra) # 800035e0 <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    80003b94:	0485                	addi	s1,s1,1
    80003b96:	00ca2703          	lw	a4,12(s4)
    80003b9a:	0004879b          	sext.w	a5,s1
    80003b9e:	fce7e1e3          	bltu	a5,a4,80003b60 <ialloc+0x32>
  printf("ialloc: no inodes\n");
    80003ba2:	00005517          	auipc	a0,0x5
    80003ba6:	a6e50513          	addi	a0,a0,-1426 # 80008610 <syscalls+0x170>
    80003baa:	ffffd097          	auipc	ra,0xffffd
    80003bae:	9de080e7          	jalr	-1570(ra) # 80000588 <printf>
  return 0;
    80003bb2:	4501                	li	a0,0
}
    80003bb4:	60a6                	ld	ra,72(sp)
    80003bb6:	6406                	ld	s0,64(sp)
    80003bb8:	74e2                	ld	s1,56(sp)
    80003bba:	7942                	ld	s2,48(sp)
    80003bbc:	79a2                	ld	s3,40(sp)
    80003bbe:	7a02                	ld	s4,32(sp)
    80003bc0:	6ae2                	ld	s5,24(sp)
    80003bc2:	6b42                	ld	s6,16(sp)
    80003bc4:	6ba2                	ld	s7,8(sp)
    80003bc6:	6161                	addi	sp,sp,80
    80003bc8:	8082                	ret
      memset(dip, 0, sizeof(*dip));
    80003bca:	04000613          	li	a2,64
    80003bce:	4581                	li	a1,0
    80003bd0:	854e                	mv	a0,s3
    80003bd2:	ffffd097          	auipc	ra,0xffffd
    80003bd6:	3b4080e7          	jalr	948(ra) # 80000f86 <memset>
      dip->type = type;
    80003bda:	01799023          	sh	s7,0(s3)
      log_write(bp);   // mark it allocated on the disk
    80003bde:	854a                	mv	a0,s2
    80003be0:	00001097          	auipc	ra,0x1
    80003be4:	c84080e7          	jalr	-892(ra) # 80004864 <log_write>
      brelse(bp);
    80003be8:	854a                	mv	a0,s2
    80003bea:	00000097          	auipc	ra,0x0
    80003bee:	9f6080e7          	jalr	-1546(ra) # 800035e0 <brelse>
      return iget(dev, inum);
    80003bf2:	85da                	mv	a1,s6
    80003bf4:	8556                	mv	a0,s5
    80003bf6:	00000097          	auipc	ra,0x0
    80003bfa:	d9c080e7          	jalr	-612(ra) # 80003992 <iget>
    80003bfe:	bf5d                	j	80003bb4 <ialloc+0x86>

0000000080003c00 <iupdate>:
{
    80003c00:	1101                	addi	sp,sp,-32
    80003c02:	ec06                	sd	ra,24(sp)
    80003c04:	e822                	sd	s0,16(sp)
    80003c06:	e426                	sd	s1,8(sp)
    80003c08:	e04a                	sd	s2,0(sp)
    80003c0a:	1000                	addi	s0,sp,32
    80003c0c:	84aa                	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003c0e:	415c                	lw	a5,4(a0)
    80003c10:	0047d79b          	srliw	a5,a5,0x4
    80003c14:	0003c597          	auipc	a1,0x3c
    80003c18:	89c5a583          	lw	a1,-1892(a1) # 8003f4b0 <sb+0x18>
    80003c1c:	9dbd                	addw	a1,a1,a5
    80003c1e:	4108                	lw	a0,0(a0)
    80003c20:	00000097          	auipc	ra,0x0
    80003c24:	890080e7          	jalr	-1904(ra) # 800034b0 <bread>
    80003c28:	892a                	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003c2a:	05850793          	addi	a5,a0,88
    80003c2e:	40c8                	lw	a0,4(s1)
    80003c30:	893d                	andi	a0,a0,15
    80003c32:	051a                	slli	a0,a0,0x6
    80003c34:	953e                	add	a0,a0,a5
  dip->type = ip->type;
    80003c36:	04449703          	lh	a4,68(s1)
    80003c3a:	00e51023          	sh	a4,0(a0)
  dip->major = ip->major;
    80003c3e:	04649703          	lh	a4,70(s1)
    80003c42:	00e51123          	sh	a4,2(a0)
  dip->minor = ip->minor;
    80003c46:	04849703          	lh	a4,72(s1)
    80003c4a:	00e51223          	sh	a4,4(a0)
  dip->nlink = ip->nlink;
    80003c4e:	04a49703          	lh	a4,74(s1)
    80003c52:	00e51323          	sh	a4,6(a0)
  dip->size = ip->size;
    80003c56:	44f8                	lw	a4,76(s1)
    80003c58:	c518                	sw	a4,8(a0)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80003c5a:	03400613          	li	a2,52
    80003c5e:	05048593          	addi	a1,s1,80
    80003c62:	0531                	addi	a0,a0,12
    80003c64:	ffffd097          	auipc	ra,0xffffd
    80003c68:	37e080e7          	jalr	894(ra) # 80000fe2 <memmove>
  log_write(bp);
    80003c6c:	854a                	mv	a0,s2
    80003c6e:	00001097          	auipc	ra,0x1
    80003c72:	bf6080e7          	jalr	-1034(ra) # 80004864 <log_write>
  brelse(bp);
    80003c76:	854a                	mv	a0,s2
    80003c78:	00000097          	auipc	ra,0x0
    80003c7c:	968080e7          	jalr	-1688(ra) # 800035e0 <brelse>
}
    80003c80:	60e2                	ld	ra,24(sp)
    80003c82:	6442                	ld	s0,16(sp)
    80003c84:	64a2                	ld	s1,8(sp)
    80003c86:	6902                	ld	s2,0(sp)
    80003c88:	6105                	addi	sp,sp,32
    80003c8a:	8082                	ret

0000000080003c8c <idup>:
{
    80003c8c:	1101                	addi	sp,sp,-32
    80003c8e:	ec06                	sd	ra,24(sp)
    80003c90:	e822                	sd	s0,16(sp)
    80003c92:	e426                	sd	s1,8(sp)
    80003c94:	1000                	addi	s0,sp,32
    80003c96:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003c98:	0003c517          	auipc	a0,0x3c
    80003c9c:	82050513          	addi	a0,a0,-2016 # 8003f4b8 <itable>
    80003ca0:	ffffd097          	auipc	ra,0xffffd
    80003ca4:	1ea080e7          	jalr	490(ra) # 80000e8a <acquire>
  ip->ref++;
    80003ca8:	449c                	lw	a5,8(s1)
    80003caa:	2785                	addiw	a5,a5,1
    80003cac:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80003cae:	0003c517          	auipc	a0,0x3c
    80003cb2:	80a50513          	addi	a0,a0,-2038 # 8003f4b8 <itable>
    80003cb6:	ffffd097          	auipc	ra,0xffffd
    80003cba:	288080e7          	jalr	648(ra) # 80000f3e <release>
}
    80003cbe:	8526                	mv	a0,s1
    80003cc0:	60e2                	ld	ra,24(sp)
    80003cc2:	6442                	ld	s0,16(sp)
    80003cc4:	64a2                	ld	s1,8(sp)
    80003cc6:	6105                	addi	sp,sp,32
    80003cc8:	8082                	ret

0000000080003cca <ilock>:
{
    80003cca:	1101                	addi	sp,sp,-32
    80003ccc:	ec06                	sd	ra,24(sp)
    80003cce:	e822                	sd	s0,16(sp)
    80003cd0:	e426                	sd	s1,8(sp)
    80003cd2:	e04a                	sd	s2,0(sp)
    80003cd4:	1000                	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    80003cd6:	c115                	beqz	a0,80003cfa <ilock+0x30>
    80003cd8:	84aa                	mv	s1,a0
    80003cda:	451c                	lw	a5,8(a0)
    80003cdc:	00f05f63          	blez	a5,80003cfa <ilock+0x30>
  acquiresleep(&ip->lock);
    80003ce0:	0541                	addi	a0,a0,16
    80003ce2:	00001097          	auipc	ra,0x1
    80003ce6:	ca2080e7          	jalr	-862(ra) # 80004984 <acquiresleep>
  if(ip->valid == 0){
    80003cea:	40bc                	lw	a5,64(s1)
    80003cec:	cf99                	beqz	a5,80003d0a <ilock+0x40>
}
    80003cee:	60e2                	ld	ra,24(sp)
    80003cf0:	6442                	ld	s0,16(sp)
    80003cf2:	64a2                	ld	s1,8(sp)
    80003cf4:	6902                	ld	s2,0(sp)
    80003cf6:	6105                	addi	sp,sp,32
    80003cf8:	8082                	ret
    panic("ilock");
    80003cfa:	00005517          	auipc	a0,0x5
    80003cfe:	92e50513          	addi	a0,a0,-1746 # 80008628 <syscalls+0x188>
    80003d02:	ffffd097          	auipc	ra,0xffffd
    80003d06:	83c080e7          	jalr	-1988(ra) # 8000053e <panic>
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    80003d0a:	40dc                	lw	a5,4(s1)
    80003d0c:	0047d79b          	srliw	a5,a5,0x4
    80003d10:	0003b597          	auipc	a1,0x3b
    80003d14:	7a05a583          	lw	a1,1952(a1) # 8003f4b0 <sb+0x18>
    80003d18:	9dbd                	addw	a1,a1,a5
    80003d1a:	4088                	lw	a0,0(s1)
    80003d1c:	fffff097          	auipc	ra,0xfffff
    80003d20:	794080e7          	jalr	1940(ra) # 800034b0 <bread>
    80003d24:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    80003d26:	05850593          	addi	a1,a0,88
    80003d2a:	40dc                	lw	a5,4(s1)
    80003d2c:	8bbd                	andi	a5,a5,15
    80003d2e:	079a                	slli	a5,a5,0x6
    80003d30:	95be                	add	a1,a1,a5
    ip->type = dip->type;
    80003d32:	00059783          	lh	a5,0(a1)
    80003d36:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    80003d3a:	00259783          	lh	a5,2(a1)
    80003d3e:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    80003d42:	00459783          	lh	a5,4(a1)
    80003d46:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    80003d4a:	00659783          	lh	a5,6(a1)
    80003d4e:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    80003d52:	459c                	lw	a5,8(a1)
    80003d54:	c4fc                	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    80003d56:	03400613          	li	a2,52
    80003d5a:	05b1                	addi	a1,a1,12
    80003d5c:	05048513          	addi	a0,s1,80
    80003d60:	ffffd097          	auipc	ra,0xffffd
    80003d64:	282080e7          	jalr	642(ra) # 80000fe2 <memmove>
    brelse(bp);
    80003d68:	854a                	mv	a0,s2
    80003d6a:	00000097          	auipc	ra,0x0
    80003d6e:	876080e7          	jalr	-1930(ra) # 800035e0 <brelse>
    ip->valid = 1;
    80003d72:	4785                	li	a5,1
    80003d74:	c0bc                	sw	a5,64(s1)
    if(ip->type == 0)
    80003d76:	04449783          	lh	a5,68(s1)
    80003d7a:	fbb5                	bnez	a5,80003cee <ilock+0x24>
      panic("ilock: no type");
    80003d7c:	00005517          	auipc	a0,0x5
    80003d80:	8b450513          	addi	a0,a0,-1868 # 80008630 <syscalls+0x190>
    80003d84:	ffffc097          	auipc	ra,0xffffc
    80003d88:	7ba080e7          	jalr	1978(ra) # 8000053e <panic>

0000000080003d8c <iunlock>:
{
    80003d8c:	1101                	addi	sp,sp,-32
    80003d8e:	ec06                	sd	ra,24(sp)
    80003d90:	e822                	sd	s0,16(sp)
    80003d92:	e426                	sd	s1,8(sp)
    80003d94:	e04a                	sd	s2,0(sp)
    80003d96:	1000                	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    80003d98:	c905                	beqz	a0,80003dc8 <iunlock+0x3c>
    80003d9a:	84aa                	mv	s1,a0
    80003d9c:	01050913          	addi	s2,a0,16
    80003da0:	854a                	mv	a0,s2
    80003da2:	00001097          	auipc	ra,0x1
    80003da6:	c7c080e7          	jalr	-900(ra) # 80004a1e <holdingsleep>
    80003daa:	cd19                	beqz	a0,80003dc8 <iunlock+0x3c>
    80003dac:	449c                	lw	a5,8(s1)
    80003dae:	00f05d63          	blez	a5,80003dc8 <iunlock+0x3c>
  releasesleep(&ip->lock);
    80003db2:	854a                	mv	a0,s2
    80003db4:	00001097          	auipc	ra,0x1
    80003db8:	c26080e7          	jalr	-986(ra) # 800049da <releasesleep>
}
    80003dbc:	60e2                	ld	ra,24(sp)
    80003dbe:	6442                	ld	s0,16(sp)
    80003dc0:	64a2                	ld	s1,8(sp)
    80003dc2:	6902                	ld	s2,0(sp)
    80003dc4:	6105                	addi	sp,sp,32
    80003dc6:	8082                	ret
    panic("iunlock");
    80003dc8:	00005517          	auipc	a0,0x5
    80003dcc:	87850513          	addi	a0,a0,-1928 # 80008640 <syscalls+0x1a0>
    80003dd0:	ffffc097          	auipc	ra,0xffffc
    80003dd4:	76e080e7          	jalr	1902(ra) # 8000053e <panic>

0000000080003dd8 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    80003dd8:	7179                	addi	sp,sp,-48
    80003dda:	f406                	sd	ra,40(sp)
    80003ddc:	f022                	sd	s0,32(sp)
    80003dde:	ec26                	sd	s1,24(sp)
    80003de0:	e84a                	sd	s2,16(sp)
    80003de2:	e44e                	sd	s3,8(sp)
    80003de4:	e052                	sd	s4,0(sp)
    80003de6:	1800                	addi	s0,sp,48
    80003de8:	89aa                	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    80003dea:	05050493          	addi	s1,a0,80
    80003dee:	08050913          	addi	s2,a0,128
    80003df2:	a021                	j	80003dfa <itrunc+0x22>
    80003df4:	0491                	addi	s1,s1,4
    80003df6:	01248d63          	beq	s1,s2,80003e10 <itrunc+0x38>
    if(ip->addrs[i]){
    80003dfa:	408c                	lw	a1,0(s1)
    80003dfc:	dde5                	beqz	a1,80003df4 <itrunc+0x1c>
      bfree(ip->dev, ip->addrs[i]);
    80003dfe:	0009a503          	lw	a0,0(s3)
    80003e02:	00000097          	auipc	ra,0x0
    80003e06:	8f4080e7          	jalr	-1804(ra) # 800036f6 <bfree>
      ip->addrs[i] = 0;
    80003e0a:	0004a023          	sw	zero,0(s1)
    80003e0e:	b7dd                	j	80003df4 <itrunc+0x1c>
    }
  }

  if(ip->addrs[NDIRECT]){
    80003e10:	0809a583          	lw	a1,128(s3)
    80003e14:	e185                	bnez	a1,80003e34 <itrunc+0x5c>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    80003e16:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    80003e1a:	854e                	mv	a0,s3
    80003e1c:	00000097          	auipc	ra,0x0
    80003e20:	de4080e7          	jalr	-540(ra) # 80003c00 <iupdate>
}
    80003e24:	70a2                	ld	ra,40(sp)
    80003e26:	7402                	ld	s0,32(sp)
    80003e28:	64e2                	ld	s1,24(sp)
    80003e2a:	6942                	ld	s2,16(sp)
    80003e2c:	69a2                	ld	s3,8(sp)
    80003e2e:	6a02                	ld	s4,0(sp)
    80003e30:	6145                	addi	sp,sp,48
    80003e32:	8082                	ret
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    80003e34:	0009a503          	lw	a0,0(s3)
    80003e38:	fffff097          	auipc	ra,0xfffff
    80003e3c:	678080e7          	jalr	1656(ra) # 800034b0 <bread>
    80003e40:	8a2a                	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    80003e42:	05850493          	addi	s1,a0,88
    80003e46:	45850913          	addi	s2,a0,1112
    80003e4a:	a021                	j	80003e52 <itrunc+0x7a>
    80003e4c:	0491                	addi	s1,s1,4
    80003e4e:	01248b63          	beq	s1,s2,80003e64 <itrunc+0x8c>
      if(a[j])
    80003e52:	408c                	lw	a1,0(s1)
    80003e54:	dde5                	beqz	a1,80003e4c <itrunc+0x74>
        bfree(ip->dev, a[j]);
    80003e56:	0009a503          	lw	a0,0(s3)
    80003e5a:	00000097          	auipc	ra,0x0
    80003e5e:	89c080e7          	jalr	-1892(ra) # 800036f6 <bfree>
    80003e62:	b7ed                	j	80003e4c <itrunc+0x74>
    brelse(bp);
    80003e64:	8552                	mv	a0,s4
    80003e66:	fffff097          	auipc	ra,0xfffff
    80003e6a:	77a080e7          	jalr	1914(ra) # 800035e0 <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    80003e6e:	0809a583          	lw	a1,128(s3)
    80003e72:	0009a503          	lw	a0,0(s3)
    80003e76:	00000097          	auipc	ra,0x0
    80003e7a:	880080e7          	jalr	-1920(ra) # 800036f6 <bfree>
    ip->addrs[NDIRECT] = 0;
    80003e7e:	0809a023          	sw	zero,128(s3)
    80003e82:	bf51                	j	80003e16 <itrunc+0x3e>

0000000080003e84 <iput>:
{
    80003e84:	1101                	addi	sp,sp,-32
    80003e86:	ec06                	sd	ra,24(sp)
    80003e88:	e822                	sd	s0,16(sp)
    80003e8a:	e426                	sd	s1,8(sp)
    80003e8c:	e04a                	sd	s2,0(sp)
    80003e8e:	1000                	addi	s0,sp,32
    80003e90:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    80003e92:	0003b517          	auipc	a0,0x3b
    80003e96:	62650513          	addi	a0,a0,1574 # 8003f4b8 <itable>
    80003e9a:	ffffd097          	auipc	ra,0xffffd
    80003e9e:	ff0080e7          	jalr	-16(ra) # 80000e8a <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003ea2:	4498                	lw	a4,8(s1)
    80003ea4:	4785                	li	a5,1
    80003ea6:	02f70363          	beq	a4,a5,80003ecc <iput+0x48>
  ip->ref--;
    80003eaa:	449c                	lw	a5,8(s1)
    80003eac:	37fd                	addiw	a5,a5,-1
    80003eae:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    80003eb0:	0003b517          	auipc	a0,0x3b
    80003eb4:	60850513          	addi	a0,a0,1544 # 8003f4b8 <itable>
    80003eb8:	ffffd097          	auipc	ra,0xffffd
    80003ebc:	086080e7          	jalr	134(ra) # 80000f3e <release>
}
    80003ec0:	60e2                	ld	ra,24(sp)
    80003ec2:	6442                	ld	s0,16(sp)
    80003ec4:	64a2                	ld	s1,8(sp)
    80003ec6:	6902                	ld	s2,0(sp)
    80003ec8:	6105                	addi	sp,sp,32
    80003eca:	8082                	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003ecc:	40bc                	lw	a5,64(s1)
    80003ece:	dff1                	beqz	a5,80003eaa <iput+0x26>
    80003ed0:	04a49783          	lh	a5,74(s1)
    80003ed4:	fbf9                	bnez	a5,80003eaa <iput+0x26>
    acquiresleep(&ip->lock);
    80003ed6:	01048913          	addi	s2,s1,16
    80003eda:	854a                	mv	a0,s2
    80003edc:	00001097          	auipc	ra,0x1
    80003ee0:	aa8080e7          	jalr	-1368(ra) # 80004984 <acquiresleep>
    release(&itable.lock);
    80003ee4:	0003b517          	auipc	a0,0x3b
    80003ee8:	5d450513          	addi	a0,a0,1492 # 8003f4b8 <itable>
    80003eec:	ffffd097          	auipc	ra,0xffffd
    80003ef0:	052080e7          	jalr	82(ra) # 80000f3e <release>
    itrunc(ip);
    80003ef4:	8526                	mv	a0,s1
    80003ef6:	00000097          	auipc	ra,0x0
    80003efa:	ee2080e7          	jalr	-286(ra) # 80003dd8 <itrunc>
    ip->type = 0;
    80003efe:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    80003f02:	8526                	mv	a0,s1
    80003f04:	00000097          	auipc	ra,0x0
    80003f08:	cfc080e7          	jalr	-772(ra) # 80003c00 <iupdate>
    ip->valid = 0;
    80003f0c:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    80003f10:	854a                	mv	a0,s2
    80003f12:	00001097          	auipc	ra,0x1
    80003f16:	ac8080e7          	jalr	-1336(ra) # 800049da <releasesleep>
    acquire(&itable.lock);
    80003f1a:	0003b517          	auipc	a0,0x3b
    80003f1e:	59e50513          	addi	a0,a0,1438 # 8003f4b8 <itable>
    80003f22:	ffffd097          	auipc	ra,0xffffd
    80003f26:	f68080e7          	jalr	-152(ra) # 80000e8a <acquire>
    80003f2a:	b741                	j	80003eaa <iput+0x26>

0000000080003f2c <iunlockput>:
{
    80003f2c:	1101                	addi	sp,sp,-32
    80003f2e:	ec06                	sd	ra,24(sp)
    80003f30:	e822                	sd	s0,16(sp)
    80003f32:	e426                	sd	s1,8(sp)
    80003f34:	1000                	addi	s0,sp,32
    80003f36:	84aa                	mv	s1,a0
  iunlock(ip);
    80003f38:	00000097          	auipc	ra,0x0
    80003f3c:	e54080e7          	jalr	-428(ra) # 80003d8c <iunlock>
  iput(ip);
    80003f40:	8526                	mv	a0,s1
    80003f42:	00000097          	auipc	ra,0x0
    80003f46:	f42080e7          	jalr	-190(ra) # 80003e84 <iput>
}
    80003f4a:	60e2                	ld	ra,24(sp)
    80003f4c:	6442                	ld	s0,16(sp)
    80003f4e:	64a2                	ld	s1,8(sp)
    80003f50:	6105                	addi	sp,sp,32
    80003f52:	8082                	ret

0000000080003f54 <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    80003f54:	1141                	addi	sp,sp,-16
    80003f56:	e422                	sd	s0,8(sp)
    80003f58:	0800                	addi	s0,sp,16
  st->dev = ip->dev;
    80003f5a:	411c                	lw	a5,0(a0)
    80003f5c:	c19c                	sw	a5,0(a1)
  st->ino = ip->inum;
    80003f5e:	415c                	lw	a5,4(a0)
    80003f60:	c1dc                	sw	a5,4(a1)
  st->type = ip->type;
    80003f62:	04451783          	lh	a5,68(a0)
    80003f66:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    80003f6a:	04a51783          	lh	a5,74(a0)
    80003f6e:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    80003f72:	04c56783          	lwu	a5,76(a0)
    80003f76:	e99c                	sd	a5,16(a1)
}
    80003f78:	6422                	ld	s0,8(sp)
    80003f7a:	0141                	addi	sp,sp,16
    80003f7c:	8082                	ret

0000000080003f7e <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80003f7e:	457c                	lw	a5,76(a0)
    80003f80:	0ed7e963          	bltu	a5,a3,80004072 <readi+0xf4>
{
    80003f84:	7159                	addi	sp,sp,-112
    80003f86:	f486                	sd	ra,104(sp)
    80003f88:	f0a2                	sd	s0,96(sp)
    80003f8a:	eca6                	sd	s1,88(sp)
    80003f8c:	e8ca                	sd	s2,80(sp)
    80003f8e:	e4ce                	sd	s3,72(sp)
    80003f90:	e0d2                	sd	s4,64(sp)
    80003f92:	fc56                	sd	s5,56(sp)
    80003f94:	f85a                	sd	s6,48(sp)
    80003f96:	f45e                	sd	s7,40(sp)
    80003f98:	f062                	sd	s8,32(sp)
    80003f9a:	ec66                	sd	s9,24(sp)
    80003f9c:	e86a                	sd	s10,16(sp)
    80003f9e:	e46e                	sd	s11,8(sp)
    80003fa0:	1880                	addi	s0,sp,112
    80003fa2:	8b2a                	mv	s6,a0
    80003fa4:	8bae                	mv	s7,a1
    80003fa6:	8a32                	mv	s4,a2
    80003fa8:	84b6                	mv	s1,a3
    80003faa:	8aba                	mv	s5,a4
  if(off > ip->size || off + n < off)
    80003fac:	9f35                	addw	a4,a4,a3
    return 0;
    80003fae:	4501                	li	a0,0
  if(off > ip->size || off + n < off)
    80003fb0:	0ad76063          	bltu	a4,a3,80004050 <readi+0xd2>
  if(off + n > ip->size)
    80003fb4:	00e7f463          	bgeu	a5,a4,80003fbc <readi+0x3e>
    n = ip->size - off;
    80003fb8:	40d78abb          	subw	s5,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003fbc:	0a0a8963          	beqz	s5,8000406e <readi+0xf0>
    80003fc0:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    80003fc2:	40000c93          	li	s9,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    80003fc6:	5c7d                	li	s8,-1
    80003fc8:	a82d                	j	80004002 <readi+0x84>
    80003fca:	020d1d93          	slli	s11,s10,0x20
    80003fce:	020ddd93          	srli	s11,s11,0x20
    80003fd2:	05890793          	addi	a5,s2,88
    80003fd6:	86ee                	mv	a3,s11
    80003fd8:	963e                	add	a2,a2,a5
    80003fda:	85d2                	mv	a1,s4
    80003fdc:	855e                	mv	a0,s7
    80003fde:	fffff097          	auipc	ra,0xfffff
    80003fe2:	870080e7          	jalr	-1936(ra) # 8000284e <either_copyout>
    80003fe6:	05850d63          	beq	a0,s8,80004040 <readi+0xc2>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    80003fea:	854a                	mv	a0,s2
    80003fec:	fffff097          	auipc	ra,0xfffff
    80003ff0:	5f4080e7          	jalr	1524(ra) # 800035e0 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003ff4:	013d09bb          	addw	s3,s10,s3
    80003ff8:	009d04bb          	addw	s1,s10,s1
    80003ffc:	9a6e                	add	s4,s4,s11
    80003ffe:	0559f763          	bgeu	s3,s5,8000404c <readi+0xce>
    uint addr = bmap(ip, off/BSIZE);
    80004002:	00a4d59b          	srliw	a1,s1,0xa
    80004006:	855a                	mv	a0,s6
    80004008:	00000097          	auipc	ra,0x0
    8000400c:	8a2080e7          	jalr	-1886(ra) # 800038aa <bmap>
    80004010:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    80004014:	cd85                	beqz	a1,8000404c <readi+0xce>
    bp = bread(ip->dev, addr);
    80004016:	000b2503          	lw	a0,0(s6)
    8000401a:	fffff097          	auipc	ra,0xfffff
    8000401e:	496080e7          	jalr	1174(ra) # 800034b0 <bread>
    80004022:	892a                	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    80004024:	3ff4f613          	andi	a2,s1,1023
    80004028:	40cc87bb          	subw	a5,s9,a2
    8000402c:	413a873b          	subw	a4,s5,s3
    80004030:	8d3e                	mv	s10,a5
    80004032:	2781                	sext.w	a5,a5
    80004034:	0007069b          	sext.w	a3,a4
    80004038:	f8f6f9e3          	bgeu	a3,a5,80003fca <readi+0x4c>
    8000403c:	8d3a                	mv	s10,a4
    8000403e:	b771                	j	80003fca <readi+0x4c>
      brelse(bp);
    80004040:	854a                	mv	a0,s2
    80004042:	fffff097          	auipc	ra,0xfffff
    80004046:	59e080e7          	jalr	1438(ra) # 800035e0 <brelse>
      tot = -1;
    8000404a:	59fd                	li	s3,-1
  }
  return tot;
    8000404c:	0009851b          	sext.w	a0,s3
}
    80004050:	70a6                	ld	ra,104(sp)
    80004052:	7406                	ld	s0,96(sp)
    80004054:	64e6                	ld	s1,88(sp)
    80004056:	6946                	ld	s2,80(sp)
    80004058:	69a6                	ld	s3,72(sp)
    8000405a:	6a06                	ld	s4,64(sp)
    8000405c:	7ae2                	ld	s5,56(sp)
    8000405e:	7b42                	ld	s6,48(sp)
    80004060:	7ba2                	ld	s7,40(sp)
    80004062:	7c02                	ld	s8,32(sp)
    80004064:	6ce2                	ld	s9,24(sp)
    80004066:	6d42                	ld	s10,16(sp)
    80004068:	6da2                	ld	s11,8(sp)
    8000406a:	6165                	addi	sp,sp,112
    8000406c:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    8000406e:	89d6                	mv	s3,s5
    80004070:	bff1                	j	8000404c <readi+0xce>
    return 0;
    80004072:	4501                	li	a0,0
}
    80004074:	8082                	ret

0000000080004076 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    80004076:	457c                	lw	a5,76(a0)
    80004078:	10d7e863          	bltu	a5,a3,80004188 <writei+0x112>
{
    8000407c:	7159                	addi	sp,sp,-112
    8000407e:	f486                	sd	ra,104(sp)
    80004080:	f0a2                	sd	s0,96(sp)
    80004082:	eca6                	sd	s1,88(sp)
    80004084:	e8ca                	sd	s2,80(sp)
    80004086:	e4ce                	sd	s3,72(sp)
    80004088:	e0d2                	sd	s4,64(sp)
    8000408a:	fc56                	sd	s5,56(sp)
    8000408c:	f85a                	sd	s6,48(sp)
    8000408e:	f45e                	sd	s7,40(sp)
    80004090:	f062                	sd	s8,32(sp)
    80004092:	ec66                	sd	s9,24(sp)
    80004094:	e86a                	sd	s10,16(sp)
    80004096:	e46e                	sd	s11,8(sp)
    80004098:	1880                	addi	s0,sp,112
    8000409a:	8aaa                	mv	s5,a0
    8000409c:	8bae                	mv	s7,a1
    8000409e:	8a32                	mv	s4,a2
    800040a0:	8936                	mv	s2,a3
    800040a2:	8b3a                	mv	s6,a4
  if(off > ip->size || off + n < off)
    800040a4:	00e687bb          	addw	a5,a3,a4
    800040a8:	0ed7e263          	bltu	a5,a3,8000418c <writei+0x116>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    800040ac:	00043737          	lui	a4,0x43
    800040b0:	0ef76063          	bltu	a4,a5,80004190 <writei+0x11a>
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    800040b4:	0c0b0863          	beqz	s6,80004184 <writei+0x10e>
    800040b8:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    800040ba:	40000c93          	li	s9,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    800040be:	5c7d                	li	s8,-1
    800040c0:	a091                	j	80004104 <writei+0x8e>
    800040c2:	020d1d93          	slli	s11,s10,0x20
    800040c6:	020ddd93          	srli	s11,s11,0x20
    800040ca:	05848793          	addi	a5,s1,88
    800040ce:	86ee                	mv	a3,s11
    800040d0:	8652                	mv	a2,s4
    800040d2:	85de                	mv	a1,s7
    800040d4:	953e                	add	a0,a0,a5
    800040d6:	ffffe097          	auipc	ra,0xffffe
    800040da:	7ce080e7          	jalr	1998(ra) # 800028a4 <either_copyin>
    800040de:	07850263          	beq	a0,s8,80004142 <writei+0xcc>
      brelse(bp);
      break;
    }
    log_write(bp);
    800040e2:	8526                	mv	a0,s1
    800040e4:	00000097          	auipc	ra,0x0
    800040e8:	780080e7          	jalr	1920(ra) # 80004864 <log_write>
    brelse(bp);
    800040ec:	8526                	mv	a0,s1
    800040ee:	fffff097          	auipc	ra,0xfffff
    800040f2:	4f2080e7          	jalr	1266(ra) # 800035e0 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    800040f6:	013d09bb          	addw	s3,s10,s3
    800040fa:	012d093b          	addw	s2,s10,s2
    800040fe:	9a6e                	add	s4,s4,s11
    80004100:	0569f663          	bgeu	s3,s6,8000414c <writei+0xd6>
    uint addr = bmap(ip, off/BSIZE);
    80004104:	00a9559b          	srliw	a1,s2,0xa
    80004108:	8556                	mv	a0,s5
    8000410a:	fffff097          	auipc	ra,0xfffff
    8000410e:	7a0080e7          	jalr	1952(ra) # 800038aa <bmap>
    80004112:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    80004116:	c99d                	beqz	a1,8000414c <writei+0xd6>
    bp = bread(ip->dev, addr);
    80004118:	000aa503          	lw	a0,0(s5)
    8000411c:	fffff097          	auipc	ra,0xfffff
    80004120:	394080e7          	jalr	916(ra) # 800034b0 <bread>
    80004124:	84aa                	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    80004126:	3ff97513          	andi	a0,s2,1023
    8000412a:	40ac87bb          	subw	a5,s9,a0
    8000412e:	413b073b          	subw	a4,s6,s3
    80004132:	8d3e                	mv	s10,a5
    80004134:	2781                	sext.w	a5,a5
    80004136:	0007069b          	sext.w	a3,a4
    8000413a:	f8f6f4e3          	bgeu	a3,a5,800040c2 <writei+0x4c>
    8000413e:	8d3a                	mv	s10,a4
    80004140:	b749                	j	800040c2 <writei+0x4c>
      brelse(bp);
    80004142:	8526                	mv	a0,s1
    80004144:	fffff097          	auipc	ra,0xfffff
    80004148:	49c080e7          	jalr	1180(ra) # 800035e0 <brelse>
  }

  if(off > ip->size)
    8000414c:	04caa783          	lw	a5,76(s5)
    80004150:	0127f463          	bgeu	a5,s2,80004158 <writei+0xe2>
    ip->size = off;
    80004154:	052aa623          	sw	s2,76(s5)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    80004158:	8556                	mv	a0,s5
    8000415a:	00000097          	auipc	ra,0x0
    8000415e:	aa6080e7          	jalr	-1370(ra) # 80003c00 <iupdate>

  return tot;
    80004162:	0009851b          	sext.w	a0,s3
}
    80004166:	70a6                	ld	ra,104(sp)
    80004168:	7406                	ld	s0,96(sp)
    8000416a:	64e6                	ld	s1,88(sp)
    8000416c:	6946                	ld	s2,80(sp)
    8000416e:	69a6                	ld	s3,72(sp)
    80004170:	6a06                	ld	s4,64(sp)
    80004172:	7ae2                	ld	s5,56(sp)
    80004174:	7b42                	ld	s6,48(sp)
    80004176:	7ba2                	ld	s7,40(sp)
    80004178:	7c02                	ld	s8,32(sp)
    8000417a:	6ce2                	ld	s9,24(sp)
    8000417c:	6d42                	ld	s10,16(sp)
    8000417e:	6da2                	ld	s11,8(sp)
    80004180:	6165                	addi	sp,sp,112
    80004182:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80004184:	89da                	mv	s3,s6
    80004186:	bfc9                	j	80004158 <writei+0xe2>
    return -1;
    80004188:	557d                	li	a0,-1
}
    8000418a:	8082                	ret
    return -1;
    8000418c:	557d                	li	a0,-1
    8000418e:	bfe1                	j	80004166 <writei+0xf0>
    return -1;
    80004190:	557d                	li	a0,-1
    80004192:	bfd1                	j	80004166 <writei+0xf0>

0000000080004194 <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80004194:	1141                	addi	sp,sp,-16
    80004196:	e406                	sd	ra,8(sp)
    80004198:	e022                	sd	s0,0(sp)
    8000419a:	0800                	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    8000419c:	4639                	li	a2,14
    8000419e:	ffffd097          	auipc	ra,0xffffd
    800041a2:	eb8080e7          	jalr	-328(ra) # 80001056 <strncmp>
}
    800041a6:	60a2                	ld	ra,8(sp)
    800041a8:	6402                	ld	s0,0(sp)
    800041aa:	0141                	addi	sp,sp,16
    800041ac:	8082                	ret

00000000800041ae <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    800041ae:	7139                	addi	sp,sp,-64
    800041b0:	fc06                	sd	ra,56(sp)
    800041b2:	f822                	sd	s0,48(sp)
    800041b4:	f426                	sd	s1,40(sp)
    800041b6:	f04a                	sd	s2,32(sp)
    800041b8:	ec4e                	sd	s3,24(sp)
    800041ba:	e852                	sd	s4,16(sp)
    800041bc:	0080                	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    800041be:	04451703          	lh	a4,68(a0)
    800041c2:	4785                	li	a5,1
    800041c4:	00f71a63          	bne	a4,a5,800041d8 <dirlookup+0x2a>
    800041c8:	892a                	mv	s2,a0
    800041ca:	89ae                	mv	s3,a1
    800041cc:	8a32                	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    800041ce:	457c                	lw	a5,76(a0)
    800041d0:	4481                	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    800041d2:	4501                	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    800041d4:	e79d                	bnez	a5,80004202 <dirlookup+0x54>
    800041d6:	a8a5                	j	8000424e <dirlookup+0xa0>
    panic("dirlookup not DIR");
    800041d8:	00004517          	auipc	a0,0x4
    800041dc:	47050513          	addi	a0,a0,1136 # 80008648 <syscalls+0x1a8>
    800041e0:	ffffc097          	auipc	ra,0xffffc
    800041e4:	35e080e7          	jalr	862(ra) # 8000053e <panic>
      panic("dirlookup read");
    800041e8:	00004517          	auipc	a0,0x4
    800041ec:	47850513          	addi	a0,a0,1144 # 80008660 <syscalls+0x1c0>
    800041f0:	ffffc097          	auipc	ra,0xffffc
    800041f4:	34e080e7          	jalr	846(ra) # 8000053e <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800041f8:	24c1                	addiw	s1,s1,16
    800041fa:	04c92783          	lw	a5,76(s2)
    800041fe:	04f4f763          	bgeu	s1,a5,8000424c <dirlookup+0x9e>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80004202:	4741                	li	a4,16
    80004204:	86a6                	mv	a3,s1
    80004206:	fc040613          	addi	a2,s0,-64
    8000420a:	4581                	li	a1,0
    8000420c:	854a                	mv	a0,s2
    8000420e:	00000097          	auipc	ra,0x0
    80004212:	d70080e7          	jalr	-656(ra) # 80003f7e <readi>
    80004216:	47c1                	li	a5,16
    80004218:	fcf518e3          	bne	a0,a5,800041e8 <dirlookup+0x3a>
    if(de.inum == 0)
    8000421c:	fc045783          	lhu	a5,-64(s0)
    80004220:	dfe1                	beqz	a5,800041f8 <dirlookup+0x4a>
    if(namecmp(name, de.name) == 0){
    80004222:	fc240593          	addi	a1,s0,-62
    80004226:	854e                	mv	a0,s3
    80004228:	00000097          	auipc	ra,0x0
    8000422c:	f6c080e7          	jalr	-148(ra) # 80004194 <namecmp>
    80004230:	f561                	bnez	a0,800041f8 <dirlookup+0x4a>
      if(poff)
    80004232:	000a0463          	beqz	s4,8000423a <dirlookup+0x8c>
        *poff = off;
    80004236:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    8000423a:	fc045583          	lhu	a1,-64(s0)
    8000423e:	00092503          	lw	a0,0(s2)
    80004242:	fffff097          	auipc	ra,0xfffff
    80004246:	750080e7          	jalr	1872(ra) # 80003992 <iget>
    8000424a:	a011                	j	8000424e <dirlookup+0xa0>
  return 0;
    8000424c:	4501                	li	a0,0
}
    8000424e:	70e2                	ld	ra,56(sp)
    80004250:	7442                	ld	s0,48(sp)
    80004252:	74a2                	ld	s1,40(sp)
    80004254:	7902                	ld	s2,32(sp)
    80004256:	69e2                	ld	s3,24(sp)
    80004258:	6a42                	ld	s4,16(sp)
    8000425a:	6121                	addi	sp,sp,64
    8000425c:	8082                	ret

000000008000425e <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    8000425e:	711d                	addi	sp,sp,-96
    80004260:	ec86                	sd	ra,88(sp)
    80004262:	e8a2                	sd	s0,80(sp)
    80004264:	e4a6                	sd	s1,72(sp)
    80004266:	e0ca                	sd	s2,64(sp)
    80004268:	fc4e                	sd	s3,56(sp)
    8000426a:	f852                	sd	s4,48(sp)
    8000426c:	f456                	sd	s5,40(sp)
    8000426e:	f05a                	sd	s6,32(sp)
    80004270:	ec5e                	sd	s7,24(sp)
    80004272:	e862                	sd	s8,16(sp)
    80004274:	e466                	sd	s9,8(sp)
    80004276:	1080                	addi	s0,sp,96
    80004278:	84aa                	mv	s1,a0
    8000427a:	8aae                	mv	s5,a1
    8000427c:	8a32                	mv	s4,a2
  struct inode *ip, *next;

  if(*path == '/')
    8000427e:	00054703          	lbu	a4,0(a0)
    80004282:	02f00793          	li	a5,47
    80004286:	02f70363          	beq	a4,a5,800042ac <namex+0x4e>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    8000428a:	ffffe097          	auipc	ra,0xffffe
    8000428e:	af4080e7          	jalr	-1292(ra) # 80001d7e <myproc>
    80004292:	15053503          	ld	a0,336(a0)
    80004296:	00000097          	auipc	ra,0x0
    8000429a:	9f6080e7          	jalr	-1546(ra) # 80003c8c <idup>
    8000429e:	89aa                	mv	s3,a0
  while(*path == '/')
    800042a0:	02f00913          	li	s2,47
  len = path - s;
    800042a4:	4b01                	li	s6,0
  if(len >= DIRSIZ)
    800042a6:	4c35                	li	s8,13

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    800042a8:	4b85                	li	s7,1
    800042aa:	a865                	j	80004362 <namex+0x104>
    ip = iget(ROOTDEV, ROOTINO);
    800042ac:	4585                	li	a1,1
    800042ae:	4505                	li	a0,1
    800042b0:	fffff097          	auipc	ra,0xfffff
    800042b4:	6e2080e7          	jalr	1762(ra) # 80003992 <iget>
    800042b8:	89aa                	mv	s3,a0
    800042ba:	b7dd                	j	800042a0 <namex+0x42>
      iunlockput(ip);
    800042bc:	854e                	mv	a0,s3
    800042be:	00000097          	auipc	ra,0x0
    800042c2:	c6e080e7          	jalr	-914(ra) # 80003f2c <iunlockput>
      return 0;
    800042c6:	4981                	li	s3,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    800042c8:	854e                	mv	a0,s3
    800042ca:	60e6                	ld	ra,88(sp)
    800042cc:	6446                	ld	s0,80(sp)
    800042ce:	64a6                	ld	s1,72(sp)
    800042d0:	6906                	ld	s2,64(sp)
    800042d2:	79e2                	ld	s3,56(sp)
    800042d4:	7a42                	ld	s4,48(sp)
    800042d6:	7aa2                	ld	s5,40(sp)
    800042d8:	7b02                	ld	s6,32(sp)
    800042da:	6be2                	ld	s7,24(sp)
    800042dc:	6c42                	ld	s8,16(sp)
    800042de:	6ca2                	ld	s9,8(sp)
    800042e0:	6125                	addi	sp,sp,96
    800042e2:	8082                	ret
      iunlock(ip);
    800042e4:	854e                	mv	a0,s3
    800042e6:	00000097          	auipc	ra,0x0
    800042ea:	aa6080e7          	jalr	-1370(ra) # 80003d8c <iunlock>
      return ip;
    800042ee:	bfe9                	j	800042c8 <namex+0x6a>
      iunlockput(ip);
    800042f0:	854e                	mv	a0,s3
    800042f2:	00000097          	auipc	ra,0x0
    800042f6:	c3a080e7          	jalr	-966(ra) # 80003f2c <iunlockput>
      return 0;
    800042fa:	89e6                	mv	s3,s9
    800042fc:	b7f1                	j	800042c8 <namex+0x6a>
  len = path - s;
    800042fe:	40b48633          	sub	a2,s1,a1
    80004302:	00060c9b          	sext.w	s9,a2
  if(len >= DIRSIZ)
    80004306:	099c5463          	bge	s8,s9,8000438e <namex+0x130>
    memmove(name, s, DIRSIZ);
    8000430a:	4639                	li	a2,14
    8000430c:	8552                	mv	a0,s4
    8000430e:	ffffd097          	auipc	ra,0xffffd
    80004312:	cd4080e7          	jalr	-812(ra) # 80000fe2 <memmove>
  while(*path == '/')
    80004316:	0004c783          	lbu	a5,0(s1)
    8000431a:	01279763          	bne	a5,s2,80004328 <namex+0xca>
    path++;
    8000431e:	0485                	addi	s1,s1,1
  while(*path == '/')
    80004320:	0004c783          	lbu	a5,0(s1)
    80004324:	ff278de3          	beq	a5,s2,8000431e <namex+0xc0>
    ilock(ip);
    80004328:	854e                	mv	a0,s3
    8000432a:	00000097          	auipc	ra,0x0
    8000432e:	9a0080e7          	jalr	-1632(ra) # 80003cca <ilock>
    if(ip->type != T_DIR){
    80004332:	04499783          	lh	a5,68(s3)
    80004336:	f97793e3          	bne	a5,s7,800042bc <namex+0x5e>
    if(nameiparent && *path == '\0'){
    8000433a:	000a8563          	beqz	s5,80004344 <namex+0xe6>
    8000433e:	0004c783          	lbu	a5,0(s1)
    80004342:	d3cd                	beqz	a5,800042e4 <namex+0x86>
    if((next = dirlookup(ip, name, 0)) == 0){
    80004344:	865a                	mv	a2,s6
    80004346:	85d2                	mv	a1,s4
    80004348:	854e                	mv	a0,s3
    8000434a:	00000097          	auipc	ra,0x0
    8000434e:	e64080e7          	jalr	-412(ra) # 800041ae <dirlookup>
    80004352:	8caa                	mv	s9,a0
    80004354:	dd51                	beqz	a0,800042f0 <namex+0x92>
    iunlockput(ip);
    80004356:	854e                	mv	a0,s3
    80004358:	00000097          	auipc	ra,0x0
    8000435c:	bd4080e7          	jalr	-1068(ra) # 80003f2c <iunlockput>
    ip = next;
    80004360:	89e6                	mv	s3,s9
  while(*path == '/')
    80004362:	0004c783          	lbu	a5,0(s1)
    80004366:	05279763          	bne	a5,s2,800043b4 <namex+0x156>
    path++;
    8000436a:	0485                	addi	s1,s1,1
  while(*path == '/')
    8000436c:	0004c783          	lbu	a5,0(s1)
    80004370:	ff278de3          	beq	a5,s2,8000436a <namex+0x10c>
  if(*path == 0)
    80004374:	c79d                	beqz	a5,800043a2 <namex+0x144>
    path++;
    80004376:	85a6                	mv	a1,s1
  len = path - s;
    80004378:	8cda                	mv	s9,s6
    8000437a:	865a                	mv	a2,s6
  while(*path != '/' && *path != 0)
    8000437c:	01278963          	beq	a5,s2,8000438e <namex+0x130>
    80004380:	dfbd                	beqz	a5,800042fe <namex+0xa0>
    path++;
    80004382:	0485                	addi	s1,s1,1
  while(*path != '/' && *path != 0)
    80004384:	0004c783          	lbu	a5,0(s1)
    80004388:	ff279ce3          	bne	a5,s2,80004380 <namex+0x122>
    8000438c:	bf8d                	j	800042fe <namex+0xa0>
    memmove(name, s, len);
    8000438e:	2601                	sext.w	a2,a2
    80004390:	8552                	mv	a0,s4
    80004392:	ffffd097          	auipc	ra,0xffffd
    80004396:	c50080e7          	jalr	-944(ra) # 80000fe2 <memmove>
    name[len] = 0;
    8000439a:	9cd2                	add	s9,s9,s4
    8000439c:	000c8023          	sb	zero,0(s9) # 2000 <_entry-0x7fffe000>
    800043a0:	bf9d                	j	80004316 <namex+0xb8>
  if(nameiparent){
    800043a2:	f20a83e3          	beqz	s5,800042c8 <namex+0x6a>
    iput(ip);
    800043a6:	854e                	mv	a0,s3
    800043a8:	00000097          	auipc	ra,0x0
    800043ac:	adc080e7          	jalr	-1316(ra) # 80003e84 <iput>
    return 0;
    800043b0:	4981                	li	s3,0
    800043b2:	bf19                	j	800042c8 <namex+0x6a>
  if(*path == 0)
    800043b4:	d7fd                	beqz	a5,800043a2 <namex+0x144>
  while(*path != '/' && *path != 0)
    800043b6:	0004c783          	lbu	a5,0(s1)
    800043ba:	85a6                	mv	a1,s1
    800043bc:	b7d1                	j	80004380 <namex+0x122>

00000000800043be <dirlink>:
{
    800043be:	7139                	addi	sp,sp,-64
    800043c0:	fc06                	sd	ra,56(sp)
    800043c2:	f822                	sd	s0,48(sp)
    800043c4:	f426                	sd	s1,40(sp)
    800043c6:	f04a                	sd	s2,32(sp)
    800043c8:	ec4e                	sd	s3,24(sp)
    800043ca:	e852                	sd	s4,16(sp)
    800043cc:	0080                	addi	s0,sp,64
    800043ce:	892a                	mv	s2,a0
    800043d0:	8a2e                	mv	s4,a1
    800043d2:	89b2                	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    800043d4:	4601                	li	a2,0
    800043d6:	00000097          	auipc	ra,0x0
    800043da:	dd8080e7          	jalr	-552(ra) # 800041ae <dirlookup>
    800043de:	e93d                	bnez	a0,80004454 <dirlink+0x96>
  for(off = 0; off < dp->size; off += sizeof(de)){
    800043e0:	04c92483          	lw	s1,76(s2)
    800043e4:	c49d                	beqz	s1,80004412 <dirlink+0x54>
    800043e6:	4481                	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    800043e8:	4741                	li	a4,16
    800043ea:	86a6                	mv	a3,s1
    800043ec:	fc040613          	addi	a2,s0,-64
    800043f0:	4581                	li	a1,0
    800043f2:	854a                	mv	a0,s2
    800043f4:	00000097          	auipc	ra,0x0
    800043f8:	b8a080e7          	jalr	-1142(ra) # 80003f7e <readi>
    800043fc:	47c1                	li	a5,16
    800043fe:	06f51163          	bne	a0,a5,80004460 <dirlink+0xa2>
    if(de.inum == 0)
    80004402:	fc045783          	lhu	a5,-64(s0)
    80004406:	c791                	beqz	a5,80004412 <dirlink+0x54>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80004408:	24c1                	addiw	s1,s1,16
    8000440a:	04c92783          	lw	a5,76(s2)
    8000440e:	fcf4ede3          	bltu	s1,a5,800043e8 <dirlink+0x2a>
  strncpy(de.name, name, DIRSIZ);
    80004412:	4639                	li	a2,14
    80004414:	85d2                	mv	a1,s4
    80004416:	fc240513          	addi	a0,s0,-62
    8000441a:	ffffd097          	auipc	ra,0xffffd
    8000441e:	c78080e7          	jalr	-904(ra) # 80001092 <strncpy>
  de.inum = inum;
    80004422:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80004426:	4741                	li	a4,16
    80004428:	86a6                	mv	a3,s1
    8000442a:	fc040613          	addi	a2,s0,-64
    8000442e:	4581                	li	a1,0
    80004430:	854a                	mv	a0,s2
    80004432:	00000097          	auipc	ra,0x0
    80004436:	c44080e7          	jalr	-956(ra) # 80004076 <writei>
    8000443a:	1541                	addi	a0,a0,-16
    8000443c:	00a03533          	snez	a0,a0
    80004440:	40a00533          	neg	a0,a0
}
    80004444:	70e2                	ld	ra,56(sp)
    80004446:	7442                	ld	s0,48(sp)
    80004448:	74a2                	ld	s1,40(sp)
    8000444a:	7902                	ld	s2,32(sp)
    8000444c:	69e2                	ld	s3,24(sp)
    8000444e:	6a42                	ld	s4,16(sp)
    80004450:	6121                	addi	sp,sp,64
    80004452:	8082                	ret
    iput(ip);
    80004454:	00000097          	auipc	ra,0x0
    80004458:	a30080e7          	jalr	-1488(ra) # 80003e84 <iput>
    return -1;
    8000445c:	557d                	li	a0,-1
    8000445e:	b7dd                	j	80004444 <dirlink+0x86>
      panic("dirlink read");
    80004460:	00004517          	auipc	a0,0x4
    80004464:	21050513          	addi	a0,a0,528 # 80008670 <syscalls+0x1d0>
    80004468:	ffffc097          	auipc	ra,0xffffc
    8000446c:	0d6080e7          	jalr	214(ra) # 8000053e <panic>

0000000080004470 <namei>:

struct inode*
namei(char *path)
{
    80004470:	1101                	addi	sp,sp,-32
    80004472:	ec06                	sd	ra,24(sp)
    80004474:	e822                	sd	s0,16(sp)
    80004476:	1000                	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80004478:	fe040613          	addi	a2,s0,-32
    8000447c:	4581                	li	a1,0
    8000447e:	00000097          	auipc	ra,0x0
    80004482:	de0080e7          	jalr	-544(ra) # 8000425e <namex>
}
    80004486:	60e2                	ld	ra,24(sp)
    80004488:	6442                	ld	s0,16(sp)
    8000448a:	6105                	addi	sp,sp,32
    8000448c:	8082                	ret

000000008000448e <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    8000448e:	1141                	addi	sp,sp,-16
    80004490:	e406                	sd	ra,8(sp)
    80004492:	e022                	sd	s0,0(sp)
    80004494:	0800                	addi	s0,sp,16
    80004496:	862e                	mv	a2,a1
  return namex(path, 1, name);
    80004498:	4585                	li	a1,1
    8000449a:	00000097          	auipc	ra,0x0
    8000449e:	dc4080e7          	jalr	-572(ra) # 8000425e <namex>
}
    800044a2:	60a2                	ld	ra,8(sp)
    800044a4:	6402                	ld	s0,0(sp)
    800044a6:	0141                	addi	sp,sp,16
    800044a8:	8082                	ret

00000000800044aa <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    800044aa:	1101                	addi	sp,sp,-32
    800044ac:	ec06                	sd	ra,24(sp)
    800044ae:	e822                	sd	s0,16(sp)
    800044b0:	e426                	sd	s1,8(sp)
    800044b2:	e04a                	sd	s2,0(sp)
    800044b4:	1000                	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    800044b6:	0003d917          	auipc	s2,0x3d
    800044ba:	aaa90913          	addi	s2,s2,-1366 # 80040f60 <log>
    800044be:	01892583          	lw	a1,24(s2)
    800044c2:	02892503          	lw	a0,40(s2)
    800044c6:	fffff097          	auipc	ra,0xfffff
    800044ca:	fea080e7          	jalr	-22(ra) # 800034b0 <bread>
    800044ce:	84aa                	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    800044d0:	02c92683          	lw	a3,44(s2)
    800044d4:	cd34                	sw	a3,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    800044d6:	02d05763          	blez	a3,80004504 <write_head+0x5a>
    800044da:	0003d797          	auipc	a5,0x3d
    800044de:	ab678793          	addi	a5,a5,-1354 # 80040f90 <log+0x30>
    800044e2:	05c50713          	addi	a4,a0,92
    800044e6:	36fd                	addiw	a3,a3,-1
    800044e8:	1682                	slli	a3,a3,0x20
    800044ea:	9281                	srli	a3,a3,0x20
    800044ec:	068a                	slli	a3,a3,0x2
    800044ee:	0003d617          	auipc	a2,0x3d
    800044f2:	aa660613          	addi	a2,a2,-1370 # 80040f94 <log+0x34>
    800044f6:	96b2                	add	a3,a3,a2
    hb->block[i] = log.lh.block[i];
    800044f8:	4390                	lw	a2,0(a5)
    800044fa:	c310                	sw	a2,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    800044fc:	0791                	addi	a5,a5,4
    800044fe:	0711                	addi	a4,a4,4
    80004500:	fed79ce3          	bne	a5,a3,800044f8 <write_head+0x4e>
  }
  bwrite(buf);
    80004504:	8526                	mv	a0,s1
    80004506:	fffff097          	auipc	ra,0xfffff
    8000450a:	09c080e7          	jalr	156(ra) # 800035a2 <bwrite>
  brelse(buf);
    8000450e:	8526                	mv	a0,s1
    80004510:	fffff097          	auipc	ra,0xfffff
    80004514:	0d0080e7          	jalr	208(ra) # 800035e0 <brelse>
}
    80004518:	60e2                	ld	ra,24(sp)
    8000451a:	6442                	ld	s0,16(sp)
    8000451c:	64a2                	ld	s1,8(sp)
    8000451e:	6902                	ld	s2,0(sp)
    80004520:	6105                	addi	sp,sp,32
    80004522:	8082                	ret

0000000080004524 <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    80004524:	0003d797          	auipc	a5,0x3d
    80004528:	a687a783          	lw	a5,-1432(a5) # 80040f8c <log+0x2c>
    8000452c:	0af05d63          	blez	a5,800045e6 <install_trans+0xc2>
{
    80004530:	7139                	addi	sp,sp,-64
    80004532:	fc06                	sd	ra,56(sp)
    80004534:	f822                	sd	s0,48(sp)
    80004536:	f426                	sd	s1,40(sp)
    80004538:	f04a                	sd	s2,32(sp)
    8000453a:	ec4e                	sd	s3,24(sp)
    8000453c:	e852                	sd	s4,16(sp)
    8000453e:	e456                	sd	s5,8(sp)
    80004540:	e05a                	sd	s6,0(sp)
    80004542:	0080                	addi	s0,sp,64
    80004544:	8b2a                	mv	s6,a0
    80004546:	0003da97          	auipc	s5,0x3d
    8000454a:	a4aa8a93          	addi	s5,s5,-1462 # 80040f90 <log+0x30>
  for (tail = 0; tail < log.lh.n; tail++) {
    8000454e:	4a01                	li	s4,0
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80004550:	0003d997          	auipc	s3,0x3d
    80004554:	a1098993          	addi	s3,s3,-1520 # 80040f60 <log>
    80004558:	a00d                	j	8000457a <install_trans+0x56>
    brelse(lbuf);
    8000455a:	854a                	mv	a0,s2
    8000455c:	fffff097          	auipc	ra,0xfffff
    80004560:	084080e7          	jalr	132(ra) # 800035e0 <brelse>
    brelse(dbuf);
    80004564:	8526                	mv	a0,s1
    80004566:	fffff097          	auipc	ra,0xfffff
    8000456a:	07a080e7          	jalr	122(ra) # 800035e0 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    8000456e:	2a05                	addiw	s4,s4,1
    80004570:	0a91                	addi	s5,s5,4
    80004572:	02c9a783          	lw	a5,44(s3)
    80004576:	04fa5e63          	bge	s4,a5,800045d2 <install_trans+0xae>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    8000457a:	0189a583          	lw	a1,24(s3)
    8000457e:	014585bb          	addw	a1,a1,s4
    80004582:	2585                	addiw	a1,a1,1
    80004584:	0289a503          	lw	a0,40(s3)
    80004588:	fffff097          	auipc	ra,0xfffff
    8000458c:	f28080e7          	jalr	-216(ra) # 800034b0 <bread>
    80004590:	892a                	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    80004592:	000aa583          	lw	a1,0(s5)
    80004596:	0289a503          	lw	a0,40(s3)
    8000459a:	fffff097          	auipc	ra,0xfffff
    8000459e:	f16080e7          	jalr	-234(ra) # 800034b0 <bread>
    800045a2:	84aa                	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    800045a4:	40000613          	li	a2,1024
    800045a8:	05890593          	addi	a1,s2,88
    800045ac:	05850513          	addi	a0,a0,88
    800045b0:	ffffd097          	auipc	ra,0xffffd
    800045b4:	a32080e7          	jalr	-1486(ra) # 80000fe2 <memmove>
    bwrite(dbuf);  // write dst to disk
    800045b8:	8526                	mv	a0,s1
    800045ba:	fffff097          	auipc	ra,0xfffff
    800045be:	fe8080e7          	jalr	-24(ra) # 800035a2 <bwrite>
    if(recovering == 0)
    800045c2:	f80b1ce3          	bnez	s6,8000455a <install_trans+0x36>
      bunpin(dbuf);
    800045c6:	8526                	mv	a0,s1
    800045c8:	fffff097          	auipc	ra,0xfffff
    800045cc:	0f2080e7          	jalr	242(ra) # 800036ba <bunpin>
    800045d0:	b769                	j	8000455a <install_trans+0x36>
}
    800045d2:	70e2                	ld	ra,56(sp)
    800045d4:	7442                	ld	s0,48(sp)
    800045d6:	74a2                	ld	s1,40(sp)
    800045d8:	7902                	ld	s2,32(sp)
    800045da:	69e2                	ld	s3,24(sp)
    800045dc:	6a42                	ld	s4,16(sp)
    800045de:	6aa2                	ld	s5,8(sp)
    800045e0:	6b02                	ld	s6,0(sp)
    800045e2:	6121                	addi	sp,sp,64
    800045e4:	8082                	ret
    800045e6:	8082                	ret

00000000800045e8 <initlog>:
{
    800045e8:	7179                	addi	sp,sp,-48
    800045ea:	f406                	sd	ra,40(sp)
    800045ec:	f022                	sd	s0,32(sp)
    800045ee:	ec26                	sd	s1,24(sp)
    800045f0:	e84a                	sd	s2,16(sp)
    800045f2:	e44e                	sd	s3,8(sp)
    800045f4:	1800                	addi	s0,sp,48
    800045f6:	892a                	mv	s2,a0
    800045f8:	89ae                	mv	s3,a1
  initlock(&log.lock, "log");
    800045fa:	0003d497          	auipc	s1,0x3d
    800045fe:	96648493          	addi	s1,s1,-1690 # 80040f60 <log>
    80004602:	00004597          	auipc	a1,0x4
    80004606:	07e58593          	addi	a1,a1,126 # 80008680 <syscalls+0x1e0>
    8000460a:	8526                	mv	a0,s1
    8000460c:	ffffc097          	auipc	ra,0xffffc
    80004610:	7ee080e7          	jalr	2030(ra) # 80000dfa <initlock>
  log.start = sb->logstart;
    80004614:	0149a583          	lw	a1,20(s3)
    80004618:	cc8c                	sw	a1,24(s1)
  log.size = sb->nlog;
    8000461a:	0109a783          	lw	a5,16(s3)
    8000461e:	ccdc                	sw	a5,28(s1)
  log.dev = dev;
    80004620:	0324a423          	sw	s2,40(s1)
  struct buf *buf = bread(log.dev, log.start);
    80004624:	854a                	mv	a0,s2
    80004626:	fffff097          	auipc	ra,0xfffff
    8000462a:	e8a080e7          	jalr	-374(ra) # 800034b0 <bread>
  log.lh.n = lh->n;
    8000462e:	4d34                	lw	a3,88(a0)
    80004630:	d4d4                	sw	a3,44(s1)
  for (i = 0; i < log.lh.n; i++) {
    80004632:	02d05563          	blez	a3,8000465c <initlog+0x74>
    80004636:	05c50793          	addi	a5,a0,92
    8000463a:	0003d717          	auipc	a4,0x3d
    8000463e:	95670713          	addi	a4,a4,-1706 # 80040f90 <log+0x30>
    80004642:	36fd                	addiw	a3,a3,-1
    80004644:	1682                	slli	a3,a3,0x20
    80004646:	9281                	srli	a3,a3,0x20
    80004648:	068a                	slli	a3,a3,0x2
    8000464a:	06050613          	addi	a2,a0,96
    8000464e:	96b2                	add	a3,a3,a2
    log.lh.block[i] = lh->block[i];
    80004650:	4390                	lw	a2,0(a5)
    80004652:	c310                	sw	a2,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80004654:	0791                	addi	a5,a5,4
    80004656:	0711                	addi	a4,a4,4
    80004658:	fed79ce3          	bne	a5,a3,80004650 <initlog+0x68>
  brelse(buf);
    8000465c:	fffff097          	auipc	ra,0xfffff
    80004660:	f84080e7          	jalr	-124(ra) # 800035e0 <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    80004664:	4505                	li	a0,1
    80004666:	00000097          	auipc	ra,0x0
    8000466a:	ebe080e7          	jalr	-322(ra) # 80004524 <install_trans>
  log.lh.n = 0;
    8000466e:	0003d797          	auipc	a5,0x3d
    80004672:	9007af23          	sw	zero,-1762(a5) # 80040f8c <log+0x2c>
  write_head(); // clear the log
    80004676:	00000097          	auipc	ra,0x0
    8000467a:	e34080e7          	jalr	-460(ra) # 800044aa <write_head>
}
    8000467e:	70a2                	ld	ra,40(sp)
    80004680:	7402                	ld	s0,32(sp)
    80004682:	64e2                	ld	s1,24(sp)
    80004684:	6942                	ld	s2,16(sp)
    80004686:	69a2                	ld	s3,8(sp)
    80004688:	6145                	addi	sp,sp,48
    8000468a:	8082                	ret

000000008000468c <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    8000468c:	1101                	addi	sp,sp,-32
    8000468e:	ec06                	sd	ra,24(sp)
    80004690:	e822                	sd	s0,16(sp)
    80004692:	e426                	sd	s1,8(sp)
    80004694:	e04a                	sd	s2,0(sp)
    80004696:	1000                	addi	s0,sp,32
  acquire(&log.lock);
    80004698:	0003d517          	auipc	a0,0x3d
    8000469c:	8c850513          	addi	a0,a0,-1848 # 80040f60 <log>
    800046a0:	ffffc097          	auipc	ra,0xffffc
    800046a4:	7ea080e7          	jalr	2026(ra) # 80000e8a <acquire>
  while(1){
    if(log.committing){
    800046a8:	0003d497          	auipc	s1,0x3d
    800046ac:	8b848493          	addi	s1,s1,-1864 # 80040f60 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    800046b0:	4979                	li	s2,30
    800046b2:	a039                	j	800046c0 <begin_op+0x34>
      sleep(&log, &log.lock);
    800046b4:	85a6                	mv	a1,s1
    800046b6:	8526                	mv	a0,s1
    800046b8:	ffffe097          	auipc	ra,0xffffe
    800046bc:	d82080e7          	jalr	-638(ra) # 8000243a <sleep>
    if(log.committing){
    800046c0:	50dc                	lw	a5,36(s1)
    800046c2:	fbed                	bnez	a5,800046b4 <begin_op+0x28>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGSIZE){
    800046c4:	509c                	lw	a5,32(s1)
    800046c6:	0017871b          	addiw	a4,a5,1
    800046ca:	0007069b          	sext.w	a3,a4
    800046ce:	0027179b          	slliw	a5,a4,0x2
    800046d2:	9fb9                	addw	a5,a5,a4
    800046d4:	0017979b          	slliw	a5,a5,0x1
    800046d8:	54d8                	lw	a4,44(s1)
    800046da:	9fb9                	addw	a5,a5,a4
    800046dc:	00f95963          	bge	s2,a5,800046ee <begin_op+0x62>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    800046e0:	85a6                	mv	a1,s1
    800046e2:	8526                	mv	a0,s1
    800046e4:	ffffe097          	auipc	ra,0xffffe
    800046e8:	d56080e7          	jalr	-682(ra) # 8000243a <sleep>
    800046ec:	bfd1                	j	800046c0 <begin_op+0x34>
    } else {
      log.outstanding += 1;
    800046ee:	0003d517          	auipc	a0,0x3d
    800046f2:	87250513          	addi	a0,a0,-1934 # 80040f60 <log>
    800046f6:	d114                	sw	a3,32(a0)
      release(&log.lock);
    800046f8:	ffffd097          	auipc	ra,0xffffd
    800046fc:	846080e7          	jalr	-1978(ra) # 80000f3e <release>
      break;
    }
  }
}
    80004700:	60e2                	ld	ra,24(sp)
    80004702:	6442                	ld	s0,16(sp)
    80004704:	64a2                	ld	s1,8(sp)
    80004706:	6902                	ld	s2,0(sp)
    80004708:	6105                	addi	sp,sp,32
    8000470a:	8082                	ret

000000008000470c <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    8000470c:	7139                	addi	sp,sp,-64
    8000470e:	fc06                	sd	ra,56(sp)
    80004710:	f822                	sd	s0,48(sp)
    80004712:	f426                	sd	s1,40(sp)
    80004714:	f04a                	sd	s2,32(sp)
    80004716:	ec4e                	sd	s3,24(sp)
    80004718:	e852                	sd	s4,16(sp)
    8000471a:	e456                	sd	s5,8(sp)
    8000471c:	0080                	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    8000471e:	0003d497          	auipc	s1,0x3d
    80004722:	84248493          	addi	s1,s1,-1982 # 80040f60 <log>
    80004726:	8526                	mv	a0,s1
    80004728:	ffffc097          	auipc	ra,0xffffc
    8000472c:	762080e7          	jalr	1890(ra) # 80000e8a <acquire>
  log.outstanding -= 1;
    80004730:	509c                	lw	a5,32(s1)
    80004732:	37fd                	addiw	a5,a5,-1
    80004734:	0007891b          	sext.w	s2,a5
    80004738:	d09c                	sw	a5,32(s1)
  if(log.committing)
    8000473a:	50dc                	lw	a5,36(s1)
    8000473c:	e7b9                	bnez	a5,8000478a <end_op+0x7e>
    panic("log.committing");
  if(log.outstanding == 0){
    8000473e:	04091e63          	bnez	s2,8000479a <end_op+0x8e>
    do_commit = 1;
    log.committing = 1;
    80004742:	0003d497          	auipc	s1,0x3d
    80004746:	81e48493          	addi	s1,s1,-2018 # 80040f60 <log>
    8000474a:	4785                	li	a5,1
    8000474c:	d0dc                	sw	a5,36(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    8000474e:	8526                	mv	a0,s1
    80004750:	ffffc097          	auipc	ra,0xffffc
    80004754:	7ee080e7          	jalr	2030(ra) # 80000f3e <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    80004758:	54dc                	lw	a5,44(s1)
    8000475a:	06f04763          	bgtz	a5,800047c8 <end_op+0xbc>
    acquire(&log.lock);
    8000475e:	0003d497          	auipc	s1,0x3d
    80004762:	80248493          	addi	s1,s1,-2046 # 80040f60 <log>
    80004766:	8526                	mv	a0,s1
    80004768:	ffffc097          	auipc	ra,0xffffc
    8000476c:	722080e7          	jalr	1826(ra) # 80000e8a <acquire>
    log.committing = 0;
    80004770:	0204a223          	sw	zero,36(s1)
    wakeup(&log);
    80004774:	8526                	mv	a0,s1
    80004776:	ffffe097          	auipc	ra,0xffffe
    8000477a:	d28080e7          	jalr	-728(ra) # 8000249e <wakeup>
    release(&log.lock);
    8000477e:	8526                	mv	a0,s1
    80004780:	ffffc097          	auipc	ra,0xffffc
    80004784:	7be080e7          	jalr	1982(ra) # 80000f3e <release>
}
    80004788:	a03d                	j	800047b6 <end_op+0xaa>
    panic("log.committing");
    8000478a:	00004517          	auipc	a0,0x4
    8000478e:	efe50513          	addi	a0,a0,-258 # 80008688 <syscalls+0x1e8>
    80004792:	ffffc097          	auipc	ra,0xffffc
    80004796:	dac080e7          	jalr	-596(ra) # 8000053e <panic>
    wakeup(&log);
    8000479a:	0003c497          	auipc	s1,0x3c
    8000479e:	7c648493          	addi	s1,s1,1990 # 80040f60 <log>
    800047a2:	8526                	mv	a0,s1
    800047a4:	ffffe097          	auipc	ra,0xffffe
    800047a8:	cfa080e7          	jalr	-774(ra) # 8000249e <wakeup>
  release(&log.lock);
    800047ac:	8526                	mv	a0,s1
    800047ae:	ffffc097          	auipc	ra,0xffffc
    800047b2:	790080e7          	jalr	1936(ra) # 80000f3e <release>
}
    800047b6:	70e2                	ld	ra,56(sp)
    800047b8:	7442                	ld	s0,48(sp)
    800047ba:	74a2                	ld	s1,40(sp)
    800047bc:	7902                	ld	s2,32(sp)
    800047be:	69e2                	ld	s3,24(sp)
    800047c0:	6a42                	ld	s4,16(sp)
    800047c2:	6aa2                	ld	s5,8(sp)
    800047c4:	6121                	addi	sp,sp,64
    800047c6:	8082                	ret
  for (tail = 0; tail < log.lh.n; tail++) {
    800047c8:	0003ca97          	auipc	s5,0x3c
    800047cc:	7c8a8a93          	addi	s5,s5,1992 # 80040f90 <log+0x30>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    800047d0:	0003ca17          	auipc	s4,0x3c
    800047d4:	790a0a13          	addi	s4,s4,1936 # 80040f60 <log>
    800047d8:	018a2583          	lw	a1,24(s4)
    800047dc:	012585bb          	addw	a1,a1,s2
    800047e0:	2585                	addiw	a1,a1,1
    800047e2:	028a2503          	lw	a0,40(s4)
    800047e6:	fffff097          	auipc	ra,0xfffff
    800047ea:	cca080e7          	jalr	-822(ra) # 800034b0 <bread>
    800047ee:	84aa                	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    800047f0:	000aa583          	lw	a1,0(s5)
    800047f4:	028a2503          	lw	a0,40(s4)
    800047f8:	fffff097          	auipc	ra,0xfffff
    800047fc:	cb8080e7          	jalr	-840(ra) # 800034b0 <bread>
    80004800:	89aa                	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    80004802:	40000613          	li	a2,1024
    80004806:	05850593          	addi	a1,a0,88
    8000480a:	05848513          	addi	a0,s1,88
    8000480e:	ffffc097          	auipc	ra,0xffffc
    80004812:	7d4080e7          	jalr	2004(ra) # 80000fe2 <memmove>
    bwrite(to);  // write the log
    80004816:	8526                	mv	a0,s1
    80004818:	fffff097          	auipc	ra,0xfffff
    8000481c:	d8a080e7          	jalr	-630(ra) # 800035a2 <bwrite>
    brelse(from);
    80004820:	854e                	mv	a0,s3
    80004822:	fffff097          	auipc	ra,0xfffff
    80004826:	dbe080e7          	jalr	-578(ra) # 800035e0 <brelse>
    brelse(to);
    8000482a:	8526                	mv	a0,s1
    8000482c:	fffff097          	auipc	ra,0xfffff
    80004830:	db4080e7          	jalr	-588(ra) # 800035e0 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    80004834:	2905                	addiw	s2,s2,1
    80004836:	0a91                	addi	s5,s5,4
    80004838:	02ca2783          	lw	a5,44(s4)
    8000483c:	f8f94ee3          	blt	s2,a5,800047d8 <end_op+0xcc>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    80004840:	00000097          	auipc	ra,0x0
    80004844:	c6a080e7          	jalr	-918(ra) # 800044aa <write_head>
    install_trans(0); // Now install writes to home locations
    80004848:	4501                	li	a0,0
    8000484a:	00000097          	auipc	ra,0x0
    8000484e:	cda080e7          	jalr	-806(ra) # 80004524 <install_trans>
    log.lh.n = 0;
    80004852:	0003c797          	auipc	a5,0x3c
    80004856:	7207ad23          	sw	zero,1850(a5) # 80040f8c <log+0x2c>
    write_head();    // Erase the transaction from the log
    8000485a:	00000097          	auipc	ra,0x0
    8000485e:	c50080e7          	jalr	-944(ra) # 800044aa <write_head>
    80004862:	bdf5                	j	8000475e <end_op+0x52>

0000000080004864 <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    80004864:	1101                	addi	sp,sp,-32
    80004866:	ec06                	sd	ra,24(sp)
    80004868:	e822                	sd	s0,16(sp)
    8000486a:	e426                	sd	s1,8(sp)
    8000486c:	e04a                	sd	s2,0(sp)
    8000486e:	1000                	addi	s0,sp,32
    80004870:	84aa                	mv	s1,a0
  int i;

  acquire(&log.lock);
    80004872:	0003c917          	auipc	s2,0x3c
    80004876:	6ee90913          	addi	s2,s2,1774 # 80040f60 <log>
    8000487a:	854a                	mv	a0,s2
    8000487c:	ffffc097          	auipc	ra,0xffffc
    80004880:	60e080e7          	jalr	1550(ra) # 80000e8a <acquire>
  if (log.lh.n >= LOGSIZE || log.lh.n >= log.size - 1)
    80004884:	02c92603          	lw	a2,44(s2)
    80004888:	47f5                	li	a5,29
    8000488a:	06c7c563          	blt	a5,a2,800048f4 <log_write+0x90>
    8000488e:	0003c797          	auipc	a5,0x3c
    80004892:	6ee7a783          	lw	a5,1774(a5) # 80040f7c <log+0x1c>
    80004896:	37fd                	addiw	a5,a5,-1
    80004898:	04f65e63          	bge	a2,a5,800048f4 <log_write+0x90>
    panic("too big a transaction");
  if (log.outstanding < 1)
    8000489c:	0003c797          	auipc	a5,0x3c
    800048a0:	6e47a783          	lw	a5,1764(a5) # 80040f80 <log+0x20>
    800048a4:	06f05063          	blez	a5,80004904 <log_write+0xa0>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    800048a8:	4781                	li	a5,0
    800048aa:	06c05563          	blez	a2,80004914 <log_write+0xb0>
    if (log.lh.block[i] == b->blockno)   // log absorption
    800048ae:	44cc                	lw	a1,12(s1)
    800048b0:	0003c717          	auipc	a4,0x3c
    800048b4:	6e070713          	addi	a4,a4,1760 # 80040f90 <log+0x30>
  for (i = 0; i < log.lh.n; i++) {
    800048b8:	4781                	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    800048ba:	4314                	lw	a3,0(a4)
    800048bc:	04b68c63          	beq	a3,a1,80004914 <log_write+0xb0>
  for (i = 0; i < log.lh.n; i++) {
    800048c0:	2785                	addiw	a5,a5,1
    800048c2:	0711                	addi	a4,a4,4
    800048c4:	fef61be3          	bne	a2,a5,800048ba <log_write+0x56>
      break;
  }
  log.lh.block[i] = b->blockno;
    800048c8:	0621                	addi	a2,a2,8
    800048ca:	060a                	slli	a2,a2,0x2
    800048cc:	0003c797          	auipc	a5,0x3c
    800048d0:	69478793          	addi	a5,a5,1684 # 80040f60 <log>
    800048d4:	963e                	add	a2,a2,a5
    800048d6:	44dc                	lw	a5,12(s1)
    800048d8:	ca1c                	sw	a5,16(a2)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    800048da:	8526                	mv	a0,s1
    800048dc:	fffff097          	auipc	ra,0xfffff
    800048e0:	da2080e7          	jalr	-606(ra) # 8000367e <bpin>
    log.lh.n++;
    800048e4:	0003c717          	auipc	a4,0x3c
    800048e8:	67c70713          	addi	a4,a4,1660 # 80040f60 <log>
    800048ec:	575c                	lw	a5,44(a4)
    800048ee:	2785                	addiw	a5,a5,1
    800048f0:	d75c                	sw	a5,44(a4)
    800048f2:	a835                	j	8000492e <log_write+0xca>
    panic("too big a transaction");
    800048f4:	00004517          	auipc	a0,0x4
    800048f8:	da450513          	addi	a0,a0,-604 # 80008698 <syscalls+0x1f8>
    800048fc:	ffffc097          	auipc	ra,0xffffc
    80004900:	c42080e7          	jalr	-958(ra) # 8000053e <panic>
    panic("log_write outside of trans");
    80004904:	00004517          	auipc	a0,0x4
    80004908:	dac50513          	addi	a0,a0,-596 # 800086b0 <syscalls+0x210>
    8000490c:	ffffc097          	auipc	ra,0xffffc
    80004910:	c32080e7          	jalr	-974(ra) # 8000053e <panic>
  log.lh.block[i] = b->blockno;
    80004914:	00878713          	addi	a4,a5,8
    80004918:	00271693          	slli	a3,a4,0x2
    8000491c:	0003c717          	auipc	a4,0x3c
    80004920:	64470713          	addi	a4,a4,1604 # 80040f60 <log>
    80004924:	9736                	add	a4,a4,a3
    80004926:	44d4                	lw	a3,12(s1)
    80004928:	cb14                	sw	a3,16(a4)
  if (i == log.lh.n) {  // Add new block to log?
    8000492a:	faf608e3          	beq	a2,a5,800048da <log_write+0x76>
  }
  release(&log.lock);
    8000492e:	0003c517          	auipc	a0,0x3c
    80004932:	63250513          	addi	a0,a0,1586 # 80040f60 <log>
    80004936:	ffffc097          	auipc	ra,0xffffc
    8000493a:	608080e7          	jalr	1544(ra) # 80000f3e <release>
}
    8000493e:	60e2                	ld	ra,24(sp)
    80004940:	6442                	ld	s0,16(sp)
    80004942:	64a2                	ld	s1,8(sp)
    80004944:	6902                	ld	s2,0(sp)
    80004946:	6105                	addi	sp,sp,32
    80004948:	8082                	ret

000000008000494a <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    8000494a:	1101                	addi	sp,sp,-32
    8000494c:	ec06                	sd	ra,24(sp)
    8000494e:	e822                	sd	s0,16(sp)
    80004950:	e426                	sd	s1,8(sp)
    80004952:	e04a                	sd	s2,0(sp)
    80004954:	1000                	addi	s0,sp,32
    80004956:	84aa                	mv	s1,a0
    80004958:	892e                	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    8000495a:	00004597          	auipc	a1,0x4
    8000495e:	d7658593          	addi	a1,a1,-650 # 800086d0 <syscalls+0x230>
    80004962:	0521                	addi	a0,a0,8
    80004964:	ffffc097          	auipc	ra,0xffffc
    80004968:	496080e7          	jalr	1174(ra) # 80000dfa <initlock>
  lk->name = name;
    8000496c:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    80004970:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    80004974:	0204a423          	sw	zero,40(s1)
}
    80004978:	60e2                	ld	ra,24(sp)
    8000497a:	6442                	ld	s0,16(sp)
    8000497c:	64a2                	ld	s1,8(sp)
    8000497e:	6902                	ld	s2,0(sp)
    80004980:	6105                	addi	sp,sp,32
    80004982:	8082                	ret

0000000080004984 <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    80004984:	1101                	addi	sp,sp,-32
    80004986:	ec06                	sd	ra,24(sp)
    80004988:	e822                	sd	s0,16(sp)
    8000498a:	e426                	sd	s1,8(sp)
    8000498c:	e04a                	sd	s2,0(sp)
    8000498e:	1000                	addi	s0,sp,32
    80004990:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    80004992:	00850913          	addi	s2,a0,8
    80004996:	854a                	mv	a0,s2
    80004998:	ffffc097          	auipc	ra,0xffffc
    8000499c:	4f2080e7          	jalr	1266(ra) # 80000e8a <acquire>
  while (lk->locked) {
    800049a0:	409c                	lw	a5,0(s1)
    800049a2:	cb89                	beqz	a5,800049b4 <acquiresleep+0x30>
    sleep(lk, &lk->lk);
    800049a4:	85ca                	mv	a1,s2
    800049a6:	8526                	mv	a0,s1
    800049a8:	ffffe097          	auipc	ra,0xffffe
    800049ac:	a92080e7          	jalr	-1390(ra) # 8000243a <sleep>
  while (lk->locked) {
    800049b0:	409c                	lw	a5,0(s1)
    800049b2:	fbed                	bnez	a5,800049a4 <acquiresleep+0x20>
  }
  lk->locked = 1;
    800049b4:	4785                	li	a5,1
    800049b6:	c09c                	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    800049b8:	ffffd097          	auipc	ra,0xffffd
    800049bc:	3c6080e7          	jalr	966(ra) # 80001d7e <myproc>
    800049c0:	591c                	lw	a5,48(a0)
    800049c2:	d49c                	sw	a5,40(s1)
  release(&lk->lk);
    800049c4:	854a                	mv	a0,s2
    800049c6:	ffffc097          	auipc	ra,0xffffc
    800049ca:	578080e7          	jalr	1400(ra) # 80000f3e <release>
}
    800049ce:	60e2                	ld	ra,24(sp)
    800049d0:	6442                	ld	s0,16(sp)
    800049d2:	64a2                	ld	s1,8(sp)
    800049d4:	6902                	ld	s2,0(sp)
    800049d6:	6105                	addi	sp,sp,32
    800049d8:	8082                	ret

00000000800049da <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    800049da:	1101                	addi	sp,sp,-32
    800049dc:	ec06                	sd	ra,24(sp)
    800049de:	e822                	sd	s0,16(sp)
    800049e0:	e426                	sd	s1,8(sp)
    800049e2:	e04a                	sd	s2,0(sp)
    800049e4:	1000                	addi	s0,sp,32
    800049e6:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    800049e8:	00850913          	addi	s2,a0,8
    800049ec:	854a                	mv	a0,s2
    800049ee:	ffffc097          	auipc	ra,0xffffc
    800049f2:	49c080e7          	jalr	1180(ra) # 80000e8a <acquire>
  lk->locked = 0;
    800049f6:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    800049fa:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    800049fe:	8526                	mv	a0,s1
    80004a00:	ffffe097          	auipc	ra,0xffffe
    80004a04:	a9e080e7          	jalr	-1378(ra) # 8000249e <wakeup>
  release(&lk->lk);
    80004a08:	854a                	mv	a0,s2
    80004a0a:	ffffc097          	auipc	ra,0xffffc
    80004a0e:	534080e7          	jalr	1332(ra) # 80000f3e <release>
}
    80004a12:	60e2                	ld	ra,24(sp)
    80004a14:	6442                	ld	s0,16(sp)
    80004a16:	64a2                	ld	s1,8(sp)
    80004a18:	6902                	ld	s2,0(sp)
    80004a1a:	6105                	addi	sp,sp,32
    80004a1c:	8082                	ret

0000000080004a1e <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    80004a1e:	7179                	addi	sp,sp,-48
    80004a20:	f406                	sd	ra,40(sp)
    80004a22:	f022                	sd	s0,32(sp)
    80004a24:	ec26                	sd	s1,24(sp)
    80004a26:	e84a                	sd	s2,16(sp)
    80004a28:	e44e                	sd	s3,8(sp)
    80004a2a:	1800                	addi	s0,sp,48
    80004a2c:	84aa                	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    80004a2e:	00850913          	addi	s2,a0,8
    80004a32:	854a                	mv	a0,s2
    80004a34:	ffffc097          	auipc	ra,0xffffc
    80004a38:	456080e7          	jalr	1110(ra) # 80000e8a <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    80004a3c:	409c                	lw	a5,0(s1)
    80004a3e:	ef99                	bnez	a5,80004a5c <holdingsleep+0x3e>
    80004a40:	4481                	li	s1,0
  release(&lk->lk);
    80004a42:	854a                	mv	a0,s2
    80004a44:	ffffc097          	auipc	ra,0xffffc
    80004a48:	4fa080e7          	jalr	1274(ra) # 80000f3e <release>
  return r;
}
    80004a4c:	8526                	mv	a0,s1
    80004a4e:	70a2                	ld	ra,40(sp)
    80004a50:	7402                	ld	s0,32(sp)
    80004a52:	64e2                	ld	s1,24(sp)
    80004a54:	6942                	ld	s2,16(sp)
    80004a56:	69a2                	ld	s3,8(sp)
    80004a58:	6145                	addi	sp,sp,48
    80004a5a:	8082                	ret
  r = lk->locked && (lk->pid == myproc()->pid);
    80004a5c:	0284a983          	lw	s3,40(s1)
    80004a60:	ffffd097          	auipc	ra,0xffffd
    80004a64:	31e080e7          	jalr	798(ra) # 80001d7e <myproc>
    80004a68:	5904                	lw	s1,48(a0)
    80004a6a:	413484b3          	sub	s1,s1,s3
    80004a6e:	0014b493          	seqz	s1,s1
    80004a72:	bfc1                	j	80004a42 <holdingsleep+0x24>

0000000080004a74 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    80004a74:	1141                	addi	sp,sp,-16
    80004a76:	e406                	sd	ra,8(sp)
    80004a78:	e022                	sd	s0,0(sp)
    80004a7a:	0800                	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    80004a7c:	00004597          	auipc	a1,0x4
    80004a80:	c6458593          	addi	a1,a1,-924 # 800086e0 <syscalls+0x240>
    80004a84:	0003c517          	auipc	a0,0x3c
    80004a88:	62450513          	addi	a0,a0,1572 # 800410a8 <ftable>
    80004a8c:	ffffc097          	auipc	ra,0xffffc
    80004a90:	36e080e7          	jalr	878(ra) # 80000dfa <initlock>
}
    80004a94:	60a2                	ld	ra,8(sp)
    80004a96:	6402                	ld	s0,0(sp)
    80004a98:	0141                	addi	sp,sp,16
    80004a9a:	8082                	ret

0000000080004a9c <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    80004a9c:	1101                	addi	sp,sp,-32
    80004a9e:	ec06                	sd	ra,24(sp)
    80004aa0:	e822                	sd	s0,16(sp)
    80004aa2:	e426                	sd	s1,8(sp)
    80004aa4:	1000                	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    80004aa6:	0003c517          	auipc	a0,0x3c
    80004aaa:	60250513          	addi	a0,a0,1538 # 800410a8 <ftable>
    80004aae:	ffffc097          	auipc	ra,0xffffc
    80004ab2:	3dc080e7          	jalr	988(ra) # 80000e8a <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004ab6:	0003c497          	auipc	s1,0x3c
    80004aba:	60a48493          	addi	s1,s1,1546 # 800410c0 <ftable+0x18>
    80004abe:	0003d717          	auipc	a4,0x3d
    80004ac2:	5a270713          	addi	a4,a4,1442 # 80042060 <disk>
    if(f->ref == 0){
    80004ac6:	40dc                	lw	a5,4(s1)
    80004ac8:	cf99                	beqz	a5,80004ae6 <filealloc+0x4a>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    80004aca:	02848493          	addi	s1,s1,40
    80004ace:	fee49ce3          	bne	s1,a4,80004ac6 <filealloc+0x2a>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    80004ad2:	0003c517          	auipc	a0,0x3c
    80004ad6:	5d650513          	addi	a0,a0,1494 # 800410a8 <ftable>
    80004ada:	ffffc097          	auipc	ra,0xffffc
    80004ade:	464080e7          	jalr	1124(ra) # 80000f3e <release>
  return 0;
    80004ae2:	4481                	li	s1,0
    80004ae4:	a819                	j	80004afa <filealloc+0x5e>
      f->ref = 1;
    80004ae6:	4785                	li	a5,1
    80004ae8:	c0dc                	sw	a5,4(s1)
      release(&ftable.lock);
    80004aea:	0003c517          	auipc	a0,0x3c
    80004aee:	5be50513          	addi	a0,a0,1470 # 800410a8 <ftable>
    80004af2:	ffffc097          	auipc	ra,0xffffc
    80004af6:	44c080e7          	jalr	1100(ra) # 80000f3e <release>
}
    80004afa:	8526                	mv	a0,s1
    80004afc:	60e2                	ld	ra,24(sp)
    80004afe:	6442                	ld	s0,16(sp)
    80004b00:	64a2                	ld	s1,8(sp)
    80004b02:	6105                	addi	sp,sp,32
    80004b04:	8082                	ret

0000000080004b06 <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    80004b06:	1101                	addi	sp,sp,-32
    80004b08:	ec06                	sd	ra,24(sp)
    80004b0a:	e822                	sd	s0,16(sp)
    80004b0c:	e426                	sd	s1,8(sp)
    80004b0e:	1000                	addi	s0,sp,32
    80004b10:	84aa                	mv	s1,a0
  acquire(&ftable.lock);
    80004b12:	0003c517          	auipc	a0,0x3c
    80004b16:	59650513          	addi	a0,a0,1430 # 800410a8 <ftable>
    80004b1a:	ffffc097          	auipc	ra,0xffffc
    80004b1e:	370080e7          	jalr	880(ra) # 80000e8a <acquire>
  if(f->ref < 1)
    80004b22:	40dc                	lw	a5,4(s1)
    80004b24:	02f05263          	blez	a5,80004b48 <filedup+0x42>
    panic("filedup");
  f->ref++;
    80004b28:	2785                	addiw	a5,a5,1
    80004b2a:	c0dc                	sw	a5,4(s1)
  release(&ftable.lock);
    80004b2c:	0003c517          	auipc	a0,0x3c
    80004b30:	57c50513          	addi	a0,a0,1404 # 800410a8 <ftable>
    80004b34:	ffffc097          	auipc	ra,0xffffc
    80004b38:	40a080e7          	jalr	1034(ra) # 80000f3e <release>
  return f;
}
    80004b3c:	8526                	mv	a0,s1
    80004b3e:	60e2                	ld	ra,24(sp)
    80004b40:	6442                	ld	s0,16(sp)
    80004b42:	64a2                	ld	s1,8(sp)
    80004b44:	6105                	addi	sp,sp,32
    80004b46:	8082                	ret
    panic("filedup");
    80004b48:	00004517          	auipc	a0,0x4
    80004b4c:	ba050513          	addi	a0,a0,-1120 # 800086e8 <syscalls+0x248>
    80004b50:	ffffc097          	auipc	ra,0xffffc
    80004b54:	9ee080e7          	jalr	-1554(ra) # 8000053e <panic>

0000000080004b58 <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    80004b58:	7139                	addi	sp,sp,-64
    80004b5a:	fc06                	sd	ra,56(sp)
    80004b5c:	f822                	sd	s0,48(sp)
    80004b5e:	f426                	sd	s1,40(sp)
    80004b60:	f04a                	sd	s2,32(sp)
    80004b62:	ec4e                	sd	s3,24(sp)
    80004b64:	e852                	sd	s4,16(sp)
    80004b66:	e456                	sd	s5,8(sp)
    80004b68:	0080                	addi	s0,sp,64
    80004b6a:	84aa                	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80004b6c:	0003c517          	auipc	a0,0x3c
    80004b70:	53c50513          	addi	a0,a0,1340 # 800410a8 <ftable>
    80004b74:	ffffc097          	auipc	ra,0xffffc
    80004b78:	316080e7          	jalr	790(ra) # 80000e8a <acquire>
  if(f->ref < 1)
    80004b7c:	40dc                	lw	a5,4(s1)
    80004b7e:	06f05163          	blez	a5,80004be0 <fileclose+0x88>
    panic("fileclose");
  if(--f->ref > 0){
    80004b82:	37fd                	addiw	a5,a5,-1
    80004b84:	0007871b          	sext.w	a4,a5
    80004b88:	c0dc                	sw	a5,4(s1)
    80004b8a:	06e04363          	bgtz	a4,80004bf0 <fileclose+0x98>
    release(&ftable.lock);
    return;
  }
  ff = *f;
    80004b8e:	0004a903          	lw	s2,0(s1)
    80004b92:	0094ca83          	lbu	s5,9(s1)
    80004b96:	0104ba03          	ld	s4,16(s1)
    80004b9a:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    80004b9e:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    80004ba2:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    80004ba6:	0003c517          	auipc	a0,0x3c
    80004baa:	50250513          	addi	a0,a0,1282 # 800410a8 <ftable>
    80004bae:	ffffc097          	auipc	ra,0xffffc
    80004bb2:	390080e7          	jalr	912(ra) # 80000f3e <release>

  if(ff.type == FD_PIPE){
    80004bb6:	4785                	li	a5,1
    80004bb8:	04f90d63          	beq	s2,a5,80004c12 <fileclose+0xba>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    80004bbc:	3979                	addiw	s2,s2,-2
    80004bbe:	4785                	li	a5,1
    80004bc0:	0527e063          	bltu	a5,s2,80004c00 <fileclose+0xa8>
    begin_op();
    80004bc4:	00000097          	auipc	ra,0x0
    80004bc8:	ac8080e7          	jalr	-1336(ra) # 8000468c <begin_op>
    iput(ff.ip);
    80004bcc:	854e                	mv	a0,s3
    80004bce:	fffff097          	auipc	ra,0xfffff
    80004bd2:	2b6080e7          	jalr	694(ra) # 80003e84 <iput>
    end_op();
    80004bd6:	00000097          	auipc	ra,0x0
    80004bda:	b36080e7          	jalr	-1226(ra) # 8000470c <end_op>
    80004bde:	a00d                	j	80004c00 <fileclose+0xa8>
    panic("fileclose");
    80004be0:	00004517          	auipc	a0,0x4
    80004be4:	b1050513          	addi	a0,a0,-1264 # 800086f0 <syscalls+0x250>
    80004be8:	ffffc097          	auipc	ra,0xffffc
    80004bec:	956080e7          	jalr	-1706(ra) # 8000053e <panic>
    release(&ftable.lock);
    80004bf0:	0003c517          	auipc	a0,0x3c
    80004bf4:	4b850513          	addi	a0,a0,1208 # 800410a8 <ftable>
    80004bf8:	ffffc097          	auipc	ra,0xffffc
    80004bfc:	346080e7          	jalr	838(ra) # 80000f3e <release>
  }
}
    80004c00:	70e2                	ld	ra,56(sp)
    80004c02:	7442                	ld	s0,48(sp)
    80004c04:	74a2                	ld	s1,40(sp)
    80004c06:	7902                	ld	s2,32(sp)
    80004c08:	69e2                	ld	s3,24(sp)
    80004c0a:	6a42                	ld	s4,16(sp)
    80004c0c:	6aa2                	ld	s5,8(sp)
    80004c0e:	6121                	addi	sp,sp,64
    80004c10:	8082                	ret
    pipeclose(ff.pipe, ff.writable);
    80004c12:	85d6                	mv	a1,s5
    80004c14:	8552                	mv	a0,s4
    80004c16:	00000097          	auipc	ra,0x0
    80004c1a:	34c080e7          	jalr	844(ra) # 80004f62 <pipeclose>
    80004c1e:	b7cd                	j	80004c00 <fileclose+0xa8>

0000000080004c20 <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    80004c20:	715d                	addi	sp,sp,-80
    80004c22:	e486                	sd	ra,72(sp)
    80004c24:	e0a2                	sd	s0,64(sp)
    80004c26:	fc26                	sd	s1,56(sp)
    80004c28:	f84a                	sd	s2,48(sp)
    80004c2a:	f44e                	sd	s3,40(sp)
    80004c2c:	0880                	addi	s0,sp,80
    80004c2e:	84aa                	mv	s1,a0
    80004c30:	89ae                	mv	s3,a1
  struct proc *p = myproc();
    80004c32:	ffffd097          	auipc	ra,0xffffd
    80004c36:	14c080e7          	jalr	332(ra) # 80001d7e <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    80004c3a:	409c                	lw	a5,0(s1)
    80004c3c:	37f9                	addiw	a5,a5,-2
    80004c3e:	4705                	li	a4,1
    80004c40:	04f76763          	bltu	a4,a5,80004c8e <filestat+0x6e>
    80004c44:	892a                	mv	s2,a0
    ilock(f->ip);
    80004c46:	6c88                	ld	a0,24(s1)
    80004c48:	fffff097          	auipc	ra,0xfffff
    80004c4c:	082080e7          	jalr	130(ra) # 80003cca <ilock>
    stati(f->ip, &st);
    80004c50:	fb840593          	addi	a1,s0,-72
    80004c54:	6c88                	ld	a0,24(s1)
    80004c56:	fffff097          	auipc	ra,0xfffff
    80004c5a:	2fe080e7          	jalr	766(ra) # 80003f54 <stati>
    iunlock(f->ip);
    80004c5e:	6c88                	ld	a0,24(s1)
    80004c60:	fffff097          	auipc	ra,0xfffff
    80004c64:	12c080e7          	jalr	300(ra) # 80003d8c <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    80004c68:	46e1                	li	a3,24
    80004c6a:	fb840613          	addi	a2,s0,-72
    80004c6e:	85ce                	mv	a1,s3
    80004c70:	05093503          	ld	a0,80(s2)
    80004c74:	ffffd097          	auipc	ra,0xffffd
    80004c78:	ebe080e7          	jalr	-322(ra) # 80001b32 <copyout>
    80004c7c:	41f5551b          	sraiw	a0,a0,0x1f
      return -1;
    return 0;
  }
  return -1;
}
    80004c80:	60a6                	ld	ra,72(sp)
    80004c82:	6406                	ld	s0,64(sp)
    80004c84:	74e2                	ld	s1,56(sp)
    80004c86:	7942                	ld	s2,48(sp)
    80004c88:	79a2                	ld	s3,40(sp)
    80004c8a:	6161                	addi	sp,sp,80
    80004c8c:	8082                	ret
  return -1;
    80004c8e:	557d                	li	a0,-1
    80004c90:	bfc5                	j	80004c80 <filestat+0x60>

0000000080004c92 <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    80004c92:	7179                	addi	sp,sp,-48
    80004c94:	f406                	sd	ra,40(sp)
    80004c96:	f022                	sd	s0,32(sp)
    80004c98:	ec26                	sd	s1,24(sp)
    80004c9a:	e84a                	sd	s2,16(sp)
    80004c9c:	e44e                	sd	s3,8(sp)
    80004c9e:	1800                	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    80004ca0:	00854783          	lbu	a5,8(a0)
    80004ca4:	c3d5                	beqz	a5,80004d48 <fileread+0xb6>
    80004ca6:	84aa                	mv	s1,a0
    80004ca8:	89ae                	mv	s3,a1
    80004caa:	8932                	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    80004cac:	411c                	lw	a5,0(a0)
    80004cae:	4705                	li	a4,1
    80004cb0:	04e78963          	beq	a5,a4,80004d02 <fileread+0x70>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004cb4:	470d                	li	a4,3
    80004cb6:	04e78d63          	beq	a5,a4,80004d10 <fileread+0x7e>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    80004cba:	4709                	li	a4,2
    80004cbc:	06e79e63          	bne	a5,a4,80004d38 <fileread+0xa6>
    ilock(f->ip);
    80004cc0:	6d08                	ld	a0,24(a0)
    80004cc2:	fffff097          	auipc	ra,0xfffff
    80004cc6:	008080e7          	jalr	8(ra) # 80003cca <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    80004cca:	874a                	mv	a4,s2
    80004ccc:	5094                	lw	a3,32(s1)
    80004cce:	864e                	mv	a2,s3
    80004cd0:	4585                	li	a1,1
    80004cd2:	6c88                	ld	a0,24(s1)
    80004cd4:	fffff097          	auipc	ra,0xfffff
    80004cd8:	2aa080e7          	jalr	682(ra) # 80003f7e <readi>
    80004cdc:	892a                	mv	s2,a0
    80004cde:	00a05563          	blez	a0,80004ce8 <fileread+0x56>
      f->off += r;
    80004ce2:	509c                	lw	a5,32(s1)
    80004ce4:	9fa9                	addw	a5,a5,a0
    80004ce6:	d09c                	sw	a5,32(s1)
    iunlock(f->ip);
    80004ce8:	6c88                	ld	a0,24(s1)
    80004cea:	fffff097          	auipc	ra,0xfffff
    80004cee:	0a2080e7          	jalr	162(ra) # 80003d8c <iunlock>
  } else {
    panic("fileread");
  }

  return r;
}
    80004cf2:	854a                	mv	a0,s2
    80004cf4:	70a2                	ld	ra,40(sp)
    80004cf6:	7402                	ld	s0,32(sp)
    80004cf8:	64e2                	ld	s1,24(sp)
    80004cfa:	6942                	ld	s2,16(sp)
    80004cfc:	69a2                	ld	s3,8(sp)
    80004cfe:	6145                	addi	sp,sp,48
    80004d00:	8082                	ret
    r = piperead(f->pipe, addr, n);
    80004d02:	6908                	ld	a0,16(a0)
    80004d04:	00000097          	auipc	ra,0x0
    80004d08:	3c6080e7          	jalr	966(ra) # 800050ca <piperead>
    80004d0c:	892a                	mv	s2,a0
    80004d0e:	b7d5                	j	80004cf2 <fileread+0x60>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    80004d10:	02451783          	lh	a5,36(a0)
    80004d14:	03079693          	slli	a3,a5,0x30
    80004d18:	92c1                	srli	a3,a3,0x30
    80004d1a:	4725                	li	a4,9
    80004d1c:	02d76863          	bltu	a4,a3,80004d4c <fileread+0xba>
    80004d20:	0792                	slli	a5,a5,0x4
    80004d22:	0003c717          	auipc	a4,0x3c
    80004d26:	2e670713          	addi	a4,a4,742 # 80041008 <devsw>
    80004d2a:	97ba                	add	a5,a5,a4
    80004d2c:	639c                	ld	a5,0(a5)
    80004d2e:	c38d                	beqz	a5,80004d50 <fileread+0xbe>
    r = devsw[f->major].read(1, addr, n);
    80004d30:	4505                	li	a0,1
    80004d32:	9782                	jalr	a5
    80004d34:	892a                	mv	s2,a0
    80004d36:	bf75                	j	80004cf2 <fileread+0x60>
    panic("fileread");
    80004d38:	00004517          	auipc	a0,0x4
    80004d3c:	9c850513          	addi	a0,a0,-1592 # 80008700 <syscalls+0x260>
    80004d40:	ffffb097          	auipc	ra,0xffffb
    80004d44:	7fe080e7          	jalr	2046(ra) # 8000053e <panic>
    return -1;
    80004d48:	597d                	li	s2,-1
    80004d4a:	b765                	j	80004cf2 <fileread+0x60>
      return -1;
    80004d4c:	597d                	li	s2,-1
    80004d4e:	b755                	j	80004cf2 <fileread+0x60>
    80004d50:	597d                	li	s2,-1
    80004d52:	b745                	j	80004cf2 <fileread+0x60>

0000000080004d54 <filewrite>:

// Write to file f.
// addr is a user virtual address.
int
filewrite(struct file *f, uint64 addr, int n)
{
    80004d54:	715d                	addi	sp,sp,-80
    80004d56:	e486                	sd	ra,72(sp)
    80004d58:	e0a2                	sd	s0,64(sp)
    80004d5a:	fc26                	sd	s1,56(sp)
    80004d5c:	f84a                	sd	s2,48(sp)
    80004d5e:	f44e                	sd	s3,40(sp)
    80004d60:	f052                	sd	s4,32(sp)
    80004d62:	ec56                	sd	s5,24(sp)
    80004d64:	e85a                	sd	s6,16(sp)
    80004d66:	e45e                	sd	s7,8(sp)
    80004d68:	e062                	sd	s8,0(sp)
    80004d6a:	0880                	addi	s0,sp,80
  int r, ret = 0;

  if(f->writable == 0)
    80004d6c:	00954783          	lbu	a5,9(a0)
    80004d70:	10078663          	beqz	a5,80004e7c <filewrite+0x128>
    80004d74:	892a                	mv	s2,a0
    80004d76:	8aae                	mv	s5,a1
    80004d78:	8a32                	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    80004d7a:	411c                	lw	a5,0(a0)
    80004d7c:	4705                	li	a4,1
    80004d7e:	02e78263          	beq	a5,a4,80004da2 <filewrite+0x4e>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    80004d82:	470d                	li	a4,3
    80004d84:	02e78663          	beq	a5,a4,80004db0 <filewrite+0x5c>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    80004d88:	4709                	li	a4,2
    80004d8a:	0ee79163          	bne	a5,a4,80004e6c <filewrite+0x118>
    // and 2 blocks of slop for non-aligned writes.
    // this really belongs lower down, since writei()
    // might be writing a device like the console.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    80004d8e:	0ac05d63          	blez	a2,80004e48 <filewrite+0xf4>
    int i = 0;
    80004d92:	4981                	li	s3,0
    80004d94:	6b05                	lui	s6,0x1
    80004d96:	c00b0b13          	addi	s6,s6,-1024 # c00 <_entry-0x7ffff400>
    80004d9a:	6b85                	lui	s7,0x1
    80004d9c:	c00b8b9b          	addiw	s7,s7,-1024
    80004da0:	a861                	j	80004e38 <filewrite+0xe4>
    ret = pipewrite(f->pipe, addr, n);
    80004da2:	6908                	ld	a0,16(a0)
    80004da4:	00000097          	auipc	ra,0x0
    80004da8:	22e080e7          	jalr	558(ra) # 80004fd2 <pipewrite>
    80004dac:	8a2a                	mv	s4,a0
    80004dae:	a045                	j	80004e4e <filewrite+0xfa>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    80004db0:	02451783          	lh	a5,36(a0)
    80004db4:	03079693          	slli	a3,a5,0x30
    80004db8:	92c1                	srli	a3,a3,0x30
    80004dba:	4725                	li	a4,9
    80004dbc:	0cd76263          	bltu	a4,a3,80004e80 <filewrite+0x12c>
    80004dc0:	0792                	slli	a5,a5,0x4
    80004dc2:	0003c717          	auipc	a4,0x3c
    80004dc6:	24670713          	addi	a4,a4,582 # 80041008 <devsw>
    80004dca:	97ba                	add	a5,a5,a4
    80004dcc:	679c                	ld	a5,8(a5)
    80004dce:	cbdd                	beqz	a5,80004e84 <filewrite+0x130>
    ret = devsw[f->major].write(1, addr, n);
    80004dd0:	4505                	li	a0,1
    80004dd2:	9782                	jalr	a5
    80004dd4:	8a2a                	mv	s4,a0
    80004dd6:	a8a5                	j	80004e4e <filewrite+0xfa>
    80004dd8:	00048c1b          	sext.w	s8,s1
      int n1 = n - i;
      if(n1 > max)
        n1 = max;

      begin_op();
    80004ddc:	00000097          	auipc	ra,0x0
    80004de0:	8b0080e7          	jalr	-1872(ra) # 8000468c <begin_op>
      ilock(f->ip);
    80004de4:	01893503          	ld	a0,24(s2)
    80004de8:	fffff097          	auipc	ra,0xfffff
    80004dec:	ee2080e7          	jalr	-286(ra) # 80003cca <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    80004df0:	8762                	mv	a4,s8
    80004df2:	02092683          	lw	a3,32(s2)
    80004df6:	01598633          	add	a2,s3,s5
    80004dfa:	4585                	li	a1,1
    80004dfc:	01893503          	ld	a0,24(s2)
    80004e00:	fffff097          	auipc	ra,0xfffff
    80004e04:	276080e7          	jalr	630(ra) # 80004076 <writei>
    80004e08:	84aa                	mv	s1,a0
    80004e0a:	00a05763          	blez	a0,80004e18 <filewrite+0xc4>
        f->off += r;
    80004e0e:	02092783          	lw	a5,32(s2)
    80004e12:	9fa9                	addw	a5,a5,a0
    80004e14:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    80004e18:	01893503          	ld	a0,24(s2)
    80004e1c:	fffff097          	auipc	ra,0xfffff
    80004e20:	f70080e7          	jalr	-144(ra) # 80003d8c <iunlock>
      end_op();
    80004e24:	00000097          	auipc	ra,0x0
    80004e28:	8e8080e7          	jalr	-1816(ra) # 8000470c <end_op>

      if(r != n1){
    80004e2c:	009c1f63          	bne	s8,s1,80004e4a <filewrite+0xf6>
        // error from writei
        break;
      }
      i += r;
    80004e30:	013489bb          	addw	s3,s1,s3
    while(i < n){
    80004e34:	0149db63          	bge	s3,s4,80004e4a <filewrite+0xf6>
      int n1 = n - i;
    80004e38:	413a07bb          	subw	a5,s4,s3
      if(n1 > max)
    80004e3c:	84be                	mv	s1,a5
    80004e3e:	2781                	sext.w	a5,a5
    80004e40:	f8fb5ce3          	bge	s6,a5,80004dd8 <filewrite+0x84>
    80004e44:	84de                	mv	s1,s7
    80004e46:	bf49                	j	80004dd8 <filewrite+0x84>
    int i = 0;
    80004e48:	4981                	li	s3,0
    }
    ret = (i == n ? n : -1);
    80004e4a:	013a1f63          	bne	s4,s3,80004e68 <filewrite+0x114>
  } else {
    panic("filewrite");
  }

  return ret;
}
    80004e4e:	8552                	mv	a0,s4
    80004e50:	60a6                	ld	ra,72(sp)
    80004e52:	6406                	ld	s0,64(sp)
    80004e54:	74e2                	ld	s1,56(sp)
    80004e56:	7942                	ld	s2,48(sp)
    80004e58:	79a2                	ld	s3,40(sp)
    80004e5a:	7a02                	ld	s4,32(sp)
    80004e5c:	6ae2                	ld	s5,24(sp)
    80004e5e:	6b42                	ld	s6,16(sp)
    80004e60:	6ba2                	ld	s7,8(sp)
    80004e62:	6c02                	ld	s8,0(sp)
    80004e64:	6161                	addi	sp,sp,80
    80004e66:	8082                	ret
    ret = (i == n ? n : -1);
    80004e68:	5a7d                	li	s4,-1
    80004e6a:	b7d5                	j	80004e4e <filewrite+0xfa>
    panic("filewrite");
    80004e6c:	00004517          	auipc	a0,0x4
    80004e70:	8a450513          	addi	a0,a0,-1884 # 80008710 <syscalls+0x270>
    80004e74:	ffffb097          	auipc	ra,0xffffb
    80004e78:	6ca080e7          	jalr	1738(ra) # 8000053e <panic>
    return -1;
    80004e7c:	5a7d                	li	s4,-1
    80004e7e:	bfc1                	j	80004e4e <filewrite+0xfa>
      return -1;
    80004e80:	5a7d                	li	s4,-1
    80004e82:	b7f1                	j	80004e4e <filewrite+0xfa>
    80004e84:	5a7d                	li	s4,-1
    80004e86:	b7e1                	j	80004e4e <filewrite+0xfa>

0000000080004e88 <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    80004e88:	7179                	addi	sp,sp,-48
    80004e8a:	f406                	sd	ra,40(sp)
    80004e8c:	f022                	sd	s0,32(sp)
    80004e8e:	ec26                	sd	s1,24(sp)
    80004e90:	e84a                	sd	s2,16(sp)
    80004e92:	e44e                	sd	s3,8(sp)
    80004e94:	e052                	sd	s4,0(sp)
    80004e96:	1800                	addi	s0,sp,48
    80004e98:	84aa                	mv	s1,a0
    80004e9a:	8a2e                	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80004e9c:	0005b023          	sd	zero,0(a1)
    80004ea0:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    80004ea4:	00000097          	auipc	ra,0x0
    80004ea8:	bf8080e7          	jalr	-1032(ra) # 80004a9c <filealloc>
    80004eac:	e088                	sd	a0,0(s1)
    80004eae:	c551                	beqz	a0,80004f3a <pipealloc+0xb2>
    80004eb0:	00000097          	auipc	ra,0x0
    80004eb4:	bec080e7          	jalr	-1044(ra) # 80004a9c <filealloc>
    80004eb8:	00aa3023          	sd	a0,0(s4)
    80004ebc:	c92d                	beqz	a0,80004f2e <pipealloc+0xa6>
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    80004ebe:	ffffc097          	auipc	ra,0xffffc
    80004ec2:	c82080e7          	jalr	-894(ra) # 80000b40 <kalloc>
    80004ec6:	892a                	mv	s2,a0
    80004ec8:	c125                	beqz	a0,80004f28 <pipealloc+0xa0>
    goto bad;
  pi->readopen = 1;
    80004eca:	4985                	li	s3,1
    80004ecc:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    80004ed0:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    80004ed4:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    80004ed8:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    80004edc:	00004597          	auipc	a1,0x4
    80004ee0:	84458593          	addi	a1,a1,-1980 # 80008720 <syscalls+0x280>
    80004ee4:	ffffc097          	auipc	ra,0xffffc
    80004ee8:	f16080e7          	jalr	-234(ra) # 80000dfa <initlock>
  (*f0)->type = FD_PIPE;
    80004eec:	609c                	ld	a5,0(s1)
    80004eee:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    80004ef2:	609c                	ld	a5,0(s1)
    80004ef4:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    80004ef8:	609c                	ld	a5,0(s1)
    80004efa:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    80004efe:	609c                	ld	a5,0(s1)
    80004f00:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    80004f04:	000a3783          	ld	a5,0(s4)
    80004f08:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    80004f0c:	000a3783          	ld	a5,0(s4)
    80004f10:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    80004f14:	000a3783          	ld	a5,0(s4)
    80004f18:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    80004f1c:	000a3783          	ld	a5,0(s4)
    80004f20:	0127b823          	sd	s2,16(a5)
  return 0;
    80004f24:	4501                	li	a0,0
    80004f26:	a025                	j	80004f4e <pipealloc+0xc6>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    80004f28:	6088                	ld	a0,0(s1)
    80004f2a:	e501                	bnez	a0,80004f32 <pipealloc+0xaa>
    80004f2c:	a039                	j	80004f3a <pipealloc+0xb2>
    80004f2e:	6088                	ld	a0,0(s1)
    80004f30:	c51d                	beqz	a0,80004f5e <pipealloc+0xd6>
    fileclose(*f0);
    80004f32:	00000097          	auipc	ra,0x0
    80004f36:	c26080e7          	jalr	-986(ra) # 80004b58 <fileclose>
  if(*f1)
    80004f3a:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80004f3e:	557d                	li	a0,-1
  if(*f1)
    80004f40:	c799                	beqz	a5,80004f4e <pipealloc+0xc6>
    fileclose(*f1);
    80004f42:	853e                	mv	a0,a5
    80004f44:	00000097          	auipc	ra,0x0
    80004f48:	c14080e7          	jalr	-1004(ra) # 80004b58 <fileclose>
  return -1;
    80004f4c:	557d                	li	a0,-1
}
    80004f4e:	70a2                	ld	ra,40(sp)
    80004f50:	7402                	ld	s0,32(sp)
    80004f52:	64e2                	ld	s1,24(sp)
    80004f54:	6942                	ld	s2,16(sp)
    80004f56:	69a2                	ld	s3,8(sp)
    80004f58:	6a02                	ld	s4,0(sp)
    80004f5a:	6145                	addi	sp,sp,48
    80004f5c:	8082                	ret
  return -1;
    80004f5e:	557d                	li	a0,-1
    80004f60:	b7fd                	j	80004f4e <pipealloc+0xc6>

0000000080004f62 <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    80004f62:	1101                	addi	sp,sp,-32
    80004f64:	ec06                	sd	ra,24(sp)
    80004f66:	e822                	sd	s0,16(sp)
    80004f68:	e426                	sd	s1,8(sp)
    80004f6a:	e04a                	sd	s2,0(sp)
    80004f6c:	1000                	addi	s0,sp,32
    80004f6e:	84aa                	mv	s1,a0
    80004f70:	892e                	mv	s2,a1
  acquire(&pi->lock);
    80004f72:	ffffc097          	auipc	ra,0xffffc
    80004f76:	f18080e7          	jalr	-232(ra) # 80000e8a <acquire>
  if(writable){
    80004f7a:	02090d63          	beqz	s2,80004fb4 <pipeclose+0x52>
    pi->writeopen = 0;
    80004f7e:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    80004f82:	21848513          	addi	a0,s1,536
    80004f86:	ffffd097          	auipc	ra,0xffffd
    80004f8a:	518080e7          	jalr	1304(ra) # 8000249e <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    80004f8e:	2204b783          	ld	a5,544(s1)
    80004f92:	eb95                	bnez	a5,80004fc6 <pipeclose+0x64>
    release(&pi->lock);
    80004f94:	8526                	mv	a0,s1
    80004f96:	ffffc097          	auipc	ra,0xffffc
    80004f9a:	fa8080e7          	jalr	-88(ra) # 80000f3e <release>
    kfree((char*)pi);
    80004f9e:	8526                	mv	a0,s1
    80004fa0:	ffffc097          	auipc	ra,0xffffc
    80004fa4:	a4a080e7          	jalr	-1462(ra) # 800009ea <kfree>
  } else
    release(&pi->lock);
}
    80004fa8:	60e2                	ld	ra,24(sp)
    80004faa:	6442                	ld	s0,16(sp)
    80004fac:	64a2                	ld	s1,8(sp)
    80004fae:	6902                	ld	s2,0(sp)
    80004fb0:	6105                	addi	sp,sp,32
    80004fb2:	8082                	ret
    pi->readopen = 0;
    80004fb4:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    80004fb8:	21c48513          	addi	a0,s1,540
    80004fbc:	ffffd097          	auipc	ra,0xffffd
    80004fc0:	4e2080e7          	jalr	1250(ra) # 8000249e <wakeup>
    80004fc4:	b7e9                	j	80004f8e <pipeclose+0x2c>
    release(&pi->lock);
    80004fc6:	8526                	mv	a0,s1
    80004fc8:	ffffc097          	auipc	ra,0xffffc
    80004fcc:	f76080e7          	jalr	-138(ra) # 80000f3e <release>
}
    80004fd0:	bfe1                	j	80004fa8 <pipeclose+0x46>

0000000080004fd2 <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    80004fd2:	711d                	addi	sp,sp,-96
    80004fd4:	ec86                	sd	ra,88(sp)
    80004fd6:	e8a2                	sd	s0,80(sp)
    80004fd8:	e4a6                	sd	s1,72(sp)
    80004fda:	e0ca                	sd	s2,64(sp)
    80004fdc:	fc4e                	sd	s3,56(sp)
    80004fde:	f852                	sd	s4,48(sp)
    80004fe0:	f456                	sd	s5,40(sp)
    80004fe2:	f05a                	sd	s6,32(sp)
    80004fe4:	ec5e                	sd	s7,24(sp)
    80004fe6:	e862                	sd	s8,16(sp)
    80004fe8:	1080                	addi	s0,sp,96
    80004fea:	84aa                	mv	s1,a0
    80004fec:	8aae                	mv	s5,a1
    80004fee:	8a32                	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    80004ff0:	ffffd097          	auipc	ra,0xffffd
    80004ff4:	d8e080e7          	jalr	-626(ra) # 80001d7e <myproc>
    80004ff8:	89aa                	mv	s3,a0

  acquire(&pi->lock);
    80004ffa:	8526                	mv	a0,s1
    80004ffc:	ffffc097          	auipc	ra,0xffffc
    80005000:	e8e080e7          	jalr	-370(ra) # 80000e8a <acquire>
  while(i < n){
    80005004:	0b405663          	blez	s4,800050b0 <pipewrite+0xde>
  int i = 0;
    80005008:	4901                	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    8000500a:	5b7d                	li	s6,-1
      wakeup(&pi->nread);
    8000500c:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    80005010:	21c48b93          	addi	s7,s1,540
    80005014:	a089                	j	80005056 <pipewrite+0x84>
      release(&pi->lock);
    80005016:	8526                	mv	a0,s1
    80005018:	ffffc097          	auipc	ra,0xffffc
    8000501c:	f26080e7          	jalr	-218(ra) # 80000f3e <release>
      return -1;
    80005020:	597d                	li	s2,-1
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    80005022:	854a                	mv	a0,s2
    80005024:	60e6                	ld	ra,88(sp)
    80005026:	6446                	ld	s0,80(sp)
    80005028:	64a6                	ld	s1,72(sp)
    8000502a:	6906                	ld	s2,64(sp)
    8000502c:	79e2                	ld	s3,56(sp)
    8000502e:	7a42                	ld	s4,48(sp)
    80005030:	7aa2                	ld	s5,40(sp)
    80005032:	7b02                	ld	s6,32(sp)
    80005034:	6be2                	ld	s7,24(sp)
    80005036:	6c42                	ld	s8,16(sp)
    80005038:	6125                	addi	sp,sp,96
    8000503a:	8082                	ret
      wakeup(&pi->nread);
    8000503c:	8562                	mv	a0,s8
    8000503e:	ffffd097          	auipc	ra,0xffffd
    80005042:	460080e7          	jalr	1120(ra) # 8000249e <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    80005046:	85a6                	mv	a1,s1
    80005048:	855e                	mv	a0,s7
    8000504a:	ffffd097          	auipc	ra,0xffffd
    8000504e:	3f0080e7          	jalr	1008(ra) # 8000243a <sleep>
  while(i < n){
    80005052:	07495063          	bge	s2,s4,800050b2 <pipewrite+0xe0>
    if(pi->readopen == 0 || killed(pr)){
    80005056:	2204a783          	lw	a5,544(s1)
    8000505a:	dfd5                	beqz	a5,80005016 <pipewrite+0x44>
    8000505c:	854e                	mv	a0,s3
    8000505e:	ffffd097          	auipc	ra,0xffffd
    80005062:	690080e7          	jalr	1680(ra) # 800026ee <killed>
    80005066:	f945                	bnez	a0,80005016 <pipewrite+0x44>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    80005068:	2184a783          	lw	a5,536(s1)
    8000506c:	21c4a703          	lw	a4,540(s1)
    80005070:	2007879b          	addiw	a5,a5,512
    80005074:	fcf704e3          	beq	a4,a5,8000503c <pipewrite+0x6a>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80005078:	4685                	li	a3,1
    8000507a:	01590633          	add	a2,s2,s5
    8000507e:	faf40593          	addi	a1,s0,-81
    80005082:	0509b503          	ld	a0,80(s3)
    80005086:	ffffd097          	auipc	ra,0xffffd
    8000508a:	8a0080e7          	jalr	-1888(ra) # 80001926 <copyin>
    8000508e:	03650263          	beq	a0,s6,800050b2 <pipewrite+0xe0>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80005092:	21c4a783          	lw	a5,540(s1)
    80005096:	0017871b          	addiw	a4,a5,1
    8000509a:	20e4ae23          	sw	a4,540(s1)
    8000509e:	1ff7f793          	andi	a5,a5,511
    800050a2:	97a6                	add	a5,a5,s1
    800050a4:	faf44703          	lbu	a4,-81(s0)
    800050a8:	00e78c23          	sb	a4,24(a5)
      i++;
    800050ac:	2905                	addiw	s2,s2,1
    800050ae:	b755                	j	80005052 <pipewrite+0x80>
  int i = 0;
    800050b0:	4901                	li	s2,0
  wakeup(&pi->nread);
    800050b2:	21848513          	addi	a0,s1,536
    800050b6:	ffffd097          	auipc	ra,0xffffd
    800050ba:	3e8080e7          	jalr	1000(ra) # 8000249e <wakeup>
  release(&pi->lock);
    800050be:	8526                	mv	a0,s1
    800050c0:	ffffc097          	auipc	ra,0xffffc
    800050c4:	e7e080e7          	jalr	-386(ra) # 80000f3e <release>
  return i;
    800050c8:	bfa9                	j	80005022 <pipewrite+0x50>

00000000800050ca <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    800050ca:	715d                	addi	sp,sp,-80
    800050cc:	e486                	sd	ra,72(sp)
    800050ce:	e0a2                	sd	s0,64(sp)
    800050d0:	fc26                	sd	s1,56(sp)
    800050d2:	f84a                	sd	s2,48(sp)
    800050d4:	f44e                	sd	s3,40(sp)
    800050d6:	f052                	sd	s4,32(sp)
    800050d8:	ec56                	sd	s5,24(sp)
    800050da:	e85a                	sd	s6,16(sp)
    800050dc:	0880                	addi	s0,sp,80
    800050de:	84aa                	mv	s1,a0
    800050e0:	892e                	mv	s2,a1
    800050e2:	8ab2                	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    800050e4:	ffffd097          	auipc	ra,0xffffd
    800050e8:	c9a080e7          	jalr	-870(ra) # 80001d7e <myproc>
    800050ec:	8a2a                	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    800050ee:	8526                	mv	a0,s1
    800050f0:	ffffc097          	auipc	ra,0xffffc
    800050f4:	d9a080e7          	jalr	-614(ra) # 80000e8a <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800050f8:	2184a703          	lw	a4,536(s1)
    800050fc:	21c4a783          	lw	a5,540(s1)
    if(killed(pr)){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    80005100:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    80005104:	02f71763          	bne	a4,a5,80005132 <piperead+0x68>
    80005108:	2244a783          	lw	a5,548(s1)
    8000510c:	c39d                	beqz	a5,80005132 <piperead+0x68>
    if(killed(pr)){
    8000510e:	8552                	mv	a0,s4
    80005110:	ffffd097          	auipc	ra,0xffffd
    80005114:	5de080e7          	jalr	1502(ra) # 800026ee <killed>
    80005118:	e941                	bnez	a0,800051a8 <piperead+0xde>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    8000511a:	85a6                	mv	a1,s1
    8000511c:	854e                	mv	a0,s3
    8000511e:	ffffd097          	auipc	ra,0xffffd
    80005122:	31c080e7          	jalr	796(ra) # 8000243a <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    80005126:	2184a703          	lw	a4,536(s1)
    8000512a:	21c4a783          	lw	a5,540(s1)
    8000512e:	fcf70de3          	beq	a4,a5,80005108 <piperead+0x3e>
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80005132:	4981                	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread++ % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    80005134:	5b7d                	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80005136:	05505363          	blez	s5,8000517c <piperead+0xb2>
    if(pi->nread == pi->nwrite)
    8000513a:	2184a783          	lw	a5,536(s1)
    8000513e:	21c4a703          	lw	a4,540(s1)
    80005142:	02f70d63          	beq	a4,a5,8000517c <piperead+0xb2>
    ch = pi->data[pi->nread++ % PIPESIZE];
    80005146:	0017871b          	addiw	a4,a5,1
    8000514a:	20e4ac23          	sw	a4,536(s1)
    8000514e:	1ff7f793          	andi	a5,a5,511
    80005152:	97a6                	add	a5,a5,s1
    80005154:	0187c783          	lbu	a5,24(a5)
    80005158:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1)
    8000515c:	4685                	li	a3,1
    8000515e:	fbf40613          	addi	a2,s0,-65
    80005162:	85ca                	mv	a1,s2
    80005164:	050a3503          	ld	a0,80(s4)
    80005168:	ffffd097          	auipc	ra,0xffffd
    8000516c:	9ca080e7          	jalr	-1590(ra) # 80001b32 <copyout>
    80005170:	01650663          	beq	a0,s6,8000517c <piperead+0xb2>
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80005174:	2985                	addiw	s3,s3,1
    80005176:	0905                	addi	s2,s2,1
    80005178:	fd3a91e3          	bne	s5,s3,8000513a <piperead+0x70>
      break;
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    8000517c:	21c48513          	addi	a0,s1,540
    80005180:	ffffd097          	auipc	ra,0xffffd
    80005184:	31e080e7          	jalr	798(ra) # 8000249e <wakeup>
  release(&pi->lock);
    80005188:	8526                	mv	a0,s1
    8000518a:	ffffc097          	auipc	ra,0xffffc
    8000518e:	db4080e7          	jalr	-588(ra) # 80000f3e <release>
  return i;
}
    80005192:	854e                	mv	a0,s3
    80005194:	60a6                	ld	ra,72(sp)
    80005196:	6406                	ld	s0,64(sp)
    80005198:	74e2                	ld	s1,56(sp)
    8000519a:	7942                	ld	s2,48(sp)
    8000519c:	79a2                	ld	s3,40(sp)
    8000519e:	7a02                	ld	s4,32(sp)
    800051a0:	6ae2                	ld	s5,24(sp)
    800051a2:	6b42                	ld	s6,16(sp)
    800051a4:	6161                	addi	sp,sp,80
    800051a6:	8082                	ret
      release(&pi->lock);
    800051a8:	8526                	mv	a0,s1
    800051aa:	ffffc097          	auipc	ra,0xffffc
    800051ae:	d94080e7          	jalr	-620(ra) # 80000f3e <release>
      return -1;
    800051b2:	59fd                	li	s3,-1
    800051b4:	bff9                	j	80005192 <piperead+0xc8>

00000000800051b6 <flags2perm>:
#include "elf.h"

static int loadseg(pde_t *, uint64, struct inode *, uint, uint);

int flags2perm(int flags)
{
    800051b6:	1141                	addi	sp,sp,-16
    800051b8:	e422                	sd	s0,8(sp)
    800051ba:	0800                	addi	s0,sp,16
    800051bc:	87aa                	mv	a5,a0
    int perm = 0;
    if(flags & 0x1)
    800051be:	8905                	andi	a0,a0,1
    800051c0:	c111                	beqz	a0,800051c4 <flags2perm+0xe>
      perm = PTE_X;
    800051c2:	4521                	li	a0,8
    if(flags & 0x2)
    800051c4:	8b89                	andi	a5,a5,2
    800051c6:	c399                	beqz	a5,800051cc <flags2perm+0x16>
      perm |= PTE_W;
    800051c8:	00456513          	ori	a0,a0,4
    return perm;
}
    800051cc:	6422                	ld	s0,8(sp)
    800051ce:	0141                	addi	sp,sp,16
    800051d0:	8082                	ret

00000000800051d2 <exec>:

int
exec(char *path, char **argv)
{
    800051d2:	de010113          	addi	sp,sp,-544
    800051d6:	20113c23          	sd	ra,536(sp)
    800051da:	20813823          	sd	s0,528(sp)
    800051de:	20913423          	sd	s1,520(sp)
    800051e2:	21213023          	sd	s2,512(sp)
    800051e6:	ffce                	sd	s3,504(sp)
    800051e8:	fbd2                	sd	s4,496(sp)
    800051ea:	f7d6                	sd	s5,488(sp)
    800051ec:	f3da                	sd	s6,480(sp)
    800051ee:	efde                	sd	s7,472(sp)
    800051f0:	ebe2                	sd	s8,464(sp)
    800051f2:	e7e6                	sd	s9,456(sp)
    800051f4:	e3ea                	sd	s10,448(sp)
    800051f6:	ff6e                	sd	s11,440(sp)
    800051f8:	1400                	addi	s0,sp,544
    800051fa:	892a                	mv	s2,a0
    800051fc:	dea43423          	sd	a0,-536(s0)
    80005200:	deb43823          	sd	a1,-528(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    80005204:	ffffd097          	auipc	ra,0xffffd
    80005208:	b7a080e7          	jalr	-1158(ra) # 80001d7e <myproc>
    8000520c:	84aa                	mv	s1,a0

  begin_op();
    8000520e:	fffff097          	auipc	ra,0xfffff
    80005212:	47e080e7          	jalr	1150(ra) # 8000468c <begin_op>

  if((ip = namei(path)) == 0){
    80005216:	854a                	mv	a0,s2
    80005218:	fffff097          	auipc	ra,0xfffff
    8000521c:	258080e7          	jalr	600(ra) # 80004470 <namei>
    80005220:	c93d                	beqz	a0,80005296 <exec+0xc4>
    80005222:	8aaa                	mv	s5,a0
    end_op();
    return -1;
  }
  ilock(ip);
    80005224:	fffff097          	auipc	ra,0xfffff
    80005228:	aa6080e7          	jalr	-1370(ra) # 80003cca <ilock>

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    8000522c:	04000713          	li	a4,64
    80005230:	4681                	li	a3,0
    80005232:	e5040613          	addi	a2,s0,-432
    80005236:	4581                	li	a1,0
    80005238:	8556                	mv	a0,s5
    8000523a:	fffff097          	auipc	ra,0xfffff
    8000523e:	d44080e7          	jalr	-700(ra) # 80003f7e <readi>
    80005242:	04000793          	li	a5,64
    80005246:	00f51a63          	bne	a0,a5,8000525a <exec+0x88>
    goto bad;

  if(elf.magic != ELF_MAGIC)
    8000524a:	e5042703          	lw	a4,-432(s0)
    8000524e:	464c47b7          	lui	a5,0x464c4
    80005252:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    80005256:	04f70663          	beq	a4,a5,800052a2 <exec+0xd0>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    8000525a:	8556                	mv	a0,s5
    8000525c:	fffff097          	auipc	ra,0xfffff
    80005260:	cd0080e7          	jalr	-816(ra) # 80003f2c <iunlockput>
    end_op();
    80005264:	fffff097          	auipc	ra,0xfffff
    80005268:	4a8080e7          	jalr	1192(ra) # 8000470c <end_op>
  }
  return -1;
    8000526c:	557d                	li	a0,-1
}
    8000526e:	21813083          	ld	ra,536(sp)
    80005272:	21013403          	ld	s0,528(sp)
    80005276:	20813483          	ld	s1,520(sp)
    8000527a:	20013903          	ld	s2,512(sp)
    8000527e:	79fe                	ld	s3,504(sp)
    80005280:	7a5e                	ld	s4,496(sp)
    80005282:	7abe                	ld	s5,488(sp)
    80005284:	7b1e                	ld	s6,480(sp)
    80005286:	6bfe                	ld	s7,472(sp)
    80005288:	6c5e                	ld	s8,464(sp)
    8000528a:	6cbe                	ld	s9,456(sp)
    8000528c:	6d1e                	ld	s10,448(sp)
    8000528e:	7dfa                	ld	s11,440(sp)
    80005290:	22010113          	addi	sp,sp,544
    80005294:	8082                	ret
    end_op();
    80005296:	fffff097          	auipc	ra,0xfffff
    8000529a:	476080e7          	jalr	1142(ra) # 8000470c <end_op>
    return -1;
    8000529e:	557d                	li	a0,-1
    800052a0:	b7f9                	j	8000526e <exec+0x9c>
  if((pagetable = proc_pagetable(p)) == 0)
    800052a2:	8526                	mv	a0,s1
    800052a4:	ffffd097          	auipc	ra,0xffffd
    800052a8:	b9e080e7          	jalr	-1122(ra) # 80001e42 <proc_pagetable>
    800052ac:	8b2a                	mv	s6,a0
    800052ae:	d555                	beqz	a0,8000525a <exec+0x88>
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800052b0:	e7042783          	lw	a5,-400(s0)
    800052b4:	e8845703          	lhu	a4,-376(s0)
    800052b8:	c735                	beqz	a4,80005324 <exec+0x152>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    800052ba:	4901                	li	s2,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800052bc:	e0043423          	sd	zero,-504(s0)
    if(ph.vaddr % PGSIZE != 0)
    800052c0:	6a05                	lui	s4,0x1
    800052c2:	fffa0713          	addi	a4,s4,-1 # fff <_entry-0x7ffff001>
    800052c6:	dee43023          	sd	a4,-544(s0)
loadseg(pagetable_t pagetable, uint64 va, struct inode *ip, uint offset, uint sz)
{
  uint i, n;
  uint64 pa;

  for(i = 0; i < sz; i += PGSIZE){
    800052ca:	6d85                	lui	s11,0x1
    800052cc:	7d7d                	lui	s10,0xfffff
    800052ce:	a481                	j	8000550e <exec+0x33c>
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    800052d0:	00003517          	auipc	a0,0x3
    800052d4:	45850513          	addi	a0,a0,1112 # 80008728 <syscalls+0x288>
    800052d8:	ffffb097          	auipc	ra,0xffffb
    800052dc:	266080e7          	jalr	614(ra) # 8000053e <panic>
    if(sz - i < PGSIZE)
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    800052e0:	874a                	mv	a4,s2
    800052e2:	009c86bb          	addw	a3,s9,s1
    800052e6:	4581                	li	a1,0
    800052e8:	8556                	mv	a0,s5
    800052ea:	fffff097          	auipc	ra,0xfffff
    800052ee:	c94080e7          	jalr	-876(ra) # 80003f7e <readi>
    800052f2:	2501                	sext.w	a0,a0
    800052f4:	1aa91a63          	bne	s2,a0,800054a8 <exec+0x2d6>
  for(i = 0; i < sz; i += PGSIZE){
    800052f8:	009d84bb          	addw	s1,s11,s1
    800052fc:	013d09bb          	addw	s3,s10,s3
    80005300:	1f74f763          	bgeu	s1,s7,800054ee <exec+0x31c>
    pa = walkaddr(pagetable, va + i);
    80005304:	02049593          	slli	a1,s1,0x20
    80005308:	9181                	srli	a1,a1,0x20
    8000530a:	95e2                	add	a1,a1,s8
    8000530c:	855a                	mv	a0,s6
    8000530e:	ffffc097          	auipc	ra,0xffffc
    80005312:	002080e7          	jalr	2(ra) # 80001310 <walkaddr>
    80005316:	862a                	mv	a2,a0
    if(pa == 0)
    80005318:	dd45                	beqz	a0,800052d0 <exec+0xfe>
      n = PGSIZE;
    8000531a:	8952                	mv	s2,s4
    if(sz - i < PGSIZE)
    8000531c:	fd49f2e3          	bgeu	s3,s4,800052e0 <exec+0x10e>
      n = sz - i;
    80005320:	894e                	mv	s2,s3
    80005322:	bf7d                	j	800052e0 <exec+0x10e>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80005324:	4901                	li	s2,0
  iunlockput(ip);
    80005326:	8556                	mv	a0,s5
    80005328:	fffff097          	auipc	ra,0xfffff
    8000532c:	c04080e7          	jalr	-1020(ra) # 80003f2c <iunlockput>
  end_op();
    80005330:	fffff097          	auipc	ra,0xfffff
    80005334:	3dc080e7          	jalr	988(ra) # 8000470c <end_op>
  p = myproc();
    80005338:	ffffd097          	auipc	ra,0xffffd
    8000533c:	a46080e7          	jalr	-1466(ra) # 80001d7e <myproc>
    80005340:	8baa                	mv	s7,a0
  uint64 oldsz = p->sz;
    80005342:	04853d03          	ld	s10,72(a0)
  sz = PGROUNDUP(sz);
    80005346:	6785                	lui	a5,0x1
    80005348:	17fd                	addi	a5,a5,-1
    8000534a:	993e                	add	s2,s2,a5
    8000534c:	77fd                	lui	a5,0xfffff
    8000534e:	00f977b3          	and	a5,s2,a5
    80005352:	def43c23          	sd	a5,-520(s0)
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE, PTE_W)) == 0)
    80005356:	4691                	li	a3,4
    80005358:	6609                	lui	a2,0x2
    8000535a:	963e                	add	a2,a2,a5
    8000535c:	85be                	mv	a1,a5
    8000535e:	855a                	mv	a0,s6
    80005360:	ffffc097          	auipc	ra,0xffffc
    80005364:	364080e7          	jalr	868(ra) # 800016c4 <uvmalloc>
    80005368:	8c2a                	mv	s8,a0
  ip = 0;
    8000536a:	4a81                	li	s5,0
  if((sz1 = uvmalloc(pagetable, sz, sz + 2*PGSIZE, PTE_W)) == 0)
    8000536c:	12050e63          	beqz	a0,800054a8 <exec+0x2d6>
  uvmclear(pagetable, sz-2*PGSIZE);
    80005370:	75f9                	lui	a1,0xffffe
    80005372:	95aa                	add	a1,a1,a0
    80005374:	855a                	mv	a0,s6
    80005376:	ffffc097          	auipc	ra,0xffffc
    8000537a:	57e080e7          	jalr	1406(ra) # 800018f4 <uvmclear>
  stackbase = sp - PGSIZE;
    8000537e:	7afd                	lui	s5,0xfffff
    80005380:	9ae2                	add	s5,s5,s8
  for(argc = 0; argv[argc]; argc++) {
    80005382:	df043783          	ld	a5,-528(s0)
    80005386:	6388                	ld	a0,0(a5)
    80005388:	c925                	beqz	a0,800053f8 <exec+0x226>
    8000538a:	e9040993          	addi	s3,s0,-368
    8000538e:	f9040c93          	addi	s9,s0,-112
  sp = sz;
    80005392:	8962                	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    80005394:	4481                	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    80005396:	ffffc097          	auipc	ra,0xffffc
    8000539a:	d6c080e7          	jalr	-660(ra) # 80001102 <strlen>
    8000539e:	0015079b          	addiw	a5,a0,1
    800053a2:	40f90933          	sub	s2,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    800053a6:	ff097913          	andi	s2,s2,-16
    if(sp < stackbase)
    800053aa:	13596663          	bltu	s2,s5,800054d6 <exec+0x304>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    800053ae:	df043d83          	ld	s11,-528(s0)
    800053b2:	000dba03          	ld	s4,0(s11) # 1000 <_entry-0x7ffff000>
    800053b6:	8552                	mv	a0,s4
    800053b8:	ffffc097          	auipc	ra,0xffffc
    800053bc:	d4a080e7          	jalr	-694(ra) # 80001102 <strlen>
    800053c0:	0015069b          	addiw	a3,a0,1
    800053c4:	8652                	mv	a2,s4
    800053c6:	85ca                	mv	a1,s2
    800053c8:	855a                	mv	a0,s6
    800053ca:	ffffc097          	auipc	ra,0xffffc
    800053ce:	768080e7          	jalr	1896(ra) # 80001b32 <copyout>
    800053d2:	10054663          	bltz	a0,800054de <exec+0x30c>
    ustack[argc] = sp;
    800053d6:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    800053da:	0485                	addi	s1,s1,1
    800053dc:	008d8793          	addi	a5,s11,8
    800053e0:	def43823          	sd	a5,-528(s0)
    800053e4:	008db503          	ld	a0,8(s11)
    800053e8:	c911                	beqz	a0,800053fc <exec+0x22a>
    if(argc >= MAXARG)
    800053ea:	09a1                	addi	s3,s3,8
    800053ec:	fb3c95e3          	bne	s9,s3,80005396 <exec+0x1c4>
  sz = sz1;
    800053f0:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    800053f4:	4a81                	li	s5,0
    800053f6:	a84d                	j	800054a8 <exec+0x2d6>
  sp = sz;
    800053f8:	8962                	mv	s2,s8
  for(argc = 0; argv[argc]; argc++) {
    800053fa:	4481                	li	s1,0
  ustack[argc] = 0;
    800053fc:	00349793          	slli	a5,s1,0x3
    80005400:	f9040713          	addi	a4,s0,-112
    80005404:	97ba                	add	a5,a5,a4
    80005406:	f007b023          	sd	zero,-256(a5) # ffffffffffffef00 <end+0xffffffff7ffbcd60>
  sp -= (argc+1) * sizeof(uint64);
    8000540a:	00148693          	addi	a3,s1,1
    8000540e:	068e                	slli	a3,a3,0x3
    80005410:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    80005414:	ff097913          	andi	s2,s2,-16
  if(sp < stackbase)
    80005418:	01597663          	bgeu	s2,s5,80005424 <exec+0x252>
  sz = sz1;
    8000541c:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    80005420:	4a81                	li	s5,0
    80005422:	a059                	j	800054a8 <exec+0x2d6>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    80005424:	e9040613          	addi	a2,s0,-368
    80005428:	85ca                	mv	a1,s2
    8000542a:	855a                	mv	a0,s6
    8000542c:	ffffc097          	auipc	ra,0xffffc
    80005430:	706080e7          	jalr	1798(ra) # 80001b32 <copyout>
    80005434:	0a054963          	bltz	a0,800054e6 <exec+0x314>
  p->trapframe->a1 = sp;
    80005438:	058bb783          	ld	a5,88(s7) # 1058 <_entry-0x7fffefa8>
    8000543c:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    80005440:	de843783          	ld	a5,-536(s0)
    80005444:	0007c703          	lbu	a4,0(a5)
    80005448:	cf11                	beqz	a4,80005464 <exec+0x292>
    8000544a:	0785                	addi	a5,a5,1
    if(*s == '/')
    8000544c:	02f00693          	li	a3,47
    80005450:	a039                	j	8000545e <exec+0x28c>
      last = s+1;
    80005452:	def43423          	sd	a5,-536(s0)
  for(last=s=path; *s; s++)
    80005456:	0785                	addi	a5,a5,1
    80005458:	fff7c703          	lbu	a4,-1(a5)
    8000545c:	c701                	beqz	a4,80005464 <exec+0x292>
    if(*s == '/')
    8000545e:	fed71ce3          	bne	a4,a3,80005456 <exec+0x284>
    80005462:	bfc5                	j	80005452 <exec+0x280>
  safestrcpy(p->name, last, sizeof(p->name));
    80005464:	4641                	li	a2,16
    80005466:	de843583          	ld	a1,-536(s0)
    8000546a:	158b8513          	addi	a0,s7,344
    8000546e:	ffffc097          	auipc	ra,0xffffc
    80005472:	c62080e7          	jalr	-926(ra) # 800010d0 <safestrcpy>
  oldpagetable = p->pagetable;
    80005476:	050bb503          	ld	a0,80(s7)
  p->pagetable = pagetable;
    8000547a:	056bb823          	sd	s6,80(s7)
  p->sz = sz;
    8000547e:	058bb423          	sd	s8,72(s7)
  p->trapframe->epc = elf.entry;  // initial program counter = main
    80005482:	058bb783          	ld	a5,88(s7)
    80005486:	e6843703          	ld	a4,-408(s0)
    8000548a:	ef98                	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    8000548c:	058bb783          	ld	a5,88(s7)
    80005490:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    80005494:	85ea                	mv	a1,s10
    80005496:	ffffd097          	auipc	ra,0xffffd
    8000549a:	a48080e7          	jalr	-1464(ra) # 80001ede <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    8000549e:	0004851b          	sext.w	a0,s1
    800054a2:	b3f1                	j	8000526e <exec+0x9c>
    800054a4:	df243c23          	sd	s2,-520(s0)
    proc_freepagetable(pagetable, sz);
    800054a8:	df843583          	ld	a1,-520(s0)
    800054ac:	855a                	mv	a0,s6
    800054ae:	ffffd097          	auipc	ra,0xffffd
    800054b2:	a30080e7          	jalr	-1488(ra) # 80001ede <proc_freepagetable>
  if(ip){
    800054b6:	da0a92e3          	bnez	s5,8000525a <exec+0x88>
  return -1;
    800054ba:	557d                	li	a0,-1
    800054bc:	bb4d                	j	8000526e <exec+0x9c>
    800054be:	df243c23          	sd	s2,-520(s0)
    800054c2:	b7dd                	j	800054a8 <exec+0x2d6>
    800054c4:	df243c23          	sd	s2,-520(s0)
    800054c8:	b7c5                	j	800054a8 <exec+0x2d6>
    800054ca:	df243c23          	sd	s2,-520(s0)
    800054ce:	bfe9                	j	800054a8 <exec+0x2d6>
    800054d0:	df243c23          	sd	s2,-520(s0)
    800054d4:	bfd1                	j	800054a8 <exec+0x2d6>
  sz = sz1;
    800054d6:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    800054da:	4a81                	li	s5,0
    800054dc:	b7f1                	j	800054a8 <exec+0x2d6>
  sz = sz1;
    800054de:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    800054e2:	4a81                	li	s5,0
    800054e4:	b7d1                	j	800054a8 <exec+0x2d6>
  sz = sz1;
    800054e6:	df843c23          	sd	s8,-520(s0)
  ip = 0;
    800054ea:	4a81                	li	s5,0
    800054ec:	bf75                	j	800054a8 <exec+0x2d6>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz, flags2perm(ph.flags))) == 0)
    800054ee:	df843903          	ld	s2,-520(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    800054f2:	e0843783          	ld	a5,-504(s0)
    800054f6:	0017869b          	addiw	a3,a5,1
    800054fa:	e0d43423          	sd	a3,-504(s0)
    800054fe:	e0043783          	ld	a5,-512(s0)
    80005502:	0387879b          	addiw	a5,a5,56
    80005506:	e8845703          	lhu	a4,-376(s0)
    8000550a:	e0e6dee3          	bge	a3,a4,80005326 <exec+0x154>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    8000550e:	2781                	sext.w	a5,a5
    80005510:	e0f43023          	sd	a5,-512(s0)
    80005514:	03800713          	li	a4,56
    80005518:	86be                	mv	a3,a5
    8000551a:	e1840613          	addi	a2,s0,-488
    8000551e:	4581                	li	a1,0
    80005520:	8556                	mv	a0,s5
    80005522:	fffff097          	auipc	ra,0xfffff
    80005526:	a5c080e7          	jalr	-1444(ra) # 80003f7e <readi>
    8000552a:	03800793          	li	a5,56
    8000552e:	f6f51be3          	bne	a0,a5,800054a4 <exec+0x2d2>
    if(ph.type != ELF_PROG_LOAD)
    80005532:	e1842783          	lw	a5,-488(s0)
    80005536:	4705                	li	a4,1
    80005538:	fae79de3          	bne	a5,a4,800054f2 <exec+0x320>
    if(ph.memsz < ph.filesz)
    8000553c:	e4043483          	ld	s1,-448(s0)
    80005540:	e3843783          	ld	a5,-456(s0)
    80005544:	f6f4ede3          	bltu	s1,a5,800054be <exec+0x2ec>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80005548:	e2843783          	ld	a5,-472(s0)
    8000554c:	94be                	add	s1,s1,a5
    8000554e:	f6f4ebe3          	bltu	s1,a5,800054c4 <exec+0x2f2>
    if(ph.vaddr % PGSIZE != 0)
    80005552:	de043703          	ld	a4,-544(s0)
    80005556:	8ff9                	and	a5,a5,a4
    80005558:	fbad                	bnez	a5,800054ca <exec+0x2f8>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz, flags2perm(ph.flags))) == 0)
    8000555a:	e1c42503          	lw	a0,-484(s0)
    8000555e:	00000097          	auipc	ra,0x0
    80005562:	c58080e7          	jalr	-936(ra) # 800051b6 <flags2perm>
    80005566:	86aa                	mv	a3,a0
    80005568:	8626                	mv	a2,s1
    8000556a:	85ca                	mv	a1,s2
    8000556c:	855a                	mv	a0,s6
    8000556e:	ffffc097          	auipc	ra,0xffffc
    80005572:	156080e7          	jalr	342(ra) # 800016c4 <uvmalloc>
    80005576:	dea43c23          	sd	a0,-520(s0)
    8000557a:	d939                	beqz	a0,800054d0 <exec+0x2fe>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    8000557c:	e2843c03          	ld	s8,-472(s0)
    80005580:	e2042c83          	lw	s9,-480(s0)
    80005584:	e3842b83          	lw	s7,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    80005588:	f60b83e3          	beqz	s7,800054ee <exec+0x31c>
    8000558c:	89de                	mv	s3,s7
    8000558e:	4481                	li	s1,0
    80005590:	bb95                	j	80005304 <exec+0x132>

0000000080005592 <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    80005592:	7179                	addi	sp,sp,-48
    80005594:	f406                	sd	ra,40(sp)
    80005596:	f022                	sd	s0,32(sp)
    80005598:	ec26                	sd	s1,24(sp)
    8000559a:	e84a                	sd	s2,16(sp)
    8000559c:	1800                	addi	s0,sp,48
    8000559e:	892e                	mv	s2,a1
    800055a0:	84b2                	mv	s1,a2
  int fd;
  struct file *f;

  argint(n, &fd);
    800055a2:	fdc40593          	addi	a1,s0,-36
    800055a6:	ffffe097          	auipc	ra,0xffffe
    800055aa:	b1c080e7          	jalr	-1252(ra) # 800030c2 <argint>
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    800055ae:	fdc42703          	lw	a4,-36(s0)
    800055b2:	47bd                	li	a5,15
    800055b4:	02e7eb63          	bltu	a5,a4,800055ea <argfd+0x58>
    800055b8:	ffffc097          	auipc	ra,0xffffc
    800055bc:	7c6080e7          	jalr	1990(ra) # 80001d7e <myproc>
    800055c0:	fdc42703          	lw	a4,-36(s0)
    800055c4:	01a70793          	addi	a5,a4,26
    800055c8:	078e                	slli	a5,a5,0x3
    800055ca:	953e                	add	a0,a0,a5
    800055cc:	611c                	ld	a5,0(a0)
    800055ce:	c385                	beqz	a5,800055ee <argfd+0x5c>
    return -1;
  if(pfd)
    800055d0:	00090463          	beqz	s2,800055d8 <argfd+0x46>
    *pfd = fd;
    800055d4:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    800055d8:	4501                	li	a0,0
  if(pf)
    800055da:	c091                	beqz	s1,800055de <argfd+0x4c>
    *pf = f;
    800055dc:	e09c                	sd	a5,0(s1)
}
    800055de:	70a2                	ld	ra,40(sp)
    800055e0:	7402                	ld	s0,32(sp)
    800055e2:	64e2                	ld	s1,24(sp)
    800055e4:	6942                	ld	s2,16(sp)
    800055e6:	6145                	addi	sp,sp,48
    800055e8:	8082                	ret
    return -1;
    800055ea:	557d                	li	a0,-1
    800055ec:	bfcd                	j	800055de <argfd+0x4c>
    800055ee:	557d                	li	a0,-1
    800055f0:	b7fd                	j	800055de <argfd+0x4c>

00000000800055f2 <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    800055f2:	1101                	addi	sp,sp,-32
    800055f4:	ec06                	sd	ra,24(sp)
    800055f6:	e822                	sd	s0,16(sp)
    800055f8:	e426                	sd	s1,8(sp)
    800055fa:	1000                	addi	s0,sp,32
    800055fc:	84aa                	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    800055fe:	ffffc097          	auipc	ra,0xffffc
    80005602:	780080e7          	jalr	1920(ra) # 80001d7e <myproc>
    80005606:	862a                	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80005608:	0d050793          	addi	a5,a0,208
    8000560c:	4501                	li	a0,0
    8000560e:	46c1                	li	a3,16
    if(p->ofile[fd] == 0){
    80005610:	6398                	ld	a4,0(a5)
    80005612:	cb19                	beqz	a4,80005628 <fdalloc+0x36>
  for(fd = 0; fd < NOFILE; fd++){
    80005614:	2505                	addiw	a0,a0,1
    80005616:	07a1                	addi	a5,a5,8
    80005618:	fed51ce3          	bne	a0,a3,80005610 <fdalloc+0x1e>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    8000561c:	557d                	li	a0,-1
}
    8000561e:	60e2                	ld	ra,24(sp)
    80005620:	6442                	ld	s0,16(sp)
    80005622:	64a2                	ld	s1,8(sp)
    80005624:	6105                	addi	sp,sp,32
    80005626:	8082                	ret
      p->ofile[fd] = f;
    80005628:	01a50793          	addi	a5,a0,26
    8000562c:	078e                	slli	a5,a5,0x3
    8000562e:	963e                	add	a2,a2,a5
    80005630:	e204                	sd	s1,0(a2)
      return fd;
    80005632:	b7f5                	j	8000561e <fdalloc+0x2c>

0000000080005634 <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    80005634:	715d                	addi	sp,sp,-80
    80005636:	e486                	sd	ra,72(sp)
    80005638:	e0a2                	sd	s0,64(sp)
    8000563a:	fc26                	sd	s1,56(sp)
    8000563c:	f84a                	sd	s2,48(sp)
    8000563e:	f44e                	sd	s3,40(sp)
    80005640:	f052                	sd	s4,32(sp)
    80005642:	ec56                	sd	s5,24(sp)
    80005644:	e85a                	sd	s6,16(sp)
    80005646:	0880                	addi	s0,sp,80
    80005648:	8b2e                	mv	s6,a1
    8000564a:	89b2                	mv	s3,a2
    8000564c:	8936                	mv	s2,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    8000564e:	fb040593          	addi	a1,s0,-80
    80005652:	fffff097          	auipc	ra,0xfffff
    80005656:	e3c080e7          	jalr	-452(ra) # 8000448e <nameiparent>
    8000565a:	84aa                	mv	s1,a0
    8000565c:	14050f63          	beqz	a0,800057ba <create+0x186>
    return 0;

  ilock(dp);
    80005660:	ffffe097          	auipc	ra,0xffffe
    80005664:	66a080e7          	jalr	1642(ra) # 80003cca <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    80005668:	4601                	li	a2,0
    8000566a:	fb040593          	addi	a1,s0,-80
    8000566e:	8526                	mv	a0,s1
    80005670:	fffff097          	auipc	ra,0xfffff
    80005674:	b3e080e7          	jalr	-1218(ra) # 800041ae <dirlookup>
    80005678:	8aaa                	mv	s5,a0
    8000567a:	c931                	beqz	a0,800056ce <create+0x9a>
    iunlockput(dp);
    8000567c:	8526                	mv	a0,s1
    8000567e:	fffff097          	auipc	ra,0xfffff
    80005682:	8ae080e7          	jalr	-1874(ra) # 80003f2c <iunlockput>
    ilock(ip);
    80005686:	8556                	mv	a0,s5
    80005688:	ffffe097          	auipc	ra,0xffffe
    8000568c:	642080e7          	jalr	1602(ra) # 80003cca <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    80005690:	000b059b          	sext.w	a1,s6
    80005694:	4789                	li	a5,2
    80005696:	02f59563          	bne	a1,a5,800056c0 <create+0x8c>
    8000569a:	044ad783          	lhu	a5,68(s5) # fffffffffffff044 <end+0xffffffff7ffbcea4>
    8000569e:	37f9                	addiw	a5,a5,-2
    800056a0:	17c2                	slli	a5,a5,0x30
    800056a2:	93c1                	srli	a5,a5,0x30
    800056a4:	4705                	li	a4,1
    800056a6:	00f76d63          	bltu	a4,a5,800056c0 <create+0x8c>
  ip->nlink = 0;
  iupdate(ip);
  iunlockput(ip);
  iunlockput(dp);
  return 0;
}
    800056aa:	8556                	mv	a0,s5
    800056ac:	60a6                	ld	ra,72(sp)
    800056ae:	6406                	ld	s0,64(sp)
    800056b0:	74e2                	ld	s1,56(sp)
    800056b2:	7942                	ld	s2,48(sp)
    800056b4:	79a2                	ld	s3,40(sp)
    800056b6:	7a02                	ld	s4,32(sp)
    800056b8:	6ae2                	ld	s5,24(sp)
    800056ba:	6b42                	ld	s6,16(sp)
    800056bc:	6161                	addi	sp,sp,80
    800056be:	8082                	ret
    iunlockput(ip);
    800056c0:	8556                	mv	a0,s5
    800056c2:	fffff097          	auipc	ra,0xfffff
    800056c6:	86a080e7          	jalr	-1942(ra) # 80003f2c <iunlockput>
    return 0;
    800056ca:	4a81                	li	s5,0
    800056cc:	bff9                	j	800056aa <create+0x76>
  if((ip = ialloc(dp->dev, type)) == 0){
    800056ce:	85da                	mv	a1,s6
    800056d0:	4088                	lw	a0,0(s1)
    800056d2:	ffffe097          	auipc	ra,0xffffe
    800056d6:	45c080e7          	jalr	1116(ra) # 80003b2e <ialloc>
    800056da:	8a2a                	mv	s4,a0
    800056dc:	c539                	beqz	a0,8000572a <create+0xf6>
  ilock(ip);
    800056de:	ffffe097          	auipc	ra,0xffffe
    800056e2:	5ec080e7          	jalr	1516(ra) # 80003cca <ilock>
  ip->major = major;
    800056e6:	053a1323          	sh	s3,70(s4)
  ip->minor = minor;
    800056ea:	052a1423          	sh	s2,72(s4)
  ip->nlink = 1;
    800056ee:	4905                	li	s2,1
    800056f0:	052a1523          	sh	s2,74(s4)
  iupdate(ip);
    800056f4:	8552                	mv	a0,s4
    800056f6:	ffffe097          	auipc	ra,0xffffe
    800056fa:	50a080e7          	jalr	1290(ra) # 80003c00 <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    800056fe:	000b059b          	sext.w	a1,s6
    80005702:	03258b63          	beq	a1,s2,80005738 <create+0x104>
  if(dirlink(dp, name, ip->inum) < 0)
    80005706:	004a2603          	lw	a2,4(s4)
    8000570a:	fb040593          	addi	a1,s0,-80
    8000570e:	8526                	mv	a0,s1
    80005710:	fffff097          	auipc	ra,0xfffff
    80005714:	cae080e7          	jalr	-850(ra) # 800043be <dirlink>
    80005718:	06054f63          	bltz	a0,80005796 <create+0x162>
  iunlockput(dp);
    8000571c:	8526                	mv	a0,s1
    8000571e:	fffff097          	auipc	ra,0xfffff
    80005722:	80e080e7          	jalr	-2034(ra) # 80003f2c <iunlockput>
  return ip;
    80005726:	8ad2                	mv	s5,s4
    80005728:	b749                	j	800056aa <create+0x76>
    iunlockput(dp);
    8000572a:	8526                	mv	a0,s1
    8000572c:	fffff097          	auipc	ra,0xfffff
    80005730:	800080e7          	jalr	-2048(ra) # 80003f2c <iunlockput>
    return 0;
    80005734:	8ad2                	mv	s5,s4
    80005736:	bf95                	j	800056aa <create+0x76>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    80005738:	004a2603          	lw	a2,4(s4)
    8000573c:	00003597          	auipc	a1,0x3
    80005740:	00c58593          	addi	a1,a1,12 # 80008748 <syscalls+0x2a8>
    80005744:	8552                	mv	a0,s4
    80005746:	fffff097          	auipc	ra,0xfffff
    8000574a:	c78080e7          	jalr	-904(ra) # 800043be <dirlink>
    8000574e:	04054463          	bltz	a0,80005796 <create+0x162>
    80005752:	40d0                	lw	a2,4(s1)
    80005754:	00003597          	auipc	a1,0x3
    80005758:	ffc58593          	addi	a1,a1,-4 # 80008750 <syscalls+0x2b0>
    8000575c:	8552                	mv	a0,s4
    8000575e:	fffff097          	auipc	ra,0xfffff
    80005762:	c60080e7          	jalr	-928(ra) # 800043be <dirlink>
    80005766:	02054863          	bltz	a0,80005796 <create+0x162>
  if(dirlink(dp, name, ip->inum) < 0)
    8000576a:	004a2603          	lw	a2,4(s4)
    8000576e:	fb040593          	addi	a1,s0,-80
    80005772:	8526                	mv	a0,s1
    80005774:	fffff097          	auipc	ra,0xfffff
    80005778:	c4a080e7          	jalr	-950(ra) # 800043be <dirlink>
    8000577c:	00054d63          	bltz	a0,80005796 <create+0x162>
    dp->nlink++;  // for ".."
    80005780:	04a4d783          	lhu	a5,74(s1)
    80005784:	2785                	addiw	a5,a5,1
    80005786:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    8000578a:	8526                	mv	a0,s1
    8000578c:	ffffe097          	auipc	ra,0xffffe
    80005790:	474080e7          	jalr	1140(ra) # 80003c00 <iupdate>
    80005794:	b761                	j	8000571c <create+0xe8>
  ip->nlink = 0;
    80005796:	040a1523          	sh	zero,74(s4)
  iupdate(ip);
    8000579a:	8552                	mv	a0,s4
    8000579c:	ffffe097          	auipc	ra,0xffffe
    800057a0:	464080e7          	jalr	1124(ra) # 80003c00 <iupdate>
  iunlockput(ip);
    800057a4:	8552                	mv	a0,s4
    800057a6:	ffffe097          	auipc	ra,0xffffe
    800057aa:	786080e7          	jalr	1926(ra) # 80003f2c <iunlockput>
  iunlockput(dp);
    800057ae:	8526                	mv	a0,s1
    800057b0:	ffffe097          	auipc	ra,0xffffe
    800057b4:	77c080e7          	jalr	1916(ra) # 80003f2c <iunlockput>
  return 0;
    800057b8:	bdcd                	j	800056aa <create+0x76>
    return 0;
    800057ba:	8aaa                	mv	s5,a0
    800057bc:	b5fd                	j	800056aa <create+0x76>

00000000800057be <sys_dup>:
{
    800057be:	7179                	addi	sp,sp,-48
    800057c0:	f406                	sd	ra,40(sp)
    800057c2:	f022                	sd	s0,32(sp)
    800057c4:	ec26                	sd	s1,24(sp)
    800057c6:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    800057c8:	fd840613          	addi	a2,s0,-40
    800057cc:	4581                	li	a1,0
    800057ce:	4501                	li	a0,0
    800057d0:	00000097          	auipc	ra,0x0
    800057d4:	dc2080e7          	jalr	-574(ra) # 80005592 <argfd>
    return -1;
    800057d8:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    800057da:	02054363          	bltz	a0,80005800 <sys_dup+0x42>
  if((fd=fdalloc(f)) < 0)
    800057de:	fd843503          	ld	a0,-40(s0)
    800057e2:	00000097          	auipc	ra,0x0
    800057e6:	e10080e7          	jalr	-496(ra) # 800055f2 <fdalloc>
    800057ea:	84aa                	mv	s1,a0
    return -1;
    800057ec:	57fd                	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    800057ee:	00054963          	bltz	a0,80005800 <sys_dup+0x42>
  filedup(f);
    800057f2:	fd843503          	ld	a0,-40(s0)
    800057f6:	fffff097          	auipc	ra,0xfffff
    800057fa:	310080e7          	jalr	784(ra) # 80004b06 <filedup>
  return fd;
    800057fe:	87a6                	mv	a5,s1
}
    80005800:	853e                	mv	a0,a5
    80005802:	70a2                	ld	ra,40(sp)
    80005804:	7402                	ld	s0,32(sp)
    80005806:	64e2                	ld	s1,24(sp)
    80005808:	6145                	addi	sp,sp,48
    8000580a:	8082                	ret

000000008000580c <sys_read>:
{
    8000580c:	7179                	addi	sp,sp,-48
    8000580e:	f406                	sd	ra,40(sp)
    80005810:	f022                	sd	s0,32(sp)
    80005812:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80005814:	fd840593          	addi	a1,s0,-40
    80005818:	4505                	li	a0,1
    8000581a:	ffffe097          	auipc	ra,0xffffe
    8000581e:	8c8080e7          	jalr	-1848(ra) # 800030e2 <argaddr>
  argint(2, &n);
    80005822:	fe440593          	addi	a1,s0,-28
    80005826:	4509                	li	a0,2
    80005828:	ffffe097          	auipc	ra,0xffffe
    8000582c:	89a080e7          	jalr	-1894(ra) # 800030c2 <argint>
  if(argfd(0, 0, &f) < 0)
    80005830:	fe840613          	addi	a2,s0,-24
    80005834:	4581                	li	a1,0
    80005836:	4501                	li	a0,0
    80005838:	00000097          	auipc	ra,0x0
    8000583c:	d5a080e7          	jalr	-678(ra) # 80005592 <argfd>
    80005840:	87aa                	mv	a5,a0
    return -1;
    80005842:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005844:	0007cc63          	bltz	a5,8000585c <sys_read+0x50>
  return fileread(f, p, n);
    80005848:	fe442603          	lw	a2,-28(s0)
    8000584c:	fd843583          	ld	a1,-40(s0)
    80005850:	fe843503          	ld	a0,-24(s0)
    80005854:	fffff097          	auipc	ra,0xfffff
    80005858:	43e080e7          	jalr	1086(ra) # 80004c92 <fileread>
}
    8000585c:	70a2                	ld	ra,40(sp)
    8000585e:	7402                	ld	s0,32(sp)
    80005860:	6145                	addi	sp,sp,48
    80005862:	8082                	ret

0000000080005864 <sys_write>:
{
    80005864:	7179                	addi	sp,sp,-48
    80005866:	f406                	sd	ra,40(sp)
    80005868:	f022                	sd	s0,32(sp)
    8000586a:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    8000586c:	fd840593          	addi	a1,s0,-40
    80005870:	4505                	li	a0,1
    80005872:	ffffe097          	auipc	ra,0xffffe
    80005876:	870080e7          	jalr	-1936(ra) # 800030e2 <argaddr>
  argint(2, &n);
    8000587a:	fe440593          	addi	a1,s0,-28
    8000587e:	4509                	li	a0,2
    80005880:	ffffe097          	auipc	ra,0xffffe
    80005884:	842080e7          	jalr	-1982(ra) # 800030c2 <argint>
  if(argfd(0, 0, &f) < 0)
    80005888:	fe840613          	addi	a2,s0,-24
    8000588c:	4581                	li	a1,0
    8000588e:	4501                	li	a0,0
    80005890:	00000097          	auipc	ra,0x0
    80005894:	d02080e7          	jalr	-766(ra) # 80005592 <argfd>
    80005898:	87aa                	mv	a5,a0
    return -1;
    8000589a:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    8000589c:	0007cc63          	bltz	a5,800058b4 <sys_write+0x50>
  return filewrite(f, p, n);
    800058a0:	fe442603          	lw	a2,-28(s0)
    800058a4:	fd843583          	ld	a1,-40(s0)
    800058a8:	fe843503          	ld	a0,-24(s0)
    800058ac:	fffff097          	auipc	ra,0xfffff
    800058b0:	4a8080e7          	jalr	1192(ra) # 80004d54 <filewrite>
}
    800058b4:	70a2                	ld	ra,40(sp)
    800058b6:	7402                	ld	s0,32(sp)
    800058b8:	6145                	addi	sp,sp,48
    800058ba:	8082                	ret

00000000800058bc <sys_close>:
{
    800058bc:	1101                	addi	sp,sp,-32
    800058be:	ec06                	sd	ra,24(sp)
    800058c0:	e822                	sd	s0,16(sp)
    800058c2:	1000                	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    800058c4:	fe040613          	addi	a2,s0,-32
    800058c8:	fec40593          	addi	a1,s0,-20
    800058cc:	4501                	li	a0,0
    800058ce:	00000097          	auipc	ra,0x0
    800058d2:	cc4080e7          	jalr	-828(ra) # 80005592 <argfd>
    return -1;
    800058d6:	57fd                	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    800058d8:	02054463          	bltz	a0,80005900 <sys_close+0x44>
  myproc()->ofile[fd] = 0;
    800058dc:	ffffc097          	auipc	ra,0xffffc
    800058e0:	4a2080e7          	jalr	1186(ra) # 80001d7e <myproc>
    800058e4:	fec42783          	lw	a5,-20(s0)
    800058e8:	07e9                	addi	a5,a5,26
    800058ea:	078e                	slli	a5,a5,0x3
    800058ec:	97aa                	add	a5,a5,a0
    800058ee:	0007b023          	sd	zero,0(a5)
  fileclose(f);
    800058f2:	fe043503          	ld	a0,-32(s0)
    800058f6:	fffff097          	auipc	ra,0xfffff
    800058fa:	262080e7          	jalr	610(ra) # 80004b58 <fileclose>
  return 0;
    800058fe:	4781                	li	a5,0
}
    80005900:	853e                	mv	a0,a5
    80005902:	60e2                	ld	ra,24(sp)
    80005904:	6442                	ld	s0,16(sp)
    80005906:	6105                	addi	sp,sp,32
    80005908:	8082                	ret

000000008000590a <sys_fstat>:
{
    8000590a:	1101                	addi	sp,sp,-32
    8000590c:	ec06                	sd	ra,24(sp)
    8000590e:	e822                	sd	s0,16(sp)
    80005910:	1000                	addi	s0,sp,32
  argaddr(1, &st);
    80005912:	fe040593          	addi	a1,s0,-32
    80005916:	4505                	li	a0,1
    80005918:	ffffd097          	auipc	ra,0xffffd
    8000591c:	7ca080e7          	jalr	1994(ra) # 800030e2 <argaddr>
  if(argfd(0, 0, &f) < 0)
    80005920:	fe840613          	addi	a2,s0,-24
    80005924:	4581                	li	a1,0
    80005926:	4501                	li	a0,0
    80005928:	00000097          	auipc	ra,0x0
    8000592c:	c6a080e7          	jalr	-918(ra) # 80005592 <argfd>
    80005930:	87aa                	mv	a5,a0
    return -1;
    80005932:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80005934:	0007ca63          	bltz	a5,80005948 <sys_fstat+0x3e>
  return filestat(f, st);
    80005938:	fe043583          	ld	a1,-32(s0)
    8000593c:	fe843503          	ld	a0,-24(s0)
    80005940:	fffff097          	auipc	ra,0xfffff
    80005944:	2e0080e7          	jalr	736(ra) # 80004c20 <filestat>
}
    80005948:	60e2                	ld	ra,24(sp)
    8000594a:	6442                	ld	s0,16(sp)
    8000594c:	6105                	addi	sp,sp,32
    8000594e:	8082                	ret

0000000080005950 <sys_link>:
{
    80005950:	7169                	addi	sp,sp,-304
    80005952:	f606                	sd	ra,296(sp)
    80005954:	f222                	sd	s0,288(sp)
    80005956:	ee26                	sd	s1,280(sp)
    80005958:	ea4a                	sd	s2,272(sp)
    8000595a:	1a00                	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    8000595c:	08000613          	li	a2,128
    80005960:	ed040593          	addi	a1,s0,-304
    80005964:	4501                	li	a0,0
    80005966:	ffffd097          	auipc	ra,0xffffd
    8000596a:	79c080e7          	jalr	1948(ra) # 80003102 <argstr>
    return -1;
    8000596e:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005970:	10054e63          	bltz	a0,80005a8c <sys_link+0x13c>
    80005974:	08000613          	li	a2,128
    80005978:	f5040593          	addi	a1,s0,-176
    8000597c:	4505                	li	a0,1
    8000597e:	ffffd097          	auipc	ra,0xffffd
    80005982:	784080e7          	jalr	1924(ra) # 80003102 <argstr>
    return -1;
    80005986:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005988:	10054263          	bltz	a0,80005a8c <sys_link+0x13c>
  begin_op();
    8000598c:	fffff097          	auipc	ra,0xfffff
    80005990:	d00080e7          	jalr	-768(ra) # 8000468c <begin_op>
  if((ip = namei(old)) == 0){
    80005994:	ed040513          	addi	a0,s0,-304
    80005998:	fffff097          	auipc	ra,0xfffff
    8000599c:	ad8080e7          	jalr	-1320(ra) # 80004470 <namei>
    800059a0:	84aa                	mv	s1,a0
    800059a2:	c551                	beqz	a0,80005a2e <sys_link+0xde>
  ilock(ip);
    800059a4:	ffffe097          	auipc	ra,0xffffe
    800059a8:	326080e7          	jalr	806(ra) # 80003cca <ilock>
  if(ip->type == T_DIR){
    800059ac:	04449703          	lh	a4,68(s1)
    800059b0:	4785                	li	a5,1
    800059b2:	08f70463          	beq	a4,a5,80005a3a <sys_link+0xea>
  ip->nlink++;
    800059b6:	04a4d783          	lhu	a5,74(s1)
    800059ba:	2785                	addiw	a5,a5,1
    800059bc:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    800059c0:	8526                	mv	a0,s1
    800059c2:	ffffe097          	auipc	ra,0xffffe
    800059c6:	23e080e7          	jalr	574(ra) # 80003c00 <iupdate>
  iunlock(ip);
    800059ca:	8526                	mv	a0,s1
    800059cc:	ffffe097          	auipc	ra,0xffffe
    800059d0:	3c0080e7          	jalr	960(ra) # 80003d8c <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    800059d4:	fd040593          	addi	a1,s0,-48
    800059d8:	f5040513          	addi	a0,s0,-176
    800059dc:	fffff097          	auipc	ra,0xfffff
    800059e0:	ab2080e7          	jalr	-1358(ra) # 8000448e <nameiparent>
    800059e4:	892a                	mv	s2,a0
    800059e6:	c935                	beqz	a0,80005a5a <sys_link+0x10a>
  ilock(dp);
    800059e8:	ffffe097          	auipc	ra,0xffffe
    800059ec:	2e2080e7          	jalr	738(ra) # 80003cca <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    800059f0:	00092703          	lw	a4,0(s2)
    800059f4:	409c                	lw	a5,0(s1)
    800059f6:	04f71d63          	bne	a4,a5,80005a50 <sys_link+0x100>
    800059fa:	40d0                	lw	a2,4(s1)
    800059fc:	fd040593          	addi	a1,s0,-48
    80005a00:	854a                	mv	a0,s2
    80005a02:	fffff097          	auipc	ra,0xfffff
    80005a06:	9bc080e7          	jalr	-1604(ra) # 800043be <dirlink>
    80005a0a:	04054363          	bltz	a0,80005a50 <sys_link+0x100>
  iunlockput(dp);
    80005a0e:	854a                	mv	a0,s2
    80005a10:	ffffe097          	auipc	ra,0xffffe
    80005a14:	51c080e7          	jalr	1308(ra) # 80003f2c <iunlockput>
  iput(ip);
    80005a18:	8526                	mv	a0,s1
    80005a1a:	ffffe097          	auipc	ra,0xffffe
    80005a1e:	46a080e7          	jalr	1130(ra) # 80003e84 <iput>
  end_op();
    80005a22:	fffff097          	auipc	ra,0xfffff
    80005a26:	cea080e7          	jalr	-790(ra) # 8000470c <end_op>
  return 0;
    80005a2a:	4781                	li	a5,0
    80005a2c:	a085                	j	80005a8c <sys_link+0x13c>
    end_op();
    80005a2e:	fffff097          	auipc	ra,0xfffff
    80005a32:	cde080e7          	jalr	-802(ra) # 8000470c <end_op>
    return -1;
    80005a36:	57fd                	li	a5,-1
    80005a38:	a891                	j	80005a8c <sys_link+0x13c>
    iunlockput(ip);
    80005a3a:	8526                	mv	a0,s1
    80005a3c:	ffffe097          	auipc	ra,0xffffe
    80005a40:	4f0080e7          	jalr	1264(ra) # 80003f2c <iunlockput>
    end_op();
    80005a44:	fffff097          	auipc	ra,0xfffff
    80005a48:	cc8080e7          	jalr	-824(ra) # 8000470c <end_op>
    return -1;
    80005a4c:	57fd                	li	a5,-1
    80005a4e:	a83d                	j	80005a8c <sys_link+0x13c>
    iunlockput(dp);
    80005a50:	854a                	mv	a0,s2
    80005a52:	ffffe097          	auipc	ra,0xffffe
    80005a56:	4da080e7          	jalr	1242(ra) # 80003f2c <iunlockput>
  ilock(ip);
    80005a5a:	8526                	mv	a0,s1
    80005a5c:	ffffe097          	auipc	ra,0xffffe
    80005a60:	26e080e7          	jalr	622(ra) # 80003cca <ilock>
  ip->nlink--;
    80005a64:	04a4d783          	lhu	a5,74(s1)
    80005a68:	37fd                	addiw	a5,a5,-1
    80005a6a:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005a6e:	8526                	mv	a0,s1
    80005a70:	ffffe097          	auipc	ra,0xffffe
    80005a74:	190080e7          	jalr	400(ra) # 80003c00 <iupdate>
  iunlockput(ip);
    80005a78:	8526                	mv	a0,s1
    80005a7a:	ffffe097          	auipc	ra,0xffffe
    80005a7e:	4b2080e7          	jalr	1202(ra) # 80003f2c <iunlockput>
  end_op();
    80005a82:	fffff097          	auipc	ra,0xfffff
    80005a86:	c8a080e7          	jalr	-886(ra) # 8000470c <end_op>
  return -1;
    80005a8a:	57fd                	li	a5,-1
}
    80005a8c:	853e                	mv	a0,a5
    80005a8e:	70b2                	ld	ra,296(sp)
    80005a90:	7412                	ld	s0,288(sp)
    80005a92:	64f2                	ld	s1,280(sp)
    80005a94:	6952                	ld	s2,272(sp)
    80005a96:	6155                	addi	sp,sp,304
    80005a98:	8082                	ret

0000000080005a9a <sys_unlink>:
{
    80005a9a:	7151                	addi	sp,sp,-240
    80005a9c:	f586                	sd	ra,232(sp)
    80005a9e:	f1a2                	sd	s0,224(sp)
    80005aa0:	eda6                	sd	s1,216(sp)
    80005aa2:	e9ca                	sd	s2,208(sp)
    80005aa4:	e5ce                	sd	s3,200(sp)
    80005aa6:	1980                	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    80005aa8:	08000613          	li	a2,128
    80005aac:	f3040593          	addi	a1,s0,-208
    80005ab0:	4501                	li	a0,0
    80005ab2:	ffffd097          	auipc	ra,0xffffd
    80005ab6:	650080e7          	jalr	1616(ra) # 80003102 <argstr>
    80005aba:	18054163          	bltz	a0,80005c3c <sys_unlink+0x1a2>
  begin_op();
    80005abe:	fffff097          	auipc	ra,0xfffff
    80005ac2:	bce080e7          	jalr	-1074(ra) # 8000468c <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    80005ac6:	fb040593          	addi	a1,s0,-80
    80005aca:	f3040513          	addi	a0,s0,-208
    80005ace:	fffff097          	auipc	ra,0xfffff
    80005ad2:	9c0080e7          	jalr	-1600(ra) # 8000448e <nameiparent>
    80005ad6:	84aa                	mv	s1,a0
    80005ad8:	c979                	beqz	a0,80005bae <sys_unlink+0x114>
  ilock(dp);
    80005ada:	ffffe097          	auipc	ra,0xffffe
    80005ade:	1f0080e7          	jalr	496(ra) # 80003cca <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    80005ae2:	00003597          	auipc	a1,0x3
    80005ae6:	c6658593          	addi	a1,a1,-922 # 80008748 <syscalls+0x2a8>
    80005aea:	fb040513          	addi	a0,s0,-80
    80005aee:	ffffe097          	auipc	ra,0xffffe
    80005af2:	6a6080e7          	jalr	1702(ra) # 80004194 <namecmp>
    80005af6:	14050a63          	beqz	a0,80005c4a <sys_unlink+0x1b0>
    80005afa:	00003597          	auipc	a1,0x3
    80005afe:	c5658593          	addi	a1,a1,-938 # 80008750 <syscalls+0x2b0>
    80005b02:	fb040513          	addi	a0,s0,-80
    80005b06:	ffffe097          	auipc	ra,0xffffe
    80005b0a:	68e080e7          	jalr	1678(ra) # 80004194 <namecmp>
    80005b0e:	12050e63          	beqz	a0,80005c4a <sys_unlink+0x1b0>
  if((ip = dirlookup(dp, name, &off)) == 0)
    80005b12:	f2c40613          	addi	a2,s0,-212
    80005b16:	fb040593          	addi	a1,s0,-80
    80005b1a:	8526                	mv	a0,s1
    80005b1c:	ffffe097          	auipc	ra,0xffffe
    80005b20:	692080e7          	jalr	1682(ra) # 800041ae <dirlookup>
    80005b24:	892a                	mv	s2,a0
    80005b26:	12050263          	beqz	a0,80005c4a <sys_unlink+0x1b0>
  ilock(ip);
    80005b2a:	ffffe097          	auipc	ra,0xffffe
    80005b2e:	1a0080e7          	jalr	416(ra) # 80003cca <ilock>
  if(ip->nlink < 1)
    80005b32:	04a91783          	lh	a5,74(s2)
    80005b36:	08f05263          	blez	a5,80005bba <sys_unlink+0x120>
  if(ip->type == T_DIR && !isdirempty(ip)){
    80005b3a:	04491703          	lh	a4,68(s2)
    80005b3e:	4785                	li	a5,1
    80005b40:	08f70563          	beq	a4,a5,80005bca <sys_unlink+0x130>
  memset(&de, 0, sizeof(de));
    80005b44:	4641                	li	a2,16
    80005b46:	4581                	li	a1,0
    80005b48:	fc040513          	addi	a0,s0,-64
    80005b4c:	ffffb097          	auipc	ra,0xffffb
    80005b50:	43a080e7          	jalr	1082(ra) # 80000f86 <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005b54:	4741                	li	a4,16
    80005b56:	f2c42683          	lw	a3,-212(s0)
    80005b5a:	fc040613          	addi	a2,s0,-64
    80005b5e:	4581                	li	a1,0
    80005b60:	8526                	mv	a0,s1
    80005b62:	ffffe097          	auipc	ra,0xffffe
    80005b66:	514080e7          	jalr	1300(ra) # 80004076 <writei>
    80005b6a:	47c1                	li	a5,16
    80005b6c:	0af51563          	bne	a0,a5,80005c16 <sys_unlink+0x17c>
  if(ip->type == T_DIR){
    80005b70:	04491703          	lh	a4,68(s2)
    80005b74:	4785                	li	a5,1
    80005b76:	0af70863          	beq	a4,a5,80005c26 <sys_unlink+0x18c>
  iunlockput(dp);
    80005b7a:	8526                	mv	a0,s1
    80005b7c:	ffffe097          	auipc	ra,0xffffe
    80005b80:	3b0080e7          	jalr	944(ra) # 80003f2c <iunlockput>
  ip->nlink--;
    80005b84:	04a95783          	lhu	a5,74(s2)
    80005b88:	37fd                	addiw	a5,a5,-1
    80005b8a:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    80005b8e:	854a                	mv	a0,s2
    80005b90:	ffffe097          	auipc	ra,0xffffe
    80005b94:	070080e7          	jalr	112(ra) # 80003c00 <iupdate>
  iunlockput(ip);
    80005b98:	854a                	mv	a0,s2
    80005b9a:	ffffe097          	auipc	ra,0xffffe
    80005b9e:	392080e7          	jalr	914(ra) # 80003f2c <iunlockput>
  end_op();
    80005ba2:	fffff097          	auipc	ra,0xfffff
    80005ba6:	b6a080e7          	jalr	-1174(ra) # 8000470c <end_op>
  return 0;
    80005baa:	4501                	li	a0,0
    80005bac:	a84d                	j	80005c5e <sys_unlink+0x1c4>
    end_op();
    80005bae:	fffff097          	auipc	ra,0xfffff
    80005bb2:	b5e080e7          	jalr	-1186(ra) # 8000470c <end_op>
    return -1;
    80005bb6:	557d                	li	a0,-1
    80005bb8:	a05d                	j	80005c5e <sys_unlink+0x1c4>
    panic("unlink: nlink < 1");
    80005bba:	00003517          	auipc	a0,0x3
    80005bbe:	b9e50513          	addi	a0,a0,-1122 # 80008758 <syscalls+0x2b8>
    80005bc2:	ffffb097          	auipc	ra,0xffffb
    80005bc6:	97c080e7          	jalr	-1668(ra) # 8000053e <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005bca:	04c92703          	lw	a4,76(s2)
    80005bce:	02000793          	li	a5,32
    80005bd2:	f6e7f9e3          	bgeu	a5,a4,80005b44 <sys_unlink+0xaa>
    80005bd6:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005bda:	4741                	li	a4,16
    80005bdc:	86ce                	mv	a3,s3
    80005bde:	f1840613          	addi	a2,s0,-232
    80005be2:	4581                	li	a1,0
    80005be4:	854a                	mv	a0,s2
    80005be6:	ffffe097          	auipc	ra,0xffffe
    80005bea:	398080e7          	jalr	920(ra) # 80003f7e <readi>
    80005bee:	47c1                	li	a5,16
    80005bf0:	00f51b63          	bne	a0,a5,80005c06 <sys_unlink+0x16c>
    if(de.inum != 0)
    80005bf4:	f1845783          	lhu	a5,-232(s0)
    80005bf8:	e7a1                	bnez	a5,80005c40 <sys_unlink+0x1a6>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    80005bfa:	29c1                	addiw	s3,s3,16
    80005bfc:	04c92783          	lw	a5,76(s2)
    80005c00:	fcf9ede3          	bltu	s3,a5,80005bda <sys_unlink+0x140>
    80005c04:	b781                	j	80005b44 <sys_unlink+0xaa>
      panic("isdirempty: readi");
    80005c06:	00003517          	auipc	a0,0x3
    80005c0a:	b6a50513          	addi	a0,a0,-1174 # 80008770 <syscalls+0x2d0>
    80005c0e:	ffffb097          	auipc	ra,0xffffb
    80005c12:	930080e7          	jalr	-1744(ra) # 8000053e <panic>
    panic("unlink: writei");
    80005c16:	00003517          	auipc	a0,0x3
    80005c1a:	b7250513          	addi	a0,a0,-1166 # 80008788 <syscalls+0x2e8>
    80005c1e:	ffffb097          	auipc	ra,0xffffb
    80005c22:	920080e7          	jalr	-1760(ra) # 8000053e <panic>
    dp->nlink--;
    80005c26:	04a4d783          	lhu	a5,74(s1)
    80005c2a:	37fd                	addiw	a5,a5,-1
    80005c2c:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80005c30:	8526                	mv	a0,s1
    80005c32:	ffffe097          	auipc	ra,0xffffe
    80005c36:	fce080e7          	jalr	-50(ra) # 80003c00 <iupdate>
    80005c3a:	b781                	j	80005b7a <sys_unlink+0xe0>
    return -1;
    80005c3c:	557d                	li	a0,-1
    80005c3e:	a005                	j	80005c5e <sys_unlink+0x1c4>
    iunlockput(ip);
    80005c40:	854a                	mv	a0,s2
    80005c42:	ffffe097          	auipc	ra,0xffffe
    80005c46:	2ea080e7          	jalr	746(ra) # 80003f2c <iunlockput>
  iunlockput(dp);
    80005c4a:	8526                	mv	a0,s1
    80005c4c:	ffffe097          	auipc	ra,0xffffe
    80005c50:	2e0080e7          	jalr	736(ra) # 80003f2c <iunlockput>
  end_op();
    80005c54:	fffff097          	auipc	ra,0xfffff
    80005c58:	ab8080e7          	jalr	-1352(ra) # 8000470c <end_op>
  return -1;
    80005c5c:	557d                	li	a0,-1
}
    80005c5e:	70ae                	ld	ra,232(sp)
    80005c60:	740e                	ld	s0,224(sp)
    80005c62:	64ee                	ld	s1,216(sp)
    80005c64:	694e                	ld	s2,208(sp)
    80005c66:	69ae                	ld	s3,200(sp)
    80005c68:	616d                	addi	sp,sp,240
    80005c6a:	8082                	ret

0000000080005c6c <sys_open>:

uint64
sys_open(void)
{
    80005c6c:	7131                	addi	sp,sp,-192
    80005c6e:	fd06                	sd	ra,184(sp)
    80005c70:	f922                	sd	s0,176(sp)
    80005c72:	f526                	sd	s1,168(sp)
    80005c74:	f14a                	sd	s2,160(sp)
    80005c76:	ed4e                	sd	s3,152(sp)
    80005c78:	0180                	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  argint(1, &omode);
    80005c7a:	f4c40593          	addi	a1,s0,-180
    80005c7e:	4505                	li	a0,1
    80005c80:	ffffd097          	auipc	ra,0xffffd
    80005c84:	442080e7          	jalr	1090(ra) # 800030c2 <argint>
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005c88:	08000613          	li	a2,128
    80005c8c:	f5040593          	addi	a1,s0,-176
    80005c90:	4501                	li	a0,0
    80005c92:	ffffd097          	auipc	ra,0xffffd
    80005c96:	470080e7          	jalr	1136(ra) # 80003102 <argstr>
    80005c9a:	87aa                	mv	a5,a0
    return -1;
    80005c9c:	557d                	li	a0,-1
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005c9e:	0a07c963          	bltz	a5,80005d50 <sys_open+0xe4>

  begin_op();
    80005ca2:	fffff097          	auipc	ra,0xfffff
    80005ca6:	9ea080e7          	jalr	-1558(ra) # 8000468c <begin_op>

  if(omode & O_CREATE){
    80005caa:	f4c42783          	lw	a5,-180(s0)
    80005cae:	2007f793          	andi	a5,a5,512
    80005cb2:	cfc5                	beqz	a5,80005d6a <sys_open+0xfe>
    ip = create(path, T_FILE, 0, 0);
    80005cb4:	4681                	li	a3,0
    80005cb6:	4601                	li	a2,0
    80005cb8:	4589                	li	a1,2
    80005cba:	f5040513          	addi	a0,s0,-176
    80005cbe:	00000097          	auipc	ra,0x0
    80005cc2:	976080e7          	jalr	-1674(ra) # 80005634 <create>
    80005cc6:	84aa                	mv	s1,a0
    if(ip == 0){
    80005cc8:	c959                	beqz	a0,80005d5e <sys_open+0xf2>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    80005cca:	04449703          	lh	a4,68(s1)
    80005cce:	478d                	li	a5,3
    80005cd0:	00f71763          	bne	a4,a5,80005cde <sys_open+0x72>
    80005cd4:	0464d703          	lhu	a4,70(s1)
    80005cd8:	47a5                	li	a5,9
    80005cda:	0ce7ed63          	bltu	a5,a4,80005db4 <sys_open+0x148>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    80005cde:	fffff097          	auipc	ra,0xfffff
    80005ce2:	dbe080e7          	jalr	-578(ra) # 80004a9c <filealloc>
    80005ce6:	89aa                	mv	s3,a0
    80005ce8:	10050363          	beqz	a0,80005dee <sys_open+0x182>
    80005cec:	00000097          	auipc	ra,0x0
    80005cf0:	906080e7          	jalr	-1786(ra) # 800055f2 <fdalloc>
    80005cf4:	892a                	mv	s2,a0
    80005cf6:	0e054763          	bltz	a0,80005de4 <sys_open+0x178>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    80005cfa:	04449703          	lh	a4,68(s1)
    80005cfe:	478d                	li	a5,3
    80005d00:	0cf70563          	beq	a4,a5,80005dca <sys_open+0x15e>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    80005d04:	4789                	li	a5,2
    80005d06:	00f9a023          	sw	a5,0(s3)
    f->off = 0;
    80005d0a:	0209a023          	sw	zero,32(s3)
  }
  f->ip = ip;
    80005d0e:	0099bc23          	sd	s1,24(s3)
  f->readable = !(omode & O_WRONLY);
    80005d12:	f4c42783          	lw	a5,-180(s0)
    80005d16:	0017c713          	xori	a4,a5,1
    80005d1a:	8b05                	andi	a4,a4,1
    80005d1c:	00e98423          	sb	a4,8(s3)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    80005d20:	0037f713          	andi	a4,a5,3
    80005d24:	00e03733          	snez	a4,a4
    80005d28:	00e984a3          	sb	a4,9(s3)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    80005d2c:	4007f793          	andi	a5,a5,1024
    80005d30:	c791                	beqz	a5,80005d3c <sys_open+0xd0>
    80005d32:	04449703          	lh	a4,68(s1)
    80005d36:	4789                	li	a5,2
    80005d38:	0af70063          	beq	a4,a5,80005dd8 <sys_open+0x16c>
    itrunc(ip);
  }

  iunlock(ip);
    80005d3c:	8526                	mv	a0,s1
    80005d3e:	ffffe097          	auipc	ra,0xffffe
    80005d42:	04e080e7          	jalr	78(ra) # 80003d8c <iunlock>
  end_op();
    80005d46:	fffff097          	auipc	ra,0xfffff
    80005d4a:	9c6080e7          	jalr	-1594(ra) # 8000470c <end_op>

  return fd;
    80005d4e:	854a                	mv	a0,s2
}
    80005d50:	70ea                	ld	ra,184(sp)
    80005d52:	744a                	ld	s0,176(sp)
    80005d54:	74aa                	ld	s1,168(sp)
    80005d56:	790a                	ld	s2,160(sp)
    80005d58:	69ea                	ld	s3,152(sp)
    80005d5a:	6129                	addi	sp,sp,192
    80005d5c:	8082                	ret
      end_op();
    80005d5e:	fffff097          	auipc	ra,0xfffff
    80005d62:	9ae080e7          	jalr	-1618(ra) # 8000470c <end_op>
      return -1;
    80005d66:	557d                	li	a0,-1
    80005d68:	b7e5                	j	80005d50 <sys_open+0xe4>
    if((ip = namei(path)) == 0){
    80005d6a:	f5040513          	addi	a0,s0,-176
    80005d6e:	ffffe097          	auipc	ra,0xffffe
    80005d72:	702080e7          	jalr	1794(ra) # 80004470 <namei>
    80005d76:	84aa                	mv	s1,a0
    80005d78:	c905                	beqz	a0,80005da8 <sys_open+0x13c>
    ilock(ip);
    80005d7a:	ffffe097          	auipc	ra,0xffffe
    80005d7e:	f50080e7          	jalr	-176(ra) # 80003cca <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    80005d82:	04449703          	lh	a4,68(s1)
    80005d86:	4785                	li	a5,1
    80005d88:	f4f711e3          	bne	a4,a5,80005cca <sys_open+0x5e>
    80005d8c:	f4c42783          	lw	a5,-180(s0)
    80005d90:	d7b9                	beqz	a5,80005cde <sys_open+0x72>
      iunlockput(ip);
    80005d92:	8526                	mv	a0,s1
    80005d94:	ffffe097          	auipc	ra,0xffffe
    80005d98:	198080e7          	jalr	408(ra) # 80003f2c <iunlockput>
      end_op();
    80005d9c:	fffff097          	auipc	ra,0xfffff
    80005da0:	970080e7          	jalr	-1680(ra) # 8000470c <end_op>
      return -1;
    80005da4:	557d                	li	a0,-1
    80005da6:	b76d                	j	80005d50 <sys_open+0xe4>
      end_op();
    80005da8:	fffff097          	auipc	ra,0xfffff
    80005dac:	964080e7          	jalr	-1692(ra) # 8000470c <end_op>
      return -1;
    80005db0:	557d                	li	a0,-1
    80005db2:	bf79                	j	80005d50 <sys_open+0xe4>
    iunlockput(ip);
    80005db4:	8526                	mv	a0,s1
    80005db6:	ffffe097          	auipc	ra,0xffffe
    80005dba:	176080e7          	jalr	374(ra) # 80003f2c <iunlockput>
    end_op();
    80005dbe:	fffff097          	auipc	ra,0xfffff
    80005dc2:	94e080e7          	jalr	-1714(ra) # 8000470c <end_op>
    return -1;
    80005dc6:	557d                	li	a0,-1
    80005dc8:	b761                	j	80005d50 <sys_open+0xe4>
    f->type = FD_DEVICE;
    80005dca:	00f9a023          	sw	a5,0(s3)
    f->major = ip->major;
    80005dce:	04649783          	lh	a5,70(s1)
    80005dd2:	02f99223          	sh	a5,36(s3)
    80005dd6:	bf25                	j	80005d0e <sys_open+0xa2>
    itrunc(ip);
    80005dd8:	8526                	mv	a0,s1
    80005dda:	ffffe097          	auipc	ra,0xffffe
    80005dde:	ffe080e7          	jalr	-2(ra) # 80003dd8 <itrunc>
    80005de2:	bfa9                	j	80005d3c <sys_open+0xd0>
      fileclose(f);
    80005de4:	854e                	mv	a0,s3
    80005de6:	fffff097          	auipc	ra,0xfffff
    80005dea:	d72080e7          	jalr	-654(ra) # 80004b58 <fileclose>
    iunlockput(ip);
    80005dee:	8526                	mv	a0,s1
    80005df0:	ffffe097          	auipc	ra,0xffffe
    80005df4:	13c080e7          	jalr	316(ra) # 80003f2c <iunlockput>
    end_op();
    80005df8:	fffff097          	auipc	ra,0xfffff
    80005dfc:	914080e7          	jalr	-1772(ra) # 8000470c <end_op>
    return -1;
    80005e00:	557d                	li	a0,-1
    80005e02:	b7b9                	j	80005d50 <sys_open+0xe4>

0000000080005e04 <sys_mkdir>:

uint64
sys_mkdir(void)
{
    80005e04:	7175                	addi	sp,sp,-144
    80005e06:	e506                	sd	ra,136(sp)
    80005e08:	e122                	sd	s0,128(sp)
    80005e0a:	0900                	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    80005e0c:	fffff097          	auipc	ra,0xfffff
    80005e10:	880080e7          	jalr	-1920(ra) # 8000468c <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    80005e14:	08000613          	li	a2,128
    80005e18:	f7040593          	addi	a1,s0,-144
    80005e1c:	4501                	li	a0,0
    80005e1e:	ffffd097          	auipc	ra,0xffffd
    80005e22:	2e4080e7          	jalr	740(ra) # 80003102 <argstr>
    80005e26:	02054963          	bltz	a0,80005e58 <sys_mkdir+0x54>
    80005e2a:	4681                	li	a3,0
    80005e2c:	4601                	li	a2,0
    80005e2e:	4585                	li	a1,1
    80005e30:	f7040513          	addi	a0,s0,-144
    80005e34:	00000097          	auipc	ra,0x0
    80005e38:	800080e7          	jalr	-2048(ra) # 80005634 <create>
    80005e3c:	cd11                	beqz	a0,80005e58 <sys_mkdir+0x54>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005e3e:	ffffe097          	auipc	ra,0xffffe
    80005e42:	0ee080e7          	jalr	238(ra) # 80003f2c <iunlockput>
  end_op();
    80005e46:	fffff097          	auipc	ra,0xfffff
    80005e4a:	8c6080e7          	jalr	-1850(ra) # 8000470c <end_op>
  return 0;
    80005e4e:	4501                	li	a0,0
}
    80005e50:	60aa                	ld	ra,136(sp)
    80005e52:	640a                	ld	s0,128(sp)
    80005e54:	6149                	addi	sp,sp,144
    80005e56:	8082                	ret
    end_op();
    80005e58:	fffff097          	auipc	ra,0xfffff
    80005e5c:	8b4080e7          	jalr	-1868(ra) # 8000470c <end_op>
    return -1;
    80005e60:	557d                	li	a0,-1
    80005e62:	b7fd                	j	80005e50 <sys_mkdir+0x4c>

0000000080005e64 <sys_mknod>:

uint64
sys_mknod(void)
{
    80005e64:	7135                	addi	sp,sp,-160
    80005e66:	ed06                	sd	ra,152(sp)
    80005e68:	e922                	sd	s0,144(sp)
    80005e6a:	1100                	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    80005e6c:	fffff097          	auipc	ra,0xfffff
    80005e70:	820080e7          	jalr	-2016(ra) # 8000468c <begin_op>
  argint(1, &major);
    80005e74:	f6c40593          	addi	a1,s0,-148
    80005e78:	4505                	li	a0,1
    80005e7a:	ffffd097          	auipc	ra,0xffffd
    80005e7e:	248080e7          	jalr	584(ra) # 800030c2 <argint>
  argint(2, &minor);
    80005e82:	f6840593          	addi	a1,s0,-152
    80005e86:	4509                	li	a0,2
    80005e88:	ffffd097          	auipc	ra,0xffffd
    80005e8c:	23a080e7          	jalr	570(ra) # 800030c2 <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005e90:	08000613          	li	a2,128
    80005e94:	f7040593          	addi	a1,s0,-144
    80005e98:	4501                	li	a0,0
    80005e9a:	ffffd097          	auipc	ra,0xffffd
    80005e9e:	268080e7          	jalr	616(ra) # 80003102 <argstr>
    80005ea2:	02054b63          	bltz	a0,80005ed8 <sys_mknod+0x74>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    80005ea6:	f6841683          	lh	a3,-152(s0)
    80005eaa:	f6c41603          	lh	a2,-148(s0)
    80005eae:	458d                	li	a1,3
    80005eb0:	f7040513          	addi	a0,s0,-144
    80005eb4:	fffff097          	auipc	ra,0xfffff
    80005eb8:	780080e7          	jalr	1920(ra) # 80005634 <create>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005ebc:	cd11                	beqz	a0,80005ed8 <sys_mknod+0x74>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005ebe:	ffffe097          	auipc	ra,0xffffe
    80005ec2:	06e080e7          	jalr	110(ra) # 80003f2c <iunlockput>
  end_op();
    80005ec6:	fffff097          	auipc	ra,0xfffff
    80005eca:	846080e7          	jalr	-1978(ra) # 8000470c <end_op>
  return 0;
    80005ece:	4501                	li	a0,0
}
    80005ed0:	60ea                	ld	ra,152(sp)
    80005ed2:	644a                	ld	s0,144(sp)
    80005ed4:	610d                	addi	sp,sp,160
    80005ed6:	8082                	ret
    end_op();
    80005ed8:	fffff097          	auipc	ra,0xfffff
    80005edc:	834080e7          	jalr	-1996(ra) # 8000470c <end_op>
    return -1;
    80005ee0:	557d                	li	a0,-1
    80005ee2:	b7fd                	j	80005ed0 <sys_mknod+0x6c>

0000000080005ee4 <sys_chdir>:

uint64
sys_chdir(void)
{
    80005ee4:	7135                	addi	sp,sp,-160
    80005ee6:	ed06                	sd	ra,152(sp)
    80005ee8:	e922                	sd	s0,144(sp)
    80005eea:	e526                	sd	s1,136(sp)
    80005eec:	e14a                	sd	s2,128(sp)
    80005eee:	1100                	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    80005ef0:	ffffc097          	auipc	ra,0xffffc
    80005ef4:	e8e080e7          	jalr	-370(ra) # 80001d7e <myproc>
    80005ef8:	892a                	mv	s2,a0
  
  begin_op();
    80005efa:	ffffe097          	auipc	ra,0xffffe
    80005efe:	792080e7          	jalr	1938(ra) # 8000468c <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    80005f02:	08000613          	li	a2,128
    80005f06:	f6040593          	addi	a1,s0,-160
    80005f0a:	4501                	li	a0,0
    80005f0c:	ffffd097          	auipc	ra,0xffffd
    80005f10:	1f6080e7          	jalr	502(ra) # 80003102 <argstr>
    80005f14:	04054b63          	bltz	a0,80005f6a <sys_chdir+0x86>
    80005f18:	f6040513          	addi	a0,s0,-160
    80005f1c:	ffffe097          	auipc	ra,0xffffe
    80005f20:	554080e7          	jalr	1364(ra) # 80004470 <namei>
    80005f24:	84aa                	mv	s1,a0
    80005f26:	c131                	beqz	a0,80005f6a <sys_chdir+0x86>
    end_op();
    return -1;
  }
  ilock(ip);
    80005f28:	ffffe097          	auipc	ra,0xffffe
    80005f2c:	da2080e7          	jalr	-606(ra) # 80003cca <ilock>
  if(ip->type != T_DIR){
    80005f30:	04449703          	lh	a4,68(s1)
    80005f34:	4785                	li	a5,1
    80005f36:	04f71063          	bne	a4,a5,80005f76 <sys_chdir+0x92>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    80005f3a:	8526                	mv	a0,s1
    80005f3c:	ffffe097          	auipc	ra,0xffffe
    80005f40:	e50080e7          	jalr	-432(ra) # 80003d8c <iunlock>
  iput(p->cwd);
    80005f44:	15093503          	ld	a0,336(s2)
    80005f48:	ffffe097          	auipc	ra,0xffffe
    80005f4c:	f3c080e7          	jalr	-196(ra) # 80003e84 <iput>
  end_op();
    80005f50:	ffffe097          	auipc	ra,0xffffe
    80005f54:	7bc080e7          	jalr	1980(ra) # 8000470c <end_op>
  p->cwd = ip;
    80005f58:	14993823          	sd	s1,336(s2)
  return 0;
    80005f5c:	4501                	li	a0,0
}
    80005f5e:	60ea                	ld	ra,152(sp)
    80005f60:	644a                	ld	s0,144(sp)
    80005f62:	64aa                	ld	s1,136(sp)
    80005f64:	690a                	ld	s2,128(sp)
    80005f66:	610d                	addi	sp,sp,160
    80005f68:	8082                	ret
    end_op();
    80005f6a:	ffffe097          	auipc	ra,0xffffe
    80005f6e:	7a2080e7          	jalr	1954(ra) # 8000470c <end_op>
    return -1;
    80005f72:	557d                	li	a0,-1
    80005f74:	b7ed                	j	80005f5e <sys_chdir+0x7a>
    iunlockput(ip);
    80005f76:	8526                	mv	a0,s1
    80005f78:	ffffe097          	auipc	ra,0xffffe
    80005f7c:	fb4080e7          	jalr	-76(ra) # 80003f2c <iunlockput>
    end_op();
    80005f80:	ffffe097          	auipc	ra,0xffffe
    80005f84:	78c080e7          	jalr	1932(ra) # 8000470c <end_op>
    return -1;
    80005f88:	557d                	li	a0,-1
    80005f8a:	bfd1                	j	80005f5e <sys_chdir+0x7a>

0000000080005f8c <sys_exec>:

uint64
sys_exec(void)
{
    80005f8c:	7145                	addi	sp,sp,-464
    80005f8e:	e786                	sd	ra,456(sp)
    80005f90:	e3a2                	sd	s0,448(sp)
    80005f92:	ff26                	sd	s1,440(sp)
    80005f94:	fb4a                	sd	s2,432(sp)
    80005f96:	f74e                	sd	s3,424(sp)
    80005f98:	f352                	sd	s4,416(sp)
    80005f9a:	ef56                	sd	s5,408(sp)
    80005f9c:	0b80                	addi	s0,sp,464
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  argaddr(1, &uargv);
    80005f9e:	e3840593          	addi	a1,s0,-456
    80005fa2:	4505                	li	a0,1
    80005fa4:	ffffd097          	auipc	ra,0xffffd
    80005fa8:	13e080e7          	jalr	318(ra) # 800030e2 <argaddr>
  if(argstr(0, path, MAXPATH) < 0) {
    80005fac:	08000613          	li	a2,128
    80005fb0:	f4040593          	addi	a1,s0,-192
    80005fb4:	4501                	li	a0,0
    80005fb6:	ffffd097          	auipc	ra,0xffffd
    80005fba:	14c080e7          	jalr	332(ra) # 80003102 <argstr>
    80005fbe:	87aa                	mv	a5,a0
    return -1;
    80005fc0:	557d                	li	a0,-1
  if(argstr(0, path, MAXPATH) < 0) {
    80005fc2:	0c07c263          	bltz	a5,80006086 <sys_exec+0xfa>
  }
  memset(argv, 0, sizeof(argv));
    80005fc6:	10000613          	li	a2,256
    80005fca:	4581                	li	a1,0
    80005fcc:	e4040513          	addi	a0,s0,-448
    80005fd0:	ffffb097          	auipc	ra,0xffffb
    80005fd4:	fb6080e7          	jalr	-74(ra) # 80000f86 <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    80005fd8:	e4040493          	addi	s1,s0,-448
  memset(argv, 0, sizeof(argv));
    80005fdc:	89a6                	mv	s3,s1
    80005fde:	4901                	li	s2,0
    if(i >= NELEM(argv)){
    80005fe0:	02000a13          	li	s4,32
    80005fe4:	00090a9b          	sext.w	s5,s2
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    80005fe8:	00391793          	slli	a5,s2,0x3
    80005fec:	e3040593          	addi	a1,s0,-464
    80005ff0:	e3843503          	ld	a0,-456(s0)
    80005ff4:	953e                	add	a0,a0,a5
    80005ff6:	ffffd097          	auipc	ra,0xffffd
    80005ffa:	02e080e7          	jalr	46(ra) # 80003024 <fetchaddr>
    80005ffe:	02054a63          	bltz	a0,80006032 <sys_exec+0xa6>
      goto bad;
    }
    if(uarg == 0){
    80006002:	e3043783          	ld	a5,-464(s0)
    80006006:	c3b9                	beqz	a5,8000604c <sys_exec+0xc0>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    80006008:	ffffb097          	auipc	ra,0xffffb
    8000600c:	b38080e7          	jalr	-1224(ra) # 80000b40 <kalloc>
    80006010:	85aa                	mv	a1,a0
    80006012:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    80006016:	cd11                	beqz	a0,80006032 <sys_exec+0xa6>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    80006018:	6605                	lui	a2,0x1
    8000601a:	e3043503          	ld	a0,-464(s0)
    8000601e:	ffffd097          	auipc	ra,0xffffd
    80006022:	058080e7          	jalr	88(ra) # 80003076 <fetchstr>
    80006026:	00054663          	bltz	a0,80006032 <sys_exec+0xa6>
    if(i >= NELEM(argv)){
    8000602a:	0905                	addi	s2,s2,1
    8000602c:	09a1                	addi	s3,s3,8
    8000602e:	fb491be3          	bne	s2,s4,80005fe4 <sys_exec+0x58>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006032:	10048913          	addi	s2,s1,256
    80006036:	6088                	ld	a0,0(s1)
    80006038:	c531                	beqz	a0,80006084 <sys_exec+0xf8>
    kfree(argv[i]);
    8000603a:	ffffb097          	auipc	ra,0xffffb
    8000603e:	9b0080e7          	jalr	-1616(ra) # 800009ea <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80006042:	04a1                	addi	s1,s1,8
    80006044:	ff2499e3          	bne	s1,s2,80006036 <sys_exec+0xaa>
  return -1;
    80006048:	557d                	li	a0,-1
    8000604a:	a835                	j	80006086 <sys_exec+0xfa>
      argv[i] = 0;
    8000604c:	0a8e                	slli	s5,s5,0x3
    8000604e:	fc040793          	addi	a5,s0,-64
    80006052:	9abe                	add	s5,s5,a5
    80006054:	e80ab023          	sd	zero,-384(s5)
  int ret = exec(path, argv);
    80006058:	e4040593          	addi	a1,s0,-448
    8000605c:	f4040513          	addi	a0,s0,-192
    80006060:	fffff097          	auipc	ra,0xfffff
    80006064:	172080e7          	jalr	370(ra) # 800051d2 <exec>
    80006068:	892a                	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    8000606a:	10048993          	addi	s3,s1,256
    8000606e:	6088                	ld	a0,0(s1)
    80006070:	c901                	beqz	a0,80006080 <sys_exec+0xf4>
    kfree(argv[i]);
    80006072:	ffffb097          	auipc	ra,0xffffb
    80006076:	978080e7          	jalr	-1672(ra) # 800009ea <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    8000607a:	04a1                	addi	s1,s1,8
    8000607c:	ff3499e3          	bne	s1,s3,8000606e <sys_exec+0xe2>
  return ret;
    80006080:	854a                	mv	a0,s2
    80006082:	a011                	j	80006086 <sys_exec+0xfa>
  return -1;
    80006084:	557d                	li	a0,-1
}
    80006086:	60be                	ld	ra,456(sp)
    80006088:	641e                	ld	s0,448(sp)
    8000608a:	74fa                	ld	s1,440(sp)
    8000608c:	795a                	ld	s2,432(sp)
    8000608e:	79ba                	ld	s3,424(sp)
    80006090:	7a1a                	ld	s4,416(sp)
    80006092:	6afa                	ld	s5,408(sp)
    80006094:	6179                	addi	sp,sp,464
    80006096:	8082                	ret

0000000080006098 <sys_pipe>:

uint64
sys_pipe(void)
{
    80006098:	7139                	addi	sp,sp,-64
    8000609a:	fc06                	sd	ra,56(sp)
    8000609c:	f822                	sd	s0,48(sp)
    8000609e:	f426                	sd	s1,40(sp)
    800060a0:	0080                	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    800060a2:	ffffc097          	auipc	ra,0xffffc
    800060a6:	cdc080e7          	jalr	-804(ra) # 80001d7e <myproc>
    800060aa:	84aa                	mv	s1,a0

  argaddr(0, &fdarray);
    800060ac:	fd840593          	addi	a1,s0,-40
    800060b0:	4501                	li	a0,0
    800060b2:	ffffd097          	auipc	ra,0xffffd
    800060b6:	030080e7          	jalr	48(ra) # 800030e2 <argaddr>
  if(pipealloc(&rf, &wf) < 0)
    800060ba:	fc840593          	addi	a1,s0,-56
    800060be:	fd040513          	addi	a0,s0,-48
    800060c2:	fffff097          	auipc	ra,0xfffff
    800060c6:	dc6080e7          	jalr	-570(ra) # 80004e88 <pipealloc>
    return -1;
    800060ca:	57fd                	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    800060cc:	0c054463          	bltz	a0,80006194 <sys_pipe+0xfc>
  fd0 = -1;
    800060d0:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    800060d4:	fd043503          	ld	a0,-48(s0)
    800060d8:	fffff097          	auipc	ra,0xfffff
    800060dc:	51a080e7          	jalr	1306(ra) # 800055f2 <fdalloc>
    800060e0:	fca42223          	sw	a0,-60(s0)
    800060e4:	08054b63          	bltz	a0,8000617a <sys_pipe+0xe2>
    800060e8:	fc843503          	ld	a0,-56(s0)
    800060ec:	fffff097          	auipc	ra,0xfffff
    800060f0:	506080e7          	jalr	1286(ra) # 800055f2 <fdalloc>
    800060f4:	fca42023          	sw	a0,-64(s0)
    800060f8:	06054863          	bltz	a0,80006168 <sys_pipe+0xd0>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    800060fc:	4691                	li	a3,4
    800060fe:	fc440613          	addi	a2,s0,-60
    80006102:	fd843583          	ld	a1,-40(s0)
    80006106:	68a8                	ld	a0,80(s1)
    80006108:	ffffc097          	auipc	ra,0xffffc
    8000610c:	a2a080e7          	jalr	-1494(ra) # 80001b32 <copyout>
    80006110:	02054063          	bltz	a0,80006130 <sys_pipe+0x98>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    80006114:	4691                	li	a3,4
    80006116:	fc040613          	addi	a2,s0,-64
    8000611a:	fd843583          	ld	a1,-40(s0)
    8000611e:	0591                	addi	a1,a1,4
    80006120:	68a8                	ld	a0,80(s1)
    80006122:	ffffc097          	auipc	ra,0xffffc
    80006126:	a10080e7          	jalr	-1520(ra) # 80001b32 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    8000612a:	4781                	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    8000612c:	06055463          	bgez	a0,80006194 <sys_pipe+0xfc>
    p->ofile[fd0] = 0;
    80006130:	fc442783          	lw	a5,-60(s0)
    80006134:	07e9                	addi	a5,a5,26
    80006136:	078e                	slli	a5,a5,0x3
    80006138:	97a6                	add	a5,a5,s1
    8000613a:	0007b023          	sd	zero,0(a5)
    p->ofile[fd1] = 0;
    8000613e:	fc042503          	lw	a0,-64(s0)
    80006142:	0569                	addi	a0,a0,26
    80006144:	050e                	slli	a0,a0,0x3
    80006146:	94aa                	add	s1,s1,a0
    80006148:	0004b023          	sd	zero,0(s1)
    fileclose(rf);
    8000614c:	fd043503          	ld	a0,-48(s0)
    80006150:	fffff097          	auipc	ra,0xfffff
    80006154:	a08080e7          	jalr	-1528(ra) # 80004b58 <fileclose>
    fileclose(wf);
    80006158:	fc843503          	ld	a0,-56(s0)
    8000615c:	fffff097          	auipc	ra,0xfffff
    80006160:	9fc080e7          	jalr	-1540(ra) # 80004b58 <fileclose>
    return -1;
    80006164:	57fd                	li	a5,-1
    80006166:	a03d                	j	80006194 <sys_pipe+0xfc>
    if(fd0 >= 0)
    80006168:	fc442783          	lw	a5,-60(s0)
    8000616c:	0007c763          	bltz	a5,8000617a <sys_pipe+0xe2>
      p->ofile[fd0] = 0;
    80006170:	07e9                	addi	a5,a5,26
    80006172:	078e                	slli	a5,a5,0x3
    80006174:	94be                	add	s1,s1,a5
    80006176:	0004b023          	sd	zero,0(s1)
    fileclose(rf);
    8000617a:	fd043503          	ld	a0,-48(s0)
    8000617e:	fffff097          	auipc	ra,0xfffff
    80006182:	9da080e7          	jalr	-1574(ra) # 80004b58 <fileclose>
    fileclose(wf);
    80006186:	fc843503          	ld	a0,-56(s0)
    8000618a:	fffff097          	auipc	ra,0xfffff
    8000618e:	9ce080e7          	jalr	-1586(ra) # 80004b58 <fileclose>
    return -1;
    80006192:	57fd                	li	a5,-1
}
    80006194:	853e                	mv	a0,a5
    80006196:	70e2                	ld	ra,56(sp)
    80006198:	7442                	ld	s0,48(sp)
    8000619a:	74a2                	ld	s1,40(sp)
    8000619c:	6121                	addi	sp,sp,64
    8000619e:	8082                	ret

00000000800061a0 <kernelvec>:
    800061a0:	7111                	addi	sp,sp,-256
    800061a2:	e006                	sd	ra,0(sp)
    800061a4:	e40a                	sd	sp,8(sp)
    800061a6:	e80e                	sd	gp,16(sp)
    800061a8:	ec12                	sd	tp,24(sp)
    800061aa:	f016                	sd	t0,32(sp)
    800061ac:	f41a                	sd	t1,40(sp)
    800061ae:	f81e                	sd	t2,48(sp)
    800061b0:	fc22                	sd	s0,56(sp)
    800061b2:	e0a6                	sd	s1,64(sp)
    800061b4:	e4aa                	sd	a0,72(sp)
    800061b6:	e8ae                	sd	a1,80(sp)
    800061b8:	ecb2                	sd	a2,88(sp)
    800061ba:	f0b6                	sd	a3,96(sp)
    800061bc:	f4ba                	sd	a4,104(sp)
    800061be:	f8be                	sd	a5,112(sp)
    800061c0:	fcc2                	sd	a6,120(sp)
    800061c2:	e146                	sd	a7,128(sp)
    800061c4:	e54a                	sd	s2,136(sp)
    800061c6:	e94e                	sd	s3,144(sp)
    800061c8:	ed52                	sd	s4,152(sp)
    800061ca:	f156                	sd	s5,160(sp)
    800061cc:	f55a                	sd	s6,168(sp)
    800061ce:	f95e                	sd	s7,176(sp)
    800061d0:	fd62                	sd	s8,184(sp)
    800061d2:	e1e6                	sd	s9,192(sp)
    800061d4:	e5ea                	sd	s10,200(sp)
    800061d6:	e9ee                	sd	s11,208(sp)
    800061d8:	edf2                	sd	t3,216(sp)
    800061da:	f1f6                	sd	t4,224(sp)
    800061dc:	f5fa                	sd	t5,232(sp)
    800061de:	f9fe                	sd	t6,240(sp)
    800061e0:	d11fc0ef          	jal	ra,80002ef0 <kerneltrap>
    800061e4:	6082                	ld	ra,0(sp)
    800061e6:	6122                	ld	sp,8(sp)
    800061e8:	61c2                	ld	gp,16(sp)
    800061ea:	7282                	ld	t0,32(sp)
    800061ec:	7322                	ld	t1,40(sp)
    800061ee:	73c2                	ld	t2,48(sp)
    800061f0:	7462                	ld	s0,56(sp)
    800061f2:	6486                	ld	s1,64(sp)
    800061f4:	6526                	ld	a0,72(sp)
    800061f6:	65c6                	ld	a1,80(sp)
    800061f8:	6666                	ld	a2,88(sp)
    800061fa:	7686                	ld	a3,96(sp)
    800061fc:	7726                	ld	a4,104(sp)
    800061fe:	77c6                	ld	a5,112(sp)
    80006200:	7866                	ld	a6,120(sp)
    80006202:	688a                	ld	a7,128(sp)
    80006204:	692a                	ld	s2,136(sp)
    80006206:	69ca                	ld	s3,144(sp)
    80006208:	6a6a                	ld	s4,152(sp)
    8000620a:	7a8a                	ld	s5,160(sp)
    8000620c:	7b2a                	ld	s6,168(sp)
    8000620e:	7bca                	ld	s7,176(sp)
    80006210:	7c6a                	ld	s8,184(sp)
    80006212:	6c8e                	ld	s9,192(sp)
    80006214:	6d2e                	ld	s10,200(sp)
    80006216:	6dce                	ld	s11,208(sp)
    80006218:	6e6e                	ld	t3,216(sp)
    8000621a:	7e8e                	ld	t4,224(sp)
    8000621c:	7f2e                	ld	t5,232(sp)
    8000621e:	7fce                	ld	t6,240(sp)
    80006220:	6111                	addi	sp,sp,256
    80006222:	10200073          	sret
    80006226:	00000013          	nop
    8000622a:	00000013          	nop
    8000622e:	0001                	nop

0000000080006230 <timervec>:
    80006230:	34051573          	csrrw	a0,mscratch,a0
    80006234:	e10c                	sd	a1,0(a0)
    80006236:	e510                	sd	a2,8(a0)
    80006238:	e914                	sd	a3,16(a0)
    8000623a:	6d0c                	ld	a1,24(a0)
    8000623c:	7110                	ld	a2,32(a0)
    8000623e:	6194                	ld	a3,0(a1)
    80006240:	96b2                	add	a3,a3,a2
    80006242:	e194                	sd	a3,0(a1)
    80006244:	4589                	li	a1,2
    80006246:	14459073          	csrw	sip,a1
    8000624a:	6914                	ld	a3,16(a0)
    8000624c:	6510                	ld	a2,8(a0)
    8000624e:	610c                	ld	a1,0(a0)
    80006250:	34051573          	csrrw	a0,mscratch,a0
    80006254:	30200073          	mret
	...

000000008000625a <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    8000625a:	1141                	addi	sp,sp,-16
    8000625c:	e422                	sd	s0,8(sp)
    8000625e:	0800                	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    80006260:	0c0007b7          	lui	a5,0xc000
    80006264:	4705                	li	a4,1
    80006266:	d798                	sw	a4,40(a5)
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    80006268:	c3d8                	sw	a4,4(a5)
}
    8000626a:	6422                	ld	s0,8(sp)
    8000626c:	0141                	addi	sp,sp,16
    8000626e:	8082                	ret

0000000080006270 <plicinithart>:

void
plicinithart(void)
{
    80006270:	1141                	addi	sp,sp,-16
    80006272:	e406                	sd	ra,8(sp)
    80006274:	e022                	sd	s0,0(sp)
    80006276:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80006278:	ffffc097          	auipc	ra,0xffffc
    8000627c:	ada080e7          	jalr	-1318(ra) # 80001d52 <cpuid>
  
  // set enable bits for this hart's S-mode
  // for the uart and virtio disk.
  *(uint32*)PLIC_SENABLE(hart) = (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    80006280:	0085171b          	slliw	a4,a0,0x8
    80006284:	0c0027b7          	lui	a5,0xc002
    80006288:	97ba                	add	a5,a5,a4
    8000628a:	40200713          	li	a4,1026
    8000628e:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    80006292:	00d5151b          	slliw	a0,a0,0xd
    80006296:	0c2017b7          	lui	a5,0xc201
    8000629a:	953e                	add	a0,a0,a5
    8000629c:	00052023          	sw	zero,0(a0)
}
    800062a0:	60a2                	ld	ra,8(sp)
    800062a2:	6402                	ld	s0,0(sp)
    800062a4:	0141                	addi	sp,sp,16
    800062a6:	8082                	ret

00000000800062a8 <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    800062a8:	1141                	addi	sp,sp,-16
    800062aa:	e406                	sd	ra,8(sp)
    800062ac:	e022                	sd	s0,0(sp)
    800062ae:	0800                	addi	s0,sp,16
  int hart = cpuid();
    800062b0:	ffffc097          	auipc	ra,0xffffc
    800062b4:	aa2080e7          	jalr	-1374(ra) # 80001d52 <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    800062b8:	00d5179b          	slliw	a5,a0,0xd
    800062bc:	0c201537          	lui	a0,0xc201
    800062c0:	953e                	add	a0,a0,a5
  return irq;
}
    800062c2:	4148                	lw	a0,4(a0)
    800062c4:	60a2                	ld	ra,8(sp)
    800062c6:	6402                	ld	s0,0(sp)
    800062c8:	0141                	addi	sp,sp,16
    800062ca:	8082                	ret

00000000800062cc <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    800062cc:	1101                	addi	sp,sp,-32
    800062ce:	ec06                	sd	ra,24(sp)
    800062d0:	e822                	sd	s0,16(sp)
    800062d2:	e426                	sd	s1,8(sp)
    800062d4:	1000                	addi	s0,sp,32
    800062d6:	84aa                	mv	s1,a0
  int hart = cpuid();
    800062d8:	ffffc097          	auipc	ra,0xffffc
    800062dc:	a7a080e7          	jalr	-1414(ra) # 80001d52 <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    800062e0:	00d5151b          	slliw	a0,a0,0xd
    800062e4:	0c2017b7          	lui	a5,0xc201
    800062e8:	97aa                	add	a5,a5,a0
    800062ea:	c3c4                	sw	s1,4(a5)
}
    800062ec:	60e2                	ld	ra,24(sp)
    800062ee:	6442                	ld	s0,16(sp)
    800062f0:	64a2                	ld	s1,8(sp)
    800062f2:	6105                	addi	sp,sp,32
    800062f4:	8082                	ret

00000000800062f6 <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    800062f6:	1141                	addi	sp,sp,-16
    800062f8:	e406                	sd	ra,8(sp)
    800062fa:	e022                	sd	s0,0(sp)
    800062fc:	0800                	addi	s0,sp,16
  if(i >= NUM)
    800062fe:	479d                	li	a5,7
    80006300:	04a7cc63          	blt	a5,a0,80006358 <free_desc+0x62>
    panic("free_desc 1");
  if(disk.free[i])
    80006304:	0003c797          	auipc	a5,0x3c
    80006308:	d5c78793          	addi	a5,a5,-676 # 80042060 <disk>
    8000630c:	97aa                	add	a5,a5,a0
    8000630e:	0187c783          	lbu	a5,24(a5)
    80006312:	ebb9                	bnez	a5,80006368 <free_desc+0x72>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    80006314:	00451613          	slli	a2,a0,0x4
    80006318:	0003c797          	auipc	a5,0x3c
    8000631c:	d4878793          	addi	a5,a5,-696 # 80042060 <disk>
    80006320:	6394                	ld	a3,0(a5)
    80006322:	96b2                	add	a3,a3,a2
    80006324:	0006b023          	sd	zero,0(a3)
  disk.desc[i].len = 0;
    80006328:	6398                	ld	a4,0(a5)
    8000632a:	9732                	add	a4,a4,a2
    8000632c:	00072423          	sw	zero,8(a4)
  disk.desc[i].flags = 0;
    80006330:	00071623          	sh	zero,12(a4)
  disk.desc[i].next = 0;
    80006334:	00071723          	sh	zero,14(a4)
  disk.free[i] = 1;
    80006338:	953e                	add	a0,a0,a5
    8000633a:	4785                	li	a5,1
    8000633c:	00f50c23          	sb	a5,24(a0) # c201018 <_entry-0x73dfefe8>
  wakeup(&disk.free[0]);
    80006340:	0003c517          	auipc	a0,0x3c
    80006344:	d3850513          	addi	a0,a0,-712 # 80042078 <disk+0x18>
    80006348:	ffffc097          	auipc	ra,0xffffc
    8000634c:	156080e7          	jalr	342(ra) # 8000249e <wakeup>
}
    80006350:	60a2                	ld	ra,8(sp)
    80006352:	6402                	ld	s0,0(sp)
    80006354:	0141                	addi	sp,sp,16
    80006356:	8082                	ret
    panic("free_desc 1");
    80006358:	00002517          	auipc	a0,0x2
    8000635c:	44050513          	addi	a0,a0,1088 # 80008798 <syscalls+0x2f8>
    80006360:	ffffa097          	auipc	ra,0xffffa
    80006364:	1de080e7          	jalr	478(ra) # 8000053e <panic>
    panic("free_desc 2");
    80006368:	00002517          	auipc	a0,0x2
    8000636c:	44050513          	addi	a0,a0,1088 # 800087a8 <syscalls+0x308>
    80006370:	ffffa097          	auipc	ra,0xffffa
    80006374:	1ce080e7          	jalr	462(ra) # 8000053e <panic>

0000000080006378 <virtio_disk_init>:
{
    80006378:	1101                	addi	sp,sp,-32
    8000637a:	ec06                	sd	ra,24(sp)
    8000637c:	e822                	sd	s0,16(sp)
    8000637e:	e426                	sd	s1,8(sp)
    80006380:	e04a                	sd	s2,0(sp)
    80006382:	1000                	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    80006384:	00002597          	auipc	a1,0x2
    80006388:	43458593          	addi	a1,a1,1076 # 800087b8 <syscalls+0x318>
    8000638c:	0003c517          	auipc	a0,0x3c
    80006390:	dfc50513          	addi	a0,a0,-516 # 80042188 <disk+0x128>
    80006394:	ffffb097          	auipc	ra,0xffffb
    80006398:	a66080e7          	jalr	-1434(ra) # 80000dfa <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    8000639c:	100017b7          	lui	a5,0x10001
    800063a0:	4398                	lw	a4,0(a5)
    800063a2:	2701                	sext.w	a4,a4
    800063a4:	747277b7          	lui	a5,0x74727
    800063a8:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    800063ac:	14f71c63          	bne	a4,a5,80006504 <virtio_disk_init+0x18c>
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    800063b0:	100017b7          	lui	a5,0x10001
    800063b4:	43dc                	lw	a5,4(a5)
    800063b6:	2781                	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    800063b8:	4709                	li	a4,2
    800063ba:	14e79563          	bne	a5,a4,80006504 <virtio_disk_init+0x18c>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    800063be:	100017b7          	lui	a5,0x10001
    800063c2:	479c                	lw	a5,8(a5)
    800063c4:	2781                	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    800063c6:	12e79f63          	bne	a5,a4,80006504 <virtio_disk_init+0x18c>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    800063ca:	100017b7          	lui	a5,0x10001
    800063ce:	47d8                	lw	a4,12(a5)
    800063d0:	2701                	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    800063d2:	554d47b7          	lui	a5,0x554d4
    800063d6:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    800063da:	12f71563          	bne	a4,a5,80006504 <virtio_disk_init+0x18c>
  *R(VIRTIO_MMIO_STATUS) = status;
    800063de:	100017b7          	lui	a5,0x10001
    800063e2:	0607a823          	sw	zero,112(a5) # 10001070 <_entry-0x6fffef90>
  *R(VIRTIO_MMIO_STATUS) = status;
    800063e6:	4705                	li	a4,1
    800063e8:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800063ea:	470d                	li	a4,3
    800063ec:	dbb8                	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    800063ee:	4b94                	lw	a3,16(a5)
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
    800063f0:	c7ffe737          	lui	a4,0xc7ffe
    800063f4:	75f70713          	addi	a4,a4,1887 # ffffffffc7ffe75f <end+0xffffffff47fbc5bf>
    800063f8:	8f75                	and	a4,a4,a3
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    800063fa:	2701                	sext.w	a4,a4
    800063fc:	d398                	sw	a4,32(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800063fe:	472d                	li	a4,11
    80006400:	dbb8                	sw	a4,112(a5)
  status = *R(VIRTIO_MMIO_STATUS);
    80006402:	5bbc                	lw	a5,112(a5)
    80006404:	0007891b          	sext.w	s2,a5
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    80006408:	8ba1                	andi	a5,a5,8
    8000640a:	10078563          	beqz	a5,80006514 <virtio_disk_init+0x19c>
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    8000640e:	100017b7          	lui	a5,0x10001
    80006412:	0207a823          	sw	zero,48(a5) # 10001030 <_entry-0x6fffefd0>
  if(*R(VIRTIO_MMIO_QUEUE_READY))
    80006416:	43fc                	lw	a5,68(a5)
    80006418:	2781                	sext.w	a5,a5
    8000641a:	10079563          	bnez	a5,80006524 <virtio_disk_init+0x1ac>
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    8000641e:	100017b7          	lui	a5,0x10001
    80006422:	5bdc                	lw	a5,52(a5)
    80006424:	2781                	sext.w	a5,a5
  if(max == 0)
    80006426:	10078763          	beqz	a5,80006534 <virtio_disk_init+0x1bc>
  if(max < NUM)
    8000642a:	471d                	li	a4,7
    8000642c:	10f77c63          	bgeu	a4,a5,80006544 <virtio_disk_init+0x1cc>
  disk.desc = kalloc();
    80006430:	ffffa097          	auipc	ra,0xffffa
    80006434:	710080e7          	jalr	1808(ra) # 80000b40 <kalloc>
    80006438:	0003c497          	auipc	s1,0x3c
    8000643c:	c2848493          	addi	s1,s1,-984 # 80042060 <disk>
    80006440:	e088                	sd	a0,0(s1)
  disk.avail = kalloc();
    80006442:	ffffa097          	auipc	ra,0xffffa
    80006446:	6fe080e7          	jalr	1790(ra) # 80000b40 <kalloc>
    8000644a:	e488                	sd	a0,8(s1)
  disk.used = kalloc();
    8000644c:	ffffa097          	auipc	ra,0xffffa
    80006450:	6f4080e7          	jalr	1780(ra) # 80000b40 <kalloc>
    80006454:	87aa                	mv	a5,a0
    80006456:	e888                	sd	a0,16(s1)
  if(!disk.desc || !disk.avail || !disk.used)
    80006458:	6088                	ld	a0,0(s1)
    8000645a:	cd6d                	beqz	a0,80006554 <virtio_disk_init+0x1dc>
    8000645c:	0003c717          	auipc	a4,0x3c
    80006460:	c0c73703          	ld	a4,-1012(a4) # 80042068 <disk+0x8>
    80006464:	cb65                	beqz	a4,80006554 <virtio_disk_init+0x1dc>
    80006466:	c7fd                	beqz	a5,80006554 <virtio_disk_init+0x1dc>
  memset(disk.desc, 0, PGSIZE);
    80006468:	6605                	lui	a2,0x1
    8000646a:	4581                	li	a1,0
    8000646c:	ffffb097          	auipc	ra,0xffffb
    80006470:	b1a080e7          	jalr	-1254(ra) # 80000f86 <memset>
  memset(disk.avail, 0, PGSIZE);
    80006474:	0003c497          	auipc	s1,0x3c
    80006478:	bec48493          	addi	s1,s1,-1044 # 80042060 <disk>
    8000647c:	6605                	lui	a2,0x1
    8000647e:	4581                	li	a1,0
    80006480:	6488                	ld	a0,8(s1)
    80006482:	ffffb097          	auipc	ra,0xffffb
    80006486:	b04080e7          	jalr	-1276(ra) # 80000f86 <memset>
  memset(disk.used, 0, PGSIZE);
    8000648a:	6605                	lui	a2,0x1
    8000648c:	4581                	li	a1,0
    8000648e:	6888                	ld	a0,16(s1)
    80006490:	ffffb097          	auipc	ra,0xffffb
    80006494:	af6080e7          	jalr	-1290(ra) # 80000f86 <memset>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    80006498:	100017b7          	lui	a5,0x10001
    8000649c:	4721                	li	a4,8
    8000649e:	df98                	sw	a4,56(a5)
  *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)disk.desc;
    800064a0:	4098                	lw	a4,0(s1)
    800064a2:	08e7a023          	sw	a4,128(a5) # 10001080 <_entry-0x6fffef80>
  *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)disk.desc >> 32;
    800064a6:	40d8                	lw	a4,4(s1)
    800064a8:	08e7a223          	sw	a4,132(a5)
  *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)disk.avail;
    800064ac:	6498                	ld	a4,8(s1)
    800064ae:	0007069b          	sext.w	a3,a4
    800064b2:	08d7a823          	sw	a3,144(a5)
  *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)disk.avail >> 32;
    800064b6:	9701                	srai	a4,a4,0x20
    800064b8:	08e7aa23          	sw	a4,148(a5)
  *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)disk.used;
    800064bc:	6898                	ld	a4,16(s1)
    800064be:	0007069b          	sext.w	a3,a4
    800064c2:	0ad7a023          	sw	a3,160(a5)
  *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)disk.used >> 32;
    800064c6:	9701                	srai	a4,a4,0x20
    800064c8:	0ae7a223          	sw	a4,164(a5)
  *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;
    800064cc:	4705                	li	a4,1
    800064ce:	c3f8                	sw	a4,68(a5)
    disk.free[i] = 1;
    800064d0:	00e48c23          	sb	a4,24(s1)
    800064d4:	00e48ca3          	sb	a4,25(s1)
    800064d8:	00e48d23          	sb	a4,26(s1)
    800064dc:	00e48da3          	sb	a4,27(s1)
    800064e0:	00e48e23          	sb	a4,28(s1)
    800064e4:	00e48ea3          	sb	a4,29(s1)
    800064e8:	00e48f23          	sb	a4,30(s1)
    800064ec:	00e48fa3          	sb	a4,31(s1)
  status |= VIRTIO_CONFIG_S_DRIVER_OK;
    800064f0:	00496913          	ori	s2,s2,4
  *R(VIRTIO_MMIO_STATUS) = status;
    800064f4:	0727a823          	sw	s2,112(a5)
}
    800064f8:	60e2                	ld	ra,24(sp)
    800064fa:	6442                	ld	s0,16(sp)
    800064fc:	64a2                	ld	s1,8(sp)
    800064fe:	6902                	ld	s2,0(sp)
    80006500:	6105                	addi	sp,sp,32
    80006502:	8082                	ret
    panic("could not find virtio disk");
    80006504:	00002517          	auipc	a0,0x2
    80006508:	2c450513          	addi	a0,a0,708 # 800087c8 <syscalls+0x328>
    8000650c:	ffffa097          	auipc	ra,0xffffa
    80006510:	032080e7          	jalr	50(ra) # 8000053e <panic>
    panic("virtio disk FEATURES_OK unset");
    80006514:	00002517          	auipc	a0,0x2
    80006518:	2d450513          	addi	a0,a0,724 # 800087e8 <syscalls+0x348>
    8000651c:	ffffa097          	auipc	ra,0xffffa
    80006520:	022080e7          	jalr	34(ra) # 8000053e <panic>
    panic("virtio disk should not be ready");
    80006524:	00002517          	auipc	a0,0x2
    80006528:	2e450513          	addi	a0,a0,740 # 80008808 <syscalls+0x368>
    8000652c:	ffffa097          	auipc	ra,0xffffa
    80006530:	012080e7          	jalr	18(ra) # 8000053e <panic>
    panic("virtio disk has no queue 0");
    80006534:	00002517          	auipc	a0,0x2
    80006538:	2f450513          	addi	a0,a0,756 # 80008828 <syscalls+0x388>
    8000653c:	ffffa097          	auipc	ra,0xffffa
    80006540:	002080e7          	jalr	2(ra) # 8000053e <panic>
    panic("virtio disk max queue too short");
    80006544:	00002517          	auipc	a0,0x2
    80006548:	30450513          	addi	a0,a0,772 # 80008848 <syscalls+0x3a8>
    8000654c:	ffffa097          	auipc	ra,0xffffa
    80006550:	ff2080e7          	jalr	-14(ra) # 8000053e <panic>
    panic("virtio disk kalloc");
    80006554:	00002517          	auipc	a0,0x2
    80006558:	31450513          	addi	a0,a0,788 # 80008868 <syscalls+0x3c8>
    8000655c:	ffffa097          	auipc	ra,0xffffa
    80006560:	fe2080e7          	jalr	-30(ra) # 8000053e <panic>

0000000080006564 <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    80006564:	7119                	addi	sp,sp,-128
    80006566:	fc86                	sd	ra,120(sp)
    80006568:	f8a2                	sd	s0,112(sp)
    8000656a:	f4a6                	sd	s1,104(sp)
    8000656c:	f0ca                	sd	s2,96(sp)
    8000656e:	ecce                	sd	s3,88(sp)
    80006570:	e8d2                	sd	s4,80(sp)
    80006572:	e4d6                	sd	s5,72(sp)
    80006574:	e0da                	sd	s6,64(sp)
    80006576:	fc5e                	sd	s7,56(sp)
    80006578:	f862                	sd	s8,48(sp)
    8000657a:	f466                	sd	s9,40(sp)
    8000657c:	f06a                	sd	s10,32(sp)
    8000657e:	ec6e                	sd	s11,24(sp)
    80006580:	0100                	addi	s0,sp,128
    80006582:	8aaa                	mv	s5,a0
    80006584:	8c2e                	mv	s8,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80006586:	00c52d03          	lw	s10,12(a0)
    8000658a:	001d1d1b          	slliw	s10,s10,0x1
    8000658e:	1d02                	slli	s10,s10,0x20
    80006590:	020d5d13          	srli	s10,s10,0x20

  acquire(&disk.vdisk_lock);
    80006594:	0003c517          	auipc	a0,0x3c
    80006598:	bf450513          	addi	a0,a0,-1036 # 80042188 <disk+0x128>
    8000659c:	ffffb097          	auipc	ra,0xffffb
    800065a0:	8ee080e7          	jalr	-1810(ra) # 80000e8a <acquire>
  for(int i = 0; i < 3; i++){
    800065a4:	4981                	li	s3,0
  for(int i = 0; i < NUM; i++){
    800065a6:	44a1                	li	s1,8
      disk.free[i] = 0;
    800065a8:	0003cb97          	auipc	s7,0x3c
    800065ac:	ab8b8b93          	addi	s7,s7,-1352 # 80042060 <disk>
  for(int i = 0; i < 3; i++){
    800065b0:	4b0d                	li	s6,3
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    800065b2:	0003cc97          	auipc	s9,0x3c
    800065b6:	bd6c8c93          	addi	s9,s9,-1066 # 80042188 <disk+0x128>
    800065ba:	a08d                	j	8000661c <virtio_disk_rw+0xb8>
      disk.free[i] = 0;
    800065bc:	00fb8733          	add	a4,s7,a5
    800065c0:	00070c23          	sb	zero,24(a4)
    idx[i] = alloc_desc();
    800065c4:	c19c                	sw	a5,0(a1)
    if(idx[i] < 0){
    800065c6:	0207c563          	bltz	a5,800065f0 <virtio_disk_rw+0x8c>
  for(int i = 0; i < 3; i++){
    800065ca:	2905                	addiw	s2,s2,1
    800065cc:	0611                	addi	a2,a2,4
    800065ce:	05690c63          	beq	s2,s6,80006626 <virtio_disk_rw+0xc2>
    idx[i] = alloc_desc();
    800065d2:	85b2                	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    800065d4:	0003c717          	auipc	a4,0x3c
    800065d8:	a8c70713          	addi	a4,a4,-1396 # 80042060 <disk>
    800065dc:	87ce                	mv	a5,s3
    if(disk.free[i]){
    800065de:	01874683          	lbu	a3,24(a4)
    800065e2:	fee9                	bnez	a3,800065bc <virtio_disk_rw+0x58>
  for(int i = 0; i < NUM; i++){
    800065e4:	2785                	addiw	a5,a5,1
    800065e6:	0705                	addi	a4,a4,1
    800065e8:	fe979be3          	bne	a5,s1,800065de <virtio_disk_rw+0x7a>
    idx[i] = alloc_desc();
    800065ec:	57fd                	li	a5,-1
    800065ee:	c19c                	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    800065f0:	01205d63          	blez	s2,8000660a <virtio_disk_rw+0xa6>
    800065f4:	8dce                	mv	s11,s3
        free_desc(idx[j]);
    800065f6:	000a2503          	lw	a0,0(s4)
    800065fa:	00000097          	auipc	ra,0x0
    800065fe:	cfc080e7          	jalr	-772(ra) # 800062f6 <free_desc>
      for(int j = 0; j < i; j++)
    80006602:	2d85                	addiw	s11,s11,1
    80006604:	0a11                	addi	s4,s4,4
    80006606:	ffb918e3          	bne	s2,s11,800065f6 <virtio_disk_rw+0x92>
    sleep(&disk.free[0], &disk.vdisk_lock);
    8000660a:	85e6                	mv	a1,s9
    8000660c:	0003c517          	auipc	a0,0x3c
    80006610:	a6c50513          	addi	a0,a0,-1428 # 80042078 <disk+0x18>
    80006614:	ffffc097          	auipc	ra,0xffffc
    80006618:	e26080e7          	jalr	-474(ra) # 8000243a <sleep>
  for(int i = 0; i < 3; i++){
    8000661c:	f8040a13          	addi	s4,s0,-128
{
    80006620:	8652                	mv	a2,s4
  for(int i = 0; i < 3; i++){
    80006622:	894e                	mv	s2,s3
    80006624:	b77d                	j	800065d2 <virtio_disk_rw+0x6e>
  }

  // format the three descriptors.
  // qemu's virtio-blk.c reads them.

  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80006626:	f8042583          	lw	a1,-128(s0)
    8000662a:	00a58793          	addi	a5,a1,10
    8000662e:	0792                	slli	a5,a5,0x4

  if(write)
    80006630:	0003c617          	auipc	a2,0x3c
    80006634:	a3060613          	addi	a2,a2,-1488 # 80042060 <disk>
    80006638:	00f60733          	add	a4,a2,a5
    8000663c:	018036b3          	snez	a3,s8
    80006640:	c714                	sw	a3,8(a4)
    buf0->type = VIRTIO_BLK_T_OUT; // write the disk
  else
    buf0->type = VIRTIO_BLK_T_IN; // read the disk
  buf0->reserved = 0;
    80006642:	00072623          	sw	zero,12(a4)
  buf0->sector = sector;
    80006646:	01a73823          	sd	s10,16(a4)

  disk.desc[idx[0]].addr = (uint64) buf0;
    8000664a:	f6078693          	addi	a3,a5,-160
    8000664e:	6218                	ld	a4,0(a2)
    80006650:	9736                	add	a4,a4,a3
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80006652:	00878513          	addi	a0,a5,8
    80006656:	9532                	add	a0,a0,a2
  disk.desc[idx[0]].addr = (uint64) buf0;
    80006658:	e308                	sd	a0,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    8000665a:	6208                	ld	a0,0(a2)
    8000665c:	96aa                	add	a3,a3,a0
    8000665e:	4741                	li	a4,16
    80006660:	c698                	sw	a4,8(a3)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    80006662:	4705                	li	a4,1
    80006664:	00e69623          	sh	a4,12(a3)
  disk.desc[idx[0]].next = idx[1];
    80006668:	f8442703          	lw	a4,-124(s0)
    8000666c:	00e69723          	sh	a4,14(a3)

  disk.desc[idx[1]].addr = (uint64) b->data;
    80006670:	0712                	slli	a4,a4,0x4
    80006672:	953a                	add	a0,a0,a4
    80006674:	058a8693          	addi	a3,s5,88
    80006678:	e114                	sd	a3,0(a0)
  disk.desc[idx[1]].len = BSIZE;
    8000667a:	6208                	ld	a0,0(a2)
    8000667c:	972a                	add	a4,a4,a0
    8000667e:	40000693          	li	a3,1024
    80006682:	c714                	sw	a3,8(a4)
  if(write)
    disk.desc[idx[1]].flags = 0; // device reads b->data
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
    80006684:	001c3c13          	seqz	s8,s8
    80006688:	0c06                	slli	s8,s8,0x1
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    8000668a:	001c6c13          	ori	s8,s8,1
    8000668e:	01871623          	sh	s8,12(a4)
  disk.desc[idx[1]].next = idx[2];
    80006692:	f8842603          	lw	a2,-120(s0)
    80006696:	00c71723          	sh	a2,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    8000669a:	0003c697          	auipc	a3,0x3c
    8000669e:	9c668693          	addi	a3,a3,-1594 # 80042060 <disk>
    800066a2:	00258713          	addi	a4,a1,2
    800066a6:	0712                	slli	a4,a4,0x4
    800066a8:	9736                	add	a4,a4,a3
    800066aa:	587d                	li	a6,-1
    800066ac:	01070823          	sb	a6,16(a4)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    800066b0:	0612                	slli	a2,a2,0x4
    800066b2:	9532                	add	a0,a0,a2
    800066b4:	f9078793          	addi	a5,a5,-112
    800066b8:	97b6                	add	a5,a5,a3
    800066ba:	e11c                	sd	a5,0(a0)
  disk.desc[idx[2]].len = 1;
    800066bc:	629c                	ld	a5,0(a3)
    800066be:	97b2                	add	a5,a5,a2
    800066c0:	4605                	li	a2,1
    800066c2:	c790                	sw	a2,8(a5)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    800066c4:	4509                	li	a0,2
    800066c6:	00a79623          	sh	a0,12(a5)
  disk.desc[idx[2]].next = 0;
    800066ca:	00079723          	sh	zero,14(a5)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    800066ce:	00caa223          	sw	a2,4(s5)
  disk.info[idx[0]].b = b;
    800066d2:	01573423          	sd	s5,8(a4)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    800066d6:	6698                	ld	a4,8(a3)
    800066d8:	00275783          	lhu	a5,2(a4)
    800066dc:	8b9d                	andi	a5,a5,7
    800066de:	0786                	slli	a5,a5,0x1
    800066e0:	97ba                	add	a5,a5,a4
    800066e2:	00b79223          	sh	a1,4(a5)

  __sync_synchronize();
    800066e6:	0ff0000f          	fence

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    800066ea:	6698                	ld	a4,8(a3)
    800066ec:	00275783          	lhu	a5,2(a4)
    800066f0:	2785                	addiw	a5,a5,1
    800066f2:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    800066f6:	0ff0000f          	fence

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    800066fa:	100017b7          	lui	a5,0x10001
    800066fe:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    80006702:	004aa783          	lw	a5,4(s5)
    80006706:	02c79163          	bne	a5,a2,80006728 <virtio_disk_rw+0x1c4>
    sleep(b, &disk.vdisk_lock);
    8000670a:	0003c917          	auipc	s2,0x3c
    8000670e:	a7e90913          	addi	s2,s2,-1410 # 80042188 <disk+0x128>
  while(b->disk == 1) {
    80006712:	4485                	li	s1,1
    sleep(b, &disk.vdisk_lock);
    80006714:	85ca                	mv	a1,s2
    80006716:	8556                	mv	a0,s5
    80006718:	ffffc097          	auipc	ra,0xffffc
    8000671c:	d22080e7          	jalr	-734(ra) # 8000243a <sleep>
  while(b->disk == 1) {
    80006720:	004aa783          	lw	a5,4(s5)
    80006724:	fe9788e3          	beq	a5,s1,80006714 <virtio_disk_rw+0x1b0>
  }

  disk.info[idx[0]].b = 0;
    80006728:	f8042903          	lw	s2,-128(s0)
    8000672c:	00290793          	addi	a5,s2,2
    80006730:	00479713          	slli	a4,a5,0x4
    80006734:	0003c797          	auipc	a5,0x3c
    80006738:	92c78793          	addi	a5,a5,-1748 # 80042060 <disk>
    8000673c:	97ba                	add	a5,a5,a4
    8000673e:	0007b423          	sd	zero,8(a5)
    int flag = disk.desc[i].flags;
    80006742:	0003c997          	auipc	s3,0x3c
    80006746:	91e98993          	addi	s3,s3,-1762 # 80042060 <disk>
    8000674a:	00491713          	slli	a4,s2,0x4
    8000674e:	0009b783          	ld	a5,0(s3)
    80006752:	97ba                	add	a5,a5,a4
    80006754:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    80006758:	854a                	mv	a0,s2
    8000675a:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    8000675e:	00000097          	auipc	ra,0x0
    80006762:	b98080e7          	jalr	-1128(ra) # 800062f6 <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    80006766:	8885                	andi	s1,s1,1
    80006768:	f0ed                	bnez	s1,8000674a <virtio_disk_rw+0x1e6>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    8000676a:	0003c517          	auipc	a0,0x3c
    8000676e:	a1e50513          	addi	a0,a0,-1506 # 80042188 <disk+0x128>
    80006772:	ffffa097          	auipc	ra,0xffffa
    80006776:	7cc080e7          	jalr	1996(ra) # 80000f3e <release>
}
    8000677a:	70e6                	ld	ra,120(sp)
    8000677c:	7446                	ld	s0,112(sp)
    8000677e:	74a6                	ld	s1,104(sp)
    80006780:	7906                	ld	s2,96(sp)
    80006782:	69e6                	ld	s3,88(sp)
    80006784:	6a46                	ld	s4,80(sp)
    80006786:	6aa6                	ld	s5,72(sp)
    80006788:	6b06                	ld	s6,64(sp)
    8000678a:	7be2                	ld	s7,56(sp)
    8000678c:	7c42                	ld	s8,48(sp)
    8000678e:	7ca2                	ld	s9,40(sp)
    80006790:	7d02                	ld	s10,32(sp)
    80006792:	6de2                	ld	s11,24(sp)
    80006794:	6109                	addi	sp,sp,128
    80006796:	8082                	ret

0000000080006798 <virtio_disk_intr>:

void
virtio_disk_intr()
{
    80006798:	1101                	addi	sp,sp,-32
    8000679a:	ec06                	sd	ra,24(sp)
    8000679c:	e822                	sd	s0,16(sp)
    8000679e:	e426                	sd	s1,8(sp)
    800067a0:	1000                	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    800067a2:	0003c497          	auipc	s1,0x3c
    800067a6:	8be48493          	addi	s1,s1,-1858 # 80042060 <disk>
    800067aa:	0003c517          	auipc	a0,0x3c
    800067ae:	9de50513          	addi	a0,a0,-1570 # 80042188 <disk+0x128>
    800067b2:	ffffa097          	auipc	ra,0xffffa
    800067b6:	6d8080e7          	jalr	1752(ra) # 80000e8a <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    800067ba:	10001737          	lui	a4,0x10001
    800067be:	533c                	lw	a5,96(a4)
    800067c0:	8b8d                	andi	a5,a5,3
    800067c2:	d37c                	sw	a5,100(a4)

  __sync_synchronize();
    800067c4:	0ff0000f          	fence

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    800067c8:	689c                	ld	a5,16(s1)
    800067ca:	0204d703          	lhu	a4,32(s1)
    800067ce:	0027d783          	lhu	a5,2(a5)
    800067d2:	04f70863          	beq	a4,a5,80006822 <virtio_disk_intr+0x8a>
    __sync_synchronize();
    800067d6:	0ff0000f          	fence
    int id = disk.used->ring[disk.used_idx % NUM].id;
    800067da:	6898                	ld	a4,16(s1)
    800067dc:	0204d783          	lhu	a5,32(s1)
    800067e0:	8b9d                	andi	a5,a5,7
    800067e2:	078e                	slli	a5,a5,0x3
    800067e4:	97ba                	add	a5,a5,a4
    800067e6:	43dc                	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    800067e8:	00278713          	addi	a4,a5,2
    800067ec:	0712                	slli	a4,a4,0x4
    800067ee:	9726                	add	a4,a4,s1
    800067f0:	01074703          	lbu	a4,16(a4) # 10001010 <_entry-0x6fffeff0>
    800067f4:	e721                	bnez	a4,8000683c <virtio_disk_intr+0xa4>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    800067f6:	0789                	addi	a5,a5,2
    800067f8:	0792                	slli	a5,a5,0x4
    800067fa:	97a6                	add	a5,a5,s1
    800067fc:	6788                	ld	a0,8(a5)
    b->disk = 0;   // disk is done with buf
    800067fe:	00052223          	sw	zero,4(a0)
    wakeup(b);
    80006802:	ffffc097          	auipc	ra,0xffffc
    80006806:	c9c080e7          	jalr	-868(ra) # 8000249e <wakeup>

    disk.used_idx += 1;
    8000680a:	0204d783          	lhu	a5,32(s1)
    8000680e:	2785                	addiw	a5,a5,1
    80006810:	17c2                	slli	a5,a5,0x30
    80006812:	93c1                	srli	a5,a5,0x30
    80006814:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    80006818:	6898                	ld	a4,16(s1)
    8000681a:	00275703          	lhu	a4,2(a4)
    8000681e:	faf71ce3          	bne	a4,a5,800067d6 <virtio_disk_intr+0x3e>
  }

  release(&disk.vdisk_lock);
    80006822:	0003c517          	auipc	a0,0x3c
    80006826:	96650513          	addi	a0,a0,-1690 # 80042188 <disk+0x128>
    8000682a:	ffffa097          	auipc	ra,0xffffa
    8000682e:	714080e7          	jalr	1812(ra) # 80000f3e <release>
}
    80006832:	60e2                	ld	ra,24(sp)
    80006834:	6442                	ld	s0,16(sp)
    80006836:	64a2                	ld	s1,8(sp)
    80006838:	6105                	addi	sp,sp,32
    8000683a:	8082                	ret
      panic("virtio_disk_intr status");
    8000683c:	00002517          	auipc	a0,0x2
    80006840:	04450513          	addi	a0,a0,68 # 80008880 <syscalls+0x3e0>
    80006844:	ffffa097          	auipc	ra,0xffffa
    80006848:	cfa080e7          	jalr	-774(ra) # 8000053e <panic>
	...

0000000080007000 <_trampoline>:
    80007000:	14051073          	csrw	sscratch,a0
    80007004:	02000537          	lui	a0,0x2000
    80007008:	357d                	addiw	a0,a0,-1
    8000700a:	0536                	slli	a0,a0,0xd
    8000700c:	02153423          	sd	ra,40(a0) # 2000028 <_entry-0x7dffffd8>
    80007010:	02253823          	sd	sp,48(a0)
    80007014:	02353c23          	sd	gp,56(a0)
    80007018:	04453023          	sd	tp,64(a0)
    8000701c:	04553423          	sd	t0,72(a0)
    80007020:	04653823          	sd	t1,80(a0)
    80007024:	04753c23          	sd	t2,88(a0)
    80007028:	f120                	sd	s0,96(a0)
    8000702a:	f524                	sd	s1,104(a0)
    8000702c:	fd2c                	sd	a1,120(a0)
    8000702e:	e150                	sd	a2,128(a0)
    80007030:	e554                	sd	a3,136(a0)
    80007032:	e958                	sd	a4,144(a0)
    80007034:	ed5c                	sd	a5,152(a0)
    80007036:	0b053023          	sd	a6,160(a0)
    8000703a:	0b153423          	sd	a7,168(a0)
    8000703e:	0b253823          	sd	s2,176(a0)
    80007042:	0b353c23          	sd	s3,184(a0)
    80007046:	0d453023          	sd	s4,192(a0)
    8000704a:	0d553423          	sd	s5,200(a0)
    8000704e:	0d653823          	sd	s6,208(a0)
    80007052:	0d753c23          	sd	s7,216(a0)
    80007056:	0f853023          	sd	s8,224(a0)
    8000705a:	0f953423          	sd	s9,232(a0)
    8000705e:	0fa53823          	sd	s10,240(a0)
    80007062:	0fb53c23          	sd	s11,248(a0)
    80007066:	11c53023          	sd	t3,256(a0)
    8000706a:	11d53423          	sd	t4,264(a0)
    8000706e:	11e53823          	sd	t5,272(a0)
    80007072:	11f53c23          	sd	t6,280(a0)
    80007076:	140022f3          	csrr	t0,sscratch
    8000707a:	06553823          	sd	t0,112(a0)
    8000707e:	00853103          	ld	sp,8(a0)
    80007082:	02053203          	ld	tp,32(a0)
    80007086:	01053283          	ld	t0,16(a0)
    8000708a:	00053303          	ld	t1,0(a0)
    8000708e:	12000073          	sfence.vma
    80007092:	18031073          	csrw	satp,t1
    80007096:	12000073          	sfence.vma
    8000709a:	8282                	jr	t0

000000008000709c <userret>:
    8000709c:	12000073          	sfence.vma
    800070a0:	18051073          	csrw	satp,a0
    800070a4:	12000073          	sfence.vma
    800070a8:	02000537          	lui	a0,0x2000
    800070ac:	357d                	addiw	a0,a0,-1
    800070ae:	0536                	slli	a0,a0,0xd
    800070b0:	02853083          	ld	ra,40(a0) # 2000028 <_entry-0x7dffffd8>
    800070b4:	03053103          	ld	sp,48(a0)
    800070b8:	03853183          	ld	gp,56(a0)
    800070bc:	04053203          	ld	tp,64(a0)
    800070c0:	04853283          	ld	t0,72(a0)
    800070c4:	05053303          	ld	t1,80(a0)
    800070c8:	05853383          	ld	t2,88(a0)
    800070cc:	7120                	ld	s0,96(a0)
    800070ce:	7524                	ld	s1,104(a0)
    800070d0:	7d2c                	ld	a1,120(a0)
    800070d2:	6150                	ld	a2,128(a0)
    800070d4:	6554                	ld	a3,136(a0)
    800070d6:	6958                	ld	a4,144(a0)
    800070d8:	6d5c                	ld	a5,152(a0)
    800070da:	0a053803          	ld	a6,160(a0)
    800070de:	0a853883          	ld	a7,168(a0)
    800070e2:	0b053903          	ld	s2,176(a0)
    800070e6:	0b853983          	ld	s3,184(a0)
    800070ea:	0c053a03          	ld	s4,192(a0)
    800070ee:	0c853a83          	ld	s5,200(a0)
    800070f2:	0d053b03          	ld	s6,208(a0)
    800070f6:	0d853b83          	ld	s7,216(a0)
    800070fa:	0e053c03          	ld	s8,224(a0)
    800070fe:	0e853c83          	ld	s9,232(a0)
    80007102:	0f053d03          	ld	s10,240(a0)
    80007106:	0f853d83          	ld	s11,248(a0)
    8000710a:	10053e03          	ld	t3,256(a0)
    8000710e:	10853e83          	ld	t4,264(a0)
    80007112:	11053f03          	ld	t5,272(a0)
    80007116:	11853f83          	ld	t6,280(a0)
    8000711a:	7928                	ld	a0,112(a0)
    8000711c:	10200073          	sret
	...
