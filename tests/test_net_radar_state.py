import math
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
PRESETS_FILE = os.path.join(PLUGIN_DIR, "presets.luau")
STATE_FILE = os.path.join(PLUGIN_DIR, "state.luau")


class NetRadarMetricsSimulator:
    def __init__(self, buffer_size=60, loss_window=20):
        self.buffer_size = buffer_size
        self.loss_window = loss_window
        self.history = []  # Ring buffer of float or None
        self.jitter_history = []
        self.loss_history = []
        self.secondary_graph_mode = "jitter"
        self.prev_rtt = None
        self.jitter = 0.0
        self.gw_ms = None
        self.dns_ms = None
        self.game_ms = None
        self.loss_pct = 0.0
        self.ssid = ""
        self.freq_mhz = 0
        self.signal_pct = 0
        self.rate_mbps = 0.0
        self.nm_conn = "unknown"

    def process_probe(self, raw_str: str):
        clean = raw_str.strip()
        if not clean:
            return
        parts = clean.split("|")
        if len(parts) < 7:
            return

        self.gw_ms = float(parts[0]) if parts[0] and parts[0] != "none" else None
        self.dns_ms = float(parts[1]) if parts[1] and parts[1] != "none" else None
        self.game_ms = float(parts[2]) if parts[2] and parts[2] != "none" else None
        self.ssid = parts[3] if parts[3] and parts[3] != "none" else ""
        self.freq_mhz = int(parts[4]) if parts[4] and parts[4].isdigit() else 0
        self.signal_pct = int(parts[5]) if parts[5] and parts[5].isdigit() else 0
        self.rate_mbps = float(parts[6]) if parts[6] and parts[6] != "none" else 0.0
        self.nm_conn = parts[7] if len(parts) >= 8 and parts[7] else "unknown"

        # Update history buffer
        self.history.append(self.game_ms)
        if len(self.history) > self.buffer_size:
            self.history.pop(0)

        # RFC 3550 Jitter: jitter += (abs(rtt - prev_rtt) - jitter) / 16
        if self.game_ms is not None:
            if self.prev_rtt is not None:
                diff = abs(self.game_ms - self.prev_rtt)
                self.jitter += (diff - self.jitter) / 16.0
            self.prev_rtt = self.game_ms

        self.jitter_history.append(self.jitter)
        if len(self.jitter_history) > self.buffer_size:
            self.jitter_history.pop(0)

        # Packet loss over last loss_window samples
        window = self.history[-self.loss_window :]
        if window:
            dropped = sum(1 for x in window if x is None)
            self.loss_pct = (dropped / len(window)) * 100.0
        else:
            self.loss_pct = 0.0

        self.loss_history.append(self.loss_pct)
        if len(self.loss_history) > self.buffer_size:
            self.loss_history.pop(0)

    def get_status(self):
        if self.gw_ms is None and self.dns_ms is None:
            return "OFFLINE"
        if self.nm_conn == "portal":
            return "CAPTIVE_PORTAL"
        if self.gw_ms is not None and self.dns_ms is None and self.game_ms is None:
            return "NO_INTERNET"
        if self.game_ms is None:
            return "POOR"

        if self.game_ms < 60.0 and self.jitter < 10.0 and self.loss_pct == 0.0:
            return "OPTIMAL"
        if self.game_ms <= 120.0 and self.jitter <= 25.0 and self.loss_pct <= 5.0:
            return "FAIR"
        return "POOR"

    def get_graph_values(self):
        full_buffer = [-1.0] * (self.buffer_size - len(self.history)) + [
            x if x is not None else -1.0 for x in self.history
        ]
        valid_points = [x for x in full_buffer if x >= 0]
        max_ms = max(valid_points) if valid_points else 0.0
        min_ms = min(valid_points) if valid_points else 0.0
        avg_ms = sum(valid_points) / len(valid_points) if valid_points else 0.0

        ceiling = max(100.0, max_ms * 1.25)
        primary_values = [
            0.0 if v < 0 else min(1.0, max(0.0, v / ceiling)) for v in full_buffer
        ]

        full_j = [0.0] * (self.buffer_size - len(self.jitter_history)) + self.jitter_history
        j_max = max(full_j) if full_j else 0.0
        j_sum = sum(full_j) if full_j else 0.0
        avg_jitter = j_sum / len(full_j) if full_j else 0.0
        j_ceiling = max(15.0, j_max * 1.3)
        jitter_values = [min(1.0, max(0.0, j / j_ceiling)) for j in full_j]

        full_l = [0.0] * (self.buffer_size - len(self.loss_history)) + self.loss_history
        max_loss = max(full_l) if full_l else 0.0
        loss_values = [min(1.0, max(0.0, l / 100.0)) for l in full_l]

        return primary_values, jitter_values, loss_values, min_ms, avg_ms, max_ms, avg_jitter, max_loss


class TestNetRadarState(unittest.TestCase):
    def test_presets_file_exists_and_exports(self):
        self.assertTrue(os.path.isfile(PRESETS_FILE), "Missing net-radar/presets.luau")
        with open(PRESETS_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("presets.LIST", content)
        self.assertIn("presets.getById", content)
        self.assertIn("sea_singapore", content)
        self.assertIn("east_asia_tokyo", content)
        self.assertIn("us_west", content)
        self.assertIn("europe_west", content)
        self.assertIn("custom", content)

    def test_state_file_exists_and_exports(self):
        self.assertTrue(os.path.isfile(STATE_FILE), "Missing net-radar/state.luau")
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('require("./presets.luau")', content)
        self.assertIn("state.subscribe", content)
        self.assertIn("state.notify", content)
        self.assertIn("state.getActiveTargetHost", content)
        self.assertIn("state.processProbe", content)
        self.assertIn("state.getStatus", content)
        self.assertIn("state.getGraphValues", content)
        self.assertIn("jitterHistory", content)
        self.assertIn("lossHistory", content)
        self.assertIn("secondaryGraphMode", content)
        self.assertIn("NO_INTERNET", content)

    def test_rfc3550_jitter_convergence(self):
        sim = NetRadarMetricsSimulator()
        # Stable 30ms RTT
        for _ in range(10):
            sim.process_probe("1.0|15.0|30.0|Home|5180|80|866")
        self.assertAlmostEqual(sim.jitter, 0.0, places=2)

        # Introduce sudden 50ms spike (diff = 20)
        sim.process_probe("1.0|15.0|50.0|Home|5180|80|866")
        # Jitter becomes 0 + (20 - 0)/16 = 1.25
        self.assertAlmostEqual(sim.jitter, 1.25, places=2)

    def test_rolling_packet_loss_calculation(self):
        sim = NetRadarMetricsSimulator(loss_window=20)
        # 19 good probes, 1 dropped probe
        for _ in range(19):
            sim.process_probe("1.0|15.0|32.0|Home|5180|80|866")
        sim.process_probe("1.0|15.0|none|Home|5180|80|866")

        self.assertEqual(len(sim.history), 20)
        self.assertEqual(sim.loss_pct, 5.0)  # 1 in 20 = 5%

    def test_status_classification(self):
        sim = NetRadarMetricsSimulator()
        # Optimal
        sim.process_probe("1.0|15.0|35.0|Home|5180|80|866|full")
        self.assertEqual(sim.get_status(), "OPTIMAL")

        # Fair (high jitter or latency between 60-120)
        sim.process_probe("1.0|15.0|85.0|Home|5180|80|866|full")
        self.assertEqual(sim.get_status(), "FAIR")

        # Captive portal (router ok, NM reports portal)
        sim.process_probe("1.2|none|none|Hotel_WiFi|2412|50|54|portal")
        self.assertEqual(sim.get_status(), "CAPTIVE_PORTAL")

        # No internet (router ok, but WAN down and not a portal)
        sim.process_probe("1.2|none|none|Home_WiFi|5180|70|300|limited")
        self.assertEqual(sim.get_status(), "NO_INTERNET")

        # Offline (gateway dead)
        sim.process_probe("none|none|none|none|0|0|0|none")
        self.assertEqual(sim.get_status(), "OFFLINE")

        # Poor (game server dead but dns ok)
        sim.process_probe("1.0|15.0|none|Home|5180|80|866|full")
        self.assertEqual(sim.get_status(), "POOR")

        # Poor (high latency > 120ms)
        sim.process_probe("1.0|15.0|150.0|Home|5180|80|866|full")
        self.assertEqual(sim.get_status(), "POOR")

    def test_malformed_or_empty_probe(self):
        sim = NetRadarMetricsSimulator()
        sim.process_probe("")
        self.assertIsNone(sim.gw_ms)
        self.assertEqual(len(sim.history), 0)

        sim.process_probe("1.0|2.0|3.0")  # fewer than 7 parts
        self.assertIsNone(sim.gw_ms)
        self.assertEqual(len(sim.history), 0)

    def test_graph_values_normalization(self):
        sim = NetRadarMetricsSimulator(buffer_size=60)
        for i in range(30):
            sim.process_probe("1.0|15.0|40.0|Home|5180|80|866|full")

        p_vals, j_vals, l_vals, min_ms, avg_ms, max_ms, avg_jitter, max_loss = sim.get_graph_values()
        self.assertEqual(len(p_vals), 60)
        self.assertEqual(len(j_vals), 60)
        self.assertEqual(len(l_vals), 60)
        self.assertEqual(min_ms, 40.0)
        self.assertEqual(avg_ms, 40.0)
        self.assertEqual(max_ms, 40.0)
        # Ceiling is max(100.0, 40 * 1.25) = 100.0 -> normalized = 40.0 / 100.0 = 0.4
        self.assertAlmostEqual(p_vals[-1], 0.4, places=2)
        # Unpopulated slots are 0.0
        self.assertEqual(p_vals[0], 0.0)
        self.assertEqual(j_vals[0], 0.0)
        self.assertEqual(l_vals[0], 0.0)
        self.assertEqual(l_vals[-1], 0.0)

    def test_state_config_sync_and_preset_switching(self):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function state.syncConfig()", content)
        self.assertIn("function state.setPreset(", content)
        self.assertIn("state.prevGameMs = nil", content)
        self.assertIn("default_target_preset", content)
        self.assertIn("custom_target_host", content)

    def test_state_cross_vm_synchronization(self):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must synchronize telemetry and active preset across isolated Luau VMs via noctalia.state
        self.assertIn("noctalia.state", content)
        self.assertIn('noctalia.state.watch("net_radar.state"', content)
        self.assertIn('noctalia.state.set("net_radar.state"', content)


if __name__ == "__main__":
    unittest.main()
