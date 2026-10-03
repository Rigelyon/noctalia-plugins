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

function prompts.load(): { PromptTemplate }
  local path = promptsFilePath()
  local raw, _ = noctalia.readFile(path)
  if not raw or noctalia.string.trim(raw) == "" then
    local defaults = prompts.getDefaults()
    prompts.save(defaults)
    return defaults
  end

  local decoded, err = noctalia.json.decode(raw)
  if err or type(decoded) ~= "table" then
    local defaults = prompts.getDefaults()
    prompts.save(defaults)
    return defaults
  end

  local list: { PromptTemplate } = {}
  for _, item in ipairs(decoded) do
    if type(item) == "table" and type(item.tag) == "string" and type(item.content) == "string" then
      table.insert(list, {
        tag = item.tag,
        label = type(item.label) == "string" and item.label or item.tag,
        description = type(item.description) == "string" and item.description or "",
        content = item.content,
      })
    end
  end

  if #list == 0 then
    local defaults = prompts.getDefaults()
    prompts.save(defaults)
    return defaults
  end

  return list
end

function prompts.save(templates: { PromptTemplate }): boolean
  local path = promptsFilePath()
  local encoded, _ = noctalia.json.encode(templates, true)
  if encoded then
    local ok, _ = noctalia.writeFile(path, encoded)
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
