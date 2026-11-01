--!nonstrict
local state = require("./state.luau")
local presets = require("./presets.luau")

local lastRenderedStatus = ""
local lastRenderedMs = -1
local lastRenderedTextInBar = false
local lastPollTime = 0
local lastNotificationTime = 0

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function executeProbe()
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  if state.isProbing then
    -- Watchdog: if probe has been pending for more than 4000ms, force reset
    if now - state.lastProbeTime < 4000 then
      return
    end
    state.isProbing = false
  end
  state.isProbing = true
  state.lastProbeTime = now

  local pluginDir = (noctalia and noctalia.pluginDir) and noctalia.pluginDir() or "."
  local probeScript = pluginDir .. "/probe.sh"
  local targetHost = state.getActiveTargetHost()

  if noctalia and noctalia.runAsync then
    local started = noctalia.runAsync({ probeScript, targetHost }, function(result)
      state.isProbing = false
      if result and result.exitCode == 0 and result.stdout and result.stdout ~= "" then
        state.processProbe(result.stdout)
      else
        state.processProbe("none|none|none|none|0|0|0")
      end
    end, 2500)
    if not started then
      state.isProbing = false
    end
  else
    state.isProbing = false
  end
end

function onClick()
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/net-radar:panel")
  end
end

local function updateWidget()
  if not barWidget then
    return
  end

  local status = state.getStatus()
  local statusColor = "primary"
  local progressVal = 1.0

  if status == "OPTIMAL" then
    statusColor = "primary"
    progressVal = 1.0
  elseif status == "FAIR" then
    statusColor = "tertiary"
    progressVal = 0.6
  elseif status == "POOR" then
    statusColor = "error"
    progressVal = 0.25
  elseif status == "CAPTIVE_PORTAL" then
    statusColor = "tertiary"
    progressVal = 0.25
  else -- OFFLINE
    statusColor = "outline"
    progressVal = 0.0
  end

  local showText = false
  if noctalia and noctalia.getConfig then
    showText = noctalia.getConfig("show_text_in_bar") == true
  end

  local currentMsFloor = state.gameMs and math.floor(state.gameMs) or -1

  -- Dirty check to minimize redraws
  if status ~= lastRenderedStatus or (showText and currentMsFloor ~= lastRenderedMs) or showText ~= lastRenderedTextInBar then
    lastRenderedStatus = status
    lastRenderedMs = currentMsFloor
    lastRenderedTextInBar = showText

    local isVertical = barWidget.isVertical and barWidget.isVertical()
    local items = {}

    -- 1 dedicated logo only ("radar" Lucide/Tabler icon)
    table.insert(items, ui.glyph({
      name = "radar",
      size = 14,
      color = statusColor,
    }))

    -- System monitor style vertical pill progress bar
    if isVertical then
      table.insert(items, ui.progress({
        width = 14,
        height = 6,
        radius = 3,
        progress = progressVal,
        fill = statusColor,
        track = "surface_variant",
      }))
    else
      table.insert(items, ui.progress({
        width = 6,
        height = 14,
        radius = 3,
        progress = progressVal,
        fill = statusColor,
        track = "surface_variant",
      }))
    end

    if showText and state.gameMs then
      table.insert(items, ui.label({
        text = string.format("%.0fms", state.gameMs),
        fontSize = 11,
        fontWeight = "bold",
        color = statusColor,
      }))
    end

    local tree
    if isVertical then
      tree = ui.column({
        align = "center",
        justify = "center",
        gap = 4,
        onClick = onClick,
      }, items)
    else
      tree = ui.row({
        align = "center",
        justify = "center",
        gap = 4,
        onClick = onClick,
      }, items)
    end

    barWidget.render(tree)
  end

  -- Rich Hover Tooltip
  local currentPreset = presets.getById(state.activePresetId)
  local targetName = currentPreset.regionName
  local gameLatencyStr = state.gameMs and string.format("%.1f ms", state.gameMs) or "--"
  local jitterStr = string.format("±%.1f ms", state.jitter)
  local lossStr = string.format("%.1f%%", state.lossPct)
  local gwStr = state.gwMs and string.format("%.1f ms", state.gwMs) or "--"
  
  local wifiStr = "Ethernet / Disconnected"
  if state.ssid ~= "" then
    local bandStr = state.freqMhz >= 5000 and "5 GHz" or "2.4 GHz"
    wifiStr = string.format("%s • %s • %.0f Mbps (%d%%)", state.ssid, bandStr, state.rateMbps, state.signalPct)
  end

  local tooltips = {
    { key = tr("widget.tooltip_title"), value = string.format("%s (%s)", tr("widget.status_" .. string.lower(status)), targetName) },
    { key = tr("widget.row_game_latency"), value = gameLatencyStr },
    { key = tr("widget.row_jitter"), value = jitterStr },
    { key = tr("widget.row_packet_loss"), value = lossStr },
    { key = tr("widget.row_gateway"), value = gwStr },
    { key = tr("widget.row_wifi_link"), value = wifiStr },
  }
  barWidget.setTooltip(tooltips)

  -- Loss threshold notification check
  if noctalia and noctalia.getConfig and noctalia.notify then
    if noctalia.getConfig("enable_loss_desktop_notification") == true then
      local threshold = noctalia.getConfig("packet_loss_alert_threshold")
      if type(threshold) ~= "number" or threshold <= 0 then
        threshold = 5
      end
      local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
      if state.lossPct >= threshold and (now - lastNotificationTime >= 60000) then
        lastNotificationTime = now
        noctalia.notify(tr("widget.title"), string.format(tr("panel.diag_isp_issue") .. " (Loss: %.0f%%)", state.lossPct))
      end
    end
  end
end

function onConfigChanged()
  state.syncConfig()
  updateWidget()
end

-- Subscribe to state updates
state.subscribe(function()
  updateWidget()
end)

-- Main tick handler with adaptive polling
function update(deltaMs: number)
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  
  local idleInterval = 5000
  if noctalia and noctalia.getConfig then
    local cfg = noctalia.getConfig("idle_poll_interval_sec")
    if type(cfg) == "number" and cfg >= 2 then
      idleInterval = cfg * 1000
    end
  end

  -- Backoff if offline
  if state.getStatus() == "OFFLINE" then
    idleInterval = math.max(idleInterval, 10000)
  end

  if now - lastPollTime >= idleInterval then
    lastPollTime = now
    executeProbe()
  end
end

-- Initial load
state.syncConfig()
executeProbe()
updateWidget()
