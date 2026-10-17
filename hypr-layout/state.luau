--!nonstrict
-- Central reactive state manager for Hyprland Layout Switcher
local state = {
  globalLayout = "dwindle",
  activeWorkspaceId = 1,
  activeWorkspaceName = "1",
  activeMonitor = "",
  currentScope = "global", -- "global" or "workspace"
  workspaceLayouts = {} :: { [number]: string },
  listeners = {} :: { (any) -> () },
}

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
    state.currentScope = scope
    state.notify()
  end
end

function state.setGlobalLayout(name: string)
  if not name or name == "" then return end
  local clean = string.lower(name)
  if state.globalLayout ~= clean then
    state.globalLayout = clean
    state.notify()
  end
end

function state.setActiveWorkspace(wsId: number, wsName: string?, monitor: string?)
  local changed = false
  if state.activeWorkspaceId ~= wsId then
    state.activeWorkspaceId = wsId
    changed = true
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
  if state.workspaceLayouts[wsId] ~= clean then
    state.workspaceLayouts[wsId] = clean
    state.notify()
  end
end

function state.getEffectiveLayout(): string
  if state.currentScope == "workspace" then
    local wsLayout = state.workspaceLayouts[state.activeWorkspaceId]
    if wsLayout and wsLayout ~= "" then
      return wsLayout
    end
  end
  return state.globalLayout or "dwindle"
end

return state
