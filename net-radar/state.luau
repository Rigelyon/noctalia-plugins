--!nonstrict
local presets = require("./presets.luau")

local state = {
  BUFFER_SIZE = 60,
  LOSS_WINDOW = 20,

  -- Current metrics
  gwMs = nil :: number?,
  dnsMs = nil :: number?,
  gameMs = nil :: number?,
  prevGameMs = nil :: number?,
  jitter = 0.0,
  lossPct = 0.0,
  sampleCount = 0,

  -- Wi-Fi physical PHY link
  ssid = "",
  freqMhz = 0,
  signalPct = 0,
  rateMbps = 0.0,

  -- Active target preset
  activePresetId = "sea_singapore",
  customHost = "1.1.1.1",

  -- Ring buffers for ui.graph (60 samples)
  history = {} :: { number },
  jitterHistory = {} :: { number },
  lossHistory = {} :: { number },
  secondaryGraphMode = "jitter" :: "jitter" | "loss",
  nmConn = "unknown",

  -- Subscribers
  listeners = {} :: { () -> () },
  isProbing = false,
  lastProbeTime = 0,
}

for i = 1, state.BUFFER_SIZE do
  table.insert(state.history, -1)
  table.insert(state.jitterHistory, 0.0)
  table.insert(state.lossHistory, 0.0)
end

function state.subscribe(fn: () -> ())
  table.insert(state.listeners, fn)
end

function state.notify()
  for _, fn in ipairs(state.listeners) do
    fn()
  end
end

function state.getActiveTargetHost(): string
  if state.activePresetId == "custom" then
    return state.customHost ~= "" and state.customHost or "1.1.1.1"
  end
  local p = presets.getById(state.activePresetId)
  return p.host
end

function state.syncConfig()
  if noctalia and noctalia.getConfig then
    local defaultPreset = noctalia.getConfig("default_target_preset")
    if type(defaultPreset) == "string" and defaultPreset ~= "" then
      state.activePresetId = defaultPreset
    end
    local customHost = noctalia.getConfig("custom_target_host")
    if type(customHost) == "string" and customHost ~= "" then
      state.customHost = customHost
    end
  end
end

function state.setPreset(presetId: string)
  state.activePresetId = presetId
  state.prevGameMs = nil
  if noctalia and noctalia.state then
    local current = noctalia.state.get("net_radar.state")
    if type(current) ~= "table" then
      current = {}
    end
    current.activePresetId = presetId
    current.prevGameMs = nil
    noctalia.state.set("net_radar.state", current)
  end
  state.notify()
end

function state.setSecondaryGraphMode(mode: "jitter" | "loss")
  state.secondaryGraphMode = mode
  if noctalia and noctalia.state then
    local current = noctalia.state.get("net_radar.state")
    if type(current) ~= "table" then
      current = {}
    end
    current.secondaryGraphMode = mode
    noctalia.state.set("net_radar.state", current)
  end
  state.notify()
end

function state.processProbe(rawOutput: string)
  if not rawOutput or rawOutput == "" then
    return
  end

  local clean = string.gsub(rawOutput, "[\r\n]", "")
  local parts = {}
  local start = 1
  while true do
    local p = string.find(clean, "|", start, true)
    if not p then
      table.insert(parts, string.sub(clean, start))
      break
    end
    table.insert(parts, string.sub(clean, start, p - 1))
    start = p + 1
  end

  if #parts < 7 then
    return
  end

  state.gwMs = (parts[1] ~= "none") and tonumber(parts[1]) or nil
  state.dnsMs = (parts[2] ~= "none") and tonumber(parts[2]) or nil
  state.gameMs = (parts[3] ~= "none") and tonumber(parts[3]) or nil
  state.ssid = (parts[4] ~= "none") and parts[4] or ""
  state.freqMhz = tonumber(parts[5]) or 0
  state.signalPct = tonumber(parts[6]) or 0
  state.rateMbps = tonumber(parts[7]) or 0.0
  state.nmConn = parts[8] or "unknown"

  -- Push into fixed ring buffer for latency
  table.remove(state.history, 1)
  table.insert(state.history, state.gameMs or -1)
  state.sampleCount = state.sampleCount + 1

  -- RFC 3550 Jitter
  if state.gameMs then
    if state.prevGameMs then
      local diff = math.abs(state.gameMs - state.prevGameMs)
      state.jitter = state.jitter + (diff - state.jitter) / 16.0
    end
    state.prevGameMs = state.gameMs
  end
  table.remove(state.jitterHistory, 1)
  table.insert(state.jitterHistory, state.jitter)

  -- Packet loss over rolling window
  local windowSize = math.min(state.sampleCount, state.LOSS_WINDOW)
  local dropped = 0
  local total = 0
  local startIndex = math.max(1, state.BUFFER_SIZE - windowSize + 1)
  for i = startIndex, state.BUFFER_SIZE do
    total = total + 1
    if state.history[i] < 0 then
      dropped = dropped + 1
    end
  end
  state.lossPct = total > 0 and (dropped / total) * 100.0 or 0.0
  table.remove(state.lossHistory, 1)
  table.insert(state.lossHistory, state.lossPct)

  if noctalia and noctalia.state then
    noctalia.state.set("net_radar.state", {
      gwMs = state.gwMs,
      dnsMs = state.dnsMs,
      gameMs = state.gameMs,
      prevGameMs = state.prevGameMs,
      jitter = state.jitter,
      lossPct = state.lossPct,
      sampleCount = state.sampleCount,
      ssid = state.ssid,
      freqMhz = state.freqMhz,
      signalPct = state.signalPct,
      rateMbps = state.rateMbps,
      history = state.history,
      jitterHistory = state.jitterHistory,
      lossHistory = state.lossHistory,
      secondaryGraphMode = state.secondaryGraphMode,
      nmConn = state.nmConn,
      activePresetId = state.activePresetId,
      customHost = state.customHost,
    })
  end

  state.notify()
end

function state.getStatus(): string
  if not state.gwMs and not state.dnsMs then
    return "OFFLINE"
  end
  if state.nmConn == "portal" then
    return "CAPTIVE_PORTAL"
  end
  if state.gwMs and not state.dnsMs and not state.gameMs then
    return "NO_INTERNET"
  end
  if not state.gameMs then
    return "POOR"
  end

  if state.gameMs < 60.0 and state.jitter < 10.0 and state.lossPct == 0.0 then
    return "OPTIMAL"
  end
  if state.gameMs <= 120.0 and state.jitter <= 25.0 and state.lossPct <= 5.0 then
    return "FAIR"
  end
  return "POOR"
end

function state.getGraphValues(): ({ number }, { number }, number, number, number, number, number, number, number)
  local primaryValues = {}
  local jitterValues = {}
  local minMs = 999999.0
  local maxMs = 0.0
  local sumMs = 0.0
  local count = 0
  local droppedCount = 0

  local populated = math.min(state.sampleCount, state.BUFFER_SIZE)
  local startIndex = (populated > 0) and (state.BUFFER_SIZE - populated + 1) or 1

  for i = startIndex, state.BUFFER_SIZE do
    local v = state.history[i]
    if v >= 0 then
      if v < minMs then minMs = v end
      if v > maxMs then maxMs = v end
      sumMs = sumMs + v
      count = count + 1
    else
      if populated > 0 then
        droppedCount = droppedCount + 1
      end
    end
  end

  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v >= 0 and maxMs == 0.0 then
      maxMs = v
    end
  end

  local ceiling = math.max(100.0, maxMs * 1.25)
  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v < 0 then
      table.insert(primaryValues, 0.0)
    else
      table.insert(primaryValues, math.min(1.0, math.max(0.0, v / ceiling)))
    end
  end

  local avgMs = count > 0 and (sumMs / count) or 0.0
  if minMs > 999990.0 then minMs = 0.0 end

  -- Jitter calculation
  local jMax = 0.0
  local jSum = 0.0
  local jCount = 0
  for i = startIndex, state.BUFFER_SIZE do
    local j = state.jitterHistory[i] or 0.0
    if j > jMax then jMax = j end
    jSum = jSum + j
    jCount = jCount + 1
  end
  local jCeiling = math.max(15.0, jMax * 1.3)
  for i = 1, state.BUFFER_SIZE do
    local j = state.jitterHistory[i] or 0.0
    table.insert(jitterValues, math.min(1.0, math.max(0.0, j / jCeiling)))
  end
  local avgJitter = jCount > 0 and (jSum / jCount) or 0.0
  local maxJitter = jMax

  -- Loss calculation
  local lMax = 0.0
  for i = startIndex, state.BUFFER_SIZE do
    local l = state.lossHistory[i] or 0.0
    if l > lMax then lMax = l end
  end
  local maxLoss = lMax

  return primaryValues, jitterValues, minMs, avgMs, maxMs, avgJitter, maxJitter, maxLoss, droppedCount
end

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

function state.getDiagnostics(): (string, string, string)
  -- 1. Tier 1 Critical (Takes precedence over everything)
  if not state.gwMs and not state.dnsMs then
    return tr("panel.diag_offline"), "alert-triangle", "outline"
  end

  if state.nmConn == "portal" then
    return tr("panel.diag_captive_portal"), "alert-triangle", "#f59e0b"
  end

  if state.gwMs and not state.dnsMs and not state.gameMs then
    return tr("panel.diag_no_internet"), "alert-triangle", "#f59e0b"
  end

  if state.lossPct >= 10.0 or not state.gameMs then
    local lossVal = (not state.gameMs and state.lossPct == 0.0) and 100.0 or state.lossPct
    local isServerOnly = (state.dnsMs and state.dnsMs <= 60.0)
    local key = isServerOnly and "panel.diag_server_loss" or "panel.diag_isp_loss"
    return tr(key, { loss = string.format("%.0f", lossVal) }), "alert-triangle", "error"
  end

  -- Finding collection
  local findings = {}
  local isWeakWifi = (state.ssid and state.ssid ~= "" and (state.signalPct or 0) > 0 and (state.signalPct or 0) < 40)

  -- 2. Tier 2 Acute Findings
  if state.lossPct >= 1.0 and state.lossPct < 10.0 then
    local isServerOnly = (state.dnsMs and state.dnsMs <= 60.0)
    local key = isServerOnly and "panel.diag_server_loss" or "panel.diag_isp_loss"
    table.insert(findings, {
      id = isServerOnly and "server_loss" or "isp_loss",
      text = tr(key, { loss = string.format("%.1f", state.lossPct) }),
      glyph = "alert-triangle",
      color = "error",
      tier = 2,
      priority = 1,
      isStable = false,
    })
  end

  if state.gwMs and state.gwMs <= 15.0 and state.gameMs and state.gameMs > 120.0 then
    local isServerOnly = (state.dnsMs and state.dnsMs <= 60.0)
    local key = isServerOnly and "panel.diag_server_lag" or "panel.diag_isp_lag"
    table.insert(findings, {
      id = isServerOnly and "server_lag" or "isp_lag",
      text = tr(key, { ms = string.format("%.0f", state.gameMs) }),
      glyph = "alert-circle",
      color = "tertiary",
      tier = 2,
      priority = 2,
      isStable = false,
    })
  end

  if state.gwMs and state.gwMs > 30.0 and not isWeakWifi then
    table.insert(findings, {
      id = "local_bufferbloat",
      text = tr("panel.diag_local_bufferbloat", { ms = string.format("%.0f", state.gwMs) }),
      glyph = "alert-circle",
      color = "tertiary",
      tier = 2,
      priority = 3,
      isStable = false,
    })
  end

  if (state.jitter or 0.0) > 15.0 then
    table.insert(findings, {
      id = "high_jitter",
      text = tr("panel.diag_high_jitter", { jitter = string.format("%.1f", state.jitter) }),
      glyph = "alert-circle",
      color = "tertiary",
      tier = 2,
      priority = 4,
      isStable = false,
    })
  end

  -- 3. Tier 3 Environmental / Physical Findings
  if isWeakWifi then
    if (not state.gwMs or state.gwMs <= 20.0) and (state.jitter or 0.0) <= 10.0 and (state.lossPct or 0.0) == 0.0 then
      table.insert(findings, {
        id = "weak_signal_stable",
        text = tr("panel.diag_weak_signal_stable", { signal = tostring(state.signalPct or 0) }),
        glyph = "info-circle",
        color = "primary",
        tier = 3,
        priority = 5,
        isStable = true,
      })
    else
      table.insert(findings, {
        id = "wifi_weak_unstable",
        text = tr("panel.diag_wifi_weak_unstable", { signal = tostring(state.signalPct or 0) }),
        glyph = "alert-triangle",
        color = "tertiary",
        tier = 3,
        priority = 6,
        isStable = false,
      })
    end
  elseif (state.ssid == "" or not state.ssid) and state.gwMs then
    table.insert(findings, {
      id = "wired_optimal",
      text = tr("panel.diag_wired_optimal"),
      glyph = "check-circle",
      color = "primary",
      tier = 3,
      priority = 7,
      isStable = true,
    })
  end

  -- 4. Synthesis & Fallback
  local hasIssues = false
  for _, f in ipairs(findings) do
    if not f.isStable then
      hasIssues = true
      break
    end
  end

  local activeFindings = {}
  for _, f in ipairs(findings) do
    if not hasIssues or not f.isStable then
      table.insert(activeFindings, f)
    end
  end

  if #activeFindings == 0 then
    return tr("panel.diag_optimal"), "info-circle", "primary"
  end

  if #activeFindings == 1 then
    local f = activeFindings[1]
    return f.text, f.glyph, f.color
  end

  -- Sort active findings by severity and priority
  local function severityScore(color: string): number
    if color == "error" then return 1 end
    if color == "tertiary" then return 2 end
    if color == "primary" then return 3 end
    return 4
  end

  table.sort(activeFindings, function(a, b)
    local sa = severityScore(a.color)
    local sb = severityScore(b.color)
    if sa ~= sb then
      return sa < sb
    end
    if a.tier ~= b.tier then
      return a.tier < b.tier
    end
    return a.priority < b.priority
  end)

  local f1 = activeFindings[1]
  local f2 = activeFindings[2]

  local clean1 = (string.gsub(f1.text, "%s*%.+$", ""))
  local clean2 = (string.gsub(f2.text, "%s*%.+$", ""))

  local diagText = tr("panel.diag_synthesis_connector", { first = clean1, second = clean2 })

  local overallColor = "primary"
  if f1.color == "error" or f2.color == "error" then
    overallColor = "error"
  elseif f1.color == "tertiary" or f2.color == "tertiary" then
    overallColor = "tertiary"
  end

  local overallGlyph = f1.glyph

  return diagText, overallGlyph, overallColor
end

state.syncConfig()

-- Cross-VM IPC Synchronization via noctalia.state
if noctalia and noctalia.state then
  local existing = noctalia.state.get("net_radar.state")
  if existing and type(existing) == "table" then
    state.gwMs = existing.gwMs
    state.dnsMs = existing.dnsMs
    state.gameMs = existing.gameMs
    state.prevGameMs = existing.prevGameMs
    state.jitter = existing.jitter or 0.0
    state.lossPct = existing.lossPct or 0.0
    state.sampleCount = existing.sampleCount or 0
    state.ssid = existing.ssid or ""
    state.freqMhz = existing.freqMhz or 0
    state.signalPct = existing.signalPct or 0
    state.rateMbps = existing.rateMbps or 0.0
    if existing.history then
      state.history = existing.history
    end
    if existing.jitterHistory then
      state.jitterHistory = existing.jitterHistory
    end
    if existing.lossHistory then
      state.lossHistory = existing.lossHistory
    end
    if existing.secondaryGraphMode then
      state.secondaryGraphMode = existing.secondaryGraphMode
    end
    if existing.nmConn then
      state.nmConn = existing.nmConn
    end
    if existing.activePresetId then
      state.activePresetId = existing.activePresetId
    end
    if existing.customHost then
      state.customHost = existing.customHost
    end
  end

  noctalia.state.watch("net_radar.state", function(data)
    if data and type(data) == "table" then
      state.gwMs = data.gwMs
      state.dnsMs = data.dnsMs
      state.gameMs = data.gameMs
      state.prevGameMs = data.prevGameMs
      state.jitter = data.jitter or 0.0
      state.lossPct = data.lossPct or 0.0
      state.sampleCount = data.sampleCount or 0
      state.ssid = data.ssid or ""
      state.freqMhz = data.freqMhz or 0
      state.signalPct = data.signalPct or 0
      state.rateMbps = data.rateMbps or 0.0
      if data.history then
        state.history = data.history
      end
      if data.jitterHistory then
        state.jitterHistory = data.jitterHistory
      end
      if data.lossHistory then
        state.lossHistory = data.lossHistory
      end
      if data.secondaryGraphMode then
        state.secondaryGraphMode = data.secondaryGraphMode
      end
      if data.nmConn then
        state.nmConn = data.nmConn
      end
      if data.activePresetId then
        state.activePresetId = data.activePresetId
      end
      if data.customHost then
        state.customHost = data.customHost
      end
      state.notify()
    end
  end)
end

return state
