# Pinboard

A minimalist, intentional reference stash and always-on-top pinned screen overlay for artists and gamers on Noctalia Shell.

Pin anatomical sketches, character designs, color palettes, Minecraft crafting recipes, and coordinate checklists directly on your screen without window-management friction.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/pinboard` |
| Entries | Bar widget: `widget`; Panel: `panel`; Layer overlay: `ref-overlay`; Service: `service` |
| Target Compositor | Hyprland / Wayland Compositors |
| Plugin API | 38 |

---

## Features

- **Dual-Mode Wayland Overlay (`[[layer]]`)**:
  - **Interactive Mode**: Quick floating header toolbar to resize (Small 300px, Medium 420px, Large 560px), move across all 4 screen corners, adjust opacity (40%, 65%, 85%, 100%), switch references, and lock to Ghost.
  - **Ghost Mode (`clickThrough = true`)**: Toolbar hides, leaving only a subtle translucent border. **100% of mouse and pen clicks pass straight through** to your drawing software (Krita, Blender, Aseprite) or game (Minecraft) without accidental drags.
- **Single Smart Board (Split View Support)**:
  - **Image Only**: High-clarity reference viewer (`ui.image`) with automatic aspect ratio scaling.
  - **Notes Only**: Formatted Markdown notes and interactive task checklists (`ui.markdown`).
  - **Split View**: Image reference on top, checklist and coordinate notes on the bottom.
- **Intentional Stash (Clean & Uncluttered)**:
  - **Smart Paste to Stash**: Reads the clipboard only when you explicitly click "Paste". Automatically filters out plain text or passwords, accepting only valid image files, web URLs, and structured checklists.
  - **Browse File...**: Native file chooser integration via XDG portal / Zenity / Kdialog.
  - **New Note**: Built-in Markdown note editor with title and checklist formatting.
- **Global Shortcut & Status Bar Integration**:
  - Global hotkey to toggle Ghost Mode instantly without switching active windows.
  - Bar widget showing live mode badges (`GHOST`, `OFF`, or item count) with left-click, right-click, and scroll gestures.

---

## Usage

### 1. Adding References

1. Open the Pinboard stash panel by clicking the pin icon in your status bar or via IPC:
   ```sh
   noctalia msg panel-toggle rigelyon/pinboard:panel
   ```
2. Add reference content using any of the 3 actions:
   - **Paste to Stash**: Copy any image or image URL from your browser, or copy a checklist from your notes, then click Paste.
   - **Browse File...**: Pick an image file directly from your disk.
   - **New Note**: Write down coordinates, crafting recipes, or drawing notes.
3. Click **"Pin"** on any item to make it the active pinned reference.

### 2. Interactive vs. Ghost Mode

- While in **Interactive Mode**, the floating header toolbar at the top of the overlay lets you:
  - Cycle corner position: Top-Right → Bottom-Right → Bottom-Left → Top-Left.
  - Change window size: Small (300px) / Medium (420px) / Large (560px).
  - Cycle opacity: 40% → 65% → 85% → 100%.
  - Cycle view layout: Split → Image Only → Note Only.
  - Next / Previous reference item.
  - Click **"Lock to Ghost"** when you are ready to play or draw.
- In **Ghost Mode**, mouse clicks pass through completely to your application. To unlock, simply press your global hotkey or right-click the status bar widget.

---

## Global Shortcuts (Hyprland Configuration)

Wayland compositors handle global hotkeys. Add these recommended bindings to your `~/.config/hypr/hyprland.conf`:

```ini
# Toggle Ghost Mode (Lock / Unlock click-through)
bind = SUPER ALT, G, exec, noctalia msg plugin rigelyon/pinboard:service all toggle-ghost

# Show or Hide the Reference Overlay
bind = SUPER ALT, O, exec, noctalia msg plugin rigelyon/pinboard:service all toggle-overlay

# Quick cycle next/previous reference item
bind = SUPER ALT, bracketright, exec, noctalia msg plugin rigelyon/pinboard:service all next-item
bind = SUPER ALT, bracketleft, exec, noctalia msg plugin rigelyon/pinboard:service all prev-item

# Quick Paste from Clipboard to Stash
bind = SUPER ALT, V, exec, noctalia msg plugin rigelyon/pinboard:service all paste-clipboard
```

---

## IPC Commands

You can trigger any Pinboard feature from custom shell scripts, terminal commands, or compositor keybinds:

```sh
# Toggle Ghost Mode (Click-Through)
noctalia msg plugin rigelyon/pinboard:service all toggle-ghost

# Toggle Overlay visibility on screen
noctalia msg plugin rigelyon/pinboard:service all toggle-overlay

# Move overlay to specific corner
noctalia msg plugin rigelyon/pinboard:service all set-anchor top_right
noctalia msg plugin rigelyon/pinboard:service all set-anchor top_left
noctalia msg plugin rigelyon/pinboard:service all set-anchor bottom_right
noctalia msg plugin rigelyon/pinboard:service all set-anchor bottom_left

# Set opacity directly (0.2 to 1.0)
noctalia msg plugin rigelyon/pinboard:service all set-opacity 0.75

# Cycle next or previous reference
noctalia msg plugin rigelyon/pinboard:service all next-item
noctalia msg plugin rigelyon/pinboard:service all prev-item

# Trigger clipboard paste to stash
noctalia msg plugin rigelyon/pinboard:service all paste-clipboard

# Toggle the Stash management panel
noctalia msg panel-toggle rigelyon/pinboard:panel
```

---

## Settings

Settings can be customized in **Noctalia Settings → Plugins → Pinboard**:

| Setting | Type | Default | Description |
|---|---|---|---|
| `default_anchor` | `select` | `top_right` | Initial screen corner for the pinned overlay |
| `default_opacity` | `number` | `0.85` | Initial transparency level (0.2 to 1.0) |
| `default_scale` | `select` | `medium` | Initial window size (Small, Medium, Large) |
| `save_clipboard_images` | `bool` | `true` | Save local copy of pasted images |
