# NetRadar (`rigelyon/net-radar`)

<p align="center">
  <strong>Real-time multi-target network radar & gaming latency diagnostics with Wi-Fi physical link health for Noctalia Shell.</strong>
</p>

---

## Why NetRadar?

Have you ever connected to a Wi-Fi network that shows full signal bars ("Connected"), only to find that opening a match in your favorite game causes severe stutter, rubberbanding, or packet loss? 

Standard network monitors only report current throughput (KB/s), and speed tests consume valuable mobile data. **NetRadar** solves this by continuously sending lightweight micro-probes (~64 bytes) to test:
1. **Local Wi-Fi Gateway**: Detects if high latency or packet loss is caused by local router interference (especially on 2.4 GHz channels).
2. **Public Internet DNS (`1.1.1.1`)**: Verifies general internet uptime and catches captive portals.
3. **Regional Game Server Clusters**: Measures real-world competitive gaming RTT, Jitter (RFC 3550), and Packet Loss %.

---

## Features

- **Icon-Only by Default**: Designed to keep your Noctalia status bar clean. Displays a single dynamic icon glyph that reflects connection readiness (`primary` for Game-Ready, `warning` for casual only, `destructive` for lag/packet loss).
- **Tactical HUD Telemetry Panel**: Sharp, minimal dashboard with segmented signal level meter, real-time streaming `ui.graph` (60s history), 3-target breakdown, and Wi-Fi PHY diagnostics (SSID, 2.4/5GHz band, signal dBm, link speed).
- **Strict CPU Budget Compliance**:
  - Combined single-command micro-probe (`probe.sh`).
  - Adaptive polling (5s background, 2s active in panel, 10s backoff when offline).
  - Pre-allocated 60-sample ring buffer to prevent GC churn.
  - Render throttling (>= 100ms) to prevent Luau instruction budget exhaustion.
- **Bilingual Support**: Full English and Indonesian localization out of the box.

---

## External Dependencies

NetRadar uses standard Linux networking utilities:
- `iputils` (`/usr/bin/ping`)
- `iproute2` (`/usr/bin/ip`)
- `networkmanager` (`/usr/bin/nmcli`)

---

## License

MIT © rigelyon
