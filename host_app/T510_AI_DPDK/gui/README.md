# GUI Notes

这个目录只存放 GUI 相关源码：

- `t510_ai_gui.cpp`
- `t510_ai_gui_app.hpp`
- `t510_ai_gui_support.cpp`
- `t510_ai_gui_workers.cpp`

GUI 的完整构建、DPDK 配置和运行说明请看顶层文档：

- [README.md](../README.md)

当前 GUI 语义摘要：

- `Capture Once`
  - 抓一块指定大小 IQ，更新显示
- `Start Stream (4MB Loop)`
  - 循环执行 4MB `capture-once`
  - 每轮更新频谱和瀑布图
- `Start Record`
  - 保持连续流录制语义
- `Start Drain Test`
  - 只做持续收包和连续性/丢包观察
  - 不写文件，不更新频谱和瀑布图

当前采样率固定：

- `245.76 MHz`
