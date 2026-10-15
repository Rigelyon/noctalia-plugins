import json
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "keybinds")


def decode_modmask(modmask: int) -> list[str]:
    mods = []
    if modmask & 64:
        mods.append("SUPER")
    if modmask & 4:
        mods.append("CTRL")
    if modmask & 8:
        mods.append("ALT")
    if modmask & 1:
        mods.append("SHIFT")
    return mods


KEY_TRANSLATIONS = {
    "code:10": "1",
    "code:11": "2",
    "code:12": "3",
    "code:13": "4",
    "code:14": "5",
    "code:15": "6",
    "code:16": "7",
    "code:17": "8",
    "code:18": "9",
    "code:19": "0",
    "code:90": "Num 0",
    "code:87": "Num 1",
    "code:88": "Num 2",
    "code:89": "Num 3",
    "code:83": "Num 4",
    "code:84": "Num 5",
    "code:85": "Num 6",
    "code:79": "Num 7",
    "code:80": "Num 8",
    "code:81": "Num 9",
    "mouse:272": "Left Click",
    "mouse:273": "Right Click",
    "mouse:274": "Middle Click",
    "mouse_up": "Scroll Up",
    "mouse_down": "Scroll Down",
    "bracketleft": "[",
    "bracketright": "]",
    "slash": "/",
    "grave": "`",
    "comma": ",",
    "period": ".",
    "equal": "=",
    "minus": "-",
    "xf86audioraisevolume": "Vol +",
    "xf86audiolowervolume": "Vol -",
    "xf86audiomute": "Mute",
    "xf86audiomicmute": "Mic Mute",
    "xf86monbrightnessup": "Bright +",
    "xf86monbrightnessdown": "Bright -",
    "xf86audioplay": "Play",
    "xf86audiostop": "Stop",
    "xf86audionext": "Next",
    "xf86audioprev": "Prev",
    "xf86sleep": "Sleep",
    "xf86rfkill": "Airplane",
}


def normalize_key(key: str) -> str:
    k_lower = key.lower().strip()
    return KEY_TRANSLATIONS.get(k_lower, key)


def categorize_bind(description: str, key: str, dispatcher: str = "", arg: str = "") -> str:
    desc = description.lower()
    k_lower = key.lower()

    # Window Management
    for term in ["window", "float", "pin", "fullscreen", "maximize", "focus", "swap", "resize"]:
        if term in desc:
            return "Window"
    if dispatcher in ["closewindow", "killactive", "togglefloating", "fullscreen", "pin", "movewindow", "resizeactive", "swapwindow", "movefocus"]:
        return "Window"

    # Workspaces
    if "workspace" in desc or dispatcher in ["workspace", "movetoworkspace", "movetoworkspacesilent", "togglespecialworkspace"]:
        return "Workspaces"

    # Apps & Launchers
    if desc.startswith("open ") or any(t in desc for t in ["browser", "terminal", "file manager", "launcher", "calculator", "settings"]):
        return "Apps"

    # Media & Hardware
    if any(t in desc for t in ["volume", "brightness", "mic", "play", "stop", "track", "mute", "airplane", "sleep"]) or k_lower.startswith("xf86"):
        return "Media"

    # Screen & Tools
    if any(t in desc for t in ["screenshot", "record", "ocr", "qr", "annotation", "clipboard"]):
        return "Screen & Tools"

    # System
    if any(t in desc for t in ["exit", "lock", "power", "shutdown", "reboot"]) or dispatcher == "exit":
        return "System"

    return "Other"


class TestKeybindsParser(unittest.TestCase):
    def test_modmask_decoding(self):
        self.assertEqual(decode_modmask(64), ["SUPER"])
        self.assertEqual(decode_modmask(65), ["SUPER", "SHIFT"])
        self.assertEqual(decode_modmask(68), ["SUPER", "CTRL"])
        self.assertEqual(decode_modmask(72), ["SUPER", "ALT"])
        self.assertEqual(decode_modmask(73), ["SUPER", "ALT", "SHIFT"])
        self.assertEqual(decode_modmask(76), ["SUPER", "CTRL", "ALT"])
        self.assertEqual(decode_modmask(0), [])

    def test_key_normalization(self):
        self.assertEqual(normalize_key("code:10"), "1")
        self.assertEqual(normalize_key("code:19"), "0")
        self.assertEqual(normalize_key("mouse:272"), "Left Click")
        self.assertEqual(normalize_key("bracketleft"), "[")
        self.assertEqual(normalize_key("XF86AudioRaiseVolume"), "Vol +")
        self.assertEqual(normalize_key("Return"), "Return")

    def test_categorization(self):
        self.assertEqual(categorize_bind("Open Terminal", "T"), "Apps")
        self.assertEqual(categorize_bind("Close Active Window", "Q"), "Window")
        self.assertEqual(categorize_bind("Float Window", "P"), "Window")
        self.assertEqual(categorize_bind("Workspace 1", "code:10"), "Workspaces")
        self.assertEqual(categorize_bind("Toggle Special Workspace 0", "code:90"), "Workspaces")
        self.assertEqual(categorize_bind("Volume Up", "XF86AudioRaiseVolume"), "Media")
        self.assertEqual(categorize_bind("Screenshot Area", "Print"), "Screen & Tools")
        self.assertEqual(categorize_bind("Exit Hyprland", "Delete"), "System")
        self.assertEqual(categorize_bind("Unknown custom command", "X"), "Other")

    def test_presets_file_exists_and_valid_json(self):
        presets_path = os.path.join(PLUGIN_DIR, "presets.luau")
        self.assertTrue(os.path.isfile(presets_path), "presets.luau must exist")
        with open(presets_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("return presets", content)
        self.assertIn("Kitty Terminal", content)
        self.assertIn("Shell / CLI", content)
        self.assertIn("subcategories", content)
        self.assertIn("Tabs & Windows", content)


    def test_natural_sorting(self):
        import re
        def natural_sort_key(s):
            return re.sub(r'\d+', lambda m: f"{int(m.group(0)):08d}", s.lower())

        items = [
            "Move Window Silently to Workspace 1",
            "Move Window Silently to Workspace 10",
            "Move Window Silently to Workspace 2",
            "Move Window Silently to Workspace 3",
            "Move Window Silently to Workspace 9",
        ]
        sorted_items = sorted(items, key=natural_sort_key)
        self.assertEqual(sorted_items[0], "Move Window Silently to Workspace 1")
        self.assertEqual(sorted_items[1], "Move Window Silently to Workspace 2")
        self.assertEqual(sorted_items[2], "Move Window Silently to Workspace 3")
        self.assertEqual(sorted_items[3], "Move Window Silently to Workspace 9")
        self.assertEqual(sorted_items[4], "Move Window Silently to Workspace 10")


if __name__ == "__main__":
    unittest.main()
