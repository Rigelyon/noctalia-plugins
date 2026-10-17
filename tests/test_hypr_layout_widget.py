import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutWidget(unittest.TestCase):
    def test_widget_file_structure(self):
        widget_path = os.path.join(PLUGIN_DIR, "widget.luau")
        self.assertTrue(os.path.isfile(widget_path), "Missing widget.luau")
        with open(widget_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function onClick()", content)
        self.assertIn("function onRightClick()", content)
        self.assertIn("barWidget.setGlyph", content)
        self.assertIn("layouts.getNextLayout", content)


if __name__ == "__main__":
    unittest.main()
