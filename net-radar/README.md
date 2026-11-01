# NetRadar

Real-time multi-target network radar & gaming latency diagnostics with Wi-Fi physical link health.

Standard network monitors only report current throughput (KB/s), and speed tests consume valuable mobile data. NetRadar continuously sends lightweight micro-probes (~64 bytes) to test:
- Local Wi-Fi Gateway: Detects if high latency or packet loss is caused by local router interference (especially on 2.4 GHz channels).
- Public Internet DNS (`1.1.1.1`): Verifies general internet uptime and catches captive portals.
- Regional Game Server Clusters: Measures real-world competitive gaming RTT, Jitter (RFC 3550), and Packet Loss %.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/net-radar` |
| Entries | Bar widget: `widget`; panel: `panel` |

## Requirements

NetRadar requires standard Linux networking utilities installed on `PATH`:
- `iproute2` (`ip`)
- `iputils` (`ping`)
- `networkmanager` (`nmcli`)

## Usage

Add the `widget` bar entry to your Noctalia status bar via Noctalia Settings. By default, it displays a single clean dynamic icon without ping text cluttering the bar.

Click the widget or run the IPC command below to toggle the Tactical Telemetry HUD panel:

```sh
noctalia msg panel-toggle rigelyon/net-radar:panel
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `show_text_in_bar` | `bool` | `false` | When disabled, displays only a clean dynamic icon glyph with no text cluttering the bar. |
| `idle_poll_interval_sec` | `int` | `5` | Background probe interval (in seconds) when the panel is closed. |
| `active_poll_interval_sec` | `int` | `2` | Fast probe interval (in seconds) while the HUD panel is open. |
| `default_target_preset` | `select` | `sea_singapore` | Preconfigured game server cluster endpoint (`sea_singapore`, `east_asia_tokyo`, `us_west`, `europe_west`, `custom`). |
| `custom_target_host` | `string` | `1.1.1.1` | IP or domain name to probe when the Custom preset is active. |
| `enable_loss_desktop_notification` | `bool` | `false` | Notify via desktop notification when packet loss exceeds threshold. |
| `packet_loss_alert_threshold` | `int` | `5` | Percentage of dropped packets within window that triggers a desktop alert. |

## Notes

- Probing is non-blocking and executes via a single combined background subprocess (`probe.sh`).
- All telemetry history is buffered in a fixed 60-sample in-memory ring buffer with render throttling (>= 100ms) to strictly comply with Noctalia's Luau CPU instruction budget.
