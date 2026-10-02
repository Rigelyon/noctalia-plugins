import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "unicode")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestManifestTranslations(unittest.TestCase):
    def test_manifest_and_translations_match(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        trans_path = os.path.join(PLUGIN_DIR, "translations", "en.json")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(trans_path), "Missing translations/en.json")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(trans_path, "r", encoding="utf-8") as f:
            translations = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/unicode")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("tags"), ["launcher", "productivity", "utility"])

        providers = manifest.get("launcher_provider", [])
        self.assertEqual(len(providers), 1)
        self.assertEqual(providers[0].get("prefix"), "uni")
        self.assertEqual(providers[0].get("debounce_ms"), 80)
        self.assertEqual(providers[0].get("entry"), "launcher.luau")

        # Check all label_key and description_key exist in translations
        for setting in manifest.get("setting", []):
            if "label_key" in setting:
                self.assertTrue(
                    has_key_path(translations, setting["label_key"]),
                    f"Missing key: {setting['label_key']}",
                )
            if "description_key" in setting:
                self.assertTrue(
                    has_key_path(translations, setting["description_key"]),
                    f"Missing key: {setting['description_key']}",
                )
            for opt in setting.get("options", []):
                if "label_key" in opt:
                    self.assertTrue(
                        has_key_path(translations, opt["label_key"]),
                        f"Missing key: {opt['label_key']}",
                    )


if __name__ == "__main__":
    unittest.main()
