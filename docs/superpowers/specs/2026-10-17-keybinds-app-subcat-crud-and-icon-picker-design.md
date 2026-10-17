# Keybinds App/Subcategory CRUD and Icon Picker Design

## Overview
This design improves the custom keybinds management in the `keybinds` Noctalia plugin. It addresses application and subcategory fragmentation and typos by introducing structured selection (`ui.select`) with dynamic creation options, an interactive Lucide **Icon Picker** modal component, in-place editing of custom App and Subcategory metadata (name and icon) in Edit Mode, and pure CRUD helpers in `keybinds/crud.luau`.

---

## Architecture & Data Flow

```
[ User Interaction ]
       │
       ├─► (Modal Keybind) ─► ui.select App / Subcat ──► [+ New Option] ─► Input Name + Icon Button
       │                                                                         │
       │                                                                         ▼
       ├─► (Edit Mode) ──► Pencil on App Tab / Subcat Card Header ────► Open Icon Picker Modal
       │                                                                         │
       ▼                                                                         ▼
[ panel.luau state & forms ] ◄────────────────────────────────── Pick Icon / Update Fields
       │
       ▼
[ crud.luau (pure helpers) ]
  • renameApp(store, oldName, newName, newIcon?)
  • renameSubcategory(store, appName, oldSubcat, newSubcat, newIcon?)
  • addKeybind(store, app, subcat, desc, mods, key, appIcon?, subcatIcon?)
  • updateKeybind(...)
       │
       ▼
[ custom_keybinds.json ] (Atomic file save via saveCustomJson)
```

---

## 1. Data Model & CRUD Helper (`keybinds/crud.luau`)

### Existing Schema Compatibility
The existing schema in `~/.config/noctalia/plugins/keybinds/custom_keybinds.json` is preserved without breaking changes:
```json
{
  "apps": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "subcategories": [
        {
          "name": "Tabs & Windows",
          "icon": "app-window",
          "binds": [
            {
              "keys": ["SUPER", "RETURN"],
              "description": "Open new terminal"
            }
          ]
        }
      ]
    }
  ]
}
```

### New / Enhanced Functions in `crud.luau`

1. **`crud.addKeybind(store, appName, subcatName, desc, mods, primaryKey, appIcon?, subcatIcon?)`**:
   - If creating a new app, sets `app.icon = appIcon or "terminal"`.
   - If creating a new subcategory, sets `sub.icon = subcatIcon or "command"`.
2. **`crud.renameApp(store, oldName, newName, newIcon?) -> (boolean, string?)`**:
   - Finds app matching `oldName` (case-insensitive).
   - Validates that trimmed `newName` is non-empty.
   - If `string.lower(newName) ~= string.lower(oldName)`, ensures no existing app shares `newName` to avoid unintended merging.
   - Updates `app.name = newName` and `app.icon = newIcon or app.icon` in-place, keeping all subcategories and binds intact.
3. **`crud.renameSubcategory(store, appName, oldSubcatName, newSubcatName, newIcon?) -> (boolean, string?)`**:
   - Finds app `appName` and target subcategory `oldSubcatName`.
   - Validates that trimmed `newSubcatName` is non-empty and unique within that app.
   - Updates `sub.name = newSubcatName` and `sub.icon = newIcon or sub.icon` in-place, keeping all binds intact.
4. **Cleanup Policy**:
   - As established, apps and subcategories are automatically cleaned up when their binds reach 0. No manual multi-delete buttons are added, avoiding accidental data loss.

---

## 2. Icon Picker Component & Curated Catalog

### Curated Lucide Icons Catalog
The plugin will bundle a structured catalog of ~75 popular Lucide icons suitable for desktop apps and keybind categories:

- **All / Semua**: aggregates all categories.
- **Dev & Terminal**: `terminal`, `code`, `command`, `cpu`, `database`, `server`, `git-branch`, `bug`, `braces`, `play`, `package`, `layers`
- **System & Desktop**: `app-window`, `monitor`, `settings`, `sliders`, `power`, `maximize`, `minimize`, `shield`, `bell`, `wifi`, `sun`, `moon`, `lock`
- **Media & Audio**: `music`, `video`, `volume-2`, `volume-x`, `camera`, `image`, `play`, `pause`, `disc`, `mic`, `headphones`
- **Navigation & Web**: `globe`, `search`, `bookmark`, `compass`, `external-link`, `link`, `map`, `send`, `home`
- **Files & Docs**: `file-text`, `folder`, `clipboard`, `typography`, `file-code`, `book-open`, `archive`, `paperclip`
- **Tools & Misc**: `sparkles`, `star`, `tool`, `key`, `keyboard`, `zap`, `flag`, `tag`, `activity`, `layout-grid`

### Icon Picker Modal (`renderIconPickerOverlay`)
- **Dimensions & Styling**: Surface background, ~500 × 420 px, centered overlay.
- **Search Bar**: Instant search input filtering icons by substring in real-time.
- **Category Filter Chips**: Row of filter chips (`Semua`, `Dev`, `Sistem`, `Media`, `Navigasi`, `File`, `Tools`).
- **Icon Grid**: Scrollable container (`ui.scroll`) rendering rows of icon buttons (8 per row).
- **Selection Action**: Clicking an icon immediately invokes `onSelect(iconName)` callback and closes the picker overlay.

---

## 3. UI Workflows in `keybinds/panel.luau`

### Workflow A: Add / Edit Keybind Modal
- **App Selection**:
  - `ui.select` listing all current custom apps + `+ Tambah Aplikasi Baru...` (`modal.app_new_option`).
  - If existing app selected: displays app's current icon preview.
  - If `+ Tambah Aplikasi Baru...` selected: reveals text input for new app name and an interactive icon button (default `"terminal"`) that opens the Icon Picker.
- **Subcategory Selection**:
  - `ui.select` listing subcategories for the active app + `+ Tambah Subkategori Baru...` (`modal.subcat_new_option`).
  - If existing subcategory selected: displays subcategory's current icon preview.
  - If `+ Tambah Subkategori Baru...` selected: reveals text input for new subcategory name and an interactive icon button (default `"command"`) that opens the Icon Picker.
- **Existing Fields**:
  - Description input, modifier chips (`SUPER`, `CTRL`, `ALT`, `SHIFT`), and key input are retained.
- **Save**:
  - Writes new/updated keybind, persists custom app/subcategory icons, and reloads view.

### Workflow B: In-Place Editing (Edit Mode Active)
- **Edit Custom App Metadata**:
  - In Edit Mode, a small `pencil` icon appears next to the custom app tab title/count.
  - Clicking opens modal `modalMode = "edit_app"`:
    - Text input for app name.
    - Icon preview button opening Icon Picker.
    - Save button calls `crud.renameApp`.
- **Edit Custom Subcategory Metadata**:
  - In Edit Mode, a small `pencil` icon appears next to the subcategory title in the card header.
  - Clicking opens modal `modalMode = "edit_subcat"`:
    - Text input for subcategory name.
    - Icon preview button opening Icon Picker.
    - Save button calls `crud.renameSubcategory`.

---

## 4. Internationalization & Translations

Add corresponding translation keys in `keybinds/translations/en.json` and `keybinds/translations/id.json`:
- `modal.app_new_option` ("+ Add New Application..." / "+ Tambah Aplikasi Baru...")
- `modal.subcat_new_option` ("+ Add New Subcategory..." / "+ Tambah Subkategori Baru...")
- `modal.icon_picker_title` ("Choose Icon" / "Pilih Icon")
- `modal.icon_search_placeholder` ("Search icon name..." / "Cari nama icon...")
- `modal.category_all` ("All" / "Semua")
- `modal.category_dev` ("Dev" / "Dev")
- `modal.category_system` ("System" / "Sistem")
- `modal.category_media` ("Media" / "Media")
- `modal.category_navigation` ("Navigation" / "Navigasi")
- `modal.category_files` ("Files" / "File")
- `modal.category_tools` ("Tools" / "Alat")
- `modal.edit_app_title` ("Edit Application" / "Edit Aplikasi")
- `modal.edit_subcat_title` ("Edit Subcategory" / "Edit Subkategori")
- `modal.err_duplicate_app` ("An application with this name already exists" / "Aplikasi dengan nama ini sudah ada")
- `modal.err_duplicate_subcat` ("A subcategory with this name already exists" / "Subkategori dengan nama ini sudah ada")

---

## 5. Testing & Validation Strategy

1. **Python Unit Tests (`tests/test_keybinds_crud.py`)**:
   - `test_rename_app_success`: Ensures renaming modifies name & icon while preserving all binds and subcategories.
   - `test_rename_app_duplicate_prevented`: Ensures renaming to an existing app name fails with clear error.
   - `test_rename_subcategory_success`: Ensures renaming subcategory preserves binds.
   - `test_rename_subcategory_duplicate_prevented`: Ensures duplicate subcategories under the same app fail.
   - `test_add_keybind_custom_icons`: Ensures custom `appIcon` and `subcatIcon` are respected.
2. **Translation & Manifest Validation**:
   - `tests/test_manifest_translations.py` ensures 100% key parity between `en.json` and `id.json`.
3. **Panel Regression Tests (`tests/test_keybinds_panel.py`)**:
   - Verify presence of `ui.select` for app and subcategory.
   - Verify icon picker modal logic and render branch.
