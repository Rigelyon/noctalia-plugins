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

  local cardChildren = {
    ui.label({
      text = m.name,
      fontWeight = "bold",
      fontSize = 12,
      color = isSelected and "primary" or "on_surface",
    }),
    ui.label({
      text = string.format("%dx%d", m.width, m.height),
      fontSize = 10,
      color = "on_surface_variant",
    }),
  }

  if m.scale ~= 1.0 then
    table.insert(cardChildren, ui.label({
      text = string.format("%.2fx", m.scale),
      fontSize = 9,
      color = "secondary",
    }))
  end

  return ui.column({
    width = bounds.w,
    height = bounds.h,
    radius = 6,
    fill = bgFill,
    border = borderFill,
    borderWidth = isSelected and 2 or 1,
    padding = 6,
    align = "center",
    justify = "center",
    onClick = onClick,
  }, cardChildren)
end

-- Renders the quick snap and preset toolbar above the canvas
function components.renderCanvasToolbar(actions: {
  onSnapLeft: () -> (),
  onSnapRight: () -> (),
  onSnapAbove: () -> (),
  onSnapBelow: () -> (),
  onAlignTops: () -> (),
  onPresetExtend: () -> (),
  onPresetMirror: () -> (),
}): any
  return ui.row({ gap = 6, align = "center", justify = "space_between" }, {
    ui.row({ gap = 4 }, {
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
    ui.row({ gap = 4 }, {
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
    })
  })
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
  return ui.column({
    radius = 8,
    fill = "surface",
    border = "error",
    borderWidth = 2,
    padding = 12,
  }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.column({ gap = 2 }, {
        ui.label({
          text = tr("panel.safety_title"),
          fontWeight = "bold",
          fontSize = 13,
          color = "on_surface",
        }),
        ui.label({
          text = tr("panel.safety_desc", { seconds = tostring(secondsRemaining) }),
          fontSize = 11,
          color = "error",
        }),
      }),
      ui.row({ gap = 8 }, {
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
      })
    })
  })
end

return components
