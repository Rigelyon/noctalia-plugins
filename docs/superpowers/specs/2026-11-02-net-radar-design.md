# NetRadar (`rigelyon/net-radar`) Design Specification

- **Plugin ID**: `rigelyon/net-radar`
- **Plugin Directory**: `net-radar/`
- **Target Platform**: Noctalia Shell (Wayland / Hyprland & General Linux Desktops)
- **Plugin API Version**: 28
- **Date**: 2026-11-02
- **Author**: rigelyon

---

## 1. Executive Summary & Problem Statement

Users who frequently rely on surrounding or public Wi-Fi networks often face a deceptive problem: the desktop Wi-Fi indicator shows full signal strength ("Connected to Internet"), but real-world responsiveness is abysmal. Regular web browsing might feel acceptable, but online games suffer severe stutter, rubberbanding, or disconnects.

Existing solutions in Noctalia and general desktop tools fall short:
1. **Passive Bandwidth Monitors (Download/Upload Speed)**: They only report current throughput (KB/s or MB/s). An idle connection shows 0 KB/s, giving zero clue whether a game will lag or drop packets before starting a match.
2. **Traditional Speed Tests**: They saturate bandwidth to measure burst throughput (Mbps), which eats mobile/tethering quota, takes 15–30 seconds, and does not monitor continuous real-time jitter, packet loss, or micro-spikes.
3. **Ambiguity of Failure Root Causes**: Users cannot tell whether the issue is local Wi-Fi congestion (2.4 GHz channel interference, distance from router) or upstream ISP / game server routing degradation.

### Core Objectives
1. **Lightweight Hybrid Probing**: Background micro-probing (1 ICMP packet ~64 bytes per interval) that measures Latency, Jitter (RFC 3550), and Packet Loss % without consuming network quota.
2. **Multi-Target Diagnostics**:
   - **Local Gateway (Router)**: Identifies local Wi-Fi channel/interference degradation.
   - **Public Anycast DNS (`1.1.1.1` / `8.8.8.8`)**: Verifies general internet uplink health and captive portal detection.
   - **Regional Game Server Endpoint (SEA/Singapore, Tokyo, etc.)**: Assesses actual competitive gaming routing.
3. **Wi-Fi Physical Link Health**: Gathers physical Wi-Fi metrics via `nmcli` or `iw` (SSID, 2.4 GHz vs 5 GHz band, signal dBm, link bitrate Mbps) to pinpoint local RF issues.
4. **Strict Noctalia Luau CPU Budget Compliance**:
   - Single-command probing combining all checks into one non-blocking subprocess.
   - Adaptive polling (5s idle, 2s active in panel, 10s backoff when offline).
   - Fixed-size circular buffer (60 points) to avoid Luau GC churn.
   - Render throttling (>= 100ms) to prevent Luau instruction budget exhaustion.
5. **Clean Minimalist Bar & Tactical HUD Panel**:
   - **Bar Widget**: Icon-only mode by default (`show_text_in_bar = false`), dynamic glyph and status tinting with rich hover tooltip.
   - **Panel**: Tactical HUD aesthetic with sharp/subtle 4px borders (no rounded pills), real-time `ui.graph` streaming latency/jitter history, segmented signal meter, and smart diagnostic callouts.

---

## 2. Architecture & File Structure

```text
net-radar/
├── plugin.toml            # Manifest: metadata, settings, widget, panel entries
├── widget.luau            # Status bar widget (reactive glyph, color tint, tooltip)
├── panel.luau             # Popup HUD panel (telemetry header, ui.graph, breakdown, wifi)
├── state.luau             # Reactive state management, rolling buffer, jitter/loss calculation
├── probe.sh               # Lightweight parallel micro-probe helper script (executable)
├── presets.luau           # Regional game server endpoint registry (SEA, Tokyo, US, Custom)
├── README.md              # Plugin documentation, screenshots, and setup guide
├── thumbnail.webp         # Catalog card artwork for Noctalia plugin store
└── translations/
    ├── en.json            # English localization
    └── id.json            # Indonesian localization
```

---

## 3. Luau CPU Budget & Performance Strategy

Noctalia executes plugin Luau code within cooperative instruction budgets per callback. Heavy string manipulation, repeated `render()` invocations, or frequent subprocess spawning cause `Luau CPU budget exhaustion` warnings and compositor frame drops.

### Optimization Rules
1. **Single Compact Subprocess (`probe.sh`)**:
   Instead of launching 4 separate asynchronous commands for gateway ping, dns ping, game ping, and Wi-Fi query, `probe.sh` runs them concurrently in background subshells and outputs a single pipe-delimited string:
   ```text
   gw_ms|dns_ms|game_ms|ssid|freq_mhz|signal_pct|rate_mbps
   ```
   Luau simply splits this single line using simple string slicing, avoiding regex overhead.
2. **Adaptive Polling Intervals**:
   - **Background / Idle (Panel Closed)**: Polls every **5 seconds** (configurable 2–30s). `widget.luau` performs dirty checking on `(status, glyph)` and updates the bar only on state changes.
   - **Active (Panel Open)**: Polls every **2 seconds** (configurable 1–10s) to keep `ui.graph` responsive.
   - **Offline Backoff**: Polls every **10 seconds** when disconnected or no default route exists.
3. **Fixed-Size Ring Buffer**:
   The 60-sample latency history is stored in a pre-allocated table of size 60 with a head pointer. Overwriting existing slots eliminates table resize and GC pressure.
4. **Deferred & Throttled Rendering**:
   Panel redraws triggered by incoming probe data are throttled to at least 100ms using `noctalia.nowMs()`.

---

## 4. Probing Mechanism & Metrics Calculation

### 4.1 Probe Execution (`probe.sh`)
```bash
#!/usr/bin/env bash
# probe.sh <game_host>
GAME_HOST="${1:-103.10.124.1}"
GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')

# Parallel ping with 800ms deadline
GW_OUT=$(ping -c 1 -W 1 "$GW" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p') &
DNS_OUT=$(ping -c 1 -W 1 "1.1.1.1" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p') &
GAME_OUT=$(ping -c 1 -W 1 "$GAME_HOST" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p') &

# Active Wi-Fi info via nmcli
WIFI_INFO=$(nmcli -t -f active,ssid,freq,signal,rate dev wifi 2>/dev/null | grep '^yes:' | head -n 1)

wait
# Format: gw_ms|dns_ms|game_ms|ssid|freq_mhz|signal_pct|rate_mbps
```

### 4.2 Metrics Calculation (`state.luau`)
1. **Latency (RTT)**: Current probe round-trip time in milliseconds (clamped, nil if dropped).
2. **Jitter (RFC 3550 Standard)**:
   ```luau
   -- Smoothed moving average inter-arrival jitter
   if state.prevRtt and currentRtt then
     local diff = math.abs(currentRtt - state.prevRtt)
     state.jitter = state.jitter + (diff - state.jitter) / 16
   end
   state.prevRtt = currentRtt
   ```
3. **Packet Loss (%)**:
   Computed over a rolling window of the last 20 probe attempts:
   $$\text{Packet Loss} = \left(\frac{\text{Failed Probes in Window}}{\text{Total Probes in Window}}\right) \times 100$$
4. **Status Classifier**:
   - **`OPTIMAL` (Game Ready / Smooth)**:
     - Game RTT < 60 ms, Jitter < 10 ms, Packet Loss == 0%.
     - Icon: `device-gamepad` or `wifi`, Color: Palette `primary` (Emerald Green).
   - **`FAIR` (Casual / Risky for Competitive)**:
     - Game RTT 60–120 ms OR Jitter 10–25 ms OR Packet Loss 1–3%.
     - Icon: `wifi-2` or `device-gamepad-2`, Color: Warning (`#F59E0B`).
   - **`POOR` (Laggy / High Spike)**:
     - Game RTT > 120 ms OR Jitter > 25 ms OR Packet Loss > 3%.
     - Icon: `alert-triangle` or `wifi-off`, Color: Destructive (`#EF4444`).
   - **`OFFLINE` / `CAPTIVE`**:
     - No default gateway or DNS unreachable. Color: Muted (`#64748B`).

---

## 5. UI/UX Specifications

### 5.1 Status Bar Widget (`widget.luau`)
- **Default Appearance**: Single dynamic icon glyph (`barWidget.setGlyph(...)`), text set to empty string (`barWidget.setText("")`).
- **Configurable Mode**: Toggle `show_text_in_bar` enables compact text (e.g. `34ms`).
- **Interactive Tooltip (`barWidget.setTooltip`)**:
  - Title: `NetRadar: OPTIMAL (SEA)`
  - Rows:
    - `Game Latency`: `32.4 ms`
    - `Jitter`: `±2.1 ms`
    - `Packet Loss`: `0.0%`
    - `Gateway`: `1.2 ms`
    - `Wi-Fi Link`: `5 GHz • 866 Mbps (84%)`

### 5.2 Tactical HUD Popup Panel (`panel.luau`)
Structured using Noctalia declarative UI (`ui.*`) with dark OLED / HUD aesthetic:

```text
┌─────────────────────────────────────────────────────────────┐
│ NETRADAR TELEMETRY                               [Retest] ✕ │
├─────────────────────────────────────────────────────────────┤
│ ▌ STATUS: OPTIMAL (GAME-READY)          [ ■ ■ ■ ■ ■ ] 32 ms │
│   Target: Valve Singapore (103.10.124.1)                RTT │
├─────────────────────────────────────────────────────────────┤
│ ℹ Wi-Fi link is pristine (1.1ms to Router, 5 GHz).          │
│   Game server routing is optimal.                           │
├─────────────────────────────────────────────────────────────┤
│ LATENCY & JITTER GRAPH (LAST 60 SECONDS)                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  ui.graph: Streaming RTT curve with fillOpacity (0.2)   │ │
│ └─────────────────────────────────────────────────────────┘ │
│ Min: 28ms  •  Avg: 33ms  •  Max: 54ms  •  Jitter: 2.1ms     │
├─────────────────────────────────────────────────────────────┤
│ MULTI-TARGET BREAKDOWN                                      │
│ ┌──────────────────┬───────────────────┬──────────────────┐ │
│ │ LOCAL GATEWAY    │ INTERNET DNS      │ GAME SERVER      │ │
│ │ 192.168.1.1      │ 1.1.1.1           │ SEA (Singapore)  │ │
│ │ 1.2 ms · 0% loss │ 14.5 ms · OK      │ 32.4 ms · 0% loss│ │
│ └──────────────────┴───────────────────┴──────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ WI-FI PHYSICAL HEALTH                                       │
│ SSID: Home_5G   • Band: 5 GHz   • Signal: -52 dBm (84%)     │
│ Channel Rate: 866.7 Mbps                                    │
├─────────────────────────────────────────────────────────────┤
│ REGION PRESET: [ Asia Tenggara / Singapore (Default)   ▼ ]  │
└─────────────────────────────────────────────────────────────┘
```

1. **Tactical Telemetry Header**:
   - 3px solid left accent border (reactive color).
   - Monospaced / bold telemetry readouts.
   - Segmented signal meter `[ ■ ■ ■ ■ ■ ]` displaying connection tier.
   - Large primary RTT number with small unit descriptor.
2. **Real-time Latency Graph (`ui.graph`)**:
   - Height: 80px, width stretching to panel width.
   - Data: 60 points normalized to `0..1` scale (clamped to dynamic max latency ceiling).
   - Color: Palette primary with smooth fill opacity.
3. **Multi-Target Cards**:
   - 3 rectangular cards with border and subtle background fill.
   - Displays IP, RTT, and loss for Gateway, DNS, and Game target.
4. **Wi-Fi Health Grid**:
   - Key-value display for SSID, Frequency Band, Signal %, and PHY Bitrate.
5. **Region Preset Switcher**:
   - Integrated dropdown / selector to quickly switch target endpoints without opening full shell settings.

---

## 6. Manifest & Configuration (`plugin.toml`)

```toml
id = "rigelyon/net-radar"
name = "NetRadar"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = ["iproute2", "iputils", "networkmanager"]
tags = ["utility", "network", "gaming", "wifi", "monitor", "bar", "panel"]
icon = "radar"
description = "Real-time multi-target network radar & gaming latency diagnostics with Wi-Fi physical link health."

[[setting]]
key = "show_text_in_bar"
type = "bool"
label_key = "settings.show_text_in_bar.label"
description_key = "settings.show_text_in_bar.description"
default = false

[[setting]]
key = "idle_poll_interval_sec"
type = "number"
label_key = "settings.idle_poll_interval_sec.label"
description_key = "settings.idle_poll_interval_sec.description"
default = 5
min = 2
max = 30
step = 1

[[setting]]
key = "active_poll_interval_sec"
type = "number"
label_key = "settings.active_poll_interval_sec.label"
description_key = "settings.active_poll_interval_sec.description"
default = 2
min = 1
max = 10
step = 1

[[setting]]
key = "default_target_preset"
type = "select"
label_key = "settings.default_target_preset.label"
description_key = "settings.default_target_preset.description"
default = "sea_singapore"
options = [
  { value = "sea_singapore", label_key = "presets.sea_singapore" },
  { value = "east_asia_tokyo", label_key = "presets.east_asia_tokyo" },
  { value = "us_west", label_key = "presets.us_west" },
  { value = "europe_west", label_key = "presets.europe_west" },
  { value = "custom", label_key = "presets.custom" },
]

[[setting]]
key = "custom_target_host"
type = "string"
label_key = "settings.custom_target_host.label"
description_key = "settings.custom_target_host.description"
default = "1.1.1.1"

[[setting]]
key = "enable_loss_desktop_notification"
type = "bool"
label_key = "settings.enable_loss_desktop_notification.label"
description_key = "settings.enable_loss_desktop_notification.description"
default = false

[[setting]]
key = "packet_loss_alert_threshold"
type = "number"
label_key = "settings.packet_loss_alert_threshold.label"
description_key = "settings.packet_loss_alert_threshold.description"
default = 5
min = 1
max = 50
step = 1

[[widget]]
id = "widget"
entry = "widget.luau"

[[panel]]
id = "panel"
entry = "panel.luau"
```

---

## 7. Error Handling & Edge Cases

| Scenario | Detection | Behavior / Recovery |
|---|---|---|
| **No Network / Wi-Fi Disconnected** | `ip route show default` is empty | Status sets to `OFFLINE`. Bar glyph turns muted gray. Polling interval backs off to 10s to conserve CPU. |
| **Captive Portal (Hotel/Cafe Wi-Fi)** | Gateway RTT is <2ms, but DNS / Game RTT fails completely | Diagnostic callout: `Captive portal detected: Local router connected, internet unreachable`. |
| **Wired Connection (Ethernet)** | `nmcli` returns no active Wi-Fi interface | Wi-Fi section gracefully switches to `Ethernet (Wired)`, displaying interface speed without crashing. |
| **Network Driver / Ping Hang** | Process fails to return within 2.5 seconds | `noctalia.runAsync` timeout parameter (`timeoutMs: 2500`) terminates the hanging process and marks the probe as lost. |
| **Rapid Panel Toggling** | User opens/closes panel quickly | Pending timers and polling rates switch cleanly without overlapping probe processes. |

---

## 8. Testing Strategy

Automated test suites located in `tests/` utilizing `pytest`:

1. `tests/test_net_radar_manifest.py`:
   - Validates `plugin.toml` syntax, metadata, valid `plugin_api = 28`, entry definitions, settings types, and bounds.
2. `tests/test_net_radar_metrics.py`:
   - Verifies RFC 3550 Jitter convergence given sample sequences.
   - Tests rolling window packet loss calculations across 20-sample windows.
   - Validates classification boundaries (`OPTIMAL`, `FAIR`, `POOR`, `OFFLINE`).
3. `tests/test_net_radar_parser.py`:
   - Tests parser resilience against simulated `probe.sh` outputs (normal, high loss, captive portal, empty lines, missing fields).
4. `tests/test_net_radar_translations.py`:
   - Verifies that all `label_key` and `description_key` references in `plugin.toml` exist in both `translations/en.json` and `translations/id.json`.
