# NetRadar Dual-Line Metrics Graph & Network Connectivity Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide dual-line trend visualization in NetRadar's HUD graph for Latency plus user-selected Jitter or Packet Loss, and fix false-positive Captive Portal classification by integrating NetworkManager connectivity state with distinct Amber (`#f59e0b`) indicators for "No Internet" and "Captive Portal".

**Architecture:**
Extend `probe.sh` to capture NetworkManager's cached connectivity state (`portal`, `limited`, `full`, `none`). Update `state.luau` to store 60-sample ring buffers for Latency, Jitter, and Packet Loss, and classify status into `NO_INTERNET` vs `CAPTIVE_PORTAL` with Amber `#f59e0b` styling. Enhance `panel.luau` to render dual-line `ui.graph` (`values` & `values2`) with interactive header badges to toggle between Jitter and Loss, and update `widget.luau` to display Amber icons for disconnected/portal states.

**Tech Stack:**
- Luau (Noctalia Plugin API 28)
- Bash (`nmcli`, `ping`, `iproute2`)
- Python 3 / `pytest` (Test harness executed inside `distrobox enter my-distrobox -- pytest`)

## Global Constraints
- Tactical HUD styling: 4px border radius (`radius = 4`), no rounded pill badges (`radius = 99` or `999` forbidden).
- Color tokens: `"#f59e0b"` for `NO_INTERNET` and `CAPTIVE_PORTAL`. Do NOT use green (`"primary"` / `"tertiary"`) for portal or no internet.
- Graph constraints: `ui.graph` supports `values` (primary) and `values2` (secondary) with `color` and `color2`.
- Commands running build/test/python must run inside Distrobox: `distrobox enter my-distrobox -- <cmd>`.

---

### Task 1: Probe Script NetworkManager Connectivity Query & Delimiter Extension

**Files:**
- Modify: `net-radar/probe.sh:23-59`
- Modify: `tests/test_net_radar_probe.py:9-68`

**Interfaces:**
- Produces: 8 pipe-delimited values on stdout:
  `${GW_MS}|${DNS_MS}|${GAME_MS}|${SSID}|${FREQ}|${SIGNAL}|${RATE}|${NM_CONN}`
  where `${NM_CONN}` is one of `"portal"`, `"limited"`, `"full"`, `"none"`, or `"unknown"`.

- [ ] **Step 1: Write the failing probe test**

Update `tests/test_net_radar_probe.py` to assert that `parse_probe_output` handles the 8th `nm_conn` field.

```python
# In tests/test_net_radar_probe.py:
def parse_probe_output(line: str):
    parts = line.strip().split("|")
    if len(parts) < 8:
        return None
    gw_ms = float(parts[0]) if parts[0] and parts[0] != "none" else None
    dns_ms = float(parts[1]) if parts[1] and parts[1] != "none" else None
    game_ms = float(parts[2]) if parts[2] and parts[2] != "none" else None
    ssid = parts[3] if parts[3] and parts[3] != "none" else ""
    freq_mhz = int(parts[4]) if parts[4] and parts[4].isdigit() else 0
    signal_pct = int(parts[5]) if parts[5] and parts[5].isdigit() else 0
    rate_mbps = float(parts[6]) if parts[6] and parts[6] != "none" else 0.0
    nm_conn = parts[7] if len(parts) >= 8 and parts[7] else "unknown"

    return {
        "gw_ms": gw_ms,
        "dns_ms": dns_ms,
        "game_ms": game_ms,
        "ssid": ssid,
        "freq_mhz": freq_mhz,
        "signal_pct": signal_pct,
        "rate_mbps": rate_mbps,
        "nm_conn": nm_conn,
    }
```

Add test cases in `TestNetRadarProbe`:
```python
    def test_parse_probe_output_with_nm_conn(self):
        sample = "1.23|14.5|32.1|Home_5G|5180|84|866.7|full"
        res = parse_probe_output(sample)
        self.assertIsNotNone(res)
        self.assertEqual(res["nm_conn"], "full")

        portal_sample = "1.10|none|none|Hotel_WiFi|2412|60|54|portal"
        res_portal = parse_probe_output(portal_sample)
        self.assertIsNotNone(res_portal)
        self.assertEqual(res_portal["nm_conn"], "portal")

        limited_sample = "1.10|none|none|Home_WiFi|5180|70|300|limited"
        res_limited = parse_probe_output(limited_sample)
        self.assertIsNotNone(res_limited)
        self.assertEqual(res_limited["nm_conn"], "limited")
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_probe.py -v
```
Expected: FAIL because 7-field existing tests fail on `< 8` check, or `nm_conn` is missing in `probe.sh`.

- [ ] **Step 3: Update `net-radar/probe.sh` to extract `nmcli networking connectivity`**

Edit `net-radar/probe.sh` around lines 23-59:
```bash
# Query NetworkManager connectivity state (fast cached query, no active rescan)
NM_CONN=$(nmcli -t networking connectivity 2>/dev/null || echo "unknown")
[ -z "$NM_CONN" ] && NM_CONN="unknown"

wait

GW_MS=$(cat "$GW_TMP" 2>/dev/null)
DNS_MS=$(cat "$DNS_TMP" 2>/dev/null)
GAME_MS=$(cat "$GAME_TMP" 2>/dev/null)

rm -f "$GW_TMP" "$DNS_TMP" "$GAME_TMP"

[ -z "$GW_MS" ] && GW_MS="none"
[ -z "$DNS_MS" ] && DNS_MS="none"
[ -z "$GAME_MS" ] && GAME_MS="none"

SSID="none"
FREQ="0"
SIGNAL="0"
RATE="0"

if [ -n "$WIFI_RAW" ]; then
  IFS=':' read -r _active _ssid _freq _signal _rate <<< "$WIFI_RAW"
  [ -n "$_ssid" ] && SSID="$_ssid"
  _freq_num=$(echo "$_freq" | tr -dc '0-9')
  [ -n "$_freq_num" ] && FREQ="$_freq_num"
  _sig_num=$(echo "$_signal" | tr -dc '0-9')
  [ -n "$_sig_num" ] && SIGNAL="$_sig_num"
  _rate_clean=$(echo "$_rate" | sed -E 's/([0-9.]+).*/\1/')
  [ -n "$_rate_clean" ] && RATE="$_rate_clean"
fi

SSID="${SSID//|/-}"

echo "${GW_MS}|${DNS_MS}|${GAME_MS}|${SSID}|${FREQ}|${SIGNAL}|${RATE}|${NM_CONN}"
```

Update older test samples in `tests/test_net_radar_probe.py` so 8 fields are provided (`|full` / `|none`).

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_probe.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add net-radar/probe.sh tests/test_net_radar_probe.py
git commit -m "feat(net-radar): add NetworkManager connectivity to probe output"
```

---

### Task 2: Localization Strings for `NO_INTERNET` & Dual-Line Graph

**Files:**
- Modify: `net-radar/translations/en.json`
- Modify: `net-radar/translations/id.json`
- Test: `tests/test_net_radar_manifest.py`

**Interfaces:**
- Produces: Localized keys in `en.json` and `id.json`:
  - `widget.status_no_internet`
  - `panel.diag_no_internet`
  - `panel.graph_badge_jitter`
  - `panel.graph_badge_loss`
  - `panel.graph_summary_jitter`
  - `panel.graph_summary_loss`

- [ ] **Step 1: Write test for new translation keys**

In `tests/test_net_radar_manifest.py`, add assertions checking the new required keys:
```python
    def test_required_translation_keys_for_no_internet_and_dual_graph(self):
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        required_keys = [
            "widget.status_no_internet",
            "panel.diag_no_internet",
            "panel.graph_badge_jitter",
            "panel.graph_badge_loss",
            "panel.graph_summary_jitter",
            "panel.graph_summary_loss",
        ]
        for key in required_keys:
            self.assertTrue(has_key_path(en, key), f"Missing key '{key}' in en.json")
            self.assertTrue(has_key_path(id_lang, key), f"Missing key '{key}' in id.json")
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_manifest.py -v
```
Expected: FAIL on missing keys.

- [ ] **Step 3: Add keys to `en.json` and `id.json`**

In `net-radar/translations/en.json`:
- Under `widget`:
  `"status_no_internet": "NO INTERNET (Local Only)",`
- Under `panel`:
  `"diag_no_internet": "Connected to local router, but no internet access.",`
  `"graph_badge_jitter": "Jitter: ±{jitter}ms",`
  `"graph_badge_loss": "Loss: {loss}%",`
  `"graph_summary_jitter": "RTT: {min}-{max}ms (avg {avg}ms) • Jitter: ±{secMin}-±{secMax}ms (avg ±{secAvg}ms)",`
  `"graph_summary_loss": "RTT: {min}-{max}ms (avg {avg}ms) • Loss: {secAvg}% (peak {secMax}%)",`

In `net-radar/translations/id.json`:
- Under `widget`:
  `"status_no_internet": "TANPA INTERNET (Hanya Lokal)",`
- Under `panel`:
  `"diag_no_internet": "Terhubung ke router lokal, tetapi tidak ada akses internet luar.",`
  `"graph_badge_jitter": "Jitter: ±{jitter}ms",`
  `"graph_badge_loss": "Loss: {loss}%",`
  `"graph_summary_jitter": "RTT: {min}-{max}ms (avg {avg}ms) • Jitter: ±{secMin}-±{secMax}ms (avg ±{secAvg}ms)",`
  `"graph_summary_loss": "RTT: {min}-{max}ms (avg {avg}ms) • Loss: {secAvg}% (peak {secMax}%)",`

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_manifest.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add net-radar/translations/en.json net-radar/translations/id.json tests/test_net_radar_manifest.py
git commit -m "feat(net-radar): add translation keys for no-internet status and dual-line graph"
```

---

### Task 3: State Management, Dual Ring Buffers & Accurate Status Classification

**Files:**
- Modify: `net-radar/state.luau`
- Modify: `tests/test_net_radar_state.py`
- Modify: `tests/test_net_radar_diagnostics.py`

**Interfaces:**
- Consumes: 8-field stdout from `probe.sh`.
- Produces in `state.luau`:
  - `state.jitterHistory`: `{ number }` (60 values)
  - `state.lossHistory`: `{ number }` (60 values)
  - `state.secondaryGraphMode`: `"jitter"` | `"loss"`
  - `state.nmConn`: string
  - `state.getStatus()`: returns `"OPTIMAL"`, `"FAIR"`, `"POOR"`, `"NO_INTERNET"`, `"CAPTIVE_PORTAL"`, or `"OFFLINE"`
  - `state.getGraphValues()`: returns `(primaryValues, secondaryValues, minRtt, avgRtt, maxRtt, secMin, secAvg, secMax)`
  - `state.getDiagnostics()`: returns Amber `"#f59e0b"` for both `NO_INTERNET` and `CAPTIVE_PORTAL`.

- [ ] **Step 1: Write failing tests in `tests/test_net_radar_state.py` and `tests/test_net_radar_diagnostics.py`**

Update `NetRadarMetricsSimulator` in `tests/test_net_radar_state.py`:
- Add `self.jitter_history = []`, `self.loss_history = []`, `self.secondary_graph_mode = "jitter"`, `self.nm_conn = "unknown"`.
- Support 8th parameter in `process_probe`.
- Update `get_status`:
  - If `gw_ms` is None and `dns_ms` is None: `"OFFLINE"`
  - If `self.nm_conn == "portal"`: `"CAPTIVE_PORTAL"`
  - If `gw_ms` is not None and `dns_ms` is None and `game_ms` is None:
    - Return `"CAPTIVE_PORTAL"` if `self.nm_conn == "portal"` else `"NO_INTERNET"`
- Update `get_graph_values` to return primary and secondary series.
- Add test methods:
  - `test_status_classification_no_internet_vs_portal`:
    - `gw=1.2, dns=none, game=none, nm_conn=limited` $\rightarrow$ `NO_INTERNET`
    - `gw=1.2, dns=none, game=none, nm_conn=portal` $\rightarrow$ `CAPTIVE_PORTAL`
  - `test_dual_graph_values_normalization`:
    - Tests normalization of secondary series for both `"jitter"` and `"loss"` modes.

In `tests/test_net_radar_diagnostics.py`:
- Update `evaluate` to check `nm_conn`:
  - If `gw_ms` and `not dns_ms` and `not game_ms`:
    - If `nm_conn == "portal"`: `tr("panel.diag_captive_portal")`, `"alert-triangle"`, `"#f59e0b"`
    - Else: `tr("panel.diag_no_internet")`, `"alert-triangle"`, `"#f59e0b"`
- Update assertions expecting `"tertiary"` for captive portal to expect `"#f59e0b"`.

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_state.py tests/test_net_radar_diagnostics.py -v
```
Expected: FAIL on `state.luau` missing new buffers/logic.

- [ ] **Step 3: Implement state updates in `net-radar/state.luau`**

In `net-radar/state.luau`:
1. Initialize buffers:
```luau
  history = {} :: { number },
  jitterHistory = {} :: { number },
  lossHistory = {} :: { number },
  secondaryGraphMode = "jitter" :: "jitter" | "loss",
  nmConn = "unknown",
```
Fill all three history tables with 60 default values (`-1` for history, `0.0` for jitterHistory and lossHistory).

2. In `state.processProbe(rawOutput: string)`:
Parse 8 parts:
```luau
  if #parts < 7 then
    return
  end

  state.gwMs = (parts[1] ~= "none") and tonumber(parts[1]) or nil
  state.dnsMs = (parts[2] ~= "none") and tonumber(parts[2]) or nil
  state.gameMs = (parts[3] ~= "none") and tonumber(parts[3]) or nil
  state.ssid = (parts[4] ~= "none") and parts[4] or ""
  state.freqMhz = tonumber(parts[5]) or 0
  state.signalPct = tonumber(parts[6]) or 0
  state.rateMbps = tonumber(parts[7]) or 0.0
  state.nmConn = parts[8] or "unknown"

  -- Push into fixed ring buffer for latency
  table.remove(state.history, 1)
  table.insert(state.history, state.gameMs or -1)
  state.sampleCount = state.sampleCount + 1

  -- RFC 3550 Jitter
  if state.gameMs then
    if state.prevGameMs then
      local diff = math.abs(state.gameMs - state.prevGameMs)
      state.jitter = state.jitter + (diff - state.jitter) / 16.0
    end
    state.prevGameMs = state.gameMs
  end
  table.remove(state.jitterHistory, 1)
  table.insert(state.jitterHistory, state.jitter)

  -- Packet loss over rolling window
  local windowSize = math.min(state.sampleCount, state.LOSS_WINDOW)
  local dropped = 0
  local total = 0
  local startIndex = math.max(1, state.BUFFER_SIZE - windowSize + 1)
  for i = startIndex, state.BUFFER_SIZE do
    total = total + 1
    if state.history[i] < 0 then
      dropped = dropped + 1
    end
  end
  state.lossPct = total > 0 and (dropped / total) * 100.0 or 0.0
  table.remove(state.lossHistory, 1)
  table.insert(state.lossHistory, state.lossPct)
```

3. Update `state.getStatus()`:
```luau
function state.getStatus(): string
  if not state.gwMs and not state.dnsMs then
    return "OFFLINE"
  end
  if state.nmConn == "portal" then
    return "CAPTIVE_PORTAL"
  end
  if state.gwMs and not state.dnsMs and not state.gameMs then
    return "NO_INTERNET"
  end
  if not state.gameMs then
    return "POOR"
  end

  if state.gameMs < 60.0 and state.jitter < 10.0 and state.lossPct == 0.0 then
    return "OPTIMAL"
  end
  if state.gameMs <= 120.0 and state.jitter <= 25.0 and state.lossPct <= 5.0 then
    return "FAIR"
  end
  return "POOR"
end
```

4. Update `state.getGraphValues()`:
```luau
function state.getGraphValues(): ({ number }, { number }, number, number, number, number, number, number)
  local primaryValues = {}
  local secondaryValues = {}
  local minMs = 999999.0
  local maxMs = 0.0
  local sumMs = 0.0
  local count = 0

  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v >= 0 then
      if v < minMs then minMs = v end
      if v > maxMs then maxMs = v end
      sumMs = sumMs + v
      count = count + 1
    end
  end

  local ceiling = math.max(100.0, maxMs * 1.25)
  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v < 0 then
      table.insert(primaryValues, 0.0)
    else
      table.insert(primaryValues, math.min(1.0, math.max(0.0, v / ceiling)))
    end
  end

  local avgMs = count > 0 and (sumMs / count) or 0.0
  if minMs > 999990.0 then minMs = 0.0 end

  local secMin = 999999.0
  local secMax = 0.0
  local secSum = 0.0
  local secCount = 0

  if state.secondaryGraphMode == "jitter" then
    for i = 1, state.BUFFER_SIZE do
      local j = state.jitterHistory[i] or 0.0
      if j < secMin then secMin = j end
      if j > secMax then secMax = j end
      secSum = secSum + j
      secCount = secCount + 1
    end
    local jCeiling = math.max(15.0, secMax * 1.3)
    for i = 1, state.BUFFER_SIZE do
      local j = state.jitterHistory[i] or 0.0
      table.insert(secondaryValues, math.min(1.0, math.max(0.0, j / jCeiling)))
    end
  else -- "loss"
    for i = 1, state.BUFFER_SIZE do
      local l = state.lossHistory[i] or 0.0
      if l < secMin then secMin = l end
      if l > secMax then secMax = l end
      secSum = secSum + l
      secCount = secCount + 1
    end
    for i = 1, state.BUFFER_SIZE do
      local l = state.lossHistory[i] or 0.0
      table.insert(secondaryValues, math.min(1.0, math.max(0.0, l / 100.0)))
    end
  end

  local secAvg = secCount > 0 and (secSum / secCount) or 0.0
  if secMin > 999990.0 then secMin = 0.0 end

  return primaryValues, secondaryValues, minMs, avgMs, maxMs, secMin, secAvg, secMax
end
```

5. Update `state.getDiagnostics()`:
```luau
  if not state.gwMs and not state.dnsMs then
    return tr("panel.diag_offline"), "alert-triangle", "outline"
  end

  if state.nmConn == "portal" then
    return tr("panel.diag_captive_portal"), "alert-triangle", "#f59e0b"
  end

  if state.gwMs and not state.dnsMs and not state.gameMs then
    return tr("panel.diag_no_internet"), "alert-triangle", "#f59e0b"
  end
```

6. Include `jitterHistory`, `lossHistory`, `secondaryGraphMode`, `nmConn` in `noctalia.state.set` and `.watch`.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_state.py tests/test_net_radar_diagnostics.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add net-radar/state.luau tests/test_net_radar_state.py tests/test_net_radar_diagnostics.py
git commit -m "feat(net-radar): add dual ring buffers and separate NO_INTERNET from CAPTIVE_PORTAL"
```

---

### Task 4: Tactical HUD Panel Dual-Line Graph & Interactive Badge Switcher

**Files:**
- Modify: `net-radar/panel.luau`
- Modify: `tests/test_net_radar_panel.py`

**Interfaces:**
- Consumes: `state.getGraphValues()`, `state.secondaryGraphMode`, `state.getStatus()`.
- Produces: Dual-line `ui.graph` rendering with interactive toggle badges `[ Jitter ]` & `[ Loss ]`, Amber `#f59e0b` styling for `NO_INTERNET` & `CAPTIVE_PORTAL`.

- [ ] **Step 1: Write failing panel tests in `tests/test_net_radar_panel.py`**

Add assertions:
- Assert `values2` and `color2` exist in `panel.luau`.
- Assert `"#f59e0b"` is present for `NO_INTERNET` and `CAPTIVE_PORTAL`.
- Assert badge switches `state.secondaryGraphMode`.
- Assert `renderSegmentedMeter` handles `NO_INTERNET`.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_panel.py -v
```
Expected: FAIL.

- [ ] **Step 3: Update `net-radar/panel.luau`**

1. In `renderSegmentedMeter(status: string)`:
```luau
  if status == "OPTIMAL" then
    activeBars = 5
    color = "primary"
  elseif status == "FAIR" then
    activeBars = 3
    color = "tertiary"
  elseif status == "POOR" then
    activeBars = 1
    color = "error"
  elseif status == "NO_INTERNET" or status == "CAPTIVE_PORTAL" then
    activeBars = 2
    color = "#f59e0b"
  else
    activeBars = 0
    color = "outline"
  end
```

2. In `renderPanel()`:
Map `statusColor` and `statusText`:
```luau
  if status == "OPTIMAL" then
    statusColor = "primary"
    statusText = tr("widget.status_optimal")
  elseif status == "FAIR" then
    statusColor = "tertiary"
    statusText = tr("widget.status_fair")
  elseif status == "POOR" then
    statusColor = "error"
    statusText = tr("widget.status_poor")
  elseif status == "NO_INTERNET" then
    statusColor = "#f59e0b"
    statusText = tr("widget.status_no_internet")
  elseif status == "CAPTIVE_PORTAL" then
    statusColor = "#f59e0b"
    statusText = tr("widget.status_captive_portal")
  else
    statusColor = "outline"
    statusText = tr("widget.status_offline")
  end
```

3. Call updated `state.getGraphValues()`:
```luau
  local primaryValues, secondaryValues, minRtt, avgRtt, maxRtt, secMin, secAvg, secMax = state.getGraphValues()
```

4. Construct interactive header badges:
```luau
  local isJitter = (state.secondaryGraphMode == "jitter")
  local jitterBadgeText = tr("panel.graph_badge_jitter", { jitter = string.format("%.1f", state.jitter) })
  local lossBadgeText = tr("panel.graph_badge_loss", { loss = string.format("%.1f", state.lossPct) })

  local badgeJitter = ui.box({
    fill = isJitter and "surface_variant" or "surface",
    border = isJitter and "#38bdf8" or "outline",
    borderWidth = 1,
    radius = 4,
    paddingH = 6,
    paddingV = 2,
    onClick = function()
      state.secondaryGraphMode = "jitter"
      throttledRender()
    end,
  }, {
    ui.label({
      text = jitterBadgeText,
      fontSize = 9,
      fontWeight = isJitter and "bold" or "normal",
      color = isJitter and "#38bdf8" or "on_surface",
      opacity = isJitter and 1.0 or 0.6,
    }),
  })

  local badgeLoss = ui.box({
    fill = not isJitter and "surface_variant" or "surface",
    border = not isJitter and "#ef4444" or "outline",
    borderWidth = 1,
    radius = 4,
    paddingH = 6,
    paddingV = 2,
    onClick = function()
      state.secondaryGraphMode = "loss"
      throttledRender()
    end,
  }, {
    ui.label({
      text = lossBadgeText,
      fontSize = 9,
      fontWeight = not isJitter and "bold" or "normal",
      color = (not isJitter and state.lossPct > 0) and "#ef4444" or "on_surface",
      opacity = not isJitter and 1.0 or 0.6,
    }),
  })
```

5. In `graphCard`:
```luau
  local secColor = isJitter and "#38bdf8" or "#ef4444"

  local summaryText = isJitter and tr("panel.graph_summary_jitter", {
    min = string.format("%.0f", minRtt),
    max = string.format("%.0f", maxRtt),
    avg = string.format("%.0f", avgRtt),
    secMin = string.format("%.1f", secMin),
    secMax = string.format("%.1f", secMax),
    secAvg = string.format("%.1f", secAvg),
  }) or tr("panel.graph_summary_loss", {
    min = string.format("%.0f", minRtt),
    max = string.format("%.0f", maxRtt),
    avg = string.format("%.0f", avgRtt),
    secAvg = string.format("%.1f", secAvg),
    secMax = string.format("%.1f", secMax),
  })

  local graphCard = ui.column({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    padding = 10,
    gap = 6,
  }, {
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.label({
        text = tr("panel.graph_title"),
        fontSize = 10,
        fontWeight = "semibold",
        opacity = 0.7,
      }),
      ui.row({
        gap = 4,
        align = "center",
      }, {
        badgeJitter,
        badgeLoss,
      }),
    }),
    ui.graph({
      height = 70,
      values = primaryValues,
      values2 = secondaryValues,
      color = statusColor,
      color2 = secColor,
      lineWidth = 2,
      fillOpacity = 0.15,
    }),
    ui.label({
      text = summaryText,
      fontSize = 9,
      opacity = 0.65,
    }),
  })
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_panel.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add net-radar/panel.luau tests/test_net_radar_panel.py
git commit -m "feat(net-radar): add dual-line graph rendering and interactive metric toggles"
```

---

### Task 5: Status Bar Widget Amber Color & Localized Tooltips

**Files:**
- Modify: `net-radar/widget.luau`
- Modify: `tests/test_net_radar_widget.py`

**Interfaces:**
- Consumes: `state.getStatus()`.
- Produces: Amber `"#f59e0b"` icon & text for `NO_INTERNET` and `CAPTIVE_PORTAL`.

- [ ] **Step 1: Write failing widget tests in `tests/test_net_radar_widget.py`**

Add test assertions:
- Verify `"#f59e0b"` is used in `widget.luau` when status is `NO_INTERNET` or `CAPTIVE_PORTAL`.
- Verify `status_no_internet` is referenced.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_widget.py -v
```
Expected: FAIL.

- [ ] **Step 3: Update `net-radar/widget.luau`**

In `updateWidget()`:
```luau
  local status = state.getStatus()
  local statusColor = "primary"

  if status == "OPTIMAL" then
    statusColor = "primary"
  elseif status == "FAIR" then
    statusColor = "tertiary"
  elseif status == "POOR" then
    statusColor = "error"
  elseif status == "NO_INTERNET" or status == "CAPTIVE_PORTAL" then
    statusColor = "#f59e0b"
  else -- OFFLINE
    statusColor = "outline"
  end
```

In tooltip generation:
```luau
  local statusKey = "widget.status_" .. string.lower(status)
  local statusLabel = tr(statusKey)
  if statusLabel == statusKey then
    statusLabel = status
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar_widget.py -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add net-radar/widget.luau tests/test_net_radar_widget.py
git commit -m "feat(net-radar): use amber color for NO_INTERNET and CAPTIVE_PORTAL in bar widget"
```

---

### Task 6: Full Integration Test Suite Verification

**Files:**
- Verify: `tests/test_net_radar*.py`

- [ ] **Step 1: Run complete net-radar test suite inside Distrobox**

Run:
```bash
distrobox enter my-distrobox -- pytest tests/test_net_radar*.py -v
```
Expected: All 50+ tests pass with zero failures or warnings.

- [ ] **Step 2: Run git diff and status check**

Run:
```bash
git status
git log -n 5 --oneline
```
Expected: Working tree clean, well-formatted commits matching project style.
