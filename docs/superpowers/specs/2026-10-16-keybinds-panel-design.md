# Keybinds Panel Plugin Design Specification

## Overview
Keybinds Panel is a Noctalia v5 community plugin (`rigelyon/keybinds`) providing a clean, aesthetic cheatsheet modal for Linux Hyprland shell keybindings combined with manually registered custom shortcuts (such as terminal multiplexers, shell shortcuts, and custom applications).

## Goals
- Dynamically parse and display active Hyprland keybinds via `hyprctl binds -j` without brittle file parsing.
- Provide a resilient, human-editable JSON configuration file (`~/.config/noctalia/custom_keybinds.json`) pre-populated with presets (Kitty, Shell CLI, Neovim).
- Deliver an aesthetically pleasing centered modal panel adhering to Noctalia's design tokens and `ui-ux-pro-max` guidelines.
- Support instant sub-millisecond search, category pill filtering with badge counters, visual `<kbd>` key badges, and click-to-copy functionality.
- Provide a lightweight status bar widget with a keyboard icon to toggle the cheatsheet panel.

---

## Architecture & Directory Layout

### Plugin Identification
- **Plugin ID**: `rigelyon/keybinds`
- **Directory**: `keybinds/`
- **Plugin API Version**: `28`
- **Default Icon**: `keyboard`
- **Category Tags**: `["utility", "hyprland", "keybinds", "cheatsheet", "panel", "bar"]`

### Directory Structure
```
keybinds/
├── plugin.toml             # Manifest declaring [[panel]], [[widget]], and [[setting]]
├── panel.luau              # Main panel UI, state management, search, and renderer
├── widget.luau             # Status bar widget
├── presets.luau            # Built-in fallback and default preset definitions
├── README.md               # User documentation for noctalia.dev
├── thumbnail.webp          # Store showcase image
└── translations/
    ├── en.json             # English translations
    └── id.json             # Indonesian translations
```

---

## Data Model & Parsing Engine

### 1. Hyprland Bitmask & Keycode Resolver
Hyprland exports keybindings via `hyprctl binds -j`. The resolver extracts modifiers using bitwise operations (`bit32.band`):
- `64` $\rightarrow$ `SUPER`
- `4` $\rightarrow$ `CTRL`
- `8` $\rightarrow$ `ALT`
- `1` $\rightarrow$ `SHIFT`

Visual order of modifiers: `SUPER` $\rightarrow$ `CTRL` $\rightarrow$ `ALT` $\rightarrow$ `SHIFT` $\rightarrow$ `[Key]`.

#### Special Key Mapping:
- **Keycodes**: `code:10` through `code:19` map to digits `1` through `0`. `code:79`..`code:90` map to Numpad numbers (`Num 0`..`Num 9`).
- **Mouse**: `mouse:272` $\rightarrow$ `Left Click`, `mouse:273` $\rightarrow$ `Right Click`, `mouse:274` $\rightarrow$ `Middle Click`, `mouse_up` $\rightarrow$ `Scroll Up`, `mouse_down` $\rightarrow$ `Scroll Down`.
- **Media & Hardware**:
  - `XF86AudioRaiseVolume` $\rightarrow$ `Vol +`
  - `XF86AudioLowerVolume` $\rightarrow$ `Vol -`
  - `XF86AudioMute` $\rightarrow$ `Mute`
  - `XF86AudioMicMute` $\rightarrow$ `Mic Mute`
  - `XF86MonBrightnessUp` $\rightarrow$ `Bright +`
  - `XF86MonBrightnessDown` $\rightarrow$ `Bright -`
  - `xf86AudioPlay` $\rightarrow$ `Play`
  - `xf86AudioStop` $\rightarrow$ `Stop`
  - `xf86AudioNext` $\rightarrow$ `Next`
  - `xf86AudioPrev` $\rightarrow$ `Prev`
  - `xf86Sleep` $\rightarrow$ `Sleep`
  - `xf86Rfkill` $\rightarrow$ `Airplane`
- **Symbols**:
  - `bracketleft` $\rightarrow$ `[`
  - `bracketright` $\rightarrow$ `]`
  - `Slash` $\rightarrow$ `/`
  - `Grave` $\rightarrow$ `` ` ``
  - `Comma` $\rightarrow$ `,`
  - `Period` $\rightarrow$ `.`
  - `Equal` $\rightarrow$ `=`
  - `Minus` $\rightarrow$ `-`

### 2. Multi-Tier Auto-Categorization
The parser groups each keybind into one of the following standard categories:
1. **Window Management** (`app_window`): Keywords matching `Window`, `Float`, `Pin`, `Fullscreen`, `Maximize`, `Focus`, `Move Window`, `Resize`, `Swap`, `Close Active`.
2. **Workspaces** (`grid_view`): Keywords matching `Workspace`, `Special Workspace`, `Next Workspace`, `Previous Workspace`.
3. **Apps & Launchers** (`rocket_launch`): Keywords starting with `Open `, or containing `Browser`, `Terminal`, `File Manager`, `Launcher`, `Control Center`, `Settings`, `Calculator`.
4. **Media & Hardware** (`volume_up`): Keywords matching `Volume`, `Brightness`, `Mic`, `Play`, `Stop`, `Track`, `Mute`, `Airplane`, `Sleep`.
5. **Screen & Tools** (`crop`): Keywords matching `Screenshot`, `Record`, `OCR`, `QR`, `Annotation`, `Clipboard`.
6. **System** (`power_settings_new`): Keywords matching `Exit`, `Lock`, `Suspend`, `Reboot`.
7. **Custom Categories**: Derived directly from the `name` field in `custom_keybinds.json` (e.g., `Kitty Terminal`, `Shell / CLI`, `Neovim`).
8. **Other / Misc**: Catch-all for uncategorized bindings to ensure no binding is dropped.

### 3. Custom Keybinds JSON Schema
Path: `~/.config/noctalia/custom_keybinds.json`
```json
{
  "categories": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "binds": [
        { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
        { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
        { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Pane" },
        { "keys": ["CTRL", "SHIFT", "["], "description": "Next Pane" },
        { "keys": ["CTRL", "SHIFT", "]"], "description": "Previous Pane" },
        { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
        { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" }
      ]
    },
    {
      "name": "Shell / CLI",
      "icon": "command",
      "binds": [
        { "keys": ["CTRL", "R"], "description": "Search Command History" },
        { "keys": ["CTRL", "L"], "description": "Clear Terminal Screen" },
        { "keys": ["CTRL", "C"], "description": "Interrupt / Cancel Process" },
        { "keys": ["CTRL", "Z"], "description": "Suspend Process to Background" },
        { "keys": ["CTRL", "A"], "description": "Move to Start of Line" },
        { "keys": ["CTRL", "E"], "description": "Move to End of Line" }
      ]
    }
  ]
}
```

### 4. Normalized In-Memory Item
```lua
type KeybindItem = {
  id: string,
  category: string,
  categoryIcon: string,
  modifiers: { string },
  key: string,
  keyComboText: string, -- e.g. "SUPER + SHIFT + T"
  description: string,
  source: "hyprland" | "custom",
  searchIndex: string,
}
```

---

## UI / UX Design & Presentation

### Modal Geometry
- Placement: `placement = "floating"`, `position = "center"`
- Dimensions: `width = 820`, `height = 640`
- `capture_keys = ["Escape"]`

### Visual Structure
1. **Header**:
   - Left: Icon (`keyboard`), title ("Keybinds Cheatsheet"), item count subtitle ("{count} active shortcuts").
   - Right: Action icons for Refresh (`refresh`), Open Settings (`settings`), and Close (`close`).
2. **Search Box**:
   - Real-time search input with clear icon when query is present.
   - Substring & multi-term matching across description, key combination, and category.
3. **Category Filter Chips**:
   - Horizontal pill bar with counts: `All`, `Window`, `Workspaces`, `Apps`, `Media`, `Screen`, `System`, plus custom tabs (`Kitty`, `Shell`).
   - Active pill highlighted with `primary` theme color; inactive pills styled with subtle borders.
4. **Keybinds Grid**:
   - 2-column responsive layout (configurable to 1-column in settings).
   - Each card contains:
     - Left: Descriptive text with high contrast.
     - Right: Visual `<kbd>` badges (`ui.box` with border, background, and mono/bold text) joined with `+` connectors.
   - Hover highlight: Subtle surface elevation / border accent.
   - Click action: Copies key combination to system clipboard via `noctalia.copyToClipboard` with temporary "Copied!" feedback badge.
5. **Footer Bar**:
   - Helpful shortcut hints: `[Esc] Close • [Click] Copy • Config: ~/.config/noctalia/custom_keybinds.json`.

---

## Settings & Configuration (`plugin.toml`)

```toml
id = "rigelyon/keybinds"
name = "Keybinds Cheatsheet"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = []
tags = ["utility", "hyprland", "keybinds", "cheatsheet", "panel", "bar"]
icon = "keyboard"
description = "Aesthetic keybindings cheatsheet panel for Hyprland shell with custom shortcut registry."

[[setting]]
key = "custom_file_path"
type = "string"
label_key = "settings.custom_file_path.label"
description_key = "settings.custom_file_path.description"
default = "~/.config/noctalia/custom_keybinds.json"

[[setting]]
key = "copy_on_click"
type = "bool"
label_key = "settings.copy_on_click.label"
description_key = "settings.copy_on_click.description"
default = true

[[setting]]
key = "grid_columns"
type = "select"
label_key = "settings.grid_columns.label"
description_key = "settings.grid_columns.description"
default = "2"
options = [
  { value = "1", label_key = "settings.grid_columns.options.1" },
  { value = "2", label_key = "settings.grid_columns.options.2" },
]

[[panel]]
id = "panel"
entry = "panel.luau"
placement = "floating"
position = "center"
width = 820
height = 640
capture_keys = ["Escape"]

[[widget]]
id = "widget"
entry = "widget.luau"
```

---

## Error Handling & Edge Cases
- **Missing / Inaccessible Hyprctl**: Displays an informational message banner: *"Hyprland binds unavailable — showing custom shortcuts"* while maintaining full functionality for custom JSON keybinds.
- **Corrupt / Invalid JSON**: File reading is wrapped in `pcall(noctalia.json.decode, raw)`. Errors are logged without crashing the panel or Noctalia shell.
- **Empty Query / No Results**: Friendly empty-state message with an icon and clear-search button.
- **Dynamic Updates**: Binds are queried fresh on `onOpen` and on manual Refresh (🔄), ensuring zero-restart synchronization with Hyprland reloads.
