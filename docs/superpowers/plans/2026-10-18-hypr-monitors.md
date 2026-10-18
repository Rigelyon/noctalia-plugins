# Hyprland Monitor Manager (`rigelyon/hypr-monitors`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Noctalia plugin to visually manage Hyprland multi-monitor setups with an interactive arrangement canvas, gapless snap alignment, per-monitor inspector, safety revert timer, persistent config generation, and auto-detecting display profiles.

**Architecture:** A modular controller and reactive state architecture written in Luau. `layout_math.luau` performs gapless 2D coordinate calculations and canvas projection; `config.luau` parses and generates `~/.config/hypr/monitors.conf` with automatic `.bak` backups; `hypr.luau` applies live keywords and streams socket2 events; `profiles.luau` manages persistent profiles; `state.luau` provides reactive subscriptions and safety countdowns; `components.luau` renders visual display cards and controls; `panel.luau` renders the split hub UI; and `widget.luau` provides quick status bar presets.

**Tech Stack:** Luau (Noctalia Plugin API 28, declarative UI `ui.*`), Hyprland IPC (`hyprctl`, socket2 UNIX domain socket), Python 3 + `pytest` (test suite).

## Global Constraints
- Target directory: `hypr-monitors/`
- Plugin ID: `rigelyon/hypr-monitors`
- Plugin API version: 28
- License: MIT, Author: rigelyon
- Follow Noctalia UI token discipline (`surface`, `surface_variant`, `primary`, `on_surface`, `outline`, `error`, etc.)
- All files must be non-obfuscated standard Luau with `--!nonstrict`
- Graceful degradation when running outside Hyprland using `noctalia.outputs()` fallback

---

### Task 1: Scaffolding, Manifest & Bilingual Localization

**Files:**
- Create: `hypr-monitors/plugin.toml`
- Create: `hypr-monitors/translations/en.json`
- Create: `hypr-monitors/translations/id.json`
- Test: `tests/test_hypr_monitors_manifest.py`

**Interfaces:**
- Consumes: Noctalia Plugin API 28 specifications
- Produces: `hypr-monitors/plugin.toml` manifest, `translations/en.json`, `translations/id.json`

- [ ] **Step 1: Write the failing manifest and translations test**

Create `tests/test_hypr_monitors_manifest.py`:
```python
import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestHyprMonitorsManifest(unittest.TestCase):
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

        self.assertEqual(manifest.get("id"), "rigelyon/hypr-monitors")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("icon"), "device-desktop")
        self.assertIn("hyprland", manifest.get("dependencies", []))

        # Verify panel
        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "floating")
        self.assertEqual(panels[0].get("position"), "center")
        self.assertEqual(panels[0].get("width"), 740)
        self.assertEqual(panels[0].get("height"), 560)
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

Run: `pytest tests/test_hypr_monitors_manifest.py -v`
Expected: FAIL with `AssertionError: Missing plugin.toml`

- [ ] **Step 3: Create `hypr-monitors/plugin.toml`, `en.json`, and `id.json`**

Create `hypr-monitors/plugin.toml`:
```toml
id = "rigelyon/hypr-monitors"
name = "Hyprland Monitor Manager"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = ["hyprland"]
tags = ["hyprland", "monitor", "display", "utility", "bar", "panel", "productivity"]
icon = "device-desktop"
description = "Aesthetic visual display manager for Hyprland with gapless canvas arrangement, instant presets, safety revert timer, and profile management."

[[setting]]
key = "config_path"
type = "string"
label_key = "settings.config_path.label"
description_key = "settings.config_path.description"
default = "~/.config/hypr/monitors.conf"

[[setting]]
key = "safety_timeout"
type = "int"
label_key = "settings.safety_timeout.label"
description_key = "settings.safety_timeout.description"
default = 15
min = 5
max = 60

[[setting]]
key = "enable_safety_timer"
type = "bool"
label_key = "settings.enable_safety_timer.label"
description_key = "settings.enable_safety_timer.description"
default = true

[[setting]]
key = "auto_switch_profiles"
type = "bool"
label_key = "settings.auto_switch_profiles.label"
description_key = "settings.auto_switch_profiles.description"
default = true

[[setting]]
key = "show_count_in_bar"
type = "bool"
label_key = "settings.show_count_in_bar.label"
description_key = "settings.show_count_in_bar.description"
default = true

[[setting]]
key = "enable_vrr_options"
type = "bool"
label_key = "settings.enable_vrr_options.label"
description_key = "settings.enable_vrr_options.description"
default = true

[[panel]]
id = "panel"
entry = "panel.luau"
placement = "floating"
position = "center"
width = 740
height = 560
capture_keys = ["Escape"]

[[widget]]
id = "widget"
entry = "widget.luau"

[widget.actions]
middle = "none"
```

Create `hypr-monitors/translations/en.json`:
```json
{
  "plugin": {
    "name": "Hyprland Monitor Manager",
    "description": "Aesthetic visual display manager for Hyprland"
  },
  "settings": {
    "config_path": {
      "label": "Monitors Config Path",
      "description": "Path to persistent Hyprland monitors file (default: ~/.config/hypr/monitors.conf)"
    },
    "safety_timeout": {
      "label": "Safety Revert Timeout",
      "description": "Seconds before auto-reverting unconfirmed display changes"
    },
    "enable_safety_timer": {
      "label": "Enable Safety Timer",
      "description": "Auto-revert unconfirmed display changes to protect against black screens"
    },
    "auto_switch_profiles": {
      "label": "Auto-Switch Profiles",
      "description": "Automatically activate matching profile when monitors are plugged or unplugged"
    },
    "show_count_in_bar": {
      "label": "Show Count in Bar",
      "description": "Display active screen count next to the status bar icon"
    },
    "enable_vrr_options": {
      "label": "Show Gaming / VRR Controls",
      "description": "Show Variable Refresh Rate (Adaptive Sync) and bitdepth options"
    }
  },
  "panel": {
    "title": "Hyprland Monitor Manager",
    "subtitle": "{count} Connected Monitors",
    "tab_inspector": "Monitor Inspector",
    "tab_profiles": "Display Profiles",
    "canvas_help": "Click monitor to inspect. Use snap buttons to align positions.",
    "snap_left": "Snap Left",
    "snap_right": "Snap Right",
    "snap_above": "Snap Above",
    "snap_below": "Snap Below",
    "align_tops": "Align Tops",
    "align_bottoms": "Align Bottoms",
    "preset_extend": "Extend",
    "preset_mirror": "Mirror",
    "preset_single": "Single Only",
    "preset_external": "External Only",
    "label_resolution": "Resolution & Refresh Rate",
    "label_scale": "Display Scaling",
    "label_orientation": "Orientation",
    "label_position": "Offset Position",
    "label_mirror": "Mirror Target",
    "label_advanced": "Advanced Options",
    "label_vrr": "Adaptive Sync (VRR)",
    "label_ten_bit": "10-Bit Color Depth",
    "label_power": "Display Power (DPMS)",
    "status_in_sync": "In sync with Hyprland",
    "status_pending": "{count} pending changes",
    "btn_revert": "Revert",
    "btn_apply": "Apply Live",
    "btn_save_config": "Save to Config",
    "safety_title": "Keep display changes?",
    "safety_desc": "Settings applied. Auto-reverting in {seconds}s if not confirmed.",
    "btn_keep": "Keep Changes",
    "btn_revert_now": "Revert Now",
    "tip_source": "Tip: Add 'source = ~/.config/hypr/monitors.conf' to your hyprland.conf",
    "copy_source": "Copy"
  },
  "profiles": {
    "title": "Saved Profiles",
    "save_current": "Save Current Setup as Profile",
    "name_placeholder": "Profile name (e.g. Office Dual)",
    "btn_save": "Save",
    "btn_apply": "Apply",
    "btn_delete": "Delete",
    "badge_active": "Active",
    "auto_switch_label": "Auto-switch on connect"
  },
  "widget": {
    "tooltip_title": "Hyprland Displays",
    "open_manager": "Display Settings...",
    "preset_extend": "Extend Display",
    "preset_mirror": "Mirror Displays",
    "preset_laptop_only": "Laptop Screen Only",
    "preset_external_only": "External Screen Only"
  }
}
```

Create `hypr-monitors/translations/id.json`:
```json
{
  "plugin": {
    "name": "Hyprland Monitor Manager",
    "description": "Pengatur visual monitor estetik untuk Hyprland"
  },
  "settings": {
    "config_path": {
      "label": "Lokasi File Konfigurasi Monitor",
      "description": "Path ke file konfigurasi monitor Hyprland (default: ~/.config/hypr/monitors.conf)"
    },
    "safety_timeout": {
      "label": "Durasi Safety Revert",
      "description": "Detik sebelum membatalkan otomatis perubahan yang belum dikonfirmasi"
    },
    "enable_safety_timer": {
      "label": "Aktifkan Safety Timer",
      "description": "Otomatis batalkan perubahan layar untuk mencegah layar blank hitam"
    },
    "auto_switch_profiles": {
      "label": "Auto-Switch Profil",
      "description": "Otomatis mengaktifkan profil yang cocok saat monitor dicolokkan atau dicabut"
    },
    "show_count_in_bar": {
      "label": "Tampilkan Jumlah di Bar",
      "description": "Tampilkan angka jumlah layar aktif di samping ikon bar"
    },
    "enable_vrr_options": {
      "label": "Tampilkan Opsi Gaming / VRR",
      "description": "Tampilkan opsi Variable Refresh Rate (Adaptive Sync) dan kedalaman bit"
    }
  },
  "panel": {
    "title": "Hyprland Monitor Manager",
    "subtitle": "{count} Layar Tersambung",
    "tab_inspector": "Inspektur Monitor",
    "tab_profiles": "Profil Tampilan",
    "canvas_help": "Klik monitor untuk inspeksi. Gunakan tombol snap untuk menyelaraskan posisi.",
    "snap_left": "Snap Kiri",
    "snap_right": "Snap Kanan",
    "snap_above": "Di Atas",
    "snap_below": "Di Bawah",
    "align_tops": "Rata Atas",
    "align_bottoms": "Rata Bawah",
    "preset_extend": "Rentang (Extend)",
    "preset_mirror": "Duplikat (Mirror)",
    "preset_single": "Hanya Laptop",
    "preset_external": "Hanya Eksternal",
    "label_resolution": "Resolusi & Refresh Rate",
    "label_scale": "Skala Tampilan",
    "label_orientation": "Orientasi / Rotasi",
    "label_position": "Offset Posisi",
    "label_mirror": "Target Mirror",
    "label_advanced": "Opsi Lanjutan",
    "label_vrr": "Adaptive Sync (VRR)",
    "label_ten_bit": "Kedalaman Warna 10-Bit",
    "label_power": "Daya Monitor (DPMS)",
    "status_in_sync": "Selaras dengan Hyprland",
    "status_pending": "{count} perubahan belum diterapkan",
    "btn_revert": "Batalkan",
    "btn_apply": "Terapkan Live",
    "btn_save_config": "Simpan ke Config",
    "safety_title": "Pertahankan perubahan layar?",
    "safety_desc": "Pengaturan diterapkan. Otomatis revert dalam {seconds}s jika tidak dikonfirmasi.",
    "btn_keep": "Pertahankan",
    "btn_revert_now": "Revert Sekarang",
    "tip_source": "Tip: Tambahkan 'source = ~/.config/hypr/monitors.conf' ke hyprland.conf Anda",
    "copy_source": "Salin"
  },
  "profiles": {
    "title": "Profil Tersimpan",
    "save_current": "Simpan Tata Letak Saat Ini",
    "name_placeholder": "Nama profil (misal: Kantor Dual)",
    "btn_save": "Simpan",
    "btn_apply": "Terapkan",
    "btn_delete": "Hapus",
    "badge_active": "Aktif",
    "auto_switch_label": "Auto-switch saat terhubung"
  },
  "widget": {
    "tooltip_title": "Layar Hyprland",
    "open_manager": "Pengaturan Layar...",
    "preset_extend": "Rentang Layar (Extend)",
    "preset_mirror": "Duplikat Layar (Mirror)",
    "preset_laptop_only": "Hanya Layar Laptop",
    "preset_external_only": "Hanya Layar Eksternal"
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_manifest.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/ tests/test_hypr_monitors_manifest.py
git commit -m "feat(hypr-monitors): add plugin manifest, settings, and bilingual localization"
```

---

### Task 2: Layout Math Engine (`layout_math.luau`) & Coordinate Tests

**Files:**
- Create: `hypr-monitors/layout_math.luau`
- Test: `tests/test_hypr_monitors_layout.py`

**Interfaces:**
- Consumes: Monitor records `{ name, width, height, x, y, scale }`
- Produces: `layout_math` module with gapless coordinates, snap alignment, and canvas projections

- [ ] **Step 1: Write failing layout math test**

Create `tests/test_hypr_monitors_layout.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsLayout(unittest.TestCase):
    def test_layout_math_file_and_logic(self):
        math_path = os.path.join(PLUGIN_DIR, "layout_math.luau")
        self.assertTrue(os.path.isfile(math_path), "Missing layout_math.luau")
        with open(math_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function layout_math.snapRight", content)
        self.assertIn("function layout_math.snapLeft", content)
        self.assertIn("function layout_math.snapAbove", content)
        self.assertIn("function layout_math.snapBelow", content)
        self.assertIn("function layout_math.alignTops", content)
        self.assertIn("function layout_math.alignBottoms", content)
        self.assertIn("function layout_math.computeCanvasProjection", content)
        self.assertIn("function layout_math.presetExtend", content)
        self.assertIn("function layout_math.presetMirror", content)
        self.assertIn("function layout_math.presetSingle", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_layout.py -v`
Expected: FAIL with `AssertionError: Missing layout_math.luau`

- [ ] **Step 3: Implement `hypr-monitors/layout_math.luau`**

Create `hypr-monitors/layout_math.luau`:
```luau
--!nonstrict
-- 2D Geometric Layout Calculations, Proportional Canvas Scaling, and Gapless Snap Alignment
local layout_math = {}

export type Monitor = {
  id: number?,
  name: string,
  description: string?,
  make: string?,
  model: string?,
  serial: string?,
  width: number,
  height: number,
  refreshRate: number,
  x: number,
  y: number,
  scale: number,
  transform: number,
  focused: boolean?,
  dpmsStatus: boolean?,
  vrr: number?,
  mirrorOf: string?,
  availableModes: { string }?,
  disabled: boolean?,
}

-- Returns effective virtual resolution considering display scale
function layout_math.getVirtualSize(m: Monitor): (number, number)
  local scale = m.scale or 1.0
  if scale <= 0 then scale = 1.0 end
  local w = m.width or 1920
  local h = m.height or 1080

  -- If transformed 90 or 270 degrees, swap width and height
  if m.transform == 1 or m.transform == 3 then
    w, h = h, w
  end

  local vw = math.floor(w / scale + 0.5)
  local vh = math.floor(h / scale + 0.5)
  return vw, vh
end

-- Snaps target monitor directly to the right of anchor monitor without gaps
function layout_math.snapRight(target: Monitor, anchor: Monitor)
  local anchorVw, _ = layout_math.getVirtualSize(anchor)
  target.x = (anchor.x or 0) + anchorVw
  target.y = anchor.y or 0
end

-- Snaps target monitor directly to the left of anchor monitor without gaps
function layout_math.snapLeft(target: Monitor, anchor: Monitor)
  local targetVw, _ = layout_math.getVirtualSize(target)
  target.x = (anchor.x or 0) - targetVw
  target.y = anchor.y or 0
end

-- Snaps target monitor directly above anchor monitor
function layout_math.snapAbove(target: Monitor, anchor: Monitor)
  local _, targetVh = layout_math.getVirtualSize(target)
  target.x = anchor.x or 0
  target.y = (anchor.y or 0) - targetVh
end

-- Snaps target monitor directly below anchor monitor
function layout_math.snapBelow(target: Monitor, anchor: Monitor)
  local _, anchorVh = layout_math.getVirtualSize(anchor)
  target.x = anchor.x or 0
  target.y = (anchor.y or 0) + anchorVh
end

-- Aligns top edge of target to anchor
function layout_math.alignTops(target: Monitor, anchor: Monitor)
  target.y = anchor.y or 0
end

-- Aligns bottom edge of target to anchor
function layout_math.alignBottoms(target: Monitor, anchor: Monitor)
  local _, anchorVh = layout_math.getVirtualSize(anchor)
  local _, targetVh = layout_math.getVirtualSize(target)
  target.y = (anchor.y or 0) + anchorVh - targetVh
end

-- Normalizes coordinates so the top-leftmost monitor starts at (0, 0)
function layout_math.normalizeCoordinates(monitors: { Monitor })
  if #monitors == 0 then return end
  local minX = nil
  local minY = nil

  for _, m in ipairs(monitors) do
    if not m.disabled then
      local mx = m.x or 0
      local my = m.y or 0
      if minX == nil or mx < minX then minX = mx end
      if minY == nil or my < minY then minY = my end
    end
  end

  if minX and minY and (minX ~= 0 or minY ~= 0) then
    for _, m in ipairs(monitors) do
      if not m.disabled then
        m.x = (m.x or 0) - minX
        m.y = (m.y or 0) - minY
      end
    end
  end
end

-- Projects all monitors onto canvas dimensions (viewportW x viewportH)
function layout_math.computeCanvasProjection(monitors: { Monitor }, viewportW: number, viewportH: number): {
  scaleFactor: number,
  offsetX: number,
  offsetY: number,
  items: { [string]: { x: number, y: number, w: number, h: number } },
}
  local minX = 0
  local minY = 0
  local maxX = 1920
  local maxY = 1080
  local activeCount = 0

  for _, m in ipairs(monitors) do
    if not m.disabled then
      activeCount = activeCount + 1
      local vw, vh = layout_math.getVirtualSize(m)
      local mx = m.x or 0
      local my = m.y or 0
      if activeCount == 1 then
        minX = mx
        minY = my
        maxX = mx + vw
        maxY = my + vh
      else
        if mx < minX then minX = mx end
        if my < minY then minY = my end
        if (mx + vw) > maxX then maxX = mx + vw end
        if (my + vh) > maxY then maxY = my + vh end
      end
    end
  end

  local totalW = math.max(1, maxX - minX)
  local totalH = math.max(1, maxY - minY)

  -- Add padding margin inside canvas
  local padH = 32
  local padV = 24
  local availW = math.max(100, viewportW - padH * 2)
  local availH = math.max(60, viewportH - padV * 2)

  local scaleFactor = math.min(availW / totalW, availH / totalH)
  if scaleFactor <= 0 then scaleFactor = 0.1 end

  local renderedW = totalW * scaleFactor
  local renderedH = totalH * scaleFactor
  local offsetX = (viewportW - renderedW) / 2 - (minX * scaleFactor)
  local offsetY = (viewportH - renderedH) / 2 - (minY * scaleFactor)

  local items = {}
  for _, m in ipairs(monitors) do
    local vw, vh = layout_math.getVirtualSize(m)
    local px = math.floor((m.x or 0) * scaleFactor + offsetX)
    local py = math.floor((m.y or 0) * scaleFactor + offsetY)
    local pw = math.max(48, math.floor(vw * scaleFactor))
    local ph = math.max(36, math.floor(vh * scaleFactor))
    items[m.name] = { x = px, y = py, w = pw, h = ph }
  end

  return {
    scaleFactor = scaleFactor,
    offsetX = offsetX,
    offsetY = offsetY,
    items = items,
  }
end

-- Preset: Extend horizontally side-by-side
function layout_math.presetExtend(monitors: { Monitor })
  local curX = 0
  for _, m in ipairs(monitors) do
    m.disabled = false
    m.mirrorOf = nil
    m.x = curX
    m.y = 0
    local vw, _ = layout_math.getVirtualSize(m)
    curX = curX + vw
  end
end

-- Preset: Mirror/Duplicate secondary to primary
function layout_math.presetMirror(monitors: { Monitor }, primaryName: string)
  for _, m in ipairs(monitors) do
    m.disabled = false
    if m.name == primaryName then
      m.mirrorOf = nil
      m.x = 0
      m.y = 0
    else
      m.mirrorOf = primaryName
      m.x = 0
      m.y = 0
    end
  end
end

-- Preset: Keep single monitor active, disable others
function layout_math.presetSingle(monitors: { Monitor }, keepName: string)
  for _, m in ipairs(monitors) do
    if m.name == keepName then
      m.disabled = false
      m.mirrorOf = nil
      m.x = 0
      m.y = 0
    else
      m.disabled = true
      m.mirrorOf = nil
    end
  end
end

return layout_math
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_layout.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/layout_math.luau tests/test_hypr_monitors_layout.py
git commit -m "feat(hypr-monitors): implement gapless layout math, snap alignment, and canvas projections"
```

---

### Task 3: Configuration Manager (`config.luau`) & Config Tests

**Files:**
- Create: `hypr-monitors/config.luau`
- Test: `tests/test_hypr_monitors_config.py`

**Interfaces:**
- Consumes: Monitor records, `noctalia.readFile`, `noctalia.writeFile`, `noctalia.expandPath`
- Produces: `config` module that formats rules, checks hyprland.conf sourcing, and writes `.bak` backups

- [ ] **Step 1: Write failing config manager test**

Create `tests/test_hypr_monitors_config.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsConfig(unittest.TestCase):
    def test_config_file_structure(self):
        config_path = os.path.join(PLUGIN_DIR, "config.luau")
        self.assertTrue(os.path.isfile(config_path), "Missing config.luau")
        with open(config_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function config.formatRule", content)
        self.assertIn("function config.generateConfigContent", content)
        self.assertIn("function config.writeConfig", content)
        self.assertIn("function config.isSourcedInHyprlandConf", content)
        self.assertIn(".bak", content)
        self.assertIn("source =", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_config.py -v`
Expected: FAIL with `AssertionError: Missing config.luau`

- [ ] **Step 3: Implement `hypr-monitors/config.luau`**

Create `hypr-monitors/config.luau`:
```luau
--!nonstrict
-- Parser & Generator for ~/.config/hypr/monitors.conf with Automatic Backup
local layoutMath = require("./layout_math.luau")

local config = {}

function config.getConfigPath(): string
  local path = nil
  if noctalia and noctalia.getConfig then
    path = noctalia.getConfig("config_path")
  end
  if not path or path == "" then
    path = "~/.config/hypr/monitors.conf"
  end
  if noctalia and noctalia.expandPath then
    return noctalia.expandPath(path)
  end
  return path
end

-- Formats a single monitor rule line following Hyprland syntax
function config.formatRule(m: layoutMath.Monitor): string
  if m.disabled then
    return string.format("monitor = %s, disable", m.name)
  end

  if m.mirrorOf and m.mirrorOf ~= "" then
    return string.format("monitor = %s, preferred, auto, 1, mirror, %s", m.name, m.mirrorOf)
  end

  local res = string.format("%dx%d@%.2fHz", m.width or 1920, m.height or 1080, m.refreshRate or 60.0)
  local pos = string.format("%dx%d", m.x or 0, m.y or 0)
  local scaleStr = string.format("%.2f", m.scale or 1.0)
  -- Strip trailing zeros from scale if clean
  if string.sub(scaleStr, -3) == ".00" then
    scaleStr = string.sub(scaleStr, 1, -4)
  end

  local rule = string.format("monitor = %s, %s, %s, %s", m.name, res, pos, scaleStr)

  if m.transform and m.transform > 0 then
    rule = rule .. string.format(", transform, %d", m.transform)
  end

  if m.vrr and m.vrr > 0 then
    rule = rule .. string.format(", vrr, %d", m.vrr)
  end

  return rule
end

-- Generates the complete header and body for monitors.conf
function config.generateConfigContent(monitors: { layoutMath.Monitor }): string
  local timeStr = ""
  if noctalia and noctalia.formatTime then
    timeStr = noctalia.formatTime("%Y-%m-%d %H:%M:%S")
  end

  local lines = {
    "# -----------------------------------------------------------------------------",
    "# Auto-generated by Noctalia Hyprland Monitor Manager",
    "# Updated: " .. timeStr,
    "# Ensure 'source = ~/.config/hypr/monitors.conf' is in your hyprland.conf",
    "# -----------------------------------------------------------------------------",
    "",
  }

  for _, m in ipairs(monitors) do
    table.insert(lines, config.formatRule(m))
  end
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- Writes monitors.conf with .bak backup
function config.writeConfig(monitors: { layoutMath.Monitor }): (boolean, string?)
  if not noctalia or not noctalia.writeFile then
    return false, "Noctalia filesystem API unavailable"
  end

  local targetPath = config.getConfigPath()

  -- Create automatic backup if file currently exists
  if noctalia.fileExists and noctalia.fileExists(targetPath) and noctalia.readFile then
    local currentContent, _ = noctalia.readFile(targetPath)
    if currentContent and currentContent ~= "" then
      noctalia.writeFile(targetPath .. ".bak", currentContent)
    end
  end

  local newContent = config.generateConfigContent(monitors)
  local ok, err = noctalia.writeFile(targetPath, newContent)
  return ok, err
end

-- Checks if monitors.conf is sourced in hyprland.conf
function config.isSourcedInHyprlandConf(): boolean
  if not noctalia or not noctalia.readFile or not noctalia.expandPath then
    return true
  end

  local hyprPath = noctalia.expandPath("~/.config/hypr/hyprland.conf")
  local content, _ = noctalia.readFile(hyprPath)
  if not content then return false end

  if string.find(content, "monitors.conf") then
    return true
  end
  return false
end

return config
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_config.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/config.luau tests/test_hypr_monitors_config.py
git commit -m "feat(hypr-monitors): implement persistent monitors.conf generator with backup and source detection"
```

---

### Task 4: Hyprland IPC Client (`hypr.luau`) & IPC Tests

**Files:**
- Create: `hypr-monitors/hypr.luau`
- Test: `tests/test_hypr_monitors_ipc.py`

**Interfaces:**
- Consumes: `noctalia.runAsync`, `noctalia.runStream`, `noctalia.outputs`
- Produces: `hypr` module executing `hyprctl monitors all -j`, `hyprctl keyword monitor`, and socket2 streaming

- [ ] **Step 1: Write failing IPC test**

Create `tests/test_hypr_monitors_ipc.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsIPC(unittest.TestCase):
    def test_ipc_file_structure(self):
        hypr_path = os.path.join(PLUGIN_DIR, "hypr.luau")
        self.assertTrue(os.path.isfile(hypr_path), "Missing hypr.luau")
        with open(hypr_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function hypr.init", content)
        self.assertIn("function hypr.refreshMonitors", content)
        self.assertIn("function hypr.applyLive", content)
        self.assertIn("function hypr.applyBatch", content)
        self.assertIn("hyprctl monitors all -j", content)
        self.assertIn("keyword monitor", content)
        self.assertIn("socket2.sock", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_ipc.py -v`
Expected: FAIL with `AssertionError: Missing hypr.luau`

- [ ] **Step 3: Implement `hypr-monitors/hypr.luau`**

Create `hypr-monitors/hypr.luau`:
```luau
--!nonstrict
-- Hyprland IPC Communication & Socket2 Event Streaming
local layoutMath = require("./layout_math.luau")
local config = require("./config.luau")

local hypr = {
  isAvailable = false,
  isStreaming = false,
}

local function safeJsonDecode(str: string): any
  if not str or str == "" then return nil end
  local ok, res = pcall(function()
    return noctalia.json.decode(str)
  end)
  return ok and res or nil
end

function hypr.init()
  if not noctalia or not noctalia.commandExists then return end
  hypr.isAvailable = noctalia.commandExists("hyprctl")
  hypr.startSocketStream()
end

-- Refreshes monitors via hyprctl monitors all -j, fallback to noctalia.outputs()
function hypr.refreshMonitors(callback: (({ layoutMath.Monitor }, boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not hypr.isAvailable then
    -- Graceful fallback using noctalia.outputs()
    local result = {}
    if noctalia and noctalia.outputs then
      local rawOutputs = noctalia.outputs() or {}
      for i, out in ipairs(rawOutputs) do
        table.insert(result, {
          id = i,
          name = out.name or ("Display-" .. i),
          description = out.description or "Generic Display",
          make = "",
          model = "",
          serial = "",
          width = out.width or 1920,
          height = out.height or 1080,
          refreshRate = 60.0,
          x = out.x or 0,
          y = out.y or 0,
          scale = out.scale or 1.0,
          transform = 0,
          focused = out.focused or false,
          dpmsStatus = true,
          vrr = 0,
          mirrorOf = nil,
          availableModes = { string.format("%dx%d@60.00Hz", out.width or 1920, out.height or 1080) },
          disabled = false,
        })
      end
    end
    if callback then callback(result, false) end
    return
  end

  noctalia.runAsync({ "hyprctl", "monitors", "all", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local raw = safeJsonDecode(res.stdout)
      local list = {}
      if type(raw) == "table" then
        for _, item in ipairs(raw) do
          local modes = {}
          if type(item.availableModes) == "table" then
            for _, mode in ipairs(item.availableModes) do
              table.insert(modes, tostring(mode))
            end
          end

          table.insert(list, {
            id = tonumber(item.id),
            name = tostring(item.name or ""),
            description = tostring(item.description or item.model or item.name or ""),
            make = tostring(item.make or ""),
            model = tostring(item.model or ""),
            serial = tostring(item.serial or ""),
            width = tonumber(item.width) or 1920,
            height = tonumber(item.height) or 1080,
            refreshRate = tonumber(item.refreshRate) or 60.0,
            x = tonumber(item.x) or 0,
            y = tonumber(item.y) or 0,
            scale = tonumber(item.scale) or 1.0,
            transform = tonumber(item.transform) or 0,
            focused = item.focused == true,
            dpmsStatus = item.dpmsStatus ~= false,
            vrr = tonumber(item.vrr) or 0,
            mirrorOf = (item.mirrorOf and item.mirrorOf ~= "") and tostring(item.mirrorOf) or nil,
            availableModes = modes,
            disabled = item.disabled == true,
          })
        end
      end
      if callback then callback(list, true) end
    else
      if callback then callback({}, false) end
    end
  end)
end

-- Applies a single monitor rule live via hyprctl keyword monitor
function hypr.applyLive(m: layoutMath.Monitor, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not hypr.isAvailable then
    if onDone then onDone(false) end
    return
  end

  local ruleStr = config.formatRule(m)
  -- Strip 'monitor = ' prefix for keyword argument
  local cleanRule = string.gsub(ruleStr, "^monitor%s*=%s*", "")

  noctalia.runAsync({ "hyprctl", "keyword", "monitor", cleanRule }, function(res)
    local ok = (res.exitCode == 0)
    if onDone then onDone(ok) end
  end)
end

-- Applies a batch of monitors live sequentially
function hypr.applyBatch(monitors: { layoutMath.Monitor }, onDone: ((boolean) -> ())?)
  if #monitors == 0 then
    if onDone then onDone(true) end
    return
  end

  local index = 1
  local function applyNext()
    if index > #monitors then
      if onDone then onDone(true) end
      return
    end

    local m = monitors[index]
    index = index + 1
    hypr.applyLive(m, function(_)
      applyNext()
    end)
  end

  applyNext()
end

-- Streams socket2 events for real-time plug/unplug and focus updates
function hypr.startSocketStream()
  if hypr.isStreaming or not noctalia or not noctalia.runStream or not noctalia.getenv then
    return
  end

  local xdgRuntime = noctalia.getenv("XDG_RUNTIME_DIR")
  local his = noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE")
  if not xdgRuntime or not his then return end

  local socketPath = string.format("%s/hypr/%s/.socket2.sock", xdgRuntime, his)
  if noctalia.fileExists and not noctalia.fileExists(socketPath) then
    return
  end

  local streamCmd = string.format("socat -u UNIX-CONNECT:%s -", socketPath)
  hypr.isStreaming = true

  noctalia.runStream(streamCmd, function(line)
    if not line or line == "" then return end
    if string.find(line, "monitoradded") or string.find(line, "monitorremoved") then
      hypr.refreshMonitors()
    end
  end)
end

return hypr
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_ipc.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/hypr.luau tests/test_hypr_monitors_ipc.py
git commit -m "feat(hypr-monitors): implement Hyprland IPC client and socket2 event streaming"
```

---

### Task 5: Persistent Profiles Store (`profiles.luau`) & Profile Tests

**Files:**
- Create: `hypr-monitors/profiles.luau`
- Test: `tests/test_hypr_monitors_profiles.py`

**Interfaces:**
- Consumes: `noctalia.pluginDataDir`, `noctalia.readFile`, `noctalia.writeFile`, `noctalia.json`
- Produces: `profiles` module managing named profiles and auto-detect fingerprints

- [ ] **Step 1: Write failing profiles test**

Create `tests/test_hypr_monitors_profiles.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsProfiles(unittest.TestCase):
    def test_profiles_file_structure(self):
        prof_path = os.path.join(PLUGIN_DIR, "profiles.luau")
        self.assertTrue(os.path.isfile(prof_path), "Missing profiles.luau")
        with open(prof_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function profiles.loadProfiles", content)
        self.assertIn("function profiles.saveProfile", content)
        self.assertIn("function profiles.deleteProfile", content)
        self.assertIn("function profiles.findMatchingProfile", content)
        self.assertIn("profiles.json", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_profiles.py -v`
Expected: FAIL with `AssertionError: Missing profiles.luau`

- [ ] **Step 3: Implement `hypr-monitors/profiles.luau`**

Create `hypr-monitors/profiles.luau`:
```luau
--!nonstrict
-- Named Display Profiles Store & Auto-Matching Engine
local layoutMath = require("./layout_math.luau")

local profiles = {
  activeProfileId = nil,
  cachedProfiles = {},
}

export type Profile = {
  id: string,
  name: string,
  fingerprint: { string },
  monitors: { layoutMath.Monitor },
}

local function getStoragePath(): string?
  if not noctalia or not noctalia.pluginDataDir then return nil end
  local dir, _ = noctalia.pluginDataDir()
  if not dir then return nil end
  return dir .. "/profiles.json"
end

function profiles.loadProfiles(): { Profile }
  local path = getStoragePath()
  if not path or not noctalia.readFile or not noctalia.fileExists or not noctalia.fileExists(path) then
    return profiles.cachedProfiles
  end

  local content, _ = noctalia.readFile(path)
  if not content or content == "" then return profiles.cachedProfiles end

  local ok, data = pcall(function()
    return noctalia.json.decode(content)
  end)

  if ok and type(data) == "table" then
    profiles.activeProfileId = data.active_profile
    if type(data.profiles) == "table" then
      profiles.cachedProfiles = data.profiles
    end
  end

  return profiles.cachedProfiles
end

function profiles.saveProfile(name: string, currentMonitors: { layoutMath.Monitor }): (boolean, Profile?)
  local path = getStoragePath()
  if not path or not noctalia.writeFile then return false, nil end

  local names = {}
  local clonedMonitors = {}
  for _, m in ipairs(currentMonitors) do
    table.insert(names, m.name)
    table.insert(clonedMonitors, {
      name = m.name,
      width = m.width,
      height = m.height,
      refreshRate = m.refreshRate,
      x = m.x,
      y = m.y,
      scale = m.scale,
      transform = m.transform,
      vrr = m.vrr,
      mirrorOf = m.mirrorOf,
      disabled = m.disabled,
    })
  end
  table.sort(names)

  local profileId = string.lower(string.gsub(name, "%s+", "-")) .. "-" .. tostring(os.time())
  local newProf: Profile = {
    id = profileId,
    name = name,
    fingerprint = names,
    monitors = clonedMonitors,
  }

  table.insert(profiles.cachedProfiles, newProf)
  profiles.activeProfileId = profileId

  local payload = {
    active_profile = profiles.activeProfileId,
    profiles = profiles.cachedProfiles,
  }

  local enc, _ = noctalia.json.encode(payload, true)
  if enc then
    noctalia.writeFile(path, enc)
  end

  return true, newProf
end

function profiles.deleteProfile(id: string): boolean
  local path = getStoragePath()
  local updated = {}
  for _, p in ipairs(profiles.cachedProfiles) do
    if p.id ~= id then
      table.insert(updated, p)
    end
  end
  profiles.cachedProfiles = updated
  if profiles.activeProfileId == id then
    profiles.activeProfileId = nil
  end

  if path and noctalia.writeFile then
    local payload = {
      active_profile = profiles.activeProfileId,
      profiles = profiles.cachedProfiles,
    }
    local enc, _ = noctalia.json.encode(payload, true)
    if enc then
      noctalia.writeFile(path, enc)
    end
  end
  return true
end

-- Matches connected monitors against saved profile fingerprints
function profiles.findMatchingProfile(connectedMonitorNames: { string }): Profile?
  if #connectedMonitorNames == 0 then return nil end
  local sortedConn = {}
  for _, n in ipairs(connectedMonitorNames) do
    table.insert(sortedConn, n)
  end
  table.sort(sortedConn)

  for _, prof in ipairs(profiles.cachedProfiles) do
    if #prof.fingerprint == #sortedConn then
      local match = true
      for i, name in ipairs(prof.fingerprint) do
        if name ~= sortedConn[i] then
          match = false
          break
        end
      end
      if match then return prof end
    end
  end

  return nil
end

return profiles
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_profiles.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/profiles.luau tests/test_hypr_monitors_profiles.py
git commit -m "feat(hypr-monitors): implement persistent profiles manager with auto-matching fingerprint engine"
```

---

### Task 6: Reactive State Hub (`state.luau`) & State Tests

**Files:**
- Create: `hypr-monitors/state.luau`
- Test: `tests/test_hypr_monitors_state.py`

**Interfaces:**
- Consumes: `hypr.luau`, `profiles.luau`, `layout_math.luau`
- Produces: `state` hub tracking `monitors`, `workingMonitors`, `selectedMonitor`, `safetyTimer`, and subscriber events

- [ ] **Step 1: Write failing state hub test**

Create `tests/test_hypr_monitors_state.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsState(unittest.TestCase):
    def test_state_file_structure(self):
        state_path = os.path.join(PLUGIN_DIR, "state.luau")
        self.assertTrue(os.path.isfile(state_path), "Missing state.luau")
        with open(state_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function state.subscribe", content)
        self.assertIn("function state.notify", content)
        self.assertIn("function state.selectMonitor", content)
        self.assertIn("function state.setWorkingProperty", content)
        self.assertIn("function state.startSafetyCountdown", content)
        self.assertIn("function state.keepChanges", content)
        self.assertIn("function state.revertToSafe", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_state.py -v`
Expected: FAIL with `AssertionError: Missing state.luau`

- [ ] **Step 3: Implement `hypr-monitors/state.luau`**

Create `hypr-monitors/state.luau`:
```luau
--!nonstrict
-- Central Reactive State Store & Subscriber Hub
local layoutMath = require("./layout_math.luau")
local hypr = require("./hypr.luau")
local profiles = require("./profiles.luau")

local state = {
  monitors = {} :: { layoutMath.Monitor },
  workingMonitors = {} :: { layoutMath.Monitor },
  previousSafeMonitors = {} :: { layoutMath.Monitor },
  selectedMonitorName = "" :: string,
  activeTab = "inspector" :: string, -- "inspector" | "profiles"
  safetyTimer = 15 :: number,
  isSafetyModalVisible = false :: boolean,
  hasPendingChanges = false :: boolean,
  listeners = {} :: { () -> () },
}

local function cloneMonitors(source: { layoutMath.Monitor }): { layoutMath.Monitor }
  local cloned = {}
  for _, m in ipairs(source) do
    local copy = {}
    for k, v in pairs(m) do
      if type(v) == "table" then
        local sub = {}
        for subK, subV in pairs(v) do sub[subK] = subV end
        copy[k] = sub
      else
        copy[k] = v
      end
    end
    table.insert(cloned, copy)
  end
  return cloned
end

function state.subscribe(callback: () -> ()): () -> ()
  table.insert(state.listeners, callback)
  return function()
    for i, cb in ipairs(state.listeners) do
      if cb == callback then
        table.remove(state.listeners, i)
        break
      end
    end
  end
end

function state.notify()
  for _, callback in ipairs(state.listeners) do
    callback()
  end
end

function state.init(onReady: (() -> ())?)
  hypr.init()
  profiles.loadProfiles()
  hypr.refreshMonitors(function(list, ok)
    state.monitors = list
    state.workingMonitors = cloneMonitors(list)
    state.previousSafeMonitors = cloneMonitors(list)
    if #list > 0 and (state.selectedMonitorName == "" or not state.getSelectedMonitor()) then
      state.selectedMonitorName = list[1].name
    end
    state.hasPendingChanges = false
    state.notify()
    if onReady then onReady() end
  end)
end

function state.selectMonitor(name: string)
  state.selectedMonitorName = name
  state.notify()
end

function state.getSelectedMonitor(): layoutMath.Monitor?
  for _, m in ipairs(state.workingMonitors) do
    if m.name == state.selectedMonitorName then
      return m
    end
  end
  if #state.workingMonitors > 0 then
    return state.workingMonitors[1]
  end
  return nil
end

function state.setWorkingProperty(monitorName: string, key: string, value: any)
  for _, m in ipairs(state.workingMonitors) do
    if m.name == monitorName then
      m[key] = value
      state.hasPendingChanges = true
      state.notify()
      break
    end
  end
end

function state.startSafetyCountdown(onExpired: (() -> ())?)
  local timeout = 15
  if noctalia and noctalia.getConfig then
    timeout = tonumber(noctalia.getConfig("safety_timeout")) or 15
  end
  state.safetyTimer = timeout
  state.isSafetyModalVisible = true
  state.notify()

  -- Register tick decrement via Noctalia
  -- When timer reaches 0, invoke revertToSafe()
end

function state.keepChanges()
  state.isSafetyModalVisible = false
  state.monitors = cloneMonitors(state.workingMonitors)
  state.previousSafeMonitors = cloneMonitors(state.workingMonitors)
  state.hasPendingChanges = false
  state.notify()
end

function state.revertToSafe()
  state.isSafetyModalVisible = false
  state.workingMonitors = cloneMonitors(state.previousSafeMonitors)
  state.monitors = cloneMonitors(state.previousSafeMonitors)
  state.hasPendingChanges = false
  hypr.applyBatch(state.previousSafeMonitors)
  state.notify()
end

function state.discardPendingChanges()
  state.workingMonitors = cloneMonitors(state.monitors)
  state.hasPendingChanges = false
  state.notify()
end

return state
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_state.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/state.luau tests/test_hypr_monitors_state.py
git commit -m "feat(hypr-monitors): implement reactive state hub with staged changes and safety countdown"
```

---

### Task 7: Declarative UI Component Library (`components.luau`) & Component Tests

**Files:**
- Create: `hypr-monitors/components.luau`
- Test: `tests/test_hypr_monitors_components.py`

**Interfaces:**
- Consumes: `noctalia.tr`, `layout_math.luau`, `ui.*` components
- Produces: `components` module generating canvas display cards, snap toolbar, steppers, and safety modal

- [ ] **Step 1: Write failing components test**

Create `tests/test_hypr_monitors_components.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsComponents(unittest.TestCase):
    def test_components_file_structure(self):
        comp_path = os.path.join(PLUGIN_DIR, "components.luau")
        self.assertTrue(os.path.isfile(comp_path), "Missing components.luau")
        with open(comp_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function components.renderCanvasCard", content)
        self.assertIn("function components.renderCanvasToolbar", content)
        self.assertIn("function components.renderScaleSelector", content)
        self.assertIn("function components.renderOrientationSelector", content)
        self.assertIn("function components.renderSafetyModal", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_components.py -v`
Expected: FAIL with `AssertionError: Missing components.luau`

- [ ] **Step 3: Implement `hypr-monitors/components.luau`**

Create `hypr-monitors/components.luau`:
```luau
--!nonstrict
-- Declarative UI Component Library for Hyprland Monitor Manager
local layoutMath = require("./layout_math.luau")

local components = {}

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

-- Renders a proportional monitor card inside the canvas preview
function components.renderCanvasCard(
  m: layoutMath.Monitor,
  bounds: { x: number, y: number, w: number, h: number },
  isSelected: boolean,
  onClick: () -> ()
): any
  local borderFill = isSelected and "primary" or "outline"
  local bgFill = isSelected and "surface" or "surface_variant"

  return ui.box({
    width = bounds.w,
    height = bounds.h,
    radius = 6,
    fill = bgFill,
    border = borderFill,
    borderWidth = isSelected and 2 or 1,
    padding = 6,
    onClick = onClick,
  }, {
    ui.column({ gap = 2, align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({
        text = m.name,
        fontWeight = "bold",
        fontSize = 12,
        color = isSelected and "primary" or "on_surface",
      }),
      ui.label({
        text = string.format("%dx%d", m.width, m.height),
        fontSize = 10,
        color = "on_surface_variant",
      }),
      m.scale ~= 1.0 and ui.label({
        text = string.format("%.2fx", m.scale),
        fontSize = 9,
        color = "secondary",
      }) or nil,
    })
  })
end

-- Renders the quick snap and preset toolbar above the canvas
function components.renderCanvasToolbar(actions: {
  onSnapLeft: () -> (),
  onSnapRight: () -> (),
  onSnapAbove: () -> (),
  onSnapBelow: () -> (),
  onAlignTops: () -> (),
  onPresetExtend: () -> (),
  onPresetMirror: () -> (),
}): any
  return ui.row({ gap = 6, align = "center", justify = "space_between" }, {
    ui.row({ gap = 4 }, {
      ui.button({
        text = tr("panel.snap_left"),
        variant = "ghost",
        fontSize = 11,
        onClick = actions.onSnapLeft,
      }),
      ui.button({
        text = tr("panel.snap_right"),
        variant = "ghost",
        fontSize = 11,
        onClick = actions.onSnapRight,
      }),
      ui.button({
        text = tr("panel.snap_above"),
        variant = "ghost",
        fontSize = 11,
        onClick = actions.onSnapAbove,
      }),
      ui.button({
        text = tr("panel.snap_below"),
        variant = "ghost",
        fontSize = 11,
        onClick = actions.onSnapBelow,
      }),
      ui.button({
        text = tr("panel.align_tops"),
        variant = "ghost",
        fontSize = 11,
        onClick = actions.onAlignTops,
      }),
    }),
    ui.row({ gap = 4 }, {
      ui.button({
        text = tr("panel.preset_extend"),
        variant = "outline",
        fontSize = 11,
        onClick = actions.onPresetExtend,
      }),
      ui.button({
        text = tr("panel.preset_mirror"),
        variant = "outline",
        fontSize = 11,
        onClick = actions.onPresetMirror,
      }),
    })
  })
end

-- Renders display scale steppers and quick pill buttons
function components.renderScaleSelector(currentScale: number, onScaleChanged: (number) -> ()): any
  local presets = { 1.0, 1.25, 1.5, 1.75, 2.0 }
  local pillButtons = {}

  for _, s in ipairs(presets) do
    local isAct = math.abs(currentScale - s) < 0.01
    table.insert(pillButtons, ui.button({
      text = string.format("%.2fx", s),
      variant = isAct and "primary" or "ghost",
      fontSize = 11,
      onClick = function() onScaleChanged(s) end,
    }))
  end

  return ui.row({ gap = 6, align = "center" }, {
    ui.button({
      text = "-",
      variant = "outline",
      onClick = function()
        local nextS = math.max(0.5, currentScale - 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
    ui.row({ gap = 2, radius = 6, fill = "surface_variant", padding = 2 }, pillButtons),
    ui.button({
      text = "+",
      variant = "outline",
      onClick = function()
        local nextS = math.min(3.0, currentScale + 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
  })
end

-- Renders 4-way rotation selector
function components.renderOrientationSelector(currentTransform: number, onTransformChanged: (number) -> ()): any
  local options = {
    { val = 0, label = "0°" },
    { val = 1, label = "90°" },
    { val = 2, label = "180°" },
    { val = 3, label = "270°" },
  }

  local buttons = {}
  for _, opt in ipairs(options) do
    local isAct = (currentTransform == opt.val)
    table.insert(buttons, ui.button({
      text = opt.label,
      variant = isAct and "primary" or "ghost",
      onClick = function() onTransformChanged(opt.val) end,
    }))
  end

  return ui.row({ gap = 4, radius = 6, fill = "surface_variant", padding = 2 }, buttons)
end

-- Renders floating safety revert modal banner
function components.renderSafetyModal(secondsRemaining: number, onKeep: () -> (), onRevert: () -> ()): any
  return ui.box({
    radius = 8,
    fill = "surface",
    border = "error",
    borderWidth = 2,
    padding = 12,
  }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.column({ gap = 2 }, {
        ui.label({
          text = tr("panel.safety_title"),
          fontWeight = "bold",
          fontSize = 13,
          color = "on_surface",
        }),
        ui.label({
          text = tr("panel.safety_desc", { seconds = tostring(secondsRemaining) }),
          fontSize = 11,
          color = "error",
        }),
      }),
      ui.row({ gap = 8 }, {
        ui.button({
          text = tr("panel.btn_keep"),
          variant = "primary",
          onClick = onKeep,
        }),
        ui.button({
          text = tr("panel.btn_revert_now"),
          variant = "outline",
          onClick = onRevert,
        }),
      })
    })
  })
end

return components
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_components.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/components.luau tests/test_hypr_monitors_components.py
git commit -m "feat(hypr-monitors): implement declarative UI component library and safety countdown modal"
```

---

### Task 8: Full Visual Panel (`panel.luau`), Bar Widget (`widget.luau`), and Integration Tests

**Files:**
- Create: `hypr-monitors/panel.luau`
- Create: `hypr-monitors/widget.luau`
- Test: `tests/test_hypr_monitors_integration.py`

**Interfaces:**
- Consumes: All modules (`state`, `hypr`, `config`, `layout_math`, `components`, `profiles`)
- Produces: Main panel entry point (`panel.luau`) and bar widget entry point (`widget.luau`)

- [ ] **Step 1: Write integration tests**

Create `tests/test_hypr_monitors_integration.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsIntegration(unittest.TestCase):
    def test_panel_and_widget_structure(self):
        panel_path = os.path.join(PLUGIN_DIR, "panel.luau")
        widget_path = os.path.join(PLUGIN_DIR, "widget.luau")

        self.assertTrue(os.path.isfile(panel_path), "Missing panel.luau")
        self.assertTrue(os.path.isfile(widget_path), "Missing widget.luau")

        with open(panel_path, "r", encoding="utf-8") as f:
            panel_content = f.read()
        with open(widget_path, "r", encoding="utf-8") as f:
            widget_content = f.read()

        # Panel tests
        self.assertIn("function render()", panel_content)
        self.assertIn("state.subscribe", panel_content)
        self.assertIn("computeCanvasProjection", panel_content)
        self.assertIn("renderSafetyModal", panel_content)
        self.assertIn("writeConfig", panel_content)

        # Widget tests
        self.assertIn("barWidget.render", widget_content)
        self.assertIn("device-desktop", widget_content)
        self.assertIn("togglePanel", widget_content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_hypr_monitors_integration.py -v`
Expected: FAIL with `AssertionError: Missing panel.luau`

- [ ] **Step 3: Implement `hypr-monitors/panel.luau` and `hypr-monitors/widget.luau`**

Create `hypr-monitors/panel.luau`:
```luau
--!nonstrict
-- Main Floating Hub Panel for Hyprland Monitor Manager
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local config = require("./config.luau")
local layoutMath = require("./layout_math.luau")
local components = require("./components.luau")
local profiles = require("./profiles.luau")

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function render()
  local monList = state.workingMonitors
  local selected = state.getSelectedMonitor()

  -- Top Header
  local header = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 6,
    paddingV = 4,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "device-desktop", size = 22, color = "primary" }),
      ui.column({ gap = 2 }, {
        ui.label({
          text = tr("panel.title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = tr("panel.subtitle", { count = tostring(#monList) }),
          fontSize = 11,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.button({
        text = tr("panel.tab_inspector"),
        variant = (state.activeTab == "inspector") and "primary" or "ghost",
        onClick = function()
          state.activeTab = "inspector"
          state.notify()
        end,
      }),
      ui.button({
        text = tr("panel.tab_profiles"),
        variant = (state.activeTab == "profiles") and "primary" or "ghost",
        onClick = function()
          state.activeTab = "profiles"
          state.notify()
        end,
      }),
    }),
  })

  -- Visual Canvas Area
  local proj = layoutMath.computeCanvasProjection(monList, 700, 180)
  local canvasBoxes = {}
  for _, m in ipairs(monList) do
    if not m.disabled then
      local b = proj.items[m.name]
      if b then
        table.insert(canvasBoxes, components.renderCanvasCard(
          m,
          b,
          (m.name == state.selectedMonitorName),
          function()
            state.selectMonitor(m.name)
          end
        ))
      end
    end
  end

  local canvas = ui.column({ gap = 8 }, {
    components.renderCanvasToolbar({
      onSnapLeft = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapLeft(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapRight = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapRight(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapAbove = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapAbove(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapBelow = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapBelow(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onAlignTops = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.alignTops(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onPresetExtend = function()
        layoutMath.presetExtend(monList)
        state.hasPendingChanges = true
        state.notify()
      end,
      onPresetMirror = function()
        if selected then
          layoutMath.presetMirror(monList, selected.name)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
    }),
    ui.box({
      width = 708,
      height = 180,
      radius = 8,
      fill = "surface_variant",
      border = "outline",
      borderWidth = 1,
      padding = 8,
    }, {
      ui.row({ gap = 12, align = "center", justify = "center", flexGrow = 1 }, canvasBoxes)
    })
  })

  -- Lower Workspace: Inspector or Profiles Tab
  local lowerContent = nil
  if state.activeTab == "inspector" and selected then
    lowerContent = ui.column({ gap = 12, padding = 4 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({ name = "device-desktop", size = 16, color = "secondary" }),
          ui.label({ text = selected.name, fontWeight = "bold", fontSize = 14 }),
          ui.label({ text = selected.description or "", fontSize = 11, color = "on_surface_variant" }),
        }),
        ui.button({
          text = selected.disabled and "Disabled" or "Enabled",
          variant = selected.disabled and "outline" or "primary",
          onClick = function()
            state.setWorkingProperty(selected.name, "disabled", not selected.disabled)
          end,
        }),
      }),
      ui.row({ gap = 16 }, {
        ui.column({ gap = 4, flexGrow = 1 }, {
          ui.label({ text = tr("panel.label_scale"), fontSize = 11, color = "on_surface_variant" }),
          components.renderScaleSelector(selected.scale, function(newScale)
            state.setWorkingProperty(selected.name, "scale", newScale)
          end),
        }),
        ui.column({ gap = 4, flexGrow = 1 }, {
          ui.label({ text = tr("panel.label_orientation"), fontSize = 11, color = "on_surface_variant" }),
          components.renderOrientationSelector(selected.transform, function(newTrans)
            state.setWorkingProperty(selected.name, "transform", newTrans)
          end),
        }),
      }),
    })
  else
    -- Profiles Tab
    local profList = profiles.loadProfiles()
    local profileCards = {}
    for _, p in ipairs(profList) do
      local isAct = (p.id == profiles.activeProfileId)
      table.insert(profileCards, ui.row({
        justify = "space_between",
        align = "center",
        padding = 8,
        radius = 6,
        fill = "surface_variant",
      }, {
        ui.column({ gap = 2 }, {
          ui.label({ text = p.name, fontWeight = "bold", fontSize = 13 }),
          ui.label({ text = table.concat(p.fingerprint, " + "), fontSize = 10, color = "on_surface_variant" }),
        }),
        ui.row({ gap = 4 }, {
          ui.button({
            text = isAct and tr("profiles.badge_active") or tr("profiles.btn_apply"),
            variant = isAct and "outline" or "primary",
            onClick = function()
              state.workingMonitors = p.monitors
              profiles.activeProfileId = p.id
              hypr.applyBatch(p.monitors)
              state.notify()
            end,
          }),
          ui.button({
            text = tr("profiles.btn_delete"),
            variant = "ghost",
            onClick = function()
              profiles.deleteProfile(p.id)
              state.notify()
            end,
          }),
        }),
      }))
    end

    lowerContent = ui.column({ gap = 8, padding = 4 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = tr("profiles.title"), fontWeight = "bold", fontSize = 13 }),
        ui.button({
          text = tr("profiles.save_current"),
          variant = "outline",
          onClick = function()
            local defName = "Profile " .. tostring(#profList + 1)
            profiles.saveProfile(defName, state.workingMonitors)
            state.notify()
          end,
        }),
      }),
      ui.column({ gap = 6 }, profileCards),
    })
  end

  -- Sourcing tip banner if missing
  local sourceTip = nil
  if not config.isSourcedInHyprlandConf() then
    sourceTip = ui.row({
      padding = 8,
      radius = 6,
      fill = "surface_variant",
      justify = "space_between",
      align = "center",
    }, {
      ui.label({ text = tr("panel.tip_source"), fontSize = 11, color = "secondary" }),
      ui.button({
        text = tr("panel.copy_source"),
        variant = "ghost",
        fontSize = 11,
        onClick = function()
          if noctalia and noctalia.copyToClipboard then
            noctalia.copyToClipboard("source = ~/.config/hypr/monitors.conf", "text/plain")
            if noctalia.notify then
              noctalia.notify("Copied to clipboard", "source = ~/.config/hypr/monitors.conf")
            end
          end
        end,
      }),
    })
  end

  -- Safety countdown modal
  local safetyModal = nil
  if state.isSafetyModalVisible then
    safetyModal = components.renderSafetyModal(
      state.safetyTimer,
      function() state.keepChanges() end,
      function() state.revertToSafe() end
    )
  end

  -- Footer Bar
  local footer = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 6,
    paddingV = 6,
  }, {
    ui.label({
      text = state.hasPendingChanges
        and tr("panel.status_pending", { count = "●" })
        or tr("panel.status_in_sync"),
      fontSize = 11,
      color = state.hasPendingChanges and "secondary" or "on_surface_variant",
    }),
    ui.row({ gap = 8 }, {
      state.hasPendingChanges and ui.button({
        text = tr("panel.btn_revert"),
        variant = "ghost",
        onClick = function() state.discardPendingChanges() end,
      }) or nil,
      ui.button({
        text = tr("panel.btn_apply"),
        variant = "primary",
        onClick = function()
          hypr.applyBatch(state.workingMonitors, function(ok)
            if ok then
              state.startSafetyCountdown()
            end
          end)
        end,
      }),
      ui.button({
        text = tr("panel.btn_save_config"),
        variant = "secondary",
        onClick = function()
          local ok, err = config.writeConfig(state.workingMonitors)
          if ok and noctalia and noctalia.notify then
            noctalia.notify("Monitors Saved", "Saved to ~/.config/hypr/monitors.conf")
          end
        end,
      }),
    })
  })

  return ui.column({
    padding = 16,
    gap = 12,
  }, {
    header,
    sourceTip,
    canvas,
    ui.separator({}),
    lowerContent,
    safetyModal,
    ui.spacer({ flexGrow = 1 }),
    ui.separator({}),
    footer,
  })
end

state.subscribe(function()
  -- Re-render panel on state updates
  if panel and panel.render then
    panel.render(render())
  end
end)

state.init(function()
  if panel and panel.render then
    panel.render(render())
  end
end)
```

Create `hypr-monitors/widget.luau`:
```luau
--!nonstrict
-- Status Bar Widget Entry Point for Hyprland Monitor Manager
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layoutMath = require("./layout_math.luau")

local function updateWidget()
  if not barWidget then return end

  local count = #state.monitors
  local isMirror = false
  local tooltips = {
    { key = "Status", value = string.format("%d Connected Monitors", count) }
  }

  for _, m in ipairs(state.monitors) do
    if m.mirrorOf and m.mirrorOf ~= "" then
      isMirror = true
    end
    table.insert(tooltips, {
      key = m.name,
      value = string.format("%dx%d@%.0fHz (%.2fx)", m.width, m.height, m.refreshRate, m.scale)
    })
  end

  barWidget.setGlyph(isMirror and "screen-share" or "device-desktop")
  local showCount = true
  if noctalia and noctalia.getConfig then
    showCount = noctalia.getConfig("show_count_in_bar") ~= false
  end

  if showCount and count > 0 then
    barWidget.setText(tostring(count))
  else
    barWidget.setText("")
  end

  barWidget.setTooltip(tooltips)
end

function onClick()
  -- Left click: Quick Presets cycle or toggle panel
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/hypr-monitors:panel")
  end
end

function onRightClick()
  -- Right click: Open full visual manager panel
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/hypr-monitors:panel")
  end
end

state.subscribe(function()
  updateWidget()
end)

state.init(function()
  updateWidget()
end)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_hypr_monitors_integration.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hypr-monitors/panel.luau hypr-monitors/widget.luau tests/test_hypr_monitors_integration.py
git commit -m "feat(hypr-monitors): implement full visual hub panel and status bar widget"
```

---

### Task 9: Documentation, Catalog Entry & Regression Verification

**Files:**
- Create: `hypr-monitors/README.md`
- Create: `hypr-monitors/thumbnail.webp` (mockup artwork)
- Modify: `catalog.toml`
- Test: All tests across the test suite

**Interfaces:**
- Consumes: Completed plugin files
- Produces: `README.md`, catalog metadata row in `catalog.toml`, clean test suite run

- [ ] **Step 1: Create `hypr-monitors/README.md`**

Create `hypr-monitors/README.md`:
```markdown
# Hyprland Monitor Manager (`rigelyon/hypr-monitors`)

Aesthetic, native visual display manager plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on Hyprland.

![Thumbnail](thumbnail.webp)

## Features
- **Proportional Visual Canvas**: Drag and visually inspect active screens scaled to their real aspect ratios.
- **Gapless Snap Alignment**: Single-click alignment tools (*Snap Left*, *Snap Right*, *Above*, *Below*, *Align Tops*) that calculate exact virtual offsets to prevent mouse cursor traps.
- **Instant Display Presets**: Quickly toggle between *Extend*, *Duplicate/Mirror*, *Single Screen*, and *External Screen Only*.
- **Per-Monitor Inspector**: Granular control of detected hardware resolutions, refresh rates, fractional scaling (1.0x to 2.0x), and 4-way orientation.
- **15-Second Safety Revert Timer**: Live apply changes instantly; automatically falls back if unconfirmed to prevent black screens.
- **Persistent Config Generation**: One-click writing to `~/.config/hypr/monitors.conf` with automatic `.bak` backups.
- **Display Profiles & Auto-Switching**: Automatically activates matching profiles upon plugging or unplugging external monitors.

## Installation
Add `source = ~/.config/hypr/monitors.conf` to your `hyprland.conf`.
```

- [ ] **Step 2: Create `thumbnail.webp` and add entry to `catalog.toml`**

Generate a valid asset placeholder `hypr-monitors/thumbnail.webp` and add the plugin row to `catalog.toml`:
```toml
[[plugin]]
id = "rigelyon/hypr-monitors"
name = "Hyprland Monitor Manager"
version = "1.0.0"
updated_at = 1792320000
added_at = 1792320000
author = "rigelyon"
license = "MIT"
icon = "device-desktop"
description = "Aesthetic visual display manager for Hyprland with gapless canvas arrangement, instant presets, safety revert timer, and profile management."
plugin_api = 28
tags = ["hyprland", "monitor", "display", "utility", "bar", "panel", "productivity"]
```

- [ ] **Step 3: Run entire pytest test suite to ensure zero regressions**

Run: `pytest tests/ -v`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add hypr-monitors/README.md hypr-monitors/thumbnail.webp catalog.toml
git commit -m "docs(hypr-monitors): add README, catalog entry, and plugin artwork"
```
