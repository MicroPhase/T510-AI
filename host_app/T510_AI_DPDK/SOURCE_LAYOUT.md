# Source Layout

当前 `host_app/T510_AI_DPDK` 已收敛为 `GUI-only` 结构。

## 构建产物

当前只构建两个目标：

- `t510_ai_dpdk`
  - GUI 依赖的静态库
- `t510_ai_gui`
  - 最终 GUI 可执行程序

## 核心库源码

这些文件组成 `t510_ai_dpdk`：

- `src/core/zero_copy.cpp`
- `src/core/time_spec.cpp`
- `src/core/dpdk_zero_copy.cpp`
- `src/transport/local_ctrl.cpp`
- `src/device/t510_ai_rfdc_ctrl.cpp`
- `src/device/t510_ai_fpga_ctrl.cpp`
- `src/device/t510_ai_impl.cpp`
- `src/device/t510_ai_iq_payload.cpp`
- `src/device/t510_ai_dpdk_device.cpp`

对应头文件在：

- `include/sdr/`
- `include/t510_ai/`

## GUI 源码

- `gui/src/t510_ai_gui.cpp`
- `gui/src/t510_ai_gui_app.hpp`
- `gui/src/t510_ai_gui_support.cpp`
- `gui/src/t510_ai_gui_workers.cpp`

## 构建脚本

- `tools/build_release.sh`
- `tools/build_asan_gui.sh`
- `tools/run_gui_gdb.sh`

## 保留文档

- `README.md`
- `IQ_TRANSPORT_LIFECYCLE.md`
- `gui/README.md`

## 已移除

以下测试/示例程序已从主线中去掉：

- `src/example/t510_ai_demo.cpp`
- `src/example/t510_ai_iq_payload_sim.cpp`

`CMakeLists.txt` 也不再构建对应 target。
