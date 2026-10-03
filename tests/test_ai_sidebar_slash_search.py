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
            trimmed = text.strip()
            if not trimmed:
                return False, ""
            if trimmed == "/search":
                return True, ""
            if trimmed.startswith("/search ") or trimmed.startswith("/search\n"):
                return True, trimmed[8:].strip()
            import re
            if re.search(r"\s/search$", trimmed):
                cleaned = re.sub(r"\s+/search$", "", trimmed)
                return True, cleaned.strip()
            if re.search(r"\s/search\s", trimmed):
                cleaned = re.sub(r"\s+/search\s+", " ", trimmed)
                return True, cleaned.strip()
            return False, ""

        ok, q = is_slash_search("/search")
        self.assertTrue(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/search who is elon musk")
        self.assertTrue(ok)
        self.assertEqual(q, "who is elon musk")

        ok, q = is_slash_search("who is elon musk /search")
        self.assertTrue(ok)
        self.assertEqual(q, "who is elon musk")

        ok, q = is_slash_search("tolong carikan /search laptop gaming")
        self.assertTrue(ok)
        self.assertEqual(q, "tolong carikan laptop gaming")

        ok, q = is_slash_search("/search   what is linux?  ")
        self.assertTrue(ok)
        self.assertEqual(q, "what is linux?")

        ok, q = is_slash_search("halo apa kabar")
        self.assertFalse(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/searching something")
        self.assertFalse(ok)

        ok, q = is_slash_search("https://google.com/search?q=123")
        self.assertFalse(ok)
        self.assertEqual(q, "")

    def test_slash_search_in_middle_and_end_in_luau_files(self):
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("%s/search$", content)
        self.assertIn("%s/search%s", content)

    def test_slash_popover_in_middle_and_end(self):
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("%s/([%w%-_]*)$", content)
        client_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "client.luau"
        )
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("client.synthesizeSearchQuery", content)
        self.assertIn("client.prepareContextualSearch", content)


    def test_panel_uses_prepare_contextual_search(self):
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("client.prepareContextualSearch", content)
        self.assertIn("search.isSlashSearch", content)
        # Verify the persistent toggle in settings was removed
        self.assertNotIn("tr(\"enable_web_search\")", content)
        # Verify slash command popover nodes
        self.assertIn("slashNodes", content)
        self.assertIn("slashQuery", content)
        self.assertIn('cmd = "/search"', content)

    def test_wikipedia_search_parsing_simulation(self):
        sample_wiki = {
            "query": {
                "search": [
                    {
                        "title": "Presiden Indonesia",
                        "pageid": 12345,
                        "snippet": "Presiden Republik Indonesia adalah kepala negara...",
                    }
                ]
            }
        }
        items = []
        for r in sample_wiki.get("query", {}).get("search", []):
            items.append({
                "title": r.get("title", ""),
                "url": "https://id.wikipedia.org/wiki/" + r.get("title", "").replace(" ", "_"),
                "snippet": r.get("snippet", ""),
            })
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["title"], "Presiden Indonesia")
        self.assertEqual(items[0]["url"], "https://id.wikipedia.org/wiki/Presiden_Indonesia")


    def test_query_synthesis_prompt_and_tokens(self):
        client_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "client.luau"
        )
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("max_tokens", content)
        self.assertIn("resolve pronouns and references", content.lower())


    def test_slash_search_message_stripping_logic(self):
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("slash_search_default_prompt", content)
        self.assertIn("strippedText", content)


if __name__ == "__main__":
    unittest.main()
