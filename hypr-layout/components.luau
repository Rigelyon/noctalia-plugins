--!nonstrict
-- UI Component Library and Schematic Wireframe Diagrams for Hyprland Switcher
local layouts = require("./layouts.luau")

local components = {}

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- Generates schematic miniature window layout wireframes (56px x 40px)
function components.renderWireframe(layoutId: string, isActive: boolean): any
  local tileFill = isActive and "primary" or "outline"
  local tileMuted = isActive and "primary" or "surface_variant"

  if layoutId == "dwindle" then
    -- Fibonacci Spiral: Left 50% window, Right 50% split into Top and Bottom windows
    return ui.row({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        -- Main Left Window
        ui.box({
          flexGrow = 1,
          radius = 3,
          fill = tileFill,
        }),
        -- Right Stack Column
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "master" then
    -- Master & Stack: Dominant 60% Left Master window, Right 40% two stacked slave windows
    return ui.row({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        -- Master window
        ui.box({
          width = 30,
          radius = 3,
          fill = tileFill,
        }),
        -- Slave stack
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "hy3" then
    -- Hy3: Tabbed top indicator with two vertical columns
    return ui.row({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        -- Tab bar indicator
        ui.row({ gap = 2, height = 4 }, {
          ui.box({ width = 14, radius = 1, fill = tileFill }),
          ui.box({ width = 14, radius = 1, fill = tileMuted }),
        }),
        -- Columns
        ui.row({ gap = 2, flexGrow = 1 }, {
          ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
          ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        }),
      }),
    })
  elseif layoutId == "scroller" or layoutId == "scrolling" then
    -- Scroller / Scrolling: 3 horizontal columns with center active
    return ui.row({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.row({ gap = 2, flexGrow = 1 }, {
        ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
        ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
        ui.box({ flexGrow = 1, radius = 3, fill = tileMuted }),
      }),
    })
  elseif layoutId == "monocle" then
    -- Monocle: single full-size window deck taking up the entire workspace
    return ui.row({
      width = 56,
      height = 40,
      radius = 4,
      fill = "surface",
      padding = 3,
    }, {
      ui.box({
        flexGrow = 1,
        radius = 3,
        fill = tileFill,
      }),
    })
  end

  -- Default generic tile fallback
  return ui.row({
    width = 56,
    height = 40,
    radius = 4,
    fill = "surface",
    padding = 3,
  }, {
    ui.box({ flexGrow = 1, radius = 3, fill = tileFill }),
  })
end

function components.renderLayoutCard(def: any, isActive: boolean, isOverride: boolean?, onSelect: () -> ()): any
  local wireframe = components.renderWireframe(def.id, isActive)
  local name = tr(def.nameKey)
  local category = tr(def.categoryKey)
  local desc = tr(def.descKey)

  local activeBadge = nil
  if isActive then
    local badgeFill = isOverride and "secondary" or "primary"
    local badgeGlyph = isOverride and "pin" or "check"
    local badgeText = isOverride and tr("panel.active_override_badge") or tr("panel.active_badge")

    activeBadge = ui.row({
      gap = 3,
      paddingV = 2,
      paddingH = 6,
      radius = 999,
      fill = badgeFill,
      align = "center",
    }, {
      ui.glyph({ name = badgeGlyph, size = 11, color = "on_" .. badgeFill }),
      ui.label({ text = badgeText, fontSize = 10, fontWeight = "bold", color = "on_" .. badgeFill }),
    })
  end

  return ui.row({
    padding = 10,
    radius = 8,
    fill = isActive and "surface" or "surface_variant",
    align = "center",
    gap = 12,
    flexGrow = 1,
    onClick = onSelect,
  }, {
    wireframe,
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 6, align = "center" }, {
          ui.glyph({ name = def.glyph, size = 16, color = isActive and "primary" or "on_surface" }),
          ui.label({ text = name, fontSize = 14, fontWeight = "bold", color = "on_surface" }),
          ui.label({ text = "•", fontSize = 12, color = "on_surface_variant" }),
          ui.label({ text = category, fontSize = 11, color = "on_surface_variant" }),
        }),
        activeBadge or ui.spacer({ width = 1 }),
      }),
      ui.label({
        text = desc,
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
  })
end

function components.renderSubActionsBar(layoutDef: any, onDispatch: (string) -> ()): any
  if not layoutDef or not layoutDef.subactions or #layoutDef.subactions == 0 then
    return ui.spacer({ height = 1 })
  end

  local buttons = {}
  for _, action in ipairs(layoutDef.subactions) do
    local label = tr(action.labelKey)
    table.insert(buttons, ui.button({
      glyph = action.icon,
      text = label,
      variant = "secondary",
      onClick = function()
        onDispatch(action.cmd)
      end,
    }))
  end

  return ui.column({ gap = 6 }, {
    ui.label({
      text = tr("panel.controls_title", { layout = tr(layoutDef.nameKey) }),
      fontSize = 12,
      fontWeight = "bold",
      color = "on_surface",
    }),
    ui.row({ gap = 6, align = "center" }, buttons),
  })
end

return components
