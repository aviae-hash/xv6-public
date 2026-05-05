// ============================================
// xv6 引导加载器 - bootmain.c
// 学生：Xaviliu
// 学号：[你的学号]
// 注释时间：2026年春季
// ============================================
// 功能：从磁盘加载ELF格式的内核镜像到内存
// 调用关系：bootasm.S -> bootmain() -> 内核入口
// ============================================

// Boot loader.
//
// Part of the boot block, along with bootasm.S, which calls bootmain().
// bootasm.S has put the processor into protected 32-bit mode.
// bootmain() loads an ELF kernel image from the disk starting at
// sector 1 and then jumps to the kernel entry routine.

#include "types.h"
#include "elf.h"
#include "x86.h"
#include "memlayout.h"

#define SECTSIZE  512  // 磁盘扇区大小：512字节

// 函数声明
void readseg(uchar*, uint, uint);

// ============================================
// bootmain() - 引导加载器主函数
// 功能：加载ELF格式的内核镜像并跳转到内核入口
// 调用者：bootasm.S（实模式->保护模式切换后）
// ============================================
void
bootmain(void)
{
  struct elfhdr *elf;      // ELF文件头指针
  struct proghdr *ph, *eph; // 程序头指针和结束指针
  void (*entry)(void);     // 内核入口函数指针
  uchar* pa;               // 物理地址指针

  // ============ 1. 读取ELF文件头 ============
  // 将ELF文件头读取到内存地址0x10000处（临时空间）
  elf = (struct elfhdr*)0x10000;  // scratch space

  // 从磁盘读取第一个页（4KB）包含ELF头
  readseg((uchar*)elf, 4096, 0);

  // ============ 2. 验证ELF格式 ============
  // 检查ELF魔数（0x7F 'E' 'L' 'F'）
  if(elf->magic != ELF_MAGIC)
    return;  // 不是有效的ELF文件，让bootasm.S处理错误

  // ============ 3. 加载所有程序段 ============
  // 获取程序头表位置和数量
  ph = (struct proghdr*)((uchar*)elf + elf->phoff); // 第一个程序头
  eph = ph + elf->phnum;                           // 程序头结束位置
  
  // 遍历所有程序段，加载到内存
  for(; ph < eph; ph++){
    pa = (uchar*)ph->paddr;  // 程序段的目标物理地址
    
    // 从磁盘读取程序段数据
    readseg(pa, ph->filesz, ph->off);
    
    // 如果内存大小大于文件大小（.bss段需要清零）
    if(ph->memsz > ph->filesz)
      stosb(pa + ph->filesz, 0, ph->memsz - ph->filesz); // 清零剩余内存
  }

  // ============ 4. 跳转到内核入口 ============
  // 从ELF头获取入口地址并跳转
  // 注意：这个函数调用不会返回！
  entry = (void(*)(void))(elf->entry);  // 获取入口函数指针
  entry();                              // 跳转到内核入口点
}

// ============================================
// waitdisk() - 等待磁盘就绪
// 功能：轮询磁盘状态寄存器，直到磁盘准备好
// ============================================
void
waitdisk(void)
{
  // 等待磁盘就绪
  // 读取0x1F7端口（磁盘状态寄存器）
  // 0x40表示磁盘已准备好
  while((inb(0x1F7) & 0xC0) != 0x40)
    ;
}

// ============================================
// readsect() - 读取单个扇区
// 参数：dst - 目标内存地址
//       offset - 扇区偏移量
// 功能：从磁盘读取一个512字节的扇区到内存
// ============================================
void
readsect(void *dst, uint offset)
{
  // 1. 等待磁盘就绪
  waitdisk();
  
  // 2. 设置读取参数（LBA28模式）
  outb(0x1F2, 1);                   // 扇区数量 = 1
  outb(0x1F3, offset);              // LBA低8位
  outb(0x1F4, offset >> 8);         // LBA中8位  
  outb(0x1F5, offset >> 16);        // LBA高8位
  outb(0x1F6, (offset >> 24) | 0xE0); // 0xE0表示LBA主设备
  outb(0x1F7, 0x20);                // 命令0x20 - 读取扇区

  // 3. 等待磁盘再次就绪
  waitdisk();
  
  // 4. 读取数据（每次32位，共128次）
  insl(0x1F0, dst, SECTSIZE/4);     // 0x1F0是数据端口
}

// ============================================
// readseg() - 读取连续字节
// 参数：pa - 物理地址
//       count - 要读取的字节数
//       offset - 起始偏移量（字节）
// 功能：从磁盘读取count字节到物理地址pa处
// 注意：可能读取比请求更多的数据（扇区对齐）
// ============================================
void
readseg(uchar* pa, uint count, uint offset)
{
  uchar* epa;  // 结束地址

  epa = pa + count;  // 计算结束地址

  // 1. 向下舍入到扇区边界（为了对齐）
  pa -= offset % SECTSIZE;

  // 2. 将字节偏移转换为扇区偏移（内核从扇区1开始）
  offset = (offset / SECTSIZE) + 1;

  // 3. 循环读取每个扇区
  // 如果速度慢，可以一次读取多个扇区
  // 可能会读取比请求更多的内存，但没关系——我们按顺序加载
  for(; pa < epa; pa += SECTSIZE, offset++)
    readsect(pa, offset);  // 读取一个扇区
}