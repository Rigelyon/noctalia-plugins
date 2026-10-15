# Keybinds Panel CRUD & Panel Dimension Expansion Design Specification

## 1. Overview
This specification details the design for expanding the Keybinds Panel (`rigelyon/keybinds`) dimensions to **1280 × 720 px** (preserving a 3-column grid layout) and implementing a full **CRUD (Create, Read, Update, Delete)** management system for custom keybindings stored in `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json`.

---

## 2. Goals & Success Criteria

1. **Panel Dimension Expansion:**
   - Increase panel dimensions from `1120 × 700` to `1280 × 720 px` in `plugin.toml`.
   - Maintain the **3-column** grid layout (`grid_columns = "3"`).
   - Ensure card column widths expand to ~413px, drastically reducing text truncation for long keybinding descriptions and combinations on 1080p and 1440p displays.

2. **Full In-Panel CRUD Functionality:**
   - **Create**: Add new keybinding with App, Subcategory, Description, and Key combinations.
   - **Read**: Display all Hyprland and custom keybinds sorted A-Z with search and app filtering (already implemented).
   - **Update**: Edit existing custom keybindings directly from the panel.
   - **Delete**: Remove custom keybindings with instant removal and file synchronization.
   - **Hyprland Safety**: Hyprland system bindings remain strictly read-only; CRUD controls only appear on custom items (`source == "custom"`).

3. **Clean, Minimalist UI Interaction:**
   - Icon-only "+ Add" button in the header bar.
   - Edit (pencil) and Delete (trash) action buttons on custom cards.
   - Elegant modal dialog overlay with modifier toggles (`SUPER`, `CTRL`, `ALT`, `SHIFT`) and primary key text input.
   - Instant reactive UI reload (`refreshAllBinds()`) without restarting Noctalia.

---

## 3. UI & UX Architecture

### 3.1. Header Bar Modifications
- Alongside the existing Search Input, Refresh button, and Close button:
  - Add an icon-only **Add Keybind** button:
    - Glyph: `"plus"`
    - Size: `14`
    - Tooltip: `tr("actions.add_keybind")` ("Add Keybind" / "Tambah Keybind")
    - Variant: `"ghost"`
    - Action: Sets `isModalOpen = true`, `modalMode = "create"`, resets form state, and re-renders.

### 3.2. Custom Card Action Buttons
For cards where `item.source == "custom"`:
- Beside or hovering on the key badges in each card:
  - **Edit Button**:
    - Glyph: `"pencil"`
    - Size: `12`
    - Color: `"on_surface_variant"`
    - Tooltip: `tr("actions.edit_keybind")` ("Edit Keybind" / "Edit Keybind")
    - Action: Populates modal form with current values (`app`, `subcat`, `desc`, `mods`, `key`), sets `editingItemId = item.id`, `modalMode = "edit"`, `isModalOpen = true`, and re-renders.
  - **Delete Button**:
    - Glyph: `"trash"`
    - Size: `12`
    - Color: `"error"`
    - Tooltip: `tr("actions.delete_keybind")` ("Delete Keybind" / "Hapus Keybind")
    - Action: Directly prompts confirmation or deletes the bind from `custom_keybinds.json`, dispatches a notification, and triggers `refreshAllBinds()`.

For cards where `item.source == "hyprland"`:
- Action buttons are hidden or not rendered.

### 3.3. Modal Dialog Form Overlay
When `isModalOpen == true`, an overlay container is rendered on top of the main panel body:
- **Backdrop**: Semi-transparent dark background (`rgba(0, 0, 0, 0.55)` or Noctalia scrim token) intercepting clicks.
- **Dialog Box**:
  - Centered box, `width = 540`, padding `20px`, rounded corners (`16 * cornerRadiusScale`), fill `"surface"`.
  - **Header**:
    - Title: `tr("modal.title_add")` or `tr("modal.title_edit")`.
    - Close Icon Button: Glyph `"x"`, closes modal.
  - **Form Fields**:
    1. **Application (`appInput`)**:
       - Text input with placeholder `tr("modal.app_placeholder")` (e.g., "Kitty Terminal", "Neovim", "Custom App").
    2. **Subcategory (`subcatInput`)**:
       - Text input with placeholder `tr("modal.subcat_placeholder")` (e.g., "Tabs & Windows", "Clipboard", "General").
    3. **Description (`descInput`)**:
       - Text input with placeholder `tr("modal.desc_placeholder")` (e.g., "Toggle Fullscreen", "Split Pane").
    4. **Modifier Keys (Toggles)**:
       - 4 clickable badge buttons: `SUPER`, `CTRL`, `ALT`, `SHIFT`.
       - Clicking a modifier toggles its boolean state.
       - Active state: fill `"primary"`, text `"on_primary"`.
       - Inactive state: fill `"surface_variant"`, text `"on_surface_variant"`.
    5. **Primary Key (`keyInput`)**:
       - Single-line text input for the primary key (e.g., `T`, `Enter`, `Space`, `[`, `F12`).
       - Automatically trimmed and uppercased.
  - **Footer Actions**:
    - **Cancel Button**: Variant `"ghost"`, closes modal without saving.
    - **Save Button**: Variant `"primary"`, validates input, commits changes to JSON file, triggers `refreshAllBinds()`, and closes modal.

---

## 4. Data Model & Persistence Logic

### 4.1. JSON Schema (`custom_keybinds.json`)
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
            { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" }
          ]
        }
      ]
    }
  ]
}
```

### 4.2. CRUD Operations Pipeline

1. **Load Data**:
   - `readCustomJson()` reads the file from `customFilePath` (defaulting to `pluginDataDir() .. "/custom_keybinds.json"`).
   - Parses into Lua table structure `{ apps = { ... } }`.

2. **Save Data**:
   - `writeCustomJson(data)` serializes the Lua table via `noctalia.json.encode(data, true)`.
   - Writes to filesystem using `noctalia.writeFile(path, encoded)`.

3. **Create Operation**:
   - Validate `appName`, `subcatName`, `desc`, and `primaryKey` are non-empty.
   - Locate existing app matching `appName` (case-insensitive). If none exists, create new app `{ name = appName, icon = "terminal", subcategories = {} }`.
   - Locate existing subcategory matching `subcatName` under the app. If none exists, create new subcategory `{ name = subcatName, icon = "command", binds = {} }`.
   - Assemble `keys`: selected modifiers (e.g. `["CTRL", "SHIFT"]`) followed by `primaryKey` (e.g. `["CTRL", "SHIFT", "T"]`).
   - Append `{ keys = keys, description = desc }` to `sub.binds`.
   - Save JSON and call `refreshAllBinds()`.

4. **Update Operation**:
   - Locate target bind by stored original coordinates or identity `(origApp, origSubcat, origBindIdx)`.
   - Update `description` and `keys`.
   - If app name or subcategory name changed, remove from old location and insert into new app/subcategory.
   - Save JSON and call `refreshAllBinds()`.

5. **Delete Operation**:
   - Locate target bind in JSON structure.
   - Remove it via `table.remove(sub.binds, bindIdx)`.
   - If `sub.binds` becomes empty, remove the empty subcategory.
   - If `app.subcategories` becomes empty, remove the empty app.
   - Save JSON and call `refreshAllBinds()`.

---

## 5. Localization & Strings

Add new i18n keys to `translations/en.json` and `translations/id.json`:
- `actions.add_keybind`: "Add Keybind" / "Tambah Keybind"
- `actions.edit_keybind`: "Edit Keybind" / "Edit Keybind"
- `actions.delete_keybind`: "Delete Keybind" / "Hapus Keybind"
- `modal.title_add`: "Add New Keybind" / "Tambah Keybind Baru"
- `modal.title_edit`: "Edit Keybind" / "Edit Keybind"
- `modal.app_label`: "Application" / "Aplikasi"
- `modal.app_placeholder`: "e.g. Kitty, Neovim" / "misal: Kitty, Neovim"
- `modal.subcat_label`: "Subcategory" / "Subkategori"
- `modal.subcat_placeholder`: "e.g. Navigation, Windows" / "misal: Navigasi, Windows"
- `modal.desc_label`: "Description" / "Deskripsi"
- `modal.desc_placeholder`: "Action description" / "Deskripsi aksi shortcut"
- `modal.modifiers_label`: "Modifiers" / "Tombol Pengubah"
- `modal.key_label`: "Primary Key" / "Tombol Utama"
- `modal.key_placeholder`: "e.g. T, Enter, Space" / "misal: T, Enter, Space"
- `modal.cancel`: "Cancel" / "Batal"
- `modal.save`: "Save" / "Simpan"
- `modal.err_validation`: "Please provide description and primary key" / "Deskripsi dan tombol utama wajib diisi"
- `modal.saved_notify`: "Keybind saved successfully" / "Keybind berhasil disimpan"
- `modal.deleted_notify`: "Keybind removed" / "Keybind berhasil dihapus"

---

## 6. Testing & Quality Assurance

1. **Manifest Dimensions Test**:
   - Verify `width = 1280` and `height = 720` in `keybinds/plugin.toml`.
2. **Translation Verification**:
   - Verify all modal and action keys are present in both `en.json` and `id.json`.
3. **Automated Unit Tests (`tests/test_keybinds_crud.py`)**:
   - Verify JSON encode and decode cycle for nested apps -> subcategories -> binds.
   - Verify create keybind in new and existing app/subcategory.
   - Verify edit/update keybind fields.
   - Verify delete keybind and cleanup of empty subcategories.
   - Verify Luau syntax validity for `keybinds/panel.luau`.
