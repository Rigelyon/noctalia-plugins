import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "pinboard")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestPinboardManifest(unittest.TestCase):
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

        self.assertEqual(manifest.get("id"), "rigelyon/pinboard")
        self.assertEqual(manifest.get("plugin_api"), 38)
        self.assertEqual(manifest.get("author"), "rigelyon")

        # Verify entry declarations
        self.assertIn("widget", manifest, "Missing [[widget]] in manifest")
        self.assertIn("panel", manifest, "Missing [[panel]] in manifest")
        self.assertIn("layer", manifest, "Missing [[layer]] in manifest")
        self.assertIn("service", manifest, "Missing [[service]] in manifest")

        # Verify all label_key and description_key exist in translations
        for setting in manifest.get("setting", []):
            lk = setting.get("label_key")
            dk = setting.get("description_key")
            if lk:
                self.assertTrue(has_key_path(en, lk), f"en.json missing {lk}")
                self.assertTrue(has_key_path(id_lang, lk), f"id.json missing {lk}")
            if dk:
                self.assertTrue(has_key_path(en, dk), f"en.json missing {dk}")
                self.assertTrue(has_key_path(id_lang, dk), f"id.json missing {dk}")
            for opt in setting.get("options", []):
                opt_lk = opt.get("label_key")
                if opt_lk:
                    self.assertTrue(has_key_path(en, opt_lk), f"en.json missing option {opt_lk}")
                    self.assertTrue(has_key_path(id_lang, opt_lk), f"id.json missing option {opt_lk}")


if __name__ == "__main__":
    unittest.main()
