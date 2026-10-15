--!nonstrict
-- Default presets and starter template for custom keybinds.

local presets = {}

presets.defaultJson = [=[{
  "categories": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "binds": [
        { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
        { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
        { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Pane" },
        { "keys": ["CTRL", "SHIFT", "["], "description": "Previous Pane" },
        { "keys": ["CTRL", "SHIFT", "]"], "description": "Next Pane" },
        { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
        { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" },
        { "keys": ["CTRL", "SHIFT", "Equal"], "description": "Increase Font Size" },
        { "keys": ["CTRL", "SHIFT", "Minus"], "description": "Decrease Font Size" }
      ]
    },
    {
      "name": "Shell / CLI",
      "icon": "terminal",
      "binds": [
        { "keys": ["CTRL", "R"], "description": "Search History (Reverse)" },
        { "keys": ["CTRL", "L"], "description": "Clear Terminal Screen" },
        { "keys": ["CTRL", "C"], "description": "Interrupt / Cancel Process" },
        { "keys": ["CTRL", "Z"], "description": "Suspend Process to Background" },
        { "keys": ["CTRL", "D"], "description": "Exit Shell / EOF" },
        { "keys": ["CTRL", "A"], "description": "Move to Start of Line" },
        { "keys": ["CTRL", "E"], "description": "Move to End of Line" },
        { "keys": ["CTRL", "U"], "description": "Delete to Start of Line" },
        { "keys": ["CTRL", "K"], "description": "Delete to End of Line" },
        { "keys": ["CTRL", "W"], "description": "Delete Word Before Cursor" }
      ]
    },
    {
      "name": "Neovim",
      "icon": "code",
      "binds": [
        { "keys": ["Leader", "f", "f"], "description": "Find Files (Telescope)" },
        { "keys": ["Leader", "f", "g"], "description": "Live Grep" },
        { "keys": ["Leader", "e"], "description": "Toggle File Explorer" },
        { "keys": ["Leader", "w"], "description": "Save Buffer" },
        { "keys": ["Leader", "q"], "description": "Quit Buffer" },
        { "keys": ["g", "d"], "description": "Go to Definition" },
        { "keys": ["K"], "description": "Hover Documentation" }
      ]
    }
  ]
}]=]

return presets
