# IQ Path V2 Candidate

This is a stability-first alternative to the current:

- `t510_ai_iq_capture`
- IQ-related logic inside `chdr_epid_loopback`

New candidate files:

- `t510_ai/lib/t510_ai_radio_ctrl/iq_framework/t510_ai_iq_capture_v2.v`
- `t510_ai/lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth/chdr_iq_bridge_v2.sv`

## Design intent

- Split "capture/stop policy" and "CHDR packetization" into two independent blocks.
- Add explicit `capture_idle/stop_done` and `idle/stop_done` visibility.
- Remove per-packet RAM storage from the CHDR IQ bridge.
- Make `mode_exit` behave as "stop at a packet boundary" instead of "clear everything immediately".

## Current integration in the tree

The current working-tree modifications use this transition shape:

1. Keep `iq_framework_wrapper` alive for TX/timekeeper compatibility.
2. Its RX outputs are redirected to `legacy_iq_user_bus_rx_*` and ignored.
3. Add `iq_framework_rx_wrapper_v2` as the active IQ capture path.
4. Replace top-level `chdr_epid_loopback` instantiation with `chdr_epid_split_v2`.
5. `chdr_epid_split_v2` keeps the original CTRL/source loopback path inside `chdr_epid_loopback`, but routes IQ through `chdr_iq_bridge_v2`.

Touched top/project files:

- `t510_ai/lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth/t510_ai_100g_full_system_top.sv`
- `t510_ai/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.xpr`
- `t510_ai/vivado/project/t510_ai_100g_full_system/t510_ai_100g_full_system.runs/synth_1/t510_ai_100g_full_system_top.tcl`

## Main tradeoff

`chdr_iq_bridge_v2` is intentionally conservative. It is simpler to reason about, but it is not tuned for maximum throughput yet. If this path proves stable on board, the next step should be adding a small ping-pong payload buffer so it can accept IQ data while the previous 512-bit beat is being transmitted.

## Verification status

Smoke simulation passed with Vivado XSim using:

- `run_tb_iq_path_v2_smoke.sh`

The smoke test covers:

- `iq_framework_rx_wrapper_v2 -> chdr_epid_split_v2` end-to-end packet flow
- CHDR packet emission
- stop-to-idle behavior

It does not yet prove full top-level timing closure or board-level sustained throughput.

## Why this may help your record issue

- `mode_exit` no longer means "mid-flight clear".
- Stop completion becomes observable.
- The IQ CHDR bridge no longer carries the control/source test payload responsibilities.
- The packetizer no longer depends on a large inferred packet RAM.
