import os
import re
import unittest

PROMPTS_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "prompts.luau")


class TestAiSidebarPrompts(unittest.TestCase):
    def test_prompts_file_structure(self):
        self.assertTrue(os.path.isfile(PROMPTS_FILE), f"Missing {PROMPTS_FILE}")
        with open(PROMPTS_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check exports
        self.assertIn("prompts.getDefaults", content)
        self.assertIn("prompts.load", content)
        self.assertIn("prompts.save", content)
        self.assertIn("prompts.filter", content)

        # Check types
        self.assertIn("export type PromptTemplate", content)

        # Check presets presence
        expected_presets = [
            "explain",
            "code-review",
            "summarize",
            "fix-grammar",
            "translate",
            "write-test",
        ]
        for preset in expected_presets:
            self.assertIn(f'tag = "{preset}"', content, f"Missing preset: {preset}")

        # Check translate generic placeholder [target]
        self.assertIn("[target]", content, "Translate preset must have [target] placeholder")

    def test_prompt_filter_simulation(self):
        presets = [
            {"tag": "explain", "label": "Explain Code or Concept", "description": "Break down step-by-step", "content": "Explain:\n\n"},
            {"tag": "code-review", "label": "Review & Optimize", "description": "Inspect bugs and edge cases", "content": "Review:\n\n"},
            {"tag": "summarize", "label": "Summarize Key Points", "description": "Extract takeaways", "content": "Summarize:\n\n"},
            {"tag": "fix-grammar", "label": "Fix Grammar & Tone", "description": "Enhance clarity", "content": "Fix:\n\n"},
            {"tag": "translate", "label": "Translate Language", "description": "Translate text accurately", "content": "Please translate the following text into [target]:\n\n"},
            {"tag": "write-test", "label": "Generate Unit Tests", "description": "Create tests", "content": "Write tests for:\n\n"},
        ]

        def filter_prompts(query: str, templates: list) -> list:
            q = query.strip().lower()
            if not q:
                return templates[:5]
            matches = []
            for t in templates:
                if (q in t["tag"].lower() or
                    q in t["label"].lower() or
                    q in t["description"].lower()):
                    matches.append(t)
                    if len(matches) >= 5:
                        break
            return matches

        # Empty query returns up to 5 items
        self.assertEqual(len(filter_prompts("", presets)), 5)

        # Exact tag match
        res_explain = filter_prompts("explain", presets)
        self.assertEqual(len(res_explain), 1)
        self.assertEqual(res_explain[0]["tag"], "explain")

        # Partial tag match
        res_trans = filter_prompts("trans", presets)
        self.assertEqual(len(res_trans), 1)
        self.assertEqual(res_trans[0]["tag"], "translate")

        # Match in label or description
        res_opt = filter_prompts("optimize", presets)
        self.assertEqual(len(res_opt), 1)
        self.assertEqual(res_opt[0]["tag"], "code-review")

    def test_lua_hash_pattern_matching(self):
        def match_lua_hash(text: str):
            m1 = re.match(r"^#([\w\-_]*)$", text)
            if m1:
                return m1.group(1)
            m2 = re.search(r"\s#([\w\-_]*)$", text)
            if m2:
                return m2.group(1)
            return None

        self.assertEqual(match_lua_hash("#"), "")
        self.assertEqual(match_lua_hash("#explain"), "explain")
        self.assertEqual(match_lua_hash("hi #code-review"), "code-review")
        self.assertIsNone(match_lua_hash("https://example.com#section"))
        self.assertIsNone(match_lua_hash("word#tag"))

    def test_popover_dismiss_on_hash_delete(self):
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        self.assertTrue(os.path.isfile(panel_file))
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Check dismissal logic on backspace/deletion of hash
        self.assertIn("oldHash and not newHash", content)
        self.assertIn("showPromptPicker = false", content)
        self.assertIn("hoveredPromptTag = nil", content)

        # Check compact left-aligned row structure
        self.assertIn('justify = "start"', content)
        self.assertIn("hoveredPromptTag", content)

    def test_no_conditional_nil_ui_props(self):
        # Noctalia's reconciler keeps a prop that is omitted, so `x and "a" or nil`
        # never clears a previous value (caused stuck hover highlights).
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIsNone(
            re.search(r"\b(fill|color|glyph|text)\s*=\s*[^,\n]*\bor nil\b", content),
            "UI props must use an explicit fallback value, not `or nil`",
        )


    def test_environment_prompt_persona_guidance(self):
        client_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "client.luau"
        )
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("factual background knowledge", content.lower())


if __name__ == "__main__":
    unittest.main()
