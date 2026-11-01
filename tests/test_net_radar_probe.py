import os
import subprocess
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
PROBE_SCRIPT = os.path.join(PLUGIN_DIR, "probe.sh")


def parse_probe_output(line: str):
    parts = line.strip().split("|")
    if len(parts) < 7:
        return None
    gw_ms = float(parts[0]) if parts[0] and parts[0] != "none" else None
    dns_ms = float(parts[1]) if parts[1] and parts[1] != "none" else None
    game_ms = float(parts[2]) if parts[2] and parts[2] != "none" else None
    ssid = parts[3] if parts[3] and parts[3] != "none" else ""
    freq_mhz = int(parts[4]) if parts[4] and parts[4].isdigit() else 0
    signal_pct = int(parts[5]) if parts[5] and parts[5].isdigit() else 0
    rate_mbps = float(parts[6]) if parts[6] and parts[6] != "none" else 0.0

    return {
        "gw_ms": gw_ms,
        "dns_ms": dns_ms,
        "game_ms": game_ms,
        "ssid": ssid,
        "freq_mhz": freq_mhz,
        "signal_pct": signal_pct,
        "rate_mbps": rate_mbps,
    }


class TestNetRadarProbe(unittest.TestCase):
    def test_probe_script_exists_and_executable(self):
        self.assertTrue(os.path.isfile(PROBE_SCRIPT), "Missing probe.sh")
        self.assertTrue(os.access(PROBE_SCRIPT, os.X_OK), "probe.sh is not executable")

    def test_parse_probe_output_normal(self):
        sample = "1.23|14.5|32.1|Home_5G|5180|84|866.7"
        res = parse_probe_output(sample)
        self.assertIsNotNone(res)
        self.assertEqual(res["gw_ms"], 1.23)
        self.assertEqual(res["dns_ms"], 14.5)
        self.assertEqual(res["game_ms"], 32.1)
        self.assertEqual(res["ssid"], "Home_5G")
        self.assertEqual(res["freq_mhz"], 5180)
        self.assertEqual(res["signal_pct"], 84)
        self.assertEqual(res["rate_mbps"], 866.7)

    def test_parse_probe_output_packet_loss(self):
        sample = "1.10|none|none|Cafe_WiFi|2412|60|54"
        res = parse_probe_output(sample)
        self.assertIsNotNone(res)
        self.assertEqual(res["gw_ms"], 1.10)
        self.assertIsNone(res["dns_ms"])
        self.assertIsNone(res["game_ms"])
        self.assertEqual(res["freq_mhz"], 2412)

    def test_parse_probe_output_offline(self):
        sample = "none|none|none|none|0|0|0"
        res = parse_probe_output(sample)
        self.assertIsNotNone(res)
        self.assertIsNone(res["gw_ms"])
        self.assertIsNone(res["dns_ms"])
        self.assertIsNone(res["game_ms"])
        self.assertEqual(res["ssid"], "")
        self.assertIsNone(parse_probe_output(""))
        self.assertIsNone(parse_probe_output("short|output"))

    def test_probe_script_trap_and_cleanup(self):
        with open(PROBE_SCRIPT, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("trap ", content)
        self.assertIn("EXIT", content)
        self.assertIn("TERM", content)
        self.assertIn("INT", content)

    def test_probe_script_sanitizes_ssid_pipes(self):
        with open(PROBE_SCRIPT, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('SSID="${SSID//|/-}"', content)


if __name__ == "__main__":
    unittest.main()
