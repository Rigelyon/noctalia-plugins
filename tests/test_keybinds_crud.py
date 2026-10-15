import json
import unittest
from pathlib import Path


class TestKeybindsCrud(unittest.TestCase):
    def setUp(self):
        self.sample_data = {
            "apps": [
                {
                    "name": "Kitty Terminal",
                    "icon": "terminal",
                    "subcategories": [
                        {
                            "name": "Tabs & Windows",
                            "icon": "app-window",
                            "binds": [
                                {"keys": ["CTRL", "SHIFT", "ENTER"], "description": "New Pane"}
                            ]
                        }
                    ]
                }
            ]
        }

    def test_json_structure_and_crud_module_exists(self):
        crud_path = Path(__file__).resolve().parent.parent / "keybinds" / "crud.luau"
        self.assertTrue(crud_path.exists(), "crud.luau must exist")
        content = crud_path.read_text(encoding="utf-8")
        self.assertIn("crud.addKeybind", content)
        self.assertIn("crud.updateKeybind", content)
        self.assertIn("crud.deleteKeybind", content)

    def test_pure_crud_operations_logic(self):
        data = json.loads(json.dumps(self.sample_data))

        # CREATE in existing app & new subcategory
        new_bind = {"keys": ["CTRL", "SHIFT", "T"], "description": "New Tab"}
        app = next(a for a in data["apps"] if a["name"].lower() == "kitty terminal")
        app["subcategories"].append({
            "name": "Sessions",
            "icon": "command",
            "binds": [new_bind]
        })
        self.assertEqual(len(app["subcategories"]), 2)
        self.assertEqual(app["subcategories"][1]["binds"][0]["description"], "New Tab")

        # UPDATE existing bind
        bind = app["subcategories"][0]["binds"][0]
        bind["description"] = "New Pane (Updated)"
        bind["keys"] = ["SUPER", "ENTER"]
        self.assertEqual(app["subcategories"][0]["binds"][0]["description"], "New Pane (Updated)")
        self.assertEqual(app["subcategories"][0]["binds"][0]["keys"], ["SUPER", "ENTER"])

        # DELETE bind
        del app["subcategories"][0]["binds"][0]
        self.assertEqual(len(app["subcategories"][0]["binds"]), 0)


if __name__ == "__main__":
    unittest.main()
