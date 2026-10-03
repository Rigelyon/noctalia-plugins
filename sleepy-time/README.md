# Sleepy Time

Sleepy Time is a timer, scheduler, and system action plugin for Noctalia v5 to manage system sleep, screen lock, power off, reboot, logout, and process termination.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/sleepy-time` |
| Entries | Bar widget: `widget`; panel: `panel`; service: `service`; desktop widget: `desktop` |

## Usage

1. Click the Sleepy Time bar widget or execute the panel toggle command to open the setup panel:
   ```sh
   noctalia msg panel-toggle rigelyon/sleepy-time:panel
   ```
2. Choose between **Countdown** mode (quick preset pills or custom duration) or **At Time** mode (target 24-hour clock time).
3. Select your target system action:
   - **Lock Screen**: Locks session via `loginctl lock-session` or compositor lock tools.
   - **Suspend**: Suspends system via `systemctl suspend` or `loginctl suspend`.
   - **Shutdown**: Powers off system via `systemctl poweroff` or `loginctl poweroff`.
   - **Reboot**: Reboots system via `systemctl reboot` or `loginctl reboot`.
   - **Log Out**: Terminates session or exits Wayland compositor (Niri, Hyprland, Sway).
   - **Kill Process**: Terminates one or multiple selected running graphical apps or user processes (`kill -15` then `kill -9`).
   - **Custom Command**: Runs any custom shell command.
4. Click **Start Timer** to begin. The setup panel automatically closes so you can continue your work.
5. Control running timers anytime from the bar widget, desktop widget, or reopened panel:
   - **Pause / Resume**: Temporarily freeze countdown.
   - **+5m / −5m**: Adjust remaining time on the fly.
   - **Cancel**: Cancel active timer (or right-click the bar widget).

## Settings

### Global Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `default_action` | `select` | `lock` | Default action preselected in setup panel (`lock`, `suspend`, `shutdown`, `reboot`, `logout`, `kill-process`, `custom-command`). |
| `default_duration` | `int` | `30` | Default timer duration in minutes (1 to 480). |
| `warning_enabled` | `bool` | `true` | Send multi-tier notification alerts (at 60s, 30s, and 10s) before executing action. |
| `warning_seconds` | `int` | `60` | Lead time in seconds to begin warning notifications (10 to 300). |
| `quick_timers` | `string` | `5,10,15,30,60,90,120` | Comma-separated list of quick preset timer durations in minutes. |
| `lock_command` | `string` | `""` | Custom command override for screen lock. |
| `suspend_command` | `string` | `""` | Custom command override for system suspend. |
| `shutdown_command` | `string` | `""` | Custom command override for system power off. |
| `reboot_command` | `string` | `""` | Custom command override for system reboot. |
| `logout_command` | `string` | `""` | Custom command override for session logout. |
| `custom_command` | `string` | `""` | Custom shell command string. |

### Bar Widget Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `show_when_idle` | `bool` | `true` | Keep the bar widget visible when no timer is active. |
| `idle_text` | `select` | `none` | Bar text displayed when idle (`none`, `plugin-name`, `next-action`). |
| `show_countdown_text` | `bool` | `true` | Show countdown remaining time text next to icon. |
| `show_action_icon` | `bool` | `false` | Display action-specific icon instead of moon icon during countdown. |
| `active_color` | `color` | `primary` | Color of widget during active countdown. |
| `paused_color` | `color` | `#f59e0b` | Color of widget when timer is paused. |
| `warning_color` | `color` | `#ef4444` | Color of widget during warning threshold. |

### Desktop Widget Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `color` | `color` | `primary` | Primary accent color for countdown readout and progress bar. |
| `show_when_idle` | `bool` | `false` | Show ambient widget on desktop when idle. |
| `show_progress` | `bool` | `true` | Show progress bar. |
| `show_percentage` | `bool` | `true` | Show remaining time percentage. |
| `show_action_label` | `bool` | `true` | Show selected action label. |
| `show_finish_time` | `bool` | `true` | Show calculated finish/target end time. |
| `show_controls` | `bool` | `true` | Show inline action & time adjustment buttons. |
| `font_size` | `int` | `38` | Countdown typography size in pixels (16 to 96). |
| `compact_mode` | `bool` | `false` | Enable single-line horizontal layout. |
| `paused_color` | `color` | `#f59e0b` | Accent color when paused. |
| `warning_color` | `color` | `#ef4444` | Accent color during warning alert. |

## Notes

- **Compositor & System Compatibility**: Default action commands are designed with automated fallbacks supporting systemd, elogind/loginctl, Niri, Hyprland, and Sway.
- **Process Listing**: The "Kill Process" selector scans user graphical processes using `ps` and extracts application icons via Noctalia's XDG icon theme resolver. It supports multi-select toggling of multiple processes to terminate concurrently.
