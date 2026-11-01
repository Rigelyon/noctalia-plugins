# Smart Diagnostic Banner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a Smart Multi-Issue Diagnostic Synthesis Engine in `net-radar` that evaluates network metrics, handles weak Wi-Fi baselines intelligently without false alarms, synthesizes dual issues into coherent sentences, and updates the Tactical HUD banner dynamically.

**Architecture:** A rule-based diagnostic classifier in `state.luau` analyzes telemetry (`gwMs`, `dnsMs`, `gameMs`, `jitter`, `lossPct`, `signalPct`, `freqMhz`), prioritizes findings via a 3-tier severity hierarchy, synthesizes up to 2 issues, and returns `(text, glyph, colorRole)` consumed directly by `diagBanner` in `panel.luau`.

**Tech Stack:** Luau (Noctalia UI runtime), Bash (`probe.sh`), Python 3 / Pytest (test suite), Distrobox (`my-distrobox`).

## Global Constraints

- All development, pytest, and linting commands must run inside Distrobox: `distrobox enter my-distrobox -- <command>`.
- Color roles must adhere strictly to Material Design 3 tokens supported by Noctalia: `"primary"`, `"tertiary"`, `"error"`, `"outline"`, `"surface"`. Do NOT use `"warning"` or `"destructive"`.
- Backward compatibility: Existing `state.getStatus()` and widget bar telemetry must remain intact.
- Both Indonesian (`id.json`) and English (`en.json`) translations must be kept 100% in sync.

---

### Task 1: Translation Dictionaries for Dynamic Diagnostic Phrases

**Files:**
- Modify: `net-radar/translations/en.json`
- Modify: `net-radar/translations/id.json`
- Test: `tests/test_net_radar_manifest.py`

**Interfaces:**
- Consumes: Existing keys in `en.json` and `id.json`
- Produces: New translation keys under `panel`:
  - `diag_wired_optimal`, `diag_weak_signal_stable`, `diag_isp_loss`, `diag_isp_lag`, `diag_local_bufferbloat`, `diag_high_jitter`, `diag_wifi_weak_unstable`, `diag_synthesis_connector`.

- [ ] **Step 1: Write test for new translation keys**

Update `tests/test_net_radar_manifest.py` to assert that all new diagnostic keys exist and have non-empty values in both `en.json` and `id.json`.

```python
# Add to tests/test_net_radar_manifest.py
def test_diagnostic_translation_keys():
    import json
    en_path = "net-radar/translations/en.json"
    id_path = "net-radar/translations/id.json"
    with open(en_path, "r", encoding="utf-8") as f:
        en = json.load(f)
    with open(id_path, "r", encoding="utf-8") as f:
        id_data = json.load(f)

    required_keys = [
        "diag_offline",
        "diag_captive_portal",
        "diag_optimal",
        "diag_wired_optimal",
        "diag_weak_signal_stable",
        "diag_isp_loss",
        "diag_isp_lag",
        "diag_local_bufferbloat",
        "diag_high_jitter",
        "diag_wifi_weak_unstable",
        "diag_synthesis_connector",
    ]

    for k in required_keys:
        assert k in en["panel"], f"Missing {k} in en.json"
        assert k in id_data["panel"], f"Missing {k} in id.json"
        assert len(en["panel"][k]) > 0
        assert len(id_data["panel"][k]) > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_manifest.py -k test_diagnostic_translation_keys -v`
Expected: FAIL with missing key assertions.

- [ ] **Step 3: Update `en.json` and `id.json` with new keys**

In `net-radar/translations/en.json`, add:
```json
    "diag_wired_optimal": "Ethernet wired connection is pristine and stable.",
    "diag_weak_signal_stable": "Wi-Fi signal is moderate ({signal}%), but link and game routing remain stable.",
    "diag_isp_loss": "ISP or external routing experiencing packet loss ({loss}%).",
    "diag_isp_lag": "Local router is fast, but ISP game routing latency is high ({ms}ms).",
    "diag_local_bufferbloat": "High latency to local gateway ({ms}ms). Potential home network congestion.",
    "diag_high_jitter": "Elevated jitter (±{jitter}ms) causing micro-stutter.",
    "diag_wifi_weak_unstable": "Weak Wi-Fi signal ({signal}%) causing packet drops.",
    "diag_synthesis_connector": "{first}, alongside {second}."
```

In `net-radar/translations/id.json`, add:
```json
    "diag_wired_optimal": "Koneksi kabel LAN sangat prima dan stabil.",
    "diag_weak_signal_stable": "Sinyal Wi-Fi sedang ({signal}%), namun koneksi router dan game tetap stabil.",
    "diag_isp_loss": "Jalur ISP atau server luar mengalami packet loss ({loss}%).",
    "diag_isp_lag": "Koneksi router lokal lancar, tapi latensi server game ISP tinggi ({ms}ms).",
    "diag_local_bufferbloat": "Latensi ke router lokal membengkak ({ms}ms). Kemungkinan bufferbloat jaringan rumah.",
    "diag_high_jitter": "Jitter tinggi (±{jitter}ms) berpotensi memicu stutter.",
    "diag_wifi_weak_unstable": "Sinyal Wi-Fi lemah ({signal}%) memicu paket hilang.",
    "diag_synthesis_connector": "{first}, serta {second}."
```

- [ ] **Step 4: Run test to verify it passes**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_manifest.py -k test_diagnostic_translation_keys -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_net_radar_manifest.py net-radar/translations/en.json net-radar/translations/id.json
git commit -m "feat(net-radar): add dynamic diagnostic banner translation keys"
```

---

### Task 2: Diagnostic Evaluation and Synthesis Engine in `state.luau`

**Files:**
- Create: `tests/test_net_radar_diagnostics.py`
- Modify: `net-radar/state.luau`

**Interfaces:**
- Consumes: `state.gwMs`, `state.dnsMs`, `state.gameMs`, `state.jitter`, `state.lossPct`, `state.ssid`, `state.freqMhz`, `state.signalPct`
- Produces: `state.getDiagnostics(): (string, string, string)` returning `(diagKeyOrText, glyphName, colorRole)`

- [ ] **Step 1: Write the failing tests in `tests/test_net_radar_diagnostics.py`**

Create `tests/test_net_radar_diagnostics.py` verifying:
1. Offline state produces `diag_offline`, `alert-triangle`, `outline`.
2. Captive portal produces `diag_captive_portal`, `alert-triangle`, `tertiary`.
3. Weak Wi-Fi with good ping/loss produces `diag_weak_signal_stable`, `info-circle`, `primary`.
4. High ISP packet loss produces `diag_isp_loss`, `alert-triangle`, `error`.
5. Local bufferbloat produces `diag_local_bufferbloat`, `alert-circle`, `tertiary`.
6. Dual issue synthesis (e.g. ISP loss + weak signal) returns combined clauses and `error` color.
7. Wired Ethernet optimal returns `diag_wired_optimal`, `check-circle`, `primary`.

- [ ] **Step 2: Run test to verify it fails**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_diagnostics.py -v`
Expected: FAIL (file or function does not exist yet).

- [ ] **Step 3: Implement `state.getDiagnostics()` in `net-radar/state.luau`**

Add `state.getDiagnostics()` in `net-radar/state.luau` implementing:
1. Tier 1 checks: `not state.gwMs and not state.dnsMs` -> OFFLINE. `state.gwMs and not state.dnsMs and not state.gameMs` -> CAPTIVE_PORTAL.
2. Finding collectors:
   - Acute issues:
     - `state.lossPct >= 10.0` or `not state.gameMs`: Critical loss
     - `state.lossPct >= 1.0`: Moderate loss
     - `state.gwMs and state.gwMs > 30.0`: Local bufferbloat
     - `state.gwMs and state.gwMs <= 15.0 and state.gameMs and state.gameMs > 120.0`: ISP routing lag
     - `state.jitter > 15.0`: High jitter
   - Environmental issues:
     - `state.ssid ~= "" and state.signalPct > 0 and state.signalPct < 40`:
       - If gateway ping is good ($< 20\text{ ms}$) and loss is $0\%$, record as `WEAK_SIGNAL_STABLE` (Severity: Info, color `primary`).
       - If gateway ping is bad or loss $> 0\%$, record as `WEAK_SIGNAL_UNSTABLE` (Severity: Warning, color `tertiary`).
     - `state.ssid == ""`: Wired connection.
3. Synthesizer:
   - Combine at most 2 findings using `diag_synthesis_connector`.
   - Select glyph (`alert-triangle`, `alert-circle`, `info-circle`, `check-circle`).
   - Select color role (`error`, `tertiary`, `primary`, `outline`).

- [ ] **Step 4: Run test to verify it passes**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_diagnostics.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_net_radar_diagnostics.py net-radar/state.luau
git commit -m "feat(net-radar): implement smart diagnostic synthesis engine in state"
```

---

### Task 3: Tactical HUD Integration in `panel.luau`

**Files:**
- Modify: `net-radar/panel.luau:182-206`
- Modify: `tests/test_net_radar_panel.py`

**Interfaces:**
- Consumes: `state.getDiagnostics(): (string, string, string)`
- Produces: Dynamic `diagBanner` in `renderPanel()`

- [ ] **Step 1: Write test in `tests/test_net_radar_panel.py`**

Update `tests/test_net_radar_panel.py` to assert that `panel.luau` calls `state.getDiagnostics()` and applies the returned glyph and color to `diagBanner`.

- [ ] **Step 2: Run test to verify it fails**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_panel.py -k test_panel_diagnostic_banner -v`
Expected: FAIL.

- [ ] **Step 3: Update `renderPanel()` in `net-radar/panel.luau`**

Replace static diagnostic banner logic in `panel.luau`:
```luau
  -- Get dynamic diagnostic synthesis from state
  local diagText, diagGlyph, diagColor = state.getDiagnostics()
  if noctalia and noctalia.tr then
    -- If state returned a raw translation key or parameterized text
    diagText = state.formatDiagnosticText(diagText)
  end

  -- Diagnostic Callout Banner
  local diagBanner = ui.row({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    paddingH = 10,
    paddingV = 8,
    align = "center",
    gap = 8,
  }, {
    ui.glyph({
      name = diagGlyph,
      size = 14,
      color = diagColor,
    }),
    ui.label({
      text = diagText,
      fontSize = 11,
      color = "on_surface",
      opacity = 0.85,
      flexGrow = 1,
    }),
  })
```

- [ ] **Step 4: Run test to verify it passes**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_panel.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_net_radar_panel.py net-radar/panel.luau
git commit -m "feat(net-radar): connect smart diagnostic synthesis to HUD banner"
```

---

### Task 4: Full Regression and Live Verification

**Files:**
- Test: All `tests/test_net_radar_*.py`

**Interfaces:**
- Consumes: Complete test suite

- [ ] **Step 1: Run full test suite in Distrobox**

Run: `distrobox enter my-distrobox -- pytest tests/test_net_radar_*.py -v`
Expected: All tests PASS.

- [ ] **Step 2: Live plugin reload check in running Noctalia**

Trigger retest or state update and inspect `~/.local/state/noctalia/noctalia.log` for any warnings or errors.

- [ ] **Step 3: Commit integration updates**

```bash
git commit --allow-empty -m "chore(net-radar): verify smart diagnostic synthesis engine integration"
```
