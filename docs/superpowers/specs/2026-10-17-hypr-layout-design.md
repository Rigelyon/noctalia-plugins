# Hyprland Layout Switcher (`rigelyon/hypr-layout`) Design Specification

- **Plugin ID**: `rigelyon/hypr-layout`
- **Plugin Directory**: `hypr-layout/`
- **Target Platform**: Noctalia Shell (Wayland / Hyprland Compositor)
- **Plugin API Version**: 28
- **Date**: 2026-10-17
- **Author**: rigelyon

---

## 1. Executive Summary & Goals

The **Hyprland Layout Switcher** (`rigelyon/hypr-layout`) is a native Noctalia plugin that allows users to seamlessly view, toggle, and manage Hyprland window tiling layouts both globally and on a per-workspace basis.

### Core Objectives
1. **Instant Feedback & Dual-Action Widget**: A status bar widget that displays the active layout icon & name, enabling one-click cycling (Left Click) and one-click opening of the visual layout panel (Right Click).
2. **Visual Layout Hub with Schematic Wireframes**: A dedicated floating panel providing rich preview cards with custom miniature window wireframe diagrams (illustrating Dwindle spiral, Master & stack, Hy3 tabs, and Scroller columns).
3. **Dual Scope Control (Global vs. Workspace)**: Support for switching layouts across the entire Hyprland session (`general:layout`) or targeting only the currently active workspace (`workspace <id>,layout:<name>`).
4. **Sub-Actions Bar**: Quick controls tailored to the active layout (e.g. Dwindle: Toggle Split, Pseudo-tile, Swap Split; Master: Swap with Master, Cycle Next, Add/Remove Master).
5. **Realtime Socket2 Streaming Synchronization**: Live synchronization via Hyprland's UNIX domain socket (`.socket2.sock`) with zero visual latency when switching workspaces or reloading configs, backed by graceful non-Hyprland fallbacks.

---

## 2. Architecture & File Structure

```text
hypr-layout/
├── plugin.toml            # Manifest: plugin metadata, widget, panel, settings definitions
├── widget.luau            # Status bar widget entry script (dual action, state subscription)
├── panel.luau             # Floating panel entry script (Layout Hub UI, segmented scope, sub-actions)
├── hypr.luau              # Hyprland IPC client (hyprctl execution + socket2 event stream reader)
├── state.luau             # Central reactive state manager & subscriber hub
├── layouts.luau           # Layout registry (dwindle, master, hy3, scroller) & sub-action definitions
├── components.luau        # Declarative UI component library (schematic wireframe generators & cards)
├── README.md              # Documentation, dependencies, and feature guide
├── thumbnail.webp         # Catalog card artwork for Noctalia plugin store
└── translations/
    ├── en.json            # English translations
    └── id.json            # Indonesian translations
```

---

## 3. Component Details & Technical Specifications

### 3.1 Manifest (`plugin.toml`)

- **Plugin Identifiers**:
  - `id = "rigelyon/hypr-layout"`
  - `name = "Hyprland Layout Switcher"`
  - `version = "1.0.0"`
  - `plugin_api = 28`
  - `author = "rigelyon"`
  - `license = "MIT"`
  - `icon = "layout-grid"`
  - `tags = ["hyprland", "layout", "utility", "bar", "panel", "productivity"]`
  - `dependencies = ["hyprland"]`

- **Settings**:
  - `default_scope`: `select` (`"global"` | `"workspace"`, default: `"global"`)
  - `show_label_in_bar`: `bool` (default: `true`)
  - `notify_on_change`: `bool` (default: `true`)
  - `enable_hy3`: `bool` (default: `false`)
  - `enable_scroller`: `bool` (default: `false`)

- **Entries**:
  - `[[widget]]`: `id = "widget"`, `entry = "widget.luau"`, `actions = { middle = "none" }`
  - `[[panel]]`: `id = "panel"`, `entry = "panel.luau"`, `placement = "floating"`, `position = "center"`, `width = 720`, `height = 540`, `capture_keys = ["Escape"]`

---

### 3.2 Hyprland IPC Engine (`hypr.luau`)

Communicates asynchronously with the Hyprland compositor:

1. **Global Layout Retrieval**:
   - Executes `hyprctl getoption general:layout -j` using `noctalia.runAsync`.
   - Parses the JSON response to extract `data.str` (e.g. `"dwindle"`).

2. **Active Workspace Retrieval**:
   - Executes `hyprctl activeworkspace -j` to obtain `{ id = number, name = string, monitor = string }`.

3. **Applying Layout Changes**:
   - **Global Scope**: Executes `hyprctl keyword general:layout <layoutName>`.
   - **Workspace Scope**: Executes `hyprctl keyword workspace <workspaceId>,layout:<layoutName>`.

4. **Sub-Actions Execution**:
   - Executes `hyprctl dispatch layoutmsg <command>` (or plugin-specific dispatchers such as `hy3:makegroup` or `scroller:cyclesize`).

5. **Socket2 Real-time Event Listener**:
   - Identifies Hyprland socket at `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
   - Reads event lines using `noctalia.runStream`:
     - `workspace>>*`: User switched workspace -> query active workspace and update state.
     - `focusedmon>>*`: Active monitor focused -> update active workspace and layout.
     - `configreloaded>>*`: Hyprland configuration reloaded -> refresh global layout.
   - **Resilience**: If `socat` or socket is unavailable, degrades safely to polling on panel open and widget clicks.

---

### 3.3 Reactive State Manager (`state.luau`)

Maintains in-memory application state and coordinates UI updates:

- **State Properties**:
  - `globalLayout`: string (current active global layout name, e.g. `"dwindle"`).
  - `activeWorkspaceId`: number (e.g. `1`).
  - `activeWorkspaceName`: string (e.g. `"1"`).
  - `workspaceLayouts`: table mapping `[workspaceId] = layoutName`.
  - `currentScope`: `"global"` | `"workspace"`.
  - `listeners`: list of subscriber callback functions `(state) -> ()`.

- **State API**:
  - `state.subscribe(fn)`: Registers a callback to receive state change notifications.
  - `state.notify()`: Triggers all registered callbacks.
  - `state.getEffectiveLayout()`: Returns the workspace layout if scope is `"workspace"` and defined, otherwise returns `globalLayout`.
  - `state.setScope(scope)`: Switches between `"global"` and `"workspace"`.

---

### 3.4 Layout Registry (`layouts.luau`)

Defines layout metadata, sub-actions, and wireframe generator identifiers:

| Layout ID | Name | Category | Phosphor Icon | Sub-actions |
| :--- | :--- | :--- | :--- | :--- |
| `dwindle` | Dwindle | Spiral Dynamic | `layout-split` | `togglesplit` ("Toggle Split"), `pseudo` ("Pseudo-tile"), `swapsplit` ("Swap Split") |
| `master` | Master | Master & Stack | `layout-sidebar` | `swapwithmaster` ("Swap Master"), `cyclenext` ("Cycle Next"), `addmaster` ("+ Master"), `removemaster` ("- Master") |
| `hy3` | Hy3 | i3/Sway Manual | `layout-columns` | `hy3:makegroup,h` ("Group H"), `hy3:makegroup,v` ("Group V"), `hy3:makegroup,tab` ("Tabs") |
| `scroller` | Scroller | PaperWM Strip | `sliders-horizontal` | `scroller:cyclesize` ("Cycle Size"), `scroller:toggleoverview` ("Overview") |

---

### 3.5 Schematic Wireframe Generator & UI Components (`components.luau`)

Implements **UI/UX Pro Max** standards using Noctalia's native declarative UI (`ui.box`, `ui.row`, `ui.column`):

1. **Miniature Window Wireframes** (54px × 36px diagram boxes):
   - **Dwindle Wireframe**: Rendered with a 50% left window box and a 50% right column subdivided into top-right and bottom-right window boxes.
   - **Master Wireframe**: Rendered with a prominent 60% master left column and a 40% slave column containing two stacked horizontal tiles.
   - **Hy3 Wireframe**: Rendered with top container tab pills and subdivided horizontal window columns.
   - **Scroller Wireframe**: Rendered with a 3-column horizontal strip with the center column highlighted as active.

2. **Interactive Layout Cards**:
   - Dynamic fill tokens: `surface_variant` for default, `primary_container` when active.
   - Border & Accent: `primary` token highlight when active, accompanied by an `Active` badge and `check` glyph.
   - Hover Feedback: Smooth transition on pointer enter/leave.

3. **Sub-Actions Control Bar**:
   - Layout-specific button pills rendered using `ui.button` with `ghost` or `tonal` styling, icons, and descriptive tooltips.

---

### 3.6 Floating Panel & Bar Widget (`panel.luau` & `widget.luau`)

1. **Floating Panel (`panel.luau`)**:
   - **Header**: Title, active workspace indicator (`Workspace <id>`), Segmented Scope Switch (`[ Global | Workspace <id> ]`), and close button.
   - **Main Grid**: 2-column layout cards with wireframe previews, descriptions, and click-to-activate interaction.
   - **Active Controls Bar**: Sub-action buttons for the currently active layout.
   - **Footer**: Usage shortcuts and link to plugin settings via `noctalia.openSettings()`.

2. **Bar Widget (`widget.luau`)**:
   - Glyph & Text: Displays active layout icon and optional label (configured via `show_label_in_bar`).
   - Left-Click (`onClick`): Instantly cycles to the next enabled layout in rotation and applies it according to `default_scope`.
   - Right-Click (`onRightClick`): Toggles the floating panel (`noctalia.togglePanel("rigelyon/hypr-layout:panel")`).
   - Reactive Sync: Auto-updates immediately upon state notification.

---

## 4. Internationalization (i18n)

Provides complete translations for English (`translations/en.json`) and Indonesian (`translations/id.json`):
- All settings labels and descriptions.
- Panel headings, scope toggles, layout titles, categories, and descriptions.
- Sub-action button labels and tooltips.
- Notification messages on layout change.

---

## 5. Verification & Testing Strategy

1. **Syntax & Linter Checks**:
   - Validate all `.luau` files against `noctalia.d.luau` and `.luaurc` using Luau LSP / analysis.
2. **IPC & Fallback Verification**:
   - Verify proper execution in headless/container environments where `hyprctl` is not active (safe degradation, informative notifications, no nil indexing crashes).
3. **Simulated State & Cycle Tests**:
   - Verify layout cycling order (`dwindle` -> `master` -> enabled plugins -> `dwindle`).
   - Verify scope toggles between global and per-workspace commands.
4. **Visual & Accessibility Inspection**:
   - Verify contrast of all labels against backgrounds according to WCAG AA (>= 4.5:1).
   - Ensure touch targets and clickable cards meet minimum sizing requirements (>= 44px).
