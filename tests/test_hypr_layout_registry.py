import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutRegistry(unittest.TestCase):
    def test_layouts_file_structure(self):
        layouts_path = os.path.join(PLUGIN_DIR, "layouts.luau")
        self.assertTrue(os.path.isfile(layouts_path), "Missing layouts.luau")
        with open(layouts_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("layouts.LAYOUT_DEFS", content)
        self.assertIn('"dwindle"', content)
        self.assertIn('"master"', content)
        self.assertIn('"hy3"', content)
        self.assertIn('"scroller"', content)
        self.assertIn('"scrolling"', content)
        self.assertIn("function layouts.getAvailableLayouts", content)
        self.assertIn("function layouts.getNextLayout", content)


if __name__ == "__main__":
    unittest.main()
