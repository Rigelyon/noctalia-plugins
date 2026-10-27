# Pinboard (`rigelyon/pinboard`) Design Specification

- **Plugin ID**: `rigelyon/pinboard`
- **Plugin Directory**: `pinboard/`
- **Target Platform**: Noctalia Shell (Wayland / Hyprland & General Wayland Compositors)
- **Plugin API Version**: 38
- **Date**: 2026-10-27
- **Author**: rigelyon

---

## 1. Executive Summary & Problem Statement

Artists, digital illustrators, and gamers frequently need reference material (anatomy sketches, color palettes, pose photos, Minecraft crafting recipes, redstone schematics, Nether coordinate checklists) pinned on-screen while working in fullscreen or tiled applications (e.g. Krita, Blender, Aseprite, Minecraft).

Traditional solutions have friction on Wayland:
1. **Standalone windows (PureRef, image viewers)** steal keyboard and mouse focus, disrupt game controls (first-person mouse capture in Minecraft), and require clumsy window-rule wrangling to keep them floating, borderless, and always-on-top across workspaces.
2. **Clipboard Managers** are noisy dumping grounds: every text snippet, URL, and password gets mixed in, cluttering references.
3. **Passive Overlays** lack quick controls to toggle click-through, adjust opacity on the fly, or switch between references during gameplay.

### Core Objectives
1. **Intentional Reference Stash**: A curated shelf for references (images and Markdown notes). Ingestion is deliberate (manual "Paste to Stash" button with MIME type validation, "Browse File" native portal dialog, or in-panel note creation) so it never pollutes or duplicates the user's general clipboard manager.
2. **Dual-Mode Wayland Overlay (`[[layer]]`)**:
   - **Interactive Mode**: Minimal floating toolbar with opacity slider, corner anchor presets, zoom/scale steppers, Next/Prev buttons, and a prominent "Lock to Ghost" button.
   - **Ghost Mode (`clickThrough = true`)**: The toolbar hides, a subtle translucent 1px accent border remains, and **100% of mouse and pen input passes completely through to the underlying application** (Minecraft or drawing software).
3. **Single Smart Board (Split View Support)**:
   - Single unified layer surface to eliminate Wayland multi-surface synchronization issues.
   - Three layout modes: **Image Only**, **Notes Only** (with rendered Markdown & interactive `[x]` checkboxes), or **Split View** (Image on top, Notes/Checklist on bottom).
4. **Instant IPC & Status Bar Coordination**:
   - Global hotkey support (e.g., `Super+Alt+G` bound in Hyprland) to toggle Ghost Mode on the fly.
   - Bar widget with visual mode badges (`Ghost`, `Edit`, `Hidden`) and quick click gestures.
5. **Robust Persistence & Offline Isolation**:
   - Persistent JSON store in `noctalia.pluginDataDir() / "pinboard.json"`.
   - Local caching of pasted images into `pinboard/data/images/`.

---

## 2. Architecture & File Structure

```text
pinboard/
├── plugin.toml            # Manifest: metadata, settings, widget, panel, layer, service
├── widget.luau            # Status bar widget (mode indicator, click actions, tooltip)
├── panel.luau             # Management panel (Stash gallery, note editor, presets, settings)
├── overlay.luau           # Pinned overlay layer entry (Dual-mode rendering, toolbar, viewer)
├── service.luau           # Background IPC coordinator & central reactive dispatcher
├── state.luau             # Central reactive state manager & subscriber hub
├── storage.luau           # JSON serialization, disk read/write, file caching
├── components.luau        # Declarative UI component library (cards, toolbar, badges, sliders)
├── README.md              # Documentation, shortcuts, and usage guide
├── thumbnail.webp         # Catalog card artwork for Noctalia plugin store
└── translations/
    ├── en.json            # English localization
    └── id.json            # Indonesian localization
```

---

## 3. Component Details & Technical Specifications

### 3.1 Manifest (`plugin.toml`)

- **Plugin Identifiers**:
  - `id = "rigelyon/pinboard"`
  - `name = "Pinboard"`
  - `version = "1.0.0"`
  - `plugin_api = 38`
  - `author = "rigelyon"`
  - `license = "MIT"`
  - `icon = "pin"`
  - `description = "Minimalist reference stash and pinned screen overlay for artists and gamers."`
  - `tags = ["utility", "productivity", "layer", "panel", "bar", "art", "gaming"]`

- **Plugin Settings**:
  - `default_anchor`: string select (`"top_right"`, `"top_left"`, `"bottom_right"`, `"bottom_left"`). Default: `"top_right"`.
  - `default_opacity`: number slider (`0.2` to `1.0`, step `0.05`). Default: `0.85`.
  - `default_scale`: select (`"small"`, `"medium"`, `"large"`). Default: `"medium"`.
  - `hotkey_ghost_toggle`: string (default `"Super+Alt+G"` for user guidance).
  - `save_clipboard_images`: bool (default `true`, automatically cache images locally).

- **Entries**:
  1. `[[widget]]` (`widget.luau`): Status bar quick-toggle & state indicator.
  2. `[[panel]]` (`panel.luau`): Attached drawer panel (width: 440, height: 560).
  3. `[[layer]]` (`overlay.luau`): Layer shell surface (`layer = "overlay"`).
  4. `[[service]]` (`service.luau`): Headless coordinator managing IPC events and state sync.

---

### 3.2 State Store & Data Models (`state.luau` & `storage.luau`)

#### Data Schema (`pinboard.json`)
```json
{
  "version": 1,
  "active_id": "item_1700000001",
  "ghost_mode": false,
  "overlay_visible": true,
  "view_mode": "split",
  "opacity": 0.85,
  "scale": "medium",
  "anchor": "top_right",
  "items": [
    {
      "id": "item_1700000001",
      "type": "image",
      "title": "Character Pose Reference",
      "path": "/home/user/.local/share/noctalia/plugins/pinboard/images/pose_1.png",
      "source_url": "",
      "created_at": 1787671119
    },
    {
      "id": "item_1700000002",
      "type": "note",
      "title": "Nether Fortress Checklist",
      "content": "### Coordinates\n- Nether Portal: X: 142, Z: -520\n- Fortress: X: 210, Z: -680\n\n### Checklist\n- [x] Obsidian x14\n- [ ] Fire Resistance Potions x3\n- [ ] Bow & Arrows\n- [ ] Golden Apple",
      "created_at": 1787671200
    }
  ]
}
```

#### Size & Scale Constants
| Scale Preset | Width (px) | Max Height (px) | Image Max Height (px) |
|---|---|---|---|
| `small` | 300 | 360 | 220 |
| `medium` | 420 | 500 | 320 |
| `large` | 560 | 680 | 440 |

#### Anchor Margins & Positions
| Anchor | Anchors Prop | Default Margins |
|---|---|---|
| `top_right` | `{"top", "right"}` | `{ top = 24, right = 24 }` |
| `top_left` | `{"top", "left"}` | `{ top = 24, left = 24 }` |
| `bottom_right` | `{"bottom", "right"}` | `{ bottom = 24, right = 24 }` |
| `bottom_left` | `{"bottom", "left"}` | `{ bottom = 24, left = 24 }` |

---

### 3.3 Overlay Surface Engine (`overlay.luau`)

The overlay surface is driven by Noctalia's `[[layer]]` system with `layer = "overlay"`:
1. **Lifecycle & Layer Configuration**:
   ```luau
   noctalia.layer.configure("ref-overlay", {
       layer = "overlay",
       anchors = currentAnchors,
       width = currentWidth,
       margins = currentMargins,
       clickThrough = state.ghost_mode,
   })
   ```
2. **Interactive Mode UI Elements**:
   - **Header Bar**:
     - Drag/Move Anchor button (cycles: Top-Right → Bottom-Right → Bottom-Left → Top-Left).
     - Scale stepper (`S` / `M` / `L`).
     - Opacity slider (`-` / `+` quick notches: 30%, 50%, 75%, 90%, 100%).
     - View mode toggle (`Image` / `Note` / `Split`).
     - **Lock Button (`"Lock to Ghost"`)**: Immediately flips `ghost_mode = true` and updates layer to `clickThrough = true`.
   - **Navigation Footer**:
     - `[ < ]` Item Counter `[ 2 / 5 ]` `[ > ]` to quickly cycle reference assets without opening the panel.
3. **Ghost Mode UI Elements**:
   - Header and toolbar are completely hidden to avoid obstructing the artwork or game.
   - Rendered with `opacity = state.opacity`.
   - Border: 1px subtle rounded border (`alpha = 0.25`) in theme's primary color, indicating the active boundary.
   - Mouse events fall directly through to the desktop/game.

---

### 3.4 Management Panel (`panel.luau`)

The panel provides the primary library management interface:
1. **Header & Action Bar**:
   - **Paste to Stash (`ui.button`)**: Inspects `noctalia.clipboardText()` or clipboard MIME. Validates whether content is a file path, image URL, or markdown text.
   - **Browse File (`ui.button`)**: Opens native file picker using `noctalia.runAsync` with `zenity --file-selection` or `kdialog` / XDG portal.
   - **New Note (`ui.button`)**: Opens inline markdown editor for crafting checklists and notes.
2. **Stash Library Card List**:
   - Thumbnail preview for images / markdown icon for notes.
   - Title, badge (Image / Note), timestamp.
   - "Pin Now" action button.
   - Delete button with confirmation.
3. **Overlay Control & Settings Section**:
   - Visibility toggle (`Show / Hide Overlay`).
   - Ghost mode toggle (`Interactive / Ghost`).
   - Opacity slider with live value readout.
   - Corner preset selector (4-button quadrant group).
   - Hyprland bind helper display:
     `bind = SUPER ALT, G, exec, noctalia msg plugin rigelyon/pinboard:service all toggle-ghost`

---

### 3.5 Background Service & IPC Protocol (`service.luau`)

The service acts as the single source of truth and coordinates IPC commands:
- `toggle-overlay`: Shows/hides the layer overlay surface.
- `toggle-ghost`: Toggles between Interactive and Ghost mode.
- `set-anchor <top_right|top_left|bottom_right|bottom_left>`: Changes anchor.
- `set-opacity <0.1..1.0>`: Adjusts transparency.
- `next-item`: Cycles to next stash item.
- `prev-item`: Cycles to previous stash item.
- `pin-item <id>`: Activates a specific item by ID.
- `paste-clipboard`: Triggers manual paste processing from external scripts/keybinds.

---

## 4. Design System Tokens & Aesthetics (`ui-ux-pro-max`)

Following the minimalism & Swiss design principles:
- **Palette**:
  - `Surface`: Adaptive Noctalia shell surface with subtle glass translucency (`#12161f` / `#1e2430` at 92% opacity).
  - `Accent / Focus`: Vivid cyan/blue (`#38bdf8`) for active items and lock badges.
  - `Ghost Accent`: Soft lavender/muted blue (`#818cf8` at 40% alpha) for ghost border indicator.
  - `Muted Text`: `#94a3b8` (minimum 4.5:1 contrast against surface).
- **Typography**:
  - Clean geometric sans-serif (system font, Archivo, or Space Grotesk).
  - Monospace formatting for coordinates and checklists.
- **Ergonomics & Touch/Click Targets**:
  - All interactive buttons have minimum 32px height and ≥8px padding.
  - Smooth transitions without layout shifting.

---

## 5. Verification & Testing Plan

1. **Manifest & Translation Validation**:
   - Run `noctalia plugins lint pinboard/` to guarantee zero schema or key errors.
   - Verify all manifest `label_key` and `description_key` entries exist in `translations/en.json` and `translations/id.json`.
2. **State & Storage Unit Tests (`tests/test_pinboard_*.py`)**:
   - Test JSON serialization and fallback creation when `pinboard.json` is missing.
   - Test add/remove/reorder operations.
   - Test clipboard URL and path validation filters.
   - Test cyclic Next/Prev navigation bounds.
3. **IPC Command Integration Tests**:
   - Test all IPC event payloads (`toggle-ghost`, `set-anchor`, `next-item`, `prev-item`).
4. **Overlay Render Tree Integrity**:
   - Verify `overlay.luau` properly emits valid `UiNode` trees for Image, Note, and Split views without nil prop exceptions.
