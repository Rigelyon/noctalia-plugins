# Sleepy Time 🌙⏱️

A comprehensive timer, scheduler, and system-action plugin for **Noctalia v5**. 

Set a countdown or schedule a target time to perform system actions like **Lock Screen**, **Suspend**, **Shutdown**, **Reboot**, **Log Out**, **Kill Process**, or run a **Custom Command**.

![Sleepy Time](thumbnail.webp)

## Features

- ⏱️ **Countdown Timer**: Quick presets (5m, 10m, 15m, 30m, 1h, 2h...) or custom duration (`HH:MM:SS`).
- 🕐 **Scheduled Time ("At" Mode)**: Schedule a target wall-clock time (`HH:MM`), with automatic next-day calculation.
- ⚡ **7 System Actions**:
  - 🔒 **Lock Screen**: Locks user session (`loginctl lock-session`).
  - 🌙 **Suspend**: System sleep (`systemctl suspend`).
  - ⏻ **Shutdown**: System power off (`systemctl poweroff`).
  - 🔄 **Reboot**: System restart (`systemctl reboot`).
  - 🚪 **Log Out**: Session exit (`niri`, `hyprland`, `sway`, `loginctl`).
  - ☠️ **Kill Process**: Pick from active processes with app icons.
  - ⌨️ **Custom Command**: Run any shell command.
- ⚠️ **Progressive Warning System**: Timed warning notifications (at T-60s, T-30s, T-10s) and color changes without annoying modal dialogs.
- 📊 **Bar Widget & Desktop Widget**: Beautiful, clean, reactive countdown displays with customizable colors, fonts, and layouts.
- 🎨 **Deep Visual Customization**: Configure colors, fonts, progress bars, idle visibility, and compact modes.

---

## Installation

Add `rigelyon/sleepy-time` to your Noctalia plugins configuration or clone into your plugins directory:

```bash
git clone https://github.com/rigelyon/noctalia-plugins ~/.config/noctalia/plugins
```

---

## Configuration Options

Global settings (`Settings` → `Plugins` → `Sleepy Time`):

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `default_action` | select | `"lock"` | Action preselected when opening panel |
| `default_duration` | int | `30` | Default timer duration in minutes |
| `warning_enabled` | bool | `true` | Show warning notifications before action |
| `warning_seconds` | int | `60` | Warning lead time in seconds |
| `quick_timers` | string | `"5,10,15,30,60,90,120"` | Comma-separated quick timer presets |
| `lock_command` | string | `""` | Override lock command |
| `suspend_command` | string | `""` | Override suspend command |
| `shutdown_command` | string | `""` | Override shutdown command |
| `reboot_command` | string | `""` | Override reboot command |
| `logout_command` | string | `""` | Override logout command |
| `custom_command` | string | `""` | Custom command override |

### Bar Widget Settings (per-placement)

- `show_when_idle`: Show bar widget when no timer is running.
- `idle_text`: Text to display when idle (`none`, `plugin-name`, `next-action`).
- `show_countdown_text`: Show remaining time text in bar.
- `show_action_icon`: Use action-specific icon during countdown.
- `active_color`, `paused_color`, `warning_color`: Theme colors.

### Desktop Widget Settings (per-instance)

- `color`: Accent color.
- `show_when_idle`: Show on desktop when idle.
- `show_progress`: Show progress bar.
- `show_percentage`: Show percentage text.
- `show_action_label`: Show target action label.
- `font_size`: Timer font size (16–96px).
- `compact_mode`: Single-line compact layout.

---

## License

[MIT](LICENCE.txt) © Rigelyon
