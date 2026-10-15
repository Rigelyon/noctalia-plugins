--!nonstrict
-- Status bar widget for Keybinds Cheatsheet

local function tr(key: string): string
  return noctalia.tr(key)
end

barWidget.setGlyph("keyboard")
barWidget.setTooltip(tr("widget.tooltip"))

function onClick()
  noctalia.togglePanel("rigelyon/keybinds:panel")
end
