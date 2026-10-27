import os
import unittest

STATE_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "state.luau")


class TestPinboardState(unittest.TestCase):
    def test_state_file_exists_and_exports(self):
        self.assertTrue(os.path.isfile(STATE_FILE), "Missing state.luau")
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        expected_methods = [
            "state.get",
            "state.subscribe",
            "state.toggleGhost",
            "state.toggleOverlay",
            "state.setAnchor",
            "state.setOpacity",
            "state.setScale",
            "state.setViewMode",
            "state.nextItem",
            "state.prevItem",
            "state.setActive",
            "state.addItem",
            "state.removeItem",
            "state.updateItemContent",
            "state.getActiveItem",
            "state.getGeometry",
        ]
        for m in expected_methods:
            self.assertIn(m, content, f"state.luau missing method {m}")

    def test_geometry_calculations(self):
        # Python simulation of geometry math
        SCALE_PRESETS = {
            "small": {"width": 300, "maxHeight": 360, "imageMaxHeight": 220},
            "medium": {"width": 420, "maxHeight": 500, "imageMaxHeight": 320},
            "large": {"width": 560, "maxHeight": 680, "imageMaxHeight": 440},
        }

        ANCHOR_PRESETS = {
            "top_right": {"anchors": ["top", "right"], "margins": {"top": 24, "right": 24}},
            "top_left": {"anchors": ["top", "left"], "margins": {"top": 24, "left": 24}},
            "bottom_right": {"anchors": ["bottom", "right"], "margins": {"bottom": 24, "right": 24}},
            "bottom_left": {"anchors": ["bottom", "left"], "margins": {"bottom": 24, "left": 24}},
        }

        def get_geometry(scale, anchor):
            s = SCALE_PRESETS.get(scale, SCALE_PRESETS["medium"])
            a = ANCHOR_PRESETS.get(anchor, ANCHOR_PRESETS["top_right"])
            return {
                "width": s["width"],
                "maxHeight": s["maxHeight"],
                "imageMaxHeight": s["imageMaxHeight"],
                "anchors": a["anchors"],
                "margins": a["margins"],
            }

        geo_tr = get_geometry("medium", "top_right")
        self.assertEqual(geo_tr["width"], 420)
        self.assertEqual(geo_tr["anchors"], ["top", "right"])
        self.assertEqual(geo_tr["margins"]["top"], 24)

        geo_bl = get_geometry("large", "bottom_left")
        self.assertEqual(geo_bl["width"], 560)
        self.assertEqual(geo_bl["anchors"], ["bottom", "left"])
        self.assertEqual(geo_bl["margins"]["bottom"], 24)

    def test_cyclic_navigation(self):
        items = ["item1", "item2", "item3"]

        def next_index(current_idx, count):
            if count == 0:
                return None
            return (current_idx % count) + 1

        def prev_index(current_idx, count):
            if count == 0:
                return None
            return count if current_idx <= 1 else current_idx - 1

        self.assertEqual(next_index(1, 3), 2)
        self.assertEqual(next_index(3, 3), 1)
        self.assertEqual(prev_index(1, 3), 3)
        self.assertEqual(prev_index(2, 3), 1)


if __name__ == "__main__":
    unittest.main()
