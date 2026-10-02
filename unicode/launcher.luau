--!nonstrict
-- Unicode Launcher Provider for Noctalia
-- Provides fast searching and one-click copying of ~40,000 Unicode characters.

-- Top-level categories with icons for initial empty query
local CATEGORIES = {
  { id = "category:Arrows", title = "Arrows", subtitle = "Browse arrows (→, ⇒, ➔, ⇡) • Press Enter to view", glyph = "arrow-right" },
  { id = "category:Mathematical Operators", title = "Mathematical Operators", subtitle = "Browse math symbols (∑, √, ∞, ∫, ±) • Press Enter to view", glyph = "math-function" },
  { id = "category:Currency Symbols", title = "Currency Symbols", subtitle = "Browse currencies (€, £, ¥, ₹, ₿) • Press Enter to view", glyph = "currency-dollar" },
  { id = "category:Geometric Shapes", title = "Geometric Shapes", subtitle = "Browse geometric shapes (▲, ■, ◆, ○) • Press Enter to view", glyph = "shapes" },
  { id = "category:Box Drawing", title = "Box Drawing & Blocks", subtitle = "Browse box drawing (─, │, ┌, █, ░) • Press Enter to view", glyph = "border-outer" },
  { id = "category:Dingbats", title = "Dingbats & Symbols", subtitle = "Browse dingbats (★, ✂, ✈, ✔, ✿) • Press Enter to view", glyph = "sparkles" },
  { id = "category:Greek and Coptic", title = "Greek and Coptic", subtitle = "Browse Greek alphabet (α, β, γ, π, Ω) • Press Enter to view", glyph = "letter-case" },
  { id = "category:Letterlike Symbols", title = "Letterlike Symbols", subtitle = "Browse letterlike symbols (№, ℃, ℉, ™) • Press Enter to view", glyph = "typography" },
  { id = "category:General Punctuation", title = "General Punctuation", subtitle = "Browse punctuation (—, …, «, », •) • Press Enter to view", glyph = "quote" },
}

-- Fallback items if data file is missing or corrupt
local FALLBACK_ITEMS = {
  { "00A9", "©", "COPYRIGHT SIGN", "Symbols" },
  { "00AE", "®", "REGISTERED SIGN", "Symbols" },
  { "2122", "™", "TRADE MARK SIGN", "Symbols" },
  { "2190", "←", "LEFTWARDS ARROW", "Arrows" },
  { "2192", "→", "RIGHTWARDS ARROW", "Arrows" },
  { "2191", "↑", "UPWARDS ARROW", "Arrows" },
  { "2193", "↓", "DOWNWARDS ARROW", "Arrows" },
  { "221E", "∞", "INFINITY", "Mathematical Operators" },
  { "221A", "√", "SQUARE ROOT", "Mathematical Operators" },
  { "2248", "≈", "ALMOST EQUAL TO", "Mathematical Operators" },
  { "2260", "≠", "NOT EQUAL TO", "Mathematical Operators" },
  { "2264", "≤", "LESS-THAN OR EQUAL TO", "Mathematical Operators" },
  { "2265", "≥", "GREATER-THAN OR EQUAL TO", "Mathematical Operators" },
  { "20AC", "€", "EURO SIGN", "Currency Symbols" },
  { "00A3", "£", "POUND SIGN", "Currency Symbols" },
  { "00A5", "¥", "YEN SIGN", "Currency Symbols" },
  { "2713", "✓", "CHECK MARK", "Dingbats" },
  { "2714", "✔", "HEAVY CHECK MARK", "Dingbats" },
  { "2717", "✗", "BALLOT X", "Dingbats" },
  { "2718", "✘", "HEAVY BALLOT X", "Dingbats" },
}

local unicodeData = nil
local queryCache = {}
local cacheKeys = {}
local MAX_CACHE_SIZE = 60

local function loadUnicodeData()
  if unicodeData ~= nil then
    return unicodeData
  end

  local content, err = noctalia.readFile("data/unicode.json")
  if not content or err then
    noctalia.notifyError("Unicode", "Failed to load unicode.json: " .. tostring(err))
    unicodeData = FALLBACK_ITEMS
    return unicodeData
  end

  local decoded, jsonErr = noctalia.json.decode(content)
  if not decoded or jsonErr then
    noctalia.notifyError("Unicode", "Failed to parse unicode.json: " .. tostring(jsonErr))
    unicodeData = FALLBACK_ITEMS
    return unicodeData
  end

  unicodeData = decoded
  return unicodeData
end

local function cachePut(query, results)
  if #cacheKeys >= MAX_CACHE_SIZE then
    local oldest = table.remove(cacheKeys, 1)
    if oldest then
      queryCache[oldest] = nil
    end
  end
  table.insert(cacheKeys, query)
  queryCache[query] = results
end

local function splitTokens(text)
  local tokens = {}
  for token in string.gmatch(text, "%S+") do
    table.insert(tokens, token:upper())
  end
  return tokens
end

local function searchUnicode(query, limit)
  local cached = queryCache[query]
  if cached then
    return cached
  end

  local data = loadUnicodeData()
  local qUpper = query:upper()
  local isHex = false
  local hexTarget = qUpper

  if string.sub(hexTarget, 1, 2) == "U+" then
    hexTarget = string.sub(hexTarget, 3)
    isHex = true
  elseif #hexTarget >= 2 and string.match(hexTarget, "^[0-9A-F]+$") then
    isHex = true
  end

  local tokens = splitTokens(qUpper)
  local rows = {}
  local count = 0

  for i = 1, #data do
    local item = data[i]
    local code = item[1]
    local char = item[2]
    local name = item[3]
    local cat = item[4]

    local matched = false
    if isHex and string.sub(code, 1, #hexTarget) == hexTarget then
      matched = true
    elseif #tokens > 0 then
      matched = true
      local nameUpper = name
      local catUpper = cat:upper()
      for t = 1, #tokens do
        local tok = tokens[t]
        if not string.find(nameUpper, tok, 1, true) and not string.find(catUpper, tok, 1, true) then
          matched = false
          break
        end
      end
    end

    if matched then
      count = count + 1
      rows[count] = {
        id = char .. "\t" .. code .. "\t" .. name,
        title = char,
        subtitle = name .. " • " .. cat,
        badge = "U+" .. code,
        glyph = "copy",
      }
      if count >= limit then
        break
      end
    end
  end

  if count == 0 then
    rows[1] = {
      id = "",
      title = "No characters found",
      subtitle = "Try another keyword or hex code (e.g. U+2192)",
      glyph = "mood-empty",
    }
  end

  cachePut(query, rows)
  return rows
end

function onQuery(query)
  local trimmed = noctalia.string.trim(query)
  if trimmed == "" then
    launcher.setResults(query, CATEGORIES)
    return
  end

  local maxResults = 30
  if noctalia.getConfig then
    local cfgMax = noctalia.getConfig("max_results")
    if cfgMax then
      maxResults = tonumber(cfgMax) or 30
    end
  else
    local okCfg, cfg = pcall(function()
      return (noctalia.config and noctalia.config.get) and noctalia.config.get() or nil
    end)
    if okCfg and cfg and cfg.max_results then
      maxResults = tonumber(cfg.max_results) or 30
    end
  end

  local results = searchUnicode(trimmed, maxResults)
  launcher.setResults(query, results)
end

function onActivate(id)
  if not id or id == "" then
    return
  end

  local category = string.match(id, "^category:(.+)$")
  if category then
    launcher.setQuery(category .. " ")
    return
  end

  local char, code, name = string.match(id, "^([^\t]+)\t([^\t]+)\t([^\t]+)$")
  if not char then
    char = id
    code = ""
    name = ""
  end

  local copyFormat = "character"
  local notifyOnCopy = true

  if noctalia.getConfig then
    local fmt = noctalia.getConfig("copy_format")
    if fmt and fmt ~= "" then copyFormat = fmt end
    local notif = noctalia.getConfig("notify_on_copy")
    if notif ~= nil then notifyOnCopy = notif end
  end

  local okCfg, cfg = pcall(function()
    return (noctalia.config and noctalia.config.get) and noctalia.config.get() or nil
  end)
  if okCfg and cfg then
    if cfg.copy_format then copyFormat = cfg.copy_format end
    if cfg.notify_on_copy ~= nil then notifyOnCopy = cfg.notify_on_copy end
  end

  local textToCopy = char
  if copyFormat == "codepoint" and code ~= "" then
    textToCopy = "U+" .. code
  elseif copyFormat == "both" and code ~= "" then
    textToCopy = char .. " (U+" .. code .. ")"
  end

  local success = noctalia.copyToClipboard(textToCopy, "text/plain")
  if success and notifyOnCopy then
    local detail = textToCopy
    if name ~= "" then
      detail = char .. " (" .. name .. ")"
    end
    noctalia.notify("Unicode", "Copied " .. detail .. " to clipboard")
  elseif not success then
    noctalia.notifyError("Unicode", "Failed to copy to clipboard")
  end
end
