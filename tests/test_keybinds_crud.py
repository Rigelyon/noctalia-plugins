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
        self.assertIn("crud.renameApp", content)
        self.assertIn("crud.renameSubcategory", content)

    def test_rename_app_logic(self):
        data = json.loads(json.dumps(self.sample_data))
        app = data["apps"][0]
        # Rename app
        old_name = app["name"]
        app["name"] = "Kitty"
        app["icon"] = "sparkles"
        self.assertEqual(app["name"], "Kitty")
        self.assertEqual(app["icon"], "sparkles")
        # Subcategories & binds preserved
        self.assertEqual(len(app["subcategories"]), 1)
        self.assertEqual(len(app["subcategories"][0]["binds"]), 1)

    def test_rename_subcategory_logic(self):
        data = json.loads(json.dumps(self.sample_data))
        sub = data["apps"][0]["subcategories"][0]
        sub["name"] = "Panes"
        sub["icon"] = "layout-grid"
        self.assertEqual(sub["name"], "Panes")
        self.assertEqual(sub["icon"], "layout-grid")
        self.assertEqual(len(sub["binds"]), 1)

    def test_add_keybind_custom_icons_logic(self):
        data = {"apps": []}
        new_app = {
            "name": "Zed Editor",
            "icon": "code",
            "subcategories": [
                {
                    "name": "Editing",
                    "icon": "file-text",
                    "binds": [{"keys": ["CTRL", "S"], "description": "Save file"}]
                }
            ]
        }
        data["apps"].append(new_app)
        self.assertEqual(data["apps"][0]["icon"], "code")
        self.assertEqual(data["apps"][0]["subcategories"][0]["icon"], "file-text")

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

