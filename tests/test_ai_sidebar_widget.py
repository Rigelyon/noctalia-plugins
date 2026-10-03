import os
import unittest

WIDGET_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "widget.luau")


class TestAiSidebarWidget(unittest.TestCase):
    def test_widget_file_exists(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "Missing widget.luau")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertTrue(content.startswith("--!strict"), "widget.luau must start with --!strict")
        self.assertIn("sparkles", content)
        self.assertIn("barWidget.setGlyph", content)
        self.assertIn("barWidget.setTooltip", content)
        self.assertIn("onClick", content)
        self.assertIn("togglePanel", content)
        self.assertIn("rigelyon/ai-sidebar:panel", content)


if __name__ == "__main__":
    unittest.main()
