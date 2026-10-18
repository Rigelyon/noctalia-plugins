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
  onClick: () -> ()
): any
  local borderFill = isSelected and "primary" or "outline"
  local bgFill = isSelected and "surface" or "surface_variant"
  local isPortrait = (m.transform == 1 or m.transform == 3)

  local badgeText = ""
  if m.mirrorOf and m.mirrorOf ~= "" and m.mirrorOf ~= "none" then
    badgeText = "⎘ Mirror"
  elseif (m.x == 0 and m.y == 0) then
    badgeText = "● Main"
  else
    badgeText = string.format("+%d,%d", m.x or 0, m.y or 0)
  end

  local headerNode = nil
  if isPortrait or bounds.w < 145 then
    headerNode = ui.column({ gap = 2, align = "center" }, {
      ui.row({ gap = 3, align = "center" }, {
        ui.glyph({ name = "device-desktop", size = 11, color = isSelected and "primary" or "on_surface_variant" }),
        ui.label({
          text = m.name,
          fontWeight = "bold",
          fontSize = 10,
          color = isSelected and "primary" or "on_surface",
        }),
      }),
      (badgeText ~= "") and ui.label({
        text = badgeText,
        fontSize = 8,
        fontWeight = "bold",
        color = isSelected and "secondary" or "on_surface_variant",
      }) or nil,
    })
  else
    headerNode = ui.row({ justify = "space_between", align = "center" }, {
      ui.row({ gap = 4, align = "center" }, {
        ui.glyph({ name = "device-desktop", size = 12, color = isSelected and "primary" or "on_surface_variant" }),
        ui.label({
          text = m.name,
          fontWeight = "bold",
          fontSize = 11,
          color = isSelected and "primary" or "on_surface",
        }),
      }),
      (badgeText ~= "") and ui.label({
        text = badgeText,
        fontSize = 9,
        fontWeight = "bold",
        color = isSelected and "secondary" or "on_surface_variant",
      }) or nil,
    })
  end

  local subInfo = string.format("%.0fHz", m.refreshRate or 60)
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

  local centerNode = ui.column({ align = "center", gap = 1 }, {
    ui.label({
      text = string.format("%dx%d", m.width, m.height),
      fontSize = (isPortrait or bounds.w < 145) and 10 or 12,
      fontWeight = "bold",
      color = "on_surface",
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
      ui.label({ text = "Single Display Connected", fontSize = 11, color = "on_surface_variant" }),
    })
  end
end

-- Renders display scale steppers and quick pill buttons
function components.renderScaleSelector(currentScale: number, onScaleChanged: (number) -> ()): any
  local presets = { 1.0, 1.25, 1.5, 1.75, 2.0 }
  local pillButtons = {}

  for _, s in ipairs(presets) do
    local isAct = math.abs(currentScale - s) < 0.01
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
        local nextS = math.max(0.5, currentScale - 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
    ui.row({ gap = 2, radius = 6, fill = "surface_variant", padding = 2 }, pillButtons),
    ui.button({
      text = "+",
      variant = "outline",
      onClick = function()
        local nextS = math.min(3.0, currentScale + 0.05)
        onScaleChanged(math.floor(nextS * 100 + 0.5) / 100)
      end,
    }),
  })
end

-- Renders 4-way rotation selector
function components.renderOrientationSelector(currentTransform: number, onTransformChanged: (number) -> ()): any
  local options = {
    { val = 0, label = "0°" },
    { val = 1, label = "90°" },
    { val = 2, label = "180°" },
    { val = 3, label = "270°" },
  }

  local buttons = {}
  for _, opt in ipairs(options) do
    local isAct = (currentTransform == opt.val)
    table.insert(buttons, ui.button({
      text = opt.label,
      variant = isAct and "primary" or "ghost",
      onClick = function() onTransformChanged(opt.val) end,
    }))
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
  local rates = {}
  local seen = {}
  if m.availableModes then
    for _, modeStr in ipairs(m.availableModes) do
      local hz = tonumber(string.match(modeStr, "@([%d%.]+)Hz"))
      if hz and not seen[math.floor(hz)] then
        seen[math.floor(hz)] = true
        table.insert(rates, math.floor(hz))
      end
    end
  end
  if #rates == 0 then
    rates = { 60, 144 }
  end
  table.sort(rates)

  local curHz = math.floor((m.refreshRate or 60) + 0.5)
  local buttons = {}
  for _, r in ipairs(rates) do
    local isAct = (math.abs(curHz - r) <= 1)
    table.insert(buttons, ui.button({
      text = string.format("%dHz", r),
      variant = isAct and "primary" or "ghost",
      fontSize = 11,
      onClick = function() onRateChanged(r) end,
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
      text = "Reset (0,0)",
      variant = "ghost",
      fontSize = 10,
      onClick = function() onOffsetChanged(0, 0) end,
    }))
  end

  return ui.row({ gap = 6, align = "center", height = 28 }, items)
end

return components
