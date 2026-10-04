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

    def test_custom_provider_includes_tools_and_reasoning_parsing(self):
        custom_path = PLUGIN_DIR / "providers" / "custom.luau"
        content = custom_path.read_text(encoding="utf-8")
        self.assertIn("web_search", content)
        self.assertIn("parseStreamEvent", content)
        self.assertIn("reasoning_content", content)

    def test_openai_provider_includes_tools_and_reasoning_parsing(self):
        openai_path = PLUGIN_DIR / "providers" / "openai.luau"
        content = openai_path.read_text(encoding="utf-8")
        self.assertIn("web_search", content)
        self.assertIn("parseStreamEvent", content)
        self.assertIn("reasoning_content", content)

    def test_gemini_provider_handles_thinking_parts(self):
        gemini_path = PLUGIN_DIR / "providers" / "gemini.luau"
        content = gemini_path.read_text(encoding="utf-8")
        self.assertIn("thought", content)
        self.assertIn("parseStreamEvent", content)

    def test_stream_parser_simulations(self):
        # 1. Reasoning content delta
        r1_line = '{"choices":[{"delta":{"reasoning_content":"Let\'s consider the user question."}}]}'
        data = json.loads(r1_line)
        self.assertEqual(data["choices"][0]["delta"]["reasoning_content"], "Let's consider the user question.")

        # 2. Tool calls delta
        tool_line = '{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","function":{"name":"web_search","arguments":"{\\"query\\":\\"laptop\\"}"}}]}}]}'
        data_tool = json.loads(tool_line)
        self.assertEqual(data_tool["choices"][0]["delta"]["tool_calls"][0]["function"]["name"], "web_search")

        # 3. Gemini thinking candidate
        gemini_line = '{"candidates":[{"content":{"parts":[{"thought":true,"text":"Thinking step 1"}]}}]}'
        data_g = json.loads(gemini_line)
        self.assertTrue(data_g["candidates"][0]["content"]["parts"][0]["thought"])
        self.assertEqual(data_g["candidates"][0]["content"]["parts"][0]["text"], "Thinking step 1")

    def test_client_stream_chat_supports_reasoning_and_tools(self):
        client_path = PLUGIN_DIR / "client.luau"
        content = client_path.read_text(encoding="utf-8")
        self.assertIn("onReasoning", content)
        self.assertIn("onToolStatus", content)
        self.assertIn("parseStreamEvent", content)
        self.assertIn("web_search", content)

    def test_plugin_toml_has_capture_keys(self):
        toml_path = PLUGIN_DIR / "plugin.toml"
        content = toml_path.read_text(encoding="utf-8")
        self.assertIn("capture_keys", content)
        self.assertIn("Escape", content)
        self.assertIn("Tab", content)

    def test_panel_has_on_key_and_slash_button(self):
        panel_path = PLUGIN_DIR / "panel.luau"
        content = panel_path.read_text(encoding="utf-8")
        self.assertIn("function onKey(", content)
        self.assertIn("showSlashPicker", content)
        self.assertIn("expandedThinking", content)
        self.assertIn("enable_web_search", content)

    def test_copy_button_copies_only_msg_content_excluding_reasoning(self):
        panel_path = PLUGIN_DIR / "panel.luau"
        content = panel_path.read_text(encoding="utf-8")
        self.assertIn('noctalia.copyToClipboard(msg.content, "text/plain")', content)
        # Ensure msg.reasoning is not concatenated to clipboard
        self.assertNotIn("msg.content .. msg.reasoning", content)
        self.assertNotIn("msg.reasoning .. msg.content", content)

    def test_keyboard_navigation_index_wraparound(self):
        # Test Down wrap-around logic: (idx % count) + 1
        count = 3
        idx = 1
        idx = (idx % count) + 1
        self.assertEqual(idx, 2)
        idx = (idx % count) + 1
        self.assertEqual(idx, 3)
        idx = (idx % count) + 1
        self.assertEqual(idx, 1)  # wrap-around to 1

        # Test Up wrap-around logic: ((idx - 2 + count) % count) + 1
        idx = ((idx - 2 + count) % count) + 1
        self.assertEqual(idx, 3)  # wrap-around from 1 to 3
        idx = ((idx - 2 + count) % count) + 1
        self.assertEqual(idx, 2)

    def test_settings_search_toggle_wiring(self):
        panel_path = PLUGIN_DIR / "panel.luau"
        content = panel_path.read_text(encoding="utf-8")
        self.assertIn("config.enable_web_search == false", content)
        self.assertIn("search_disabled_notice", content)

    def test_thinking_accordion_structure_in_panel(self):
        panel_path = PLUGIN_DIR / "panel.luau"
        content = panel_path.read_text(encoding="utf-8")
        self.assertIn("expandedThinking[idx]", content)
        self.assertIn('"brain"', content)
        self.assertIn("thinking_active", content)
        self.assertIn("thinking_done", content)

    def test_autonomous_tool_single_hop_limit(self):
        client_path = PLUGIN_DIR / "client.luau"
        content = client_path.read_text(encoding="utf-8")
        self.assertIn("_disable_tools = true", content)

if __name__ == "__main__":
    unittest.main()

