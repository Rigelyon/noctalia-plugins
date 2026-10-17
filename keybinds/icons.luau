--!nonstrict
-- Icon Picker catalog & modal component for Keybinds Cheatsheet
local icons = {}

icons.ICON_CATEGORIES = {
  { id = "all", labelKey = "modal.category_all" },
  { id = "dev", labelKey = "modal.category_dev", icons = { "terminal", "code", "command", "cpu", "database", "server", "git-branch", "bug", "braces", "play", "package", "layers" } },
  { id = "system", labelKey = "modal.category_system", icons = { "app-window", "monitor", "settings", "sliders", "power", "maximize", "minimize", "shield", "bell", "wifi", "sun", "moon", "lock" } },
  { id = "media", labelKey = "modal.category_media", icons = { "music", "video", "volume-2", "volume-x", "camera", "image", "play", "pause", "disc", "mic", "headphones" } },
  { id = "navigation", labelKey = "modal.category_navigation", icons = { "globe", "search", "bookmark", "compass", "external-link", "link", "map", "send", "home" } },
  { id = "files", labelKey = "modal.category_files", icons = { "file-text", "folder", "clipboard", "typography", "file-code", "book-open", "archive", "paperclip" } },
  { id = "tools", labelKey = "modal.category_tools", icons = { "sparkles", "star", "tool", "key", "keyboard", "zap", "flag", "tag", "activity", "layout-grid" } },
}

function icons.renderIconPickerOverlay(props: {
  search: string,
  category: string,
  current: string,
  cornerRadiusScale: number,
  tr: (string, any?) -> string,
  onSearchChange: (string) -> (),
  onCategorySelect: (string) -> (),
  onPick: (string) -> (),
  onClose: () -> (),
}): any
  local search = props.search or ""
  local category = props.category or "all"
  local current = props.current or "terminal"
  local cornerRadiusScale = props.cornerRadiusScale or 1.0
  local tr = props.tr

  local visibleIcons: { string } = {}
  local seen: { [string]: boolean } = {}

  if category == "all" then
    for _, cat in ipairs(icons.ICON_CATEGORIES) do
      if cat.icons then
        for _, ic in ipairs(cat.icons) do
          if not seen[ic] then
            seen[ic] = true
            table.insert(visibleIcons, ic)
          end
        end
      end
    end
  else
    for _, cat in ipairs(icons.ICON_CATEGORIES) do
      if cat.id == category and cat.icons then
        for _, ic in ipairs(cat.icons) do
          table.insert(visibleIcons, ic)
        end
        break
      end
    end
  end

  local searchLower = string.lower(noctalia.string.trim(search))
  if searchLower ~= "" then
    local filtered: { string } = {}
    for _, ic in ipairs(visibleIcons) do
      if string.find(string.lower(ic), searchLower, 1, true) then
        table.insert(filtered, ic)
      end
    end
    visibleIcons = filtered
  end

  -- Category chips
  local catChips = {}
  for _, cat in ipairs(icons.ICON_CATEGORIES) do
    local isSel = (cat.id == category)
    table.insert(catChips, ui.row({
      paddingV = 4,
      paddingH = 10,
      radius = 6 * cornerRadiusScale,
      fill = isSel and "primary" or "surface_variant",
      onClick = function()
        props.onCategorySelect(cat.id)
      end,
    }, {
      ui.label({
        text = tr(cat.labelKey),
        fontSize = 10,
        fontWeight = isSel and "bold" or "normal",
        color = isSel and "on_primary" or "on_surface_variant",
      }),
    }))
  end

  -- Grid of 8 icons per row
  local iconRows = {}
  local cols = 8
  local total = #visibleIcons

  if total == 0 then
    table.insert(iconRows, ui.column({
      align = "center",
      justify = "center",
      padding = 24,
      gap = 8,
    }, {
      ui.glyph({ name = "search", size = 24, color = "on_surface_variant" }),
      ui.label({ text = tr("panel.no_results", { query = search }), fontSize = 11, color = "on_surface_variant" }),
    }))
  else
    local curRow = {}
    for i, ic in ipairs(visibleIcons) do
      local isSel = (ic == current)
      table.insert(curRow, ui.row({
        width = 46,
        height = 42,
        align = "center",
        justify = "center",
        radius = 6 * cornerRadiusScale,
        fill = isSel and "primary" or "surface_variant",
        tooltip = ic,
        onClick = function()
          props.onPick(ic)
        end,
      }, {
        ui.glyph({
          name = ic,
          size = 18,
          color = isSel and "on_primary" or "on_surface",
        }),
      }))

      if #curRow == cols or i == total then
        if i == total and #curRow < cols then
          while #curRow < cols do
            table.insert(curRow, ui.spacer({ width = 46, height = 42 }))
          end
        end
        table.insert(iconRows, ui.row({ gap = 6, align = "center", justify = "space_between" }, curRow))
        curRow = {}
      end
    end
  end

  return ui.column({
    flexGrow = 1,
    align = "center",
    justify = "center",
    padding = 16,
  }, {
    ui.column({
      width = 480,
      radius = 12 * cornerRadiusScale,
      fill = "surface",
      padding = 16,
      gap = 10,
    }, {
      -- Header
      ui.row({
        justify = "space_between",
        align = "center",
      }, {
        ui.row({ gap = 8, align = "center" }, {
          ui.glyph({ name = "sparkles", size = 16, color = "primary" }),
          ui.label({
            text = tr("modal.icon_picker_title"),
            fontSize = 14,
            fontWeight = "bold",
            color = "on_surface",
          }),
        }),
        ui.button({
          glyph = "x",
          variant = "ghost",
          onClick = function()
            props.onClose()
          end,
        }),
      }),

      -- Search Input
      ui.input({
        key = "icon-picker-search",
        placeholder = tr("modal.icon_search_placeholder"),
        value = search,
        onChange = function(val)
          props.onSearchChange(val)
        end,
      }),

      -- Category Chips
      ui.row({ gap = 4, align = "center" }, catChips),

      -- Scrollable Grid
      ui.scroll({
        flexGrow = 1,
        height = 220,
        gap = 6,
      }, iconRows),
    }),
  })
end

return icons
