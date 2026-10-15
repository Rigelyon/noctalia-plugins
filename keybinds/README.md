# Keybinds Cheatsheet

![Keybinds Cheatsheet](thumbnail.webp)

A sleek, aesthetic cheatsheet panel for Linux Hyprland keybindings paired with a customizable manual shortcut registry for terminal applications, shell commands, and custom tools.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/keybinds` |
| Entries | Bar widget: `widget`; panel: `panel` |

## Requirements

- `hyprland`: For dynamic Wayland keybinding discovery (`hyprctl`).
- Noctalia v5 (Plugin API 28+).

## Usage

Add the `widget` bar widget to your status bar layout in Noctalia Settings, or click it to open the cheatsheet. You can also toggle the `panel` directly from a Hyprland keybind or terminal command:

```sh
noctalia msg panel-toggle rigelyon/keybinds:panel
```

To bind this in your Hyprland configuration (`~/.config/hypr/configs/keybinds.lua`):

```lua
hl.bind("SUPER + F1", hl.dsp.exec_cmd("noctalia msg panel-toggle rigelyon/keybinds:panel"), { description = "Open Keybinds Cheatsheet" })
```

### Features

- **Live Hyprland Sync**: Queries active keybindings directly from `hyprctl binds -j`. Updates instantly when Hyprland reloads.
- **Smart Auto-Categorization**: Intelligently groups shortcuts into *Window Management*, *Workspaces*, *Apps & Launchers*, *Media & Hardware*, *Screen & Tools*, and *System*.
- **Physical `<kbd>` Visual Styling**: Displays modifier combinations (`SUPER`, `CTRL`, `ALT`, `SHIFT`) and special keys formatted like physical mechanical keyboard keys.
- **Instant Multi-Word Search**: Filter shortcuts by description, key name, or category in real-time.
- **Click to Copy**: Click any shortcut card to instantly copy the key combination string to your clipboard.
- **Decoupled Custom Registry**: Includes built-in presets for Kitty Terminal, Shell CLI, and Neovim in `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json`.

### Custom Keybinds

Edit `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json` to register custom shortcuts:

```json
{
  "apps": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "subcategories": [
        {
          "name": "Tabs & Windows",
          "icon": "app-window",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
            { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" }
          ]
        }
      ]
    }
  ]
}
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `custom_file_path` | `string` | `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json` | Path to manual JSON shortcut definitions. |
| `copy_on_click` | `bool` | `true` | Automatically copies the key combination to clipboard when clicking a card. |
| `grid_columns` | `select` | `3` | Number of columns to display in the shortcuts grid (`1`, `2`, or `3`). |

## Notes

- Binds are fetched dynamically via `hyprctl binds -j` on panel open and manual refresh.
- If Hyprland is unavailable, custom keybinds remain accessible.
