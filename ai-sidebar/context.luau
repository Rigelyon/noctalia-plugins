--!strict
local context = {}

export type Message = {
  role: string,
  content: string,
  timestamp: number?,
}

function context.estimateTokens(text: string?): number
  if not text or text == "" then
    return 0
  end
  local len = string.len(text)
  return math.max(1, math.ceil(len / 4))
end

function context.estimateMessageTokens(msg: Message): number
  return context.estimateTokens(msg.content) + 4
end

function context.estimateTotalTokens(messages: { Message }): number
  local total = 0
  for _, msg in ipairs(messages) do
    total += context.estimateMessageTokens(msg)
  end
  return total
end

-- Compacts intermediate message turns into a single summary line
local function summarizeTurn(msg: Message): string
  local roleTag = (msg.role == "user") and "User" or "AI"
  local cleaned = msg.content:gsub("\n+", " "):gsub("%s+", " ")
  if string.len(cleaned) > 100 then
    cleaned = string.sub(cleaned, 1, 97) .. "..."
  end
  return roleTag .. ": " .. cleaned
end

-- Prepares conversation context with anchor turn preservation and rolling condensation
function context.prepareContext(
  messages: { Message },
  maxTokens: number,
  systemPrompt: string?
): { Message }
  if #messages == 0 then
    return {}
  end

  local budget = maxTokens or 4096
  local sysTokens = systemPrompt and (context.estimateTokens(systemPrompt) + 4) or 0
  local availableBudget = budget - sysTokens

  -- If total messages easily fit into budget, return shallow copy
  local currentTotal = context.estimateTotalTokens(messages)
  if currentTotal <= availableBudget or #messages <= 2 then
    local copy = {}
    for _, m in ipairs(messages) do
      table.insert(copy, { role = m.role, content = m.content })
    end
    return copy
  end

  -- Anchor turn: preserve the original user prompt
  local anchor = messages[1]
  local anchorTokens = context.estimateMessageTokens(anchor)
  local remainingBudget = availableBudget - anchorTokens - 250 -- reserve 250 tokens for recap note

  -- Select active recent window from tail backwards
  local recentReversed = {}
  local recentTokens = 0
  local cutIndex = #messages

  for i = #messages, 2, -1 do
    local msgTokens = context.estimateMessageTokens(messages[i])
    if recentTokens + msgTokens > remainingBudget and #recentReversed >= 2 then
      cutIndex = i
      break
    end
    recentTokens += msgTokens
    table.insert(recentReversed, messages[i])
    cutIndex = i - 1
  end

  -- Re-reverse recent messages
  local recent = {}
  for i = #recentReversed, 1, -1 do
    table.insert(recent, recentReversed[i])
  end

  -- If no intermediate messages were skipped, return directly
  if cutIndex < 2 then
    local result = { { role = anchor.role, content = anchor.content } }
    for _, m in ipairs(recent) do
      table.insert(result, { role = m.role, content = m.content })
    end
    return result
  end

  -- Summarize skipped middle turns
  local summaryLines = {}
  for i = 2, cutIndex do
    table.insert(summaryLines, summarizeTurn(messages[i]))
  end

  local recapText = "[Previous discussion context:\n" .. table.concat(summaryLines, "\n") .. "\n]"
  local recapMsg = {
    role = "system",
    content = recapText,
  }

  local finalMessages = {}
  table.insert(finalMessages, { role = anchor.role, content = anchor.content })
  table.insert(finalMessages, recapMsg)
  for _, m in ipairs(recent) do
    table.insert(finalMessages, { role = m.role, content = m.content })
  end

  return finalMessages
end

return context
