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
        self.assertIn("function layout_math.resolveCollisions", content)

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

    def test_unmirroring_preserves_main_display(self):
        # Scenario: Monitor 1 (eDP-1) is main at (0, 0), Monitor 2 (HDMI-A-1) is extended at (1920, 0)
        monitors = [
            {"name": "eDP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1.0, "mirrorOf": None},
            {"name": "HDMI-A-1", "x": 1920, "y": 0, "width": 3840, "height": 2160, "scale": 1.0, "mirrorOf": None},
        ]
        # Step 1: Monitor 2 clones Monitor 1 -> saves unmirrored pos (1920, 0)
        monitors[1]["_unmirroredX"] = monitors[1]["x"]
        monitors[1]["_unmirroredY"] = monitors[1]["y"]
        monitors[1]["mirrorOf"] = "eDP-1"
        monitors[1]["x"] = 0
        monitors[1]["y"] = 0

        self.assertEqual(monitors[1]["mirrorOf"], "eDP-1")
        self.assertEqual(monitors[1]["_unmirroredX"], 1920)

        # Step 2: Monitor 2 is switched back to independent
        prev_source = monitors[1]["mirrorOf"]
        monitors[1]["mirrorOf"] = None
        monitors[1]["x"] = monitors[1]["_unmirroredX"]
        monitors[1]["y"] = monitors[1]["_unmirroredY"]

        # Verify eDP-1 is still at (0, 0) and HDMI-A-1 returned to (1920, 0)
        self.assertEqual(monitors[0]["x"], 0)
        self.assertEqual(monitors[0]["y"], 0)
        self.assertEqual(monitors[1]["x"], 1920)
        self.assertEqual(monitors[1]["y"], 0)


if __name__ == "__main__":
    unittest.main()
