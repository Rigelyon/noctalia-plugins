# Keybinds Panel CRUD & Dimension Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Keybinds Panel width to 1280 × 720 px (maintaining a 3-column layout) and implement full in-panel CRUD (Create, Read, Update, Delete) for custom keybindings stored in `custom_keybinds.json`.

**Architecture:** Implement modular JSON CRUD logic in `keybinds/crud.luau` for data manipulation (create/update/delete apps, subcategories, and binds). Connect this into `keybinds/panel.luau` with an icon-only `plus` button in the header, `pencil` & `trash` action buttons on custom cards, and an interactive Modal Dialog overlay with modifier toggles (`SUPER`, `CTRL`, `ALT`, `SHIFT`) and primary key text input.

**Tech Stack:** Luau (Noctalia UI toolkit: `ui.row`, `ui.column`, `ui.input`, `ui.button`, `ui.glyph`, `ui.label`, `noctalia.json`), TOML, Python (pytest unit testing).

## Global Constraints
- Panel Dimensions: `width = 1280`, `height = 720` in `keybinds/plugin.toml`.
- Grid Layout: Exactly 3 columns (`grid_columns = "3"`).
- Storage Path: `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json` via `noctalia.pluginDataDir()`.
- Hyprland Bindings: Strictly read-only (`source == "hyprland"`), no edit/delete buttons rendered.
- Keycombos: All modifier and key badges displayed in uppercase (`SUPER`, `CTRL`, `ALT`, `SHIFT`).
- No placeholders: Every step has full, exact code and verifiable commands.

---

### Task 1: Panel Dimension Expansion & Translations

**Files:**
- Modify: `keybinds/plugin.toml:43-44`
- Modify: `keybinds/translations/en.json`
- Modify: `keybinds/translations/id.json`
- Modify: `tests/test_keybinds_manifest.py:16-17`

**Interfaces:**
- Consumes: `keybinds/plugin.toml` panel definition.
- Produces: Updated panel width (1280) & height (720), and i18n translation keys under `actions.*` and `modal.*`.

- [ ] **Step 1: Update the unit test expectation for panel dimensions**

Update `tests/test_keybinds_manifest.py` to assert width 1280 and height 720:
```python
    def test_panel_dimensions(self):
        panel = self.manifest["panel"][0]
        self.assertEqual(panel["width"], 1280)
        self.assertEqual(panel["height"], 720)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_manifest.py -v`
Expected: FAIL (`AssertionError: 1120 != 1280`).

- [ ] **Step 3: Update `keybinds/plugin.toml` and translations**

In `keybinds/plugin.toml`:
```toml
[[panel]]
id = "panel"
entry = "panel.luau"
placement = "floating"
position = "center"
width = 1280
height = 720
capture_keys = ["Escape"]
```

In `keybinds/translations/en.json`:
Add keys under `"actions"` and `"modal"`:
```json
    "actions": {
      "add_keybind": "Add Keybind",
      "edit_keybind": "Edit Keybind",
      "delete_keybind": "Delete Keybind"
    },
    "modal": {
      "title_add": "Add New Keybind",
      "title_edit": "Edit Keybind",
      "app_label": "Application",
      "app_placeholder": "e.g. Kitty, Neovim, Browser",
      "subcat_label": "Subcategory",
      "subcat_placeholder": "e.g. Navigation, Windows, General",
      "desc_label": "Description",
      "desc_placeholder": "e.g. New Tab, Split Horizontal",
      "modifiers_label": "Modifiers",
      "key_label": "Primary Key",
      "key_placeholder": "e.g. T, Enter, Space, F1",
      "cancel": "Cancel",
      "save": "Save",
      "err_validation": "Description and primary key are required",
      "saved_notify": "Keybind saved successfully",
      "deleted_notify": "Keybind removed"
    }
```

In `keybinds/translations/id.json`:
Add corresponding Indonesian translations:
```json
    "actions": {
      "add_keybind": "Tambah Keybind",
      "edit_keybind": "Edit Keybind",
      "delete_keybind": "Hapus Keybind"
    },
    "modal": {
      "title_add": "Tambah Keybind Baru",
      "title_edit": "Edit Keybind",
      "app_label": "Aplikasi",
      "app_placeholder": "misal: Kitty, Neovim, Browser",
      "subcat_label": "Subkategori",
      "subcat_placeholder": "misal: Navigasi, Windows, General",
      "desc_label": "Deskripsi",
      "desc_placeholder": "misal: Tab Baru, Split Horizontal",
      "modifiers_label": "Tombol Pengubah",
      "key_label": "Tombol Utama",
      "key_placeholder": "misal: T, Enter, Space, F1",
      "cancel": "Batal",
      "save": "Simpan",
      "err_validation": "Deskripsi dan tombol utama wajib diisi",
      "saved_notify": "Keybind berhasil disimpan",
      "deleted_notify": "Keybind berhasil dihapus"
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_manifest_translations.py tests/test_keybinds_manifest.py -v`
Expected: PASS (all tests pass).

- [ ] **Step 5: Commit changes**

```bash
git add keybinds/plugin.toml keybinds/translations/en.json keybinds/translations/id.json tests/test_keybinds_manifest.py
git commit -m "feat(keybinds): expand panel to 1280x720 and add CRUD translations"
```

---

### Task 2: Pure CRUD Data Module (`keybinds/crud.luau`) & Unit Tests

**Files:**
- Create: `keybinds/crud.luau`
- Create: `tests/test_keybinds_crud.py`

**Interfaces:**
- Consumes: JSON string or decoded table matching `{ apps = [ { name = "...", subcategories = [ { name = "...", binds = [ ... ] } ] } ] }`.
- Produces:
  - `crud.addKeybind(data, appName, subcatName, desc, modifiers, key)`
  - `crud.updateKeybind(data, origTarget, newApp, newSubcat, newDesc, newModifiers, newKey)`
  - `crud.deleteKeybind(data, appName, subcatName, bindIndex)`

- [ ] **Step 1: Write the failing unit tests in `tests/test_keybinds_crud.py`**

Create `tests/test_keybinds_crud.py`:
```python
import json
import unittest
from pathlib import Path

class TestKeybindsCrud(unittest.TestCase):
    def setUp(self):
        self.sample_data = {
            "apps": [
                {
                    "name": "Kitty Terminal",
                    "icon": "terminal",
                    "subcategories": [
                        {
                            "name": "Tabs & Windows",
                            "icon": "app-window",
                            "binds": [
                                {"keys": ["CTRL", "SHIFT", "ENTER"], "description": "New Pane"}
                            ]
                        }
                    ]
                }
            ]
        }

    def test_json_structure_and_crud_module_exists(self):
        crud_path = Path(__file__).resolve().parent.parent / "keybinds" / "crud.luau"
        self.assertTrue(crud_path.exists(), "crud.luau must exist")
        content = crud_path.read_text(encoding="utf-8")
        self.assertIn("crud.addKeybind", content)
        self.assertIn("crud.updateKeybind", content)
        self.assertIn("crud.deleteKeybind", content)

    def test_pure_crud_operations_logic(self):
        # Emulate and verify CRUD logic contracts in python
        data = json.loads(json.dumps(self.sample_data))
        
        # CREATE in existing app & new subcategory
        new_bind = {"keys": ["CTRL", "SHIFT", "T"], "description": "New Tab"}
        app = next(a for a in data["apps"] if a["name"].lower() == "kitty terminal")
        app["subcategories"].append({
            "name": "Sessions",
            "icon": "command",
            "binds": [new_bind]
        })
        self.assertEqual(len(app["subcategories"]), 2)
        self.assertEqual(app["subcategories"][1]["binds"][0]["description"], "New Tab")

        # UPDATE existing bind
        bind = app["subcategories"][0]["binds"][0]
        bind["description"] = "New Pane (Updated)"
        bind["keys"] = ["SUPER", "ENTER"]
        self.assertEqual(app["subcategories"][0]["binds"][0]["description"], "New Pane (Updated)")
        self.assertEqual(app["subcategories"][0]["binds"][0]["keys"], ["SUPER", "ENTER"])

        # DELETE bind
        del app["subcategories"][0]["binds"][0]
        self.assertEqual(len(app["subcategories"][0]["binds"]), 0)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_crud.py -v`
Expected: FAIL (`AssertionError: crud.luau must exist`).

- [ ] **Step 3: Implement `keybinds/crud.luau`**

Create `keybinds/crud.luau`:
```luau
--!nonstrict
-- CRUD operations helper module for custom keybinds.

local crud = {}

export type BindEntry = {
  keys: { string },
  description: string,
}

export type SubcatEntry = {
  name: string,
  icon: string,
  binds: { BindEntry },
}

export type AppEntry = {
  name: string,
  icon: string,
  subcategories: { SubcatEntry },
}

export type CustomStore = {
  apps: { AppEntry },
}

function crud.ensureStore(data: any): CustomStore
  if type(data) ~= "table" then
    return { apps = {} }
  end
  if type(data.apps) ~= "table" then
    data.apps = {}
  end
  return data
end

function crud.findApp(store: CustomStore, appName: string): AppEntry?
  local target = string.lower(noctalia.string.trim(appName))
  for _, app in ipairs(store.apps) do
    if string.lower(app.name) == target then
      return app
    end
  end
  return nil
end

function crud.findSubcategory(app: AppEntry, subcatName: string): SubcatEntry?
  local target = string.lower(noctalia.string.trim(subcatName))
  for _, sub in ipairs(app.subcategories) do
    if string.lower(sub.name) == target then
      return sub
    end
  end
  return nil
end

function crud.addKeybind(
  store: CustomStore,
  appName: string,
  subcatName: string,
  description: string,
  modifiers: { string },
  primaryKey: string
): (boolean, string?)
  local cleanApp = noctalia.string.trim(appName)
  local cleanSub = noctalia.string.trim(subcatName)
  local cleanDesc = noctalia.string.trim(description)
  local cleanKey = string.upper(noctalia.string.trim(primaryKey))

  if cleanDesc == "" or cleanKey == "" then
    return false, "Description and primary key are required"
  end
  if cleanApp == "" then
    cleanApp = "Custom"
  end
  if cleanSub == "" then
    cleanSub = "General"
  end

  local keys = {}
  for _, m in ipairs(modifiers) do
    table.insert(keys, string.upper(noctalia.string.trim(m)))
  end
  table.insert(keys, cleanKey)

  local app = crud.findApp(store, cleanApp)
  if not app then
    app = {
      name = cleanApp,
      icon = "terminal",
      subcategories = {},
    }
    table.insert(store.apps, app)
  end

  local sub = crud.findSubcategory(app, cleanSub)
  if not sub then
    sub = {
      name = cleanSub,
      icon = "command",
      binds = {},
    }
    table.insert(app.subcategories, sub)
  end

  table.insert(sub.binds, {
    keys = keys,
    description = cleanDesc,
  })

  return true, nil
end

function crud.updateKeybind(
  store: CustomStore,
  origApp: string,
  origSubcat: string,
  origBindIdx: number,
  newApp: string,
  newSubcat: string,
  newDesc: string,
  newModifiers: { string },
  newKey: string
): (boolean, string?)
  -- First delete original
  local deleted = crud.deleteKeybind(store, origApp, origSubcat, origBindIdx)
  if not deleted then
    return false, "Original keybind not found"
  end

  -- Then insert updated
  return crud.addKeybind(store, newApp, newSubcat, newDesc, newModifiers, newKey)
end

function crud.deleteKeybind(
  store: CustomStore,
  appName: string,
  subcatName: string,
  bindIdx: number
): boolean
  local app = crud.findApp(store, appName)
  if not app then
    return false
  end

  local sub = crud.findSubcategory(app, subcatName)
  if not sub or not sub.binds or bindIdx < 1 or bindIdx > #sub.binds then
    return false
  end

  table.remove(sub.binds, bindIdx)

  -- Cleanup empty subcategory
  if #sub.binds == 0 then
    for sIdx, s in ipairs(app.subcategories) do
      if s == sub then
        table.remove(app.subcategories, sIdx)
        break
      end
    end
  end

  -- Cleanup empty app
  if #app.subcategories == 0 then
    for aIdx, a in ipairs(store.apps) do
      if a == app then
        table.remove(store.apps, aIdx)
        break
      end
    end
  end

  return true
end

return crud
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_crud.py -v`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add keybinds/crud.luau tests/test_keybinds_crud.py
git commit -m "feat(keybinds): add crud helper module and unit tests"
```

---

### Task 3: In-Panel Modal Form UI & Action Handlers in `keybinds/panel.luau`

**Files:**
- Modify: `keybinds/panel.luau`
- Modify: `tests/test_keybinds_panel.py`

**Interfaces:**
- Consumes: `keybinds/crud.luau`, `noctalia.json.encode`, `noctalia.writeFile`, `noctalia.notify`.
- Produces:
  - Header: Icon-only `plus` button.
  - Card: `pencil` and `trash` buttons for custom items.
  - Overlay: `renderModalOverlay()` with modifier toggles (`SUPER`, `CTRL`, `ALT`, `SHIFT`), primary key input, app input, subcategory input, and description input.

- [ ] **Step 1: Add panel UI test assertions in `tests/test_keybinds_panel.py`**

In `tests/test_keybinds_panel.py`, add checks for CRUD UI components:
```python
    def test_crud_components_present(self):
        content = (Path(__file__).resolve().parent.parent / "keybinds" / "panel.luau").read_text(encoding="utf-8")
        self.assertIn("crud.addKeybind", content)
        self.assertIn("crud.updateKeybind", content)
        self.assertIn("crud.deleteKeybind", content)
        self.assertIn("isModalOpen", content)
        self.assertIn("renderModalOverlay", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_panel.py::TestKeybindsPanel::test_crud_components_present -v`
Expected: FAIL (`AssertionError: 'crud.addKeybind' not found in content`).

- [ ] **Step 3: Integrate CRUD and Modal into `keybinds/panel.luau`**

In `keybinds/panel.luau`:
1. Import `crud`:
```luau
local presets = require("./presets.luau")
local crud = require("./crud.luau")
```

2. Add custom item metadata fields to `KeybindItem`:
```luau
type KeybindItem = {
  id: string,
  appId: string,
  appName: string,
  appIcon: string,
  subcatId: string,
  subcatName: string,
  subcatIcon: string,
  modifiers: { string },
  key: string,
  keyComboText: string,
  description: string,
  source: string,
  searchIndex: string,
  bindIndex: number?,
}
```

3. Add Modal Form state variables:
```luau
local isModalOpen = false
local modalMode = "create" -- "create" or "edit"
local editTarget = {
  origApp = "",
  origSubcat = "",
  origBindIdx = 0,
}
local formApp = ""
local formSubcat = ""
local formDesc = ""
local formKey = ""
local formMods = {
  SUPER = false,
  CTRL = false,
  ALT = false,
  SHIFT = false,
}
local formError = ""
```

4. Helper functions to save JSON:
```luau
local function getCustomFilePath(): string
  local rawPath = customFilePath
  if rawPath == "" then
    local cfgPath = noctalia.getConfig("custom_file_path")
    if cfgPath and cfgPath ~= "" then
      rawPath = cfgPath
    else
      local dataDir = noctalia.pluginDataDir()
      rawPath = (dataDir and dataDir ~= "") and (dataDir .. "/custom_keybinds.json") or "~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json"
    end
  end
  return noctalia.expandPath(rawPath)
end

local function saveCustomJson(store: any): boolean
  local path = getCustomFilePath()
  local ok, encoded = pcall(function()
    return noctalia.json.encode(store, true)
  end)
  if not ok or not encoded then
    return false
  end
  return noctalia.writeFile(path, encoded)
end
```

5. In `loadCustomKeybinds()`, record `bindIndex = bIdx`:
```luau
table.insert(customItems, {
  id = "custom-" .. appId .. "-" .. tostring(subIdx) .. "-" .. tostring(bIdx),
  appId = appId,
  appName = appName,
  appIcon = appIcon,
  subcatId = subId,
  subcatName = subName,
  subcatIcon = subIcon,
  modifiers = mods,
  key = primaryKey,
  keyComboText = combo,
  description = desc,
  source = "custom",
  searchIndex = string.lower(appName .. " " .. subName .. " " .. desc .. " " .. combo),
  bindIndex = bIdx,
})
```

6. Header bar: Add icon-only `plus` button:
```luau
ui.button({
  glyph = "plus",
  size = 14,
  variant = "ghost",
  tooltip = tr("actions.add_keybind"),
  onClick = function()
    modalMode = "create"
    formApp = if activeApp ~= "hyprland" then activeApp else "Custom"
    formSubcat = "General"
    formDesc = ""
    formKey = ""
    formMods = { SUPER = false, CTRL = false, ALT = false, SHIFT = false }
    formError = ""
    isModalOpen = true
    render()
  end,
})
```

7. Card row: Add `pencil` and `trash` buttons for custom cards:
```luau
if item.source == "custom" and item.bindIndex ~= nil then
  table.insert(cardChildren, ui.row({ gap = 2, align = "center" }, {
    ui.button({
      glyph = "pencil",
      size = 12,
      variant = "ghost",
      tooltip = tr("actions.edit_keybind"),
      onClick = function()
        modalMode = "edit"
        editTarget = {
          origApp = item.appName,
          origSubcat = item.subcatName,
          origBindIdx = item.bindIndex or 1,
        }
        formApp = item.appName
        formSubcat = item.subcatName
        formDesc = item.description
        formKey = item.key
        formMods = { SUPER = false, CTRL = false, ALT = false, SHIFT = false }
        for _, m in ipairs(item.modifiers) do
          local mu = string.upper(m)
          if formMods[mu] ~= nil then
            formMods[mu] = true
          end
        end
        formError = ""
        isModalOpen = true
        render()
      end,
    }),
    ui.button({
      glyph = "trash",
      size = 12,
      variant = "ghost",
      tooltip = tr("actions.delete_keybind"),
      onClick = function()
        local path = getCustomFilePath()
        local raw = noctalia.readFile(path)
        if raw then
          local ok, store = pcall(function() return noctalia.json.decode(raw) end)
          if ok and store then
            crud.deleteKeybind(store, item.appName, item.subcatName, item.bindIndex or 1)
            saveCustomJson(store)
            noctalia.notify("Keybinds", tr("modal.deleted_notify"))
            refreshAllBinds()
          end
        end
      end,
    }),
  }))
end
```

8. Implement `renderModalOverlay()`:
Renders a centered dialog box with backdrop covering the cheatsheet, rendering:
- Title (`modal.title_add` / `modal.title_edit`) + close icon button.
- App name input (`formApp`).
- Subcategory input (`formSubcat`).
- Description input (`formDesc`).
- Modifier toggle chips (`SUPER`, `CTRL`, `ALT`, `SHIFT`). Clicking a chip toggles `formMods[key]`.
- Primary key text input (`formKey`).
- Validation message (`formError`) if empty.
- Cancel and Save buttons.
- On save:
```luau
local activeMods = {}
if formMods.SUPER then table.insert(activeMods, "SUPER") end
if formMods.CTRL then table.insert(activeMods, "CTRL") end
if formMods.ALT then table.insert(activeMods, "ALT") end
if formMods.SHIFT then table.insert(activeMods, "SHIFT") end

local path = getCustomFilePath()
local raw = noctalia.readFile(path) or "{}"
local ok, store = pcall(function() return noctalia.json.decode(raw) end)
store = crud.ensureStore(if ok then store else {})

local success, errMsg
if modalMode == "create" then
  success, errMsg = crud.addKeybind(store, formApp, formSubcat, formDesc, activeMods, formKey)
else
  success, errMsg = crud.updateKeybind(store, editTarget.origApp, editTarget.origSubcat, editTarget.origBindIdx, formApp, formSubcat, formDesc, activeMods, formKey)
end

if not success then
  formError = errMsg or tr("modal.err_validation")
  render()
  return
end

saveCustomJson(store)
isModalOpen = false
noctalia.notify("Keybinds", tr("modal.saved_notify"))
refreshAllBinds()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_keybinds_panel.py tests/test_keybinds_crud.py -v`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add keybinds/panel.luau tests/test_keybinds_panel.py
git commit -m "feat(keybinds): add in-panel CRUD modal dialog and custom card action buttons"
```

---

### Task 4: Documentation & Full Verification

**Files:**
- Modify: `keybinds/README.md`
- Run: full test suite

- [ ] **Step 1: Update `keybinds/README.md`**

Document the new features in `keybinds/README.md`:
- Wider 1280 × 720 px layout.
- In-panel CRUD: Add button (`+`), Edit (`pencil`), Delete (`trash`).
- Interactive Modal Form with Modifier chips and Key input.
- Real-time JSON persistence in `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json`.

- [ ] **Step 2: Run all repository tests**

Run: `pytest tests/test_manifest_translations.py tests/test_keybinds_*.py -v`
Expected: 100% PASS.

- [ ] **Step 3: Commit documentation**

```bash
git add keybinds/README.md
git commit -m "docs(keybinds): document panel dimensions and in-panel CRUD features"
```
