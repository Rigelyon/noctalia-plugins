# Hyprland Layout Switcher (`rigelyon/hypr-layout`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Noctalia plugin to seamlessly inspect, toggle, and manage Hyprland window tiling layouts both globally and per-workspace with a status bar widget and a floating Layout Hub panel featuring schematic window wireframe previews.

**Architecture:** A modular controller and reactive state architecture written in Luau. `hypr.luau` interfaces with the Hyprland compositor asynchronously and streams socket2 events; `state.luau` manages reactive subscriptions; `layouts.luau` provides metadata and sub-actions; `components.luau` produces schematic window wireframes; `widget.luau` renders the bar widget with dual-click actions; and `panel.luau` renders the full Layout Hub UI.

**Tech Stack:** Luau (Noctalia Plugin API 28, declarative UI `ui.*`), Hyprland IPC (`hyprctl`, socket2 UNIX domain socket), Python 3 + `pytest` (test suite).

## Global Constraints
- Target directory: `hypr-layout/`
- Plugin ID: `rigelyon/hypr-layout`
- Plugin API version: 28
- License: MIT, Author: rigelyon
- Follow Noctalia UI token discipline (`surface`, `surface_variant`, `primary_container`, `primary`, etc.)
- All files must be non-obfuscated standard Luau with `--!nonstrict`
- Complete resilience and graceful degradation when running outside Hyprland or without `socat`

---

### Task 1: Plugin Scaffolding, Manifest & Translations

**Files:**
- Create: `hypr-layout/plugin.toml`
- Create: `hypr-layout/translations/en.json`
- Create: `hypr-layout/translations/id.json`
- Test: `tests/test_hypr_layout_manifest.py`

**Interfaces:**
- Consumes: Noctalia Plugin API 28 specifications
- Produces: `hypr-layout/plugin.toml` manifest, `translations/en.json`, `translations/id.json`

- [ ] **Step 1: Write the failing manifest and translation test**

Create `tests/test_hypr_layout_manifest.py`:
```python
import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestHyprLayoutManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/hypr-layout")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("icon"), "layout-grid")

        # Verify panel
        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "floating")
        self.assertEqual(panels[0].get("position"), "center")
        self.assertIn("Escape", panels[0].get("capture_keys", []))

        # Verify widget
        widgets = manifest.get("widget", [])
        self.assertEqual(len(widgets), 1)
        self.assertEqual(widgets[0].get("id"), "widget")
        self.assertEqual(widgets[0].get("entry"), "widget.luau")

        # Verify translation keys for all settings
        for setting in manifest.get("setting", []):
            for key_prop in ["label_key", "description_key"]:
                if key_prop in setting:
                    k = setting[key_prop]
                    self.assertTrue(has_key_path(en, k), f"en.json missing {k}")
                    self.assertTrue(has_key_path(id_lang, k), f"id.json missing {k}")
            for opt in setting.get("options", []):
                if "label_key" in opt:
                    k = opt["label_key"]
                    self.assertTrue(has_key_path(en, k), f"en.json missing {k}")
                    self.assertTrue(has_key_path(id_lang, k), f"id.json missing {k}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_manifest.py -v`
Expected: FAIL (files missing)

- [ ] **Step 3: Implement minimal plugin.toml, en.json, id.json**

Create `hypr-layout/plugin.toml`:
```toml
id = "rigelyon/hypr-layout"
name = "Hyprland Layout Switcher"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = ["hyprland"]
tags = ["hyprland", "layout", "utility", "bar", "panel", "productivity"]
icon = "layout-grid"
description = "Aesthetic Hyprland layout switcher with status bar widget, dual scope (global/workspace), and schematic wireframe hub."

[[setting]]
key = "default_scope"
type = "select"
label_key = "settings.default_scope.label"
description_key = "settings.default_scope.description"
default = "global"
options = [
  { value = "global", label_key = "settings.default_scope.options.global" },
  { value = "workspace", label_key = "settings.default_scope.options.workspace" },
]

[[setting]]
key = "show_label_in_bar"
type = "bool"
label_key = "settings.show_label_in_bar.label"
description_key = "settings.show_label_in_bar.description"
default = true

[[setting]]
key = "notify_on_change"
type = "bool"
label_key = "settings.notify_on_change.label"
description_key = "settings.notify_on_change.description"
default = true

[[setting]]
key = "enable_hy3"
type = "bool"
label_key = "settings.enable_hy3.label"
description_key = "settings.enable_hy3.description"
default = false

[[setting]]
key = "enable_scroller"
type = "bool"
label_key = "settings.enable_scroller.label"
description_key = "settings.enable_scroller.description"
default = false

[[panel]]
id = "panel"
entry = "panel.luau"
placement = "floating"
position = "center"
width = 720
height = 540
capture_keys = ["Escape"]

[[widget]]
id = "widget"
entry = "widget.luau"

[widget.actions]
middle = "none"
```

Create `hypr-layout/translations/en.json`:
```json
{
  "manifest": {
    "name": "Hyprland Layout Switcher",
    "description": "Aesthetic Hyprland layout switcher with status bar widget, dual scope (global/workspace), and schematic wireframe hub."
  },
  "settings": {
    "default_scope": {
      "label": "Default Layout Scope",
      "description": "Select whether layout changes apply globally to all workspaces or specifically to the active workspace by default.",
      "options": {
        "global": "Global Session",
        "workspace": "Current Active Workspace"
      }
    },
    "show_label_in_bar": {
      "label": "Show Layout Name in Bar",
      "description": "Display the textual name of the active layout beside the glyph in the status bar widget."
    },
    "notify_on_change": {
      "label": "Notification on Layout Change",
      "description": "Show a desktop notification whenever the layout is switched."
    },
    "enable_hy3": {
      "label": "Enable Hy3 Plugin Layout",
      "description": "Include the third-party hy3 i3/sway-like manual tiling layout in the switcher rotation and panel."
    },
    "enable_scroller": {
      "label": "Enable Hyprscroller Plugin Layout",
      "description": "Include the third-party hyprscroller PaperWM-like layout in the switcher rotation and panel."
    }
  },
  "widget": {
    "tooltip": "Hyprland Layout: {layout} ({scope})\nLeft-click: Quick cycle • Right-click: Layout Hub"
  },
  "panel": {
    "title": "Hyprland Layout Switcher",
    "scope_label": "Target Scope:",
    "scope_global": "Global Session",
    "scope_workspace": "Workspace {id}",
    "active_badge": "Active",
    "controls_title": "Active Layout Controls ({layout})",
    "hint": "Left-click bar widget to cycle • Right-click to open this panel",
    "open_settings": "Settings"
  },
  "layouts": {
    "dwindle": {
      "name": "Dwindle",
      "category": "Spiral Dynamic",
      "description": "Dynamic spiral tiling layout with automatic Fibonacci window splits."
    },
    "master": {
      "name": "Master",
      "category": "Master & Stack",
      "description": "Fixed primary master window column flanked by stacked slave window tiles."
    },
    "hy3": {
      "name": "Hy3",
      "category": "Manual Tiling",
      "description": "i3/sway style manual container groups with horizontal, vertical, and tabbed splits."
    },
    "scroller": {
      "name": "Scroller",
      "category": "PaperWM Strip",
      "description": "Infinite horizontal carousel strip of window columns."
    }
  },
  "subactions": {
    "togglesplit": "Toggle Split",
    "pseudo": "Pseudo-tile",
    "swapsplit": "Swap Split",
    "swapwithmaster": "Swap Master",
    "cyclenext": "Cycle Next",
    "addmaster": "+ Master",
    "removemaster": "- Master",
    "makegroup_h": "Group H",
    "makegroup_v": "Group V",
    "makegroup_tab": "Tabs",
    "cyclesize": "Cycle Size",
    "toggleoverview": "Overview"
  },
  "notifications": {
    "switched": "Layout switched to {layout} ({scope})"
  }
}
```

Create `hypr-layout/translations/id.json`:
```json
{
  "manifest": {
    "name": "Hyprland Layout Switcher",
    "description": "Pengubah layout Hyprland estetik dengan widget status bar, cakupan ganda (global/workspace), dan visual wireframe hub."
  },
  "settings": {
    "default_scope": {
      "label": "Cakupan Default Layout",
      "description": "Pilih apakah perubahan layout berlaku secara global ke semua workspace atau khusus ke workspace yang sedang aktif.",
      "options": {
        "global": "Sesi Global",
        "workspace": "Workspace Aktif Saat Ini"
      }
    },
    "show_label_in_bar": {
      "label": "Tampilkan Nama Layout di Bar",
      "description": "Tampilkan teks nama layout aktif di samping ikon pada widget status bar."
    },
    "notify_on_change": {
      "label": "Notifikasi Pergantian Layout",
      "description": "Tampilkan notifikasi desktop setiap kali layout berganti."
    },
    "enable_hy3": {
      "label": "Aktifkan Plugin Layout Hy3",
      "description": "Sertakan layout manual tiling gaya i3/sway hy3 pada rotasi switcher dan panel."
    },
    "enable_scroller": {
      "label": "Aktifkan Plugin Layout Hyprscroller",
      "description": "Sertakan layout PaperWM hyprscroller pada rotasi switcher dan panel."
    }
  },
  "widget": {
    "tooltip": "Layout Hyprland: {layout} ({scope})\nKlik kiri: Ganti cepat • Klik kanan: Buka Layout Hub"
  },
  "panel": {
    "title": "Hyprland Layout Switcher",
    "scope_label": "Target Cakupan:",
    "scope_global": "Sesi Global",
    "scope_workspace": "Workspace {id}",
    "active_badge": "Aktif",
    "controls_title": "Kontrol Layout Aktif ({layout})",
    "hint": "Klik kiri widget bar untuk cycle cepat • Klik kanan untuk buka panel ini",
    "open_settings": "Pengaturan"
  },
  "layouts": {
    "dwindle": {
      "name": "Dwindle",
      "category": "Spiral Dinamis",
      "description": "Layout tiling spiral dinamis dengan pembagian jendela otomatis Fibonacci."
    },
    "master": {
      "name": "Master",
      "category": "Master & Stack",
      "description": "Kolom jendela master utama tetap didampingi tumpukan jendela slave bertingkat."
    },
    "hy3": {
      "name": "Hy3",
      "category": "Manual Tiling",
      "description": "Kontainer grup manual gaya i3/sway dengan pembagian horizontal, vertikal, dan tab."
    },
    "scroller": {
      "name": "Scroller",
      "category": "Strip PaperWM",
      "description": "Strip komidi putar horizontal tanpa batas dari kolom jendela."
    }
  },
  "subactions": {
    "togglesplit": "Toggle Split",
    "pseudo": "Pseudo-tile",
    "swapsplit": "Swap Split",
    "swapwithmaster": "Swap Master",
    "cyclenext": "Cycle Next",
    "addmaster": "+ Master",
    "removemaster": "- Master",
    "makegroup_h": "Grup H",
    "makegroup_v": "Grup V",
    "makegroup_tab": "Tab",
    "cyclesize": "Ubah Ukuran",
    "toggleoverview": "Overview"
  },
  "notifications": {
    "switched": "Layout berganti ke {layout} ({scope})"
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_manifest.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/plugin.toml hypr-layout/translations/ tests/test_hypr_layout_manifest.py
git commit -m "feat(hypr-layout): add plugin manifest, settings, and translations"
```

---

### Task 2: Layout Definitions & Registry (`layouts.luau`)

**Files:**
- Create: `hypr-layout/layouts.luau`
- Test: `tests/test_hypr_layout_registry.py`

**Interfaces:**
- Consumes: Noctalia translation helper (`tr`)
- Produces: `layouts.getAvailableLayouts(config)`, `layouts.getLayout(id)`, `layouts.getNextLayout(currentId, config)`

- [ ] **Step 1: Write the failing registry test**

Create `tests/test_hypr_layout_registry.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutRegistry(unittest.TestCase):
    def test_layouts_file_structure(self):
        layouts_path = os.path.join(PLUGIN_DIR, "layouts.luau")
        self.assertTrue(os.path.isfile(layouts_path), "Missing layouts.luau")
        with open(layouts_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("layouts.LAYOUT_DEFS", content)
        self.assertIn('"dwindle"', content)
        self.assertIn('"master"', content)
        self.assertIn('"hy3"', content)
        self.assertIn('"scroller"', content)
        self.assertIn("function layouts.getAvailableLayouts", content)
        self.assertIn("function layouts.getNextLayout", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_registry.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/layouts.luau`**

Create `hypr-layout/layouts.luau`:
```luau
--!nonstrict
-- Layout Registry and Sub-action definitions for Hyprland Switcher
local layouts = {}

export type SubAction = {
  id: string,
  labelKey: string,
  icon: string,
  cmd: string,
}

export type LayoutDef = {
  id: string,
  nameKey: string,
  categoryKey: string,
  descKey: string,
  glyph: string,
  isPlugin: boolean,
  subactions: { SubAction },
}

layouts.LAYOUT_DEFS = {
  dwindle = {
    id = "dwindle",
    nameKey = "layouts.dwindle.name",
    categoryKey = "layouts.dwindle.category",
    descKey = "layouts.dwindle.description",
    glyph = "layout-split",
    isPlugin = false,
    subactions = {
      { id = "togglesplit", labelKey = "subactions.togglesplit", icon = "git-fork", cmd = "togglesplit" },
      { id = "pseudo", labelKey = "subactions.pseudo", icon = "aspect-ratio", cmd = "pseudo" },
      { id = "swapsplit", labelKey = "subactions.swapsplit", icon = "arrows-left-right", cmd = "swapsplit" },
    },
  },
  master = {
    id = "master",
    nameKey = "layouts.master.name",
    categoryKey = "layouts.master.category",
    descKey = "layouts.master.description",
    glyph = "layout-sidebar",
    isPlugin = false,
    subactions = {
      { id = "swapwithmaster", labelKey = "subactions.swapwithmaster", icon = "arrows-exchange", cmd = "swapwithmaster" },
      { id = "cyclenext", labelKey = "subactions.cyclenext", icon = "arrow-clockwise", cmd = "cyclenext" },
      { id = "addmaster", labelKey = "subactions.addmaster", icon = "plus", cmd = "addmaster" },
      { id = "removemaster", labelKey = "subactions.removemaster", icon = "minus", cmd = "removemaster" },
    },
  },
  hy3 = {
    id = "hy3",
    nameKey = "layouts.hy3.name",
    categoryKey = "layouts.hy3.category",
    descKey = "layouts.hy3.description",
    glyph = "layout-columns",
    isPlugin = true,
    subactions = {
      { id = "makegroup_h", labelKey = "subactions.makegroup_h", icon = "columns", cmd = "hy3:makegroup,h" },
      { id = "makegroup_v", labelKey = "subactions.makegroup_v", icon = "rows", cmd = "hy3:makegroup,v" },
      { id = "makegroup_tab", labelKey = "subactions.makegroup_tab", icon = "browsers", cmd = "hy3:makegroup,tab" },
    },
  },
  scroller = {
    id = "scroller",
    nameKey = "layouts.scroller.name",
    categoryKey = "layouts.scroller.category",
    descKey = "layouts.scroller.description",
    glyph = "sliders-horizontal",
    isPlugin = true,
    subactions = {
      { id = "cyclesize", labelKey = "subactions.cyclesize", icon = "arrows-out", cmd = "scroller:cyclesize" },
      { id = "toggleoverview", labelKey = "subactions.toggleoverview", icon = "eye", cmd = "scroller:toggleoverview" },
    },
  },
}

function layouts.getLayout(id: string): LayoutDef?
  if not id or id == "" then return layouts.LAYOUT_DEFS["dwindle"] end
  local normalized = string.lower(id)
  return layouts.LAYOUT_DEFS[normalized]
end

function layouts.getAvailableLayouts(configGetter: ((string) -> any)?): { LayoutDef }
  local list = {
    layouts.LAYOUT_DEFS.dwindle,
    layouts.LAYOUT_DEFS.master,
  }
  local enableHy3 = false
  local enableScroller = false

  if configGetter then
    enableHy3 = (configGetter("enable_hy3") == true)
    enableScroller = (configGetter("enable_scroller") == true)
  end

  if enableHy3 then
    table.insert(list, layouts.LAYOUT_DEFS.hy3)
  end
  if enableScroller then
    table.insert(list, layouts.LAYOUT_DEFS.scroller)
  end

  return list
end

function layouts.getNextLayout(currentId: string, configGetter: ((string) -> any)?): LayoutDef
  local available = layouts.getAvailableLayouts(configGetter)
  if #available == 0 then return layouts.LAYOUT_DEFS.dwindle end

  local currentNormalized = string.lower(currentId or "dwindle")
  local currentIndex = 1
  for i, def in ipairs(available) do
    if def.id == currentNormalized then
      currentIndex = i
      break
    end
  end

  local nextIndex = (currentIndex % #available) + 1
  return available[nextIndex]
end

return layouts
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_registry.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/layouts.luau tests/test_hypr_layout_registry.py
git commit -m "feat(hypr-layout): add layouts registry and subactions definitions"
```

---

### Task 3: State Manager & Reactive Hub (`state.luau`)

**Files:**
- Create: `hypr-layout/state.luau`
- Test: `tests/test_hypr_layout_state.py`

**Interfaces:**
- Consumes: `layouts.luau`
- Produces: `state.subscribe(fn)`, `state.notify()`, `state.setGlobalLayout(name)`, `state.setWorkspaceLayout(wsId, name)`, `state.getEffectiveLayout()`

- [ ] **Step 1: Write the failing state manager test**

Create `tests/test_hypr_layout_state.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutState(unittest.TestCase):
    def test_state_file_structure(self):
        state_path = os.path.join(PLUGIN_DIR, "state.luau")
        self.assertTrue(os.path.isfile(state_path), "Missing state.luau")
        with open(state_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function state.subscribe", content)
        self.assertIn("function state.notify", content)
        self.assertIn("function state.getEffectiveLayout", content)
        self.assertIn("function state.setScope", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_state.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/state.luau`**

Create `hypr-layout/state.luau`:
```luau
--!nonstrict
-- Central reactive state manager for Hyprland Layout Switcher
local state = {
  globalLayout = "dwindle",
  activeWorkspaceId = 1,
  activeWorkspaceName = "1",
  activeMonitor = "",
  currentScope = "global", -- "global" or "workspace"
  workspaceLayouts = {} :: { [number]: string },
  listeners = {} :: { (any) -> () },
}

function state.subscribe(callback: (any) -> ())
  table.insert(state.listeners, callback)
end

function state.notify()
  for _, callback in ipairs(state.listeners) do
    local ok, err = pcall(function()
      callback(state)
    end)
    if not ok and noctalia and noctalia.log then
      noctalia.log("[hypr-layout] Error in state listener: " .. tostring(err))
    end
  end
end

function state.setScope(scope: string)
  if scope == "global" or scope == "workspace" then
    state.currentScope = scope
    state.notify()
  end
end

function state.setGlobalLayout(name: string)
  if not name or name == "" then return end
  local clean = string.lower(name)
  if state.globalLayout ~= clean then
    state.globalLayout = clean
    state.notify()
  end
end

function state.setActiveWorkspace(wsId: number, wsName: string?, monitor: string?)
  local changed = false
  if state.activeWorkspaceId ~= wsId then
    state.activeWorkspaceId = wsId
    changed = true
  end
  if wsName and state.activeWorkspaceName ~= wsName then
    state.activeWorkspaceName = wsName
    changed = true
  end
  if monitor and state.activeMonitor ~= monitor then
    state.activeMonitor = monitor
    changed = true
  end
  if changed then
    state.notify()
  end
end

function state.setWorkspaceLayout(wsId: number, name: string)
  if not wsId or not name or name == "" then return end
  local clean = string.lower(name)
  if state.workspaceLayouts[wsId] ~= clean then
    state.workspaceLayouts[wsId] = clean
    state.notify()
  end
end

function state.getEffectiveLayout(): string
  if state.currentScope == "workspace" then
    local wsLayout = state.workspaceLayouts[state.activeWorkspaceId]
    if wsLayout and wsLayout ~= "" then
      return wsLayout
    end
  end
  return state.globalLayout or "dwindle"
end

return state
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_state.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/state.luau tests/test_hypr_layout_state.py
git commit -m "feat(hypr-layout): add central reactive state manager"
```

---

### Task 4: Hyprland IPC Client & Socket2 Streamer (`hypr.luau`)

**Files:**
- Create: `hypr-layout/hypr.luau`
- Test: `tests/test_hypr_layout_ipc.py`

**Interfaces:**
- Consumes: `state.luau`, `noctalia.runAsync`, `noctalia.runStream`, `noctalia.json`
- Produces: `hypr.init()`, `hypr.refresh()`, `hypr.setLayout(layoutName, scope, onDone)`, `hypr.dispatchSubAction(cmd, onDone)`

- [ ] **Step 1: Write the failing IPC test**

Create `tests/test_hypr_layout_ipc.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutIPC(unittest.TestCase):
    def test_ipc_file_structure(self):
        hypr_path = os.path.join(PLUGIN_DIR, "hypr.luau")
        self.assertTrue(os.path.isfile(hypr_path), "Missing hypr.luau")
        with open(hypr_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function hypr.init", content)
        self.assertIn("function hypr.refresh", content)
        self.assertIn("function hypr.setLayout", content)
        self.assertIn("function hypr.dispatchSubAction", content)
        self.assertIn("socket2.sock", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_ipc.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/hypr.luau`**

Create `hypr-layout/hypr.luau`:
```luau
--!nonstrict
-- Hyprland IPC communication & socket2 event streaming
local state = require("./state.luau")

local hypr = {
  isStreaming = false,
  isAvailable = true,
}

local function safeJsonDecode(str: string): any
  if not str or str == "" then return nil end
  local ok, res = pcall(function()
    return noctalia.json.decode(str)
  end)
  return ok and res or nil
end

function hypr.refreshGlobalLayout(onDone: ((string?) -> ())?)
  if not noctalia or not noctalia.runAsync then return end
  noctalia.runAsync({ "hyprctl", "getoption", "general:layout", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local data = safeJsonDecode(res.stdout)
      if data and data.str then
        state.setGlobalLayout(data.str)
        if onDone then onDone(data.str) end
        return
      end
    else
      hypr.isAvailable = false
    end
    if onDone then onDone(nil) end
  end)
end

function hypr.refreshActiveWorkspace(onDone: ((number?, string?) -> ())?)
  if not noctalia or not noctalia.runAsync then return end
  noctalia.runAsync({ "hyprctl", "activeworkspace", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local data = safeJsonDecode(res.stdout)
      if data and data.id then
        local wsId = tonumber(data.id) or 1
        local wsName = tostring(data.name or wsId)
        local monitor = tostring(data.monitor or "")
        state.setActiveWorkspace(wsId, wsName, monitor)
        if onDone then onDone(wsId, wsName) end
        return
      end
    end
    if onDone then onDone(nil, nil) end
  end)
end

function hypr.refresh()
  hypr.refreshGlobalLayout()
  hypr.refreshActiveWorkspace()
end

function hypr.setLayout(layoutName: string, scope: string?, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not layoutName or layoutName == "" then return end
  local targetScope = scope or state.currentScope

  if targetScope == "workspace" then
    local wsId = state.activeWorkspaceId or 1
    local cmd = { "hyprctl", "keyword", "workspace", tostring(wsId) .. ",layout:" .. layoutName }
    noctalia.runAsync(cmd, function(res)
      local success = (res.exitCode == 0)
      if success then
        state.setWorkspaceLayout(wsId, layoutName)
      end
      if onDone then onDone(success) end
    end)
  else
    local cmd = { "hyprctl", "keyword", "general:layout", layoutName }
    noctalia.runAsync(cmd, function(res)
      local success = (res.exitCode == 0)
      if success then
        state.setGlobalLayout(layoutName)
      end
      if onDone then onDone(success) end
    end)
  end
end

function hypr.dispatchSubAction(command: string, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not command or command == "" then return end
  local cmd = {}
  if string.find(command, ":", 1, true) then
    -- Custom plugin dispatcher, e.g. "hy3:makegroup,h" or "scroller:cyclesize"
    local colonIdx = string.find(command, ":", 1, true)
    local dispatcher = string.sub(command, 1, colonIdx - 1)
    local arg = string.sub(command, colonIdx + 1)
    cmd = { "hyprctl", "dispatch", dispatcher, arg }
  else
    -- Standard Hyprland layoutmsg dispatcher
    cmd = { "hyprctl", "dispatch", "layoutmsg", command }
  end

  noctalia.runAsync(cmd, function(res)
    local success = (res.exitCode == 0)
    if onDone then onDone(success) end
  end)
end

function hypr.startSocketStream()
  if hypr.isStreaming or not noctalia or not noctalia.runStream or not noctalia.getenv then
    return
  end

  local xdgRuntime = noctalia.getenv("XDG_RUNTIME_DIR") or "/run/user/" .. tostring(noctalia.getenv("UID") or "1000")
  local his = noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE")
  if not his or his == "" then
    return
  end

  local sockPath = xdgRuntime .. "/hypr/" .. his .. "/.socket2.sock"
  local streamCmd = "socat -U - UNIX-CONNECT:\"" .. sockPath .. "\""

  hypr.isStreaming = true
  noctalia.runStream(streamCmd, function(line)
    if not line or line == "" then return end
    if string.sub(line, 1, 11) == "workspace>>" then
      hypr.refreshActiveWorkspace()
    elseif string.sub(line, 1, 12) == "focusedmon>>" then
      hypr.refreshActiveWorkspace()
    elseif string.sub(line, 1, 16) == "configreloaded>>" then
      hypr.refreshGlobalLayout()
    end
  end)
end

function hypr.init()
  hypr.refresh()
  hypr.startSocketStream()
end

return hypr
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_ipc.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/hypr.luau tests/test_hypr_layout_ipc.py
git commit -m "feat(hypr-layout): add hyprland ipc engine and socket2 event listener"
```

---

### Task 5: Schematic Wireframe Generator & UI Components (`components.luau`)

**Files:**
- Create: `hypr-layout/components.luau`
- Test: `tests/test_hypr_layout_components.py`

**Interfaces:**
- Consumes: `layouts.luau`, `ui.*` primitives
- Produces: `components.renderWireframe(layoutId, isActive)`, `components.renderLayoutCard(...)`, `components.renderSubActionsBar(...)`

- [ ] **Step 1: Write the failing components test**

Create `tests/test_hypr_layout_components.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutComponents(unittest.TestCase):
    def test_components_file_structure(self):
        comp_path = os.path.join(PLUGIN_DIR, "components.luau")
        self.assertTrue(os.path.isfile(comp_path), "Missing components.luau")
        with open(comp_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function components.renderWireframe", content)
        self.assertIn("function components.renderLayoutCard", content)
        self.assertIn("function components.renderSubActionsBar", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_components.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/components.luau`**

Create `hypr-layout/components.luau`:
```luau
--!nonstrict
-- UI Component Library and Schematic Wireframe Diagrams for Hyprland Switcher
local layouts = require("./layouts.luau")

local components = {}

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- Generates schematic miniature window layout wireframes (56px x 40px)
function components.renderWireframe(layoutId: string, isActive: boolean): any
  local tileFill = isActive and "primary" or "outline"
  local tileMuted = isActive and "primary_container" or "surface_variant"

  if layoutId == "dwindle" then
    -- Fibonacci Spiral: Left 50% window, Right 50% split into Top and Bottom windows
    return ui.box({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        -- Main Left Window
        ui.box({
          flexGrow = 1,
          radius = 3,
          fill = tileFill,
        }),
        -- Right Stack Column
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "master" then
    -- Master & Stack: Dominant 60% Left Master window, Right 40% two stacked slave windows
    return ui.box({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        -- Master window
        ui.box({
          width = 30,
          radius = 3,
          fill = tileFill,
        }),
        -- Slave stack
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "hy3" then
    -- Hy3: Tabbed top indicator with two vertical columns
    return ui.box({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        -- Tab bar indicator
        ui.row({ gap = 2, height = 4 }, {
          ui.box({ width = 14, radius = 1, fill = tileFill }),
          ui.box({ width = 14, radius = 1, fill = tileMuted }),
        }),
        -- Columns
        ui.row({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "scroller" then
    -- Scroller: 3 horizontal columns with center active
    return ui.box({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
        ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
      }),
    })
  end

  -- Default generic tile fallback
  return ui.box({
    width = 56,
    height = 40,
    radius = 4,
    fill = "surface",
    padding = 3,
  }, {
    ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
  })
end

function components.renderLayoutCard(def: any, isActive: boolean, onSelect: () -> ()): any
  local wireframe = components.renderWireframe(def.id, isActive)
  local name = tr(def.nameKey)
  local category = tr(def.categoryKey)
  local desc = tr(def.descKey)

  local activeBadge = nil
  if isActive then
    activeBadge = ui.row({
      gap = 3,
      paddingV = 2,
      paddingH = 6,
      radius = 999,
      fill = "primary",
      align = "center",
    }, {
      ui.glyph({ name = "check", size = 11, color = "on_primary" }),
      ui.label({ text = tr("panel.active_badge"), fontSize = 10, fontWeight = "bold", color = "on_primary" }),
    })
  end

  return ui.row({
    padding = 10,
    radius = 8,
    fill = isActive and "primary_container" or "surface_variant",
    align = "center",
    gap = 12,
    flexGrow = 1,
    onClick = onSelect,
  }, {
    wireframe,
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({ name = def.glyph, size = 16, color = isActive and "primary" or "on_surface" }),
          ui.label({ text = name, fontSize = 14, fontWeight = "bold", color = "on_surface" }),
          ui.label({ text = "•", fontSize = 12, color = "on_surface_variant" }),
          ui.label({ text = category, fontSize = 11, color = "on_surface_variant" }),
        }),
        activeBadge or ui.spacer({ width = 1 }),
      }),
      ui.label({
        text = desc,
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
  })
end

function components.renderSubActionsBar(layoutDef: any, onDispatch: (string) -> ()): any
  if not layoutDef or not layoutDef.subactions or #layoutDef.subactions == 0 then
    return ui.spacer({ height = 1 })
  end

  local buttons = {}
  for _, action in ipairs(layoutDef.subactions) do
    local label = tr(action.labelKey)
    table.insert(buttons, ui.button({
      glyph = action.icon,
      text = label,
      variant = "tonal",
      onClick = function()
        onDispatch(action.cmd)
      end,
    }))
  end

  return ui.column({ gap = 6 }, {
    ui.label({
      text = tr("panel.controls_title", { layout = tr(layoutDef.nameKey) }),
      fontSize = 12,
      fontWeight = "bold",
      color = "on_surface",
    }),
    ui.row({ gap = 6, align = "center" }, buttons),
  })
end

return components
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_components.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/components.luau tests/test_hypr_layout_components.py
git commit -m "feat(hypr-layout): add schematic wireframe generator and UI components"
```

---

### Task 6: Status Bar Widget (`widget.luau`)

**Files:**
- Create: `hypr-layout/widget.luau`
- Test: `tests/test_hypr_layout_widget.py`

**Interfaces:**
- Consumes: `hypr.luau`, `state.luau`, `layouts.luau`, `barWidget.*`
- Produces: Status bar widget entry script with dual-action click listeners (`onClick` for quick cycle, `onRightClick` for panel)

- [ ] **Step 1: Write the failing widget test**

Create `tests/test_hypr_layout_widget.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutWidget(unittest.TestCase):
    def test_widget_file_structure(self):
        widget_path = os.path.join(PLUGIN_DIR, "widget.luau")
        self.assertTrue(os.path.isfile(widget_path), "Missing widget.luau")
        with open(widget_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function onClick()", content)
        self.assertIn("function onRightClick()", content)
        self.assertIn("barWidget.setGlyph", content)
        self.assertIn("layouts.getNextLayout", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_widget.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/widget.luau`**

Create `hypr-layout/widget.luau`:
```luau
--!nonstrict
-- Status Bar Widget for Hyprland Layout Switcher
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layouts = require("./layouts.luau")

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function updateWidgetPresentation()
  local effectiveLayoutId = state.getEffectiveLayout()
  local def = layouts.getLayout(effectiveLayoutId) or layouts.LAYOUT_DEFS.dwindle
  local layoutName = tr(def.nameKey)

  barWidget.setGlyph(def.glyph)

  local showLabel = noctalia.getConfig("show_label_in_bar")
  if showLabel ~= false then
    barWidget.setText(layoutName)
  else
    barWidget.setText("")
  end

  local scopeText = (state.currentScope == "workspace")
    and ("WS " .. tostring(state.activeWorkspaceId))
    or tr("settings.default_scope.options.global")

  barWidget.setTooltip(tr("widget.tooltip", {
    layout = layoutName,
    scope = scopeText,
  }))
end

-- Re-render presentation whenever central state changes
state.subscribe(function()
  updateWidgetPresentation()
end)

-- Left-click: Cycle to next layout in sequence
function onClick()
  local effective = state.getEffectiveLayout()
  local nextDef = layouts.getNextLayout(effective, noctalia.getConfig)
  local targetScope = state.currentScope

  hypr.setLayout(nextDef.id, targetScope, function(ok)
    if ok then
      local notifyEnabled = noctalia.getConfig("notify_on_change")
      if notifyEnabled ~= false then
        local nextName = tr(nextDef.nameKey)
        local scopeDesc = (targetScope == "workspace")
          and ("Workspace " .. tostring(state.activeWorkspaceId))
          or tr("settings.default_scope.options.global")
        noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
          layout = nextName,
          scope = scopeDesc,
        }))
      end
    end
  end)
end

-- Right-click: Open floating Layout Hub panel
function onRightClick()
  noctalia.togglePanel("rigelyon/hypr-layout:panel")
end

-- Initialize default scope from config
local defaultScope = noctalia.getConfig("default_scope")
if defaultScope == "workspace" or defaultScope == "global" then
  state.currentScope = defaultScope
end

-- Initialize IPC and widget presentation
hypr.init()
updateWidgetPresentation()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_widget.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/widget.luau tests/test_hypr_layout_widget.py
git commit -m "feat(hypr-layout): add status bar widget with dual-click interactions"
```

---

### Task 7: Floating Layout Hub Panel (`panel.luau`)

**Files:**
- Create: `hypr-layout/panel.luau`
- Test: `tests/test_hypr_layout_panel.py`

**Interfaces:**
- Consumes: `hypr.luau`, `state.luau`, `layouts.luau`, `components.luau`, `panel.*`
- Produces: Floating panel entry script with Layout Cards, Scope Segmented Control, and Sub-actions Bar

- [ ] **Step 1: Write the failing panel test**

Create `tests/test_hypr_layout_panel.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutPanel(unittest.TestCase):
    def test_panel_file_structure(self):
        panel_path = os.path.join(PLUGIN_DIR, "panel.luau")
        self.assertTrue(os.path.isfile(panel_path), "Missing panel.luau")
        with open(panel_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("panel.render", content)
        self.assertIn("function onOpen", content)
        self.assertIn("components.renderLayoutCard", content)
        self.assertIn("components.renderSubActionsBar", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_panel.py -v`
Expected: FAIL (file missing)

- [ ] **Step 3: Implement `hypr-layout/panel.luau`**

Create `hypr-layout/panel.luau`:
```luau
--!nonstrict
-- Floating Layout Hub Panel for Hyprland Switcher
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layouts = require("./layouts.luau")
local components = require("./components.luau")

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function render()
  local effective = state.getEffectiveLayout()
  local availableLayouts = layouts.getAvailableLayouts(noctalia.getConfig)
  local activeDef = layouts.getLayout(effective) or layouts.LAYOUT_DEFS.dwindle

  -- Header Bar
  local header = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 4,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "layout-grid", size = 20, color = "primary" }),
      ui.column({ gap = 1 }, {
        ui.label({ text = tr("panel.title"), fontSize = 15, fontWeight = "bold", color = "on_surface" }),
        ui.label({
          text = tr("panel.scope_workspace", { id = tostring(state.activeWorkspaceId) }),
          fontSize = 11,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      -- Segmented Scope Control: Global vs Workspace
      ui.row({
        padding = 3,
        radius = 8,
        fill = "surface_variant",
        gap = 2,
      }, {
        ui.button({
          text = tr("panel.scope_global"),
          variant = (state.currentScope == "global") and "filled" or "ghost",
          onClick = function()
            state.setScope("global")
          end,
        }),
        ui.button({
          text = tr("panel.scope_workspace", { id = tostring(state.activeWorkspaceId) }),
          variant = (state.currentScope == "workspace") and "filled" or "ghost",
          onClick = function()
            state.setScope("workspace")
          end,
        }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })

  -- Layout Cards Grid (2 columns)
  local cardRows = {}
  local numLayouts = #availableLayouts
  for i = 1, numLayouts, 2 do
    local def1 = availableLayouts[i]
    local def2 = availableLayouts[i + 1]

    local card1 = components.renderLayoutCard(def1, def1.id == effective, function()
      hypr.setLayout(def1.id, state.currentScope, function(ok)
        if ok and noctalia.getConfig("notify_on_change") ~= false then
          local nextName = tr(def1.nameKey)
          local scopeDesc = (state.currentScope == "workspace")
            and ("Workspace " .. tostring(state.activeWorkspaceId))
            or tr("settings.default_scope.options.global")
          noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
            layout = nextName,
            scope = scopeDesc,
          }))
        end
      end)
    end)

    local card2 = nil
    if def2 then
      card2 = components.renderLayoutCard(def2, def2.id == effective, function()
        hypr.setLayout(def2.id, state.currentScope, function(ok)
          if ok and noctalia.getConfig("notify_on_change") ~= false then
            local nextName = tr(def2.nameKey)
            local scopeDesc = (state.currentScope == "workspace")
              and ("Workspace " .. tostring(state.activeWorkspaceId))
              or tr("settings.default_scope.options.global")
            noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
              layout = nextName,
              scope = scopeDesc,
            }))
          end
        end)
      end)
    else
      card2 = ui.spacer({ flexGrow = 1 })
    end

    table.insert(cardRows, ui.row({ gap = 10, flexGrow = 1 }, { card1, card2 }))
  end

  -- Subactions Bar
  local subactionsBar = components.renderSubActionsBar(activeDef, function(cmd)
    hypr.dispatchSubAction(cmd)
  end)

  -- Footer Bar
  local footer = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 4,
  }, {
    ui.label({
      text = tr("panel.hint"),
      fontSize = 11,
      color = "on_surface_variant",
    }),
    ui.button({
      glyph = "gear",
      text = tr("panel.open_settings"),
      variant = "ghost",
      onClick = function()
        noctalia.openSettings()
      end,
    }),
  })

  -- Main Panel Layout
  local content = ui.column({
    padding = 16,
    gap = 14,
    fill = "surface",
    flexGrow = 1,
  }, {
    header,
    ui.separator(),
    ui.column({ gap = 10, flexGrow = 1 }, cardRows),
    ui.separator(),
    subactionsBar,
    ui.separator(),
    footer,
  })

  panel.render(content)
end

-- Subscribe panel to state updates
state.subscribe(function()
  render()
end)

function onOpen(context: any)
  hypr.refresh()
  render()
end

function onClose()
  -- Clean up if needed
end

-- Initial render
render()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_panel.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/panel.luau tests/test_hypr_layout_panel.py
git commit -m "feat(hypr-layout): add floating Layout Hub panel with wireframes and sub-actions"
```

---

### Task 8: Documentation, Thumbnail Artwork & Catalog

**Files:**
- Create: `hypr-layout/README.md`
- Create: `hypr-layout/thumbnail.webp`
- Test: `tests/test_hypr_layout_docs.py`

**Interfaces:**
- Produces: Complete markdown documentation and catalog card image artwork

- [ ] **Step 1: Write the failing documentation test**

Create `tests/test_hypr_layout_docs.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutDocs(unittest.TestCase):
    def test_readme_and_thumbnail(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(readme_path), "Missing README.md")
        self.assertTrue(os.path.isfile(thumb_path), "Missing thumbnail.webp")

        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("Hyprland Layout Switcher", content)
        self.assertIn("dwindle", content)
        self.assertIn("master", content)
        self.assertIn("hyprctl", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_layout_docs.py -v`
Expected: FAIL (files missing)

- [ ] **Step 3: Implement `hypr-layout/README.md` and generate `thumbnail.webp`**

Create `hypr-layout/README.md`:
```markdown
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
```

Generate `hypr-layout/thumbnail.webp` with a Python script creating a sleek, high-resolution aesthetic thumbnail image featuring blue/orange accent tokens, wireframe diagrams, and modern typography.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_layout_docs.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-layout/README.md hypr-layout/thumbnail.webp tests/test_hypr_layout_docs.py
git commit -m "docs(hypr-layout): add documentation and catalog thumbnail artwork"
```

---

### Task 9: Full Test Suite Verification

**Files:**
- Test: `tests/test_hypr_layout_*.py`

- [ ] **Step 1: Run complete hypr-layout test suite**

Run: `pytest tests/test_hypr_layout_*.py -v`
Expected: 5 passed in 0.05s

- [ ] **Step 2: Commit any final polishing changes**

```bash
git status
```
