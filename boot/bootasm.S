#include "asm.h"
#include "memlayout.h"
#include "mmu.h"

# 启动第一个CPU：切换到32位保护模式，跳转到C代码
# BIOS从硬盘的第一个扇区加载此代码到物理地址0x7c00处，
# 并在实模式下开始执行，此时%cs=0 %ip=7c00

.code16                       # 生成16位代码（实模式）
.globl start
start:
  cli                         # BIOS启用了中断；这里先关闭中断
  
  # ============ 1. 初始化段寄存器 ============
  # 将数据段寄存器DS、ES和SS清零
  xorw    %ax,%ax             # 将%ax寄存器清零（AX=0）
  movw    %ax,%ds             # -> 数据段(DS)=0
  movw    %ax,%es             # -> 附加段(ES)=0
  movw    %ax,%ss             # -> 堆栈段(SS)=0
  
  # ============ 2. 开启A20地址线 ============
  # 早期PC的物理地址线A20被强制置0，使得2MB内存的PC只能使用1MB
  # 这里需要解除这个限制，以便访问1MB以上的内存
seta20.1:
  inb     $0x64,%al               # 读取键盘控制器状态端口(0x64)
  testb   $0x2,%al                # 测试第1位（输入缓冲区是否满）
  jnz     seta20.1                # 如果缓冲区满，循环等待
  
  movb    $0xd1,%al               # 发送命令0xd1到端口0x64
  outb    %al,$0x64               # 表示要写8042的输出端口

seta20.2:
  inb     $0x64,%al               # 再次等待键盘控制器就绪
  testb   $0x2,%al
  jnz     seta20.2
  
  movb    $0xdf,%al               # 发送数据0xdf到端口0x60
  outb    %al,$0x60               # 0xdf = 11011111b，将A20线置1
  
  # ============ 3. 切换到保护模式 ============
  # 使用一个引导GDT，使虚拟地址直接映射到物理地址
  # 这样在模式切换过程中内存映射不会改变
  lgdt    gdtdesc                 # 加载全局描述符表(GDT)
  movl    %cr0, %eax              # 读取控制寄存器CR0
  orl     $CR0_PE, %eax           # 设置保护模式使能位(PE=1)
  movl    %eax, %cr0              # 写回CR0，正式进入保护模式

//PAGEBREAK!
  # ============ 4. 使用长跳转完成保护模式切换 ============
  # 通过长跳转重新加载%cs和%eip
  # 段描述符设置为无转换，所以映射仍然是恒等映射
  ljmp    $(SEG_KCODE<<3), $start32  # 跳转到32位代码段

.code32  # 从现在开始生成32位代码（保护模式）
start32:
  # ============ 5. 设置保护模式下的数据段寄存器 ============
  movw    $(SEG_KDATA<<3), %ax    # 我们的数据段选择子
  movw    %ax, %ds                # -> DS: 数据段（内核数据）
  movw    %ax, %es                # -> ES: 附加段
  movw    %ax, %ss                # -> SS: 堆栈段
  movw    $0, %ax                 # 清零未使用的段寄存器
  movw    %ax, %fs                # -> FS: 暂时不用
  movw    %ax, %gs                # -> GS: 暂时不用
  
  # ============ 6. 设置栈指针并调用C函数 ============
  movl    $start, %esp            # 设置栈指针指向start地址
  call    bootmain                # 调用bootmain.c中的C函数
  
  # ============ 7. bootmain不应该返回，如果返回则进入死循环 ============
  # 如果bootmain返回（不应该发生），触发Bochs断点
  movw    $0x8a00, %ax            # 0x8a00 -> 端口0x8a00
  movw    %ax, %dx
  outw    %ax, %dx
  movw    $0x8ae0, %ax            # 0x8ae0 -> 端口0x8a00
  outw    %ax, %dx
  
spin:
  jmp     spin                    # 无限循环

# ============ 8. 引导GDT（全局描述符表） ============
.p2align 2                                # 强制4字节对齐
gdt:
  SEG_NULLASM                             # 第一个GDT条目必须为空
  SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)   # 代码段：可执行、可读
  SEG_ASM(STA_W, 0x0, 0xffffffff)         # 数据段：可写

gdtdesc:
  .word   (gdtdesc - gdt - 1)             # GDT界限（大小-1）
  .long   gdt                             # GDT基地址