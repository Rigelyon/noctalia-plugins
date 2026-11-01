--!nonstrict
-- Central Reactive State Store & Subscriber Hub
local layoutMath = require("./layout_math.luau")
local hypr = require("./hypr.luau")
local config = require("./config.luau")
local profiles = require("./profiles.luau")

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

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
  _timerId = 0 :: number,
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

state.cloneMonitors = cloneMonitors

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

    -- While the safety modal is actively countdown, do not clobber workingMonitors or safe rollback monitors
    if state.isSafetyModalVisible then
      state.notify()
      if onDone then onDone() end
      return
    end

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
      for _, wm in ipairs(state.workingMonitors) do
        if not wm.mirrorOf or wm.mirrorOf == "" or wm.mirrorOf == "none" then
          wm._unmirroredX = wm.x or 0
          wm._unmirroredY = wm.y or 0
        end
      end
      layoutMath.resolveCollisions(state.workingMonitors)
      layoutMath.normalizeCoordinates(state.workingMonitors)
      state.previousSafeMonitors = cloneMonitors(state.workingMonitors)
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
      if key == "disabled" and value == false then
        local overlaps = false
        for _, other in ipairs(state.workingMonitors) do
          if other.name ~= monitorName and not other.disabled then
            if (other.x or 0) == (m.x or 0) and (other.y or 0) == (m.y or 0) then
              overlaps = true
              break
            end
          end
        end
        if overlaps then
          local maxRight = -999999
          local rightmost = nil
          for _, other in ipairs(state.workingMonitors) do
            if other.name ~= monitorName and not other.disabled then
              local ovw, _ = layoutMath.getVirtualSize(other)
              local rightEdge = (other.x or 0) + ovw
              if rightEdge > maxRight then
                maxRight = rightEdge
                rightmost = other
              end
            end
          end
          if rightmost then
            layoutMath.snapRight(m, rightmost)
          end
        end
        layoutMath.normalizeCoordinates(state.workingMonitors)
        state.selectedMonitorName = monitorName
      end
      state.hasPendingChanges = true
      state.notify()
      break
    end
  end
end

-- Persists the current working monitors to ~/.config/hypr/hypr-monitors.lua with safety countdown
function state.applyConfig(onDone: ((boolean) -> ())?)
  state.previousSafeMonitors = cloneMonitors(state.monitors)

  local ok, err = config.writeConfig(state.workingMonitors)
  if ok then
    local enableSafety = true
    if noctalia and noctalia.getConfig then
      enableSafety = noctalia.getConfig("enable_safety_timer") ~= false
    end

    if enableSafety then
      state.startSafetyCountdown()
    else
      state.hasPendingChanges = false
      state.monitors = cloneMonitors(state.workingMonitors)
      state.notify()
      if noctalia and noctalia.notify then
        noctalia.notify(tr("panel.notify_saved_title"), tr("panel.notify_saved_body", { path = config.getConfigPath() }))
      end
    end
  else
    if noctalia and noctalia.notifyError then
      noctalia.notifyError(tr("panel.notify_failed_title"), tostring(err or "Failed to write config file"))
    end
  end
  if onDone then onDone(ok) end
end

function state.startSafetyCountdown(onExpired: (() -> ())?)
  local timeout = 15
  if noctalia and noctalia.getConfig then
    timeout = tonumber(noctalia.getConfig("safety_timeout")) or 15
  end
  state.safetyTimer = timeout
  state.isSafetyModalVisible = true
  if not state.previousSafeMonitors or #state.previousSafeMonitors == 0 then
    state.previousSafeMonitors = cloneMonitors(state.monitors)
  end
  state.notify()

  local currentId = (state._timerId or 0) + 1
  state._timerId = currentId

  local function tick()
    if not state.isSafetyModalVisible or state._timerId ~= currentId then return end
    if noctalia and noctalia.runAsync then
      noctalia.runAsync({ "sleep", "1" }, function(_)
        if not state.isSafetyModalVisible or state._timerId ~= currentId then return end
        state.safetyTimer = state.safetyTimer - 1
        if state.safetyTimer <= 0 then
          state.revertToSafe()
          if onExpired then onExpired() end
        else
          state.notify()
          tick()
        end
      end)
    end
  end
  tick()
end

function state.keepChanges()
  state.isSafetyModalVisible = false
  state.monitors = cloneMonitors(state.workingMonitors)
  state.previousSafeMonitors = cloneMonitors(state.workingMonitors)
  state.hasPendingChanges = false
  state.notify()
  if noctalia and noctalia.notify then
    noctalia.notify(tr("panel.notify_confirmed_title"), tr("panel.notify_saved_body", { path = config.getConfigPath() }))
  end
end

function state.revertToSafe()
  state.isSafetyModalVisible = false
  state.workingMonitors = cloneMonitors(state.previousSafeMonitors)
  state.monitors = cloneMonitors(state.previousSafeMonitors)
  state.hasPendingChanges = false
  config.writeConfig(state.previousSafeMonitors)
  state.notify()
  if noctalia and noctalia.notify then
    noctalia.notify(tr("panel.notify_reverted_title"), tr("panel.notify_reverted_body"))
  end
end

function state.discardPendingChanges()
  state.workingMonitors = cloneMonitors(state.monitors)
  state.hasPendingChanges = false
  state.notify()
end

return state
