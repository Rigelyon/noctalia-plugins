# Hyprland Layout Switcher

<p align="center">
  <img src="thumbnail.webp" alt="Hyprland Layout Switcher" style="width: 100%; max-width: 600px; border-radius: 12px;" />
</p>

An aesthetic, intuitive layout switcher plugin for **Noctalia** on **Hyprland**. Switch seamlessly between tiling layouts globally or specifically for your active workspace with real-time feedback and schematic window wireframe previews.

---

## ✨ Features

- **Dual-Action Status Bar Widget**:
  - **Left Click**: Instantly cycle to the next enabled layout (`dwindle` → `master` → optional plugins).
  - **Right Click**: Open the visual **Layout Hub** floating panel.
  - Active layout name and glyph visible directly in your status bar.

- **Schematic Window Wireframe Previews**:
  - Miniature diagrams illustrate how windows tile in each layout:
    - **Dwindle**: Fibonacci spiral arrangement.
    - **Master**: Dominant master column flanked by stacked slave windows.
    - **Hy3**: Manual container groups and tabbed windows.
    - **Scroller**: Horizontal carousel columns (PaperWM style).

- **Dual Scope Control**:
  - **Global Session**: Applies layout changes compositor-wide via `hyprctl keyword general:layout <name>`.
  - **Workspace Specific**: Applies layout changes targeting only the active workspace via `hyprctl keyword workspace <id>,layout:<name>`.

- **Context-Aware Sub-Actions**:
  - Quick buttons for layout-specific dispatcher messages:
    - *Dwindle*: Toggle Split, Pseudo-tile, Swap Split.
    - *Master*: Swap Master, Cycle Next, + Master, - Master.
    - *Hy3*: Group Horizontal, Group Vertical, Tabs.
    - *Scroller*: Cycle Size, Toggle Overview.

- **Real-Time Hyprland Socket2 Sync**:
  - Listens to Hyprland's UNIX domain socket stream (`.socket2.sock`) for instant zero-latency updates when workspaces change or configurations reload.
  - Graceful fallback when running in non-Hyprland environments.

---

## 📦 Dependencies

- `hyprland`: The Wayland compositor (`hyprctl`).
- `socat` *(optional, recommended)*: Enables instantaneous socket2 event streaming.

---

## ⚙️ Configuration

Configure via Noctalia Settings (`Settings` → `Plugins` → `Hyprland Layout Switcher`):

| Setting | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `default_scope` | Select | `global` | Default target scope (`global` or `workspace`). |
| `show_label_in_bar` | Bool | `true` | Show layout text name next to the icon in status bar. |
| `notify_on_change` | Bool | `true` | Display desktop notification when layout changes. |
| `enable_hy3` | Bool | `false` | Enable hy3 plugin manual tiling layout. |
| `enable_scroller` | Bool | `false` | Enable hyprscroller PaperWM layout. |

---

## 📄 License

MIT © [rigelyon](https://github.com/rigelyon)
