import json
import os
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
PLUGIN_DIR = REPO_ROOT / "ai-sidebar"

class TestAiSidebarReasoningAndTools(unittest.TestCase):
    def test_storage_message_type_contains_reasoning_fields(self):
        storage_path = PLUGIN_DIR / "storage.luau"
        content = storage_path.read_text(encoding="utf-8")
        self.assertIn("reasoning: string?", content)
        self.assertIn("reasoningDurationMs: number?", content)
        self.assertIn("tool_calls: { any }?", content)
        self.assertIn("tool_call_id: string?", content)

    def test_translations_contain_reasoning_and_toolbar_keys(self):
        en_path = PLUGIN_DIR / "translations" / "en.json"
        id_path = PLUGIN_DIR / "translations" / "id.json"
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_trans = json.load(f)

        required_keys = [
            "thinking_active",
            "thinking_done",
            "thinking_seconds",
            "action_slash_commands",
            "search_disabled_notice",
        ]
        for key in required_keys:
            self.assertIn(key, en, f"Missing {key} in en.json")
            self.assertIn(key, id_trans, f"Missing {key} in id.json")

if __name__ == "__main__":
    unittest.main()
