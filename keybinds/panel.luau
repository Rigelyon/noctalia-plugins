--!nonstrict
-- Keybinds Cheatsheet Panel for Noctalia
-- Displays active Hyprland bindings and manual custom shortcuts categorized per app with subcategories.

local presets = require("./presets.luau")
local crud = require("./crud.luau")

type KeybindItem = {
  id: string,
  appId: string,
  appName: string,
  appIcon: string,
  subcatId: string,
  subcatName: string,
  subcatIcon: string,
  modifiers: { string },
  key: string,
  keyComboText: string,
  description: string,
  source: string,
  searchIndex: string,
  sortKey: string,
  bindIndex: number?,
}

local items: { KeybindItem } = {}
local activeApp = "hyprland"
local searchQuery = ""
local copiedId: string? = nil
local hyprAvailable = true
local isLoading = false
local cornerRadiusScale = 1.0
local gridColumns = "3"
local customFilePath = ""

-- Edit mode & Modal form state
local isEditMode = false
local isModalOpen = false
local modalMode = "create" -- "create" or "edit"
local editTarget = {
  origApp = "",
  origSubcat = "",
  origBindIdx = 0,
}
local formApp = ""
local formSubcat = ""
local formDesc = ""
local formKey = ""
local formMods = {
  SUPER = false,
  CTRL = false,
  ALT = false,
  SHIFT = false,
}
local formError = ""

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- Key translations mapping
local KEY_TRANSLATIONS = {
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

local function normalizeKey(key: string): string
  local lower = string.lower(noctalia.string.trim(key))
  return KEY_TRANSLATIONS[lower] or key
end

local function naturalSortKey(str: string?): string
  if not str or str == "" then return "" end
  local lower = string.lower(str)
  local res = string.gsub(lower, "%d+", function(digits)
    return string.format("%08d", tonumber(digits) or 0)
  end)
  return res
end

local function decodeModmask(modmask: number): { string }
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

local function categorizeBind(description: string, key: string, dispatcher: string?): (string, string)
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

local HYPRLAND_SUBCAT_INFO = {
  window = { icon = "app-window", labelKey = "panel.categories.window" },
  workspaces = { icon = "layout-grid", labelKey = "panel.categories.workspaces" },
  apps = { icon = "rocket", labelKey = "panel.categories.apps" },
  media = { icon = "volume-2", labelKey = "panel.categories.media" },
  screen = { icon = "camera", labelKey = "panel.categories.screen" },
  system = { icon = "power", labelKey = "panel.categories.system" },
  other = { icon = "hash", labelKey = "panel.categories.other" },
}

local function buildKeyComboText(modifiers: { string }, key: string): string
  local parts = {}
  for _, m in ipairs(modifiers) do
    table.insert(parts, string.upper(m))
  end
  if key ~= "" then
    table.insert(parts, string.upper(key))
  end
  return table.concat(parts, " + ")
end

local function getCustomFilePath(): string
  local rawPath = customFilePath
  if rawPath == "" then
    local cfgPath = noctalia.getConfig("custom_file_path")
    if cfgPath and cfgPath ~= "" then
      rawPath = cfgPath
    else
      local dataDir = noctalia.pluginDataDir()
      rawPath = (dataDir and dataDir ~= "") and (dataDir .. "/custom_keybinds.json") or "~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json"
    end
  end
  return noctalia.expandPath(rawPath)
end

local function saveCustomJson(store: any): boolean
  local path = getCustomFilePath()
  local ok, encoded = pcall(function()
    return noctalia.json.encode(store, true)
  end)
  if not ok or not encoded then
    return false
  end
  local dir = string.match(path, "^(.*)/[^/]+$")
  if dir then
    noctalia.mkdirAll(dir)
  end
  return noctalia.writeFile(path, encoded)
end

local function loadCustomKeybinds(): { KeybindItem }
  local customItems: { KeybindItem } = {}
  local path = getCustomFilePath()

  -- Create default file if absent
  if not noctalia.fileExists(path) then
    local dir = string.match(path, "^(.*)/[^/]+$")
    if dir then
      noctalia.mkdirAll(dir)
    end
    noctalia.writeFile(path, presets.defaultJson)
  end

  local raw = noctalia.readFile(path)
  if not raw then
    return customItems
  end

  local ok, data = pcall(function()
    return noctalia.json.decode(raw)
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
                local keys = b.keys or {}
                local mods = {}
                local primaryKey = ""
                if #keys > 0 then
                  for kIdx = 1, #keys - 1 do
                    table.insert(mods, string.upper(keys[kIdx]))
                  end
                  primaryKey = string.upper(keys[#keys])
                end
                local desc = b.description or ""
                local combo = buildKeyComboText(mods, primaryKey)
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
                  keyComboText = combo,
                  description = desc,
                  source = "custom",
                  searchIndex = string.lower(appName .. " " .. subName .. " " .. desc .. " " .. combo),
                  sortKey = naturalSortKey(desc),
                  bindIndex = bIdx,
                })
              end
            end
          end
        elseif type(app.binds) == "table" then
          for bIdx, b in ipairs(app.binds) do
            local keys = b.keys or {}
            local mods = {}
            local primaryKey = ""
            if #keys > 0 then
              for kIdx = 1, #keys - 1 do
                table.insert(mods, string.upper(keys[kIdx]))
              end
              primaryKey = string.upper(keys[#keys])
            end
            local desc = b.description or ""
            local subName = b.subcategory or b.subcat or b.category or "General"
            local subIcon = b.subcategoryIcon or b.icon or "command"
            local subId = string.lower(subName)
            local combo = buildKeyComboText(mods, primaryKey)
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
              keyComboText = combo,
              description = desc,
              source = "custom",
              searchIndex = string.lower(appName .. " " .. subName .. " " .. desc .. " " .. combo),
              sortKey = naturalSortKey(desc),
              bindIndex = bIdx,
            })
          end
        end
      end
    end
  end

  return customItems
end

local function refreshAllBinds()
  isLoading = true
  render()

  local customList = loadCustomKeybinds()
  items = {}

  -- Append custom list first
  for _, item in ipairs(customList) do
    table.insert(items, item)
  end

  -- Run hyprctl binds -j
  noctalia.runAsync({ "hyprctl", "binds", "-j" }, function(res)
    isLoading = false
    if res.exitCode == 0 and #res.stdout > 0 then
      hyprAvailable = true
      local ok, rawBinds = pcall(function()
        return noctalia.json.decode(res.stdout)
      end)
      if ok and type(rawBinds) == "table" then
        for idx, b in ipairs(rawBinds) do
          local rawKey = b.key or ""
          local desc = b.description or ""
          if desc == "" and b.dispatcher then
            desc = b.dispatcher .. (b.arg and (" " .. b.arg) or "")
          end

          -- If key is missing from JSON serialization, restore key from keycode or description
          if rawKey == "" and b.keycode and b.keycode > 0 then
            rawKey = "code:" .. tostring(b.keycode)
          end
          if rawKey == "" then
            local specNum = string.match(desc, "Special Workspace (%d+)")
            if specNum then
              rawKey = "Num " .. specNum
            else
              local wsNum = string.match(desc, "Workspace (%d+)")
              if wsNum then
                rawKey = (wsNum == "10") and "0" or wsNum
              end
            end
          end

          local normKey = string.upper(normalizeKey(rawKey))
          local mods = decodeModmask(b.modmask or 0)
          local catKey, catIcon = categorizeBind(desc, normKey, b.dispatcher)
          local info = HYPRLAND_SUBCAT_INFO[catKey]
          local subcatName = (info and tr(info.labelKey)) or catKey
          local subcatIcon = (info and info.icon) or catIcon
          local combo = buildKeyComboText(mods, normKey)

          table.insert(items, {
            id = "hypr-" .. tostring(idx),
            appId = "hyprland",
            appName = "Hyprland",
            appIcon = "layout-grid",
            subcatId = catKey,
            subcatName = subcatName,
            subcatIcon = subcatIcon,
            modifiers = mods,
            key = normKey,
            keyComboText = combo,
            description = desc,
            source = "hyprland",
            searchIndex = string.lower("hyprland " .. subcatName .. " " .. desc .. " " .. combo),
            sortKey = naturalSortKey(desc),
          })
        end
      end
    else
      hyprAvailable = false
    end
    render()
  end, 3000)
end

-- App list collection
local function getAppList(): { { id: string, name: string, icon: string, count: number } }
  local apps = {}
  local seen = {}

  local hyprCount = 0
  for _, item in ipairs(items) do
    if item.appId == "hyprland" then
      hyprCount = hyprCount + 1
    end
  end
  if hyprCount > 0 or hyprAvailable then
    table.insert(apps, {
      id = "hyprland",
      name = "Hyprland",
      icon = "layout-grid",
      count = hyprCount,
    })
    seen["hyprland"] = true
  end

  for _, item in ipairs(items) do
    if not seen[item.appId] then
      seen[item.appId] = true
      local cnt = 0
      for _, it in ipairs(items) do
        if it.appId == item.appId then
          cnt = cnt + 1
        end
      end
      table.insert(apps, {
        id = item.appId,
        name = item.appName,
        icon = item.appIcon,
        count = cnt,
      })
    end
  end

  return apps
end

-- UI Building Blocks
local function renderHeader(): any
  return ui.row({
    justify = "space_between",
    align = "center",
    gap = 12,
    paddingV = 2,
  }, {
    -- Left: Title & Count
    ui.row({ gap = 8, align = "center" }, {
      ui.row({
        padding = 5,
        radius = 6 * cornerRadiusScale,
        fill = "surface_variant",
      }, {
        ui.glyph({ name = "keyboard", size = 16, color = "primary" }),
      }),
      ui.label({ text = tr("panel.title"), fontSize = 14, fontWeight = "bold" }),
      ui.label({
        text = "(" .. tostring(#items) .. ")",
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
    -- Center: Compact Search Input (integrated directly into header)
    ui.row({
      align = "center",
      gap = 6,
      flexGrow = 1,
      paddingH = 12,
    }, {
      ui.input({
        key = "search-input",
        flexGrow = 1,
        placeholder = tr("panel.search_placeholder"),
        value = searchQuery,
        onChange = function(val)
          searchQuery = val
          render()
        end,
      }),
      (#searchQuery > 0) and ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = "Clear search",
        onClick = function()
          searchQuery = ""
          render()
        end,
      }) or nil,
    }),
    -- Right: Action Buttons
    ui.row({ gap = 4, align = "center" }, {
      ui.button({
        glyph = "pencil",
        variant = isEditMode and "primary" or "ghost",
        tooltip = tr("actions.toggle_edit_mode"),
        onClick = function()
          isEditMode = not isEditMode
          render()
        end,
      }),
      ui.button({
        glyph = "plus",
        variant = "ghost",
        tooltip = tr("actions.add_keybind"),
        onClick = function()
          modalMode = "create"
          formApp = if activeApp ~= "hyprland" then activeApp else "Custom"
          formSubcat = "General"
          formDesc = ""
          formKey = ""
          formMods = { SUPER = false, CTRL = false, ALT = false, SHIFT = false }
          formError = ""
          isModalOpen = true
          render()
        end,
      }),
      ui.button({
        glyph = "refresh",
        variant = "ghost",
        tooltip = "Refresh Keybinds",
        onClick = function()
          refreshAllBinds()
        end,
      }),
      ui.button({
        glyph = "settings",
        variant = "ghost",
        tooltip = "Open Settings",
        onClick = function()
          noctalia.openSettings()
        end,
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = "Close (Esc)",
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })
end

local function renderAppTabs(): any
  local apps = getAppList()
  if #apps == 0 then
    return ui.row({})
  end

  -- Validate activeApp
  local activeFound = false
  for _, app in ipairs(apps) do
    if app.id == activeApp then
      activeFound = true
      break
    end
  end
  if not activeFound and #apps > 0 then
    activeApp = apps[1].id
  end

  local q = string.lower(noctalia.string.trim(searchQuery))
  local qWords = {}
  for w in string.gmatch(q, "%S+") do
    table.insert(qWords, w)
  end

  -- Calculate match count per app if searching
  local matchCounts = {}
  if #qWords > 0 then
    for _, item in ipairs(items) do
      local matched = true
      for _, w in ipairs(qWords) do
        if not string.find(item.searchIndex, w, 1, true) then
          matched = false
          break
        end
      end
      if matched then
        matchCounts[item.appId] = (matchCounts[item.appId] or 0) + 1
      end
    end
  end

  local tabNodes = {}
  for _, app in ipairs(apps) do
    local isSelected = (activeApp == app.id)
    local displayCount = (#qWords > 0) and (matchCounts[app.id] or 0) or app.count
    table.insert(tabNodes, ui.row({
      key = "app-tab-" .. app.id,
      paddingV = 5,
      paddingH = 12,
      radius = 16 * cornerRadiusScale,
      fill = isSelected and "primary" or "surface",
      onClick = function()
        activeApp = app.id
        render()
      end,
    }, {
      ui.row({ gap = 6, align = "center" }, {
        ui.glyph({
          name = app.icon,
          size = 14,
          color = isSelected and "on_primary" or "on_surface_variant",
        }),
        ui.label({
          text = app.name,
          fontSize = 12,
          fontWeight = isSelected and "bold" or "normal",
          color = isSelected and "on_primary" or "on_surface",
        }),
        ui.row({
          paddingV = 1,
          paddingH = 6,
          radius = 8,
          fill = isSelected and "on_primary" or "surface_variant",
        }, {
          ui.label({
            text = tostring(displayCount),
            fontSize = 9,
            fontWeight = "bold",
            color = isSelected and "primary" or "on_surface_variant",
          }),
        }),
      }),
    }))
  end

  return ui.row({
    key = "app-tabs-bar",
    gap = 8,
    align = "center",
    justify = "start",
    flexGrow = 0,
  }, tabNodes)
end

local function renderSubcategoryHeading(title: string, icon: string, count: number): any
  return ui.row({
    gap = 8,
    align = "center",
    paddingV = 4,
    paddingH = 2,
  }, {
    ui.glyph({ name = icon, size = 13, color = "primary" }),
    ui.label({
      text = title,
      fontSize = 12,
      fontWeight = "bold",
      color = "primary",
    }),
    ui.row({
      paddingV = 1,
      paddingH = 6,
      radius = 8,
      fill = "surface_variant",
    }, {
      ui.label({
        text = tostring(count),
        fontSize = 9,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
    }),
    ui.box({
      flexGrow = 1,
      height = 1,
      fill = "surface_variant",
    }),
  })
end

local function renderKbdBadge(text: string, isPrimary: boolean): any
  return ui.row({
    paddingV = 2,
    paddingH = 5,
    radius = 4 * cornerRadiusScale,
    fill = isPrimary and "surface_variant" or "surface",
  }, {
    ui.label({
      text = string.upper(text),
      fontSize = 10,
      fontWeight = "bold",
      color = isPrimary and "primary" or "on_surface",
    }),
  })
end

local function renderKeybindCard(item: KeybindItem): any
  local isCopied = (copiedId == item.id)

  local kbdBadges = {}
  for _, m in ipairs(item.modifiers) do
    table.insert(kbdBadges, renderKbdBadge(string.upper(m), false))
    table.insert(kbdBadges, ui.label({ text = "+", fontSize = 9, color = "on_surface_variant" }))
  end
  if item.key ~= "" then
    table.insert(kbdBadges, renderKbdBadge(string.upper(item.key), true))
  end

  -- Prevent text overflowing under badges; calculate safe max description length
  local maxDescLen = if isEditMode
    then (34 - (#item.modifiers * 5) - (string.len(item.key) > 6 and 4 or 0))
    else (46 - (#item.modifiers * 5) - (string.len(item.key) > 6 and 4 or 0))
  if maxDescLen < 16 then maxDescLen = 16 end

  local displayDesc = item.description
  if string.len(displayDesc) > maxDescLen then
    displayDesc = string.sub(displayDesc, 1, maxDescLen - 1) .. "…"
  end

  local fullTooltip = item.description .. " (" .. item.keyComboText .. ")"

  local cardActions = nil
  if isEditMode and item.source == "custom" and item.bindIndex ~= nil then
    cardActions = ui.row({ gap = 2, align = "center" }, {
      ui.button({
        glyph = "pencil",
        variant = "ghost",
        tooltip = tr("actions.edit_keybind"),
        onClick = function()
          modalMode = "edit"
          editTarget = {
            origApp = item.appName,
            origSubcat = item.subcatName,
            origBindIdx = item.bindIndex or 1,
          }
          formApp = item.appName
          formSubcat = item.subcatName
          formDesc = item.description
          formKey = item.key
          formMods = { SUPER = false, CTRL = false, ALT = false, SHIFT = false }
          for _, m in ipairs(item.modifiers) do
            local mu = string.upper(m)
            if formMods[mu] ~= nil then
              formMods[mu] = true
            end
          end
          formError = ""
          isModalOpen = true
          render()
        end,
      }),
      ui.button({
        glyph = "trash",
        variant = "ghost",
        tooltip = tr("actions.delete_keybind"),
        onClick = function()
          local path = getCustomFilePath()
          local raw = noctalia.readFile(path)
          if raw then
            local ok, store = pcall(function() return noctalia.json.decode(raw) end)
            if ok and store then
              crud.deleteKeybind(store, item.appName, item.subcatName, item.bindIndex or 1)
              saveCustomJson(store)
              noctalia.notify("Keybinds", tr("modal.deleted_notify"))
              refreshAllBinds()
            end
          end
        end,
      }),
    })
  end

  return ui.row({
    key = "card-" .. item.id,
    flexGrow = 1,
    paddingV = 5,
    paddingH = 8,
    radius = 6 * cornerRadiusScale,
    fill = isCopied and "primary_container" or "surface",
    align = "center",
    justify = "space_between",
    gap = 6,
    tooltip = fullTooltip,
    onClick = function()
      local copyEnabled = noctalia.getConfig("copy_on_click") ~= false
      if copyEnabled then
        noctalia.copyToClipboard(item.keyComboText, "text/plain")
        copiedId = item.id
        render()
      end
    end,
  }, {
    ui.row({ gap = 6, align = "center", flexGrow = 1, tooltip = fullTooltip }, {
      ui.glyph({ name = item.subcatIcon, size = 11, color = "on_surface_variant" }),
      ui.label({
        text = isCopied and tr("panel.copied") or displayDesc,
        fontSize = 11,
        fontWeight = isCopied and "bold" or "normal",
        color = isCopied and "on_primary_container" or "on_surface",
        maxLines = 1,
      }),
    }),
    ui.row({ gap = 4, align = "center" }, {
      ui.row({ gap = 2, align = "center" }, kbdBadges),
      cardActions,
    }),
  })
end

local function filterItems(): { KeybindItem }
  local filtered = {}
  local q = string.lower(noctalia.string.trim(searchQuery))
  local qWords = {}
  for word in string.gmatch(q, "%S+") do
    table.insert(qWords, word)
  end

  for _, item in ipairs(items) do
    if item.appId == activeApp then
      if #qWords == 0 then
        table.insert(filtered, item)
      else
        local matchSearch = true
        for _, w in ipairs(qWords) do
          if not string.find(item.searchIndex, w, 1, true) then
            matchSearch = false
            break
          end
        end
        if matchSearch then
          table.insert(filtered, item)
        end
      end
    end
  end
  return filtered
end

local function renderCardGrid(filtered: { KeybindItem }): any
  if #filtered == 0 then
    return ui.column({
      flexGrow = 1,
      align = "center",
      justify = "center",
      gap = 10,
      padding = 30,
    }, {
      ui.glyph({ name = "search", size = 36, color = "on_surface_variant" }),
      ui.label({
        text = tr("panel.no_results", { query = searchQuery }),
        fontSize = 12,
        color = "on_surface_variant",
      }),
    })
  end

  local cols = tonumber(gridColumns) or 3
  local scrollContent = {}

  -- Group items by subcategory
  local groups = {}
  local groupMap = {}

  for _, item in ipairs(filtered) do
    local grp = groupMap[item.subcatId]
    if not grp then
      grp = {
        id = item.subcatId,
        name = item.subcatName,
        icon = item.subcatIcon,
        items = {},
      }
      groupMap[item.subcatId] = grp
      table.insert(groups, grp)
    end
    table.insert(grp.items, item)
  end

  -- Sort subcategories naturally by name (A to Z)
  table.sort(groups, function(a, b)
    return naturalSortKey(a.name) < naturalSortKey(b.name)
  end)

  for _, grp in ipairs(groups) do
    if #grp.items > 0 then
      -- Sort items within subcategory naturally (A to Z, 1..10)
      table.sort(grp.items, function(a, b)
        return (a.sortKey or "") < (b.sortKey or "")
      end)

      -- Subcategory Section Heading
      table.insert(scrollContent, renderSubcategoryHeading(grp.name, grp.icon, #grp.items))

      -- Cards in N columns (flowing top-to-bottom down columns, then left-to-right)
      local totalItems = #grp.items
      if cols == 3 then
        local numRows = math.ceil(totalItems / 3)
        for r = 1, numRows do
          local idx1 = r
          local idx2 = r + numRows
          local idx3 = r + numRows * 2

          local col1 = renderKeybindCard(grp.items[idx1])
          local col2 = (idx2 <= totalItems) and renderKeybindCard(grp.items[idx2]) or ui.spacer({ flexGrow = 1 })
          local col3 = (idx3 <= totalItems) and renderKeybindCard(grp.items[idx3]) or ui.spacer({ flexGrow = 1 })
          table.insert(scrollContent, ui.row({ gap = 6, align = "center" }, { col1, col2, col3 }))
        end
      elseif cols == 2 then
        local numRows = math.ceil(totalItems / 2)
        for r = 1, numRows do
          local idx1 = r
          local idx2 = r + numRows

          local col1 = renderKeybindCard(grp.items[idx1])
          local col2 = (idx2 <= totalItems) and renderKeybindCard(grp.items[idx2]) or ui.spacer({ flexGrow = 1 })
          table.insert(scrollContent, ui.row({ gap = 6, align = "center" }, { col1, col2 }))
        end
      else
        for _, item in ipairs(grp.items) do
          table.insert(scrollContent, renderKeybindCard(item))
        end
      end

      -- Subtle gap after section
      table.insert(scrollContent, ui.spacer({ height = 4 }))
    end
  end

  return ui.scroll({
    flexGrow = 1,
    gap = 4,
  }, scrollContent)
end

local function renderFooter(): any
  local path = noctalia.expandPath(customFilePath)
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 2,
  }, {
    ui.label({
      text = tr("panel.footer_hint", { path = path }),
      fontSize = 10,
      color = "on_surface_variant",
    }),
    (not hyprAvailable) and ui.label({
      text = tr("panel.hypr_unavailable"),
      fontSize = 10,
      color = "error",
    }) or nil,
  })
end

local function renderModalOverlay(): any
  local isEdit = (modalMode == "edit")
  local modalTitle = if isEdit then tr("modal.title_edit") else tr("modal.title_add")

  -- Modifier Chips
  local modButtons = {}
  local modNames = { "SUPER", "CTRL", "ALT", "SHIFT" }
  for _, m in ipairs(modNames) do
    local isSelected = (formMods[m] == true)
    table.insert(modButtons, ui.row({
      paddingV = 6,
      paddingH = 14,
      radius = 6 * cornerRadiusScale,
      fill = isSelected and "primary" or "surface_variant",
      onClick = function()
        formMods[m] = not isSelected
        render()
      end,
    }, {
      ui.label({
        text = m,
        fontSize = 11,
        fontWeight = "bold",
        color = isSelected and "on_primary" or "on_surface_variant",
      }),
    }))
  end

  return ui.column({
    flexGrow = 1,
    align = "center",
    justify = "center",
    padding = 16,
  }, {
    ui.column({
      width = 540,
      radius = 12 * cornerRadiusScale,
      fill = "surface",
      padding = 20,
      gap = 12,
    }, {
      -- Modal Header
      ui.row({
        justify = "space_between",
        align = "center",
      }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.glyph({
            name = isEdit and "pencil" or "plus",
            size = 16,
            color = "primary",
          }),
          ui.label({
            text = modalTitle,
            fontSize = 15,
            fontWeight = "bold",
            color = "on_surface",
          }),
        }),
        ui.button({
          glyph = "x",
          variant = "ghost",
          tooltip = tr("modal.cancel"),
          onClick = function()
            isModalOpen = false
            formError = ""
            render()
          end,
        }),
      }),

      -- App Name Field
      ui.column({ gap = 4 }, {
        ui.label({ text = tr("modal.app_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
        ui.input({
          key = "modal-app-input",
          placeholder = tr("modal.app_placeholder"),
          value = formApp,
          onChange = function(val)
            formApp = val
          end,
        }),
      }),

      -- Subcategory Field
      ui.column({ gap = 4 }, {
        ui.label({ text = tr("modal.subcat_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
        ui.input({
          key = "modal-subcat-input",
          placeholder = tr("modal.subcat_placeholder"),
          value = formSubcat,
          onChange = function(val)
            formSubcat = val
          end,
        }),
      }),

      -- Description Field
      ui.column({ gap = 4 }, {
        ui.label({ text = tr("modal.desc_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
        ui.input({
          key = "modal-desc-input",
          placeholder = tr("modal.desc_placeholder"),
          value = formDesc,
          onChange = function(val)
            formDesc = val
          end,
        }),
      }),

      -- Modifier Keys Row
      ui.column({ gap = 4 }, {
        ui.label({ text = tr("modal.modifiers_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
        ui.row({ gap = 8, align = "center" }, modButtons),
      }),

      -- Primary Key Field
      ui.column({ gap = 4 }, {
        ui.label({ text = tr("modal.key_label"), fontSize = 11, color = "on_surface_variant", fontWeight = "bold" }),
        ui.input({
          key = "modal-key-input",
          placeholder = tr("modal.key_placeholder"),
          value = formKey,
          onChange = function(val)
            formKey = string.upper(val)
          end,
        }),
      }),

      -- Error Message (if any)
      (#formError > 0) and ui.label({
        text = formError,
        fontSize = 11,
        color = "error",
      }) or nil,

      -- Action Buttons (Footer)
      ui.row({
        justify = "flex_end",
        gap = 8,
        align = "center",
      }, {
        ui.button({
          text = tr("modal.cancel"),
          variant = "ghost",
          onClick = function()
            isModalOpen = false
            formError = ""
            render()
          end,
        }),
        ui.button({
          text = tr("modal.save"),
          variant = "primary",
          onClick = function()
            local activeMods = {}
            if formMods.SUPER then table.insert(activeMods, "SUPER") end
            if formMods.CTRL then table.insert(activeMods, "CTRL") end
            if formMods.ALT then table.insert(activeMods, "ALT") end
            if formMods.SHIFT then table.insert(activeMods, "SHIFT") end

            local path = getCustomFilePath()
            local raw = noctalia.readFile(path) or "{}"
            local ok, store = pcall(function() return noctalia.json.decode(raw) end)
            store = crud.ensureStore(if ok and type(store) == "table" then store else {})

            local success, errMsg
            if modalMode == "create" then
              success, errMsg = crud.addKeybind(store, formApp, formSubcat, formDesc, activeMods, formKey)
            else
              success, errMsg = crud.updateKeybind(
                store,
                editTarget.origApp,
                editTarget.origSubcat,
                editTarget.origBindIdx,
                formApp,
                formSubcat,
                formDesc,
                activeMods,
                formKey
              )
            end

            if not success then
              formError = errMsg or tr("modal.err_validation")
              render()
              return
            end

            local saved = saveCustomJson(store)
            if not saved then
              formError = "Failed to write to file"
              render()
              return
            end

            isModalOpen = false
            formError = ""
            noctalia.notify("Keybinds", tr("modal.saved_notify"))
            refreshAllBinds()
          end,
        }),
      }),
    }),
  })
end

render = function()
  local contentNode
  if isModalOpen then
    contentNode = renderModalOverlay()
  else
    local filtered = filterItems()
    contentNode = ui.column({
      key = "cheatsheet-content",
      flexGrow = 1,
      gap = 10,
      align = "stretch",
    }, {
      renderAppTabs(),
      renderCardGrid(filtered),
    })
  end

  panel.render(ui.column({
    flexGrow = 1,
    gap = 10,
    align = "stretch",
    padding = 12,
  }, {
    renderHeader(),
    contentNode,
    renderFooter(),
  }))
end

-- ── Lifecycle Callbacks ────────────────────────────────────────────────────────

function onOpen(_context)
  cornerRadiusScale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
  gridColumns = tostring(noctalia.getConfig("grid_columns") or "3")

  local cfgPath = noctalia.getConfig("custom_file_path")
  if cfgPath and cfgPath ~= "" then
    customFilePath = cfgPath
  else
    local dataDir = noctalia.pluginDataDir()
    customFilePath = (dataDir and dataDir ~= "") and (dataDir .. "/custom_keybinds.json") or "~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json"
  end

  searchQuery = ""
  activeApp = "hyprland"
  copiedId = nil
  isEditMode = false
  isModalOpen = false
  formError = ""

  refreshAllBinds()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    if isModalOpen then
      isModalOpen = false
      formError = ""
      render()
    elseif #searchQuery > 0 then
      searchQuery = ""
      render()
    elseif isEditMode then
      isEditMode = false
      render()
    else
      panel.close()
    end
  end
end
