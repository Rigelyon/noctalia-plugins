--!nonstrict
-- Keybinds Cheatsheet Panel for Noctalia
-- Displays active Hyprland bindings and manual custom shortcuts in an aesthetic modal.

local presets = require("./presets.luau")

type KeybindItem = {
  id: string,
  category: string,
  categoryIcon: string,
  modifiers: { string },
  key: string,
  keyComboText: string,
  description: string,
  source: string,
  searchIndex: string,
}

local items: { KeybindItem } = {}
local activeCategory = "all"
local searchQuery = ""
local copiedId: string? = nil
local hyprAvailable = true
local isLoading = false
local cornerRadiusScale = 1.0
local gridColumns = "2"
local customFilePath = ""

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

local function buildKeyComboText(modifiers: { string }, key: string): string
  local parts = {}
  for _, m in ipairs(modifiers) do
    table.insert(parts, m)
  end
  if key ~= "" then
    table.insert(parts, key)
  end
  return table.concat(parts, " + ")
end

local function loadCustomKeybinds(): { KeybindItem }
  local customItems: { KeybindItem } = {}
  local path = noctalia.expandPath(customFilePath)

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

  if ok and type(data) == "table" and type(data.categories) == "table" then
    for _, cat in ipairs(data.categories) do
      local catName = cat.name or "Custom"
      local catIcon = cat.icon or "terminal"
      if catIcon == "terminal_window" then
        catIcon = "terminal"
      end
      if type(cat.binds) == "table" then
        for i, b in ipairs(cat.binds) do
          local keys = b.keys or {}
          local mods = {}
          local primaryKey = ""
          if #keys > 0 then
            for kIdx = 1, #keys - 1 do
              table.insert(mods, keys[kIdx])
            end
            primaryKey = keys[#keys]
          end
          local desc = b.description or ""
          local combo = buildKeyComboText(mods, primaryKey)
          table.insert(customItems, {
            id = "custom-" .. catName .. "-" .. tostring(i),
            category = catName,
            categoryIcon = catIcon,
            modifiers = mods,
            key = primaryKey,
            keyComboText = combo,
            description = desc,
            source = "custom",
            searchIndex = string.lower(catName .. " " .. desc .. " " .. combo),
          })
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
          if rawKey == "" and b.keycode and b.keycode > 0 then
            rawKey = "code:" .. tostring(b.keycode)
          end
          local normKey = normalizeKey(rawKey)
          local mods = decodeModmask(b.modmask or 0)
          local desc = b.description or ""
          if desc == "" and b.dispatcher then
            desc = b.dispatcher .. (b.arg and (" " .. b.arg) or "")
          end
          local catKey, catIcon = categorizeBind(desc, rawKey, b.dispatcher)
          local combo = buildKeyComboText(mods, normKey)

          table.insert(items, {
            id = "hypr-" .. tostring(idx),
            category = catKey,
            categoryIcon = catIcon,
            modifiers = mods,
            key = normKey,
            keyComboText = combo,
            description = desc,
            source = "hyprland",
            searchIndex = string.lower(catKey .. " " .. desc .. " " .. combo),
          })
        end
      end
    else
      hyprAvailable = false
    end
    render()
  end, 3000)
end

-- UI Building Blocks
local function renderHeader(): any
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 4,
  }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.row({
        padding = 8,
        radius = 8 * cornerRadiusScale,
        fill = "surface_variant",
      }, {
        ui.glyph({ name = "keyboard", size = 22, color = "primary" }),
      }),
      ui.column({ gap = 2 }, {
        ui.label({ text = tr("panel.title"), fontSize = 16, fontWeight = "bold" }),
        ui.label({
          text = tr("panel.subtitle", { count = #items }),
          fontSize = 11,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
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
        tooltip = "Close",
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })
end

local function renderSearchBar(): any
  return ui.row({
    align = "center",
    gap = 8,
    padding = 6,
    paddingH = 12,
    radius = 8 * cornerRadiusScale,
    fill = "surface_variant",
  }, {
    ui.glyph({ name = "search", size = 16, color = "on_surface_variant" }),
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
      onClick = function()
        searchQuery = ""
        render()
      end,
    }) or nil,
  })
end

local function getCategoryCounts(): { [string]: number }
  local counts = { all = #items }
  for _, item in ipairs(items) do
    counts[item.category] = (counts[item.category] or 0) + 1
  end
  return counts
end

local function renderCategoryPills(): any
  local counts = getCategoryCounts()

  -- Base categories
  local cats = {
    { id = "all", label = tr("panel.categories.all"), icon = "layout-grid" },
    { id = "window", label = tr("panel.categories.window"), icon = "app-window" },
    { id = "workspaces", label = tr("panel.categories.workspaces"), icon = "layout-grid" },
    { id = "apps", label = tr("panel.categories.apps"), icon = "rocket" },
    { id = "media", label = tr("panel.categories.media"), icon = "volume-2" },
    { id = "screen", label = tr("panel.categories.screen"), icon = "camera" },
    { id = "system", label = tr("panel.categories.system"), icon = "power" },
  }

  -- Collect custom categories present in items
  local customCatsSeen = {}
  for _, item in ipairs(items) do
    if item.source == "custom" and not customCatsSeen[item.category] then
      customCatsSeen[item.category] = true
      table.insert(cats, {
        id = item.category,
        label = item.category,
        icon = item.categoryIcon or "terminal",
      })
    end
  end

  local pillNodes = {}
  for _, cat in ipairs(cats) do
    local cnt = counts[cat.id] or 0
    if cnt > 0 or cat.id == "all" then
      local isSelected = (activeCategory == cat.id)
      table.insert(pillNodes, ui.row({
        key = "pill-" .. cat.id,
        paddingV = 6,
        paddingH = 12,
        radius = 20 * cornerRadiusScale,
        fill = isSelected and "primary" or "surface",
        onClick = function()
          activeCategory = cat.id
          render()
        end,
      }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({
            name = cat.icon,
            size = 14,
            color = isSelected and "on_primary" or "on_surface_variant",
          }),
          ui.label({
            text = cat.label,
            fontSize = 12,
            fontWeight = isSelected and "bold" or "normal",
            color = isSelected and "on_primary" or "on_surface",
          }),
          ui.row({
            paddingV = 1,
            paddingH = 6,
            radius = 10,
            fill = isSelected and "on_primary" or "surface_variant",
          }, {
            ui.label({
              text = tostring(cnt),
              fontSize = 10,
              fontWeight = "bold",
              color = isSelected and "primary" or "on_surface_variant",
            }),
          }),
        }),
      }))
    end
  end

  return ui.row({
    gap = 6,
  }, pillNodes)
end

local function renderKbdBadge(text: string, isPrimary: boolean): any
  return ui.row({
    paddingV = 3,
    paddingH = 7,
    radius = 4 * cornerRadiusScale,
    fill = isPrimary and "surface_variant" or "surface",
  }, {
    ui.label({
      text = text,
      fontSize = 11,
      fontWeight = "bold",
      color = isPrimary and "primary" or "on_surface",
    }),
  })
end

local function renderKeybindCard(item: KeybindItem): any
  local isCopied = (copiedId == item.id)

  local kbdBadges = {}
  for _, m in ipairs(item.modifiers) do
    table.insert(kbdBadges, renderKbdBadge(m, false))
    table.insert(kbdBadges, ui.label({ text = "+", fontSize = 10, color = "on_surface_variant" }))
  end
  if item.key ~= "" then
    table.insert(kbdBadges, renderKbdBadge(item.key, true))
  end

  return ui.column({
    key = "card-" .. item.id,
    flexGrow = 1,
    padding = 10,
    radius = 8 * cornerRadiusScale,
    fill = isCopied and "primary_container" or "surface",
    onClick = function()
      local copyEnabled = noctalia.getConfig("copy_on_click") ~= false
      if copyEnabled then
        noctalia.copyToClipboard(item.keyComboText, "text/plain")
        copiedId = item.id
        render()
      end
    end,
  }, {
    ui.row({
      align = "center",
      justify = "space_between",
      gap = 8,
    }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({
          text = isCopied and tr("panel.copied") or item.description,
          fontSize = 12,
          fontWeight = isCopied and "bold" or "normal",
          color = isCopied and "on_primary_container" or "on_surface",
          maxLines = 1,
        }),
        ui.row({ gap = 4, align = "center" }, {
          ui.glyph({ name = item.categoryIcon, size = 11, color = "on_surface_variant" }),
          ui.label({
            text = item.category,
            fontSize = 10,
            color = "on_surface_variant",
          }),
        }),
      }),
      ui.row({ gap = 4, align = "center" }, kbdBadges),
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
    local matchCat = (activeCategory == "all") or (item.category == activeCategory)
    if matchCat then
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
      gap = 12,
      padding = 40,
    }, {
      ui.glyph({ name = "search", size = 48, color = "on_surface_variant" }),
      ui.label({
        text = tr("panel.no_results", { query = searchQuery }),
        fontSize = 13,
        color = "on_surface_variant",
      }),
    })
  end

  local isTwoCols = (gridColumns == "2")
  local rows = {}

  if isTwoCols then
    for i = 1, #filtered, 2 do
      local col1 = renderKeybindCard(filtered[i])
      local col2 = (i + 1 <= #filtered) and renderKeybindCard(filtered[i + 1]) or ui.spacer({ flexGrow = 1 })
      table.insert(rows, ui.row({ gap = 8, align = "center" }, { col1, col2 }))
    end
  else
    for _, item in ipairs(filtered) do
      table.insert(rows, renderKeybindCard(item))
    end
  end

  return ui.scroll({
    flexGrow = 1,
    gap = 8,
  }, rows)
end

local function renderFooter(): any
  local path = noctalia.expandPath(customFilePath)
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 4,
  }, {
    ui.label({
      text = tr("panel.footer_hint", { path = path }),
      fontSize = 11,
      color = "on_surface_variant",
    }),
    (not hyprAvailable) and ui.label({
      text = tr("panel.hypr_unavailable"),
      fontSize = 11,
      color = "error",
    }) or nil,
  })
end

render = function()
  local filtered = filterItems()
  panel.render(ui.column({
    flexGrow = 1,
    gap = 12,
    align = "stretch",
    padding = 16,
  }, {
    renderHeader(),
    renderSearchBar(),
    renderCategoryPills(),
    renderCardGrid(filtered),
    renderFooter(),
  }))
end

-- ── Lifecycle Callbacks ────────────────────────────────────────────────────────

function onOpen(_context)
  cornerRadiusScale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
  gridColumns = tostring(noctalia.getConfig("grid_columns") or "2")
  customFilePath = noctalia.getConfig("custom_file_path") or "~/.config/noctalia/custom_keybinds.json"

  searchQuery = ""
  activeCategory = "all"
  copiedId = nil

  refreshAllBinds()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    if #searchQuery > 0 then
      searchQuery = ""
      render()
    else
      panel.close()
    end
  end
end
