# Sleepy Time

Sleepy Time is a comprehensive timer, scheduler, and system action plugin for Noctalia v5 that helps manage system sleep, screen lock, and power operations.

![Sleepy Time](thumbnail.webp)

## Plugin

This plugin manifest ID is `rigelyon/sleepy-time` and provides four entries:

- `service`: Background timer engine that runs countdown logic and executes actions.
- `widget`: Bar widget displaying active countdown and opening the setup panel on click.
- `panel`: Control panel for configuring timer duration, action mode, and process targets.
- `desktop`: Pinned desktop widget showing ambient countdown progress.

To toggle the control panel from the command line or IPC, run:

```bash
noctalia msg panel-toggle rigelyon/sleepy-time:panel
```

## Usage

1. Click the Sleepy Time bar widget or execute the panel toggle command to open the setup panel.
2. Choose between **Countdown** mode (quick preset or custom duration) or **At Time** mode (target wall-clock time).
3. Select your target action:
   - Lock Screen
   - Suspend
   - Shutdown
   - Reboot
   - Log Out
   - Kill Process
   - Custom Command
4. Click **Start** to begin the timer.
5. Control active timers using the **Pause**, **Resume**, **+5m**, **-5m**, or **Cancel** buttons.

## Settings

Global settings can be configured in Settings → Plugins → Sleepy Time:

- `default_action`: Default action when opening setup panel (`lock`, `suspend`, `shutdown`, `reboot`, `logout`, `kill-process`, `custom-command`).
- `default_duration`: Default duration in minutes for new timers.
- `warning_enabled`: Enable warning notifications before action fires.
- `warning_seconds`: Lead time in seconds for warning notifications (default: 60s).
- `warning_sound`: Play notification sound during warning phase.
- `quick_timers`: Comma-separated list of quick timer presets in minutes (e.g. `5,10,15,30,60,90,120`).
- `lock_command`: Override lock screen command line.
- `suspend_command`: Override suspend command line.
- `shutdown_command`: Override shutdown command line.
- `reboot_command`: Override reboot command line.
- `logout_command`: Override log out command line.
- `custom_command`: Custom shell command string.

### Widget Settings

- `show_when_idle`: Show the bar widget when no timer is active.
- `idle_text`: Display text when idle (`none`, `plugin-name`, `next-action`).
- `show_countdown_text`: Show remaining time text next to icon.
- `show_action_icon`: Display action-specific icon during countdown.
- `active_color`, `paused_color`, `warning_color`: Custom color palette.

### Desktop Widget Settings

- `color`: Primary accent color.
- `show_when_idle`: Render desktop widget when idle.
- `show_progress`: Render progress bar.
- `show_percentage`: Render percentage indicator.
- `show_action_label`: Render action label text.
- `font_size`: Timer font size in pixels (16 to 96).
- `compact_mode`: Single-line layout.

## License

[MIT](LICENCE.txt) © Rigelyon
