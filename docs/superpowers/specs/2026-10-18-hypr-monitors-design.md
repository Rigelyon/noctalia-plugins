# Hyprland Monitor Manager (`rigelyon/hypr-monitors`) Design Specification

- **Plugin ID**: `rigelyon/hypr-monitors`
- **Plugin Directory**: `hypr-monitors/`
- **Target Platform**: Noctalia Shell (Wayland / Hyprland Compositor)
- **Plugin API Version**: 28
- **Date**: 2026-10-18
- **Author**: rigelyon

---

## 1. Executive Summary & Goals

Configuring multi-monitor setups in Hyprland currently requires editing configuration files manually (`hyprland.conf` or `monitors.conf`) with error-prone syntax (`monitor=name,res@hz,offset,scale,...`) where small coordinate typos result in awkward cursor jumps, mismatched physical arrangements, or black screens.

The **Hyprland Monitor Manager** (`rigelyon/hypr-monitors`) is a native Noctalia plugin designed to provide a premium, modern visual display manager experience for Hyprland. It bridges the gap between low-level compositor IPC commands and intuitive desktop display settings.

### Core Objectives
1. **Interactive Visual Arrangement Canvas**: Proportional miniature display cards representing connected monitors with real aspect ratios, selection highlight, and live position coordination.
2. **Gapless Snap Alignment & Presets**: Mathematical alignment tools (*Snap Left*, *Snap Right*, *Above*, *Below*, *Align Tops/Bottoms/Center*) that eliminate subpixel cursor gaps between screens, plus instant one-click display presets (*Extend*, *Mirror/Duplicate*, *Single Screen*, *External Only*).
3. **Comprehensive Per-Monitor Inspector**: Granular control of detected hardware resolutions & refresh rates (via EDID/Hyprland), fractional scaling (1.0x to 2.0x), 4-way rotation/transform (0°, 90°, 180°, 270°), power toggle (DPMS on/off), and advanced gaming toggles (VRR / Adaptive Sync and 10-bit color).
4. **Safety Revert Countdown (15 Seconds)**: Instant live testing via `hyprctl keyword monitor` backed by a 15-second automatic fallback countdown modal to protect users from unrecoverable black or out-of-range screens.
5. **Permanent Config Generation & Backup**: One-click writing to `~/.config/hypr/monitors.conf` with automatic `.bak` backups and detection of whether the file is properly sourced in `hyprland.conf`.
6. **Named Display Profiles & Plug/Unplug Auto-Detect**: Create and switch named profiles ("Work Dual Monitor", "Presentation Mirror", "Laptop Mobile") with automatic activation when monitors are plugged/unplugged via Hyprland socket2 events (`monitoradded` / `monitorremoved`).
7. **Dual-Action Bar Widget**: Status bar widget showing display icon, active monitor counter, and rich tooltip. Left-click provides a quick preset popover; right-click opens the full visual hub panel.

---

## 2. Architecture & File Structure

```text
hypr-monitors/
├── plugin.toml            # Manifest: metadata, settings, panel (740x560), bar widget
├── widget.luau            # Status bar widget entry point (dual action, state subscription)
├── panel.luau             # Floating panel entry point (Canvas, Tabs, Footer, Safety Modal)
├── hypr.luau              # Hyprland IPC client (hyprctl monitors, keyword apply, socket2 listener)
├── state.luau             # Central reactive state manager & subscriber hub
├── config.luau            # Parser & writer for ~/.config/hypr/monitors.conf (with .bak backup)
├── layout_math.luau       # Gapless coordinate calculation, proportional scaling, snap alignment
├── components.luau        # Declarative UI component library (monitor cards, steppers, canvas toolbar)
├── profiles.luau          # Persistent named display profiles manager (save, load, auto-match)
├── README.md              # User documentation, installation, and usage instructions
├── thumbnail.webp         # Catalog card artwork for Noctalia plugin store
└── translations/
    ├── en.json            # English localization strings
    └── id.json            # Indonesian localization strings
```

---

## 3. Component Details & Technical Specifications

### 3.1 Manifest (`plugin.toml`)

- **Plugin Identifiers**:
  - `id = "rigelyon/hypr-monitors"`
  - `name = "Hyprland Monitor Manager"`
  - `version = "1.0.0"`
  - `plugin_api = 28`
  - `author = "rigelyon"`
  - `license = "MIT"`
  - `icon = "device-desktop"`
  - `tags = ["hyprland", "monitor", "display", "utility", "bar", "panel", "productivity"]`
  - `dependencies = ["hyprland"]`
  - `description = "Aesthetic visual display manager for Hyprland with gapless canvas arrangement, instant presets, safety revert timer, and profile management."`

- **Settings Definitions**:
  - `config_path`: Type `string`, default `"~/.config/hypr/monitors.conf"`. Path to persistent Hyprland monitors file.
  - `safety_timeout`: Type `int`, default `15`. Countdown in seconds before auto-reverting unconfirmed display changes.
  - `enable_safety_timer`: Type `bool`, default `true`. Toggle for the 15-second safety revert modal.
  - `auto_switch_profiles`: Type `bool`, default `true`. Automatically apply matching display profile on monitor plug/unplug.
  - `show_count_in_bar`: Type `bool`, default `true`. Display active screen count in the status bar widget.
  - `enable_vrr_options`: Type `bool`, default `true`. Show VRR / Adaptive Sync controls in the Advanced accordion.

- **Panel Definition**:
  - `id = "panel"`
  - `entry = "panel.luau"`
  - `placement = "floating"`
  - `position = "center"`
  - `width = 740`
  - `height = 560`
  - `capture_keys = ["Escape"]`

- **Widget Definition**:
  - `id = "widget"`
  - `entry = "widget.luau"`
  - `[widget.actions]`
    - `middle = "none"`

---

### 3.2 Hyprland IPC Client (`hypr.luau`)

Responsible for querying display state, applying live rules, and streaming compositor socket events.

- **Functions**:
  - `hypr.init()`: Checks if `hyprctl` is available. Starts socket2 event listener.
  - `hypr.refreshMonitors(callback: (({ Monitor }, boolean) -> ())?)`:
    - Executes `hyprctl monitors all -j`.
    - Parses JSON output into a normalized table of `Monitor` records:
      - `id`: number
      - `name`: string (e.g., `"eDP-1"`, `"DP-1"`)
      - `description`: string (e.g., `"LG Electronics 27GL850"`)
      - `make`: string, `model`: string, `serial`: string
      - `width`: number, `height`: number, `refreshRate`: number
      - `x`: number, `y`: number
      - `scale`: number (e.g. 1.0, 1.25)
      - `transform`: number (0, 1, 2, 3, 4...)
      - `focused`: boolean
      - `dpmsStatus`: boolean
      - `vrr`: number (0: off, 1: on, 2: fullscreen)
      - `mirrorOf`: string? (name of monitor being mirrored, or empty)
      - `availableModes`: array of string formatted modes (e.g. `["2560x1440@164.99Hz", "1920x1080@144.00Hz", ...]`)
      - `disabled`: boolean
    - Falls back to `noctalia.outputs()` if `hyprctl` is absent.
  - `hypr.applyMonitor(monitor: Monitor, onDone: ((boolean) -> ())?)`:
    - Constructs keyword command:
      - If `monitor.disabled`: `hyprctl keyword monitor "<name>,disable"`
      - If `monitor.mirrorOf` set: `hyprctl keyword monitor "<name>,preferred,auto,1,mirror,<mirrorOf>"`
      - Normal: `hyprctl keyword monitor "<name>,<width>x<height>@<refreshRate>,<x>x<y>,<scale>[,transform,<t>][,vrr,<v>]"`
    - Executes via `noctalia.runAsync`.
  - `hypr.applyBatch(monitors: { Monitor }, onDone: ((boolean) -> ())?)`:
    - Applies a list of monitor configurations sequentially or in a combined batch call.
  - `hypr.startSocketStream()`:
    - Locates `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
    - Streams events using `noctalia.runStream`:
      - On `monitoradded>>...` or `monitorremoved>>...`: triggers `hypr.refreshMonitors()` and notifies `profiles.checkAutoSwitch()`.
      - On `focusedmon>>...`: updates active screen focus indicators.

---

### 3.3 Layout Math & Coordinate Engine (`layout_math.luau`)

Encapsulates coordinate geometry, canvas scaling, and gapless edge alignment.

- **Proportional Canvas Projection**:
  - `layout_math.computeCanvasBounds(monitors: { Monitor }, canvasW: number, canvasH: number)`:
    - Calculates the bounding rectangle of all monitor layouts `(minX, minY, maxX, maxY)`.
    - Computes uniform scale factor to center and fit all monitors within the canvas preview viewport while preserving physical aspect ratios.
  - `layout_math.projectToCanvas(m: Monitor, factor: number, offsetX: number, offsetY: number)`:
    - Converts virtual pixel coordinates `(x, y, w, h)` to canvas UI pixels `(screenX, screenY, screenW, screenH)`.

- **Gapless Snap Calculations**:
  - `layout_math.snapRight(target: Monitor, anchor: Monitor)`:
    - Computes `target.x = anchor.x + math.floor(anchor.width / anchor.scale)` and `target.y = anchor.y`.
  - `layout_math.snapLeft(target: Monitor, anchor: Monitor)`:
    - Computes `target.x = anchor.x - math.floor(target.width / target.scale)` and `target.y = anchor.y`.
  - `layout_math.snapAbove(target: Monitor, anchor: Monitor)`:
    - Computes `target.x = anchor.x` and `target.y = anchor.y - math.floor(target.height / target.scale)`.
  - `layout_math.snapBelow(target: Monitor, anchor: Monitor)`:
    - Computes `target.x = anchor.x` and `target.y = anchor.y + math.floor(anchor.height / anchor.scale)`.
  - `layout_math.alignTops(target: Monitor, anchor: Monitor)`: Sets `target.y = anchor.y`.
  - `layout_math.alignBottoms(target: Monitor, anchor: Monitor)`: Sets `target.y = anchor.y + (anchor.height / anchor.scale) - (target.height / target.scale)`.
  - `layout_math.alignCenters(target: Monitor, anchor: Monitor)`: Vertically centers target relative to anchor.

- **Display Preset Helpers**:
  - `layout_math.presetExtend(monitors: { Monitor })`: Sets primary at 0x0, subsequent displays sequentially to the right.
  - `layout_math.presetMirror(monitors: { Monitor }, primaryName: string)`: Sets secondary displays to `mirror,primaryName`.
  - `layout_math.presetSingle(monitors: { Monitor }, keepName: string)`: Enables `keepName`, disables all other monitors.

---

### 3.4 Configuration Manager (`config.luau`)

Handles persistent storage in `~/.config/hypr/monitors.conf`.

- **Functions**:
  - `config.getConfigPath()`: Resolves setting `config_path` (default `~/.config/hypr/monitors.conf`).
  - `config.formatRule(m: Monitor): string`:
    - Produces clean, readable Hyprland syntax:
      `monitor = DP-1, 2560x1440@165.00Hz, 1920x0, 1.25, vrr, 1`
      or `monitor = eDP-1, disable`
  - `config.writeConfig(monitors: { Monitor }): (boolean, string?)`:
    - Reads existing file if present and backs it up to `<config_path>.bak`.
    - Formats header and active rules.
    - Writes file using `noctalia.writeFile`.
  - `config.isSourcedInHyprlandConf(): boolean`:
    - Inspects `~/.config/hypr/hyprland.conf` to check if `source = ...monitors.conf` is included.
    - If missing, returns `false` to prompt a helpful banner in the UI.

---

### 3.5 State Management Hub (`state.luau`)

Reactive store coordinating UI state, staged working changes, and subscriptions.

- **State Properties**:
  - `monitors`: Array of `Monitor` representing live system state.
  - `workingMonitors`: Deep copy of `monitors` where pending edits are staged.
  - `selectedMonitorName`: String of the currently inspected monitor.
  - `previousSafeMonitors`: Snapshot stored before clicking "Apply Live" for revert protection.
  - `activeTab`: `"inspector"` | `"profiles"`.
  - `safetyTimer`: Number of seconds remaining (15..0) when countdown is active.
  - `isSafetyModalVisible`: Boolean.
  - `hasPendingChanges`: Boolean, true when `workingMonitors` differs from `monitors`.
  - `listeners`: Array of render subscriber callbacks.

- **State Methods**:
  - `state.init(onReady: () -> ())`
  - `state.setWorkingProperty(monitorName: string, key: string, value: any)`
  - `state.selectMonitor(name: string)`
  - `state.startSafetyCountdown(onExpired: () -> ())`
  - `state.keepChanges()`: Commits working state, cancels timer, saves to active.
  - `state.revertToSafe()`: Restores `previousSafeMonitors`, applies via `hypr.applyBatch()`, hides modal.
  - `state.subscribe(callback: () -> ())`

---

### 3.6 Display Profile Store (`profiles.luau`)

Manages named presets stored in `noctalia.pluginDataDir() .. "/profiles.json"`.

- **Schema**:
  ```json
  {
    "active_profile": "office-dual",
    "profiles": [
      {
        "id": "office-dual",
        "name": "Office Dual Monitor",
        "monitors": [
          {
            "name": "eDP-1",
            "width": 1920,
            "height": 1080,
            "refreshRate": 144.0,
            "x": 0,
            "y": 0,
            "scale": 1.0,
            "transform": 0,
            "disabled": false
          },
          {
            "name": "DP-1",
            "width": 2560,
            "height": 1440,
            "refreshRate": 165.0,
            "x": 1920,
            "y": 0,
            "scale": 1.25,
            "transform": 0,
            "vrr": 1,
            "disabled": false
          }
        ]
      }
    ]
  }
  ```
- **Methods**:
  - `profiles.loadProfiles()`: Reads and deserializes stored profiles.
  - `profiles.saveProfile(name: string, monitors: { Monitor })`: Saves current layout as a named profile.
  - `profiles.deleteProfile(id: string)`: Removes a profile.
  - `profiles.applyProfile(id: string)`: Loads profile settings into `state.workingMonitors` and applies live.
  - `profiles.findMatchingProfile(connectedMonitors: { string }): Profile?`:
    - Compares list of connected monitor names against profile fingerprints.
    - Returns match if found.

---

### 3.7 UI Components & Panel Layout (`components.luau` & `panel.luau`)

Constructed with Noctalia's native declarative `ui.*` library, styled according to the **ui-ux-pro-max** Dark OLED/Utility guidelines.

- **Panel Window**:
  - 740px width × 560px height, centered, floating.
- **Header**:
  - Title: *"Hyprland Monitor Manager"*, icon: `device-desktop`.
  - Active profile badge and connected monitor count.
  - Close button.
- **Top Section: Visual Canvas**:
  - Scaled viewport with dark grid styling (`fill = "surface_variant"`, border `outline`).
  - Proportional monitor boxes with connector name, resolution, scale badge, and selection ring (`primary`).
  - Canvas Toolbar:
    - Snap Alignment: `Snap Left`, `Snap Right`, `Above`, `Below`, `Align Tops/Bottoms`.
    - Presets: `Extend`, `Mirror`, `Single Screen`, `External Only`.
- **Lower Section: Tabbed Workspace**:
  - **Tab 1: Monitor Inspector**:
    - Power toggle (Enable/Disable DPMS).
    - Mode selector: Hardware resolution & refresh rate dropdown.
    - Scale: Stepper and quick pill buttons (`1.0x`, `1.25x`, `1.5x`, `2.0x`).
    - Orientation: 4 rotation buttons (`0°`, `90°`, `180°`, `270°`).
    - Position readout: `X: 0, Y: 0` with fine-tuning steppers.
    - Mirroring target dropdown.
    - Advanced Accordion: VRR (Adaptive Sync) selector and 10-bit color toggle.
  - **Tab 2: Display Profiles**:
    - List of saved profiles with active indicator.
    - "Save Current as Profile" dialog button.
    - Auto-switch on connect toggle.
- **Footer Bar**:
  - Pending changes indicator.
  - Action buttons:
    - `[Revert]` (ghost button)
    - `[Apply Live]` (primary button, triggers 15s safety countdown)
    - `[Save to Config]` (secondary button, writes `~/.config/hypr/monitors.conf`)
- **Safety Revert Modal**:
  - Floating banner overlaid when countdown is active:
    - *"New display settings applied. Keep changes? Reverting in {N}s..."*
    - `[✓ Keep Changes]` (primary)
    - `[✕ Revert Now]` (error/outline)

---

### 3.8 Status Bar Widget (`widget.luau`)

- **Appearance**:
  - Glyph: `device-desktop` (switches to `screen-share` when mirroring).
  - Text counter: Number of active monitors (e.g. `2`).
  - Tooltip: Per-monitor resolution summary.
- **Actions**:
  - **Left Click**: Quick popover menu (Extend, Mirror, Laptop Only, External Only, saved profiles list, "Open Display Manager...").
  - **Right Click**: Directly toggles the full 740x560 panel.

---

## 4. Internationalization & Localization (`translations/`)

Full bilingual localization:
- `translations/en.json`: English strings for all titles, buttons, tooltips, presets, and errors.
- `translations/id.json`: Indonesian strings for all titles, buttons, tooltips, presets, and errors.

---

## 5. Automated Testing Strategy

Test suite implemented in Python (`unittest`) within `tests/`:
1. `test_hypr_monitors_manifest.py`:
   - Validates `plugin.toml` structure, keys, dependencies, and settings.
   - Verifies translation keys synchronization between `en.json` and `id.json`.
2. `test_hypr_monitors_config.py`:
   - Validates `config.luau` parser and writer logic.
   - Tests `monitor = ...` syntax generation for standard, disabled, mirrored, and VRR configurations.
   - Tests `.bak` backup file creation.
3. `test_hypr_monitors_layout.py`:
   - Validates mathematical calculations in `layout_math.luau`:
     - Proportional scaling and bounding box calculations.
     - Gapless snap coordinates for Left, Right, Above, Below.
4. `test_hypr_monitors_profiles.py`:
   - Validates profile JSON serialization and deserialization.
   - Tests monitor fingerprint matching on plug/unplug events.
5. `test_hypr_monitors_ipc.py`:
   - Validates command formulation for `hyprctl keyword monitor`.
   - Tests socket2 event parsing for `monitoradded` and `monitorremoved`.

---

## 6. Implementation Stages & Verification Gates

1. **Stage 1: Manifest, Translations, and Layout Math**
   - Create `plugin.toml`, `translations/en.json`, `translations/id.json`.
   - Implement `layout_math.luau` with unit tests for gapless math.
2. **Stage 2: Hyprland IPC Client & Configuration Writer**
   - Implement `hypr.luau` and `config.luau`.
   - Add unit tests for command formatting and config generation.
3. **Stage 3: State Management & Profiles Store**
   - Implement `state.luau` (safety countdown, staged changes) and `profiles.luau`.
   - Add unit tests for state mutations and profile matching.
4. **Stage 4: Declarative UI Components, Panel, and Widget**
   - Implement `components.luau` (proportional canvas cards, snap toolbar, stepper).
   - Implement `panel.luau` (canvas, inspector tab, profiles tab, safety modal) and `widget.luau` (quick popover).
5. **Stage 5: Documentation, Catalog Metadata & Final Verification**
   - Create `README.md` and catalog entries.
   - Run complete test suite and verify no regressions across the workspace.
