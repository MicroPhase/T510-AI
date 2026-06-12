# IQ Transport Lifecycle

这个文档说明当前 `T510_AI_DPDK` 里关于 `IQ data transport` 生命周期管理的做法。

目标不是解释整个 GUI，而是解释这件事：

- 为什么 `Stop` 后不再重建整套 `device/impl`
- 为什么只关闭和重建 `DPDK IQ 数据流`
- 这些逻辑目前落在哪一层

## 背景

当前 host 侧实际上有两条逻辑上不同的链路：

- `control transport`
  - 用于 `peek/poke`、配置 RFDC、配置 FPGA 控制寄存器
  - 对应 `local_ctrl`
- `IQ data transport`
  - 用于接收 FPGA 发出的 IQ CHDR/UDP 数据
  - 对应 `DPDK offload/data port`

代码上这两部分都由 `t510_ai_impl` 持有：

- control: [t510_ai_impl.cpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/src/device/t510_ai_impl.cpp)
- IQ data: [t510_ai_impl.cpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/src/device/t510_ai_impl.cpp)

以前 GUI 层遇到 `Stop` 后状态异常时，尝试过“像退出程序再重开一样”直接重建整套 `device/impl`。这个办法虽然有时能恢复数据流，但容易引出新的问题：

- `Stop` 后立刻打 control bus，容易出现 `ack timeout`
- GUI 需要自己拼装很多 transport 生命周期逻辑
- `control` 和 `IQ data` 两条链路被一起重置，耦合太重

因此当前策略改成：

- `Stop` 时只释放 `IQ data transport`
- `Start` 时只在需要时重建 `IQ data transport`
- `control transport` 和 `local_ctrl` 整体保持不动

## 当前设计

### 1. `t510_ai_impl` 负责真正的 IQ data xport 生命周期

接口定义在：

- [t510_ai_impl.hpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/include/t510_ai/t510_ai_impl.hpp)

核心接口：

- `has_iq_data_xport()`
- `reopen_iq_data_xport()`
- `close_iq_data_xport()`

实现位置：

- [t510_ai_impl.cpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/src/device/t510_ai_impl.cpp)

它们只操作 `_iq_data_xport`，不会重建：

- `_ctrl_xport`
- `_ctrl_bus`
- `_rfdc_ctrl`
- `_fpga_ctrl`

也就是说，这一层只负责“数据口活不活着”，不负责控制面恢复。

### 2. `t510_ai_dpdk_device` 负责把 IQ transport 和 route 组合成一个高层动作

接口定义在：

- [t510_ai_dpdk_device.hpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/include/t510_ai/t510_ai_dpdk_device.hpp)

当前新增的高层接口：

- `prepare_iq_data_path(uint16_t src_epid = IQ_CAPTURE_DST_EPID, double timeout = 1.0)`
- `release_iq_data_path()`

以及较底层的辅助接口：

- `has_iq_data_transport()`
- `ensure_iq_data_transport()`
- `reopen_iq_data_transport()`
- `close_iq_data_transport()`

实现位置：

- [t510_ai_dpdk_device.cpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/src/device/t510_ai_dpdk_device.cpp)

语义是：

- `prepare_iq_data_path()`
  - 如果 IQ transport 已关闭，则重建
  - 然后保证 `IQ_CAPTURE_DST_EPID` 路由已广告
- `release_iq_data_path()`
  - 关闭 IQ transport
  - 同时清掉 route cache

这样上层不再需要分别写：

- reopen transport
- advertise route
- invalidate route cache

这些都收敛到 `device` 层统一处理。

### 3. GUI 只是调用高层接口，不再自己管理 transport 细节

当前 GUI 入口：

- [t510_ai_gui.cpp](/home/wcc/vm_box/xilinx_image_builder/t510_ai/host/T510_AI_DPDK/gui/src/t510_ai_gui.cpp)

现在的调用原则：

- `Capture Once / Start Stream / Start Record / Start Drain Test`
  - 先调用 `device->prepare_iq_data_path(...)`
  - 再进入各自的采集/流处理流程
- `Stop Stream / Stop Record / Stop Drain Test`
  - 先执行原来的 `stop + quiesce`
  - 再调用 `device->release_iq_data_path()`

也就是说，GUI 现在知道“什么时候该准备/释放数据路径”，但不知道“准备/释放数据路径内部怎么做”。

## 为什么不直接沉到 `stop_rx_stream()` / `arm_rx_*()`

看起来最自然的做法，好像是把这套逻辑直接塞进：

- `t510_ai_impl::stop_rx_stream()`
- `t510_ai_impl::arm_rx_capture_once()`
- `t510_ai_impl::arm_rx_stream()`

当前没有这么做，原因是这会把三件事过度耦合：

- FPGA stop/rearm 控制
- DPDK IQ 数据口生命周期
- route advertise 缓存语义

特别是 `stop_rx_stream()` 现在会被 `quiesce_rx_path()` 多次调用。如果把“关闭 IQ transport”直接绑定到 `stop_rx_stream()`：

- 很容易在排空过程里过早把数据口打掉
- 导致后续 drain/flush 逻辑行为变得不稳定

所以当前边界是：

- `impl`
  - 只提供 transport 生命周期原语
- `device`
  - 组合成 IQ 数据路径的高层动作
- `GUI`
  - 只在合适的时机调用高层动作

这是当前比较稳妥的一层分工。

## 为什么这个方案比“重建整个 device/impl”更合适

因为我们现在已知：

- 程序退出再重开，确实能让 `stream/drain` 恢复
- 但重建整个 `device/impl` 会碰 control plane
- control plane 在 stop 后临界窗口容易打出 `ack timeout`

所以更安全的做法是：

- 只把问题最相关的 `IQ data transport` 生命周期单独拎出来管理
- 尽量不去动 control bus

这能保留“像重开程序那样把数据口清干净”的效果，同时避免把 `local_ctrl` 一起拖进来。

## 当前已知边界

这个方案当前只解决 host 侧“数据口残留状态”的问题，不等于已经证明 FPGA 没问题。

它不能单独解决这些情况：

- FPGA `mode_exit / stop / rearm` 边界状态异常
- `record` 期间 host 侧 DPDK 队列本身被压爆
- 板端在 stop 后仍持续出流

所以如果后面仍然出现：

- `seq error`
- `vita gap`
- `record` 后模式切换异常

仍然需要同时看：

- GUI 里 `dpdk_drop_delta`
- `quiesce` 统计
- FPGA 侧 stop/rearm 语义

## 推荐理解方式

把当前逻辑理解成：

- `control plane` 是常驻会话
- `IQ data plane` 是可释放、可重建的会话

当前只是把 `IQ data plane` 的生命周期显式化了。

这不是最终架构，只是当前为了验证和规避问题采取的一种工程折中。

## 后续可选演进

如果后面要继续收敛，可以考虑两步：

1. 在 `t510_ai_dpdk_device` 再往上封装 mode 级接口
   - 例如 `start_stream_path()` / `stop_stream_path()`
   - 这样 GUI 可以进一步瘦身

2. 等 FPGA stop/rearm 语义稳定后，再评估是否把一部分逻辑沉到更下层
   - 但不建议直接把 route/transport 生命周期硬塞进 `stop_rx_stream()`

