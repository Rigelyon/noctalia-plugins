--!strict
local prompts = {}

export type PromptTemplate = {
  tag: string,
  label: string,
  description: string,
  content: string,
}

local function getDataDir(): string
  local dir = noctalia.pluginDataDir()
  if dir then
    noctalia.mkdirAll(dir)
    return dir
  end
  local fallback = noctalia.expandPath("~/.local/share/noctalia/ai-sidebar")
  noctalia.mkdirAll(fallback)
  return fallback
end

local function promptsFilePath(): string
  return getDataDir() .. "/prompts.json"
end

function prompts.getDefaults(): { PromptTemplate }
  return {
    {
      tag = "explain",
      label = "Explain Code or Concept",
      description = "Break down complex code or concepts step-by-step",
      content = "Please explain the following code or concept step-by-step:\n\n",
    },
    {
      tag = "code-review",
      label = "Review & Optimize",
      description = "Inspect code for bugs, edge cases, and performance",
      content = "Please review the following code for bugs, edge cases, and performance optimizations:\n\n",
    },
    {
      tag = "summarize",
      label = "Summarize Key Points",
      description = "Extract key takeaways and action items concisely",
      content = "Summarize the key takeaways and actionable points from the text below:\n\n",
    },
    {
      tag = "fix-grammar",
      label = "Fix Grammar & Tone",
      description = "Enhance clarity, spelling, and professional tone",
      content = "Please fix grammar, spelling, and enhance clarity and professional tone:\n\n",
    },
    {
      tag = "translate",
      label = "Translate Language",
      description = "Translate text accurately into a target language",
      content = "Please translate the following text into [target]:\n\n",
    },
    {
      tag = "write-test",
      label = "Generate Unit Tests",
      description = "Create unit tests covering edge cases and paths",
      content = "Generate comprehensive unit tests covering happy paths and edge cases for:\n\n",
    },
  }
end

local cachedPrompts: { PromptTemplate }? = nil
local lastFileError: string? = nil

export type PromptStatus = {
  ok: boolean,
  error: string?,
  count: number,
  path: string,
}

function prompts.getFilePath(): string
  return promptsFilePath()
end

function prompts.openInEditor(): boolean
  local path = promptsFilePath()
  local raw = noctalia.readFile(path)
  if not raw or noctalia.string.trim(raw) == "" then
    local defaults = prompts.getDefaults()
    prompts.save(defaults)
  end

  local ok, res = pcall(function()
    return noctalia.runAsync({ "xdg-open", path })
  end)
  return ok and (res ~= false)
end

function prompts.getStatus(): PromptStatus
  local list = prompts.load()
  return {
    ok = (lastFileError == nil),
    error = lastFileError,
    count = #list,
    path = promptsFilePath(),
  }
end

function prompts.load(): { PromptTemplate }
  local path = promptsFilePath()
  local raw = noctalia.readFile(path)
  if raw == nil then
    -- File does not exist yet: write defaults
    local defaults = prompts.getDefaults()
    prompts.save(defaults)
    cachedPrompts = defaults
    lastFileError = nil
    return defaults
  end

  local trimmed = noctalia.string.trim(raw)
  if trimmed == "" then
    lastFileError = "prompts.json is empty"
    if cachedPrompts and #cachedPrompts > 0 then
      return cachedPrompts
    end
    return prompts.getDefaults()
  end

  local decodeOk, decoded = pcall(function()
    local res, err = noctalia.json.decode(trimmed)
    if err then error(err) end
    return res
  end)

  if not decodeOk or type(decoded) ~= "table" then
    local errMsg = if not decodeOk then tostring(decoded) else "Root JSON element must be an array"
    lastFileError = "Syntax error in prompts.json: " .. errMsg
    noctalia.log("AI Sidebar: " .. tostring(lastFileError))
    -- CRITICAL SAFETY: Do NOT overwrite the file! Preserve user content and fall back to memory
    if cachedPrompts and #cachedPrompts > 0 then
      return cachedPrompts
    end
    return prompts.getDefaults()
  end

  local list: { PromptTemplate } = {}
  local malformedCount = 0
  for idx, item in ipairs(decoded) do
    if type(item) == "table" then
      local rawTag = item.tag
      local rawContent = item.content
      local tag = if type(rawTag) == "string" and noctalia.string.trim(rawTag) ~= ""
        then noctalia.string.trim(rawTag):gsub("^#+", "")
        else nil
      local content = if type(rawContent) == "string" and noctalia.string.trim(rawContent) ~= ""
        then rawContent
        else nil
      local label = if type(item.label) == "string" and noctalia.string.trim(item.label) ~= ""
        then noctalia.string.trim(item.label)
        else (tag or "Prompt " .. tostring(idx))
      local desc = if type(item.description) == "string"
        then item.description
        else ""

      if tag and content then
        table.insert(list, {
          tag = tag,
          label = label,
          description = desc,
          content = content,
        })
      else
        malformedCount += 1
      end
    else
      malformedCount += 1
    end
  end

  if malformedCount > 0 then
    lastFileError = string.format("%d prompt item(s) skipped (missing required 'tag' or 'content')", malformedCount)
  else
    lastFileError = nil
  end

  if #list == 0 then
    lastFileError = "No valid prompt templates found in prompts.json"
    if cachedPrompts and #cachedPrompts > 0 then
      return cachedPrompts
    end
    return prompts.getDefaults()
  end

  cachedPrompts = list
  return list
end

function prompts.save(templates: { PromptTemplate }): boolean
  local path = promptsFilePath()
  local encoded, _ = noctalia.json.encode(templates, true)
  if encoded then
    local ok, _ = noctalia.writeFile(path, encoded)
    if ok then
      cachedPrompts = templates
      lastFileError = nil
    end
    return ok
  end
  return false
end

function prompts.filter(query: string, templates: { PromptTemplate }?): { PromptTemplate }
  local list = templates or prompts.load()
  local q = noctalia.string.trim(query):lower()
  if q == "" then
    local res: { PromptTemplate } = {}
    for i = 1, math.min(#list, 5) do
      table.insert(res, list[i])
    end
    return res
  end

  local matches: { PromptTemplate } = {}
  for _, t in ipairs(list) do
    if t.tag:lower():find(q, 1, true) or t.label:lower():find(q, 1, true) or t.description:lower():find(q, 1, true) then
      table.insert(matches, t)
      if #matches >= 5 then
        break
      end
    end
  end
  return matches
end

return prompts
