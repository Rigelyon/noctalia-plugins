--!nonstrict
-- Declarative UI Component Library for Hyprland Monitor Manager
local layoutMath = require("./layout_math.luau")

local components = {}

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

-- Renders a proportional monitor card inside the canvas preview
function components.renderCanvasCard(
  m: layoutMath.Monitor,
  bounds: { x: number, y: number, w: number, h: number },
  isSelected: boolean,
  onClick: () -> (),
  isMain: boolean?
): any
  local borderFill = isSelected and "primary" or "outline"
  local bgFill = isSelected and "surface" or "surface_variant"
  local isPortrait = (m.transform == 1 or m.transform == 3)

  local badgeText = ""
  if m.disabled then
    badgeText = tr("panel.badge_disabled") or "Nonaktif"
  elseif m.mirrorOf and m.mirrorOf ~= "" and m.mirrorOf ~= "none" then
    badgeText = tr("panel.badge_clone", { source = m.mirrorOf }) or ("Duplikat " .. m.mirrorOf)
  elseif isMain or (isMain == nil and (m.x == 0 and m.y == 0)) then
    badgeText = tr("panel.badge_main") or "Layar Utama"
  else
    badgeText = string.format("+%d,%d", m.x or 0, m.y or 0)
  end

  local iconName = m.disabled and "eye-off" or "device-desktop"
  local iconColor = isSelected and "primary" or "on_surface_variant"
  local titleColor = isSelected and "primary" or (m.disabled and "on_surface_variant" or "on_surface")
  local badgeColor = isSelected and "secondary" or "on_surface_variant"

  local headerNode = nil
  if isPortrait or bounds.w < 145 then
    headerNode = ui.column({ gap = 2, align = "center" }, {
      ui.row({ gap = 3, align = "center" }, {
        ui.glyph({ name = iconName, size = 11, color = iconColor }),
        ui.label({
          text = m.name,
          fontWeight = "bold",
          fontSize = 10,
          color = titleColor,
        }),
      }),
      (badgeText ~= "") and ui.label({
        text = badgeText,
        fontSize = 8,
        fontWeight = "bold",
        color = badgeColor,
      }) or nil,
    })
  else
    headerNode = ui.row({ justify = "space_between", align = "center" }, {
      ui.row({ gap = 4, align = "center" }, {
        ui.glyph({ name = iconName, size = 12, color = iconColor }),
        ui.label({
          text = m.name,
          fontWeight = "bold",
          fontSize = 11,
          color = titleColor,
        }),
      }),
      (badgeText ~= "") and ui.label({
        text = badgeText,
        fontSize = 9,
        fontWeight = "bold",
        color = badgeColor,
      }) or nil,
    })
  end

  local subInfo = ""
  if m.disabled then
    subInfo = tr("panel.badge_disabled") or "Nonaktif"
  else
    subInfo = string.format("%.0fHz", m.refreshRate or 60)
    if isPortrait or bounds.w < 120 then
      if m.scale and m.scale ~= 1.0 then
        subInfo = subInfo .. string.format(" • %.1fx", m.scale)
      end
      if isPortrait then
        subInfo = subInfo .. " ↻"
      end
    else
      subInfo = string.format("%.0fHz • %.2fx%s", m.refreshRate or 60, m.scale or 1, isPortrait and " ↻90°" or "")
    end
  end

  local centerNode = ui.column({ align = "center", gap = 1 }, {
    ui.label({
      text = string.format("%dx%d", m.width, m.height),
      fontSize = (isPortrait or bounds.w < 145) and 10 or 12,
      fontWeight = "bold",
      color = m.disabled and "on_surface_variant" or "on_surface",
    }),
    ui.label({
      text = subInfo,
      fontSize = (isPortrait or bounds.w < 145) and 9 or 10,
      color = isSelected and "secondary" or "on_surface_variant",
    }),
  })

  return ui.column({
    width = bounds.w,
    height = bounds.h,
    radius = 8,
    fill = bgFill,
    border = borderFill,
    borderWidth = isSelected and 2 or 1,
    padding = (bounds.w < 110 or bounds.h < 110) and 4 or 8,
    justify = "space_between",
    align = "center",
    onClick = onClick,
  }, { headerNode, centerNode })
end

-- Renders the quick snap and preset toolbar above the canvas
function components.renderCanvasToolbar(actions: {
  isMulti: boolean?,
  onSnapLeft: () -> (),
  onSnapRight: () -> (),
  onSnapAbove: () -> (),
  onSnapBelow: () -> (),
  onAlignTops: () -> (),
  onPresetExtend: () -> (),
  onPresetMirror: () -> (),
}): any
  local isMulti = actions.isMulti ~= false

  if isMulti then
    return ui.row({ gap = 4, align = "center", justify = "space_between" }, {
      ui.row({ gap = 2, align = "center" }, {
        ui.button({
          text = tr("panel.snap_left"),
          variant = "ghost",
          fontSize = 11,
          onClick = actions.onSnapLeft,
        }),
        ui.button({
          text = tr("panel.snap_right"),
          variant = "ghost",
          fontSize = 11,
          onClick = actions.onSnapRight,
        }),
        ui.button({
          text = tr("panel.snap_above"),
          variant = "ghost",
          fontSize = 11,
          onClick = actions.onSnapAbove,
        }),
        ui.button({
          text = tr("panel.snap_below"),
          variant = "ghost",
          fontSize = 11,
          onClick = actions.onSnapBelow,
        }),
        ui.button({
          text = tr("panel.align_tops"),
          variant = "ghost",
          fontSize = 11,
          onClick = actions.onAlignTops,
        }),
      }),
      ui.row({ gap = 4, align = "center" }, {
        ui.button({
          text = tr("panel.preset_extend"),
          variant = "outline",
          fontSize = 11,
          onClick = actions.onPresetExtend,
        }),
        ui.button({
          text = tr("panel.preset_mirror"),
          variant = "outline",
          fontSize = 11,
          onClick = actions.onPresetMirror,
        }),
      }),
    })
  else
    return ui.row({ gap = 6, align = "center" }, {
      ui.glyph({ name = "device-desktop", size = 14, color = "secondary" }),
      ui.label({ text = tr("panel.single_display") or "Satu Layar Terhubung", fontSize = 11, color = "on_surface_variant" }),
    })
  end
end

-- Renders display scale steppers and quick pill buttons
function components.renderScaleSelector(currentScale: number?, onScaleChanged: (number) -> ()): any
  local scaleVal = currentScale or 1.0
  local presets = { 1.0, 1.25, 1.5, 1.75, 2.0 }
  local pillButtons = {}

  for _, s in ipairs(presets) do
    local isAct = math.abs(scaleVal - s) < 0.01
    table.insert(pillButtons, ui.button({
      text = string.format("%.2fx", s),
      variant = isAct and "primary" or "ghost",
      fontSize = 11,
      onClick = function() onScaleChanged(s) end,
    }))
  end

  return ui.row({ gap = 6, align = "center" }, {
    ui.button({
      text = "-",
      variant = "outline",
      onClick = function()
        local nextS = math.max(0.5, scaleVal - 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
    ui.row({ gap = 2, radius = 6, fill = "surface_variant", padding = 2 }, pillButtons),
    ui.button({
      text = "+",
      variant = "outline",
      onClick = function()
        local nextS = math.min(3.0, scaleVal + 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
  })
end

-- Renders 4-way rotation selector
function components.renderOrientationSelector(currentTransform: number?, onTransformChanged: (number) -> ()): any
  local transVal = currentTransform or 0
  local options = {
    { val = 0, label = "0°" },
    { val = 1, label = "90°" },
    { val = 2, label = "180°" },
    { val = 3, label = "270°" },
  }

  local buttons = {}
  for _, opt in ipairs(options) do
    local isAct = (transVal == opt.val)
    table.insert(buttons, ui.button({
      text = opt.label,
      variant = isAct and "primary" or "ghost",
      onClick = function() onTransformChanged(opt.val) end,
    }))
  end

  return ui.row({ gap = 4, radius = 6, fill = "surface_variant", padding = 2 }, buttons)
end

-- Renders display mode selector (Extend vs Clone/Mirror of another display)
function components.renderMirrorSelector(
  selected: layoutMath.Monitor,
  allMonitors: { layoutMath.Monitor },
  onMirrorChanged: (string?) -> ()
): any
  local isExtend = (not selected.mirrorOf or selected.mirrorOf == "" or selected.mirrorOf == "none")
  local buttons = {}

  -- Option 1: Extend (Independent screen)
  table.insert(buttons, ui.button({
    text = tr("panel.mode_extend") or "Layar Terpisah",
    variant = isExtend and "primary" or "ghost",
    fontSize = 11,
    onClick = function()
      onMirrorChanged(nil)
    end,
  }))

  -- Options 2+: Clone from other available connected displays
  for _, other in ipairs(allMonitors) do
    if other.name ~= selected.name then
      local isCloningThis = (selected.mirrorOf == other.name)
      local cloneLabel = tr("panel.mode_clone_from", { source = other.name })
        or ("Duplikat dari " .. other.name)
      table.insert(buttons, ui.button({
        text = cloneLabel,
        variant = isCloningThis and "primary" or "ghost",
        fontSize = 11,
        onClick = function()
          onMirrorChanged(other.name)
        end,
      }))
    end
  end

  return ui.row({ gap = 4, radius = 6, fill = "surface_variant", padding = 2 }, buttons)
end

-- Renders floating safety revert modal banner
function components.renderSafetyModal(secondsRemaining: number, onKeep: () -> (), onRevert: () -> ()): any
  return ui.row({
    justify = "space_between",
    align = "center",
    paddingH = 12,
    paddingV = 6,
    radius = 8,
    fill = "surface_variant",
    border = "error",
    borderWidth = 1,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "alert-triangle", size = 18, color = "error" }),
      ui.column({ gap = 2 }, {
        ui.label({
          text = tr("panel.safety_title"),
          fontWeight = "bold",
          fontSize = 12,
          color = "on_surface",
        }),
        ui.label({
          text = tr("panel.safety_desc", { seconds = tostring(secondsRemaining) }),
          fontSize = 11,
          color = "error",
        }),
      }),
    }),
    ui.row({ gap = 8, align = "center" }, {
      ui.button({
        text = tr("panel.btn_keep"),
        variant = "primary",
        onClick = onKeep,
      }),
      ui.button({
        text = tr("panel.btn_revert_now"),
        variant = "outline",
        onClick = onRevert,
      }),
    }),
  })
end

-- Renders refresh rate pills (e.g. 60Hz, 144Hz)
function components.renderRefreshRateSelector(m: layoutMath.Monitor, onRateChanged: (number) -> ()): any
  local options = {} -- array of { nominal: number, exact: number }
  local seenNominal = {}

  if m.availableModes and #m.availableModes > 0 then
    local curW = m.width or 1920
    local curH = m.height or 1080
    local matchedModes = {}

    -- 1. Prefer modes matching the current monitor resolution
    for _, modeStr in ipairs(m.availableModes) do
      local w, h, hz = string.match(modeStr, "^(%d+)x(%d+)@([%d%.]+)")
      if w and h and hz then
        if tonumber(w) == curW and tonumber(h) == curH then
          table.insert(matchedModes, tonumber(hz))
        end
      end
    end

    -- Fallback: if no modes match current resolution, extract all valid rates
    if #matchedModes == 0 then
      for _, modeStr in ipairs(m.availableModes) do
        local hz = string.match(modeStr, "@([%d%.]+)")
        if hz then
          table.insert(matchedModes, tonumber(hz))
        end
      end
    end

    -- Group by rounded nominal rate (e.g. 29.97 -> 30, 59.94 -> 60, 23.98 -> 24)
    for _, hz in ipairs(matchedModes) do
      if hz and hz > 0 then
        local nominal = math.floor(hz + 0.5)
        if not seenNominal[nominal] then
          local item = { nominal = nominal, exact = hz }
          seenNominal[nominal] = item
          table.insert(options, item)
        else
          local existing = seenNominal[nominal]
          -- Prefer exact integer if available (e.g. 60.00 over 59.94), or closest to nominal
          if math.abs(hz - nominal) < math.abs(existing.exact - nominal) then
            existing.exact = hz
          end
        end
      end
    end
  end

  if #options == 0 then
    options = {
      { nominal = 60, exact = 60.0 },
      { nominal = 144, exact = 144.0 },
    }
  end

  table.sort(options, function(a, b)
    return a.nominal < b.nominal
  end)

  -- Identify exactly one active nominal rate
  local curRate = m.refreshRate or 60.0
  local activeNominal = math.floor(curRate + 0.5)

  local bestNominal = options[1].nominal
  local bestDiff = math.abs(curRate - options[1].exact)
  for _, opt in ipairs(options) do
    local diff = math.abs(curRate - opt.exact)
    if opt.nominal == activeNominal then
      bestNominal = opt.nominal
      break
    elseif diff < bestDiff then
      bestDiff = diff
      bestNominal = opt.nominal
    end
  end

  local buttons = {}
  for _, opt in ipairs(options) do
    local isAct = (opt.nominal == bestNominal)
    table.insert(buttons, ui.button({
      text = string.format("%dHz", opt.nominal),
      variant = isAct and "primary" or "ghost",
      fontSize = 11,
      onClick = function()
        onRateChanged(opt.exact)
      end,
    }))
  end

  return ui.row({ gap = 2, radius = 6, fill = "surface_variant", padding = 2 }, buttons)
end

-- Renders position coordinate badges with quick offset nudges
function components.renderPositionDisplay(m: layoutMath.Monitor, onOffsetChanged: (number, number) -> ()): any
  local curX = m.x or 0
  local curY = m.y or 0
  local hasOffset = (curX ~= 0 or curY ~= 0)

  local items = {
    ui.label({
      text = string.format("X: %d  Y: %d", curX, curY),
      fontSize = 11,
      fontWeight = "bold",
      color = "on_surface",
    }),
  }

  if hasOffset then
    table.insert(items, ui.button({
      text = tr("panel.btn_reset_pos") or "Atur Ulang Posisi",
      variant = "ghost",
      fontSize = 10,
      onClick = function() onOffsetChanged(0, 0) end,
    }))
  end

  return ui.row({ gap = 6, align = "center", height = 28 }, items)
end

return components
