--!nonstrict
-- Status Bar Widget Entry Point for Hyprland Monitor Manager
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layoutMath = require("./layout_math.luau")

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function updateWidget()
  if not barWidget then return end

  local count = #state.monitors
  local isMirror = false
  local tooltips = {
    { key = tr("widget.tooltip_title"), value = tr("panel.subtitle", { count = tostring(count) }) }
  }

  for _, m in ipairs(state.monitors) do
    if m.mirrorOf and m.mirrorOf ~= "" and m.mirrorOf ~= "none" then
      isMirror = true
    end
    table.insert(tooltips, {
      key = m.name,
      value = string.format("%dx%d @ %.0fHz • %.2fx", m.width, m.height, m.refreshRate, m.scale)
    })
  end

  barWidget.setGlyph(isMirror and "screen-share" or "device-desktop")
  local showCount = true
  if noctalia and noctalia.getConfig then
    showCount = noctalia.getConfig("show_count_in_bar") ~= false
  end

  if showCount and count > 0 then
    barWidget.setText(tostring(count))
  else
    barWidget.setText("")
  end

  barWidget.setTooltip(tooltips)
end

function onClick()
  -- Left click: Quick Presets cycle or toggle panel
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/hypr-monitors:panel")
  end
end

function onRightClick()
  -- Right click: Open full visual manager panel
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/hypr-monitors:panel")
  end
end

state.subscribe(function()
  updateWidget()
end)

state.init(function()
  updateWidget()
end)
