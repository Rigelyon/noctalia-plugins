import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")


class TestKeybindsDocs(unittest.TestCase):
    def test_readme_and_thumbnail(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(readme_path), "README.md must exist")
        self.assertTrue(os.path.isfile(thumb_path), "thumbnail.webp must exist")

        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("# Keybinds Cheatsheet", content)
        self.assertIn("hyprctl", content)
        self.assertIn("custom_keybinds.json", content)
        self.assertGreater(os.path.getsize(thumb_path), 100)


if __name__ == "__main__":
    unittest.main()
