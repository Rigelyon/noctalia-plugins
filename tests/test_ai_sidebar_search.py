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

    def test_duckduckgo_lite_html_parsing_simulation(self):
        sample_html = """
        <a rel="nofollow" href="https://example.com/result1" class='result-link'>Result Title 1</a>
        </td></tr><tr><td></td>
        <td class='result-snippet'>Snippet for result 1 with <b>bold</b> text.</td>
        <a rel="nofollow" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fresult2&amp;rut=123" class='result-link'>Result Title 2</a>
        </td></tr><tr><td></td>
        <td class='result-snippet'>Snippet for result 2 &amp; extra info.</td>
        """
        import re, urllib.parse

        links = re.findall(r'<a[^>]+href=[\'\"]([^\'\"]+)[\'\"][^>]*class=[\'\"]result-link[\'\"][^>]*>(.*?)</a>', sample_html)
        snippets = re.findall(r'<td[^>]*class=[\'\"]result-snippet[\'\"][^>]*>(.*?)</td>', sample_html, re.DOTALL)

        items = []
        for i in range(min(len(links), len(snippets))):
            url, title = links[i]
            m_uddg = re.search(r'uddg=([^&]+)', url)
            if m_uddg:
                url = urllib.parse.unquote(m_uddg.group(1))
            items.append({
                "title": re.sub(r'<[^>]+>', '', title).strip(),
                "url": url,
                "snippet": re.sub(r'<[^>]+>', '', snippets[i]).replace('&amp;', '&').strip()
            })

        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]["title"], "Result Title 1")
        self.assertEqual(items[0]["url"], "https://example.com/result1")
        self.assertEqual(items[0]["snippet"], "Snippet for result 1 with bold text.")
        self.assertEqual(items[1]["title"], "Result Title 2")
        self.assertEqual(items[1]["url"], "https://example.com/result2")
        self.assertEqual(items[1]["snippet"], "Snippet for result 2 & extra info.")

    def test_gemini_google_search_grounding_payload(self):
        gemini_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "providers", "gemini.luau"
        )
        with open(gemini_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("googleSearch", content)
        self.assertIn("enable_web_search", content)

    def test_client_search_integration(self):
        client_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "client.luau"
        )
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('require("./search.luau")', content)
        self.assertIn("client.prepareSearchContext", content)


    def test_format_search_context_persona_preservation(self):
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("Web Context & Factual Background", content)
        self.assertIn("Retain your established persona", content)
        self.assertNotIn("Incorporate the above live web search information into your response", content)


if __name__ == "__main__":
    unittest.main()

