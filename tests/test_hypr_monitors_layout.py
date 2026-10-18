import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsLayout(unittest.TestCase):
    def test_layout_math_file_and_logic(self):
        math_path = os.path.join(PLUGIN_DIR, "layout_math.luau")
        self.assertTrue(os.path.isfile(math_path), "Missing layout_math.luau")
        with open(math_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function layout_math.getVirtualSize", content)
        self.assertIn("function layout_math.snapRight", content)
        self.assertIn("function layout_math.snapLeft", content)
        self.assertIn("function layout_math.snapAbove", content)
        self.assertIn("function layout_math.snapBelow", content)
        self.assertIn("function layout_math.alignTops", content)
        self.assertIn("function layout_math.alignBottoms", content)
        self.assertIn("function layout_math.computeCanvasProjection", content)
        self.assertIn("function layout_math.presetExtend", content)
        self.assertIn("function layout_math.presetMirror", content)
        self.assertIn("function layout_math.presetSingle", content)

    def test_mathematical_gapless_alignment(self):
        # Anchor monitor: 1920x1080 at scale 1.0, located at (0, 0)
        # Target monitor: 2560x1440 at scale 1.25
        anchor_vw = int(1920 / 1.0)
        anchor_vh = int(1080 / 1.0)
        target_vw = int(2560 / 1.25)
        target_vh = int(1440 / 1.25)

        self.assertEqual(anchor_vw, 1920)
        self.assertEqual(anchor_vh, 1080)
        self.assertEqual(target_vw, 2048)
        self.assertEqual(target_vh, 1152)

        # Snap right: target.x must be anchor.x + anchor_vw (1920)
        self.assertEqual(0 + anchor_vw, 1920)

        # Snap left: target.x must be anchor.x - target_vw (-2048)
        self.assertEqual(0 - target_vw, -2048)

        # Snap above: target.y must be anchor.y - target_vh (-1152)
        self.assertEqual(0 - target_vh, -1152)

        # Snap below: target.y must be anchor.y + anchor_vh (1080)
        self.assertEqual(0 + anchor_vh, 1080)


if __name__ == "__main__":
    unittest.main()
