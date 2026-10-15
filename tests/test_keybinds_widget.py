import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")
WIDGET_FILE = os.path.join(PLUGIN_DIR, "widget.luau")


class TestKeybindsWidget(unittest.TestCase):
    def test_widget_structure_and_callbacks(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "widget.luau must exist")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertTrue(content.startswith("--!nonstrict"))
        self.assertIn("barWidget.setGlyph(", content)
        self.assertIn("barWidget.setTooltip(", content)
        self.assertIn("function onClick()", content)
        self.assertIn("noctalia.togglePanel(", content)


if __name__ == "__main__":
    unittest.main()
