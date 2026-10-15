--!nonstrict
-- Default presets and starter template for custom keybinds.

local presets = {}

presets.defaultJson = [=[{
  "apps": [
    {
      "name": "Kitty Terminal",
      "icon": "terminal",
      "subcategories": [
        {
          "name": "Tabs & Windows",
          "icon": "app-window",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Pane" },
            { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
            { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Pane" },
            { "keys": ["CTRL", "SHIFT", "["], "description": "Previous Pane" },
            { "keys": ["CTRL", "SHIFT", "]"], "description": "Next Pane" }
          ]
        },
        {
          "name": "Clipboard",
          "icon": "clipboard",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
            { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" }
          ]
        },
        {
          "name": "Font & Layout",
          "icon": "typography",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "Equal"], "description": "Increase Font Size" },
            { "keys": ["CTRL", "SHIFT", "Minus"], "description": "Decrease Font Size" }
          ]
        }
      ]
    },
    {
      "name": "Shell / CLI",
      "icon": "terminal",
      "subcategories": [
        {
          "name": "Navigation & History",
          "icon": "history",
          "binds": [
            { "keys": ["CTRL", "R"], "description": "Search History (Reverse)" },
            { "keys": ["CTRL", "L"], "description": "Clear Terminal Screen" },
            { "keys": ["CTRL", "A"], "description": "Move to Start of Line" },
            { "keys": ["CTRL", "E"], "description": "Move to End of Line" }
          ]
        },
        {
          "name": "Process Control",
          "icon": "player-stop",
          "binds": [
            { "keys": ["CTRL", "C"], "description": "Interrupt / Cancel Process" },
            { "keys": ["CTRL", "Z"], "description": "Suspend Process to Background" },
            { "keys": ["CTRL", "D"], "description": "Exit Shell / EOF" }
          ]
        },
        {
          "name": "Line Editing",
          "icon": "edit",
          "binds": [
            { "keys": ["CTRL", "U"], "description": "Delete to Start of Line" },
            { "keys": ["CTRL", "K"], "description": "Delete to End of Line" },
            { "keys": ["CTRL", "W"], "description": "Delete Word Before Cursor" }
          ]
        }
      ]
    },
    {
      "name": "Neovim",
      "icon": "code",
      "subcategories": [
        {
          "name": "Navigation & Search",
          "icon": "search",
          "binds": [
            { "keys": ["Leader", "f", "f"], "description": "Find Files (Telescope)" },
            { "keys": ["Leader", "f", "g"], "description": "Live Grep" },
            { "keys": ["g", "d"], "description": "Go to Definition" },
            { "keys": ["K"], "description": "Hover Documentation" }
          ]
        },
        {
          "name": "Buffer & File",
          "icon": "file-text",
          "binds": [
            { "keys": ["Leader", "e"], "description": "Toggle File Explorer" },
            { "keys": ["Leader", "w"], "description": "Save Buffer" },
            { "keys": ["Leader", "q"], "description": "Quit Buffer" }
          ]
        }
      ]
    }
  ]
}]=]

return presets
