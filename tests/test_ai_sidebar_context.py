import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
CONTEXT_FILE = os.path.join(PLUGIN_DIR, "context.luau")


class TestAiSidebarContext(unittest.TestCase):
    def test_context_file_exists(self):
        self.assertTrue(os.path.isfile(CONTEXT_FILE), f"Missing {CONTEXT_FILE}")
        with open(CONTEXT_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("context.estimateTokens", content)
        self.assertIn("context.estimateMessageTokens", content)
        self.assertIn("context.estimateTotalTokens", content)
        self.assertIn("context.prepareContext", content)

    def test_token_estimation_heuristic_simulation(self):
        def estimate_tokens(text: str) -> int:
            if not text:
                return 0
            return max(1, (len(text) + 3) // 4)

        def estimate_message_tokens(msg: dict) -> int:
            return estimate_tokens(msg.get("content", "")) + 4

        def estimate_total_tokens(messages: list) -> int:
            return sum(estimate_message_tokens(m) for m in messages)

        self.assertEqual(estimate_tokens(""), 0)
        self.assertEqual(estimate_tokens("a"), 1)
        self.assertEqual(estimate_tokens("1234"), 1)
        self.assertEqual(estimate_tokens("12345"), 2)
        self.assertEqual(estimate_tokens("Hello world!"), 3)

        msg = {"role": "user", "content": "Hello"}
        self.assertEqual(estimate_message_tokens(msg), 2 + 4)  # 2 + 4 overhead = 6
        self.assertEqual(estimate_total_tokens([msg, msg]), 12)

    def test_prepare_context_sliding_window_simulation(self):
        def prepare_context(messages: list, max_tokens: int, system_prompt: str = None) -> list:
            if not messages:
                return []

            if len(messages) <= 2:
                return list(messages)

            anchor = messages[0]
            recent = messages[-2:]

            if len(messages) <= 4:
                return list(messages)

            recap_content = "[Previous discussion context: middle turns omitted for brevity]"
            recap_msg = {"role": "system", "content": recap_content}
            return [anchor, recap_msg] + recent

        raw_msgs = [
            {"role": "user", "content": "How do I build a plugin?"},
            {"role": "assistant", "content": "Step 1: create plugin.toml"},
            {"role": "user", "content": "What about settings?"},
            {"role": "assistant", "content": "Use storage.luau"},
            {"role": "user", "content": "What about panels?"},
            {"role": "assistant", "content": "Use panel.luau"},
        ]

        condensed = prepare_context(raw_msgs, 100)
        self.assertEqual(condensed[0]["content"], "How do I build a plugin?")
        self.assertIn("Previous discussion context", condensed[1]["content"])
        self.assertEqual(condensed[-1]["content"], "Use panel.luau")


if __name__ == "__main__":
    unittest.main()
