import json
import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
STATE_FILE = os.path.join(PLUGIN_DIR, "state.luau")
TRANSLATIONS_DIR = os.path.join(PLUGIN_DIR, "translations")


class NetRadarDiagnosticsEvaluator:
    """Python reference evaluator matching state.getDiagnostics() logic in state.luau."""

    def __init__(self, translations_dir: str = TRANSLATIONS_DIR):
        with open(os.path.join(translations_dir, "en.json"), "r", encoding="utf-8") as f:
            self.en = json.load(f)
        with open(os.path.join(translations_dir, "id.json"), "r", encoding="utf-8") as f:
            self.id_lang = json.load(f)

    def tr(self, key: str, subst: dict = None, lang: str = "en") -> str:
        data = self.en if lang == "en" else self.id_lang
        parts = key.split(".")
        val = data
        for p in parts:
            if isinstance(val, dict) and p in val:
                val = val[p]
            else:
                return key
        if not isinstance(val, str):
            return key
        if subst:
            for k, v in subst.items():
                val = val.replace(f"{{{k}}}", str(v))
        return val

    def evaluate(self, state, lang: str = "en"):
        gw_ms = getattr(state, "gw_ms", None) if not isinstance(state, dict) else state.get("gw_ms")
        dns_ms = getattr(state, "dns_ms", None) if not isinstance(state, dict) else state.get("dns_ms")
        game_ms = getattr(state, "game_ms", None) if not isinstance(state, dict) else state.get("game_ms")
        jitter = float(getattr(state, "jitter", 0.0) if not isinstance(state, dict) else state.get("jitter", 0.0))
        loss_pct = float(getattr(state, "loss_pct", 0.0) if not isinstance(state, dict) else state.get("loss_pct", 0.0))
        ssid = str(getattr(state, "ssid", "") if not isinstance(state, dict) else state.get("ssid", ""))
        signal_pct = int(getattr(state, "signal_pct", 0) if not isinstance(state, dict) else state.get("signal_pct", 0))
        nm_conn = getattr(state, "nm_conn", None) if not isinstance(state, dict) else state.get("nm_conn")

        # 1. Tier 1 Critical (Takes precedence over everything)
        if gw_ms is None and dns_ms is None:
            return self.tr("panel.diag_offline", lang=lang), "alert-triangle", "outline"

        if nm_conn == "portal":
            return self.tr("panel.diag_captive_portal", lang=lang), "alert-triangle", "#f59e0b"

        if gw_ms is not None and dns_ms is None and game_ms is None:
            return self.tr("panel.diag_no_internet", lang=lang), "alert-triangle", "#f59e0b"

        if loss_pct >= 10.0 or game_ms is None:
            loss_val = 100.0 if (game_ms is None and loss_pct == 0.0) else loss_pct
            loss_str = f"{loss_val:.0f}"
            is_server_only = (dns_ms is not None and dns_ms <= 60.0)
            key = "panel.diag_server_loss" if is_server_only else "panel.diag_isp_loss"
            return self.tr(key, {"loss": loss_str}, lang=lang), "alert-triangle", "error"

        # 2. Findings collection
        findings = []
        is_weak_wifi = (ssid != "" and 0 < signal_pct < 40)

        # Tier 2 Acute Findings
        if 1.0 <= loss_pct < 10.0:
            is_server_only = (dns_ms is not None and dns_ms <= 60.0)
            key = "panel.diag_server_loss" if is_server_only else "panel.diag_isp_loss"
            id_name = "server_loss" if is_server_only else "isp_loss"
            findings.append({
                "id": id_name,
                "text": self.tr(key, {"loss": f"{loss_pct:.1f}"}, lang=lang),
                "glyph": "alert-triangle",
                "color": "error",
                "tier": 2,
                "priority": 1,
                "is_stable": False,
            })

        if gw_ms is not None and gw_ms <= 15.0 and game_ms is not None and game_ms > 120.0:
            is_server_only = (dns_ms is not None and dns_ms <= 60.0)
            key = "panel.diag_server_lag" if is_server_only else "panel.diag_isp_lag"
            id_name = "server_lag" if is_server_only else "isp_lag"
            findings.append({
                "id": id_name,
                "text": self.tr(key, {"ms": f"{game_ms:.0f}"}, lang=lang),
                "glyph": "alert-circle",
                "color": "tertiary",
                "tier": 2,
                "priority": 2,
                "is_stable": False,
            })

        if gw_ms is not None and gw_ms > 30.0 and not is_weak_wifi:
            findings.append({
                "id": "local_bufferbloat",
                "text": self.tr("panel.diag_local_bufferbloat", {"ms": f"{gw_ms:.0f}"}, lang=lang),
                "glyph": "alert-circle",
                "color": "tertiary",
                "tier": 2,
                "priority": 3,
                "is_stable": False,
            })

        if jitter > 15.0:
            findings.append({
                "id": "high_jitter",
                "text": self.tr("panel.diag_high_jitter", {"jitter": f"{jitter:.1f}"}, lang=lang),
                "glyph": "alert-circle",
                "color": "tertiary",
                "tier": 2,
                "priority": 4,
                "is_stable": False,
            })

        # Tier 3 Environmental / Physical Findings
        if is_weak_wifi:
            if (gw_ms is None or gw_ms <= 20.0) and jitter <= 10.0 and loss_pct == 0.0:
                findings.append({
                    "id": "weak_signal_stable",
                    "text": self.tr("panel.diag_weak_signal_stable", {"signal": str(signal_pct)}, lang=lang),
                    "glyph": "info-circle",
                    "color": "primary",
                    "tier": 3,
                    "priority": 5,
                    "is_stable": True,
                })
            else:
                findings.append({
                    "id": "wifi_weak_unstable",
                    "text": self.tr("panel.diag_wifi_weak_unstable", {"signal": str(signal_pct)}, lang=lang),
                    "glyph": "alert-triangle",
                    "color": "tertiary",
                    "tier": 3,
                    "priority": 6,
                    "is_stable": False,
                })
        elif ssid == "" and gw_ms is not None:
            findings.append({
                "id": "wired_optimal",
                "text": self.tr("panel.diag_wired_optimal", lang=lang),
                "glyph": "check-circle",
                "color": "primary",
                "tier": 3,
                "priority": 7,
                "is_stable": True,
            })

        # 3. Synthesis & Fallback
        has_issues = any(not f["is_stable"] for f in findings)
        if has_issues:
            active_findings = [f for f in findings if not f["is_stable"]]
        else:
            active_findings = findings

        if not active_findings:
            return self.tr("panel.diag_optimal", lang=lang), "info-circle", "primary"

        if len(active_findings) == 1:
            f = active_findings[0]
            return f["text"], f["glyph"], f["color"]

        # Sort by severity score and tier/priority
        severity_order = {"error": 1, "tertiary": 2, "primary": 3, "outline": 4}
        sorted_findings = sorted(
            active_findings,
            key=lambda x: (severity_order.get(x["color"], 99), x["tier"], x["priority"])
        )

        f1 = sorted_findings[0]
        f2 = sorted_findings[1]

        clean1 = re.sub(r"\s*\.+$", "", f1["text"])
        clean2 = re.sub(r"\s*\.+$", "", f2["text"])

        diag_text = self.tr("panel.diag_synthesis_connector", {"first": clean1, "second": clean2}, lang=lang)

        if any(f["color"] == "error" for f in (f1, f2)):
            overall_color = "error"
        elif any(f["color"] == "tertiary" for f in (f1, f2)):
            overall_color = "tertiary"
        else:
            overall_color = "primary"

        overall_glyph = f1["glyph"]

        return diag_text, overall_glyph, overall_color


class TestNetRadarDiagnostics(unittest.TestCase):
    def setUp(self):
        self.evaluator = NetRadarDiagnosticsEvaluator()

    def test_state_luau_declares_get_diagnostics(self):
        self.assertTrue(os.path.isfile(STATE_FILE), "Missing net-radar/state.luau")
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function state.getDiagnostics()", content)
        self.assertIn("panel.diag_offline", content)
        self.assertIn("panel.diag_captive_portal", content)
        self.assertIn("panel.diag_no_internet", content)
        self.assertIn('"#f59e0b"', content)
        self.assertIn("panel.diag_isp_loss", content)
        self.assertIn("panel.diag_isp_lag", content)
        self.assertIn("panel.diag_local_bufferbloat", content)
        self.assertIn("panel.diag_high_jitter", content)
        self.assertIn("panel.diag_weak_signal_stable", content)
        self.assertIn("panel.diag_wifi_weak_unstable", content)
        self.assertIn("panel.diag_wired_optimal", content)
        self.assertIn("panel.diag_optimal", content)
        self.assertIn("panel.diag_synthesis_connector", content)

        # Assert only valid Material Design 3 roles or verified hex colors are used
        self.assertNotIn('"warning"', content)
        self.assertNotIn('"destructive"', content)

    def test_evaluator_offline(self):
        # Offline: no gateway and no DNS
        text, glyph, color = self.evaluator.evaluate({"gw_ms": None, "dns_ms": None, "game_ms": None})
        self.assertEqual(text, "No default gateway found. Network is disconnected.")
        self.assertEqual(glyph, "alert-triangle")
        self.assertEqual(color, "outline")

    def test_evaluator_captive_portal(self):
        # Captive portal: gateway ok, NM reports portal
        text, glyph, color = self.evaluator.evaluate({"gw_ms": 1.5, "dns_ms": None, "game_ms": None, "nm_conn": "portal"})
        self.assertEqual(text, "Connected to local router, but internet is blocked. Check captive login.")
        self.assertEqual(glyph, "alert-triangle")
        self.assertEqual(color, "#f59e0b")

        # No internet: gateway ok, but WAN down and not portal
        text_no_net, glyph_no_net, color_no_net = self.evaluator.evaluate({"gw_ms": 1.5, "dns_ms": None, "game_ms": None, "nm_conn": "limited"})
        self.assertEqual(text_no_net, "Connected to local router, but no internet access.")
        self.assertEqual(glyph_no_net, "alert-triangle")
        self.assertEqual(color_no_net, "#f59e0b")

    def test_evaluator_critical_loss(self):
        # Critical loss on target server (DNS is healthy at 15ms)
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 15.0,
            "game_ms": 40.0,
            "loss_pct": 15.0,
        })
        self.assertEqual(text, "Internet is healthy, but target game server is experiencing packet loss (15%).")
        self.assertEqual(glyph, "alert-triangle")
        self.assertEqual(color, "error")

        # Critical loss on ISP (DNS is slow at 75ms)
        text_isp, glyph_isp, color_isp = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 75.0,
            "game_ms": 40.0,
            "loss_pct": 15.0,
        })
        self.assertEqual(text_isp, "ISP or external internet connection experiencing packet loss (15%).")
        self.assertEqual(glyph_isp, "alert-triangle")
        self.assertEqual(color_isp, "error")

        # Critical loss: game server completely dead (game_ms is None)
        text2, glyph2, color2 = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 15.0,
            "game_ms": None,
            "loss_pct": 0.0,
        })
        self.assertEqual(text2, "Internet is healthy, but target game server is experiencing packet loss (100%).")
        self.assertEqual(glyph2, "alert-triangle")
        self.assertEqual(color2, "error")

    def test_evaluator_weak_signal_stable(self):
        # Baseline Exception: weak signal (35%) with good ping (5ms), low jitter, zero loss
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 5.0,
            "dns_ms": 15.0,
            "game_ms": 35.0,
            "jitter": 2.0,
            "loss_pct": 0.0,
            "ssid": "Home_WiFi",
            "signal_pct": 35,
        })
        self.assertEqual(text, "Wi-Fi signal is moderate (35%), but link and game routing remain stable.")
        self.assertEqual(glyph, "info-circle")
        self.assertEqual(color, "primary")

    def test_evaluator_weak_signal_unstable_high_gateway(self):
        # Weak signal (35%) with high gateway ping (45ms) -> Wi-Fi unstable
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 45.0,
            "dns_ms": 55.0,
            "game_ms": 70.0,
            "jitter": 4.0,
            "loss_pct": 0.0,
            "ssid": "Home_WiFi",
            "signal_pct": 35,
        })
        self.assertEqual(text, "Weak Wi-Fi signal (35%) causing packet drops.")
        self.assertEqual(glyph, "alert-triangle")
        self.assertEqual(color, "tertiary")

    def test_evaluator_server_loss_vs_isp_loss(self):
        # Moderate loss on game server when DNS is healthy (15ms)
        text_srv, glyph_srv, color_srv = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 15.0,
            "game_ms": 35.0,
            "jitter": 3.0,
            "loss_pct": 6.0,
            "ssid": "Home_WiFi",
            "signal_pct": 80,
        })
        self.assertEqual(text_srv, "Internet is healthy, but target game server is experiencing packet loss (6.0%).")
        self.assertEqual(glyph_srv, "alert-triangle")
        self.assertEqual(color_srv, "error")

        # Moderate loss on ISP when DNS is slow/struggling (85ms)
        text_isp, glyph_isp, color_isp = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 85.0,
            "game_ms": 35.0,
            "jitter": 3.0,
            "loss_pct": 6.0,
            "ssid": "Home_WiFi",
            "signal_pct": 80,
        })
        self.assertEqual(text_isp, "ISP or external internet connection experiencing packet loss (6.0%).")
        self.assertEqual(glyph_isp, "alert-triangle")
        self.assertEqual(color_isp, "error")

    def test_evaluator_dual_issue_synthesis_en_and_id(self):
        # Dual issue: Server loss (6%) + weak Wi-Fi signal (35%)
        state_data = {
            "gw_ms": 5.0,
            "dns_ms": 15.0,
            "game_ms": 35.0,
            "jitter": 3.0,
            "loss_pct": 6.0,
            "ssid": "Home_WiFi",
            "signal_pct": 35,
        }

        # English synthesis
        text_en, glyph_en, color_en = self.evaluator.evaluate(state_data, lang="en")
        expected_en = (
            "Internet is healthy, but target game server is experiencing packet loss (6.0%), "
            "alongside Weak Wi-Fi signal (35%) causing packet drops."
        )
        self.assertEqual(text_en, expected_en)
        self.assertEqual(glyph_en, "alert-triangle")
        self.assertEqual(color_en, "error")

        # Indonesian synthesis
        text_id, glyph_id, color_id = self.evaluator.evaluate(state_data, lang="id")
        expected_id = (
            "Koneksi internet lancar, tetapi server game target mengalami packet loss (6.0%), "
            "serta Sinyal Wi-Fi lemah (35%) memicu paket hilang."
        )
        self.assertEqual(text_id, expected_id)
        self.assertEqual(glyph_id, "alert-triangle")
        self.assertEqual(color_id, "error")

    def test_evaluator_wired_connection_optimal(self):
        # Wired Ethernet connection (ssid == "") with good stats
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 1.0,
            "dns_ms": 12.0,
            "game_ms": 28.0,
            "jitter": 1.0,
            "loss_pct": 0.0,
            "ssid": "",
            "signal_pct": 0,
        })
        self.assertEqual(text, "Ethernet wired connection is pristine and stable.")
        self.assertEqual(glyph, "check-circle")
        self.assertEqual(color, "primary")

    def test_evaluator_pristine_wifi_optimal(self):
        # Pristine Wi-Fi connection with good signal (85%) and low latency
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 2.0,
            "dns_ms": 14.0,
            "game_ms": 32.0,
            "jitter": 2.0,
            "loss_pct": 0.0,
            "ssid": "Fast_WiFi_5G",
            "signal_pct": 85,
        })
        self.assertEqual(text, "Wi-Fi link and game routing are pristine.")
        self.assertEqual(glyph, "info-circle")
        self.assertEqual(color, "primary")

    def test_evaluator_local_bufferbloat(self):
        # Local gateway latency > 30ms on strong Wi-Fi (85%)
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 42.0,
            "dns_ms": 48.0,
            "game_ms": 55.0,
            "jitter": 3.0,
            "loss_pct": 0.0,
            "ssid": "Home_5G",
            "signal_pct": 85,
        })
        self.assertEqual(text, "High latency to local gateway (42ms). Potential home network congestion.")
        self.assertEqual(glyph, "alert-circle")
        self.assertEqual(color, "tertiary")

    def test_evaluator_server_lag_vs_isp_lag(self):
        # Local gateway is fast (8ms), DNS is fast (20ms), but game server is 145ms -> Server lag
        text_srv, glyph_srv, color_srv = self.evaluator.evaluate({
            "gw_ms": 8.0,
            "dns_ms": 20.0,
            "game_ms": 145.0,
            "jitter": 4.0,
            "loss_pct": 0.0,
            "ssid": "Home_5G",
            "signal_pct": 85,
        })
        self.assertEqual(text_srv, "Internet is fast, but target game server latency is high (145ms).")
        self.assertEqual(glyph_srv, "alert-circle")
        self.assertEqual(color_srv, "tertiary")

        # Local gateway is fast (8ms), but DNS is also slow (90ms) and game is 145ms -> ISP lag
        text_isp, glyph_isp, color_isp = self.evaluator.evaluate({
            "gw_ms": 8.0,
            "dns_ms": 90.0,
            "game_ms": 145.0,
            "jitter": 4.0,
            "loss_pct": 0.0,
            "ssid": "Home_5G",
            "signal_pct": 85,
        })
        self.assertEqual(text_isp, "Local router is fast, but ISP internet routing latency is high (145ms).")
        self.assertEqual(glyph_isp, "alert-circle")
        self.assertEqual(color_isp, "tertiary")

    def test_evaluator_high_jitter(self):
        # Elevated jitter (> 15ms) causing micro-stutter
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 5.0,
            "dns_ms": 22.0,
            "game_ms": 45.0,
            "jitter": 21.4,
            "loss_pct": 0.0,
            "ssid": "Home_5G",
            "signal_pct": 85,
        })
        self.assertEqual(text, "Elevated jitter (±21.4ms) causing micro-stutter.")
        self.assertEqual(glyph, "alert-circle")
        self.assertEqual(color, "tertiary")

    def test_evaluator_dual_acute_issues(self):
        # Dual acute issues: Local bufferbloat (42ms) + High Jitter (18.2ms)
        text, glyph, color = self.evaluator.evaluate({
            "gw_ms": 42.0,
            "dns_ms": 48.0,
            "game_ms": 60.0,
            "jitter": 18.2,
            "loss_pct": 0.0,
            "ssid": "Home_5G",
            "signal_pct": 85,
        })
        expected = (
            "High latency to local gateway (42ms). Potential home network congestion, "
            "alongside Elevated jitter (±18.2ms) causing micro-stutter."
        )
        self.assertEqual(text, expected)
        self.assertEqual(glyph, "alert-circle")
        self.assertEqual(color, "tertiary")


if __name__ == "__main__":
    unittest.main()
