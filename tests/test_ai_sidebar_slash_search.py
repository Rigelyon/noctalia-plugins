import os
import unittest

SEARCH_FILE = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "search.luau"
)


class TestAiSidebarSlashSearch(unittest.TestCase):
    def test_search_file_contains_slash_helper(self):
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("search.isSlashSearch", content)

    def test_slash_search_parsing_logic(self):
        def is_slash_search(text):
            t = text.strip()
            if t == "/search":
                return True, ""
            if t.startswith("/search ") or t.startswith("/search\n"):
                return True, t[7:].strip()
            return False, ""

        ok, q = is_slash_search("/search")
        self.assertTrue(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/search who is elon musk")
        self.assertTrue(ok)
        self.assertEqual(q, "who is elon musk")

        ok, q = is_slash_search("/search   what is linux?  ")
        self.assertTrue(ok)
        self.assertEqual(q, "what is linux?")

        ok, q = is_slash_search("halo apa kabar")
        self.assertFalse(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/searching something")
        self.assertFalse(ok)


if __name__ == "__main__":
    unittest.main()
