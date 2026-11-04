import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
PANEL_FILE = os.path.join(PLUGIN_DIR, "panel.luau")


class TestNetRadarPanel(unittest.TestCase):
    def test_panel_file_exists(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")

    def test_panel_uses_native_graph_and_hud_elements(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use native ui.graph
        self.assertIn("ui.graph", content)
        # Must have retest trigger
        self.assertIn("executeProbe", content)
        # Must throttle renders to protect CPU budget
        self.assertIn("nowMs", content)
        # Must render segmented level meter
        self.assertIn("renderSegmentedMeter", content)

    def test_panel_tactical_hud_design_constraints(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must adhere to tactical HUD design: sharp/subtle 4px borders with left accent border
        self.assertIn("radius = 4", content)
        # Must NOT use rounded pill badges (e.g. radius 99, 999, full)
        self.assertNotIn("radius = 99", content)
        self.assertNotIn("radius = 999", content)
        self.assertNotIn('radius = "full"', content)

        # Segmented meter bars count and color states (Noctalia MD3 palette)
        self.assertIn("bars = 5", content)
        self.assertIn('"primary"', content)
        self.assertIn('"tertiary"', content)
        self.assertIn('"error"', content)
        self.assertIn('"outline"', content)

    def test_panel_multi_target_and_wifi_diagnostics(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Multi-target cards (Gateway, DNS, Game)
        self.assertIn("target_gateway", content)
        self.assertIn("target_dns", content)
        self.assertIn("target_game", content)
        self.assertIn("state.gwMs", content)
        self.assertIn("state.dnsMs", content)
        self.assertIn("state.gameMs", content)
        self.assertIn("state.lossPct", content)

        # Wi-Fi physical link diagnostics
        self.assertIn("state.ssid", content)
        self.assertIn("state.freqMhz", content)
        self.assertIn("state.signalPct", content)
        self.assertIn("state.rateMbps", content)

    def test_panel_cpu_budget_and_render_throttling(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Render throttler to respect Luau CPU budget (>= 100ms)
        self.assertIn("throttledRender", content)
        self.assertIn("100", content)
        self.assertIn("state.subscribe", content)
        self.assertIn("function update(", content)

    def test_no_lua_syntax_gotchas(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for idx, line in enumerate(lines[1:], start=2):
            trimmed = line.strip()
            # Lua does not use ! for negation (e.g. !var, (!var))
            self.assertNotIn("(!", trimmed, f"Line {idx} uses '(!' instead of '(not '")
            self.assertFalse(trimmed.startswith("!"), f"Line {idx} starts with '!' instead of 'not '")
            self.assertNotIn("!=", trimmed, f"Line {idx} uses '!=' instead of '~='")
            self.assertNotIn("&&", trimmed, f"Line {idx} uses '&&' instead of 'and'")
            self.assertNotIn("||", trimmed, f"Line {idx} uses '||' instead of 'or'")

    def test_panel_probe_timeout_accounting(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('state.processProbe("none|none|none|none|0|0|0|none")', content)

    def test_panel_second_ticks_lifecycle(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("panel.setWantsSecondTicks(true)", content)
        self.assertIn("panel.setWantsSecondTicks(false)", content)
        self.assertIn("function onOpen()", content)
        self.assertIn("function onClose()", content)

    def test_panel_preset_dynamic_cycle(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use native ui.select for region/preset dropdown
        self.assertIn("ui.select", content)
        # Must NOT use fake dropdown button with unicode arrow
        self.assertNotIn("▾", content)
        self.assertIn("selectedIndex", content)
        self.assertIn("options", content)
        self.assertIn("state.setPreset(", content)
        self.assertIn("presets.LIST", content)

    def test_panel_smart_diagnostic_banner(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must call state.getDiagnostics() to get dynamic text, glyph, and color
        self.assertIn("state.getDiagnostics()", content)
        self.assertIn("diagGlyph", content)
        self.assertIn("diagColor", content)
        self.assertIn("name = diagGlyph", content)
        self.assertIn("color = diagColor", content)

    def test_panel_combined_telemetry_graph_and_legend(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use dual-line graph with values2 and color2 for Latency + Jitter
        self.assertIn("values2 =", content)
        self.assertIn("color2 =", content)
        self.assertIn('"#38bdf8"', content)  # Cyan Jitter
        self.assertIn('"#ef4444"', content)  # Red Loss
        self.assertIn('"#f59e0b"', content)
        self.assertIn("NO_INTERNET", content)
        self.assertIn("CAPTIVE_PORTAL", content)
        # Legend indicators present without toggle buttons
        self.assertIn('"RTT"', content)
        self.assertIn('"Jitter"', content)
        self.assertIn('"Loss"', content)



if __name__ == "__main__":
    unittest.main()
