import json
import os
import unittest

DATA_FILE = os.path.join(os.path.dirname(__file__), "..", "unicode", "data", "unicode.json")

def simulate_search(data, query, max_results=30):
    query = query.strip().upper()
    if not query:
        return []

    # Check hex codepoint pattern
    is_hex = False
    hex_target = query
    if hex_target.startswith("U+"):
        hex_target = hex_target[2:]
        is_hex = True
    elif len(hex_target) >= 2 and all(c in "0123456789ABCDEF" for c in hex_target):
        is_hex = True

    results = []
    tokens = query.split()

    for item in data:
        code, char, name, cat = item
        # If hex search matches
        if is_hex and code.startswith(hex_target):
            results.append(item)
            if len(results) >= max_results:
                break
            continue

        # Multi-token name & category matching
        matched = True
        name_upper = name.upper()
        cat_upper = cat.upper()
        for token in tokens:
            if token not in name_upper and token not in cat_upper:
                matched = False
                break
        if matched:
            results.append(item)
            if len(results) >= max_results:
                break

    return results

class TestLauncherSearch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            cls.data = json.load(f)

    def test_search_arrow_right(self):
        res = simulate_search(self.data, "arrow right")
        self.assertGreater(len(res), 0)
        self.assertTrue(any(item[1] == "→" for item in res))

    def test_search_copyright(self):
        res = simulate_search(self.data, "copyright")
        self.assertGreater(len(res), 0)
        self.assertEqual(res[0][1], "©")

    def test_search_hex(self):
        res = simulate_search(self.data, "U+00A9")
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0][1], "©")

    def test_search_math_sum(self):
        res = simulate_search(self.data, "math sum")
        self.assertGreater(len(res), 0)
        self.assertTrue(any(item[1] == "∑" for item in res))

if __name__ == "__main__":
    unittest.main()
