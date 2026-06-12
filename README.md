# T510-AI Customer Package

这个仓库整理了 T510-AI / T510-FNIC 相关的 FPGA、板级 Linux 镜像构建配置、Buildroot external package，以及 T510-AI DPDK GUI 上位机源码。

## 目录入口

- `hdl/t510_ai/`: T510-AI 100G FPGA 工程源码、Vivado 重建脚本和已验证硬件导出物。
- `hdl/t510_fnic/`: T510-FNIC Aurora bring-up FPGA 工程源码、Vivado 重建脚本和硬件导出物。
- `board/t510-ai/`: T510-AI PS 侧镜像构建配置、设备树补充、U-Boot 配置、Buildroot 配置和板端工具。
- `board/t510-fnic/`: T510-FNIC PS 侧镜像构建配置和 RFDC 控制程序。
- `buildroot-external/`: Buildroot external tree，包含 T510/FNIC 镜像需要的本地 package。
- `host_app/T510_AI_DPDK/`: T510-AI GUI 上位机和 DPDK 数据面源码。
- `scripts/`: 镜像构建、Xilinx 工具调用、QSPI/SD 包装等公共脚本。

## 快速开始

构建 T510-AI 镜像：

```bash
export VIVADO_SETTINGS=/opt/Xilinx/Vivado/2022.2/settings64.sh
make fetch BOARD=t510-ai
make BOARD=t510-ai
```

构建 T510-FNIC SD 启动文件：

```bash
export VIVADO_SETTINGS=/opt/Xilinx/Vivado/2022.2/settings64.sh
make fetch BOARD=t510-fnic
make BOARD=t510-fnic sd
```

重建 FPGA 工程：

```bash
cd hdl/t510_ai
./scripts/recreate_vivado_project.sh

cd ../t510_fnic
./scripts/recreate_vivado_project.sh
```

构建 GUI 上位机：

```bash
cd host_app/T510_AI_DPDK
./tools/build_release.sh
```

## 交付范围

仓库保留了源码、脚本、板级配置、补丁和必要的 T510-AI / T510-FNIC bit/xsa/ltx 硬件导出物。以下内容不会纳入版本管理，需要按需重新生成或由 `make fetch` 获取：

- Linux、U-Boot、Buildroot、ATF、embeddedsw、device-tree-xlnx 等外部源码树。
- `build/`、Vivado `vivado/project/`、`.Xil/`、xsim、CMake build 等生成目录。
- 本地 IQ 录波、调试日志和 host 侧编译产物。

更详细的板级使用说明见 `board/t510-ai/README.md` 和 `board/t510-fnic/README.md`。
