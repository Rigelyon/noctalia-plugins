--!nonstrict
-- Central Reactive State Store & Subscriber Hub
local layoutMath = require("./layout_math.luau")
local hypr = require("./hypr.luau")
local profiles = require("./profiles.luau")

local state = {
  monitors = {} :: { layoutMath.Monitor },
  workingMonitors = {} :: { layoutMath.Monitor },
  previousSafeMonitors = {} :: { layoutMath.Monitor },
  selectedMonitorName = "" :: string,
  activeTab = "inspector" :: string, -- "inspector" | "profiles"
  safetyTimer = 15 :: number,
  isSafetyModalVisible = false :: boolean,
  hasPendingChanges = false :: boolean,
  listeners = {} :: { () -> () },
}

local function cloneMonitors(source: { layoutMath.Monitor }): { layoutMath.Monitor }
  local cloned = {}
  for _, m in ipairs(source) do
    local copy = {}
    for k, v in pairs(m) do
      if type(v) == "table" then
        local sub = {}
        for subK, subV in pairs(v) do sub[subK] = subV end
        copy[k] = sub
      else
        copy[k] = v
      end
    end
    table.insert(cloned, copy)
  end
  return cloned
end

function state.subscribe(callback: () -> ()): () -> ()
  table.insert(state.listeners, callback)
  return function()
    for i, cb in ipairs(state.listeners) do
      if cb == callback then
        table.remove(state.listeners, i)
        break
      end
    end
  end
end

function state.notify()
  for _, callback in ipairs(state.listeners) do
    callback()
  end
end

function state.refresh(onDone: (() -> ())?)
  hypr.refreshMonitors(function(list, ok)
    state.monitors = list
    local topologyChanged = (#list ~= #state.workingMonitors)
    if not topologyChanged then
      for i, m in ipairs(list) do
        if not state.workingMonitors[i] or state.workingMonitors[i].name ~= m.name then
          topologyChanged = true
          break
        end
      end
    end

    if topologyChanged or not state.hasPendingChanges then
      state.workingMonitors = cloneMonitors(list)
      state.previousSafeMonitors = cloneMonitors(list)
      state.hasPendingChanges = false
    end
    if #list > 0 and (state.selectedMonitorName == "" or not state.getSelectedMonitor()) then
      state.selectedMonitorName = list[1].name
    end
    state.notify()
    if onDone then onDone() end
  end)
end

function state.init(onReady: (() -> ())?)
  hypr.init()
  profiles.loadProfiles()
  hypr.startSocketStream(function()
    state.refresh()
  end)
  state.refresh(onReady)
end

function state.selectMonitor(name: string)
  state.selectedMonitorName = name
  state.notify()
end

function state.getSelectedMonitor(): layoutMath.Monitor?
  for _, m in ipairs(state.workingMonitors) do
    if m.name == state.selectedMonitorName then
      return m
    end
  end
  if #state.workingMonitors > 0 then
    return state.workingMonitors[1]
  end
  return nil
end

function state.setWorkingProperty(monitorName: string, key: string, value: any)
  for _, m in ipairs(state.workingMonitors) do
    if m.name == monitorName then
      m[key] = value
      state.hasPendingChanges = true
      state.notify()
      break
    end
  end
end

function state.startSafetyCountdown(onExpired: (() -> ())?)
  local timeout = 15
  if noctalia and noctalia.getConfig then
    timeout = tonumber(noctalia.getConfig("safety_timeout")) or 15
  end
  state.safetyTimer = timeout
  state.isSafetyModalVisible = true
  state.notify()
end

function state.keepChanges()
  state.isSafetyModalVisible = false
  state.monitors = cloneMonitors(state.workingMonitors)
  state.previousSafeMonitors = cloneMonitors(state.workingMonitors)
  state.hasPendingChanges = false
  state.notify()
end

function state.revertToSafe()
  state.isSafetyModalVisible = false
  state.workingMonitors = cloneMonitors(state.previousSafeMonitors)
  state.monitors = cloneMonitors(state.previousSafeMonitors)
  state.hasPendingChanges = false
  hypr.applyBatch(state.previousSafeMonitors)
  state.notify()
end

function state.discardPendingChanges()
  state.workingMonitors = cloneMonitors(state.monitors)
  state.hasPendingChanges = false
  state.notify()
end

return state
