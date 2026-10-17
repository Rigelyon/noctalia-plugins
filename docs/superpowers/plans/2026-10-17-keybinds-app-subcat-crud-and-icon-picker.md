# Keybinds App/Subcategory CRUD and Icon Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement robust Application and Subcategory management with `ui.select` dropdowns, an interactive Lucide Icon Picker modal, in-place editing in Edit Mode, and pure CRUD helpers.

**Architecture:** Pure logic is implemented and tested in `keybinds/crud.luau` (`renameApp`, `renameSubcategory`, enhanced `addKeybind`/`updateKeybind`). The UI in `keybinds/panel.luau` provides a reusable `renderIconPickerOverlay()` component, updates the Add/Edit Keybind modal to use `ui.select` with dynamic `+ New` inputs, and adds quick edit buttons to custom app tabs and subcategory headers when Edit Mode is active.

**Tech Stack:** Luau (Noctalia Plugin API), JSON, Python / Pytest for testing.

## Global Constraints
- Noctalia `ui.select` uses 0-based indexing for `selectedIndex` and `onChange`.
- Noctalia `ui.glyph` renders Lucide icon names (e.g. `terminal`, `code`, `command`, `app-window`).
- Default icon for new app is `"terminal"`. Default icon for new subcategory is `"command"`.
- Backward-compatible schema in `custom_keybinds.json`. No external network dependencies.
- Natural sorting and 3-column top-to-bottom layout must remain completely functional.

---

### Task 1: Extend `keybinds/crud.luau` with `renameApp`, `renameSubcategory`, and Custom Icons

**Files:**
- Modify: `keybinds/crud.luau`
- Test: `tests/test_keybinds_crud.py`

**Interfaces:**
- Consumes: `CustomStore`, `AppEntry`, `SubcatEntry`, `BindEntry` in `keybinds/crud.luau`
- Produces:
  - `crud.addKeybind(store, appName, subcatName, desc, mods, primaryKey, appIcon?, subcatIcon?) -> (boolean, string?)`
  - `crud.updateKeybind(store, origApp, origSubcat, origBindIdx, newApp, newSubcat, newDesc, newMods, newKey, newAppIcon?, newSubcatIcon?) -> (boolean, string?)`
  - `crud.renameApp(store, oldName, newName, newIcon?) -> (boolean, string?)`
  - `crud.renameSubcategory(store, appName, oldSubcatName, newSubcatName, newIcon?) -> (boolean, string?)`

- [ ] **Step 1: Write the failing tests in `tests/test_keybinds_crud.py`**

Add tests for `renameApp`, `renameSubcategory`, and custom icon creation:
```python
def test_rename_app_success():
    script = """
    local crud = require("./keybinds/crud")
    local store = {
        apps = {
            {
                name = "Kitty",
                icon = "terminal",
                subcategories = {
                    { name = "General", icon = "command", binds = { { keys = {"SUPER"}, description = "test" } } }
                }
            }
        }
    }
    local ok, err = crud.renameApp(store, "Kitty", "Ghostty", "sparkles")
    assert(ok == true, "Expected renameApp to succeed")
    assert(store.apps[1].name == "Ghostty", "Expected name to be Ghostty")
    assert(store.apps[1].icon == "sparkles", "Expected icon to be sparkles")
    assert(#store.apps[1].subcategories == 1, "Expected subcategories to remain intact")
    print("PASS")
    """
    assert run_luau(script) == "PASS"

def test_rename_app_duplicate_prevented():
    script = """
    local crud = require("./keybinds/crud")
    local store = {
        apps = {
            { name = "Kitty", icon = "terminal", subcategories = {} },
            { name = "Ghostty", icon = "terminal", subcategories = {} }
        }
    }
    local ok, err = crud.renameApp(store, "Kitty", "Ghostty")
    assert(ok == false, "Expected renameApp to fail due to duplicate name")
    print("PASS")
    """
    assert run_luau(script) == "PASS"

def test_rename_subcategory_success():
    script = """
    local crud = require("./keybinds/crud")
    local store = {
        apps = {
            {
                name = "Kitty",
                icon = "terminal",
                subcategories = {
                    { name = "Tabs", icon = "command", binds = { { keys = {"SUPER", "T"}, description = "New tab" } } }
                }
            }
        }
    }
    local ok, err = crud.renameSubcategory(store, "Kitty", "Tabs", "Panes", "layout-grid")
    assert(ok == true, "Expected renameSubcategory to succeed")
    assert(store.apps[1].subcategories[1].name == "Panes", "Expected subcat name to be Panes")
    assert(store.apps[1].subcategories[1].icon == "layout-grid", "Expected subcat icon to be layout-grid")
    assert(#store.apps[1].subcategories[1].binds == 1, "Expected binds intact")
    print("PASS")
    """
    assert run_luau(script) == "PASS"

def test_add_keybind_custom_icons():
    script = """
    local crud = require("./keybinds/crud")
    local store = { apps = {} }
    local ok, err = crud.addKeybind(store, "Zed", "Editing", "Save", {"CTRL"}, "S", "code", "file-text")
    assert(ok == true, "Expected addKeybind to succeed")
    assert(store.apps[1].name == "Zed")
    assert(store.apps[1].icon == "code", "Expected custom app icon")
    assert(store.apps[1].subcategories[1].icon == "file-text", "Expected custom subcat icon")
    print("PASS")
    """
    assert run_luau(script) == "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_crud.py -k "rename or custom_icons" -v`
Expected: FAIL with `crud.renameApp is not a function` or similar.

- [ ] **Step 3: Implement changes in `keybinds/crud.luau`**

Update `keybinds/crud.luau`:
- In `crud.addKeybind`: accept `appIcon?: string?, subcatIcon?: string?` and use them when creating `app` or `sub`:
  ```luau
  if not app then
    app = {
      name = cleanApp,
      icon = if appIcon and safeTrim(appIcon) ~= "" then safeTrim(appIcon) else "terminal",
      subcategories = {},
    }
    table.insert(store.apps, app)
  end

  local sub = crud.findSubcategory(app, cleanSub)
  if not sub then
    sub = {
      name = cleanSub,
      icon = if subcatIcon and safeTrim(subcatIcon) ~= "" then safeTrim(subcatIcon) else "command",
      binds = {},
    }
    table.insert(app.subcategories, sub)
  end
  ```
- Implement `crud.renameApp`:
  ```luau
  function crud.renameApp(store: CustomStore, oldName: string, newName: string, newIcon: string?): (boolean, string?)
    local app = crud.findApp(store, oldName)
    if not app then
      return false, "Application not found"
    end
    local cleanNew = safeTrim(newName)
    if cleanNew == "" then
      return false, "Application name cannot be empty"
    end
    if string.lower(cleanNew) ~= string.lower(app.name) then
      local existing = crud.findApp(store, cleanNew)
      if existing then
        return false, "An application with this name already exists"
      end
    end
    app.name = cleanNew
    if newIcon and safeTrim(newIcon) ~= "" then
      app.icon = safeTrim(newIcon)
    end
    return true, nil
  end
  ```
- Implement `crud.renameSubcategory`:
  ```luau
  function crud.renameSubcategory(store: CustomStore, appName: string, oldSubcatName: string, newSubcatName: string, newIcon: string?): (boolean, string?)
    local app = crud.findApp(store, appName)
    if not app then
      return false, "Application not found"
    end
    local sub = crud.findSubcategory(app, oldSubcatName)
    if not sub then
      return false, "Subcategory not found"
    end
    local cleanNew = safeTrim(newSubcatName)
    if cleanNew == "" then
      return false, "Subcategory name cannot be empty"
    end
    if string.lower(cleanNew) ~= string.lower(sub.name) then
      local existing = crud.findSubcategory(app, cleanNew)
      if existing then
        return false, "A subcategory with this name already exists in this application"
      end
    end
    sub.name = cleanNew
    if newIcon and safeTrim(newIcon) ~= "" then
      sub.icon = safeTrim(newIcon)
    end
    return true, nil
  end
  ```
- In `crud.updateKeybind`: pass `newAppIcon` and `newSubcatIcon` to `crud.addKeybind`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_keybinds_crud.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/crud.luau tests/test_keybinds_crud.py
git commit -m "feat(keybinds): add renameApp, renameSubcategory, and custom icons to crud module"
```

---

### Task 2: Add Translations for Icon Picker & App/Subcat Management

**Files:**
- Modify: `keybinds/translations/en.json`
- Modify: `keybinds/translations/id.json`
- Test: `tests/test_manifest_translations.py`

**Interfaces:**
- Produces: translation keys for `modal.app_new_option`, `modal.subcat_new_option`, `modal.pick_icon`, `modal.icon_picker_title`, `modal.icon_search_placeholder`, `modal.category_*`, `modal.edit_app_title`, `modal.edit_subcat_title`, `modal.err_duplicate_app`, `modal.err_duplicate_subcat`.

- [ ] **Step 1: Add new keys to `keybinds/translations/en.json`**

```json
{
  "modal": {
    "app_new_option": "+ Add New Application...",
    "subcat_new_option": "+ Add New Subcategory...",
    "pick_icon": "Choose Icon",
    "icon_picker_title": "Choose Icon",
    "icon_search_placeholder": "Search icon name...",
    "category_all": "All",
    "category_dev": "Dev",
    "category_system": "System",
    "category_media": "Media",
    "category_navigation": "Navigation",
    "category_files": "Files",
    "category_tools": "Tools",
    "edit_app_title": "Edit Application",
    "edit_subcat_title": "Edit Subcategory",
    "err_duplicate_app": "An application with this name already exists",
    "err_duplicate_subcat": "A subcategory with this name already exists"
  }
}
```

- [ ] **Step 2: Add matching keys to `keybinds/translations/id.json`**

```json
{
  "modal": {
    "app_new_option": "+ Tambah Aplikasi Baru...",
    "subcat_new_option": "+ Tambah Subkategori Baru...",
    "pick_icon": "Pilih Icon",
    "icon_picker_title": "Pilih Icon",
    "icon_search_placeholder": "Cari nama icon...",
    "category_all": "Semua",
    "category_dev": "Dev",
    "category_system": "Sistem",
    "category_media": "Media",
    "category_navigation": "Navigasi",
    "category_files": "Berkas",
    "category_tools": "Alat",
    "edit_app_title": "Edit Aplikasi",
    "edit_subcat_title": "Edit Subkategori",
    "err_duplicate_app": "Aplikasi dengan nama ini sudah ada",
    "err_duplicate_subcat": "Subkategori dengan nama ini sudah ada"
  }
}
```

- [ ] **Step 3: Run translation parity test**

Run: `pytest tests/test_manifest_translations.py -v`
Expected: PASS with 100% key match.

- [ ] **Step 4: Commit**

```bash
git add keybinds/translations/en.json keybinds/translations/id.json
git commit -m "i18n(keybinds): add translations for icon picker and app/subcat management"
```

---

### Task 3: Implement Curated Icon Catalog & `renderIconPickerOverlay` in `keybinds/panel.luau`

**Files:**
- Modify: `keybinds/panel.luau`
- Test: `tests/test_keybinds_panel.py`

**Interfaces:**
- Produces:
  - `ICON_CATEGORIES`: table mapping category IDs to list of Lucide icon names
  - `openIconPicker(initialIcon: string, onSelect: (icon: string) -> ())`
  - `closeIconPicker()`
  - `renderIconPickerOverlay(): any`

- [ ] **Step 1: Write tests in `tests/test_keybinds_panel.py`**

Verify that `panel.luau` defines the icon catalog and `renderIconPickerOverlay`:
```python
def test_icon_picker_defined():
    with open("keybinds/panel.luau", "r", encoding="utf-8") as f:
        content = f.read()
    assert "renderIconPickerOverlay" in content, "renderIconPickerOverlay function must be defined"
    assert "ICON_CATALOG" in content or "ICON_CATEGORIES" in content, "Icon catalog must be defined"
    assert "openIconPicker" in content, "openIconPicker must be defined"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_panel.py -k "icon_picker" -v`
Expected: FAIL.

- [ ] **Step 3: Implement icon catalog and `renderIconPickerOverlay` in `keybinds/panel.luau`**

Define icon catalog table:
```luau
local ICON_CATEGORIES = {
  { id = "all", labelKey = "modal.category_all" },
  { id = "dev", labelKey = "modal.category_dev", icons = { "terminal", "code", "command", "cpu", "database", "server", "git-branch", "bug", "braces", "play", "package", "layers" } },
  { id = "system", labelKey = "modal.category_system", icons = { "app-window", "monitor", "settings", "sliders", "power", "maximize", "minimize", "shield", "bell", "wifi", "sun", "moon", "lock" } },
  { id = "media", labelKey = "modal.category_media", icons = { "music", "video", "volume-2", "volume-x", "camera", "image", "play", "pause", "disc", "mic", "headphones" } },
  { id = "navigation", labelKey = "modal.category_navigation", icons = { "globe", "search", "bookmark", "compass", "external-link", "link", "map", "send", "home" } },
  { id = "files", labelKey = "modal.category_files", icons = { "file-text", "folder", "clipboard", "typography", "file-code", "book-open", "archive", "paperclip" } },
  { id = "tools", labelKey = "modal.category_tools", icons = { "sparkles", "star", "tool", "key", "keyboard", "zap", "flag", "tag", "activity", "layout-grid" } },
}
```

Add state:
```luau
local isIconPickerOpen = false
local iconPickerSearch = ""
local iconPickerCategory = "all"
local iconPickerCurrent = ""
local iconPickerCallback: ((string) -> ())? = nil

local function openIconPicker(current: string, callback: (string) -> ())
  isIconPickerOpen = true
  iconPickerSearch = ""
  iconPickerCategory = "all"
  iconPickerCurrent = current or "terminal"
  iconPickerCallback = callback
  render()
end

local function closeIconPicker()
  isIconPickerOpen = false
  iconPickerCallback = nil
  render()
end
```

Implement `renderIconPickerOverlay`:
- Search input
- Category buttons
- Grid of 8 columns with `ui.row` and `ui.button` / `ui.box` with `ui.glyph`
- On click: call callback and `closeIconPicker()`

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_panel.py -k "icon_picker" -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/panel.luau tests/test_keybinds_panel.py
git commit -m "feat(keybinds): add icon catalog and renderIconPickerOverlay component"
```

---

### Task 4: Upgrade Add/Edit Keybind Modal to Use `ui.select` and Dynamic `+ New` Inputs with Icon Picker

**Files:**
- Modify: `keybinds/panel.luau`
- Test: `tests/test_keybinds_panel.py`

**Interfaces:**
- Consumes: `crud.ensureStore`, `crud.addKeybind`, `crud.updateKeybind`, `openIconPicker`
- Form State:
  - `formAppSelectedIdx`: number
  - `formAppIsNew`: boolean
  - `formApp`: string
  - `formAppIcon`: string
  - `formSubcatSelectedIdx`: number
  - `formSubcatIsNew`: boolean
  - `formSubcat`: string
  - `formSubcatIcon`: string

- [ ] **Step 1: Write test in `tests/test_keybinds_panel.py`**

```python
def test_modal_uses_select_dropdowns():
    with open("keybinds/panel.luau", "r", encoding="utf-8") as f:
        content = f.read()
    assert "modal.app_new_option" in content, "Modal must support + New App option"
    assert "modal.subcat_new_option" in content, "Modal must support + New Subcategory option"
    assert "ui.select" in content, "Modal must use ui.select for apps and subcategories"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_panel.py -k "modal_uses_select" -v`
Expected: FAIL.

- [ ] **Step 3: Implement `ui.select` and dynamic inputs in `renderModalOverlay`**

In `keybinds/panel.luau`:
- Extract list of available custom apps from `custom_keybinds.json` store:
  - Populate `appOptions` table: `{ "AppName1", "AppName2", ..., tr("modal.app_new_option") }`.
  - When an existing app is selected, populate `subcatOptions`: `{ "Subcat1", "Subcat2", ..., tr("modal.subcat_new_option") }`.
  - If `formAppIsNew` is true, display name input + icon button with tooltip `tr("modal.pick_icon")`. Clicking icon button triggers `openIconPicker(formAppIcon, function(newIcon) formAppIcon = newIcon; render() end)`.
  - If `formSubcatIsNew` is true, display subcategory name input + icon button with tooltip `tr("modal.pick_icon")`. Clicking icon button triggers `openIconPicker(formSubcatIcon, function(newIcon) formSubcatIcon = newIcon; render() end)`.
- When form saves:
  - Pass `formAppIcon` and `formSubcatIcon` into `crud.addKeybind` or `crud.updateKeybind`.
- In `render()`:
  - If `isIconPickerOpen`, layer `renderIconPickerOverlay()` over or replace content.

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_keybinds_panel.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/panel.luau tests/test_keybinds_panel.py
git commit -m "feat(keybinds): implement ui.select and icon picker in keybind modal"
```

---

### Task 5: Add In-Place Edit Buttons for App Tab & Subcategory Headers in Edit Mode

**Files:**
- Modify: `keybinds/panel.luau`
- Test: `tests/test_keybinds_panel.py`

**Interfaces:**
- Produces:
  - Edit button on active custom tab bar node when `isEditMode == true`
  - Edit button on custom subcategory section header when `isEditMode == true`
  - Modal rendering for `modalMode == "edit_app"` and `modalMode == "edit_subcat"`

- [ ] **Step 1: Write test in `tests/test_keybinds_panel.py`**

```python
def test_inplace_app_and_subcat_edit():
    with open("keybinds/panel.luau", "r", encoding="utf-8") as f:
        content = f.read()
    assert 'modalMode == "edit_app"' in content or 'modalMode == \\"edit_app\\"' in content, "edit_app modal mode required"
    assert 'modalMode == "edit_subcat"' in content or 'modalMode == \\"edit_subcat\\"' in content, "edit_subcat modal mode required"
    assert "crud.renameApp" in content, "renameApp must be invoked in panel.luau"
    assert "crud.renameSubcategory" in content, "renameSubcategory must be invoked in panel.luau"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_panel.py -k "inplace" -v`
Expected: FAIL.

- [ ] **Step 3: Implement in-place edit buttons and modals**

In `keybinds/panel.luau`:
- In `renderTabs()`:
  - For custom apps, if `isEditMode` is true and this is the active tab, render a small ghost button with glyph `"pencil"` next to the tab label.
  - Clicking sets `modalMode = "edit_app"`, `editAppName = app.name`, `editAppIcon = app.icon`, `isModalOpen = true`, and re-renders.
- In `renderSectionHeader()`:
  - If `isCustom` is true and `isEditMode` is true, render a small ghost button with glyph `"pencil"` next to the title.
  - Clicking sets `modalMode = "edit_subcat"`, `editSubcatName = grp.title`, `editSubcatIcon = grp.icon`, `isModalOpen = true`, and re-renders.
- In `renderModalOverlay()`:
  - If `modalMode == "edit_app"`:
    - Title: `tr("modal.edit_app_title")`
    - Input: `editAppName`
    - Icon preview button calling `openIconPicker`
    - Save button calling `crud.renameApp(...)` and saving JSON.
  - If `modalMode == "edit_subcat"`:
    - Title: `tr("modal.edit_subcat_title")`
    - Input: `editSubcatName`
    - Icon preview button calling `openIconPicker`
    - Save button calling `crud.renameSubcategory(...)` and saving JSON.

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_keybinds_panel.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/panel.luau tests/test_keybinds_panel.py
git commit -m "feat(keybinds): add in-place edit buttons for app tabs and subcategories"
```

---

### Task 6: Full Integration Testing & Regression Verification

**Files:**
- Modify: `tests/test_keybinds_panel.py`
- Test: All tests in `tests/`

- [ ] **Step 1: Run complete test suite**

Run: `pytest tests/test_manifest_translations.py tests/test_keybinds_crud.py tests/test_keybinds_panel.py -v`
Expected: All tests PASS.

- [ ] **Step 2: Verify Luau syntax via luau CLI (if available) or python runner**

Run: `python3 -c "import tests.test_keybinds_crud; print('Imports valid')"`
Expected: Imports valid.

- [ ] **Step 3: Commit any final regression adjustments**

```bash
git status
```
Ensure working tree is clean.
