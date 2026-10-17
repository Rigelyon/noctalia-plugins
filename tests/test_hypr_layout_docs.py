import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutDocs(unittest.TestCase):
    def test_readme_and_thumbnail(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(readme_path), "Missing README.md")
        self.assertTrue(os.path.isfile(thumb_path), "Missing thumbnail.webp")

        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("Hyprland Layout Switcher", content)
        self.assertIn("dwindle", content)
        self.assertIn("master", content)
        self.assertIn("hyprctl", content)


if __name__ == "__main__":
    unittest.main()
