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
            { "keys": ["CTRL", "SHIFT", "Enter"], "description": "New Window" },
            { "keys": ["CTRL", "SHIFT", "N"], "description": "New OS Window" },
            { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Window" },
            { "keys": ["CTRL", "SHIFT", "]"], "description": "Next Window" },
            { "keys": ["CTRL", "SHIFT", "["], "description": "Previous Window" },
            { "keys": ["CTRL", "SHIFT", "F"], "description": "Move Window Forward" },
            { "keys": ["CTRL", "SHIFT", "B"], "description": "Move Window Backward" },
            { "keys": ["CTRL", "SHIFT", "`"], "description": "Move Window to Top" },
            { "keys": ["CTRL", "SHIFT", "R"], "description": "Resize Window" },
            { "keys": ["CTRL", "SHIFT", "F7"], "description": "Visually Focus Window" },
            { "keys": ["CTRL", "SHIFT", "F8"], "description": "Visually Swap Window" },
            { "keys": ["CTRL", "SHIFT", "1"], "description": "Focus Window 1" },
            { "keys": ["CTRL", "SHIFT", "2"], "description": "Focus Window 2" },
            { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
            { "keys": ["CTRL", "SHIFT", "Q"], "description": "Close Tab" },
            { "keys": ["CTRL", "SHIFT", "Right"], "description": "Next Tab" },
            { "keys": ["CTRL", "SHIFT", "Left"], "description": "Previous Tab" },
            { "keys": ["CTRL", "SHIFT", "."], "description": "Move Tab Forward" },
            { "keys": ["CTRL", "SHIFT", ","], "description": "Move Tab Backward" },
            { "keys": ["CTRL", "SHIFT", "ALT", "T"], "description": "Set Tab Title" },
            { "keys": ["CTRL", "SHIFT", "L"], "description": "Next Layout" }
          ]
        },
        {
          "name": "Scrolling",
          "icon": "history",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "Up"], "description": "Scroll Line Up" },
            { "keys": ["CTRL", "SHIFT", "Down"], "description": "Scroll Line Down" },
            { "keys": ["CTRL", "SHIFT", "Page_Up"], "description": "Scroll Page Up" },
            { "keys": ["CTRL", "SHIFT", "Page_Down"], "description": "Scroll Page Down" },
            { "keys": ["CTRL", "SHIFT", "Home"], "description": "Scroll to Top" },
            { "keys": ["CTRL", "SHIFT", "End"], "description": "Scroll to Bottom" },
            { "keys": ["CTRL", "SHIFT", "Z"], "description": "Previous Shell Prompt" },
            { "keys": ["CTRL", "SHIFT", "X"], "description": "Next Shell Prompt" },
            { "keys": ["CTRL", "SHIFT", "H"], "description": "Browse Scrollback in Less" },
            { "keys": ["CTRL", "SHIFT", "G"], "description": "Browse Last Command Output" },
            { "keys": ["CTRL", "SHIFT", "/"], "description": "Search Scrollback in Less" }
          ]
        },
        {
          "name": "Clipboard",
          "icon": "clipboard",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
            { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" },
            { "keys": ["CTRL", "SHIFT", "S"], "description": "Paste from Selection" },
            { "keys": ["CTRL", "SHIFT", "O"], "description": "Pass Selection to Program" }
          ]
        },
        {
          "name": "Font & Layout",
          "icon": "typography",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "Equal"], "description": "Increase Font Size" },
            { "keys": ["CTRL", "SHIFT", "Minus"], "description": "Decrease Font Size" },
            { "keys": ["CTRL", "SHIFT", "Backspace"], "description": "Restore Font Size" },
            { "keys": ["CTRL", "SHIFT", "F11"], "description": "Toggle Fullscreen" },
            { "keys": ["CTRL", "SHIFT", "F10"], "description": "Toggle Maximized" },
            { "keys": ["CTRL", "SHIFT", "A > M"], "description": "Increase Background Opacity" },
            { "keys": ["CTRL", "SHIFT", "A > L"], "description": "Decrease Background Opacity" },
            { "keys": ["CTRL", "SHIFT", "A > 1"], "description": "Full Background Opacity" },
            { "keys": ["CTRL", "SHIFT", "A > D"], "description": "Reset Background Opacity" }
          ]
        },
        {
          "name": "Configuration & Tools",
          "icon": "settings",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "F1"], "description": "Show Documentation" },
            { "keys": ["CTRL", "SHIFT", "F2"], "description": "Edit kitty.conf" },
            { "keys": ["CTRL", "SHIFT", "F3"], "description": "Open Command Palette" },
            { "keys": ["CTRL", "SHIFT", "F5"], "description": "Reload kitty.conf" },
            { "keys": ["CTRL", "SHIFT", "F6"], "description": "Debug kitty.conf" },
            { "keys": ["CTRL", "SHIFT", "Escape"], "description": "Open Kitty Shell" },
            { "keys": ["CTRL", "SHIFT", "U"], "description": "Input Unicode Character" },
            { "keys": ["CTRL", "SHIFT", "E"], "description": "Open URL in Web Browser" },
            { "keys": ["CTRL", "SHIFT", "Delete"], "description": "Reset Terminal" }
          ]
        }
      ]
    },
    {
      "name": "Shell / CLI",
      "icon": "terminal",
      "subcategories": [
        {
          "name": "Navigation",
          "icon": "arrow-right",
          "binds": [
            { "keys": ["CTRL", "A"], "description": "Move to Start of Line" },
            { "keys": ["CTRL", "E"], "description": "Move to End of Line" },
            { "keys": ["CTRL", "F"], "description": "Move Forward 1 Character" },
            { "keys": ["CTRL", "B"], "description": "Move Backward 1 Character" },
            { "keys": ["ALT", "F"], "description": "Move Forward 1 Word" },
            { "keys": ["ALT", "B"], "description": "Move Backward 1 Word" },
            { "keys": ["CTRL", "X", "X"], "description": "Toggle Cursor & Line Start" }
          ]
        },
        {
          "name": "History & Search",
          "icon": "history",
          "binds": [
            { "keys": ["CTRL", "R"], "description": "Search History (Reverse)" },
            { "keys": ["CTRL", "S"], "description": "Search History Forward" },
            { "keys": ["CTRL", "G"], "description": "Abort History Search" },
            { "keys": ["CTRL", "P"], "description": "Previous Command (History Up)" },
            { "keys": ["CTRL", "N"], "description": "Next Command (History Down)" },
            { "keys": ["ALT", "."], "description": "Insert Last Argument of Prev Command" }
          ]
        },
        {
          "name": "Line Editing",
          "icon": "edit",
          "binds": [
            { "keys": ["CTRL", "U"], "description": "Delete to Start of Line" },
            { "keys": ["CTRL", "K"], "description": "Delete to End of Line" },
            { "keys": ["CTRL", "W"], "description": "Delete Word Before Cursor" },
            { "keys": ["ALT", "D"], "description": "Delete Word After Cursor" },
            { "keys": ["ALT", "Backspace"], "description": "Delete Word Before Cursor" },
            { "keys": ["CTRL", "Y"], "description": "Paste (Yank) Last Deleted Text" },
            { "keys": ["CTRL", "T"], "description": "Swap Previous Two Characters" },
            { "keys": ["ALT", "T"], "description": "Swap Previous Two Words" },
            { "keys": ["ALT", "U"], "description": "Uppercase Word After Cursor" },
            { "keys": ["ALT", "L"], "description": "Lowercase Word After Cursor" },
            { "keys": ["ALT", "C"], "description": "Capitalize Word After Cursor" },
            { "keys": ["CTRL", "_"], "description": "Undo Last Edit" }
          ]
        },
        {
          "name": "Process Control",
          "icon": "player-stop",
          "binds": [
            { "keys": ["CTRL", "C"], "description": "Interrupt / Cancel Process (SIGINT)" },
            { "keys": ["CTRL", "Z"], "description": "Suspend Process to Background (SIGTSTP)" },
            { "keys": ["CTRL", "D"], "description": "Exit Shell / EOF" },
            { "keys": ["CTRL", "\\"], "description": "Quit with Core Dump (SIGQUIT)" }
          ]
        },
        {
          "name": "Screen & Output",
          "icon": "terminal",
          "binds": [
            { "keys": ["CTRL", "L"], "description": "Clear Terminal Screen" },
            { "keys": ["CTRL", "S"], "description": "Pause Terminal Output (XOFF)" },
            { "keys": ["CTRL", "Q"], "description": "Resume Terminal Output (XON)" }
          ]
        },
        {
          "name": "Terminal Emulator (General)",
          "icon": "app-window",
          "binds": [
            { "keys": ["CTRL", "SHIFT", "C"], "description": "Copy to Clipboard" },
            { "keys": ["CTRL", "SHIFT", "V"], "description": "Paste from Clipboard" },
            { "keys": ["CTRL", "SHIFT", "T"], "description": "New Tab" },
            { "keys": ["CTRL", "SHIFT", "W"], "description": "Close Tab" },
            { "keys": ["CTRL", "SHIFT", "N"], "description": "New Window" },
            { "keys": ["CTRL", "SHIFT", "Q"], "description": "Close Window / Exit" },
            { "keys": ["CTRL", "SHIFT", "F"], "description": "Find / Search in Terminal" },
            { "keys": ["CTRL", "SHIFT", "+"], "description": "Zoom In" },
            { "keys": ["CTRL", "-"], "description": "Zoom Out" },
            { "keys": ["CTRL", "0"], "description": "Reset Zoom" },
            { "keys": ["F11"], "description": "Toggle Fullscreen" }
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
