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
