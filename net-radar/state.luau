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

  -- Ring buffer for ui.graph (60 samples, nil stored as -1)
  history = {} :: { number },

  -- Subscribers
  listeners = {} :: { () -> () },
  isProbing = false,
  lastProbeTime = 0,
}

for i = 1, state.BUFFER_SIZE do
  table.insert(state.history, -1)
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

function state.processProbe(rawOutput: string)
  if not rawOutput or rawOutput == "" then
    return
  end

  local clean = string.gsub(rawOutput, "[\r\n]", "")
  local parts = {}
  for part in string.gmatch(clean, "([^|]+)") do
    table.insert(parts, part)
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

  -- Push into fixed ring buffer
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

  state.notify()
end

function state.getStatus(): string
  if not state.gwMs and not state.dnsMs then
    return "OFFLINE"
  end
  if state.gwMs and not state.dnsMs and not state.gameMs then
    return "CAPTIVE_PORTAL"
  end
  if not state.gameMs then
    return "POOR"
  end

  if state.gameMs < 60.0 and state.jitter < 10.0 and state.lossPct == 0.0 then
    return "OPTIMAL"
  end
  if state.gameMs <= 120.0 and state.jitter <= 25.0 and state.lossPct <= 3.0 then
    return "FAIR"
  end
  return "POOR"
end

function state.getGraphValues(): ({ number }, number, number, number)
  local values = {}
  local minMs = 999999.0
  local maxMs = 0.0
  local sumMs = 0.0
  local count = 0

  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v >= 0 then
      if v < minMs then minMs = v end
      if v > maxMs then maxMs = v end
      sumMs = sumMs + v
      count = count + 1
    end
  end

  local ceiling = math.max(100.0, maxMs * 1.25)
  for i = 1, state.BUFFER_SIZE do
    local v = state.history[i]
    if v < 0 then
      table.insert(values, 0.0)
    else
      table.insert(values, math.min(1.0, math.max(0.0, v / ceiling)))
    end
  end

  local avgMs = count > 0 and (sumMs / count) or 0.0
  if minMs > 999990.0 then minMs = 0.0 end

  return values, minMs, avgMs, maxMs
end

return state
