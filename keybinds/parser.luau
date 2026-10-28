--!nonstrict
-- Parser & Normalizer for Hyprland and Custom Keybinds
local parser = {}

export type KeyToken = {
  text: string,
  isPrimary: boolean,
  sepAfter: string?,
}

export type KeybindItem = {
  id: string,
  appId: string,
  appName: string,
  appIcon: string,
  subcatId: string,
  subcatName: string,
  subcatIcon: string,
  modifiers: { string },
  key: string,
  tokens: { KeyToken }?,
  keyComboText: string,
  description: string,
  source: string,
  searchIndex: string,
  sortKey: string,
  bindIndex: number?,
}

parser.KEY_TRANSLATIONS = {
  ["code:10"] = "1",
  ["code:11"] = "2",
  ["code:12"] = "3",
  ["code:13"] = "4",
  ["code:14"] = "5",
  ["code:15"] = "6",
  ["code:16"] = "7",
  ["code:17"] = "8",
  ["code:18"] = "9",
  ["code:19"] = "0",
  ["code:90"] = "Num 0",
  ["code:87"] = "Num 1",
  ["code:88"] = "Num 2",
  ["code:89"] = "Num 3",
  ["code:83"] = "Num 4",
  ["code:84"] = "Num 5",
  ["code:85"] = "Num 6",
  ["code:79"] = "Num 7",
  ["code:80"] = "Num 8",
  ["code:81"] = "Num 9",
  ["mouse:272"] = "Left Click",
  ["mouse:273"] = "Right Click",
  ["mouse:274"] = "Middle Click",
  ["mouse_up"] = "Scroll Up",
  ["mouse_down"] = "Scroll Down",
  ["bracketleft"] = "[",
  ["bracketright"] = "]",
  ["slash"] = "/",
  ["grave"] = "`",
  ["comma"] = ",",
  ["period"] = ".",
  ["equal"] = "=",
  ["minus"] = "-",
  ["xf86audioraisevolume"] = "Vol +",
  ["xf86audiolowervolume"] = "Vol -",
  ["xf86audiomute"] = "Mute",
  ["xf86audiomicmute"] = "Mic Mute",
  ["xf86monbrightnessup"] = "Bright +",
  ["xf86monbrightnessdown"] = "Bright -",
  ["xf86audioplay"] = "Play",
  ["xf86audiostop"] = "Stop",
  ["xf86audionext"] = "Next",
  ["xf86audioprev"] = "Prev",
  ["xf86sleep"] = "Sleep",
  ["xf86rfkill"] = "Airplane",
}

function parser.normalizeKey(key: string): string
  local lower = string.lower(noctalia.string.trim(key))
  return parser.KEY_TRANSLATIONS[lower] or key
end

function parser.naturalSortKey(str: string?): string
  if not str or str == "" then return "" end
  local lower = string.lower(str)
  local res = string.gsub(lower, "%d+", function(digits)
    return string.format("%08d", tonumber(digits) or 0)
  end)
  return res
end

function parser.decodeModmask(modmask: number): { string }
  local mods = {}
  if bit32.band(modmask, 64) ~= 0 then
    table.insert(mods, "SUPER")
  end
  if bit32.band(modmask, 4) ~= 0 then
    table.insert(mods, "CTRL")
  end
  if bit32.band(modmask, 8) ~= 0 then
    table.insert(mods, "ALT")
  end
  if bit32.band(modmask, 1) ~= 0 then
    table.insert(mods, "SHIFT")
  end
  return mods
end

function parser.categorizeBind(description: string, key: string, dispatcher: string?): (string, string)
  local desc = string.lower(description or "")
  local k = string.lower(key or "")
  local disp = string.lower(dispatcher or "")

  -- Window Management
  local windowTerms = { "window", "float", "pin", "fullscreen", "maximize", "focus", "swap", "resize" }
  for _, term in ipairs(windowTerms) do
    if string.find(desc, term, 1, true) then
      return "window", "app-window"
    end
  end
  if disp == "closewindow" or disp == "killactive" or disp == "togglefloating" or disp == "fullscreen"
    or disp == "pin" or disp == "movewindow" or disp == "resizeactive" or disp == "swapwindow" or disp == "movefocus" then
    return "window", "app-window"
  end

  -- Workspaces
  if string.find(desc, "workspace", 1, true) or disp == "workspace" or disp == "movetoworkspace"
    or disp == "movetoworkspacesilent" or disp == "togglespecialworkspace" then
    return "workspaces", "layout-grid"
  end

  -- Apps & Launchers
  if string.sub(desc, 1, 5) == "open " or string.find(desc, "browser", 1, true) or string.find(desc, "terminal", 1, true)
    or string.find(desc, "file manager", 1, true) or string.find(desc, "launcher", 1, true) or string.find(desc, "calculator", 1, true)
    or string.find(desc, "settings", 1, true) then
    return "apps", "rocket"
  end

  -- Media & Hardware
  local mediaTerms = { "volume", "brightness", "mic", "play", "stop", "track", "mute", "airplane", "sleep" }
  for _, term in ipairs(mediaTerms) do
    if string.find(desc, term, 1, true) then
      return "media", "volume-2"
    end
  end
  if string.sub(k, 1, 4) == "xf86" then
    return "media", "volume-2"
  end

  -- Screen & Tools
  local screenTerms = { "screenshot", "record", "ocr", "qr", "annotation", "clipboard" }
  for _, term in ipairs(screenTerms) do
    if string.find(desc, term, 1, true) then
      return "screen", "camera"
    end
  end

  -- System
  if string.find(desc, "exit", 1, true) or string.find(desc, "lock", 1, true) or string.find(desc, "power", 1, true)
    or string.find(desc, "shutdown", 1, true) or string.find(desc, "reboot", 1, true) or disp == "exit" then
    return "system", "power"
  end

  return "other", "hash"
end

parser.HYPRLAND_SUBCAT_INFO = {
  window = { icon = "app-window", labelKey = "panel.categories.window" },
  workspaces = { icon = "layout-grid", labelKey = "panel.categories.workspaces" },
  apps = { icon = "rocket", labelKey = "panel.categories.apps" },
  media = { icon = "volume-2", labelKey = "panel.categories.media" },
  screen = { icon = "camera", labelKey = "panel.categories.screen" },
  system = { icon = "power", labelKey = "panel.categories.system" },
  other = { icon = "hash", labelKey = "panel.categories.other" },
}

function parser.buildKeyComboText(modifiers: { string }, key: string): string
  local parts = {}
  for _, m in ipairs(modifiers) do
    table.insert(parts, string.upper(m))
  end
  if key ~= "" then
    table.insert(parts, string.upper(key))
  end
  return table.concat(parts, " + ")
end

function parser.parseKeyTokens(raw: any): ({ KeyToken }, string)
  local tokens: { KeyToken } = {}
  local comboText = ""

  if type(raw) == "table" then
    local parts = {}
    for _, k in ipairs(raw) do
      if type(k) == "string" and k ~= "" then
        table.insert(parts, k)
      end
    end
    -- If array contains a single preformatted string like "CTRL + A, D"
    if #parts == 1 and (string.find(parts[1], ",") or string.find(parts[1], "+") or string.find(parts[1], " ")) then
      return parser.parseKeyTokens(parts[1])
    end
    -- Otherwise treat as standard combo array
    for i, p in ipairs(parts) do
      local isLast = (i == #parts)
      table.insert(tokens, {
        text = string.upper(p),
        isPrimary = isLast,
        sepAfter = if not isLast then "+" else nil,
      })
    end
    comboText = table.concat(parts, " + ")
    return tokens, comboText
  end

  if type(raw) ~= "string" or raw == "" then
    return tokens, ""
  end

  comboText = raw

  -- Split into steps by comma `,`
  local steps = {}
  for step in string.gmatch(raw .. ",", "([^,]+),") do
    local trimmed = string.match(step, "^%s*(.-)%s*$") or ""
    if trimmed ~= "" then
      table.insert(steps, trimmed)
    end
  end

  if #steps == 0 then
    local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
    if trimmed ~= "" then
      table.insert(steps, trimmed)
    end
  end

  for sIdx, stepStr in ipairs(steps) do
    local isLastStep = (sIdx == #steps)
    if string.find(stepStr, "+", 1, true) then
      -- Simultan split by `+`
      local subKeys = {}
      for k in string.gmatch(stepStr .. "+", "([^+]+)%+") do
        local tk = string.match(k, "^%s*(.-)%s*$") or ""
        if tk ~= "" then
          table.insert(subKeys, tk)
        end
      end
      for kIdx, k in ipairs(subKeys) do
        local isLastKeyInStep = (kIdx == #subKeys)
        local isFinalAction = isLastStep and isLastKeyInStep
        local sep = nil
        if not isLastKeyInStep then
          sep = "+"
        elseif not isLastStep then
          sep = ","
        end
        table.insert(tokens, {
          text = string.upper(k),
          isPrimary = isFinalAction,
          sepAfter = sep,
        })
      end
    else
      -- Check if space-separated sequence (e.g. "Leader f f")
      local subKeys = {}
      for k in string.gmatch(stepStr, "%S+") do
        table.insert(subKeys, k)
      end
      if #subKeys > 1 then
        for kIdx, k in ipairs(subKeys) do
          local isLastKeyInStep = (kIdx == #subKeys)
          local isFinalAction = isLastStep and isLastKeyInStep
          local sep = nil
          if not isLastKeyInStep then
            sep = " "
          elseif not isLastStep then
            sep = ","
          end
          table.insert(tokens, {
            text = string.upper(k),
            isPrimary = isFinalAction,
            sepAfter = sep,
          })
        end
      else
        local k = subKeys[1] or stepStr
        local isFinalAction = isLastStep
        table.insert(tokens, {
          text = string.upper(k),
          isPrimary = isFinalAction,
          sepAfter = if not isLastStep then "," else nil,
        })
      end
    end
  end

  return tokens, comboText
end

function parser.parseCustomKeybinds(rawJson: string): { KeybindItem }
  local customItems: { KeybindItem } = {}
  if not rawJson or #rawJson == 0 then
    return customItems
  end

  local ok, data = pcall(function()
    return noctalia.json.decode(rawJson)
  end)

  if ok and type(data) == "table" then
    local appList = data.apps or data.categories
    if type(appList) == "table" then
      for appIdx, app in ipairs(appList) do
        local appName = app.name or ("App " .. tostring(appIdx))
        local appIcon = app.icon or "terminal"
        if appIcon == "terminal_window" then
          appIcon = "terminal"
        end
        local appId = string.lower(appName)

        if type(app.subcategories) == "table" then
          for subIdx, sub in ipairs(app.subcategories) do
            local subName = sub.name or "General"
            local subIcon = sub.icon or "command"
            local subId = string.lower(subName)
            if type(sub.binds) == "table" then
              for bIdx, b in ipairs(sub.binds) do
                local tokens, combo = parser.parseKeyTokens(b.keys)
                local mods = {}
                local primaryKey = ""
                for _, tok in ipairs(tokens) do
                  if tok.isPrimary then
                    primaryKey = tok.text
                  else
                    table.insert(mods, tok.text)
                  end
                end
                if primaryKey == "" and #tokens > 0 then
                  primaryKey = tokens[#tokens].text
                end
                local desc = b.description or ""
                table.insert(customItems, {
                  id = "custom-" .. appId .. "-" .. tostring(subIdx) .. "-" .. tostring(bIdx),
                  appId = appId,
                  appName = appName,
                  appIcon = appIcon,
                  subcatId = subId,
                  subcatName = subName,
                  subcatIcon = subIcon,
                  modifiers = mods,
                  key = primaryKey,
                  tokens = tokens,
                  keyComboText = combo,
                  description = desc,
                  source = "custom",
                  searchIndex = string.lower(appName .. " " .. subName .. " " .. desc .. " " .. combo),
                  sortKey = parser.naturalSortKey(desc),
                  bindIndex = bIdx,
                })
              end
            end
          end
        elseif type(app.binds) == "table" then
          for bIdx, b in ipairs(app.binds) do
            local tokens, combo = parser.parseKeyTokens(b.keys)
            local mods = {}
            local primaryKey = ""
            for _, tok in ipairs(tokens) do
              if tok.isPrimary then
                primaryKey = tok.text
              else
                table.insert(mods, tok.text)
              end
            end
            if primaryKey == "" and #tokens > 0 then
              primaryKey = tokens[#tokens].text
            end
            local desc = b.description or ""
            local subName = b.subcategory or b.subcat or b.category or "General"
            local subIcon = b.subcategoryIcon or b.icon or "command"
            local subId = string.lower(subName)
            table.insert(customItems, {
              id = "custom-" .. appId .. "-" .. tostring(bIdx),
              appId = appId,
              appName = appName,
              appIcon = appIcon,
              subcatId = subId,
              subcatName = subName,
              subcatIcon = subIcon,
              modifiers = mods,
              key = primaryKey,
              tokens = tokens,
              keyComboText = combo,
              description = desc,
              source = "custom",
              searchIndex = string.lower(appName .. " " .. subName .. " " .. desc .. " " .. combo),
              sortKey = parser.naturalSortKey(desc),
              bindIndex = bIdx,
            })
          end
        end
      end
    end
  end

  return customItems
end

return parser
