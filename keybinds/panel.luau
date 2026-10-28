--!nonstrict
-- Keybinds Cheatsheet Panel for Noctalia
-- Orchestrates active Hyprland bindings and manual custom shortcuts per application.

local presets = require("./presets.luau")
local crud = require("./crud.luau")
local icons = require("./icons.luau")
local parser = require("./parser.luau")
local components = require("./components.luau")
local modals = require("./modals.luau")

type KeybindItem = parser.KeybindItem

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
local modalMode = "create" -- "create", "edit", "edit_app", "edit_subcat"
local editTarget = {
  origApp = "",
  origSubcat = "",
  origBindIdx = 0,
}
local formApp = ""
local formAppIcon = "terminal"
local formAppSelectedIdx = 0
local formAppIsNew = false
local formSubcat = ""
local formSubcatIcon = "command"
local formSubcatSelectedIdx = 0
local formSubcatIsNew = false
local formDesc = ""
local formKey = ""
local formMods = {
  SUPER = false,
  CTRL = false,
  ALT = false,
  SHIFT = false,
}
local formError = ""

-- In-place edit state for App and Subcategory
local editAppName = ""
local editAppIcon = "terminal"
local editSubcatName = ""
local editSubcatIcon = "command"
local editSubcatParentApp = ""

-- Icon Picker state & catalog reference
local ICON_CATEGORIES = icons.ICON_CATEGORIES
local isIconPickerOpen = false
local iconPickerSearch = ""
local iconPickerCategory = "all"
local iconPickerCurrent = ""
local iconPickerCallback: ((string) -> ())? = nil

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function openIconPicker(current: string?, callback: (string) -> ())
  isIconPickerOpen = true
  iconPickerSearch = ""
  iconPickerCategory = "all"
  iconPickerCurrent = current or "terminal"
  iconPickerCallback = callback
  if render then
    render()
  end
end

local function closeIconPicker()
  isIconPickerOpen = false
  iconPickerCallback = nil
  if render then
    render()
  end
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

local function getCustomStore(): any
  local path = getCustomFilePath()
  local raw = noctalia.readFile(path) or "{}"
  local ok, store = pcall(function() return noctalia.json.decode(raw) end)
  return crud.ensureStore(if ok and type(store) == "table" then store else {})
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

local function getStateFilePath(): string
  local dataDir = noctalia.pluginDataDir()
  local rawPath = (dataDir and dataDir ~= "") and (dataDir .. "/state.json") or "~/.local/state/noctalia/plugins/data/rigelyon/keybinds/state.json"
  return noctalia.expandPath(rawPath)
end

local function saveState()
  local path = getStateFilePath()
  local ok, encoded = pcall(function()
    return noctalia.json.encode({ activeApp = activeApp })
  end)
  if ok and encoded then
    local dir = string.match(path, "^(.*)/[^/]+$")
    if dir then
      noctalia.mkdirAll(dir)
    end
    noctalia.writeFile(path, encoded)
  end
end

local function loadState()
  local path = getStateFilePath()
  local raw = noctalia.readFile(path)
  if raw then
    local ok, data = pcall(function() return noctalia.json.decode(raw) end)
    if ok and type(data) == "table" and type(data.activeApp) == "string" and data.activeApp ~= "" then
      activeApp = data.activeApp
    end
  end
end

local function loadCustomKeybinds(): { KeybindItem }
  local path = getCustomFilePath()
  if not noctalia.fileExists(path) then
    local dir = string.match(path, "^(.*)/[^/]+$")
    if dir then
      noctalia.mkdirAll(dir)
    end
    noctalia.writeFile(path, presets.defaultJson)
  end
  local raw = noctalia.readFile(path) or ""
  return parser.parseCustomKeybinds(raw)
end

local function refreshAllBinds()
  isLoading = true
  if render then
    render()
  end

  local customList = loadCustomKeybinds()
  items = {}

  for _, item in ipairs(customList) do
    table.insert(items, item)
  end

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

          local normKey = string.upper(parser.normalizeKey(rawKey))
          local mods = parser.decodeModmask(b.modmask or 0)
          local catKey, catIcon = parser.categorizeBind(desc, normKey, b.dispatcher)
          local info = parser.HYPRLAND_SUBCAT_INFO[catKey]
          local subcatName = (info and tr(info.labelKey)) or catKey
          local subcatIcon = (info and info.icon) or catIcon

          local combo = parser.buildKeyComboText(mods, normKey)
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
            sortKey = parser.naturalSortKey(desc),
            bindIndex = nil,
          })
        end
      end
    else
      hyprAvailable = false
    end
    if render then
      noctalia.runAsync({ "sleep", "0.01" }, function()
        render()
      end)
    end
  end)
end

local function getAppList(): { { id: string, name: string, icon: string, count: number } }
  local apps = {}
  local seen = {}

  local hyprCount = 0
  for _, item in ipairs(items) do
    if item.appId == "hyprland" then
      hyprCount = hyprCount + 1
    end
  end
  table.insert(apps, {
    id = "hyprland",
    name = "Hyprland",
    icon = "layout-grid",
    count = hyprCount,
  })
  seen["hyprland"] = true

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
    -- Center: Compact Search Input
    (function()
      local searchNodes = {
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
      }
      if #searchQuery > 0 then
        table.insert(searchNodes, ui.button({
          glyph = "x",
          variant = "ghost",
          tooltip = "Clear search",
          onClick = function()
            searchQuery = ""
            render()
          end,
        }))
      end
      return ui.row({
        align = "center",
        gap = 6,
        flexGrow = 1,
        paddingH = 12,
      }, searchNodes)
    end)(),
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
          local store = getCustomStore()
          local defaultAppName = if activeApp ~= "hyprland" then activeApp else "Custom"
          local matchedAppIdx = nil
          if store and type(store.apps) == "table" then
            for idx, a in ipairs(store.apps) do
              if string.lower(a.name) == string.lower(defaultAppName) then
                matchedAppIdx = idx
                break
              end
            end
          end

          if matchedAppIdx then
            local a = store.apps[matchedAppIdx]
            formAppSelectedIdx = matchedAppIdx - 1
            formAppIsNew = false
            formApp = a.name
            formAppIcon = a.icon or "terminal"
            if a.subcategories and #a.subcategories > 0 then
              formSubcatSelectedIdx = 0
              formSubcatIsNew = false
              formSubcat = a.subcategories[1].name
              formSubcatIcon = a.subcategories[1].icon or "command"
            else
              formSubcatSelectedIdx = 0
              formSubcatIsNew = true
              formSubcat = "General"
              formSubcatIcon = "command"
            end
          else
            local totalApps = if store and type(store.apps) == "table" then #store.apps else 0
            if totalApps > 0 and activeApp == "hyprland" then
              local a = store.apps[1]
              formAppSelectedIdx = 0
              formAppIsNew = false
              formApp = a.name
              formAppIcon = a.icon or "terminal"
              if a.subcategories and #a.subcategories > 0 then
                formSubcatSelectedIdx = 0
                formSubcatIsNew = false
                formSubcat = a.subcategories[1].name
                formSubcatIcon = a.subcategories[1].icon or "command"
              else
                formSubcatSelectedIdx = 0
                formSubcatIsNew = true
                formSubcat = "General"
                formSubcatIcon = "command"
              end
            else
              formAppSelectedIdx = totalApps
              formAppIsNew = true
              formApp = defaultAppName
              formAppIcon = "terminal"
              formSubcatSelectedIdx = 0
              formSubcatIsNew = true
              formSubcat = "General"
              formSubcatIcon = "command"
            end
          end

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
      local innerTabChildren = {
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
      }
      if isSelected and isEditMode and app.id ~= "hyprland" then
        table.insert(innerTabChildren, ui.button({
          glyph = "pencil",
          variant = "ghost",
          tooltip = tr("modal.edit_app_title"),
          onClick = function()
            modalMode = "edit_app"
            editTarget.origApp = app.name
            editAppName = app.name
            editAppIcon = app.icon or "terminal"
            formError = ""
            isModalOpen = true
            render()
          end,
        }))
      end

      table.insert(tabNodes, ui.row({
        key = "app-tab-" .. app.id,
        paddingV = 5,
        paddingH = 12,
        radius = 16 * cornerRadiusScale,
        fill = isSelected and "primary" or "surface",
        onClick = function()
          activeApp = app.id
          saveState()
          render()
        end,
      }, {
        ui.row({ gap = 6, align = "center" }, innerTabChildren),
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

local function renderSubcategoryHeading(title: string, icon: string, count: number, isCustom: boolean?, appName: string?): any
  local headingChildren = {
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
  }

  if isEditMode and isCustom then
    table.insert(headingChildren, ui.button({
      glyph = "pencil",
      variant = "ghost",
      tooltip = tr("modal.edit_subcat_title"),
      onClick = function()
        modalMode = "edit_subcat"
        editTarget.origApp = appName or activeApp
        editTarget.origSubcat = title
        editSubcatName = title
        editSubcatIcon = icon or "command"
        editSubcatParentApp = appName or activeApp
        formError = ""
        isModalOpen = true
        render()
      end,
    }))
  end

  table.insert(headingChildren, ui.box({
    flexGrow = 1,
    height = 1,
    fill = "surface_variant",
  }))

  return ui.row({
    gap = 8,
    align = "center",
    paddingV = 4,
    paddingH = 2,
  }, headingChildren)
end

local function renderKeybindCard(item: KeybindItem): any
  return components.renderKeybindCard(item, {
    isEditMode = isEditMode,
    copiedId = copiedId,
    cornerRadiusScale = cornerRadiusScale,
    tr = tr,
    onCopy = function(comboText, id)
      noctalia.copyToClipboard(item.keyComboText, "text/plain")
      copiedId = id
      render()
    end,
    onEdit = function(it)
      modalMode = "edit"
      editTarget = {
        origApp = it.appName,
        origSubcat = it.subcatName,
        origBindIdx = it.bindIndex or 1,
      }
      local store = getCustomStore()
      local appFoundIdx = nil
      local subFoundIdx = nil
      if store and type(store.apps) == "table" then
        for aIdx, a in ipairs(store.apps) do
          if string.lower(a.name) == string.lower(it.appName) then
            appFoundIdx = aIdx
            if type(a.subcategories) == "table" then
              for sIdx, s in ipairs(a.subcategories) do
                if string.lower(s.name) == string.lower(it.subcatName) then
                  subFoundIdx = sIdx
                  break
                end
              end
            end
            break
          end
        end
      end

      if appFoundIdx then
        local a = store.apps[appFoundIdx]
        formAppSelectedIdx = appFoundIdx - 1
        formAppIsNew = false
        formApp = a.name
        formAppIcon = a.icon or "terminal"
        if subFoundIdx then
          formSubcatSelectedIdx = subFoundIdx - 1
          formSubcatIsNew = false
          formSubcat = a.subcategories[subFoundIdx].name
          formSubcatIcon = a.subcategories[subFoundIdx].icon or "command"
        else
          local totalSubs = if type(a.subcategories) == "table" then #a.subcategories else 0
          formSubcatSelectedIdx = totalSubs
          formSubcatIsNew = true
          formSubcat = it.subcatName
          formSubcatIcon = it.subcatIcon or "command"
        end
      else
        local totalApps = if store and type(store.apps) == "table" then #store.apps else 0
        formAppSelectedIdx = totalApps
        formAppIsNew = true
        formApp = it.appName
        formAppIcon = it.appIcon or "terminal"
        formSubcatSelectedIdx = 0
        formSubcatIsNew = true
        formSubcat = it.subcatName
        formSubcatIcon = it.subcatIcon or "command"
      end

      formDesc = it.description
      formKey = it.keyComboText or it.key
      formMods = { SUPER = false, CTRL = false, ALT = false, SHIFT = false }
      if it.tokens == nil then
        for _, m in ipairs(it.modifiers) do
          local mu = string.upper(m)
          if formMods[mu] ~= nil then
            formMods[mu] = true
          end
        end
      end
      formError = ""
      isModalOpen = true
      render()
    end,
    onDelete = function(it)
      local currentStore = getCustomStore()
      crud.deleteKeybind(currentStore, it.appName, it.subcatName, it.bindIndex or 1)
      saveCustomJson(currentStore)
      noctalia.notify("Keybinds", tr("modal.deleted_notify"))
      refreshAllBinds()
    end,
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

local function renderKeybindsGrid(): any
  local activeItems = filterItems()

  if #activeItems == 0 then
    return ui.column({
      flexGrow = 1,
      align = "center",
      justify = "center",
      gap = 8,
      padding = 32,
    }, {
      ui.glyph({ name = "search", size = 28, color = "on_surface_variant" }),
      ui.label({
        text = tr("panel.no_results", { query = searchQuery }),
        fontSize = 12,
        color = "on_surface_variant",
      }),
    })
  end

  -- Group items by subcategory
  local groups = {}
  local groupIndex = {}
  for _, item in ipairs(activeItems) do
    if not groupIndex[item.subcatId] then
      local grp = {
        id = item.subcatId,
        name = item.subcatName,
        icon = item.subcatIcon,
        isCustom = (item.source == "custom"),
        appName = item.appName,
        items = {},
      }
      table.insert(groups, grp)
      groupIndex[item.subcatId] = grp
    end
    table.insert(groupIndex[item.subcatId].items, item)
  end

  local scrollContent = {}
  for _, grp in ipairs(groups) do
    table.sort(grp.items, function(a, b)
      if a.sortKey ~= b.sortKey then
        return a.sortKey < b.sortKey
      end
      return a.description < b.description
    end)

    table.insert(scrollContent, renderSubcategoryHeading(grp.name, grp.icon, #grp.items, grp.isCustom, grp.appName))

    local totalItems = #grp.items
    if gridColumns == "3" then
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
    else
      local numRows = math.ceil(totalItems / 2)
      for r = 1, numRows do
        local idx1 = r
        local idx2 = r + numRows

        local col1 = renderKeybindCard(grp.items[idx1])
        local col2 = (idx2 <= totalItems) and renderKeybindCard(grp.items[idx2]) or ui.spacer({ flexGrow = 1 })

        table.insert(scrollContent, ui.row({ gap = 6, align = "center" }, { col1, col2 }))
      end
    end

    table.insert(scrollContent, ui.spacer({ height = 4 }))
  end

  return ui.scroll({
    flexGrow = 1,
    gap = 4,
    paddingH = 2,
  }, scrollContent)
end

local function renderFooter(): any
  local footerChildren = {
    ui.label({
      text = tr("panel.footer_hint") .. " · Config: " .. getCustomFilePath(),
      fontSize = 10,
      color = "on_surface_variant",
    }),
  }
  if not hyprAvailable then
    table.insert(footerChildren, ui.label({
      text = tr("panel.hypr_unavailable"),
      fontSize = 10,
      color = "error",
    }))
  end

  return ui.row({
    justify = "space_between",
    align = "center",
    paddingV = 4,
    paddingH = 4,
  }, footerChildren)
end

local function renderIconPickerOverlay(): any
  return icons.renderIconPickerOverlay({
    search = iconPickerSearch,
    category = iconPickerCategory,
    current = iconPickerCurrent,
    cornerRadiusScale = cornerRadiusScale,
    tr = tr,
    onSearchChange = function(val)
      iconPickerSearch = val
      render()
    end,
    onCategorySelect = function(catId)
      iconPickerCategory = catId
      render()
    end,
    onPick = function(ic)
      local cb = iconPickerCallback
      closeIconPicker()
      if cb then
        cb(ic)
      end
    end,
    onClose = function()
      closeIconPicker()
    end,
  })
end

local function renderModalOverlay(): any
  if modalMode == "edit_app" then
    return modals.renderEditAppModal({
      editAppName = editAppName,
      editAppIcon = editAppIcon,
      editTarget = editTarget,
      formError = formError,
      cornerRadiusScale = cornerRadiusScale,
      tr = tr,
      openIconPicker = openIconPicker,
      onAppNameChange = function(val)
        editAppName = val
      end,
      onAppIconChange = function(ic)
        editAppIcon = ic
        render()
      end,
      onCancel = function()
        isModalOpen = false
        formError = ""
        render()
      end,
      getCustomStore = getCustomStore,
      onSave = function(currentStore, newName, newIcon)
        local ok, err = crud.renameApp(currentStore, editTarget.origApp, newName, newIcon)
        if not ok then
          formError = err or tr("modal.err_duplicate_app")
          render()
          return
        end

        local saved = saveCustomJson(currentStore)
        if not saved then
          formError = "Failed to write to file"
          render()
          return
        end

        if string.lower(activeApp) == string.lower(editTarget.origApp) or activeApp == editTarget.origApp then
          activeApp = string.lower(newName)
          saveState()
        end

        isModalOpen = false
        formError = ""
        noctalia.notify("Keybinds", tr("modal.saved_notify"))
        refreshAllBinds()
      end,
    })
  elseif modalMode == "edit_subcat" then
    return modals.renderEditSubcatModal({
      editSubcatName = editSubcatName,
      editSubcatIcon = editSubcatIcon,
      editSubcatParentApp = editSubcatParentApp,
      editTarget = editTarget,
      formError = formError,
      cornerRadiusScale = cornerRadiusScale,
      tr = tr,
      openIconPicker = openIconPicker,
      onSubcatNameChange = function(val)
        editSubcatName = val
      end,
      onSubcatIconChange = function(ic)
        editSubcatIcon = ic
        render()
      end,
      onCancel = function()
        isModalOpen = false
        formError = ""
        render()
      end,
      getCustomStore = getCustomStore,
      onSave = function(currentStore, newName, newIcon)
        local ok, err = crud.renameSubcategory(
          currentStore,
          editSubcatParentApp,
          editTarget.origSubcat,
          newName,
          newIcon
        )
        if not ok then
          formError = err or tr("modal.err_duplicate_subcat")
          render()
          return
        end

        local saved = saveCustomJson(currentStore)
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
    })
  else
    return modals.renderAddEditKeybindModal({
      modalMode = modalMode,
      formApp = formApp,
      formAppIcon = formAppIcon,
      formAppSelectedIdx = formAppSelectedIdx,
      formSubcat = formSubcat,
      formSubcatIcon = formSubcatIcon,
      formSubcatSelectedIdx = formSubcatSelectedIdx,
      formDesc = formDesc,
      formKey = formKey,
      formMods = formMods,
      formError = formError,
      cornerRadiusScale = cornerRadiusScale,
      tr = tr,
      openIconPicker = openIconPicker,
      onAppSelected = function(idx)
        formAppSelectedIdx = idx
        formSubcatSelectedIdx = 0
        render()
      end,
      onAppChange = function(val)
        formApp = val
      end,
      onAppIconChange = function(ic)
        formAppIcon = ic
        render()
      end,
      onSubcatSelected = function(idx)
        formSubcatSelectedIdx = idx
        render()
      end,
      onSubcatChange = function(val)
        formSubcat = val
      end,
      onSubcatIconChange = function(ic)
        formSubcatIcon = ic
        render()
      end,
      onDescChange = function(val)
        formDesc = val
      end,
      onKeyChange = function(val)
        formKey = val
      end,
      onModToggle = function(m)
        formMods[m] = not formMods[m]
        render()
      end,
      onCancel = function()
        isModalOpen = false
        formError = ""
        render()
      end,
      getCustomStore = getCustomStore,
      onSave = function(currentStore, payload)
        local effectiveKey = formKey
        if #payload.activeMods > 0 then
          local modPrefix = table.concat(payload.activeMods, " + ")
          if not string.find(string.upper(formKey), modPrefix, 1, true) then
            effectiveKey = modPrefix .. " + " .. formKey
          end
        end

        local success, errMsg
        if modalMode == "create" then
          success, errMsg = crud.addKeybind(
            currentStore,
            payload.effectiveApp,
            payload.effectiveSubcat,
            formDesc,
            effectiveKey,
            formAppIcon,
            formSubcatIcon
          )
        else
          success, errMsg = crud.updateKeybind(
            currentStore,
            editTarget.origApp,
            editTarget.origSubcat,
            editTarget.origBindIdx,
            payload.effectiveApp,
            payload.effectiveSubcat,
            formDesc,
            effectiveKey,
            formAppIcon,
            formSubcatIcon
          )
        end

        if not success then
          formError = errMsg or tr("modal.err_validation")
          render()
          return
        end

        local saved = saveCustomJson(currentStore)
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
    })
  end
end

render = function()
  cornerRadiusScale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
  gridColumns = tostring(noctalia.getConfig("grid_columns") or "3")

  local contentNode
  if isIconPickerOpen then
    contentNode = renderIconPickerOverlay()
  elseif isModalOpen then
    contentNode = renderModalOverlay()
  else
    contentNode = ui.column({
      key = "cheatsheet-content",
      flexGrow = 1,
      gap = 10,
      align = "stretch",
    }, {
      renderAppTabs(),
      renderKeybindsGrid(),
    })
  end

  panel.render(ui.column({
    padding = 16,
    gap = 10,
    flexGrow = 1,
    align = "stretch",
  }, {
    renderHeader(),
    contentNode,
    renderFooter(),
  }))
end

function onOpen(_context)
  local cfgPath = noctalia.getConfig("custom_file_path")
  if cfgPath and cfgPath ~= "" then
    customFilePath = cfgPath
  else
    local dataDir = noctalia.pluginDataDir()
    customFilePath = (dataDir and dataDir ~= "") and (dataDir .. "/custom_keybinds.json") or "~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json"
  end

  searchQuery = ""
  copiedId = nil
  isEditMode = false
  isModalOpen = false
  isIconPickerOpen = false
  iconPickerCallback = nil
  iconPickerSearch = ""
  iconPickerCategory = "all"
  formError = ""

  loadState()
  refreshAllBinds()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    if isIconPickerOpen then
      closeIconPicker()
    elseif isModalOpen then
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
