import os
import unittest

PANEL_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "panel.luau")


class TestPinboardPanel(unittest.TestCase):
    def test_panel_file_exists_and_structure(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check declarative panel render call
        self.assertIn("panel.render(", content, "Missing panel.render call")

        # Check action triggers
        self.assertIn("Paste to Stash", content)
        self.assertIn("Browse", content)
        self.assertIn("New Note", content)

        # Check state subscription
        self.assertIn("state.subscribe(", content)


if __name__ == "__main__":
    unittest.main()
