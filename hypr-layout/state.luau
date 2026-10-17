--!nonstrict
-- Central reactive state manager for Hyprland Layout Switcher
local state = {
  globalLayout = "dwindle",
  activeWorkspaceId = 1,
  activeWorkspaceName = "1",
  activeMonitor = "",
  currentScope = "global", -- "global" or "workspace"
  workspaceLayouts = {} :: { [string | number]: string },
  listeners = {} :: { (any) -> () },
}

local function getPersistFilePath(): string?
  if not noctalia or not noctalia.pluginDataDir then return nil end
  local ok, dir = pcall(function()
    return noctalia.pluginDataDir()
  end)
  if not ok or not dir or dir == "" then return nil end
  return dir .. "/state.json"
end

local function saveDurableState()
  local path = getPersistFilePath()
  if not path or not noctalia or not noctalia.writeFile or not noctalia.json then return end
  local ok, encoded = pcall(function()
    local copy = {}
    for k, v in pairs(state.workspaceLayouts) do
      copy[tostring(k)] = v
    end
    return noctalia.json.encode({
      scope = state.currentScope,
      workspaceLayouts = copy,
    })
  end)
  if ok and encoded then
    pcall(function()
      noctalia.writeFile(path, encoded)
    end)
  end
end

local function loadDurableState()
  local path = getPersistFilePath()
  if not path or not noctalia or not noctalia.readFile or not noctalia.json then return end
  local ok, raw = pcall(function()
    return noctalia.readFile(path)
  end)
  if ok and raw and raw ~= "" then
    local decOk, data = pcall(function()
      return noctalia.json.decode(raw)
    end)
    if decOk and type(data) == "table" then
      if data.scope == "global" or data.scope == "workspace" then
        state.currentScope = data.scope
      end
      if type(data.workspaceLayouts) == "table" then
        for k, v in pairs(data.workspaceLayouts) do
          state.workspaceLayouts[k] = v
          local numK = tonumber(k)
          if numK then
            state.workspaceLayouts[numK] = v
          end
        end
      end
    end
  end
end

local function initSharedState()
  if not noctalia or not noctalia.state then
    loadDurableState()
    return
  end

  -- Initialize scope from host shared state or persistent storage
  local sharedScope = noctalia.state.get("hypr_layout.scope")
  if sharedScope == "global" or sharedScope == "workspace" then
    state.currentScope = sharedScope
  else
    loadDurableState()
    if state.currentScope ~= "global" and state.currentScope ~= "workspace" then
      local defaultScope = noctalia.getConfig("default_scope")
      if defaultScope == "workspace" or defaultScope == "global" then
        state.currentScope = defaultScope
      else
        state.currentScope = "global"
      end
    end
    noctalia.state.set("hypr_layout.scope", state.currentScope)
  end

  -- Initialize global layout
  local sharedGlobal = noctalia.state.get("hypr_layout.global_layout")
  if type(sharedGlobal) == "string" and sharedGlobal ~= "" then
    state.globalLayout = sharedGlobal
  end

  -- Initialize workspace layouts
  local sharedWs = noctalia.state.get("hypr_layout.workspace_layouts")
  if type(sharedWs) == "table" then
    for k, v in pairs(sharedWs) do
      state.workspaceLayouts[k] = v
      local numK = tonumber(k)
      if numK then
        state.workspaceLayouts[numK] = v
      end
    end
  else
    local copy = {}
    for k, v in pairs(state.workspaceLayouts) do
      copy[tostring(k)] = v
    end
    noctalia.state.set("hypr_layout.workspace_layouts", copy)
  end

  -- Initialize active workspace ID
  local sharedWsId = noctalia.state.get("hypr_layout.active_ws_id")
  if type(sharedWsId) == "number" then
    state.activeWorkspaceId = sharedWsId
    state.activeWorkspaceName = tostring(sharedWsId)
  end

  -- Watch host shared state for reactive cross-runtime updates (widget <-> panel)
  noctalia.state.watch("hypr_layout.scope", function(val)
    if (val == "global" or val == "workspace") and state.currentScope ~= val then
      state.currentScope = val
      state.notify()
    end
  end)

  noctalia.state.watch("hypr_layout.global_layout", function(val)
    if type(val) == "string" and val ~= "" and state.globalLayout ~= val then
      state.globalLayout = val
      state.notify()
    end
  end)

  noctalia.state.watch("hypr_layout.workspace_layouts", function(val)
    if type(val) == "table" then
      for k, v in pairs(val) do
        state.workspaceLayouts[k] = v
        local numK = tonumber(k)
        if numK then
          state.workspaceLayouts[numK] = v
        end
      end
      state.notify()
    end
  end)

  noctalia.state.watch("hypr_layout.active_ws_id", function(val)
    if type(val) == "number" and state.activeWorkspaceId ~= val then
      state.activeWorkspaceId = val
      state.activeWorkspaceName = tostring(val)
      state.notify()
    end
  end)
end

function state.subscribe(callback: (any) -> ())
  table.insert(state.listeners, callback)
end

function state.notify()
  for _, callback in ipairs(state.listeners) do
    local ok, err = pcall(function()
      callback(state)
    end)
    if not ok and noctalia and noctalia.log then
      noctalia.log("[hypr-layout] Error in state listener: " .. tostring(err))
    end
  end
end

function state.setScope(scope: string)
  if scope == "global" or scope == "workspace" then
    if state.currentScope ~= scope then
      state.currentScope = scope
      if noctalia and noctalia.state then
        noctalia.state.set("hypr_layout.scope", scope)
      end
      saveDurableState()
      state.notify()
    end
  end
end

function state.setGlobalLayout(name: string)
  if not name or name == "" then return end
  local clean = string.lower(name)
  if state.globalLayout ~= clean then
    state.globalLayout = clean
    if noctalia and noctalia.state then
      noctalia.state.set("hypr_layout.global_layout", clean)
    end
    state.notify()
  end
end

function state.setActiveWorkspace(wsId: number, wsName: string?, monitor: string?)
  local changed = false
  if state.activeWorkspaceId ~= wsId then
    state.activeWorkspaceId = wsId
    changed = true
    if noctalia and noctalia.state then
      noctalia.state.set("hypr_layout.active_ws_id", wsId)
    end
  end
  if wsName and state.activeWorkspaceName ~= wsName then
    state.activeWorkspaceName = wsName
    changed = true
  end
  if monitor and state.activeMonitor ~= monitor then
    state.activeMonitor = monitor
    changed = true
  end
  if changed then
    state.notify()
  end
end

function state.setWorkspaceLayout(wsId: number, name: string)
  if not wsId or not name or name == "" then return end
  local clean = string.lower(name)
  local key = tostring(wsId)
  if state.workspaceLayouts[key] ~= clean or state.workspaceLayouts[wsId] ~= clean then
    state.workspaceLayouts[key] = clean
    state.workspaceLayouts[wsId] = clean
    if noctalia and noctalia.state then
      local current = noctalia.state.get("hypr_layout.workspace_layouts") or {}
      local copy = {}
      if type(current) == "table" then
        for k, v in pairs(current) do
          copy[tostring(k)] = v
        end
      end
      copy[key] = clean
      noctalia.state.set("hypr_layout.workspace_layouts", copy)
    end
    saveDurableState()
    state.notify()
  end
end

function state.hasWorkspaceOverride(wsId: number?): boolean
  local id = wsId or state.activeWorkspaceId
  local key = tostring(id)
  local override = state.workspaceLayouts[key] or state.workspaceLayouts[id]
  return override ~= nil and override ~= ""
end

function state.removeWorkspaceOverride(wsId: number?)
  local id = wsId or state.activeWorkspaceId
  local key = tostring(id)
  local hadOverride = (state.workspaceLayouts[key] ~= nil or state.workspaceLayouts[id] ~= nil)
  if hadOverride then
    state.workspaceLayouts[key] = nil
    state.workspaceLayouts[id] = nil
    if noctalia and noctalia.state then
      local current = noctalia.state.get("hypr_layout.workspace_layouts") or {}
      local copy = {}
      if type(current) == "table" then
        for k, v in pairs(current) do
          if k ~= key and tonumber(k) ~= id then
            copy[tostring(k)] = v
          end
        end
      end
      noctalia.state.set("hypr_layout.workspace_layouts", copy)
    end
    saveDurableState()
    state.notify()
  end
end

function state.getEffectiveLayout(): string
  local wsKey = tostring(state.activeWorkspaceId)
  local wsLayout = state.workspaceLayouts[wsKey] or state.workspaceLayouts[state.activeWorkspaceId]
  if wsLayout and wsLayout ~= "" then
    return wsLayout
  end
  return state.globalLayout or "dwindle"
end

-- Initialize state immediately on module load
initSharedState()

return state
