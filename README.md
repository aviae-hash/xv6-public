# xv6 读书实践周实验报告

## 一、实验内容说明

### 完成的任务

| 层级 | 任务 | 状态 |
|------|------|------|
| 第一层 | 任务1：系统调用路径跟踪 | ✅ 完成 |
| 第一层 | 任务2：调度过程观察 | ✅ 完成 |
| 第一层 | 任务3：内存分配观察 | ✅ 完成 |

### 修改的文件
- `testwrite.c` - 用户测试程序
- `Makefile` - 添加 testwrite 编译规则
- `syscall.c` - 添加系统调用入口日志
- `sysfile.c` - 添加 sys_write 调用日志
- `proc.c` - 添加调度切换日志
- `kalloc.c` - 添加内存分配日志

## 二、实现过程

### 任务1：系统调用跟踪
在 `syscall.c` 的 `syscall()` 函数中添加 `cprintf("[KERNEL] enter syscall, num=%d\n", num)`，在 `sysfile.c` 的 `sys_write()` 函数中添加 `cprintf("[KERNEL] sys_write invoked\n")`。创建 `testwrite.c` 用户程序调用 write 系统调用进行验证。

### 任务2：调度观察
在 `proc.c` 的 `scheduler()` 函数中添加 `cprintf("[SCHED] switch to pid=%d\n", p->pid)`。运行 `ls & cat README &` 观察不同进程 pid 交替输出。

### 任务3：内存分配
在 `kalloc.c` 的 `kalloc()` 函数中添加 `cprintf("[MEM] alloc page at 0x%x\n", (uint)r)`。运行 `ls` 观察页分配地址。

## 三、遇到的问题及解决方法

1. **Windows 和 WSL 文件系统兼容性**：编译时提示 `No rule to make target 'bootstrap.S'`，原因是 Windows 不区分大小写。解决：切换到 WSL 原生文件系统 `~/xv6-public` 开发。

2. **Makefile 格式错误**：报 `recipe commences before first target`，解决：使用 `git checkout Makefile` 恢复原始文件，重新添加 `_testwrite`。

3. **_testwrite 未编译**：`make fs.img` 报错文件不存在，解决：手动运行 `gcc` 和 `ld` 编译链接 `_testwrite`。

4. **退出 xv6**：使用 `Ctrl+A` 然后 `X` 退出 QEMU。

## 四、实践心得

通过本次 xv6 内核实验，我深入理解了操作系统运行阶段的核心机制。

**系统调用方面**：通过在 syscall() 和 sys_write() 中添加日志，我清楚地看到了用户程序调用 write() 时，控制权从用户态陷入内核态，经过系统调用分发函数，最终执行具体的 sys_write() 实现。

**调度机制方面**：在 scheduler() 中添加调度日志后，运行多个后台进程看到不同进程的 pid 交替出现，直观地理解了时间片轮转调度算法。

**内存管理方面**：在 kalloc() 中添加日志后，运行 ls 命令看到多次页分配输出，地址逐步递增，验证了 xv6 使用链表管理空闲页框。

这次实验让我从"理论理解"上升到"动手验证"。虽然过程中遇到了环境配置、Makefile 格式等困难，但通过查阅资料和反复调试，最终都解决了。这些经验对我后续学习操作系统内核非常有价值。
