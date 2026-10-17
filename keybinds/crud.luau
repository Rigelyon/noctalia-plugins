--!nonstrict
-- CRUD operations helper module for custom keybinds.

local crud = {}

export type BindEntry = {
  keys: { string },
  description: string,
}

export type SubcatEntry = {
  name: string,
  icon: string,
  binds: { BindEntry },
}

export type AppEntry = {
  name: string,
  icon: string,
  subcategories: { SubcatEntry },
}

export type CustomStore = {
  apps: { AppEntry },
}

local function safeTrim(s: string?): string
  if not s then return "" end
  if type(noctalia) == "table" and noctalia.string and noctalia.string.trim then
    return noctalia.string.trim(s)
  end
  return string.match(s, "^%s*(.-)%s*$") or ""
end

function crud.ensureStore(data: any): CustomStore
  if type(data) ~= "table" then
    return { apps = {} }
  end
  if type(data.apps) ~= "table" then
    data.apps = {}
  end
  return data
end

function crud.findApp(store: CustomStore, appName: string): AppEntry?
  local target = string.lower(safeTrim(appName))
  for _, app in ipairs(store.apps) do
    if string.lower(app.name) == target then
      return app
    end
  end
  return nil
end

function crud.findSubcategory(app: AppEntry, subcatName: string): SubcatEntry?
  local target = string.lower(safeTrim(subcatName))
  for _, sub in ipairs(app.subcategories) do
    if string.lower(sub.name) == target then
      return sub
    end
  end
  return nil
end

function crud.addKeybind(
  store: CustomStore,
  appName: string,
  subcatName: string,
  description: string,
  modifiers: { string },
  primaryKey: string,
  appIcon: string?,
  subcatIcon: string?
): (boolean, string?)
  local cleanApp = safeTrim(appName)
  local cleanSub = safeTrim(subcatName)
  local cleanDesc = safeTrim(description)
  local cleanKey = string.upper(safeTrim(primaryKey))

  if cleanDesc == "" or cleanKey == "" then
    return false, "Description and primary key are required"
  end
  if cleanApp == "" then
    cleanApp = "Custom"
  end
  if cleanSub == "" then
    cleanSub = "General"
  end

  local keys = {}
  for _, m in ipairs(modifiers) do
    local mu = string.upper(safeTrim(m))
    if mu ~= "" then
      table.insert(keys, mu)
    end
  end
  table.insert(keys, cleanKey)

  local app = crud.findApp(store, cleanApp)
  if not app then
    local chosenAppIcon = if appIcon and safeTrim(appIcon) ~= "" then safeTrim(appIcon) else "terminal"
    app = {
      name = cleanApp,
      icon = chosenAppIcon,
      subcategories = {},
    }
    table.insert(store.apps, app)
  elseif appIcon and safeTrim(appIcon) ~= "" then
    app.icon = safeTrim(appIcon)
  end

  local sub = crud.findSubcategory(app, cleanSub)
  if not sub then
    local chosenSubIcon = if subcatIcon and safeTrim(subcatIcon) ~= "" then safeTrim(subcatIcon) else "command"
    sub = {
      name = cleanSub,
      icon = chosenSubIcon,
      binds = {},
    }
    table.insert(app.subcategories, sub)
  elseif subcatIcon and safeTrim(subcatIcon) ~= "" then
    sub.icon = safeTrim(subcatIcon)
  end

  table.insert(sub.binds, {
    keys = keys,
    description = cleanDesc,
  })

  return true, nil
end

function crud.deleteKeybind(
  store: CustomStore,
  appName: string,
  subcatName: string,
  bindIdx: number
): boolean
  local app = crud.findApp(store, appName)
  if not app or type(app.subcategories) ~= "table" then
    return false
  end

  local sub = crud.findSubcategory(app, subcatName)
  if not sub or type(sub.binds) ~= "table" or bindIdx < 1 or bindIdx > #sub.binds then
    return false
  end

  table.remove(sub.binds, bindIdx)

  -- Cleanup empty subcategory
  if #sub.binds == 0 then
    for sIdx, s in ipairs(app.subcategories) do
      if s == sub then
        table.remove(app.subcategories, sIdx)
        break
      end
    end
  end

  -- Cleanup empty app
  if #app.subcategories == 0 then
    for aIdx, a in ipairs(store.apps) do
      if a == app then
        table.remove(store.apps, aIdx)
        break
      end
    end
  end

  return true
end

function crud.updateKeybind(
  store: CustomStore,
  origApp: string,
  origSubcat: string,
  origBindIdx: number,
  newApp: string,
  newSubcat: string,
  newDesc: string,
  newModifiers: { string },
  newKey: string,
  newAppIcon: string?,
  newSubcatIcon: string?
): (boolean, string?)
  local deleted = crud.deleteKeybind(store, origApp, origSubcat, origBindIdx)
  if not deleted then
    return false, "Original keybind not found"
  end

  return crud.addKeybind(store, newApp, newSubcat, newDesc, newModifiers, newKey, newAppIcon, newSubcatIcon)
end

function crud.renameApp(
  store: CustomStore,
  oldName: string,
  newName: string,
  newIcon: string?
): (boolean, string?)
  local app = crud.findApp(store, oldName)
  if not app then
    return false, "Application not found"
  end
  local cleanNew = safeTrim(newName)
  if cleanNew == "" then
    return false, "Application name cannot be empty"
  end
  if string.lower(cleanNew) ~= string.lower(app.name) then
    local existing = crud.findApp(store, cleanNew)
    if existing then
      return false, "An application with this name already exists"
    end
  end
  app.name = cleanNew
  if newIcon and safeTrim(newIcon) ~= "" then
    app.icon = safeTrim(newIcon)
  end
  return true, nil
end

function crud.renameSubcategory(
  store: CustomStore,
  appName: string,
  oldSubcatName: string,
  newSubcatName: string,
  newIcon: string?
): (boolean, string?)
  local app = crud.findApp(store, appName)
  if not app then
    return false, "Application not found"
  end
  local sub = crud.findSubcategory(app, oldSubcatName)
  if not sub then
    return false, "Subcategory not found"
  end
  local cleanNew = safeTrim(newSubcatName)
  if cleanNew == "" then
    return false, "Subcategory name cannot be empty"
  end
  if string.lower(cleanNew) ~= string.lower(sub.name) then
    local existing = crud.findSubcategory(app, cleanNew)
    if existing then
      return false, "A subcategory with this name already exists in this application"
    end
  end
  sub.name = cleanNew
  if newIcon and safeTrim(newIcon) ~= "" then
    sub.icon = safeTrim(newIcon)
  end
  return true, nil
end

return crud

