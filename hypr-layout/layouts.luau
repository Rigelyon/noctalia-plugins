--!nonstrict
-- Layout Registry and Sub-action definitions for Hyprland Switcher
local layouts = {}

export type SubAction = {
  id: string,
  labelKey: string,
  icon: string,
  cmd: string,
}

export type LayoutDef = {
  id: string,
  nameKey: string,
  categoryKey: string,
  descKey: string,
  glyph: string,
  isPlugin: boolean,
  subactions: { SubAction },
}

layouts.LAYOUT_DEFS = {
  dwindle = {
    id = "dwindle",
    nameKey = "layouts.dwindle.name",
    categoryKey = "layouts.dwindle.category",
    descKey = "layouts.dwindle.description",
    glyph = "layout-grid",
    isPlugin = false,
    subactions = {
      { id = "togglesplit", labelKey = "subactions.togglesplit", icon = "git-branch", cmd = "togglesplit" },
      { id = "pseudo", labelKey = "subactions.pseudo", icon = "app-window", cmd = "pseudo" },
      { id = "swapsplit", labelKey = "subactions.swapsplit", icon = "command", cmd = "swapsplit" },
    },
  },
  master = {
    id = "master",
    nameKey = "layouts.master.name",
    categoryKey = "layouts.master.category",
    descKey = "layouts.master.description",
    glyph = "app-window",
    isPlugin = false,
    subactions = {
      { id = "swapwithmaster", labelKey = "subactions.swapwithmaster", icon = "command", cmd = "swapwithmaster" },
      { id = "cyclenext", labelKey = "subactions.cyclenext", icon = "play", cmd = "cyclenext" },
      { id = "addmaster", labelKey = "subactions.addmaster", icon = "plus", cmd = "addmaster" },
      { id = "removemaster", labelKey = "subactions.removemaster", icon = "minus", cmd = "removemaster" },
    },
  },
  hy3 = {
    id = "hy3",
    nameKey = "layouts.hy3.name",
    categoryKey = "layouts.hy3.category",
    descKey = "layouts.hy3.description",
    glyph = "app-window",
    isPlugin = true,
    subactions = {
      { id = "makegroup_h", labelKey = "subactions.makegroup_h", icon = "app-window", cmd = "hy3:makegroup,h" },
      { id = "makegroup_v", labelKey = "subactions.makegroup_v", icon = "app-window", cmd = "hy3:makegroup,v" },
      { id = "makegroup_tab", labelKey = "subactions.makegroup_tab", icon = "layers", cmd = "hy3:makegroup,tab" },
    },
  },
  scroller = {
    id = "scroller",
    nameKey = "layouts.scroller.name",
    categoryKey = "layouts.scroller.category",
    descKey = "layouts.scroller.description",
    glyph = "sliders",
    isPlugin = true,
    subactions = {
      { id = "cyclesize", labelKey = "subactions.cyclesize", icon = "maximize", cmd = "scroller:cyclesize" },
      { id = "toggleoverview", labelKey = "subactions.toggleoverview", icon = "monitor", cmd = "scroller:toggleoverview" },
    },
  },
}

function layouts.getLayout(id: string): LayoutDef?
  if not id or id == "" then return layouts.LAYOUT_DEFS["dwindle"] end
  local normalized = string.lower(id)
  return layouts.LAYOUT_DEFS[normalized]
end

function layouts.getAvailableLayouts(configGetter: ((string) -> any)?): { LayoutDef }
  local list = {
    layouts.LAYOUT_DEFS.dwindle,
    layouts.LAYOUT_DEFS.master,
  }
  local enableHy3 = false
  local enableScroller = false

  if configGetter then
    enableHy3 = (configGetter("enable_hy3") == true)
    enableScroller = (configGetter("enable_scroller") == true)
  end

  if enableHy3 then
    table.insert(list, layouts.LAYOUT_DEFS.hy3)
  end
  if enableScroller then
    table.insert(list, layouts.LAYOUT_DEFS.scroller)
  end

  return list
end

function layouts.getNextLayout(currentId: string, configGetter: ((string) -> any)?): LayoutDef
  local available = layouts.getAvailableLayouts(configGetter)
  if #available == 0 then return layouts.LAYOUT_DEFS.dwindle end

  local currentNormalized = string.lower(currentId or "dwindle")
  local currentIndex = 1
  for i, def in ipairs(available) do
    if def.id == currentNormalized then
      currentIndex = i
      break
    end
  end

  local nextIndex = (currentIndex % #available) + 1
  return available[nextIndex]
end

return layouts
