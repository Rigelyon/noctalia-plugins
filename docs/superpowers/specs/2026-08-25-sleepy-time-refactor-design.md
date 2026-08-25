# Sleepy Time Plugin Refactoring Specification (Noctalia v5 API Level 28)

## 1. Overview & Goals

Sleepy Time (`rigelyon/sleepy-time`) is a power management, sleep timer, and system action scheduler plugin for the Noctalia desktop shell.
This specification details the comprehensive refactoring of Sleepy Time to bring it to **Noctalia Plugin API Level 28**, leveraging modern reactive state management, clean declarative UI closures, multi-tier warning notifications, intelligent desktop compositor fallbacks, and resilient UI error handling.

### Goals
- Fully modernize the codebase to Noctalia `plugin_api = 28`.
- Implement a reactive headless service engine as the single source of truth (`service.luau`).
- Provide an interactive, declarative setup & control panel (`panel.luau`) that automatically closes on timer start.
- Provide a responsive bar widget (`widget.luau`) that adapts to horizontal and vertical bar layouts with safe tooltip handling.
- Provide an ambient desktop widget (`desktop.luau`) with accurate progress bars and compact/card modes.
- Implement multi-tier system warning notifications (at 60s, 30s, 10s thresholds) without sound for now.
- Support robust system actions (Lock Screen, Suspend, Shutdown, Reboot, Log Out, Kill App, Custom Command) with compositors and init system fallbacks.
- Maintain full localization parity in `translations/en.json`.

---

## 2. Architecture & Entry Points

The plugin consists of 4 integrated entries running in isolated Luau VM threads, coordinated through `noctalia.state`:

```
┌────────────────────────────────────────────────────────┐
│                      plugin.toml                       │
│                   (plugin_api = 28)                    │
└──────────────────────────┬─────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ widget.luau  │   │  panel.luau  │   │ desktop.luau │
│ (Bar Widget) │   │ (Setup Modal)│   │(Desktop Card)│
└───────┬──────┘   └──────┬───────┘   └──────┬───────┘
        │                 │                  │
        │ noctalia.state  │ noctalia.state   │ noctalia.state
        │ (read / watch)  │ (cmd / read)     │ (read / watch)
        ▼                 ▼                  ▼
┌────────────────────────────────────────────────────────┐
│                      service.luau                      │
│      (Headless Engine - Countdown, Actions, IPC)       │
└────────────────────────────────────────────────────────┘
```

1. **`service.luau` (`[[service]]`)**: Background daemon owning countdown ticks (`noctalia.setUpdateInterval(1000)`), time calculations, process listing, warning dispatch, and action execution.
2. **`widget.luau` (`[[widget]]`)**: Status bar presentation with `barWidget.render()`, horizontal/vertical support (`barWidget.isVertical()`), left-click to open panel, right-click to quick-cancel/open.
3. **`panel.luau` (`[[panel]]`)**: Declarative setup and control surface (`panel.render()`). Sized at 380x520 with mode switching, quick presets, custom duration input, action picker, running process picker, and playback controls. Closes on timer start.
4. **`desktop.luau` (`[[desktop_widget]]`)**: Declarative ambient desktop widget (`desktopWidget.render()`) reflecting timer countdown, progress bar, and action status.

---

## 3. Manifest Specification (`plugin.toml`)

- `id = "rigelyon/sleepy-time"`
- `version = "2.0.0"`
- `plugin_api = 28`
- `tags = ["bar", "panel", "desktop", "service", "countdown", "time", "productivity", "utility"]`
- `icon = "moon-stars"`

### Declared Settings
- **Global Settings (`[[setting]]`)**:
  - `default_action` (select: `lock`, `suspend`, `shutdown`, `reboot`, `logout`, `kill-process`, `custom-command`)
  - `default_duration` (int: default 30 min, range 1..480)
  - `warning_enabled` (bool: default true)
  - `warning_seconds` (int: default 60s, range 10..300)
  - `quick_timers` (string: default `"5,10,15,30,60,90,120"`)
  - `lock_command` (string: override)
  - `suspend_command` (string: override)
  - `shutdown_command` (string: override)
  - `reboot_command` (string: override)
  - `logout_command` (string: override)
  - `custom_command` (string: override)
- **Bar Widget Settings (`[[widget.setting]]`)**:
  - `show_when_idle` (bool: default true)
  - `idle_text` (select: `none`, `plugin-name`, `next-action`)
  - `show_countdown_text` (bool: default true)
  - `show_action_icon` (bool: default false)
  - `active_color` (color: default `"primary"`)
  - `paused_color` (color: default `"#f59e0b"`)
  - `warning_color` (color: default `"#ef4444"`)
- **Panel Settings (`[[panel]]`)**:
  - `id = "panel"`
  - `entry = "panel.luau"`
  - `placement = "attached"`
  - `position = "auto"`
  - `open_near_click = true`
  - `width = 380`
  - `height = 520`
- **Desktop Widget Settings (`[[desktop_widget.setting]]`)**:
  - `color` (color: default `"primary"`)
  - `show_when_idle` (bool: default false)
  - `show_progress` (bool: default true)
  - `show_percentage` (bool: default true)
  - `show_action_label` (bool: default true)
  - `font_size` (int: default 38, range 16..96)
  - `compact_mode` (bool: default false)
  - `paused_color` (color: default `"#f59e0b"`)
  - `warning_color` (color: default `"#ef4444"`)

---

## 4. State Management Schema (`noctalia.state`)

### 1. `sleepy.state` (Published by Service)
```lua
{
  status        = "IDLE",       -- "IDLE" | "RUNNING" | "PAUSED" | "WARNING"
  mode          = "countdown",  -- "countdown" | "scheduled"
  remaining     = 1800,         -- Remaining seconds
  duration      = 1800,         -- Total baseline seconds (for progress)
  formattedTime = "30:00",      -- Formatted string "MM:SS" or "H:MM:SS"
  action        = "lock",       -- Selected action key
  actionTarget  = "",           -- Target process name or custom command string
  targetTimeStr = "",           -- HH:MM string if scheduled mode
  warningActive = false,        -- Boolean true during warning threshold
}
```

### 2. `sleepy.cmd` (Command Channel)
- `START`: `{ action = "start", mode = "countdown"|"scheduled", seconds = 1800, targetTime = "23:30", targetAction = "lock", targetParam = "" }`
- `PAUSE`: `{ action = "pause" }`
- `RESUME`: `{ action = "resume" }`
- `CANCEL` / `RESET`: `{ action = "cancel" }`
- `ADD_TIME`: `{ action = "addTime", seconds = 300 }`
- `FETCH_PROCESSES`: `{ action = "fetchProcesses" }`

### 3. `sleepy.processes` (Process List Cache)
- Table of `{ pid = string, name = string, iconPath = string }`

### 4. `sleepy.presets` (Quick Preset List)
- Table of `{ minutes = number, label = string }` parsed from configuration.

---

## 5. Detailed Component Designs

### A. Headless Engine (`service.luau`)
- **Timer Countdown**:
  - `noctalia.setUpdateInterval(1000)`.
  - In `update()`, if `status == "RUNNING"` or `status == "WARNING"`, decrements `remaining` by 1.
  - Generates `formattedTime`:
    - If `remaining >= 3600`: `string.format("%d:%02d:%02d", h, m, s)`
    - Else: `string.format("%02d:%02d", m, s)`
- **Warning Notifications**:
  - Threshold: `warning_seconds` (default 60s).
  - Multi-tier alerts at <= 60s, <= 30s, <= 10s:
    - 60s: `⏳ [Action] in [time]`
    - 30s: `⚠️ [Action] in 30 seconds!`
    - 10s: `🔴 [Action] in 10 seconds!`
  - No sound played (reserved for future updates).
- **Action Execution**:
  - Uses `noctalia.runAsync(cmd, onResult)`:
    - **Lock**: `config.lock_command ~= ""` -> `config.lock_command`, else `loginctl lock-session || hyprlock || swaylock || waylock`
    - **Suspend**: `config.suspend_command ~= ""` -> `config.suspend_command`, else `systemctl suspend || loginctl suspend`
    - **Shutdown**: `config.shutdown_command ~= ""` -> `config.shutdown_command`, else `systemctl poweroff || loginctl poweroff`
    - **Reboot**: `config.reboot_command ~= ""` -> `config.reboot_command`, else `systemctl reboot || loginctl reboot`
    - **Log Out**: `config.logout_command ~= ""` -> `config.logout_command`, else `loginctl terminate-session "${XDG_SESSION_ID:-self}" || niri msg action quit --skip-confirmation 2>/dev/null || hyprctl dispatch exit 2>/dev/null || swaymsg exit 2>/dev/null`
    - **Kill Process**: `kill -15 <pid> 2>/dev/null || pkill -15 -f <target>`
    - **Custom Command**: `target ~= ""` -> `target`, else `config.custom_command`
- **Scheduled "At Time" Calculation**:
  - Compares target `HH:MM` against `os.date("*t")`.
  - If target time has already passed today, schedules for tomorrow (`diff + 86400`).
- **Process Scanning**:
  - Runs `ps -u $(whoami) -o pid=,comm=,args= --sort=comm`.
  - Filters out shell/system helpers (`ps`, `sh`, `bash`, `zsh`, `sed`, `grep`, `systemd`).
  - Resolves application icon using `noctalia.appIconPath(comm, 24)`.
  - Publishes deduplicated list to `sleepy.processes`.

### B. Bar Widget (`widget.luau`)
- **Declarative Rendering**:
  - Uses `barWidget.render(tree)`.
  - Supports vertical bars (`barWidget.isVertical()`).
- **States & Visual Styles**:
  - **IDLE**: Displays `moon-stars` glyph. If `show_when_idle == false`, renders minimal glyph or empty container. If `idle_text == "plugin-name"`, shows "Sleepy Time". If `idle_text == "next-action"`, shows action name.
  - **RUNNING**: Displays clock/action glyph and formatted time with `active_color`.
  - **PAUSED**: Displays paused glyph and time with `paused_color` (amber).
  - **WARNING**: Displays alert glyph and time with `warning_color` (red).
- **Gestures**:
  - `onClick()`: Toggles panel `noctalia.togglePanel("rigelyon/sleepy-time:panel")`.
  - `onRightClick()`: If running, sends `CANCEL` command; if idle, toggles panel.
- **Safe Tooltip Handling**:
  - Tracks tooltip state locally to prevent `clearTooltip()` crashes.

### C. Setup & Control Panel (`panel.luau`)
- **Declarative UI Structure (`panel.render`)**:
  - Fixed dimensions (`width = 380, height = 520`).
  - Top header with "Sleepy Time" label, icon, and close button.
  - **When IDLE (Setup View)**:
    - Mode Switcher: Two pill buttons (`Countdown` vs `At Time`).
    - **Countdown View**:
      - Quick Presets: Rendered dynamically from `sleepy.presets` in a wrapped row grid. Clicking a preset highlights it and updates the custom duration buffer.
      - Custom Duration: `ui.input` accepting `MM:SS`, `HH:MM:SS`, or numeric minutes.
    - **At Time View**:
      - `ui.input` for `HH:MM` (24-hour clock) with calculated time preview ("Runs in 2h 15m").
    - **Action Picker Grid**:
      - Compact grid of action buttons with glyphs (Lock, Suspend, Shutdown, Reboot, Log Out, Kill App, Custom).
    - **Target Parameter Details**:
      - If "Kill App": Displays selectable active processes with icons.
      - If "Custom": Text input for custom shell command.
    - **Footer Action**:
      - Large primary "Start Timer" button (`variant = "primary"`).
      - On start: dispatches `START` command to `service.luau` and immediately calls `panel.close()`.
  - **When RUNNING / PAUSED / WARNING (Control View)**:
    - Large digital timer display with action badge and mode indicator.
    - Progress bar: `ui.progress({ progress = (1 - (remaining / duration)), fill = accentColor, height = 6 })`.
    - Button bar:
      - `[ ⏸ Pause ]` / `[ ▶ Resume ]` (`variant = "primary"`)
      - `[ +5m ]` and `[ -5m ]` (`variant = "secondary"`)
      - `[ ✕ Cancel ]` (`variant = "destructive"`)

### D. Desktop Widget (`desktop.luau`)
- **Declarative Presentation (`desktopWidget.render`)**:
  - Watches `sleepy.state` and automatically updates on tick.
  - **Idle State**: Hidden or minimal chip depending on `show_when_idle`.
  - **Running / Warning State**:
    - Large formatted time label (fontSize configurable, default 38).
    - Progress bar: `ui.progress({ progress = (1 - (remaining / duration)), fill = accentColor, height = 6, radius = 3 })`.
    - Percentage label & Action badge.
    - Compact Mode support (single row flexbox layout) vs Full Card mode.

### E. Translations (`translations/en.json`)
- Complete key-value definitions for all manifest keys, button labels, notifications, action names, and status tags.

---

## 6. Verification & Testing Plan

1. **Syntax & Manifest Validation**:
   - Verify `plugin.toml` matches Noctalia guidelines (tags, types, dependencies, keys).
   - Ensure all translation keys referenced in `plugin.toml` exist in `translations/en.json`.
2. **Luau Analysis**:
   - Validate strict type conformity against `noctalia.d.luau`.
   - Ensure no obsolete APIs (`noctalia.getConfig` used correctly as single accessor, correct `ui.progress` and `barWidget` methods).
3. **Behavioral Testing**:
   - Test Countdown timer start, tick decrement, pause, resume, +5m, -5m, and cancel.
   - Test At-Time schedule calculation for same-day and next-day targets.
   - Test Warning notification triggers at thresholds (60s, 30s, 10s).
   - Test panel auto-close on start and reopening in active mode.
   - Test bar widget state rendering and orientation.
   - Test desktop widget rendering and progress calculation.
