--!nonstrict
-- Unicode Launcher Provider for Noctalia
-- Provides fast searching, category browsing, and one-click copying of Unicode characters.

local CATEGORY_GLYPHS = {
  ["Arrows"] = "arrow-right",
  ["Math"] = "math-function",
  ["Currency"] = "currency-dollar",
  ["Symbols"] = "sparkles",
  ["Box Drawing"] = "box",
  ["Typography"] = "quote",
  ["Numbers"] = "numbers",
  ["Letterlike"] = "typography",
  ["Greek"] = "letter-case",
  ["Latin"] = "alphabet-latin",
}

-- Fallback items if data file is missing or corrupt
local FALLBACK_ITEMS = {
  { "00A9", "©", "COPYRIGHT SIGN", "Letterlike" },
  { "00AE", "®", "REGISTERED SIGN", "Letterlike" },
  { "2122", "™", "TRADE MARK SIGN", "Letterlike" },
  { "2190", "←", "LEFTWARDS ARROW", "Arrows" },
  { "2192", "→", "RIGHTWARDS ARROW", "Arrows" },
  { "2191", "↑", "UPWARDS ARROW", "Arrows" },
  { "2193", "↓", "DOWNWARDS ARROW", "Arrows" },
  { "221E", "∞", "INFINITY", "Math" },
  { "221A", "√", "SQUARE ROOT", "Math" },
  { "2248", "≈", "ALMOST EQUAL TO", "Math" },
  { "2260", "≠", "NOT EQUAL TO", "Math" },
  { "2264", "≤", "LESS-THAN OR EQUAL TO", "Math" },
  { "2265", "≥", "GREATER-THAN OR EQUAL TO", "Math" },
  { "0024", "$", "DOLLAR SIGN", "Currency" },
  { "20AC", "€", "EURO SIGN", "Currency" },
  { "00A3", "£", "POUND SIGN", "Currency" },
  { "00A5", "¥", "YEN SIGN", "Currency" },
  { "2713", "✓", "CHECK MARK", "Symbols" },
  { "2714", "✔", "HEAVY CHECK MARK", "Symbols" },
  { "2717", "✗", "BALLOT X", "Symbols" },
  { "2718", "✘", "HEAVY BALLOT X", "Symbols" },
}

local db = nil

local function row(code, char, name, cat)
  return {
    id = char .. "\t" .. code .. "\t" .. name,
    title = char .. "   " .. name,
    subtitle = "U+" .. code .. " • " .. cat,
    glyph = CATEGORY_GLYPHS[cat] or "typography",
    category = cat,
  }
end

local function loadDatabase()
  if db ~= nil then
    return db
  end

  local content, err = noctalia.readFile("data/unicode.json")
  local entries = nil

  if content and not err then
    local decoded, jsonErr = noctalia.json.decode(content)
    if decoded and not jsonErr and type(decoded) == "table" then
      entries = decoded
    else
      noctalia.notifyError("Unicode", "Failed to parse unicode.json: " .. tostring(jsonErr))
    end
  else
    noctalia.notifyError("Unicode", "Failed to read data/unicode.json: " .. tostring(err))
  end

  if not entries then
    entries = FALLBACK_ITEMS
  end

  local allRows = {}
  for i = 1, #entries do
    local item = entries[i]
    allRows[i] = row(item[1], item[2], item[3], item[4])
  end

  return { entries = entries, allRows = allRows }
end

local db = loadDatabase()

local function splitTokens(text)
  local tokens = {}
  for token in string.gmatch(text, "%S+") do
    table.insert(tokens, token:upper())
  end
  return tokens
end

function onQuery(query)
  local d = db or loadDatabase()
  local trimmed = noctalia.string.trim(query)

  -- When query is empty, return all pre-formatted rows so Noctalia's native
  -- category filter bar can filter across any category instantly.
  if trimmed == "" then
    launcher.setResults(query, d.allRows)
    return
  end

  local qUpper = trimmed:upper()
  local isHex = false
  local hexTarget = qUpper

  if string.sub(hexTarget, 1, 2) == "U+" then
    hexTarget = string.sub(hexTarget, 3)
    isHex = true
  elseif #hexTarget >= 2 and string.match(hexTarget, "^[0-9A-F]+$") then
    isHex = true
  end

  local tokens = splitTokens(qUpper)
  local maxResults = 100
  local okCfg, cfg = pcall(function()
    return noctalia.getConfig and noctalia.getConfig("max_results") or nil
  end)
  if okCfg and cfg then
    maxResults = tonumber(cfg) or 100
  end

  local rows = {}
  local count = 0
  local entries = d.entries

  for i = 1, #entries do
    local item = entries[i]
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
        if not string.find(nameUpper, tok, 1, true) and not string.find(catUpper, tok, 1, true) and not string.find(char, tok, 1, true) then
          matched = false
          break
        end
      end
    end

    if matched then
      count = count + 1
      rows[count] = row(code, char, name, cat)
      if count >= maxResults then
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

  launcher.setResults(query, rows)
end

function onActivate(id)
  if not id or id == "" then
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
    local notif = noctalia.getConfig("notify_on_copy")
    if fmt then copyFormat = tostring(fmt) end
    if notif ~= nil then notifyOnCopy = (notif == true) end
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
