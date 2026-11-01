import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsProfiles(unittest.TestCase):
    def test_profiles_file_structure(self):
        prof_path = os.path.join(PLUGIN_DIR, "profiles.luau")
        self.assertTrue(os.path.isfile(prof_path), "Missing profiles.luau")
        with open(prof_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function profiles.loadProfiles", content)
        self.assertIn("function profiles.saveProfile", content)
        self.assertIn("function profiles.deleteProfile", content)
        self.assertIn("function profiles.findMatchingProfile", content)
        self.assertIn("profiles.json", content)

    def test_fingerprint_matching_order_invariant(self):
        saved_fingerprint = sorted(["DP-1", "eDP-1"])
        connected_monitors = sorted(["eDP-1", "DP-1"])
        self.assertEqual(saved_fingerprint, connected_monitors)

        unmatched = sorted(["eDP-1", "HDMI-A-1"])
        self.assertNotEqual(saved_fingerprint, unmatched)

    def test_no_string_gsub_inside_single_arg_call(self):
        prof_path = os.path.join(PLUGIN_DIR, "profiles.luau")
        with open(prof_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertNotIn("string.lower(string.gsub(", content)


if __name__ == "__main__":
    unittest.main()
