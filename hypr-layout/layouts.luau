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
      { id = "swapwithmaster", labelKey = "subactions.swapwithmaster", icon = "command", cmd = "swapwithmaster auto" },
      { id = "cyclenext", labelKey = "subactions.cyclenext", icon = "arrow-right", cmd = "cyclenext" },
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
      { id = "makegroup_tab", labelKey = "subactions.makegroup_tab", icon = "folder", cmd = "hy3:makegroup,tab" },
    },
  },
  scrolling = {
    id = "scrolling",
    nameKey = "layouts.scrolling.name",
    categoryKey = "layouts.scrolling.category",
    descKey = "layouts.scrolling.description",
    glyph = "maximize",
    isPlugin = false,
    subactions = {
      { id = "center", labelKey = "subactions.center", icon = "maximize", cmd = "center" },
      { id = "fit_active", labelKey = "subactions.fit", icon = "app-window", cmd = "fit active" },
      { id = "colresize", labelKey = "subactions.colresize", icon = "refresh-cw", cmd = "colresize +conf" },
      { id = "swapcol", labelKey = "subactions.swapcol", icon = "arrow-right", cmd = "swapcol r" },
    },
  },
  monocle = {
    id = "monocle",
    nameKey = "layouts.monocle.name",
    categoryKey = "layouts.monocle.category",
    descKey = "layouts.monocle.description",
    glyph = "app-window",
    isPlugin = false,
    subactions = {
      { id = "cyclenext", labelKey = "subactions.cyclenext", icon = "arrow-right", cmd = "cyclenext" },
      { id = "cycleprev", labelKey = "subactions.cycleprev", icon = "refresh-cw", cmd = "cycleprev" },
    },
  },
}

-- Backward compatibility alias
layouts.LAYOUT_DEFS.scroller = layouts.LAYOUT_DEFS.scrolling

function layouts.getLayout(id: string): LayoutDef?
  if not id or id == "" then return layouts.LAYOUT_DEFS["dwindle"] end
  local normalized = string.lower(id)
  if normalized == "scroller" then
    return layouts.LAYOUT_DEFS["scrolling"]
  end
  return layouts.LAYOUT_DEFS[normalized]
end

function layouts.getAvailableLayouts(configGetter: ((string) -> any)?): { LayoutDef }
  local list = {
    layouts.LAYOUT_DEFS.dwindle,
    layouts.LAYOUT_DEFS.master,
    layouts.LAYOUT_DEFS.scrolling,
    layouts.LAYOUT_DEFS.monocle,
  }
  local enableHy3 = false

  if configGetter then
    enableHy3 = (configGetter("enable_hy3") == true)
  end

  if enableHy3 then
    table.insert(list, layouts.LAYOUT_DEFS.hy3)
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
