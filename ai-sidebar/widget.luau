--!strict
-- AI Sidebar Bar Widget

barWidget.setGlyph("sparkles")
barWidget.setTooltip(noctalia.tr("title"))

function onClick()
  noctalia.togglePanel("rigelyon/ai-sidebar:panel")
end
