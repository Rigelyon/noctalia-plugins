import os
import unittest

WIDGET_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "widget.luau")


class TestPinboardWidget(unittest.TestCase):
    def test_widget_file_exists_and_callbacks(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "Missing widget.luau")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check standard Noctalia bar widget callbacks
        self.assertIn("function onClick()", content)
        self.assertIn("function onRightClick()", content)
        self.assertIn("function onScroll(", content)

        # Check presentation APIs
        self.assertIn("barWidget.setGlyph(", content)
        self.assertIn("barWidget.setText(", content)
        self.assertIn("barWidget.setTooltip(", content)

        # Check interaction triggers
        self.assertIn("noctalia.togglePanel(", content)
        self.assertIn("state.toggleGhost(", content)
        self.assertIn("state.nextItem(", content)
        self.assertIn("state.prevItem(", content)


if __name__ == "__main__":
    unittest.main()
