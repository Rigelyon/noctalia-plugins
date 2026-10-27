import os
import unittest

SERVICE_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "service.luau")


class TestPinboardIpc(unittest.TestCase):
    def test_service_file_exists_and_handlers(self):
        self.assertTrue(os.path.isfile(SERVICE_FILE), "Missing service.luau")
        with open(SERVICE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check standard entry callbacks
        self.assertIn("function onIpc(", content)
        self.assertIn("function onConfigChanged(", content)
        self.assertIn("function onEnable(", content)

        # Check supported IPC event handlers
        expected_events = [
            "toggle-ghost",
            "toggle-overlay",
            "set-anchor",
            "set-opacity",
            "set-scale",
            "next-item",
            "prev-item",
            "pin-item",
            "paste-clipboard",
            "browse-file",
        ]
        for ev in expected_events:
            self.assertIn(ev, content, f"service.luau missing handler for IPC event '{ev}'")


if __name__ == "__main__":
    unittest.main()
