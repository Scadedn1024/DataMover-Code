# DataMover 工程说明

## 1. 工程概述
本工程包含 4 个 Verilog 模块，用于在 AXI Stream 与 AXI Memory Mapped 之间进行数据搬运，覆盖 MM2S（读内存到流）与 S2MM（写流到内存）两个方向，并提供两套输入流宽度适配版本：8bit 到 64bit、32bit 到 64bit。

整体上，模块内部通过异步 FIFO 完成 I_sys_clk 与 I_ps_clk 两个时钟域之间的数据与指令跨域。

## 2. 文件与功能对应

| 文件名 | 模块名 | 方向 | 主要功能 |
|---|---|---|---|
| datamover_mm2s_8to64.v | datamover_mm2s | MM2S | 接收 72bit 命令，发起 AXI 读突发，64bit 读数据拆分为 8bit 流输出 |
| datamover_s2mm_8to64.v | datamover_s2mm | S2MM | 接收 72bit 命令与 8bit 流数据，组包为 64bit，发起 AXI 写突发 |
| datamover_mm2s_32to64.v | datamover_mm2s | MM2S | 接收地址+长度命令，AXI 读后输出 I/Q 两路 16bit（合计 32bit 流语义） |
| datamover_s2mm_32to64.v | datamover_s2mm | S2MM | 接收 I/Q 两路 16bit 流数据与地址+长度命令，组包写入 AXI |

说明：
- 8to64 与 32to64 两组文件内模块名分别相同（都叫 datamover_mm2s 或 datamover_s2mm），综合或仿真时应避免同名模块同时加入同一编译单元。

## 3. 接口与命令格式

### 3.1 8to64 版本命令格式（72bit）
CMD[71:0] 字段定义：
- [71:68] RSVD
- [67:64] TAG
- [63:32] SADDR
- [31] DRR
- [30] EOF
- [29:24] DSA
- [23] TYPE
- [22:0] BTT

### 3.2 32to64 版本命令接口
32to64 版本使用分离命令输入：
- cmd_addr（地址）
- cmd_len（长度）

## 4. 时钟域与数据路径
- I_sys_clk：PL 侧命令与流接口主要工作时钟。
- I_ps_clk：AXI MM 读写事务主要工作时钟。
- 跨域机制：通过 xpm_fifo_async 实现命令与数据在两个时钟域之间安全传递。

## 5. 当前实现约束与注意事项

### 5.1 通用约束
- 设计按 一条指令 对应 一组数据 的时序模型工作。
- 当前指令未完成前，不应下发下一条同方向指令。

### 5.2 MM2S 32to64 版本
- 注释中明确：默认下游 tready 常为高。
- 若存在明显反压，异步 FIFO 读出传递可能出现重复或遗漏风险。
- cmd_len 需为偶数。

### 5.3 S2MM 32to64 版本
- cmd_len 需为偶数且不为 0。
- 应按 指令在前、数据在后 的顺序输入。

### 5.4 S2MM 8to64 版本
- 注释中指出：若无有效指令仅输入数据，数据将被丢弃。

## 6. 状态与错误指示
- MM2S 与 S2MM 均提供状态流接口：
  - sts_tdata = 0x80：长度匹配或事务正常
  - sts_tdata = 0x10：长度不匹配或错误
- 同时提供错误输出信号（O_mm2s_err / O_s2mm_err）用于上层监测。

## 7. 集成建议
1. 先选择单一版本（8to64 或 32to64）进行系统集成，避免同名模块冲突。
2. 保证命令与数据严格配对，避免乱序注入。
3. 结合系统吞吐评估 tready 反压场景，必要时增加缓冲或修正读出握手机制。
4. 若面向 AXI4 Full，建议复核 awlen/arlen 位宽、突发长度与目标互联配置是否一致。

## 8. 后续可完善方向
- 增加统一顶层封装，参数化选择 8to64 或 32to64 模式。
- 增加 testbench，覆盖跨域、反压、尾包字节对齐、异常响应等场景。
