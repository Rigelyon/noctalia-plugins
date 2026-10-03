import os
import unittest

STORAGE_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "storage.luau")


class TestAiSidebarMetrics(unittest.TestCase):
    def test_metrics_schema_definition(self):
        self.assertTrue(os.path.isfile(STORAGE_FILE), f"Missing {STORAGE_FILE}")
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check MessageMetrics type export
        self.assertIn("export type MessageMetrics", content)
        self.assertIn("tokens: number?", content)
        self.assertIn("durationMs: number?", content)
        self.assertIn("tokensPerSec: number?", content)

        # Check Message definition has metrics field
        self.assertIn("metrics: MessageMetrics?", content)

        # Check loadSessions parses metrics
        self.assertIn("metricsObj", content)

    def test_speed_calculation_simulation(self):
        def compute_metrics(tokens: int, duration_ms: int) -> dict:
            clamped_duration_ms = max(100, duration_ms)
            duration_sec = clamped_duration_ms / 1000.0
            tokens_per_sec = round((tokens / duration_sec) * 10) / 10
            return {
                "tokens": tokens,
                "durationMs": clamped_duration_ms,
                "tokensPerSec": tokens_per_sec,
            }

        # Normal response
        m1 = compute_metrics(240, 1500)
        self.assertEqual(m1["tokens"], 240)
        self.assertEqual(m1["durationMs"], 1500)
        self.assertEqual(m1["tokensPerSec"], 160.0)

        # Very fast / 0ms duration (clamped to 100ms)
        m2 = compute_metrics(10, 0)
        self.assertEqual(m2["durationMs"], 100)
        self.assertEqual(m2["tokensPerSec"], 100.0)

        # Fractional speed rounding
        m3 = compute_metrics(100, 3000)
        self.assertEqual(m3["tokensPerSec"], 33.3)


if __name__ == "__main__":
    unittest.main()
