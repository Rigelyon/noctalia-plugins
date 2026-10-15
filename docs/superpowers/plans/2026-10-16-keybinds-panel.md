# Keybinds Cheatsheet Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `rigelyon/keybinds` Noctalia community plugin providing an aesthetic, responsive centered modal cheatsheet for Linux Hyprland keybindings with custom manual shortcut registry support.

**Architecture:** Hyprland keybindings are fetched asynchronously via `hyprctl binds -j` and processed by a bitmask modmask decoder and smart auto-categorizer. Custom user keybinds (e.g. Kitty, Neovim, Shell CLI) are loaded from a decoupled JSON file (`~/.config/noctalia/custom_keybinds.json`) seeded with default presets. A centered floating declarative UI panel (`820x640`) renders an instant search bar, category filter pills with badge counts, 2-column `<kbd>` cards with click-to-copy, and a companion status bar widget.

**Tech Stack:** Noctalia Plugin API v28 (Luau), Hyprland IPC (`hyprctl`), JSON, Python/pytest (testing suite).

## Global Constraints
- Plugin ID: `rigelyon/keybinds` located in top-level directory `keybinds/`.
- Plugin API version: `28`.
- Luau files must start with `--!nonstrict`.
- Trusted, unsandboxed Luau with zero obfuscated or remote code execution.
- External dependencies must be declared in `plugin.toml` and documentation.
- All manifest `label_key` and `description_key` references must be defined in both `translations/en.json` and `translations/id.json`.
- Visual styling must adhere to Noctalia design tokens (`surface`, `surface_variant`, `primary`, `on_primary`, `outline`, `shell.corner_radius_scale`).

---

### Task 1: Plugin Manifest & Localization

**Files:**
- Create: `keybinds/plugin.toml`
- Create: `keybinds/translations/en.json`
- Create: `keybinds/translations/id.json`
- Test: `tests/test_keybinds_manifest.py`

**Interfaces:**
- Produces: `keybinds/plugin.toml` declaring plugin metadata, `[[panel]]`, `[[widget]]`, and `[[setting]]` entries.
- Produces: `translations/en.json` and `translations/id.json` with matching translation keys.

- [ ] **Step 1: Write the failing test**

Create `tests/test_keybinds_manifest.py`:
```python
import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestKeybindsManifest(unittest.TestCase):
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

        self.assertEqual(manifest.get("id"), "rigelyon/keybinds")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("icon"), "keyboard")

        # Verify panel
        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "floating")
        self.assertEqual(panels[0].get("position"), "center")
        self.assertEqual(panels[0].get("width"), 820)
        self.assertEqual(panels[0].get("height"), 640)
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

Run: `pytest tests/test_keybinds_manifest.py`
Expected: FAIL with `AssertionError: Missing plugin.toml`

- [ ] **Step 3: Implement plugin.toml, en.json, and id.json**

Create `keybinds/plugin.toml`:
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

Create `keybinds/translations/en.json`:
```json
{
  "plugin_name": "Keybinds Cheatsheet",
  "plugin_desc": "Aesthetic keybindings cheatsheet panel for Hyprland shell with custom shortcut registry.",
  "settings": {
    "custom_file_path": {
      "label": "Custom Keybinds File Path",
      "description": "Path to the JSON file containing manually registered custom shortcuts."
    },
    "copy_on_click": {
      "label": "Copy on Click",
      "description": "Clicking any shortcut card automatically copies the key combination to clipboard."
    },
    "grid_columns": {
      "label": "Grid Columns",
      "description": "Number of columns to display in the shortcuts grid.",
      "options": {
        "1": "1 Column",
        "2": "2 Columns"
      }
    }
  },
  "panel": {
    "title": "Keybinds Cheatsheet",
    "subtitle": "{count} active shortcuts",
    "search_placeholder": "Search shortcut, key, or category...",
    "no_results": "No shortcuts matching \"{query}\"",
    "copied": "Copied to clipboard!",
    "hypr_unavailable": "Hyprctl not detected — showing custom keybinds only",
    "footer_hint": "Esc: Close • Click: Copy • Config: {path}",
    "categories": {
      "all": "All",
      "window": "Window",
      "workspaces": "Workspaces",
      "apps": "Apps",
      "media": "Media",
      "screen": "Screen & Tools",
      "system": "System",
      "other": "Other"
    }
  },
  "widget": {
    "tooltip": "Keybinds Cheatsheet (Click to open)"
  }
}
```

Create `keybinds/translations/id.json`:
```json
{
  "plugin_name": "Keybinds Cheatsheet",
  "plugin_desc": "Panel cheatsheet daftar keybinds Hyprland yang rapi dan cantik dengan custom shortcut registry.",
  "settings": {
    "custom_file_path": {
      "label": "Jalur File Custom Keybinds",
      "description": "Lokasi file JSON berisi daftar shortcut kustom yang didaftarkan manual."
    },
    "copy_on_click": {
      "label": "Salin Saat Diklik",
      "description": "Mengklik kartu shortcut akan otomatis menyalin kombinasi tombol ke clipboard."
    },
    "grid_columns": {
      "label": "Jumlah Kolom Grid",
      "description": "Jumlah kolom yang ditampilkan pada grid daftar shortcut.",
      "options": {
        "1": "1 Kolom",
        "2": "2 Kolom"
      }
    }
  },
  "panel": {
    "title": "Keybinds Cheatsheet",
    "subtitle": "{count} shortcut aktif",
    "search_placeholder": "Cari shortcut, tombol, atau kategori...",
    "no_results": "Tidak ada shortcut yang cocok dengan \"{query}\"",
    "copied": "Berhasil disalin ke clipboard!",
    "hypr_unavailable": "Hyprctl tidak terdeteksi — hanya menampilkan custom keybinds",
    "footer_hint": "Esc: Tutup • Klik: Salin • Config: {path}",
    "categories": {
      "all": "Semua",
      "window": "Window",
      "workspaces": "Workspace",
      "apps": "Aplikasi",
      "media": "Media",
      "screen": "Layar & Alat",
      "system": "Sistem",
      "other": "Lainnya"
    }
  },
  "widget": {
    "tooltip": "Keybinds Cheatsheet (Klik untuk membuka)"
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_manifest.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add keybinds/plugin.toml keybinds/translations/ tests/test_keybinds_manifest.py
git commit -m "feat(keybinds): add plugin manifest and en/id localization files"
```

---

### Task 2: Keybind Parsing Engine & Default Presets

**Files:**
- Create: `keybinds/presets.luau`
- Test: `tests/test_keybinds_parser.py`

**Interfaces:**
- Produces: `presets.luau` providing `defaultJsonContent` and fallback presets.
- Test verifies Python simulation of:
  - Bitmask decoding: `modmask` to `SUPER`, `CTRL`, `ALT`, `SHIFT`.
  - Keycode normalization: `code:10` $\rightarrow$ `1`, `mouse:272` $\rightarrow$ `LMB`, `XF86AudioRaiseVolume` $\rightarrow$ `Vol +`.
  - Multi-tier categorization rules: mapping raw Hyprland binds to `Window`, `Workspaces`, `Apps`, `Media`, `Screen`, `System`, `Other`.
  - Custom JSON decoder & validation.

- [ ] **Step 1: Write the failing test**

Create `tests/test_keybinds_parser.py`:
```python
import json
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")


def decode_modmask(modmask: int) -> list[str]:
    mods = []
    if modmask & 64:
        mods.append("SUPER")
    if modmask & 4:
        mods.append("CTRL")
    if modmask & 8:
        mods.append("ALT")
    if modmask & 1:
        mods.append("SHIFT")
    return mods


KEY_TRANSLATIONS = {
    "code:10": "1",
    "code:11": "2",
    "code:12": "3",
    "code:13": "4",
    "code:14": "5",
    "code:15": "6",
    "code:16": "7",
    "code:17": "8",
    "code:18": "9",
    "code:19": "0",
    "code:90": "Num 0",
    "code:87": "Num 1",
    "code:88": "Num 2",
    "code:89": "Num 3",
    "code:83": "Num 4",
    "code:84": "Num 5",
    "code:85": "Num 6",
    "code:79": "Num 7",
    "code:80": "Num 8",
    "code:81": "Num 9",
    "mouse:272": "Left Click",
    "mouse:273": "Right Click",
    "mouse:274": "Middle Click",
    "mouse_up": "Scroll Up",
    "mouse_down": "Scroll Down",
    "bracketleft": "[",
    "bracketright": "]",
    "slash": "/",
    "grave": "`",
    "comma": ",",
    "period": ".",
    "equal": "=",
    "minus": "-",
    "xf86audioraisevolume": "Vol +",
    "xf86audiolowervolume": "Vol -",
    "xf86audiomute": "Mute",
    "xf86audiomicmute": "Mic Mute",
    "xf86monbrightnessup": "Bright +",
    "xf86monbrightnessdown": "Bright -",
    "xf86audioplay": "Play",
    "xf86audiostop": "Stop",
    "xf86audionext": "Next",
    "xf86audioprev": "Prev",
    "xf86sleep": "Sleep",
    "xf86rfkill": "Airplane",
}


def normalize_key(key: str) -> str:
    k_lower = key.lower().strip()
    return KEY_TRANSLATIONS.get(k_lower, key)


def categorize_bind(description: str, key: str, dispatcher: str = "", arg: str = "") -> str:
    desc = description.lower()
    k_lower = key.lower()

    # Window Management
    for term in ["window", "float", "pin", "fullscreen", "maximize", "focus", "swap", "resize"]:
        if term in desc:
            return "Window"
    if dispatcher in ["closewindow", "killactive", "togglefloating", "fullscreen", "pin", "movewindow", "resizeactive", "swapwindow", "movefocus"]:
        return "Window"

    # Workspaces
    if "workspace" in desc or dispatcher in ["workspace", "movetoworkspace", "movetoworkspacesilent", "togglespecialworkspace"]:
        return "Workspaces"

    # Apps & Launchers
    if desc.startswith("open ") or any(t in desc for t in ["browser", "terminal", "file manager", "launcher", "calculator", "settings"]):
        return "Apps"

    # Media & Hardware
    if any(t in desc for t in ["volume", "brightness", "mic", "play", "stop", "track", "mute", "airplane", "sleep"]) or k_lower.startswith("xf86"):
        return "Media"

    # Screen & Tools
    if any(t in desc for t in ["screenshot", "record", "ocr", "qr", "annotation", "clipboard"]):
        return "Screen & Tools"

    # System
    if any(t in desc for t in ["exit", "lock", "power", "shutdown", "reboot"]) or dispatcher == "exit":
        return "System"

    return "Other"


class TestKeybindsParser(unittest.TestCase):
    def test_modmask_decoding(self):
        self.assertEqual(decode_modmask(64), ["SUPER"])
        self.assertEqual(decode_modmask(65), ["SUPER", "SHIFT"])
        self.assertEqual(decode_modmask(68), ["SUPER", "CTRL"])
        self.assertEqual(decode_modmask(72), ["SUPER", "ALT"])
        self.assertEqual(decode_modmask(73), ["SUPER", "ALT", "SHIFT"])
        self.assertEqual(decode_modmask(76), ["SUPER", "CTRL", "ALT"])
        self.assertEqual(decode_modmask(0), [])

    def test_key_normalization(self):
        self.assertEqual(normalize_key("code:10"), "1")
        self.assertEqual(normalize_key("code:19"), "0")
        self.assertEqual(normalize_key("mouse:272"), "Left Click")
        self.assertEqual(normalize_key("bracketleft"), "[")
        self.assertEqual(normalize_key("XF86AudioRaiseVolume"), "Vol +")
        self.assertEqual(normalize_key("Return"), "Return")

    def test_categorization(self):
        self.assertEqual(categorize_bind("Open Terminal", "T"), "Apps")
        self.assertEqual(categorize_bind("Close Active Window", "Q"), "Window")
        self.assertEqual(categorize_bind("Float Window", "P"), "Window")
        self.assertEqual(categorize_bind("Workspace 1", "code:10"), "Workspaces")
        self.assertEqual(categorize_bind("Toggle Special Workspace 0", "code:90"), "Workspaces")
        self.assertEqual(categorize_bind("Volume Up", "XF86AudioRaiseVolume"), "Media")
        self.assertEqual(categorize_bind("Screenshot Area", "Print"), "Screen & Tools")
        self.assertEqual(categorize_bind("Exit Hyprland", "Delete"), "System")
        self.assertEqual(categorize_bind("Unknown custom command", "X"), "Other")

    def test_presets_file_exists_and_valid_json(self):
        presets_path = os.path.join(PLUGIN_DIR, "presets.luau")
        self.assertTrue(os.path.isfile(presets_path), "presets.luau must exist")
        with open(presets_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("return {", content)
        self.assertIn("Kitty Terminal", content)
        self.assertIn("Shell / CLI", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_parser.py`
Expected: FAIL with `AssertionError: presets.luau must exist`

- [ ] **Step 3: Implement presets.luau**

Create `keybinds/presets.luau`:
```lua
--!nonstrict
-- Default presets and starter template for custom keybinds.

local presets = {}

presets.defaultJson = [=[{
  "categories": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "binds": [
        { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
        { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
        { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Pane" },
        { "keys": ["CTRL", "SHIFT", "["], "description": "Previous Pane" },
        { "keys": ["CTRL", "SHIFT", "]"], "description": "Next Pane" },
        { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
        { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" },
        { "keys": ["CTRL", "SHIFT", "Equal"], "description": "Increase Font Size" },
        { "keys": ["CTRL", "SHIFT", "Minus"], "description": "Decrease Font Size" }
      ]
    },
    {
      "name": "Shell / CLI",
      "icon": "terminal_window",
      "binds": [
        { "keys": ["CTRL", "R"], "description": "Search History (Reverse)" },
        { "keys": ["CTRL", "L"], "description": "Clear Terminal Screen" },
        { "keys": ["CTRL", "C"], "description": "Interrupt / Cancel Process" },
        { "keys": ["CTRL", "Z"], "description": "Suspend Process to Background" },
        { "keys": ["CTRL", "D"], "description": "Exit Shell / EOF" },
        { "keys": ["CTRL", "A"], "description": "Move to Start of Line" },
        { "keys": ["CTRL", "E"], "description": "Move to End of Line" },
        { "keys": ["CTRL", "U"], "description": "Delete to Start of Line" },
        { "keys": ["CTRL", "K"], "description": "Delete to End of Line" },
        { "keys": ["CTRL", "W"], "description": "Delete Word Before Cursor" }
      ]
    },
    {
      "name": "Neovim",
      "icon": "code",
      "binds": [
        { "keys": ["Leader", "f", "f"], "description": "Find Files (Telescope)" },
        { "keys": ["Leader", "f", "g"], "description": "Live Grep" },
        { "keys": ["Leader", "e"], "description": "Toggle File Explorer" },
        { "keys": ["Leader", "w"], "description": "Save Buffer" },
        { "keys": ["Leader", "q"], "description": "Quit Buffer" },
        { "keys": ["g", "d"], "description": "Go to Definition" },
        { "keys": ["K"], "description": "Hover Documentation" }
      ]
    }
  ]
}]=]

return presets
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_parser.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add keybinds/presets.luau tests/test_keybinds_parser.py
git commit -m "feat(keybinds): add presets module and parser unit tests"
```

---

### Task 3: Panel UI & State Management

**Files:**
- Create: `keybinds/panel.luau`
- Test: `tests/test_keybinds_panel.py`

**Interfaces:**
- Consumes: `presets.luau` for starter templates.
- Consumes: `hyprctl binds -j` output via `noctalia.runAsync`.
- Consumes: Custom JSON file at `custom_file_path`.
- Produces: `panel.render(...)` with complete interactive UI, search filtering, category pills, `<kbd>` badges, and copy-on-click feedback.

- [ ] **Step 1: Write the failing test**

Create `tests/test_keybinds_panel.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
PANEL_FILE = os.path.join(PLUGIN_DIR, "panel.luau")


class TestKeybindsPanel(unittest.TestCase):
    def test_panel_structure_and_callbacks(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "panel.luau must exist")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Directive
        self.assertTrue(content.startswith("--!nonstrict"))

        # Lifecycle callbacks
        self.assertIn("function onOpen(", content)
        self.assertIn("function onKey(", content)

        # Declarative UI calls
        self.assertIn("panel.render(", content)
        self.assertIn("ui.input(", content)
        self.assertIn("ui.scroll(", content)
        self.assertIn("ui.box(", content)
        self.assertIn("ui.label(", content)
        self.assertIn("ui.glyph(", content)

        # Hyprctl & custom JSON integration
        self.assertIn("hyprctl", content)
        self.assertIn("noctalia.runAsync", content)
        self.assertIn("noctalia.readFile", content)
        self.assertIn("noctalia.copyToClipboard", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_panel.py`
Expected: FAIL with `AssertionError: panel.luau must exist`

- [ ] **Step 3: Implement keybinds/panel.luau**

Create `keybinds/panel.luau` implementing:
- Modular decoding of modmasks and key translations.
- Multi-tier categorization.
- Safe asynchronous reading of `hyprctl binds -j` with error fallback banner.
- Auto-initialization of `~/.config/noctalia/custom_keybinds.json` using `presets.defaultJson`.
- Reactive search filtering across description, key combo, and category.
- Clean category pill selection bar with badge counts.
- 2-column or 1-column card grid rendering with `<kbd>` key boxes.
- Click-to-copy handler with temporary visual feedback.
- `Escape` key handling to clear search or close panel.

```lua
--!nonstrict
-- Keybinds Cheatsheet Panel for Noctalia
-- Displays active Hyprland bindings and manual custom shortcuts in an aesthetic modal.

local presets = require("./presets")

type KeybindItem = {
  id: string,
  category: string,
  categoryIcon: string,
  modifiers: { string },
  key: string,
  keyComboText: string,
  description: string,
  source: string,
  searchIndex: string,
}

local items: { KeybindItem } = {}
local activeCategory = "all"
local searchQuery = ""
local copiedId: string? = nil
local copiedTimer: number = 0
local hyprAvailable = true
local isLoading = false
local cornerRadiusScale = 1.0
local gridColumns = "2"
local customFilePath = ""

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- Key translations mapping
local KEY_TRANSLATIONS = {
  ["code:10"] = "1",
  ["code:11"] = "2",
  ["code:12"] = "3",
  ["code:13"] = "4",
  ["code:14"] = "5",
  ["code:15"] = "6",
  ["code:16"] = "7",
  ["code:17"] = "8",
  ["code:18"] = "9",
  ["code:19"] = "0",
  ["code:90"] = "Num 0",
  ["code:87"] = "Num 1",
  ["code:88"] = "Num 2",
  ["code:89"] = "Num 3",
  ["code:83"] = "Num 4",
  ["code:84"] = "Num 5",
  ["code:85"] = "Num 6",
  ["code:79"] = "Num 7",
  ["code:80"] = "Num 8",
  ["code:81"] = "Num 9",
  ["mouse:272"] = "Left Click",
  ["mouse:273"] = "Right Click",
  ["mouse:274"] = "Middle Click",
  ["mouse_up"] = "Scroll Up",
  ["mouse_down"] = "Scroll Down",
  ["bracketleft"] = "[",
  ["bracketright"] = "]",
  ["slash"] = "/",
  ["grave"] = "`",
  ["comma"] = ",",
  ["period"] = ".",
  ["equal"] = "=",
  ["minus"] = "-",
  ["xf86audioraisevolume"] = "Vol +",
  ["xf86audiolowervolume"] = "Vol -",
  ["xf86audiomute"] = "Mute",
  ["xf86audiomicmute"] = "Mic Mute",
  ["xf86monbrightnessup"] = "Bright +",
  ["xf86monbrightnessdown"] = "Bright -",
  ["xf86audioplay"] = "Play",
  ["xf86audiostop"] = "Stop",
  ["xf86audionext"] = "Next",
  ["xf86audioprev"] = "Prev",
  ["xf86sleep"] = "Sleep",
  ["xf86rfkill"] = "Airplane",
}

local function normalizeKey(key: string): string
  local lower = string.lower(noctalia.string.trim(key))
  return KEY_TRANSLATIONS[lower] or key
end

local function decodeModmask(modmask: number): { string }
  local mods = {}
  if bit32.band(modmask, 64) ~= 0 then
    table.insert(mods, "SUPER")
  end
  if bit32.band(modmask, 4) ~= 0 then
    table.insert(mods, "CTRL")
  end
  if bit32.band(modmask, 8) ~= 0 then
    table.insert(mods, "ALT")
  end
  if bit32.band(modmask, 1) ~= 0 then
    table.insert(mods, "SHIFT")
  end
  return mods
end

local function categorizeBind(description: string, key: string, dispatcher: string?): (string, string)
  local desc = string.lower(description or "")
  local k = string.lower(key or "")
  local disp = string.lower(dispatcher or "")

  -- Window Management
  local windowTerms = { "window", "float", "pin", "fullscreen", "maximize", "focus", "swap", "resize" }
  for _, term in ipairs(windowTerms) do
    if string.find(desc, term, 1, true) then
      return "window", "app_window"
    end
  end
  if disp == "closewindow" or disp == "killactive" or disp == "togglefloating" or disp == "fullscreen"
    or disp == "pin" or disp == "movewindow" or disp == "resizeactive" or disp == "swapwindow" or disp == "movefocus" then
    return "window", "app_window"
  end

  -- Workspaces
  if string.find(desc, "workspace", 1, true) or disp == "workspace" or disp == "movetoworkspace"
    or disp == "movetoworkspacesilent" or disp == "togglespecialworkspace" then
    return "workspaces", "grid_view"
  end

  -- Apps & Launchers
  if string.sub(desc, 1, 5) == "open " or string.find(desc, "browser", 1, true) or string.find(desc, "terminal", 1, true)
    or string.find(desc, "file manager", 1, true) or string.find(desc, "launcher", 1, true) or string.find(desc, "calculator", 1, true)
    or string.find(desc, "settings", 1, true) then
    return "apps", "rocket_launch"
  end

  -- Media & Hardware
  local mediaTerms = { "volume", "brightness", "mic", "play", "stop", "track", "mute", "airplane", "sleep" }
  for _, term in ipairs(mediaTerms) do
    if string.find(desc, term, 1, true) then
      return "media", "volume_up"
    end
  end
  if string.sub(k, 1, 4) == "xf86" then
    return "media", "volume_up"
  end

  -- Screen & Tools
  local screenTerms = { "screenshot", "record", "ocr", "qr", "annotation", "clipboard" }
  for _, term in ipairs(screenTerms) do
    if string.find(desc, term, 1, true) then
      return "screen", "crop"
    end
  end

  -- System
  if string.find(desc, "exit", 1, true) or string.find(desc, "lock", 1, true) or string.find(desc, "power", 1, true)
    or string.find(desc, "shutdown", 1, true) or string.find(desc, "reboot", 1, true) or disp == "exit" then
    return "system", "power_settings_new"
  end

  return "other", "category"
end

local function buildKeyComboText(modifiers: { string }, key: string): string
  local parts = {}
  for _, m in ipairs(modifiers) do
    table.insert(parts, m)
  end
  if key ~= "" then
    table.insert(parts, key)
  end
  return table.concat(parts, " + ")
end

local function loadCustomKeybinds(): { KeybindItem }
  local customItems: { KeybindItem } = {}
  local path = noctalia.expandPath(customFilePath)

  -- Create default file if absent
  if not noctalia.fileExists(path) then
    local dir = string.match(path, "^(.*)/[^/]+$")
    if dir then
      noctalia.mkdirAll(dir)
    end
    noctalia.writeFile(path, presets.defaultJson)
  end

  local raw = noctalia.readFile(path)
  if not raw then
    return customItems
  end

  local ok, data = pcall(function()
    return noctalia.json.decode(raw)
  end)

  if ok and type(data) == "table" and type(data.categories) == "table" then
    for _, cat in ipairs(data.categories) do
      local catName = cat.name or "Custom"
      local catIcon = cat.icon or "terminal"
      if type(cat.binds) == "table" then
        for i, b in ipairs(cat.binds) do
          local keys = b.keys or {}
          local mods = {}
          local primaryKey = ""
          if #keys > 0 then
            for kIdx = 1, #keys - 1 do
              table.insert(mods, keys[kIdx])
            end
            primaryKey = keys[#keys]
          end
          local desc = b.description or ""
          local combo = buildKeyComboText(mods, primaryKey)
          table.insert(customItems, {
            id = "custom-" .. catName .. "-" .. tostring(i),
            category = catName,
            categoryIcon = catIcon,
            modifiers = mods,
            key = primaryKey,
            keyComboText = combo,
            description = desc,
            source = "custom",
            searchIndex = string.lower(catName .. " " .. desc .. " " .. combo),
          })
        end
      end
    end
  end

  return customItems
end

local function refreshAllBinds()
  isLoading = true
  render()

  local customList = loadCustomKeybinds()
  items = {}

  -- Append custom list first
  for _, item in ipairs(customList) do
    table.insert(items, item)
  end

  -- Run hyprctl binds -j
  noctalia.runAsync({ "hyprctl", "binds", "-j" }, function(res)
    isLoading = false
    if res.exitCode == 0 and #res.stdout > 0 then
      hyprAvailable = true
      local ok, rawBinds = pcall(function()
        return noctalia.json.decode(res.stdout)
      end)
      if ok and type(rawBinds) == "table" then
        for idx, b in ipairs(rawBinds) do
          local rawKey = b.key or ""
          if rawKey == "" and b.keycode and b.keycode > 0 then
            rawKey = "code:" .. tostring(b.keycode)
          end
          local normKey = normalizeKey(rawKey)
          local mods = decodeModmask(b.modmask or 0)
          local desc = b.description or ""
          if desc == "" and b.dispatcher then
            desc = b.dispatcher .. (b.arg and (" " .. b.arg) or "")
          end
          local catKey, catIcon = categorizeBind(desc, rawKey, b.dispatcher)
          local combo = buildKeyComboText(mods, normKey)

          table.insert(items, {
            id = "hypr-" .. tostring(idx),
            category = catKey,
            categoryIcon = catIcon,
            modifiers = mods,
            key = normKey,
            keyComboText = combo,
            description = desc,
            source = "hyprland",
            searchIndex = string.lower(catKey .. " " .. desc .. " " .. combo),
          })
        end
      end
    else
      hyprAvailable = false
    end
    render()
  end, 3000)
end

-- UI Building Blocks
local function renderHeader(): any
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 4,
  }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.box({
        padding = 8,
        radius = 8 * cornerRadiusScale,
        fill = "surface_variant",
      }, {
        ui.glyph({ name = "keyboard", size = 22, color = "primary" }),
      }),
      ui.column({ gap = 2 }, {
        ui.label({ text = tr("panel.title"), fontSize = 16, fontWeight = "bold" }),
        ui.label({
          text = tr("panel.subtitle", { count = #items }),
          fontSize = 11,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.button({
        icon = "refresh",
        tooltip = "Refresh Keybinds",
        flat = true,
        onClick = function()
          refreshAllBinds()
        end,
      }),
      ui.button({
        icon = "settings",
        tooltip = "Open Settings",
        flat = true,
        onClick = function()
          noctalia.openSettings()
        end,
      }),
      ui.button({
        icon = "close",
        tooltip = "Close",
        flat = true,
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })
end

local function renderSearchBar(): any
  return ui.row({
    align = "center",
    gap = 8,
    padding = 6,
    paddingH = 12,
    radius = 8 * cornerRadiusScale,
    fill = "surface_variant",
  }, {
    ui.glyph({ name = "search", size = 16, color = "on_surface_variant" }),
    ui.input({
      flexGrow = 1,
      placeholder = tr("panel.search_placeholder"),
      value = searchQuery,
      onInput = function(val)
        searchQuery = val
        render()
      end,
    }),
    (#searchQuery > 0) and ui.button({
      icon = "close",
      flat = true,
      onClick = function()
        searchQuery = ""
        render()
      end,
    }) or nil,
  })
end

local function getCategoryCounts(): { [string]: number }
  local counts = { all = #items }
  for _, item in ipairs(items) do
    counts[item.category] = (counts[item.category] or 0) + 1
  end
  return counts
end

local function renderCategoryPills(): any
  local counts = getCategoryCounts()

  -- Base categories
  local cats = {
    { id = "all", label = tr("panel.categories.all"), icon = "apps" },
    { id = "window", label = tr("panel.categories.window"), icon = "app_window" },
    { id = "workspaces", label = tr("panel.categories.workspaces"), icon = "grid_view" },
    { id = "apps", label = tr("panel.categories.apps"), icon = "rocket_launch" },
    { id = "media", label = tr("panel.categories.media"), icon = "volume_up" },
    { id = "screen", label = tr("panel.categories.screen"), icon = "crop" },
    { id = "system", label = tr("panel.categories.system"), icon = "power_settings_new" },
  }

  -- Collect custom categories present in items
  local customCatsSeen = {}
  for _, item in ipairs(items) do
    if item.source == "custom" and not customCatsSeen[item.category] then
      customCatsSeen[item.category] = true
      table.insert(cats, {
        id = item.category,
        label = item.category,
        icon = item.categoryIcon or "terminal",
      })
    end
  end

  local pillNodes = {}
  for _, cat in ipairs(cats) do
    local cnt = counts[cat.id] or 0
    if cnt > 0 or cat.id == "all" then
      local isSelected = (activeCategory == cat.id)
      table.insert(pillNodes, ui.box({
        key = "pill-" .. cat.id,
        paddingV = 6,
        paddingH = 12,
        radius = 20 * cornerRadiusScale,
        fill = isSelected and "primary" or "surface",
        onClick = function()
          activeCategory = cat.id
          render()
        end,
      }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({
            name = cat.icon,
            size = 14,
            color = isSelected and "on_primary" or "on_surface_variant",
          }),
          ui.label({
            text = cat.label,
            fontSize = 12,
            fontWeight = isSelected and "bold" or "normal",
            color = isSelected and "on_primary" or "on_surface",
          }),
          ui.box({
            paddingV = 1,
            paddingH = 6,
            radius = 10,
            fill = isSelected and "on_primary" or "surface_variant",
          }, {
            ui.label({
              text = tostring(cnt),
              fontSize = 10,
              fontWeight = "bold",
              color = isSelected and "primary" or "on_surface_variant",
            }),
          }),
        }),
      }))
    end
  end

  return ui.scroll({
    direction = "horizontal",
    gap = 6,
  }, pillNodes)
end

local function renderKbdBadge(text: string, isPrimary: boolean): any
  return ui.box({
    paddingV = 3,
    paddingH = 7,
    radius = 4 * cornerRadiusScale,
    fill = isPrimary and "surface_variant" or "surface",
  }, {
    ui.label({
      text = text,
      fontSize = 11,
      fontWeight = "bold",
      color = isPrimary and "primary" or "on_surface",
    }),
  })
end

local function renderKeybindCard(item: KeybindItem): any
  local isCopied = (copiedId == item.id)

  local kbdBadges = {}
  for _, m in ipairs(item.modifiers) do
    table.insert(kbdBadges, renderKbdBadge(m, false))
    table.insert(kbdBadges, ui.label({ text = "+", fontSize = 10, color = "on_surface_variant" }))
  end
  if item.key ~= "" then
    table.insert(kbdBadges, renderKbdBadge(item.key, true))
  end

  return ui.box({
    key = "card-" .. item.id,
    flexGrow = 1,
    padding = 10,
    radius = 8 * cornerRadiusScale,
    fill = isCopied and "primary_container" or "surface",
    onClick = function()
      local copyEnabled = noctalia.getConfig("copy_on_click") ~= false
      if copyEnabled then
        noctalia.copyToClipboard(item.keyComboText, "text/plain")
        copiedId = item.id
        render()
      end
    end,
  }, {
    ui.row({
      align = "center",
      justify = "space_between",
      gap = 8,
    }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({
          text = isCopied and tr("panel.copied") or item.description,
          fontSize = 12,
          fontWeight = isCopied and "bold" or "normal",
          color = isCopied and "on_primary_container" or "on_surface",
          maxLines = 1,
        }),
        ui.row({ gap = 4, align = "center" }, {
          ui.glyph({ name = item.categoryIcon, size = 11, color = "on_surface_variant" }),
          ui.label({
            text = item.category,
            fontSize = 10,
            color = "on_surface_variant",
          }),
        }),
      }),
      ui.row({ gap = 4, align = "center" }, kbdBadges),
    }),
  })
end

local function filterItems(): { KeybindItem }
  local filtered = {}
  local q = string.lower(noctalia.string.trim(searchQuery))
  local qWords = {}
  for word in string.gmatch(q, "%S+") do
    table.insert(qWords, word)
  end

  for _, item in ipairs(items) do
    local matchCat = (activeCategory == "all") or (item.category == activeCategory)
    if matchCat then
      if #qWords == 0 then
        table.insert(filtered, item)
      else
        local matchSearch = true
        for _, w in ipairs(qWords) do
          if not string.find(item.searchIndex, w, 1, true) then
            matchSearch = false
            break
          end
        end
        if matchSearch then
          table.insert(filtered, item)
        end
      end
    end
  end
  return filtered
end

local function renderCardGrid(filtered: { KeybindItem }): any
  if #filtered == 0 then
    return ui.column({
      flexGrow = 1,
      align = "center",
      justify = "center",
      gap = 12,
      padding = 40,
    }, {
      ui.glyph({ name = "search_off", size = 48, color = "on_surface_variant" }),
      ui.label({
        text = tr("panel.no_results", { query = searchQuery }),
        fontSize = 13,
        color = "on_surface_variant",
      }),
    })
  end

  local isTwoCols = (gridColumns == "2")
  local rows = {}

  if isTwoCols then
    for i = 1, #filtered, 2 do
      local col1 = renderKeybindCard(filtered[i])
      local col2 = (i + 1 <= #filtered) and renderKeybindCard(filtered[i + 1]) or ui.spacer({ flexGrow = 1 })
      table.insert(rows, ui.row({ gap = 8, align = "center" }, { col1, col2 }))
    end
  else
    for _, item in ipairs(filtered) do
      table.insert(rows, renderKeybindCard(item))
    end
  end

  return ui.scroll({
    flexGrow = 1,
    gap = 8,
  }, rows)
end

local function renderFooter(): any
  local path = noctalia.expandPath(customFilePath)
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 4,
  }, {
    ui.label({
      text = tr("panel.footer_hint", { path = path }),
      fontSize = 11,
      color = "on_surface_variant",
    }),
    (!hyprAvailable) and ui.label({
      text = tr("panel.hypr_unavailable"),
      fontSize = 11,
      color = "error",
    }) or nil,
  })
end

render = function()
  local filtered = filterItems()
  panel.render(ui.column({
    flexGrow = 1,
    gap = 12,
    align = "stretch",
    padding = 16,
  }, {
    renderHeader(),
    renderSearchBar(),
    renderCategoryPills(),
    renderCardGrid(filtered),
    renderFooter(),
  }))
end

-- ── Lifecycle Callbacks ────────────────────────────────────────────────────────

function onOpen(_context)
  cornerRadiusScale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
  gridColumns = tostring(noctalia.getConfig("grid_columns") or "2")
  customFilePath = noctalia.getConfig("custom_file_path") or "~/.config/noctalia/custom_keybinds.json"

  searchQuery = ""
  activeCategory = "all"
  copiedId = nil

  refreshAllBinds()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    if #searchQuery > 0 then
      searchQuery = ""
      render()
    else
      panel.close()
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_panel.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add keybinds/panel.luau tests/test_keybinds_panel.py
git commit -m "feat(keybinds): implement panel UI with instant search, pill filters, and kbd badges"
```

---

### Task 4: Status Bar Widget

**Files:**
- Create: `keybinds/widget.luau`
- Test: `tests/test_keybinds_widget.py`

**Interfaces:**
- Produces: `widget.luau` handling status bar presentation, keyboard icon, tooltip, and left-click panel toggle.

- [ ] **Step 1: Write the failing test**

Create `tests/test_keybinds_widget.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
WIDGET_FILE = os.path.join(PLUGIN_DIR, "widget.luau")


class TestKeybindsWidget(unittest.TestCase):
    def test_widget_structure_and_callbacks(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "widget.luau must exist")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertTrue(content.startswith("--!nonstrict"))
        self.assertIn("barWidget.setGlyph(", content)
        self.assertIn("barWidget.setTooltip(", content)
        self.assertIn("function onClick()", content)
        self.assertIn("noctalia.togglePanel(", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_widget.py`
Expected: FAIL with `AssertionError: widget.luau must exist`

- [ ] **Step 3: Implement keybinds/widget.luau**

Create `keybinds/widget.luau`:
```lua
--!nonstrict
-- Status bar widget for Keybinds Cheatsheet

local function tr(key: string): string
  return noctalia.tr(key)
end

barWidget.setGlyph("keyboard")
barWidget.setTooltip(tr("widget.tooltip"))

function onClick()
  noctalia.togglePanel("rigelyon/keybinds:panel")
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_widget.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add keybinds/widget.luau tests/test_keybinds_widget.py
git commit -m "feat(keybinds): add status bar widget for toggling keybinds cheatsheet"
```

---

### Task 5: Documentation & Thumbnail Asset

**Files:**
- Create: `keybinds/README.md`
- Create: `keybinds/thumbnail.webp`
- Test: `tests/test_keybinds_docs.py`

**Interfaces:**
- Produces: `README.md` compliant with Noctalia store template.
- Produces: `thumbnail.webp` (800x450 card image).

- [ ] **Step 1: Write the failing test**

Create `tests/test_keybinds_docs.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")


class TestKeybindsDocs(unittest.TestCase):
    def test_readme_and_thumbnail(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(readme_path), "README.md must exist")
        self.assertTrue(os.path.isfile(thumb_path), "thumbnail.webp must exist")

        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("# Keybinds Cheatsheet", content)
        self.assertIn("hyprctl", content)
        self.assertIn("custom_keybinds.json", content)
        self.assertGreater(os.path.getsize(thumb_path), 100)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_docs.py`
Expected: FAIL with `AssertionError: README.md must exist`

- [ ] **Step 3: Create README.md and generate thumbnail.webp**

Create `keybinds/README.md`:
```markdown
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
```

Generate `keybinds/thumbnail.webp` with Python PIL or convert utility.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_docs.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add keybinds/README.md keybinds/thumbnail.webp tests/test_keybinds_docs.py
git commit -m "docs(keybinds): add user documentation and thumbnail showcase asset"
```

---

### Task 6: Full Test Suite Verification & Integration Check

**Files:**
- Test: All tests in `tests/test_keybinds_*.py`

- [ ] **Step 1: Run complete keybinds test suite**

Run: `pytest tests/test_keybinds_*.py -v`
Expected: All 5 test suites PASS with 0 failures.

- [ ] **Step 2: Run catalog / existing plugin sanity check**

Run: `pytest tests/test_manifest_translations.py -v`
Expected: Existing repository sanity checks remain passing.

- [ ] **Step 3: Final verification commit if needed**

```bash
git status
```
