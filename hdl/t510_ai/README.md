# T510-AI 100G 移植工程

这个目录是从 X440 的 `100G QSFP + PS DMA` 导出工程裁剪出来的一份可重建移植包，目标环境为：

- 目录：`hdl/t510_ai`
- 目标器件：`xczu47dr-ffve1156-2-i`
- 推荐 Vivado：`2022.2`

## 目录说明

- `lib/`
  - 100G 传输路径依赖的 AXI、FIFO、RFNoC/xport 公共源码
- `top/`
  - `top/t510_ai/ip/` 是可追踪源码资产：XCI、BD Tcl、wrapper 和 100G 顶层源码
  - `top/t510_ai/build-ip/` 是由脚本重建出来的 Vivado 缓存，不再是必须归档内容
- `scripts/vivado/`
  - 新环境下的建工程脚本、板级管脚约束和保留的通用时序约束
  - 其中 `create_t510_ai_100g_ps_bd_exported_from_current.tcl` 表示从当前可工作的 `xpr` 反导出的最新 PS BD 脚本快照
  - `t510_ai_build_ip_cache.tcl` / `rebuild_t510_ai_build_ip_cache.tcl` 用于从 `top/t510_ai/ip/` 重建 `build-ip/`
  - `legacy/` 下保留旧版或参考用脚本，不参与当前 T510 主流程
- `vivado/`
  - 仅用于存放 Vivado 生成的工程目录，例如 `vivado/project/`

## 建工程

```bash
cd hdl/t510_ai
bash scripts/recreate_vivado_project.sh
```

工程默认生成到：

- `vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.xpr`

如果你只想先重建 `build-ip` 缓存，不建 `.xpr`，执行：

```bash
cd hdl/t510_ai
bash scripts/rebuild_build_ip_cache.sh --force
```

## 当前迁移状态

- 已切换目标器件到 `xczu47dr-ffve1156-2-i`
- 已保留 X440 100G 系统所需的 PS 接口模型：
  - `M_AXI_HPM0`
  - `S_AXI_HPC1`
  - `pl_ps_irq0`
  - `40M / 100M / 200M` 三路 PL 时钟
- 已保留原有 100G 传输路径和 DMA/AXI-Lite 连接方式
- PS 侧 AXI-Lite 现在直接导出两路独立接口，不再使用顶层 AXI 分流：
  - `axil` 给 100G 以太网控制
  - `axil_ctrl` 给 `axi_center_control`
- 已验证新建工程脚本可以在 Vivado 2022.2 下创建项目和 `t510_ai_100g_ps_bd`
- `scripts/vivado/create_t510_ai_100g_full_system_project.tcl` 现在默认直接使用 `create_t510_ai_100g_ps_bd_exported_from_current.tcl`
  - 这个文件由当前验证通过的工程反导出得到，优先保证“脚本和当前工程一致”
- 当前导出的 PS BD 已包含：
  - T510 所需的 DDR、MIO 和常用外设配置
  - 一颗 `usp_rf_data_converter:2.6`
  - 2 路 ADC I/Q 输出、2 路 DAC 输入、`adc_clk/dac_clk/sysref_in`、`radio_rx_clk/radio_tx_clk` 和 `user_sysref_adc/dac`
  - `gpio_i/gpio_o/gpio_t` 三组 EMIO GPIO 端口
  - AXI-Lite 地址映射：`ETH=0xA0000000`、`RFDC=0xA0040000`、`DMA_LITE=0xA0080000`、`CTRL=0xA00C0000`
- 当前已确认这些 PS 关键属性来自 T510 配置：
  - DDR：`DDR4`，`1199.988037 MHz`，`DDR4_2400P`
  - 外设：`QSPI`、`SD0`、`SD1`、`SPI1`、`USB0`、`ENET3` 已启用
  - IO：`I2C0` 和 `UART0` 走 `EMIO`，`UART1` 走 `MIO 40..41`
  - 同时保留本工程所需的 `PL0=100 MHz`、`PL1=40 MHz`、`PL3=200 MHz`
- 已把 `scripts/vivado/t510_ai_pin.xdc` 接入建工程脚本
  - 当前已约束 `QSFP0` 的参考时钟、4 路 GT 收发、`modprs/reset/lpmode` 和 `qsfp_link_up/qsfp_activity`
  - 这些管脚命名已经对齐到当前 `t510_ai_100g_full_system_top`

## 已知事项

- 导入的部分 XCI/BD 原始生成环境是 Vivado 2021.1、器件是 `xczu28dr`
- 新工程脚本里已经加入 `upgrade_ip`
- 第一次在新环境建工程时，Vivado 仍可能提示部分 IP 升级/锁定信息
- 如果后续要继续综合实现，建议在 GUI 中再执行一次 `Report IP Status` 并确认升级结果

## 归档建议

当前目录已经整理成“三层”：

- 源码真源
  - `lib/`
  - `top/t510_ai/ip/`
  - `lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth/t510_ai_100g_full_system_top.sv`
  - `scripts/vivado/*.tcl`
  - `scripts/vivado/*.xdc`
- 可删缓存
  - `top/t510_ai/build-ip/`
  - `vivado/project/`
- `artifacts/t510_ai_100g_full_system/`
  - 用于存放当前验证通过后导出的 `bit/xsa/ltx`

现在 `build-ip/` 和 `vivado/project/` 都可以删掉，再从脚本恢复。

如果要先整理归档、同时保留当前 `vivado/project/` 工程目录，执行：

```bash
cd hdl/t510_ai
bash scripts/prepare_archive.sh
```

如果确认当前工程缓存已经不再需要，再执行：

```bash
cd hdl/t510_ai
bash scripts/prepare_archive.sh --source-only
```

脚本会做这些事：

- 先从当前 `vivado/project/t510_ai_100g_full_system/` 反导出最新的 BD Tcl 和 wrapper
  - 包括 `create_t510_ai_100g_ps_bd_exported_from_current.tcl`
  - 以及 `top/t510_ai/ip/` 下几份 100G 相关 BD Tcl / wrapper
- 从 `vivado/project/t510_ai_100g_full_system/` 提取当前已有的 `t510_ai_100g_full_system_top.bit/.ltx/.xsa` 到 `artifacts/`
- 删除 `top/t510_ai/build-ip/` 下的日志/输出文件
- 只有显式传 `--purge-project` / `--purge-build-ip` / `--source-only` 时才删除生成缓存
- 只有显式传 `--prune-ide` 时才删除 `.vscode/`、`.qoder/`

当前源码里显式保留了 block design wrapper 文件，不再依赖 `vivado/project/` 下的临时 wrapper。

归档之后如果要重新打开工程，不用依赖旧的 `.xpr`，直接执行：

```bash
cd hdl/t510_ai
bash scripts/recreate_vivado_project.sh
```

## 需要你后续补的部分

- RFDC 相关板级管脚约束
  - 参考工程 `antsdr_t510/xdc/t510.xdc` 里没有给出 `adc_clk_clk_*`、`dac_clk_clk_*`、`sysref_in_diff_*`、`rx_ch*_v_*`、`tx_ch*_v_*` 这些 RFDC 口的 `PACKAGE_PIN`
  - 当前工程因此还没有补这部分 XDC，需要你根据 T510-AI 的实际原理图继续补齐
- 如果 T510-AI 实际不是 4-lane 100G QSFP，而是单 lane SFP/25G/10G 结构：
  - 还需要进一步改顶层接口和 MGT 协议配置

## 参考来源

- 原始迁移源：UHD `usrp3/top/x400/export_x4xx_qsfp_wrapper_cg_100g`（外部参考，不在本仓库）
- T510 参考 PS/工程风格：`antsdr_t510` 参考工程（外部参考，不在本仓库）
