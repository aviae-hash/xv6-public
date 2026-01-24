# ============================================
# xv6 内核入口文件 - entry.S
# 学生：Xaviliu
# 学号：[你的学号]
# 注释时间：2026年春季
# ============================================
# 功能：内核入口点，初始化页表并跳转到main()
# 调用关系：bootmain() -> entry -> main()
# ============================================

# The xv6 kernel starts executing in this file. This file is linked with
# the kernel C code, so it can refer to kernel symbols such as main().
# The boot block (bootasm.S and bootmain.c) jumps to entry below.
# xv6内核从这里开始执行。此文件与内核C代码链接，因此可以引用内核符号如main()
# 引导块（bootasm.S和bootmain.c）跳转到下面的entry

# Multiboot header, for multiboot boot loaders like GNU Grub.
# http://www.gnu.org/software/grub/manual/multiboot/multiboot.html
# 多引导头，用于GNU Grub等多引导加载器
#
# Using GRUB 2, you can boot xv6 from a file stored in a
# Linux file system by copying kernel or kernelmemfs to /boot
# and then adding this menu entry:
# 使用GRUB 2，你可以从Linux文件系统中启动xv6，通过将kernel或kernelmemfs
# 复制到/boot，然后添加此菜单项：
#
# menuentry "xv6" {
# 	insmod ext2
# 	set root='(hd0,msdos1)'
# 	set kernel='/boot/kernel'
# 	echo "Loading ${kernel}..."
# 	multiboot ${kernel} ${kernel}
# 	boot
# }

#include "asm.h"
#include "memlayout.h"
#include "mmu.h"
#include "param.h"

# ============================================
# 多引导头 - 用于多引导加载器的数据
# ============================================
.p2align 2        # 4字节对齐
.text             # 代码段开始
.globl multiboot_header
multiboot_header:
  #define magic 0x1badb002  # 多引导魔数
  #define flags 0           # 标志位
  .long magic              # 魔数（必须）
  .long flags              # 标志位
  .long (-magic-flags)     # 校验和（魔数+标志位+校验和 = 0）

# ============================================
# 内核入口点定义
# ============================================
# By convention, the _start symbol specifies the ELF entry point.
# Since we haven't set up virtual memory yet, our entry point is
# the physical address of 'entry'.
# 按照约定，_start符号指定ELF入口点。
# 由于我们尚未设置虚拟内存，入口点是'entry'的物理地址。
.globl _start
_start = V2P_WO(entry)  # _start = entry的物理地址（V2P_WO:虚拟地址转物理地址）

# ============================================
# entry - 内核主入口点
# 引导处理器进入xv6，分页关闭状态
# ============================================
.globl entry
entry:
  # ============ 1. 启用4MB大页支持 ============
  # Turn on page size extension for 4Mbyte pages
  movl    %cr4, %eax          # 读取CR4控制寄存器
  orl     $(CR4_PSE), %eax    # 设置PSE位（启用4MB页）
  movl    %eax, %cr4          # 写回CR4

  # ============ 2. 设置页目录 ============
  # Set page directory
  movl    $(V2P_WO(entrypgdir)), %eax  # 获取entrypgdir的物理地址
  movl    %eax, %cr3                    # 设置CR3为页目录物理地址

  # ============ 3. 开启分页 ============
  # Turn on paging.
  movl    %cr0, %eax                    # 读取CR0控制寄存器
  orl     $(CR0_PG|CR0_WP), %eax        # 设置PG位（启用分页）和WP位（写保护）
  movl    %eax, %cr0                    # 写回CR0，正式开启分页机制

  # ============ 4. 设置栈指针 ============
  # Set up the stack pointer.
  movl $(stack + KSTACKSIZE), %esp      # 设置栈指针指向栈顶
  # stack: 栈底地址，KSTACKSIZE: 栈大小
  # stack + KSTACKSIZE = 栈顶地址

  # ============ 5. 跳转到main()函数 ============
  # Jump to main(), and switch to executing at
  # high addresses. The indirect call is needed because
  # the assembler produces a PC-relative instruction
  # for a direct jump.
  # 跳转到main()，并切换到高地址执行。
  # 需要间接调用，因为汇编器对直接跳转会生成PC相对指令。
  mov $main, %eax    # 将main函数的地址加载到eax
  jmp *%eax          # 间接跳转到eax指向的地址（main函数）

# ============================================
# 栈空间定义
# ============================================
.comm stack, KSTACKSIZE  # 分配KSTACKSIZE大小的未初始化内存给stack
# .comm: 声明未初始化的通用内存区域
# stack: 符号名，KSTACKSIZE: 大小（在param.h中定义，通常为4096*8=32KB）