--!nonstrict
-- Main Floating Hub Panel for Hyprland Monitor Manager
local state = require("./state.luau")
local hypr = require("./hypr.luau")
local config = require("./config.luau")
local layoutMath = require("./layout_math.luau")
local components = require("./components.luau")
local profiles = require("./profiles.luau")

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function render()
  local monList = state.workingMonitors
  local selected = state.getSelectedMonitor()

  -- Top Header
  local header = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 6,
    paddingV = 4,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "device-desktop", size = 22, color = "primary" }),
      ui.column({ gap = 2 }, {
        ui.label({
          text = tr("panel.title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = tr("panel.subtitle", { count = tostring(#monList) }),
          fontSize = 11,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.button({
        text = tr("panel.tab_inspector"),
        variant = (state.activeTab == "inspector") and "primary" or "ghost",
        onClick = function()
          state.activeTab = "inspector"
          state.notify()
        end,
      }),
      ui.button({
        text = tr("panel.tab_profiles"),
        variant = (state.activeTab == "profiles") and "primary" or "ghost",
        onClick = function()
          state.activeTab = "profiles"
          state.notify()
        end,
      }),
    }),
  })

  -- Visual Canvas Area
  local proj = layoutMath.computeCanvasProjection(monList, 700, 180)
  local canvasBoxes = {}
  for _, m in ipairs(monList) do
    if not m.disabled then
      local b = proj.items[m.name]
      if b then
        table.insert(canvasBoxes, components.renderCanvasCard(
          m,
          b,
          (m.name == state.selectedMonitorName),
          function()
            state.selectMonitor(m.name)
          end
        ))
      end
    end
  end

  local canvas = ui.column({ gap = 8 }, {
    components.renderCanvasToolbar({
      onSnapLeft = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapLeft(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapRight = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapRight(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapAbove = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapAbove(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onSnapBelow = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.snapBelow(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onAlignTops = function()
        if selected and #monList > 1 then
          local anchor = (monList[1].name == selected.name) and monList[2] or monList[1]
          layoutMath.alignTops(selected, anchor)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
      onPresetExtend = function()
        layoutMath.presetExtend(monList)
        state.hasPendingChanges = true
        state.notify()
      end,
      onPresetMirror = function()
        if selected then
          layoutMath.presetMirror(monList, selected.name)
          state.hasPendingChanges = true
          state.notify()
        end
      end,
    }),
    ui.row({
      width = 708,
      height = 180,
      radius = 8,
      fill = "surface_variant",
      border = "outline",
      borderWidth = 1,
      padding = 8,
      align = "center",
      justify = "center",
      gap = 12,
    }, canvasBoxes),
  })

  -- Lower Workspace: Inspector or Profiles Tab
  local lowerContent = nil
  if state.activeTab == "inspector" and selected then
    lowerContent = ui.column({ gap = 12, padding = 4 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({ name = "device-desktop", size = 16, color = "secondary" }),
          ui.label({ text = selected.name, fontWeight = "bold", fontSize = 14 }),
          ui.label({ text = selected.description or "", fontSize = 11, color = "on_surface_variant" }),
        }),
        ui.button({
          text = selected.disabled and "Disabled" or "Enabled",
          variant = selected.disabled and "outline" or "primary",
          onClick = function()
            state.setWorkingProperty(selected.name, "disabled", not selected.disabled)
          end,
        }),
      }),
      ui.row({ gap = 16 }, {
        ui.column({ gap = 4, flexGrow = 1 }, {
          ui.label({ text = tr("panel.label_scale"), fontSize = 11, color = "on_surface_variant" }),
          components.renderScaleSelector(selected.scale, function(newScale)
            state.setWorkingProperty(selected.name, "scale", newScale)
          end),
        }),
        ui.column({ gap = 4, flexGrow = 1 }, {
          ui.label({ text = tr("panel.label_orientation"), fontSize = 11, color = "on_surface_variant" }),
          components.renderOrientationSelector(selected.transform, function(newTrans)
            state.setWorkingProperty(selected.name, "transform", newTrans)
          end),
        }),
      }),
    })
  else
    -- Profiles Tab
    local profList = profiles.loadProfiles()
    local profileCards = {}
    for _, p in ipairs(profList) do
      local isAct = (p.id == profiles.activeProfileId)
      table.insert(profileCards, ui.row({
        justify = "space_between",
        align = "center",
        padding = 8,
        radius = 6,
        fill = "surface_variant",
      }, {
        ui.column({ gap = 2 }, {
          ui.label({ text = p.name, fontWeight = "bold", fontSize = 13 }),
          ui.label({ text = table.concat(p.fingerprint, " + "), fontSize = 10, color = "on_surface_variant" }),
        }),
        ui.row({ gap = 4 }, {
          ui.button({
            text = isAct and tr("profiles.badge_active") or tr("profiles.btn_apply"),
            variant = isAct and "outline" or "primary",
            onClick = function()
              state.workingMonitors = p.monitors
              profiles.activeProfileId = p.id
              hypr.applyBatch(p.monitors)
              state.notify()
            end,
          }),
          ui.button({
            text = tr("profiles.btn_delete"),
            variant = "ghost",
            onClick = function()
              profiles.deleteProfile(p.id)
              state.notify()
            end,
          }),
        }),
      }))
    end

    lowerContent = ui.column({ gap = 8, padding = 4 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = tr("profiles.title"), fontWeight = "bold", fontSize = 13 }),
        ui.button({
          text = tr("profiles.save_current"),
          variant = "outline",
          onClick = function()
            local defName = "Profile " .. tostring(#profList + 1)
            profiles.saveProfile(defName, state.workingMonitors)
            state.notify()
          end,
        }),
      }),
      ui.column({ gap = 6 }, profileCards),
    })
  end

  -- Sourcing tip banner if missing
  local sourceTip = nil
  if not config.isSourcedInHyprlandConf() then
    sourceTip = ui.row({
      padding = 8,
      radius = 6,
      fill = "surface_variant",
      justify = "space_between",
      align = "center",
    }, {
      ui.label({ text = tr("panel.tip_source"), fontSize = 11, color = "secondary" }),
      ui.button({
        text = tr("panel.copy_source"),
        variant = "ghost",
        fontSize = 11,
        onClick = function()
          if noctalia and noctalia.copyToClipboard then
            noctalia.copyToClipboard("source = ~/.config/hypr/monitors.conf", "text/plain")
            if noctalia.notify then
              noctalia.notify("Copied to clipboard", "source = ~/.config/hypr/monitors.conf")
            end
          end
        end,
      }),
    })
  end

  -- Safety countdown modal
  local safetyModal = nil
  if state.isSafetyModalVisible then
    safetyModal = components.renderSafetyModal(
      state.safetyTimer,
      function() state.keepChanges() end,
      function() state.revertToSafe() end
    )
  end

  local footerButtons = {}
  if state.hasPendingChanges then
    table.insert(footerButtons, ui.button({
      text = tr("panel.btn_revert"),
      variant = "ghost",
      onClick = function() state.discardPendingChanges() end,
    }))
  end
  table.insert(footerButtons, ui.button({
    text = tr("panel.btn_apply"),
    variant = "primary",
    onClick = function()
      hypr.applyBatch(state.workingMonitors, function(ok)
        if ok then
          state.startSafetyCountdown()
        end
      end)
    end,
  }))
  table.insert(footerButtons, ui.button({
    text = tr("panel.btn_save_config"),
    variant = "secondary",
    onClick = function()
      local ok, err = config.writeConfig(state.workingMonitors)
      if ok and noctalia and noctalia.notify then
        noctalia.notify("Monitors Saved", "Saved to ~/.config/hypr/monitors.conf")
      end
    end,
  }))

  local footer = ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 6,
    paddingV = 6,
  }, {
    ui.label({
      text = state.hasPendingChanges
        and tr("panel.status_pending", { count = "●" })
        or tr("panel.status_in_sync"),
      fontSize = 11,
      color = state.hasPendingChanges and "secondary" or "on_surface_variant",
    }),
    ui.row({ gap = 8 }, footerButtons),
  })

  local mainChildren = { header }
  if sourceTip then
    table.insert(mainChildren, sourceTip)
  end
  table.insert(mainChildren, canvas)
  table.insert(mainChildren, ui.separator({}))
  if lowerContent then
    table.insert(mainChildren, lowerContent)
  end
  if safetyModal then
    table.insert(mainChildren, safetyModal)
  end
  table.insert(mainChildren, ui.spacer({ flexGrow = 1 }))
  table.insert(mainChildren, ui.separator({}))
  table.insert(mainChildren, footer)

  return ui.column({
    padding = 16,
    gap = 12,
  }, mainChildren)
end

state.subscribe(function()
  -- Re-render panel on state updates
  if panel and panel.render then
    panel.render(render())
  end
end)

state.init(function()
  if panel and panel.render then
    panel.render(render())
  end
end)
