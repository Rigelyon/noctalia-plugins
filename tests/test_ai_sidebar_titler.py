import os
import unittest

CLIENT_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "client.luau")


class TestAiSidebarTitler(unittest.TestCase):
    def test_titler_function_structure(self):
        self.assertTrue(os.path.isfile(CLIENT_FILE), f"Missing {CLIENT_FILE}")
        with open(CLIENT_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check client.generateTitle export
        self.assertIn("function client.generateTitle(", content)
        self.assertIn("titlerMessages", content)
        self.assertIn("conversation summarizer", content)
        self.assertIn("noctalia.http(req", content)

    def test_title_sanitization_simulation(self):
        def clean_title(raw_title: str) -> str:
            if not raw_title:
                return ""
            clean = raw_title.strip()
            # Strip quotes
            clean = clean.strip("\"'")
            # Strip illegal characters
            for char in '/\\%:*?"<>|':
                clean = clean.replace(char, "")
            clean = clean.strip()
            if len(clean) > 45:
                clean = clean[:42] + "..."
            return clean

        self.assertEqual(clean_title('"React Hook Refactor"'), "React Hook Refactor")
        self.assertEqual(clean_title("'Title With Quotes'"), "Title With Quotes")
        self.assertEqual(
            clean_title("A very long title that exceeds the forty-five character limit for titles"),
            "A very long title that exceeds the forty-f...",
        )


if __name__ == "__main__":
    unittest.main()
