--!strict
local markdown = {}

export type Segment = {
  type: string, -- "text" | "code"
  content: string?,
  language: string?,
  code: string?,
}

-- Parses message text into markdown text and fenced code block segments
function markdown.parseSegments(text: string?): { Segment }
  local segments: { Segment } = {}
  if not text or text == "" then
    return segments
  end

  local cursor = 1
  local len = string.len(text)

  while cursor <= len do
    local fenceStart = string.find(text, "```", cursor, true)
    if not fenceStart then
      -- No more code blocks, rest is text
      local remainder = string.sub(text, cursor)
      if string.match(remainder, "%S") then
        table.insert(segments, { type = "text", content = remainder })
      end
      break
    end

    -- Add text segment before fence if non-empty
    if fenceStart > cursor then
      local preText = string.sub(text, cursor, fenceStart - 1)
      if string.match(preText, "%S") then
        table.insert(segments, { type = "text", content = preText })
      end
    end

    -- Look for newline after language tag
    local langStart = fenceStart + 3
    local lineBreak = string.find(text, "\n", langStart, true)
    local lang = "text"
    local codeStart = langStart

    if lineBreak then
      local extractedLang = string.sub(text, langStart, lineBreak - 1)
      extractedLang = string.gsub(extractedLang, "^%s+", "")
      extractedLang = string.gsub(extractedLang, "%s+$", "")
      if extractedLang ~= "" then
        lang = extractedLang
      end
      codeStart = lineBreak + 1
    end

    -- Look for closing fence
    local fenceEnd = string.find(text, "```", codeStart, true)
    if fenceEnd then
      local code = string.sub(text, codeStart, fenceEnd - 1)
      table.insert(segments, {
        type = "code",
        language = lang,
        code = code,
      })
      cursor = fenceEnd + 3
    else
      -- Unclosed code block (e.g. streaming in progress)
      local unclosedCode = string.sub(text, codeStart)
      table.insert(segments, {
        type = "code",
        language = lang,
        code = unclosedCode,
      })
      break
    end
  end

  return segments
end

return markdown
