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

    def test_components_tokens_and_spacing(self):
        with open(COMP_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must support token-based rendering
        self.assertIn("itemOrMods.tokens", content)
        # Must support comma separator
        self.assertIn('text = ","', content)
        # Must use compact gap = 3 for proper spacing without taking too much horizontal space
        self.assertIn("gap = 3, align = \"center\" }, kbdBadges", content)


if __name__ == "__main__":
    unittest.main()

