import json
import os
import unittest

DATA_FILE = os.path.join(os.path.dirname(__file__), "..", "unicode", "data", "unicode.json")

class TestUnicodeDataset(unittest.TestCase):
    def test_file_exists_and_valid_json(self):
        self.assertTrue(os.path.isfile(DATA_FILE), f"Missing dataset: {DATA_FILE}")
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        self.assertIsInstance(data, list)
        self.assertGreaterEqual(len(data), 35000, "Dataset should have at least 35,000 named characters")

    def test_entry_structure_and_popular_symbols(self):
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)

        found_copyright = False
        found_arrow = False
        found_infinity = False

        for entry in data:
            self.assertEqual(len(entry), 4, f"Entry must be [hex, char, name, category]: {entry}")
            hex_code, char, name, category = entry
            self.assertTrue(isinstance(hex_code, str) and len(hex_code) >= 2)
            self.assertTrue(isinstance(char, str) and len(char) >= 1)
            self.assertTrue(isinstance(name, str) and len(name) >= 1)
            self.assertTrue(isinstance(category, str) and len(category) >= 1)

            if hex_code == "00A9":
                self.assertEqual(char, "©")
                self.assertIn("COPYRIGHT", name)
                found_copyright = True
            elif hex_code == "2192":
                self.assertEqual(char, "→")
                self.assertIn("ARROW", name)
                found_arrow = True
            elif hex_code == "221E":
                self.assertEqual(char, "∞")
                self.assertIn("INFINITY", name)
                found_infinity = True

        self.assertTrue(found_copyright, "Missing Copyright symbol")
        self.assertTrue(found_arrow, "Missing Rightwards Arrow")
        self.assertTrue(found_infinity, "Missing Infinity symbol")

if __name__ == "__main__":
    unittest.main()
