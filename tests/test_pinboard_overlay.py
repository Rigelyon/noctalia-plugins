import os
import unittest

OVERLAY_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "overlay.luau")


class TestPinboardOverlay(unittest.TestCase):
    def test_overlay_file_exists_and_structure(self):
        self.assertTrue(os.path.isfile(OVERLAY_FILE), "Missing overlay.luau")
        with open(OVERLAY_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check layer shell rendering calls
        self.assertIn("layer.render(", content, "Missing layer.render call")
        self.assertIn("noctalia.layer.configure(", content, "Missing noctalia.layer.configure call")
        self.assertIn('layer = "overlay"', content, "Must declare layer = overlay")
        self.assertIn("clickThrough =", content, "Must configure clickThrough property")

        # Check view modes
        self.assertIn('"image"', content)
        self.assertIn('"note"', content)
        self.assertIn('"split"', content)


if __name__ == "__main__":
    unittest.main()
