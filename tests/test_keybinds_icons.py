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
