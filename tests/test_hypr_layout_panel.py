import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutPanel(unittest.TestCase):
    def test_panel_file_structure(self):
        panel_path = os.path.join(PLUGIN_DIR, "panel.luau")
        self.assertTrue(os.path.isfile(panel_path), "Missing panel.luau")
        with open(panel_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("panel.render", content)
        self.assertIn("function onOpen", content)
        self.assertIn("components.renderLayoutCard", content)
        self.assertIn("components.renderSubActionsBar", content)


if __name__ == "__main__":
    unittest.main()
