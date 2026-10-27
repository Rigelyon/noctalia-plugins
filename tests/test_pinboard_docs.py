import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "pinboard")


class TestPinboardDocs(unittest.TestCase):
    def test_readme_and_thumbnail_exist(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumbnail_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(readme_path), "Missing pinboard/README.md")
        self.assertTrue(os.path.isfile(thumbnail_path), "Missing pinboard/thumbnail.webp")

        with open(readme_path, "r", encoding="utf-8") as f:
            readme = f.read()

        # Check required documentation sections
        self.assertIn("# Pinboard", readme)
        self.assertIn("Ghost Mode", readme)
        self.assertIn("Interactive Mode", readme)
        self.assertIn("noctalia msg", readme)
        self.assertIn("Hyprland", readme)


if __name__ == "__main__":
    unittest.main()
