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

  -- Visual Canvas Area: detect if monitors are vertically stacked
  local isVertical = false
  if #monList > 1 then
    local m1 = monList[1]
    local m2 = monList[2]
    if math.abs((m2.y or 0) - (m1.y or 0)) > math.abs((m2.x or 0) - (m1.x or 0)) then
      isVertical = true
    end
  end

  local proj = layoutMath.computeCanvasProjection(monList, 740, 180)

  -- Identify single true main monitor: first active unmirrored monitor at 0,0
  local mainMonitorName = nil
  for _, m in ipairs(monList) do
    if not m.disabled and (not m.mirrorOf or m.mirrorOf == "" or m.mirrorOf == "none") and (m.x == 0 and m.y == 0) then
      mainMonitorName = m.name
      break
    end
  end
  if not mainMonitorName and #monList > 0 then
    mainMonitorName = monList[1].name
  end

  local cardsData = {}
  for _, m in ipairs(monList) do
    local b = proj.items[m.name]
    if b then
      table.insert(cardsData, {
        m = m,
        node = components.renderCanvasCard(
          m,
          b,
          (m.name == state.selectedMonitorName),
          function()
            state.selectMonitor(m.name)
          end,
          (m.name == mainMonitorName)
        ),
      })
    end
  end

  -- Sort cards according to spatial position, active monitors first
  table.sort(cardsData, function(a, b)
    if a.m.disabled ~= b.m.disabled then
      return not a.m.disabled
    end
    local ax, ay = a.m.x or 0, a.m.y or 0
    local bx, by = b.m.x or 0, b.m.y or 0
    if isVertical then
      if ay ~= by then return ay < by end
      return ax < bx
    else
      if ax ~= bx then return ax < bx end
      return ay < by
    end
  end)

  local canvasBoxes = {}
  for _, cd in ipairs(cardsData) do
    table.insert(canvasBoxes, cd.node)
  end

  local canvasContainer = nil
  if isVertical then
    canvasContainer = ui.column({
      height = 180,
      radius = 8,
      fill = "surface_variant",
      border = "outline",
      borderWidth = 1,
      padding = 8,
      align = "center",
      justify = "center",
      gap = 8,
    }, canvasBoxes)
  else
    canvasContainer = ui.row({
      height = 180,
      radius = 8,
      fill = "surface_variant",
      border = "outline",
      borderWidth = 1,
      padding = 8,
      align = "center",
      justify = "center",
      gap = 12,
    }, canvasBoxes)
  end

  local function getSnapAnchor(target: layoutMath.Monitor): layoutMath.Monitor?
    for _, m in ipairs(monList) do
      if m.name ~= target.name and not m.disabled then
        return m
      end
    end
    for _, m in ipairs(monList) do
      if m.name ~= target.name then
        return m
      end
    end
    return nil
  end

  local canvas = ui.column({ gap = 6 }, {
    components.renderCanvasToolbar({
      isMulti = (#monList > 1),
      onSnapLeft = function()
        if selected and #monList > 1 then
          local anchor = getSnapAnchor(selected)
          if anchor then
            layoutMath.snapLeft(selected, anchor)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
          end
        end
      end,
      onSnapRight = function()
        if selected and #monList > 1 then
          local anchor = getSnapAnchor(selected)
          if anchor then
            layoutMath.snapRight(selected, anchor)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
          end
        end
      end,
      onSnapAbove = function()
        if selected and #monList > 1 then
          local anchor = getSnapAnchor(selected)
          if anchor then
            layoutMath.snapAbove(selected, anchor)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
          end
        end
      end,
      onSnapBelow = function()
        if selected and #monList > 1 then
          local anchor = getSnapAnchor(selected)
          if anchor then
            layoutMath.snapBelow(selected, anchor)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
          end
        end
      end,
      onAlignTops = function()
        if selected and #monList > 1 then
          local anchor = getSnapAnchor(selected)
          if anchor then
            layoutMath.alignTops(selected, anchor)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
          end
        end
      end,
      onPresetExtend = function()
        layoutMath.presetExtend(monList)
        for _, m in ipairs(monList) do
          m._unmirroredX = m.x
          m._unmirroredY = m.y
        end
        layoutMath.normalizeCoordinates(monList)
        state.hasPendingChanges = true
        state.notify()
      end,
      onPresetMirror = function()
        local mainName = nil
        for _, m in ipairs(monList) do
          if not m.disabled and (not m.mirrorOf or m.mirrorOf == "" or m.mirrorOf == "none") and (m.x == 0 and m.y == 0) then
            mainName = m.name
            break
          end
        end
        if not mainName and #monList > 0 then
          mainName = monList[1].name
        end
        layoutMath.presetMirror(monList, mainName)
        layoutMath.normalizeCoordinates(monList)
        state.hasPendingChanges = true
        state.notify()
      end,
    }),
    canvasContainer,
  })

  -- Lower Workspace: Inspector or Profiles Tab
  local lowerContent = nil
  if state.activeTab == "inspector" and selected then
    lowerContent = ui.column({ gap = 8, padding = 2 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({
            name = selected.disabled and "eye-off" or "device-desktop",
            size = 16,
            color = selected.disabled and "on_surface_variant" or "secondary",
          }),
          ui.label({ text = selected.name, fontWeight = "bold", fontSize = 14 }),
          ui.label({ text = selected.description or "", fontSize = 11, color = "on_surface_variant" }),
        }),
        ui.button({
          text = selected.disabled and tr("panel.btn_enable_display") or tr("panel.btn_disable_display"),
          variant = selected.disabled and "primary" or "outline",
          onClick = function()
            state.setWorkingProperty(selected.name, "disabled", not selected.disabled)
          end,
        }),
      }),
      (#monList > 1) and ui.column({ gap = 4 }, {
        ui.label({
          text = tr("panel.label_mirror") or "Mode Tampilan",
          fontSize = 11,
          color = "on_surface_variant",
        }),
        components.renderMirrorSelector(selected, monList, function(targetMirrorOf)
          if targetMirrorOf and targetMirrorOf ~= "" and targetMirrorOf ~= "none" then
            -- Switching to clone
            if not selected.mirrorOf or selected.mirrorOf == "" or selected.mirrorOf == "none" then
              selected._unmirroredX = selected.x
              selected._unmirroredY = selected.y
            end
            selected.mirrorOf = targetMirrorOf
            selected.x = 0
            selected.y = 0
          else
            -- Switching back to independent
            local prevSource = selected.mirrorOf
            selected.mirrorOf = nil

            local restored = false
            if selected._unmirroredX and (selected._unmirroredX ~= 0 or selected._unmirroredY ~= 0) then
              selected.x = selected._unmirroredX
              selected.y = selected._unmirroredY or 0
              local collides = false
              for _, other in ipairs(monList) do
                if other.name ~= selected.name and not other.disabled and (not other.mirrorOf or other.mirrorOf == "" or other.mirrorOf == "none") then
                  if (other.x or 0) == selected.x and (other.y or 0) == selected.y then
                    collides = true
                    break
                  end
                end
              end
              if not collides then
                restored = true
              end
            end

            if not restored then
              local anchor = nil
              if prevSource and prevSource ~= "" then
                for _, other in ipairs(monList) do
                  if other.name == prevSource and not other.disabled then
                    anchor = other
                    break
                  end
                end
              end
              if not anchor then
                for _, other in ipairs(monList) do
                  if other.name ~= selected.name and not other.disabled and (other.x == 0 and other.y == 0) then
                    anchor = other
                    break
                  end
                end
              end
              if not anchor then
                for _, other in ipairs(monList) do
                  if other.name ~= selected.name and not other.disabled then
                    anchor = other
                    break
                  end
                end
              end

              if anchor then
                layoutMath.snapRight(selected, anchor)
              else
                selected.x = 0
                selected.y = 0
              end
            end

            layoutMath.resolveCollisions(monList)
            layoutMath.normalizeCoordinates(monList)
            selected._unmirroredX = selected.x
            selected._unmirroredY = selected.y
          end
          state.hasPendingChanges = true
          state.notify()
        end),
      }) or nil,
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
      ui.row({ gap = 16, justify = "space_between", align = "flex_start" }, {
        ui.column({ gap = 4 }, {
          ui.label({ text = tr("panel.label_refresh_rate") or "Kecepatan Segar", fontSize = 11, color = "on_surface_variant" }),
          components.renderRefreshRateSelector(selected, function(newRate)
            state.setWorkingProperty(selected.name, "refreshRate", newRate)
          end),
        }),
        ui.column({ gap = 4, align = "flex_end" }, {
          ui.label({ text = tr("panel.label_position") or "Koordinat Posisi", fontSize = 11, color = "on_surface_variant" }),
          components.renderPositionDisplay(selected, function(newX, newY)
            selected.x = newX
            selected.y = newY
            selected._unmirroredX = newX
            selected._unmirroredY = newY
            layoutMath.resolveCollisions(monList, selected.name)
            layoutMath.normalizeCoordinates(monList)
            state.hasPendingChanges = true
            state.notify()
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
              state.workingMonitors = state.cloneMonitors(p.monitors)
              profiles.activeProfileId = p.id
              state.applyConfig()
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
            local defName = tr("profiles.default_name", { num = tostring(#profList + 1) })
            if defName == "profiles.default_name" then
              defName = "Profil " .. tostring(#profList + 1)
            end
            profiles.saveProfile(defName, state.workingMonitors)
            state.notify()
          end,
        }),
      }),
      ui.column({ gap = 6 }, profileCards),
    })
  end

  local footer = nil
  if state.isSafetyModalVisible then
    footer = components.renderSafetyModal(
      state.safetyTimer,
      function() state.keepChanges() end,
      function() state.revertToSafe() end
    )
  else
    local footerButtons = {}
    if state.hasPendingChanges then
      table.insert(footerButtons, ui.button({
        text = tr("panel.btn_revert"),
        variant = "ghost",
        onClick = function() state.discardPendingChanges() end,
      }))
    end
    table.insert(footerButtons, ui.button({
      text = tr("panel.btn_save_config"),
      variant = "primary",
      onClick = function()
        state.applyConfig()
      end,
    }))

    footer = ui.row({
      justify = "space_between",
      align = "center",
      paddingH = 4,
      paddingV = 2,
      border = "none",
      borderWidth = 0,
      fill = "transparent",
      radius = 0,
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
  end

  local mainChildren = { header, canvas, ui.separator({}) }
  if lowerContent then
    table.insert(mainChildren, lowerContent)
  end
  table.insert(mainChildren, ui.separator({}))
  table.insert(mainChildren, footer)

  return ui.column({
    padding = 14,
    gap = 8,
  }, mainChildren)
end

state.subscribe(function()
  -- Re-render panel on state updates
  if panel and panel.render then
    panel.render(render())
  end
end)

function onOpen(context: any)
  state.refresh(function()
    if panel and panel.render then
      panel.render(render())
    end
  end)
end

function onClose()
  -- Clean up if needed
end

state.init(function()
  if panel and panel.render then
    panel.render(render())
  end
end)
