# T510_FNIC Vivado 脚本使用说明

本目录用于维护 `T510_FNIC` Aurora/RFDC Vivado 工程的导出、重建和 bitstream 构建流程。推荐把 Vivado GUI 中确认过的工程状态导出为 `scripts/vivado/*.tcl`，再用这些 Tcl 脚本重建工程，避免 `.xpr/.srcs/.gen` 中残留本地路径或旧 IP 状态。

## 1. 环境

脚本优先使用仓库根目录下的环境脚本：

```text
scripts/xilinx-settings.sh
```

如果不存在，则默认加载：

```text
/opt/Xilinx/Vivado/${XILINX_VERSION:-2022.2}/settings64.sh
```

也可以在命令行指定 Vivado 版本：

```bash
hdl/t510_fnic/scripts/recreate_vivado_project.sh --vivado-version 2022.2
```

## 2. 导出当前 Vivado 工程状态

当你在 Vivado GUI 中修改了 block design、fileset、约束或项目 IP 后，需要把当前工程状态导出回脚本。

默认从以下工程导出：

```text
hdl/t510_fnic/vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr
```

先导出到临时 generated 目录，便于 review：

```bash
hdl/t510_fnic/scripts/export_current_project_scripts.sh
```

默认输出目录：

```text
hdl/t510_fnic/scripts/vivado/generated/
```

确认 generated 中的导出内容无误后，用 `--apply` 覆盖主重建脚本：

```bash
hdl/t510_fnic/scripts/export_current_project_scripts.sh --apply
```

`--apply` 会更新：

```text
hdl/t510_fnic/scripts/vivado/create_t510_fnic_aurora_bd.tcl
hdl/t510_fnic/scripts/vivado/create_t510_fnic_aurora_sources.tcl
```

同时会把非 block-design 自动生成的项目 IP `.xci/.xcix` 复制到：

```text
hdl/t510_fnic/lib/ip/
```

常用可选参数：

```bash
hdl/t510_fnic/scripts/export_current_project_scripts.sh \
  --project hdl/t510_fnic/vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr \
  --out-dir hdl/t510_fnic/scripts/vivado/generated \
  --ip-dir hdl/t510_fnic/lib/ip
```

注意：

1. `create_t510_fnic_aurora_sources.tcl` 文件头已经标明不要手工维护，应该通过导出脚本刷新。
2. BD 内部自动生成的 IP 由 Vivado 在重建工程时重新生成；不要把 `.srcs/sources_1/bd/.../ip/...` 这类 BD 派生 IP 手工加入 `lib/ip`。
3. 导出后建议检查 `git diff`，确认新增/删除的 RTL、XDC、XCI 符合预期。

## 3. 重建 Vivado 工程

默认重建命令：

```bash
hdl/t510_fnic/scripts/recreate_vivado_project.sh
```

默认生成工程：

```text
hdl/t510_fnic/vivado/project/t510_fnic_aurora/
```

对应工程文件：

```text
hdl/t510_fnic/vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr
```

创建带日期或版本号的工程：

```bash
hdl/t510_fnic/scripts/recreate_vivado_project.sh --tag 2026_06_05
```

这会生成：

```text
hdl/t510_fnic/vivado/project/t510_fnic_2026_06_05/
```

也可以手动指定工程名和目录：

```bash
hdl/t510_fnic/scripts/recreate_vivado_project.sh \
  --project-name t510_fnic_recreate_test \
  --project-dir /tmp/t510_fnic_recreate_test
```

每次重建完成后，工程目录下会写入：

```text
project_manifest.txt
```

其中记录工程名、工程目录、tag、git SHA、git dirty/clean 状态和构建时间戳。

## 4. 构建 bitstream

默认构建当前工程：

```bash
hdl/t510_fnic/scripts/build_t510_fnic_aurora_bit.sh
```

构建指定 tag 工程：

```bash
hdl/t510_fnic/scripts/build_t510_fnic_aurora_bit.sh --tag 2026_06_05
```

构建指定工程目录：

```bash
hdl/t510_fnic/scripts/build_t510_fnic_aurora_bit.sh \
  --project-name t510_fnic_recreate_test \
  --project-dir /tmp/t510_fnic_recreate_test
```

## 5. 推荐工作流

1. 在 Vivado GUI 中打开当前工程并修改 block design、IP、fileset 或约束。
2. 保存工程，确认 Vivado 中综合/实现相关设置符合预期。
3. 先导出到 generated 目录：

   ```bash
   hdl/t510_fnic/scripts/export_current_project_scripts.sh
   ```

4. 检查 generated 输出和 `git diff`。
5. 确认无误后应用导出结果：

   ```bash
   hdl/t510_fnic/scripts/export_current_project_scripts.sh --apply
   ```

6. 用临时目录验证重建：

   ```bash
   hdl/t510_fnic/scripts/recreate_vivado_project.sh \
     --project-name t510_fnic_recreate_test \
     --project-dir /tmp/t510_fnic_recreate_test
   ```

7. 如需验证 bitstream，继续构建：

   ```bash
   hdl/t510_fnic/scripts/build_t510_fnic_aurora_bit.sh \
     --project-name t510_fnic_recreate_test \
     --project-dir /tmp/t510_fnic_recreate_test
   ```

8. 重建和构建都通过后，再提交 `scripts/vivado/*.tcl`、`lib/ip/*.xci`、RTL/XDC 和文档改动。
