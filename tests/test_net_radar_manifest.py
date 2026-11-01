import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestNetRadarManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/net-radar")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")

        # Verify entry declarations
        self.assertIn("widget", manifest, "Missing [[widget]] in manifest")
        self.assertIn("panel", manifest, "Missing [[panel]] in manifest")

        # Verify default show_text_in_bar is false (user constraint)
        settings = {s.get("key"): s for s in manifest.get("setting", [])}
        self.assertIn("show_text_in_bar", settings)
        self.assertFalse(settings["show_text_in_bar"].get("default"))

        # Verify all label_key and description_key exist in translations
        for setting in manifest.get("setting", []):
            lk = setting.get("label_key")
            dk = setting.get("description_key")
            if lk:
                self.assertTrue(has_key_path(en, lk), f"Missing '{lk}' in en.json")
                self.assertTrue(has_key_path(id_lang, lk), f"Missing '{lk}' in id.json")
            if dk:
                self.assertTrue(has_key_path(en, dk), f"Missing '{dk}' in en.json")
                self.assertTrue(has_key_path(id_lang, dk), f"Missing '{dk}' in id.json")
            for opt in setting.get("options", []):
                olk = opt.get("label_key")
                if olk:
                    self.assertTrue(has_key_path(en, olk), f"Missing option key '{olk}' in en.json")
                    self.assertTrue(has_key_path(id_lang, olk), f"Missing option key '{olk}' in id.json")

    def test_diagnostic_translation_keys(self):
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_data = json.load(f)

        required_keys = [
            "diag_offline",
            "diag_captive_portal",
            "diag_optimal",
            "diag_wired_optimal",
            "diag_weak_signal_stable",
            "diag_isp_loss",
            "diag_isp_lag",
            "diag_local_bufferbloat",
            "diag_high_jitter",
            "diag_wifi_weak_unstable",
            "diag_synthesis_connector",
        ]

        for key in required_keys:
            self.assertIn(key, en.get("panel", {}), f"Missing '{key}' in en['panel']")
            self.assertTrue(bool(en["panel"].get(key)), f"Key '{key}' in en['panel'] must not be empty")
            self.assertIn(key, id_data.get("panel", {}), f"Missing '{key}' in id['panel']")
            self.assertTrue(bool(id_data["panel"].get(key)), f"Key '{key}' in id['panel'] must not be empty")



if __name__ == "__main__":
    unittest.main()
