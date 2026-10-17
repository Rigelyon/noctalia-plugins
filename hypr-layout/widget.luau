--!nonstrict
-- Status Bar Widget for Hyprland Layout Switcher
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layouts = require("./layouts.luau")

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function updateWidgetPresentation()
  local effectiveLayoutId = state.getEffectiveLayout()
  local def = layouts.getLayout(effectiveLayoutId) or layouts.LAYOUT_DEFS.dwindle
  local layoutName = tr(def.nameKey)

  barWidget.setGlyph(def.glyph)

  local showLabel = noctalia.getConfig("show_label_in_bar")
  if showLabel ~= false then
    barWidget.setText(layoutName)
  else
    barWidget.setText("")
  end

  local scopeText = (state.currentScope == "workspace")
    and ("WS " .. tostring(state.activeWorkspaceId))
    or tr("settings.default_scope.options.global")

  barWidget.setTooltip(tr("widget.tooltip", {
    layout = layoutName,
    scope = scopeText,
  }))
end

-- Re-render presentation whenever central state changes
state.subscribe(function()
  updateWidgetPresentation()
end)

-- Left-click: Cycle to next layout in sequence
function onClick()
  local effective = state.getEffectiveLayout()
  local nextDef = layouts.getNextLayout(effective, noctalia.getConfig)
  local targetScope = state.currentScope

  hypr.setLayout(nextDef.id, targetScope, function(ok)
    if ok then
      local notifyEnabled = noctalia.getConfig("notify_on_change")
      if notifyEnabled ~= false then
        local nextName = tr(nextDef.nameKey)
        local scopeDesc = (targetScope == "workspace")
          and ("Workspace " .. tostring(state.activeWorkspaceId))
          or tr("settings.default_scope.options.global")
        noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
          layout = nextName,
          scope = scopeDesc,
        }))
      end
    end
  end)
end

-- Right-click: Open floating Layout Hub panel
function onRightClick()
  noctalia.togglePanel("rigelyon/hypr-layout:panel")
end

-- Initialize IPC and widget presentation
hypr.init()
updateWidgetPresentation()
