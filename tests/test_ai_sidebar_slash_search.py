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


    def test_client_contains_contextual_search_methods(self):
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
