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
        self.assertIn("ui.row(", content)
        self.assertIn("ui.column(", content)
        self.assertIn("ui.label(", content)
        self.assertIn("ui.glyph(", content)

        # Hyprctl & custom JSON integration
        self.assertIn("hyprctl", content)
        self.assertIn("noctalia.runAsync", content)
        self.assertIn("noctalia.readFile", content)
        self.assertIn('noctalia.copyToClipboard(item.keyComboText, "text/plain")', content)

        # Per-app and subcategory architecture
        self.assertIn("renderAppTabs", content)
        self.assertIn("renderSubcategoryHeading", content)
        self.assertNotIn('activeCategory = "all"', content)

    def test_no_lua_syntax_gotchas(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for idx, line in enumerate(lines[1:], start=2):
            trimmed = line.strip()
            # Lua does not use ! for negation (e.g. !var, (!var))
            self.assertNotIn("(!", trimmed, f"Line {idx} uses '(!' instead of '(not '")
            self.assertFalse(trimmed.startswith("!"), f"Line {idx} starts with '!' instead of 'not '")


    def test_crud_components_present(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("crud.addKeybind", content)
        self.assertIn("crud.updateKeybind", content)
        self.assertIn("crud.deleteKeybind", content)
        self.assertIn("isModalOpen", content)
        self.assertIn("renderModalOverlay", content)


    def test_top_to_bottom_column_chunking(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("math.ceil(totalItems / 3)", content)
        self.assertIn("idx2 = r + numRows", content)
        self.assertIn("idx3 = r + numRows * 2", content)


    def test_active_tab_state_persistence(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("saveState()", content)
        self.assertIn("loadState()", content)
        self.assertIn("state.json", content)
        # Ensure onOpen does not unconditionally reset activeApp to hyprland
        on_open_body = content.split("function onOpen(")[1].split("end")[0]
        self.assertNotIn('activeApp = "hyprland"', on_open_body)


    def test_icon_picker_defined(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("renderIconPickerOverlay", content, "renderIconPickerOverlay function must be defined")
        self.assertIn("ICON_CATEGORIES", content, "Icon catalog must be defined")
        self.assertIn("openIconPicker", content, "openIconPicker must be defined")
        self.assertIn("isIconPickerOpen", content, "isIconPickerOpen state must be defined")

    def test_modal_uses_select_dropdowns(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("modal.app_new_option", content, "Modal must support + New App option")
        self.assertIn("modal.subcat_new_option", content, "Modal must support + New Subcategory option")
        self.assertIn("ui.select", content, "Modal must use ui.select for apps and subcategories")

    def test_inplace_app_and_subcat_edit(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn('modalMode == "edit_app"', content, "edit_app modal mode required")
        self.assertIn('modalMode == "edit_subcat"', content, "edit_subcat modal mode required")
        self.assertIn("crud.renameApp", content, "renameApp must be invoked in panel.luau")
        self.assertIn("crud.renameSubcategory", content, "renameSubcategory must be invoked in panel.luau")


if __name__ == "__main__":
    unittest.main()



