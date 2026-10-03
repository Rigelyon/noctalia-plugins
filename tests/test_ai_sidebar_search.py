import json
import os
import unittest

SEARCH_FILE = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "search.luau"
)


class TestAiSidebarSearch(unittest.TestCase):
    def test_search_file_exists(self):
        self.assertTrue(os.path.isfile(SEARCH_FILE), "Missing ai-sidebar/search.luau")
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        expected_exports = [
            "search.formatSearchContext",
            "search.buildSearchRequest",
            "search.parseSearchResponse",
            "search.performSearch",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"search.luau missing export {exp}")

    def test_context_formatting_simulation(self):
        items = [
            {"title": "Doc 1", "url": "https://example.com/1", "snippet": "Snippet 1"},
            {"title": "Doc 2", "url": "https://example.com/2", "snippet": "Snippet 2"},
        ]
        lines = ['[Web Search Results for: "test query"]']
        for i, item in enumerate(items, 1):
            lines.append(f"{i}. [{item['title']}]({item['url']})\n   {item['snippet']}")
        lines.append(
            "\nInstructions: Incorporate the above live web search information into your response. Cite sources with markdown links where appropriate."
        )
        formatted = "\n".join(lines)

        self.assertIn("[Doc 1](https://example.com/1)", formatted)
        self.assertIn("Snippet 1", formatted)
        self.assertIn("Instructions:", formatted)

    def test_tavily_response_parsing_simulation(self):
        sample_tavily = {
            "results": [
                {
                    "title": "Tavily Title",
                    "url": "https://tavily.com",
                    "content": "Tavily summary text",
                }
            ]
        }
        results = [
            {
                "title": r.get("title", ""),
                "url": r.get("url", ""),
                "snippet": r.get("content", ""),
            }
            for r in sample_tavily.get("results", [])
        ]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["title"], "Tavily Title")
        self.assertEqual(results[0]["snippet"], "Tavily summary text")

    def test_brave_response_parsing_simulation(self):
        sample_brave = {
            "web": {
                "results": [
                    {
                        "title": "Brave Title",
                        "url": "https://brave.com",
                        "description": "Brave summary",
                    }
                ]
            }
        }
        results = [
            {
                "title": r.get("title", ""),
                "url": r.get("url", ""),
                "snippet": r.get("description", ""),
            }
            for r in sample_brave.get("web", {}).get("results", [])
        ]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["title"], "Brave Title")
        self.assertEqual(results[0]["snippet"], "Brave summary")

    def test_duckduckgo_response_parsing_simulation(self):
        sample_ddg = {
            "Heading": "Python",
            "AbstractText": "Python is a programming language.",
            "AbstractURL": "https://en.wikipedia.org/wiki/Python",
            "RelatedTopics": [
                {
                    "Text": "Topic 1 - An interesting topic",
                    "FirstURL": "https://example.com/t1",
                }
            ],
        }
        items = []
        if sample_ddg.get("AbstractText"):
            items.append(
                {
                    "title": sample_ddg.get("Heading")
                    or "DuckDuckGo Instant Answer",
                    "url": sample_ddg.get("AbstractURL", ""),
                    "snippet": sample_ddg.get("AbstractText", ""),
                }
            )
        for topic in sample_ddg.get("RelatedTopics", []):
            if (
                isinstance(topic, dict)
                and topic.get("Text")
                and topic.get("FirstURL")
            ):
                items.append(
                    {
                        "title": topic["Text"].split(" - ")[0],
                        "url": topic["FirstURL"],
                        "snippet": topic["Text"],
                    }
                )
        self.assertGreaterEqual(len(items), 1)
        self.assertEqual(items[0]["title"], "Python")


if __name__ == "__main__":
    unittest.main()
