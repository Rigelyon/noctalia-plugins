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
        self.assertIn("noctalia.copyToClipboard", content)

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


if __name__ == "__main__":
    unittest.main()
