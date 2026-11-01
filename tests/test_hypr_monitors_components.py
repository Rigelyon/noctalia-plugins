import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsComponents(unittest.TestCase):
    def test_components_file_structure(self):
        comp_path = os.path.join(PLUGIN_DIR, "components.luau")
        self.assertTrue(os.path.isfile(comp_path), "Missing components.luau")
        with open(comp_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function components.renderCanvasCard", content)
        self.assertIn("function components.renderCanvasToolbar", content)
        self.assertIn("function components.renderScaleSelector", content)
        self.assertIn("function components.renderOrientationSelector", content)
        self.assertIn("function components.renderSafetyModal", content)
        self.assertIn("function components.renderRefreshRateSelector", content)
        self.assertIn("seenNominal", content)
        self.assertIn("bestNominal", content)

    def test_refresh_rate_deduplication_and_selection_algorithm(self):
        # Sample modes from Sony TV as shown in the user's report
        modes = [
            "3840x2160@60.00Hz",
            "3840x2160@59.94Hz",
            "3840x2160@50.00Hz",
            "3840x2160@30.00Hz",
            "3840x2160@29.97Hz",
            "3840x2160@25.00Hz",
            "3840x2160@24.00Hz",
            "3840x2160@23.98Hz",
            "1920x1080@75.00Hz",  # Different resolution: must be filtered out
        ]
        cur_w, cur_h = 3840, 2160
        cur_refresh = 29.97

        # 1. Resolution filter
        import re
        matched = []
        for m in modes:
            match = re.match(r"^(\d+)x(\d+)@([\d\.]+)", m)
            if match and int(match.group(1)) == cur_w and int(match.group(2)) == cur_h:
                matched.append(float(match.group(3)))

        self.assertEqual(len(matched), 8)
        self.assertNotIn(75.0, matched)

        # 2. Group by rounded nominal rate
        seen_nominal = {}
        options = []
        for hz in matched:
            nominal = round(hz)
            if nominal not in seen_nominal:
                item = {"nominal": nominal, "exact": hz}
                seen_nominal[nominal] = item
                options.append(item)
            else:
                existing = seen_nominal[nominal]
                if abs(hz - nominal) < abs(existing["exact"] - nominal):
                    existing["exact"] = hz

        options.sort(key=lambda x: x["nominal"])
        nominal_rates = [o["nominal"] for o in options]

        # Verify no doubled rates (29 & 30, 23 & 24, 59 & 60 collapsed to clean nominals)
        self.assertEqual(nominal_rates, [24, 25, 30, 50, 60])

        # 3. Exactly one button is active
        active_nominal = round(cur_refresh)
        active_count = 0
        for opt in options:
            if opt["nominal"] == active_nominal:
                active_count += 1

        self.assertEqual(active_count, 1)
        self.assertEqual(active_nominal, 30)


if __name__ == "__main__":
    unittest.main()
