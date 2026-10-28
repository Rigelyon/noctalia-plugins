--!nonstrict
-- UI Components for Keybind Cards and Keyboard Badges
local components = {}

function components.renderKbdBadge(text: string, isPrimary: boolean, cornerRadiusScale: number): any
  return ui.row({
    paddingV = 2,
    paddingH = 5,
    radius = 4 * cornerRadiusScale,
    fill = isPrimary and "surface_variant" or "surface",
  }, {
    ui.label({
      text = string.upper(text),
      fontSize = 10,
      fontWeight = "bold",
      color = isPrimary and "primary" or "on_surface",
    }),
  })
end

function components.renderKbdBadges(itemOrMods: any, keyOrScale: any, maybeScale: any): { any }
  local kbdBadges = {}
  local cornerRadiusScale = 1.0

  if type(itemOrMods) == "table" and itemOrMods.tokens ~= nil then
    cornerRadiusScale = keyOrScale or 1.0
    for _, tok in ipairs(itemOrMods.tokens) do
      if tok.sepAfter == "," then
        local badge = components.renderKbdBadge(tok.text, tok.isPrimary, cornerRadiusScale)
        local comma = ui.label({ text = ",", fontSize = 10, fontWeight = "bold", color = "on_surface_variant" })
        table.insert(kbdBadges, ui.row({ gap = 1, align = "center" }, { badge, comma }))
      else
        table.insert(kbdBadges, components.renderKbdBadge(tok.text, tok.isPrimary, cornerRadiusScale))
        if tok.sepAfter == "+" then
          table.insert(kbdBadges, ui.label({ text = "+", fontSize = 9, color = "on_surface_variant" }))
        end
      end
    end
    return kbdBadges
  end

  -- Legacy signature fallback: renderKbdBadges(modifiers: { string }, key: string, cornerRadiusScale: number)
  local modifiers = if type(itemOrMods) == "table" then itemOrMods else {}
  local key = if type(keyOrScale) == "string" then keyOrScale else ""
  cornerRadiusScale = maybeScale or 1.0

  for _, m in ipairs(modifiers) do
    table.insert(kbdBadges, components.renderKbdBadge(string.upper(m), false, cornerRadiusScale))
    table.insert(kbdBadges, ui.label({ text = "+", fontSize = 9, color = "on_surface_variant" }))
  end
  if key ~= "" then
    table.insert(kbdBadges, components.renderKbdBadge(string.upper(key), true, cornerRadiusScale))
  end
  return kbdBadges
end

function components.renderKeybindCard(item: any, props: {
  isEditMode: boolean,
  copiedId: string?,
  cornerRadiusScale: number,
  onCopy: ((keyComboText: string, id: string) -> ())?,
  onEdit: ((item: any) -> ())?,
  onDelete: ((item: any) -> ())?,
  tr: (string, any?) -> string,
}): any
  local isCopied = (props.copiedId == item.id)
  local isEditMode = props.isEditMode
  local cornerRadiusScale = props.cornerRadiusScale or 1.0
  local tr = props.tr

  local kbdBadges = if item.tokens ~= nil
    then components.renderKbdBadges(item, cornerRadiusScale)
    else components.renderKbdBadges(item.modifiers, item.key, cornerRadiusScale)

  -- Prevent text overflowing under badges; calculate safe max description length
  local maxDescLen = if isEditMode
    then (34 - (#item.modifiers * 5) - (string.len(item.key) > 6 and 4 or 0))
    else (46 - (#item.modifiers * 5) - (string.len(item.key) > 6 and 4 or 0))
  if maxDescLen < 16 then maxDescLen = 16 end

  local displayDesc = item.description
  if string.len(displayDesc) > maxDescLen then
    displayDesc = string.sub(displayDesc, 1, maxDescLen - 1) .. "…"
  end

  local fullTooltip = item.description .. " (" .. item.keyComboText .. ")"

  local cardActions = nil
  if isEditMode and item.source == "custom" and item.bindIndex ~= nil then
    cardActions = ui.row({ gap = 2, align = "center" }, {
      ui.button({
        glyph = "pencil",
        variant = "ghost",
        tooltip = tr("actions.edit_keybind"),
        onClick = function()
          if props.onEdit then
            props.onEdit(item)
          end
        end,
      }),
      ui.button({
        glyph = "trash",
        variant = "ghost",
        tooltip = tr("actions.delete_keybind"),
        onClick = function()
          if props.onDelete then
            props.onDelete(item)
          end
        end,
      }),
    })
  end

  return ui.row({
    key = "card-" .. item.id,
    flexGrow = 1,
    paddingV = 5,
    paddingH = 8,
    radius = 6 * cornerRadiusScale,
    fill = isCopied and "primary_container" or "surface",
    align = "center",
    justify = "space_between",
    gap = 6,
    tooltip = fullTooltip,
    onClick = function()
      local copyEnabled = noctalia.getConfig("copy_on_click") ~= false
      if copyEnabled then
        noctalia.copyToClipboard(item.keyComboText, "text/plain")
        if props.onCopy then
          props.onCopy(item.keyComboText, item.id)
        end
      end
    end,
  }, {
    ui.row({ gap = 6, align = "center", flexGrow = 1, tooltip = fullTooltip }, {
      ui.glyph({ name = item.subcatIcon, size = 11, color = "on_surface_variant" }),
      ui.label({
        text = isCopied and tr("panel.copied") or displayDesc,
        fontSize = 11,
        fontWeight = isCopied and "bold" or "normal",
        color = isCopied and "on_primary_container" or "on_surface",
        maxLines = 1,
      }),
    }),
    ui.row({ gap = 4, align = "center" }, {
      ui.row({ gap = 3, align = "center" }, kbdBadges),
      cardActions,
    }),
  })
end

return components
