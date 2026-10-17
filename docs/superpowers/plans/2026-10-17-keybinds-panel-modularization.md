# Keybinds Panel Modularization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor and modularize `keybinds/panel.luau` (~2,036 lines) into cohesive, focused modules (`icons.luau`, `parser.luau`, `components.luau`, `modals.luau`, and a lean `panel.luau` orchestrator of ~500 lines) while maintaining 100% backward compatibility and test parity.

**Architecture:** Split by functional domain with clean boundaries: icon catalog & picker in `icons.luau`, binding decoding & normalization in `parser.luau`, card item rendering in `components.luau`, dialogs/forms in `modals.luau`, and state orchestrator with lifecycle in `panel.luau`. Each module communicates via explicit Luau tables/functions required via `require("./<module>.luau")`.

**Tech Stack:** Luau (Noctalia UI toolkit: `ui.row`, `ui.column`, `ui.input`, `ui.select`, `ui.button`, `ui.glyph`, `ui.label`), Python (pytest unit testing).

## Global Constraints

- Preserve all existing styling tokens, colors (`surface`, `primary`, `on_surface`, `outline`), and 1280x720 panel dimension.
- Maintain natural sorting and 3-column top-to-bottom chunking (`math.ceil(totalItems / 3)`).
- Retain all test assertions in `tests/test_keybinds_*.py` and ensure 100% pass rate.
- Retain `flexGrow = 1` and `align = "stretch"` fixes on modal input rows so input fields never shrink.

---

### Task 1: Create `keybinds/icons.luau`

**Files:**
- Create: `keybinds/icons.luau`
- Test: `tests/test_keybinds_icons.py`

**Interfaces:**
- Produces:
  - `ICON_CATEGORIES`: table of 7 categories with Lucide icon names.
  - `renderIconPickerOverlay(props: IconPickerProps): any`: Renders the floating icon picker modal.

- [ ] **Step 1: Write the unit test for `icons.luau`**

Create `tests/test_keybinds_icons.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
ICONS_FILE = os.path.join(PLUGIN_DIR, "icons.luau")


class TestKeybindsIcons(unittest.TestCase):
    def test_icons_module_exists(self):
        self.assertTrue(os.path.isfile(ICONS_FILE), "icons.luau must exist")
        with open(ICONS_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("ICON_CATEGORIES", content)
        self.assertIn("renderIconPickerOverlay", content)
        self.assertIn("category_all", content)
        self.assertIn("terminal", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_keybinds_icons.py -v`
Expected: FAIL (file not found).

- [ ] **Step 3: Extract icon catalog and picker component into `keybinds/icons.luau`**

Extract `ICON_CATEGORIES` and `renderIconPickerOverlay` from `panel.luau` into `keybinds/icons.luau`. It takes `props = { isOpen, search, category, current, onSearchChange, onCategorySelect, onPick, onClose, tr, cornerRadiusScale }`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_keybinds_icons.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/icons.luau tests/test_keybinds_icons.py
git commit -m "feat(keybinds): extract icon catalog and picker modal into icons.luau"
```

---

### Task 2: Create `keybinds/parser.luau`

**Files:**
- Create: `keybinds/parser.luau`
- Modify: `tests/test_keybinds_parser.py`

**Interfaces:**
- Produces:
  - `KEY_TRANSLATIONS`: table of keycode/name mappings.
  - `normalizeKey(key: string): string`
  - `naturalSortKey(str: string?): string`
  - `decodeModmask(modmask: number): { string }`
  - `categorizeBind(description: string, key: string, dispatcher: string?): (string, string)`
  - `HYPRLAND_SUBCAT_INFO`: table of subcat metadata.
  - `buildKeyComboText(modifiers: { string }, key: string): string`
  - `parseCustomKeybinds(rawJson: string): { any }`

- [ ] **Step 1: Write test for `keybinds/parser.luau` file presence and exports**

Update `tests/test_keybinds_parser.py` to assert that `keybinds/parser.luau` exists and exports the normalization and decoding functions.

- [ ] **Step 2: Run test to verify failure**

Run: `pytest tests/test_keybinds_parser.py -v`
Expected: FAIL (parser.luau not found).

- [ ] **Step 3: Implement `keybinds/parser.luau`**

Extract all normalization, sorting, decoding, categorization, and custom JSON parser logic from `panel.luau` into `keybinds/parser.luau`.

- [ ] **Step 4: Run test to verify pass**

Run: `pytest tests/test_keybinds_parser.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/parser.luau tests/test_keybinds_parser.py
git commit -m "feat(keybinds): extract key normalization and parser into parser.luau"
```

---

### Task 3: Create `keybinds/components.luau`

**Files:**
- Create: `keybinds/components.luau`
- Test: `tests/test_keybinds_components.py`

**Interfaces:**
- Produces:
  - `renderKbdBadges(modifiers: { string }, primaryKey: string, isHovered: boolean, cornerRadiusScale: number): any`
  - `renderKeybindCard(item: any, props: CardProps): any`

- [ ] **Step 1: Write the unit test for `components.luau`**

Create `tests/test_keybinds_components.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
COMP_FILE = os.path.join(PLUGIN_DIR, "components.luau")


class TestKeybindsComponents(unittest.TestCase):
    def test_components_module_exists(self):
        self.assertTrue(os.path.isfile(COMP_FILE), "components.luau must exist")
        with open(COMP_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("renderKeybindCard", content)
        self.assertIn("renderKbdBadges", content)
        self.assertIn("noctalia.copyToClipboard", content)
```

- [ ] **Step 2: Run test to verify failure**

Run: `pytest tests/test_keybinds_components.py -v`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `keybinds/components.luau`**

Extract `renderKbdBadges` and `renderKeybindCard` into `keybinds/components.luau`. It takes `props = { isEditMode, copiedId, cornerRadiusScale, onCopy, onEdit, onDelete, tr }`.

- [ ] **Step 4: Run test to verify pass**

Run: `pytest tests/test_keybinds_components.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/components.luau tests/test_keybinds_components.py
git commit -m "feat(keybinds): extract card and badge components into components.luau"
```

---

### Task 4: Create `keybinds/modals.luau`

**Files:**
- Create: `keybinds/modals.luau`
- Test: `tests/test_keybinds_modals.py`

**Interfaces:**
- Produces:
  - `renderEditAppModal(props: EditAppModalProps): any`
  - `renderEditSubcatModal(props: EditSubcatModalProps): any`
  - `renderAddEditKeybindModal(props: AddKeybindModalProps): any`

- [ ] **Step 1: Write the unit test for `modals.luau`**

Create `tests/test_keybinds_modals.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
MODALS_FILE = os.path.join(PLUGIN_DIR, "modals.luau")


class TestKeybindsModals(unittest.TestCase):
    def test_modals_module_exists(self):
        self.assertTrue(os.path.isfile(MODALS_FILE), "modals.luau must exist")
        with open(MODALS_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("renderEditAppModal", content)
        self.assertIn("renderEditSubcatModal", content)
        self.assertIn("renderAddEditKeybindModal", content)
        self.assertIn("ui.select", content)
        self.assertIn("modal-app-input", content)
        self.assertIn("modal-subcat-input", content)
        self.assertIn("flexGrow = 1", content)
        self.assertIn('align = "stretch"', content)
```

- [ ] **Step 2: Run test to verify failure**

Run: `pytest tests/test_keybinds_modals.py -v`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `keybinds/modals.luau`**

Extract `renderEditAppModal`, `renderEditSubcatModal`, and `renderAddModal` into `keybinds/modals.luau`.
Ensure that all `ui.input` and `ui.row` within form rows preserve `flexGrow = 1` and `align = "stretch"`.

- [ ] **Step 4: Run test to verify pass**

Run: `pytest tests/test_keybinds_modals.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add keybinds/modals.luau tests/test_keybinds_modals.py
git commit -m "feat(keybinds): extract modal dialog components into modals.luau"
```

---

### Task 5: Refactor `keybinds/panel.luau` as Lean Orchestrator and Verify

**Files:**
- Modify: `keybinds/panel.luau`
- Test: All tests in `tests/test_keybinds_*.py` and `tests/test_manifest_translations.py`

**Interfaces:**
- Consumes:
  - `require("./presets.luau")`
  - `require("./crud.luau")`
  - `require("./icons.luau")`
  - `require("./parser.luau")`
  - `require("./components.luau")`
  - `require("./modals.luau")`
- Produces:
  - `onOpen(context)`
  - `onKey(chord, pressed)`
  - Panel UI render via `panel.render(...)`

- [ ] **Step 1: Wire all modules into `keybinds/panel.luau`**

Update `keybinds/panel.luau` to require the new modules and act as the clean coordinator:
- Panel level state (`activeApp`, `searchQuery`, `copiedId`, `isEditMode`, modal states)
- `renderHeader`: Search input & action buttons
- `renderAppTabs`: Horizontal app tab list with in-place edit button
- `renderSubcategoryHeading`: Subcategory title, icon, and in-place edit button
- `renderKeybindsGrid`: Top-to-bottom 3-column distribution
- `renderModalOverlay`: Thin wrapper delegating to `modals.luau` and `icons.luau`
- `render`: Master tree assembly
- `onOpen`, `onKey`: Lifecycle handlers

- [ ] **Step 2: Verify `panel.luau` line count reduction**

Run: `wc -l keybinds/panel.luau`
Expected: Under 600 lines (down from 2,036 lines).

- [ ] **Step 3: Run entire test suite**

Run: `pytest tests/test_manifest_translations.py tests/test_keybinds_*.py -v`
Expected: All 26+ tests PASS.

- [ ] **Step 4: Visual runtime verification**

Run:
```bash
flatpak-spawn --host noctalia msg panel-toggle rigelyon/keybinds:panel && sleep 0.5 && flatpak-spawn --host grim -o eDP-1 /tmp/refactor_verify.png
```
Verify the panel renders identically to before.

- [ ] **Step 5: Commit**

```bash
git add keybinds/panel.luau
git commit -m "refactor(keybinds): modularize panel into orchestrator with dedicated submodules"
```
