--!nonstrict
-- Floating Layout Hub Panel for Hyprland Switcher
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local layouts = require("./layouts.luau")
local components = require("./components.luau")

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function render()
  local effective = state.getEffectiveLayout()
  local availableLayouts = layouts.getAvailableLayouts(noctalia.getConfig)
  local activeDef = layouts.getLayout(effective) or layouts.LAYOUT_DEFS.dwindle
  local globalDef = layouts.getLayout(state.globalLayout) or layouts.LAYOUT_DEFS.dwindle
  local hasOverride = state.hasWorkspaceOverride()

  local statusBadge = nil
  local resetBtn = nil

  if hasOverride then
    statusBadge = ui.row({
      gap = 4,
      align = "center",
      paddingH = 6,
      paddingV = 2,
      radius = 4,
      fill = "secondary_container",
    }, {
      ui.glyph({ name = "circle-filled", size = 8, color = "secondary" }),
      ui.label({
        text = tr("panel.status_custom", { id = tostring(state.activeWorkspaceId) }),
        fontSize = 11,
        fontWeight = "bold",
        color = "on_secondary_container",
      }),
    })

    resetBtn = ui.button({
      glyph = "arrow-back-up",
      text = tr("panel.reset_to_global"),
      variant = "ghost",
      tooltip = tr("panel.reset_to_global_tooltip", { global = tr(globalDef.nameKey) }),
      onClick = function()
        hypr.resetWorkspaceToGlobal(state.activeWorkspaceId, function(ok)
          if ok and noctalia.getConfig("notify_on_change") ~= false then
            noctalia.notify(tr("manifest.name"), tr("notifications.reset_global", {
              id = tostring(state.activeWorkspaceId),
              layout = tr(globalDef.nameKey),
            }))
          end
        end)
      end,
    })
  else
    statusBadge = ui.row({
      gap = 4,
      align = "center",
      paddingH = 6,
      paddingV = 2,
      radius = 4,
      fill = "surface_variant",
    }, {
      ui.glyph({ name = "circle-filled", size = 8, color = "outline" }),
      ui.label({
        text = tr("panel.status_global", { layout = tr(globalDef.nameKey) }),
        fontSize = 11,
        color = "on_surface_variant",
      }),
    })
  end

  -- Header Bar
  local header = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 4,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "layout-grid", size = 20, color = "primary" }),
      ui.column({ gap = 2 }, {
        ui.label({ text = tr("panel.title"), fontSize = 15, fontWeight = "bold", color = "on_surface" }),
        ui.row({ gap = 6, align = "center" }, {
          statusBadge,
          resetBtn or ui.spacer({ width = 1 }),
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      -- Segmented Scope Control: Global vs Workspace
      ui.row({
        padding = 3,
        radius = 8,
        fill = "surface_variant",
        gap = 2,
      }, {
        ui.button({
          text = tr("panel.scope_global"),
          variant = (state.currentScope == "global") and "primary" or "ghost",
          onClick = function()
            state.setScope("global")
          end,
        }),
        ui.button({
          text = tr("panel.scope_workspace", { id = tostring(state.activeWorkspaceId) }),
          variant = (state.currentScope == "workspace") and "primary" or "ghost",
          onClick = function()
            state.setScope("workspace")
          end,
        }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })

  -- Layout Cards Grid (2 columns)
  local cardRows = {}
  local numLayouts = #availableLayouts
  for i = 1, numLayouts, 2 do
    local def1 = availableLayouts[i]
    local def2 = availableLayouts[i + 1]

    local card1 = components.renderLayoutCard(def1, def1.id == effective, hasOverride, function()
      hypr.setLayout(def1.id, state.currentScope, function(ok)
        if ok and noctalia.getConfig("notify_on_change") ~= false then
          local nextName = tr(def1.nameKey)
          local scopeDesc = (state.currentScope == "workspace")
            and ("Workspace " .. tostring(state.activeWorkspaceId))
            or tr("settings.default_scope.options.global")
          noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
            layout = nextName,
            scope = scopeDesc,
          }))
        end
      end)
    end)

    local card2 = nil
    if def2 then
      card2 = components.renderLayoutCard(def2, def2.id == effective, hasOverride, function()
        hypr.setLayout(def2.id, state.currentScope, function(ok)
          if ok and noctalia.getConfig("notify_on_change") ~= false then
            local nextName = tr(def2.nameKey)
            local scopeDesc = (state.currentScope == "workspace")
              and ("Workspace " .. tostring(state.activeWorkspaceId))
              or tr("settings.default_scope.options.global")
            noctalia.notify(tr("manifest.name"), tr("notifications.switched", {
              layout = nextName,
              scope = scopeDesc,
            }))
          end
        end)
      end)
    else
      card2 = ui.spacer({ flexGrow = 1 })
    end

    table.insert(cardRows, ui.row({ gap = 10, flexGrow = 1 }, { card1, card2 }))
  end

  -- Subactions Bar
  local subactionsBar = components.renderSubActionsBar(activeDef, function(cmd)
    hypr.dispatchSubAction(cmd)
  end)

  -- Footer Bar
  local footer = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 4,
  }, {
    ui.label({
      text = tr("panel.hint"),
      fontSize = 11,
      color = "on_surface_variant",
    }),
    ui.button({
      glyph = "settings",
      text = tr("panel.open_settings"),
      variant = "ghost",
      onClick = function()
        noctalia.openSettings()
      end,
    }),
  })

  -- Main Panel Layout
  local content = ui.column({
    padding = 16,
    gap = 14,
    fill = "surface",
    flexGrow = 1,
  }, {
    header,
    ui.separator(),
    ui.column({ gap = 10, flexGrow = 1 }, cardRows),
    ui.separator(),
    subactionsBar,
    ui.separator(),
    footer,
  })

  panel.render(content)
end

-- Subscribe panel to state updates
state.subscribe(function()
  render()
end)

function onOpen(context: any)
  hypr.refresh()
  render()
end

function onClose()
  -- Clean up if needed
end

-- Initial render
render()
