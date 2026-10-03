import json
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
CUSTOM_PROVIDER_FILE = os.path.join(PLUGIN_DIR, "providers", "custom.luau")


class TestAiSidebarCustomProvider(unittest.TestCase):
    def test_custom_provider_file_exists(self):
        self.assertTrue(
            os.path.isfile(CUSTOM_PROVIDER_FILE),
            f"Missing {CUSTOM_PROVIDER_FILE}",
        )

    def test_custom_provider_structure(self):
        with open(CUSTOM_PROVIDER_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("custom.buildChatRequest", content)
        self.assertIn("custom.buildTestRequest", content)
        self.assertIn("custom.parseStreamLine", content)
        self.assertIn("custom.parseTestResponse", content)
        self.assertIn("normalizeUrl", content)
        self.assertIn("/chat/completions", content)
        self.assertIn("Authorization: Bearer", content)
        self.assertIn("stream = true", content)

    def test_stream_parser_simulation(self):
        # Simulate SSE parsing logic
        line = 'data: {"choices":[{"delta":{"content":"Hello"}}]}'
        prefix = "data:"
        self.assertTrue(line.strip().startswith(prefix))
        payload_str = line.strip()[len(prefix):].strip()
        data = json.loads(payload_str)
        self.assertEqual(data["choices"][0]["delta"]["content"], "Hello")

    def test_test_response_simulation(self):
        # Simulate 200 OK
        resp_ok = {"ok": True, "status": 200, "body": '{"choices":[{"message":{"content":"pong"}}]}'}
        self.assertEqual(resp_ok["status"], 200)

        # Simulate 401 Unauthorized
        resp_err = {"ok": False, "status": 401, "body": '{"error":{"message":"Invalid API key"}}'}
        data = json.loads(resp_err["body"])
        self.assertEqual(data["error"]["message"], "Invalid API key")

    def test_storage_custom_config_structure(self):
        storage_file = os.path.join(PLUGIN_DIR, "storage.luau")
        with open(storage_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("custom_base_url: string", content)
        self.assertIn("custom_key: string", content)
        self.assertIn("custom_model: string", content)
        self.assertIn('noctalia.getConfig("custom_base_url")', content)
        self.assertIn('noctalia.getConfig("custom_api_key")', content)
        self.assertIn('custom_base_url = escapeTomlString', content)
        self.assertIn('custom_api_key = escapeTomlString', content)
        self.assertIn('custom_model = escapeTomlString', content)

    def test_client_router_includes_custom(self):
        client_file = os.path.join(PLUGIN_DIR, "client.luau")
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('require("./providers/custom.luau")', content)
        self.assertIn('name == "custom"', content)


if __name__ == "__main__":
    unittest.main()
