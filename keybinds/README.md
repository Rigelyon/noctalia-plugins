# Keybinds Cheatsheet

<p align="center">
  <img src="thumbnail.webp" alt="Keybinds Cheatsheet" style="width: 100%; max-width: 680px; border-radius: 12px;" />
</p>

A sleek, aesthetic cheatsheet panel for Linux Hyprland keybindings paired with a customizable manual shortcut registry for terminal applications, shell commands, and custom tools.

## Features

- **⚡ Live Hyprland Sync**: Queries active keybindings directly from `hyprctl binds -j` without brittle config parsing. Updates instantly when Hyprland reloads.
- **✨ Smart Auto-Categorization**: Intelligently groups shortcuts into *Window Management*, *Workspaces*, *Apps & Launchers*, *Media & Hardware*, *Screen & Tools*, and *System*.
- **⌨️ Physical `<kbd>` Visual Styling**: Displays modifier combinations (`SUPER`, `CTRL`, `ALT`, `SHIFT`) and special keys formatted like physical mechanical keyboard keys.
- **🔍 Instant Multi-Word Search**: Filter shortcuts by description, key name, or category in real-time.
- **📋 Click to Copy**: Click any shortcut card to instantly copy the key combination string to your clipboard.
- **🛠️ Decoupled Custom Registry**: Includes built-in presets for Kitty Terminal, Shell CLI, and Neovim in `~/.config/noctalia/custom_keybinds.json`.
- **📊 Status Bar Widget**: Keyboard icon in your Noctalia bar with instant panel toggle.

## Requirements

- **Hyprland**: For dynamic Wayland keybinding discovery (`hyprctl`).
- **Noctalia v5** (Plugin API 28+).

## Custom Keybinds

Edit `~/.config/noctalia/custom_keybinds.json` to register custom shortcuts:

```json
{
  "categories": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "binds": [
        { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
        { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" }
      ]
    }
  ]
}
```

## Settings

- **Custom Keybinds File Path**: Path to manual JSON shortcut definitions.
- **Copy on Click**: Enable/disable automatic clipboard copy when clicking cards.
- **Grid Columns**: Choose between 1-column or 2-column layout.
