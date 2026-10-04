--!nonstrict
-- AI Sidebar panel implementation with streaming chat, session history, and provider settings.

local storage = require("./storage.luau")
local client = require("./client.luau")
local markdown = require("./markdown.luau")
local export = require("./export.luau")
local prompts = require("./prompts.luau")
local context = require("./context.luau")
local search = require("./search.luau")

local activeTab = "chat" -- "chat" | "history" | "setting"
local sessions = {}
local currentSession = nil
local config = nil

local inputBuffer = ""
local inputRev = 0
local settingRev = 0
local scrollRev = 0
local historySearch = ""
local isStreaming = false
local isSearching = false
local streamHandle = nil
local lastRenderMs = 0
local retryStatus = nil
local copiedCodeKey = nil

-- UI transient states
local pendingDeleteSessionId = nil
local pendingClear = false
local testConnStatus = nil -- nil | "testing" | "success" | "error: <msg>"
local showApiKey = false
local showSearchApiKey = false
local startFreshOnOpen = false
local showPromptPicker = false
local hoveredPromptTag: string? = nil
local hoveredSlashCmd: string? = nil
local saveSuccess = false

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- ── Streaming Actions ─────────────────────────────────────────────────────────

local function stopStreaming()
  if streamHandle ~= nil then
    streamHandle.stop()
    streamHandle = nil
  end
  isStreaming = false
  isSearching = false
  retryStatus = nil
  if currentSession and #currentSession.messages > 0 then
    storage.saveSessions(sessions)
  end
  render()
end

local function sendMessage()
  local text = noctalia.string.trim(inputBuffer)
  if text == "" or isStreaming then return end

  local isSearch, strippedText = search.isSlashSearch(text)
  local messageText = text
  if isSearch then
    if strippedText == "" then
      messageText = tr("slash_search_default_prompt")
    else
      messageText = strippedText
    end
  end

  if not currentSession then
    currentSession = storage.createSession(messageText, config.active_provider, config[config.active_provider .. "_model"])
    table.insert(sessions, 1, currentSession)
  else
    local exists = false
    for _, s in ipairs(sessions) do
      if s.id == currentSession.id then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(sessions, 1, currentSession)
    end
  end

  -- Add user message
  table.insert(currentSession.messages, {
    role = "user",
    content = messageText,
    timestamp = math.floor(noctalia.nowMs() / 1000),
    is_search = if isSearch then true else nil,
  })

  startFreshOnOpen = false

  -- Set session title from first message if default
  if currentSession.title == "New Conversation" then
    currentSession.title = storage.generateTitle(messageText)
  end
  currentSession.updated_at = math.floor(noctalia.nowMs() / 1000)
  table.sort(sessions, function(a, b) return a.updated_at > b.updated_at end)

  local capped = storage.capMessages(currentSession.messages)
  capped = table.clone(capped)

  -- Create placeholder for assistant response
  table.insert(currentSession.messages, {
    role = "assistant",
    content = "",
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  inputBuffer = ""
  inputRev += 1
  scrollRev += 1
  isStreaming = true
  retryStatus = nil
  lastRenderMs = noctalia.nowMs()
  local streamStartMs = noctalia.nowMs()
  local assistantMsg = currentSession.messages[#currentSession.messages]

  local function beginStream(searchCtx: string?, isSlashSearch: boolean?)
    if not isStreaming then return end
    isSearching = false
    lastRenderMs = noctalia.nowMs()
    render()

    streamHandle = client.streamChat(
      capped,
      config,
      function(chunk: string)
        retryStatus = nil
      assistantMsg.content = assistantMsg.content .. chunk
      local now = noctalia.nowMs()
      -- Throttled UI update (>= 80ms) for CPU budget compliance
      if now - lastRenderMs >= 80 then
        lastRenderMs = now
        scrollRev += 1
        render()
      end
      end,
      function(err: string)
        if not isStreaming then return end
      isStreaming = false
      streamHandle = nil
      retryStatus = nil
      assistantMsg.content = assistantMsg.content .. "\n\n**[" .. tr("error_title") .. ": " .. err .. "]**"
      storage.saveSessions(sessions)
      scrollRev += 1
      render()
      end,
      function()
        isStreaming = false
      streamHandle = nil
      retryStatus = nil

      -- Compute telemetry metrics
      local durationMs = math.max(100, noctalia.nowMs() - streamStartMs)
      local tokens = context.estimateTokens(assistantMsg.content)
      local durationSec = durationMs / 1000
      local tokensPerSec = math.round((tokens / durationSec) * 10) / 10
      assistantMsg.metrics = {
        tokens = tokens,
        durationMs = durationMs,
        tokensPerSec = tokensPerSec,
      }

      storage.saveSessions(sessions)
      scrollRev += 1
      render()

      -- Background auto-titler trigger on Turn 1 completion
      if currentSession and #currentSession.messages == 2 then
        local capturedSessionId = currentSession.id
        client.generateTitle(text, assistantMsg.content, config, function(autoTitle)
          if currentSession and currentSession.id == capturedSessionId then
            currentSession.title = autoTitle
            storage.saveSessions(sessions)
            render()
          else
            for _, s in ipairs(sessions) do
              if s.id == capturedSessionId then
                s.title = autoTitle
                storage.saveSessions(sessions)
                break
              end
            end
          end
        end)
      end
    end,
      function(status: string, attempt: number, maxRetries: number)
        if status == "retrying" then
          retryStatus = tr("status_retrying", { attempt = tostring(attempt), max = tostring(maxRetries) })
          render()
        end
      end,
      searchCtx,
      isSlashSearch
    )
  end

  if isSearch then
    isSearching = true
    render()
    local searchCompleted = false
    local function finishSearch(ctx: string?)
      if searchCompleted then return end
      searchCompleted = true
      beginStream(ctx, true)
    end

    pcall(function()
      local ran = noctalia.runAsync({ "sleep", "6" }, function()
        finishSearch(nil)
      end)
      if not ran then
        noctalia.runAsync("sleep 6", function()
          finishSearch(nil)
        end)
      end
    end)

    client.prepareContextualSearch(messageText, capped, config, function(searchCtx)
      finishSearch(searchCtx)
    end, true)
  else
    beginStream(nil, false)
  end
end

local function regenerateResponse()
  if isStreaming or not currentSession or #currentSession.messages == 0 then return end
  local removed = storage.removeLastAssistantMessage(sessions, currentSession.id)
  if not removed then return end
  if #currentSession.messages == 0 then return end
  local lastUserMsg = currentSession.messages[#currentSession.messages]
  if lastUserMsg.role ~= "user" then return end

  currentSession.updated_at = math.floor(noctalia.nowMs() / 1000)
  table.sort(sessions, function(a, b) return a.updated_at > b.updated_at end)

  local capped = storage.capMessages(currentSession.messages)
  capped = table.clone(capped)

  table.insert(currentSession.messages, {
    role = "assistant",
    content = "",
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  scrollRev += 1
  isStreaming = true
  retryStatus = nil
  lastRenderMs = noctalia.nowMs()
  local streamStartMs = noctalia.nowMs()
  local assistantMsg = currentSession.messages[#currentSession.messages]

  local function beginStream(searchCtx: string?, isSlashSearch: boolean?)
    if not isStreaming then return end
    isSearching = false
    lastRenderMs = noctalia.nowMs()
    render()

    streamHandle = client.streamChat(
      capped,
      config,
      function(chunk: string)
        retryStatus = nil
        assistantMsg.content = assistantMsg.content .. chunk
        local now = noctalia.nowMs()
        if now - lastRenderMs >= 80 then
          lastRenderMs = now
          scrollRev += 1
          render()
        end
      end,
      function(err: string)
        if not isStreaming then return end
        isStreaming = false
        streamHandle = nil
        retryStatus = nil
        assistantMsg.content = assistantMsg.content .. "\n\n**[" .. tr("error_title") .. ": " .. err .. "]**"
        storage.saveSessions(sessions)
        scrollRev += 1
        render()
      end,
      function()
        isStreaming = false
        streamHandle = nil
        retryStatus = nil

        local durationMs = math.max(100, noctalia.nowMs() - streamStartMs)
        local tokens = context.estimateTokens(assistantMsg.content)
        local durationSec = durationMs / 1000
        local tokensPerSec = math.round((tokens / durationSec) * 10) / 10
        assistantMsg.metrics = {
          tokens = tokens,
          durationMs = durationMs,
          tokensPerSec = tokensPerSec,
        }

        storage.saveSessions(sessions)
        scrollRev += 1
        render()
      end,
      function(status: string, attempt: number, maxRetries: number)
        if status == "retrying" then
          retryStatus = tr("status_retrying", { attempt = tostring(attempt), max = tostring(maxRetries) })
          render()
        end
      end,
      searchCtx,
      isSlashSearch
    )
  end

  local isSearch = (lastUserMsg.is_search == true) or select(1, search.isSlashSearch(lastUserMsg.content))
  if isSearch then
    isSearching = true
    render()
    local searchCompleted = false
    local function finishSearch(ctx: string?)
      if searchCompleted then return end
      searchCompleted = true
      beginStream(ctx, true)
    end

    pcall(function()
      local ran = noctalia.runAsync({ "sleep", "6" }, function()
        finishSearch(nil)
      end)
      if not ran then
        noctalia.runAsync("sleep 6", function()
          finishSearch(nil)
        end)
      end
    end)

    client.prepareContextualSearch(lastUserMsg.content, capped, config, function(searchCtx)
      finishSearch(searchCtx)
    end, true)
  else
    beginStream(nil, false)
  end
end

local function renderAssistantContent(content: string, msgIndex: number): { any }
  local segments = markdown.parseSegments(content)
  local nodes = {}
  for segIdx, seg in ipairs(segments) do
    if seg.type == "code" then
      local codeKey = tostring(msgIndex) .. "_" .. tostring(segIdx)
      local isCopied = (copiedCodeKey == codeKey)
      local langLabel = (seg.language and seg.language ~= "") and seg.language or "text"
      local codeText = seg.code or ""
      local cleanCode = codeText:gsub("%s+$", "")

      table.insert(nodes, ui.column({
        fill = "surface_variant/0.3",
        radius = 8,
        padding = 8,
        paddingH = 12,
        gap = 4,
      }, {
        ui.row({ align = "center", justify = "space_between" }, {
          ui.label({
            text = langLabel,
            fontSize = 10,
            color = "primary",
            fontWeight = "bold",
          }),
          ui.button({
            glyph = isCopied and "check" or "copy",
            variant = "ghost",
            padding = 2,
            paddingH = 4,
            tooltip = isCopied and tr("code_copied") or tr("action_copy_code"),
            onClick = function()
              if codeText ~= "" then
                noctalia.copyToClipboard(codeText, "text/plain")
                copiedCodeKey = codeKey
                render()
                noctalia.runAsync({ "sleep", "2" }, function()
                  if copiedCodeKey == codeKey then
                    copiedCodeKey = nil
                    render()
                  end
                end)
              end
            end,
          }),
        }),
        ui.markdown({ text = "```" .. langLabel .. "\n" .. cleanCode .. "\n```" }),
        ui.spacer({ height = 12 }),
      }))
    else
      if seg.content and seg.content ~= "" then
        table.insert(nodes, ui.markdown({ text = seg.content }))
      end
    end
  end
  if #nodes == 0 then
    table.insert(nodes, ui.markdown({ text = content }))
  end
  return nodes
end

local function renderChatView()
  local messageNodes = {}

  if not currentSession or #currentSession.messages == 0 then
    table.insert(messageNodes, ui.column({
      align = "center",
      justify = "center",
      gap = 12,
      padding = 32,
      flexGrow = 1,
    }, {
      ui.glyph({ name = "sparkles", size = 48, color = "primary" }),
      ui.label({ text = tr("welcome_title"), fontSize = 16, fontWeight = "bold" }),
      ui.label({
        text = tr("welcome_subtitle"),
        fontSize = 12,
        color = "on_surface_variant",
      }),
    }))
  else
    for idx, msg in ipairs(currentSession.messages) do
      if msg.role == "user" then
        local timeStr = msg.timestamp and noctalia.formatTime("%H:%M", msg.timestamp) or ""
        local hasNewline = msg.content:find("\n") ~= nil
        local hasMarkdown = msg.content:find("[%*_`~]") ~= nil
        local isLong = (#msg.content > 32) or hasNewline or hasMarkdown

        local contentNode
        if not isLong then
          contentNode = ui.label({ text = msg.content })
        else
          contentNode = ui.markdown({ text = msg.content })
        end

        local userActionButtons = {}
        table.insert(userActionButtons, ui.button({
          glyph = "pencil",
          variant = "ghost",
          tooltip = tr("action_edit"),
          onClick = function()
            if not isStreaming then
              inputBuffer = msg.content
              inputRev += 1
              storage.rewindSession(sessions, currentSession.id, idx - 1)
              render()
            end
          end,
        }))
        table.insert(userActionButtons, ui.button({
          glyph = "arrow-back-up",
          variant = "ghost",
          tooltip = tr("action_rewind"),
          onClick = function()
            if not isStreaming then
              storage.rewindSession(sessions, currentSession.id, idx)
              render()
            end
          end,
        }))

        local bubbleNode = ui.column({
          fill = "primary/0.2",
          radius = 12,
          padding = 8,
          paddingH = 12,
          gap = 6,
          minWidth = 110,
          flexGrow = if isLong then 4 else nil,
        }, {
          ui.row({ gap = 6, align = "center", justify = "space_between" }, {
            ui.row({ gap = 6, align = "center" }, {
              ui.glyph({ name = "user", size = 13, color = "primary" }),
              ui.label({
                text = tr("role_user"),
                fontSize = 11,
                fontWeight = "bold",
                color = "primary",
              }),
              ui.label({
                text = "·  " .. timeStr,
                fontSize = 10,
                color = "on_surface_variant",
              }),
            }),
            ui.row({ gap = 2, align = "center" }, userActionButtons),
          }),
          contentNode,
        })

        if isLong then
          table.insert(messageNodes, ui.row({ align = "start" }, {
            ui.spacer({ flexGrow = 1 }),
            bubbleNode,
          }))
        else
          table.insert(messageNodes, ui.row({ justify = "end", align = "start" }, {
            bubbleNode,
          }))
        end
      elseif msg.role == "assistant" then
        local content = msg.content
        if content == "" and isStreaming then
          if isSearching then
            content = "_" .. tr("status_searching_web") .. "_"
          else
            content = "_" .. tr("status_typing") .. "_"
          end
        end
        local timeStr = msg.timestamp and noctalia.formatTime("%H:%M", msg.timestamp) or ""
        local isLastAssistant = (idx == #currentSession.messages)

        local actionButtons = {}
        if isLastAssistant and not isStreaming and content ~= "" and not content:find(tr("error_title")) then
          table.insert(actionButtons, ui.button({
            glyph = "refresh",
            variant = "ghost",
            tooltip = tr("action_regenerate"),
            onClick = regenerateResponse,
          }))
        end
        table.insert(actionButtons, ui.button({
          glyph = "copy",
          variant = "ghost",
          tooltip = tr("copy"),
          onClick = function()
            if content ~= "" then
              noctalia.copyToClipboard(msg.content, "text/plain")
              noctalia.notify(tr("copied_to_clipboard"), "sparkles")
            end
          end,
        }))
        table.insert(actionButtons, ui.button({
          glyph = "arrow-back-up",
          variant = "ghost",
          tooltip = tr("action_rewind"),
          onClick = function()
            if not isStreaming then
              storage.rewindSession(sessions, currentSession.id, idx)
              render()
            end
          end,
        }))

        local assistantChildren = {
          ui.row({ gap = 6, align = "center", justify = "space_between" }, {
            ui.row({ gap = 6, align = "center" }, {
              ui.glyph({ name = "sparkles", size = 13, color = "primary" }),
              ui.label({
                text = tr("role_assistant"),
                fontSize = 11,
                fontWeight = "bold",
                color = "primary",
              }),
              ui.label({
                text = "·  " .. timeStr,
                fontSize = 10,
                color = "on_surface_variant",
              }),
            }),
            ui.row({ gap = 2, align = "center" }, actionButtons),
          }),
        }

        for _, cNode in ipairs(renderAssistantContent(content, idx)) do
          table.insert(assistantChildren, cNode)
        end

        if retryStatus and isStreaming and isLastAssistant then
          table.insert(assistantChildren, ui.row({ align = "center", gap = 6 }, {
            ui.glyph({ name = "loader-2", size = 12, color = "secondary" }),
            ui.label({ text = retryStatus, fontSize = 10, color = "secondary" }),
          }))
        end

        if msg.metrics and msg.metrics.tokens and msg.metrics.durationMs and msg.metrics.tokensPerSec then
          local metricStr = string.format("~%d tokens · %.1fs · %.1f tok/s", msg.metrics.tokens, msg.metrics.durationMs / 1000, msg.metrics.tokensPerSec)
          table.insert(assistantChildren, ui.row({ justify = "end", align = "center" }, {
            ui.label({
              text = metricStr,
              fontSize = 10,
              color = "outline",
            }),
          }))
        end

        table.insert(messageNodes, ui.row({ justify = "start", align = "start" }, {
          ui.column({
            fill = "surface_variant/0.25",
            radius = 12,
            padding = 8,
            paddingH = 12,
            flexGrow = 1,
            gap = 6,
          }, assistantChildren),
        }))
      end
    end
  end

  local actionButtons = {}
  if isStreaming then
    table.insert(actionButtons, ui.button({
      glyph = "player-stop",
      variant = "primary",
      text = tr("stop"),
      onClick = stopStreaming,
    }))
  else
    if pendingClear then
      table.insert(actionButtons, ui.label({ text = tr("clear_confirm"), color = "error" }))
      table.insert(actionButtons, ui.button({
        glyph = "check",
        variant = "primary",
        onClick = function()
          if currentSession then
            local updated = {}
            for _, s in ipairs(sessions) do
              if s.id ~= currentSession.id then
                table.insert(updated, s)
              end
            end
            sessions = updated
            currentSession.messages = {}
            storage.saveSessions(sessions)
          end
          startFreshOnOpen = true
          inputBuffer = ""
          inputRev += 1
          pendingClear = false
          render()
        end,
      }))
      table.insert(actionButtons, ui.button({
        glyph = "x",
        variant = "ghost",
        onClick = function()
          pendingClear = false
          render()
        end,
      }))
    else
      table.insert(actionButtons, ui.button({
        glyph = "hash",
        variant = showPromptPicker and "primary" or "ghost",
        tooltip = tr("prompt_library"),
        onClick = function()
          showPromptPicker = not showPromptPicker
          render()
        end,
      }))
      table.insert(actionButtons, ui.button({
        glyph = "eraser",
        variant = "ghost",
        tooltip = tr("clear"),
        onClick = function()
          pendingClear = true
          render()
        end,
      }))
      table.insert(actionButtons, ui.button({
        glyph = "send",
        variant = "primary",
        text = tr("send"),
        onClick = sendMessage,
      }))
    end
  end

  local hashQuery = inputBuffer:match("^#([%w%-_]*)$") or inputBuffer:match("%s#([%w%-_]*)$")
  local isPromptActive = showPromptPicker or (hashQuery ~= nil)
  local matchingPrompts = isPromptActive and prompts.filter(hashQuery or "") or {}

  local promptNodes = {}
  if isPromptActive and #matchingPrompts > 0 then
    table.insert(promptNodes, ui.row({
      align = "center",
      justify = "space_between",
      paddingH = 6,
      padding = 2,
      onHover = function(state)
        if (state == "true" or state == true) and hoveredPromptTag ~= nil then
          hoveredPromptTag = nil
          render()
        end
      end,
    }, {
      ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = "sparkles", size = 11, color = "primary" }),
        ui.label({ text = tr("prompt_library"), fontSize = 10, fontWeight = "bold", color = "primary" }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("close"),
        onClick = function()
          showPromptPicker = false
          hoveredPromptTag = nil
          render()
        end,
      }),
    }))
    table.insert(promptNodes, ui.separator({}))

    for _, p in ipairs(matchingPrompts) do
      local isHovered = hoveredPromptTag == p.tag
      table.insert(promptNodes, ui.row({
        key = "prompt-" .. p.tag,
        align = "center",
        justify = "start",
        gap = 6,
        padding = 3,
        paddingH = 6,
        radius = 4,
        fill = isHovered and "surface_variant" or "surface_variant/0",
        onHover = function(state)
          if state == "true" or state == true then
            if hoveredPromptTag ~= p.tag then
              hoveredPromptTag = p.tag
              render()
            end
          else
            if hoveredPromptTag == p.tag then
              hoveredPromptTag = nil
              render()
            end
          end
        end,
        onClick = function()
          if hashQuery ~= nil then
            local pattern = "(#[" .. "%w%-_" .. "]*)$"
            inputBuffer = inputBuffer:gsub(pattern, p.content)
          else
            inputBuffer = inputBuffer .. p.content
          end
          showPromptPicker = false
          hoveredPromptTag = nil
          inputRev += 1
          render()
        end,
      }, {
        ui.glyph({ name = "hash", size = 11, color = "primary" }),
        ui.label({ text = p.tag, fontWeight = "bold", fontSize = 11, color = "primary" }),
        ui.label({ text = "—", fontSize = 10, color = "on_surface_variant" }),
        ui.label({ text = p.label, fontSize = 11, color = "on_surface", flexGrow = 1 }),
      }))
    end
  end

  local inputChildren = {}
  local slashQuery = inputBuffer:match("^/([%w%-_]*)$") or inputBuffer:match("%s/([%w%-_]*)$")
  local isSlashActive = (slashQuery ~= nil)
  local matchingSlashCommands = {}
  if isSlashActive then
    local sq = (slashQuery or ""):lower()
    local availableSlashCommands = {
      {
        cmd = "/search",
        label = tr("slash_cmd_search_label") ~= "slash_cmd_search_label" and tr("slash_cmd_search_label") or "Web Search",
        desc = tr("slash_cmd_search_desc") ~= "slash_cmd_search_desc" and tr("slash_cmd_search_desc") or "Cari informasi real-time di internet",
        glyph = "world",
      },
    }
    for _, sc in ipairs(availableSlashCommands) do
      if sc.cmd:sub(2):lower():find(sq, 1, true) then
        table.insert(matchingSlashCommands, sc)
      end
    end
  end

  local slashNodes = {}
  if isSlashActive and #matchingSlashCommands > 0 then
    table.insert(slashNodes, ui.row({
      align = "center",
      justify = "space_between",
      paddingH = 6,
      padding = 2,
      onHover = function(state)
        if (state == "true" or state == true) and hoveredSlashCmd ~= nil then
          hoveredSlashCmd = nil
          render()
        end
      end,
    }, {
      ui.row({ gap = 5, align = "center" }, {
        ui.glyph({ name = "terminal", size = 11, color = "primary" }),
        ui.label({ text = "Slash Commands", fontSize = 10, fontWeight = "bold", color = "primary" }),
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("close"),
        onClick = function()
          hoveredSlashCmd = nil
          inputBuffer = ""
          inputRev += 1
          render()
        end,
      }),
    }))
    table.insert(slashNodes, ui.separator({}))

    for _, sc in ipairs(matchingSlashCommands) do
      local isHovered = hoveredSlashCmd == sc.cmd
      table.insert(slashNodes, ui.row({
        key = "slash-" .. sc.cmd,
        align = "center",
        justify = "start",
        gap = 6,
        padding = 3,
        paddingH = 6,
        radius = 4,
        fill = isHovered and "surface_variant" or "surface_variant/0",
        onHover = function(state)
          if state == "true" or state == true then
            if hoveredSlashCmd ~= sc.cmd then
              hoveredSlashCmd = sc.cmd
              render()
            end
          else
            if hoveredSlashCmd == sc.cmd then
              hoveredSlashCmd = nil
              render()
            end
          end
        end,
        onClick = function()
          if slashQuery ~= nil then
            local pattern = "(/[" .. "%w%-_" .. "]*)$"
            inputBuffer = inputBuffer:gsub(pattern, sc.cmd .. " ")
          else
            inputBuffer = inputBuffer .. " " .. sc.cmd .. " "
          end
          hoveredSlashCmd = nil
          inputRev += 1
          render()
        end,
      }, {
        ui.glyph({ name = sc.glyph, size = 11, color = "primary" }),
        ui.label({ text = sc.cmd, fontWeight = "bold", fontSize = 11, color = "primary" }),
        ui.label({ text = "—", fontSize = 10, color = "on_surface_variant" }),
        ui.label({ text = sc.desc, fontSize = 11, color = "on_surface", flexGrow = 1 }),
      }))
    end
  end

  if #slashNodes > 0 then
    table.insert(inputChildren, ui.column({
      fill = "surface_variant/0.4",
      radius = 6,
      padding = 4,
      gap = 2,
      align = "stretch",
      onHover = function()
        if hoveredSlashCmd ~= nil then
          hoveredSlashCmd = nil
          render()
        end
      end,
    }, slashNodes))
  elseif #promptNodes > 0 then
    table.insert(inputChildren, ui.column({
      fill = "surface_variant/0.4",
      radius = 6,
      padding = 4,
      gap = 2,
      align = "stretch",
      -- Only the innermost hovered node reports, so the container only fires when the
      -- pointer is in its padding/gaps (enter) or has left it entirely (leave). In both
      -- cases no row is hovered.
      onHover = function()
        if hoveredPromptTag ~= nil then
          hoveredPromptTag = nil
          render()
        end
      end,
    }, promptNodes))
  end

  table.insert(inputChildren, ui.input({
    key = "chat-input-" .. inputRev,
    value = inputBuffer,
    placeholder = tr("input_placeholder"),
    multiline = true,
    submitOnEnter = true,
    focus = true,
    height = 70,
    onChange = function(val)
      local oldHash = (inputBuffer:match("^#([%w%-_]*)$") ~= nil) or (inputBuffer:match("%s#([%w%-_]*)$") ~= nil)
      local oldSlash = (inputBuffer:match("^/([%w%-_]*)$") ~= nil) or (inputBuffer:match("%s/([%w%-_]*)$") ~= nil)
      local wasActive = showPromptPicker or oldHash or oldSlash
      inputBuffer = val or ""
      local newHash = (inputBuffer:match("^#([%w%-_]*)$") ~= nil) or (inputBuffer:match("%s#([%w%-_]*)$") ~= nil)
      local newSlash = (inputBuffer:match("^/([%w%-_]*)$") ~= nil) or (inputBuffer:match("%s/([%w%-_]*)$") ~= nil)

      if oldHash and not newHash then
        showPromptPicker = false
        hoveredPromptTag = nil
      end
      if oldSlash and not newSlash then
        hoveredSlashCmd = nil
      end

      local isActive = showPromptPicker or newHash or newSlash
      if wasActive or isActive then
        render()
      end
    end,
    onSubmit = function()
      sendMessage()
    end,
  }))

  local statusText: string
  if isStreaming then
    if isSearching then
      statusText = tr("status_searching_web")
    else
      statusText = retryStatus or tr("status_typing")
    end
  else
    local msgs = (currentSession and currentSession.messages) or {}
    local totalTokens = context.estimateTotalTokens(msgs)
    local msgCount = #msgs
    local msgLabel = (msgCount == 1) and tr("metric_message_singular") or tr("metric_messages", { count = msgCount })
    statusText = string.format("~%d / %d tok · %s", totalTokens, context.BUDGET_TOKENS or 4096, msgLabel)
  end

  table.insert(inputChildren, ui.row({ align = "center", justify = "space_between" }, {
    ui.label({
      text = statusText,
      fontSize = 11,
      color = "on_surface_variant",
    }),
    ui.row({ gap = 4, align = "center" }, actionButtons),
  }))

  local inputRow = ui.column({ gap = 6, align = "stretch" }, inputChildren)

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    ui.scroll({
      flexGrow = 1,
      gap = 10,
      padding = 10,
      paddingH = 12,
      stickToBottom = true,
      scrollToBottomRev = scrollRev,
    }, messageNodes),
    ui.separator({}),
    inputRow,
  })
end

-- ── View: History ────────────────────────────────────────────────────────────

local function renderHistoryView()
  local searchBar = ui.input({
    value = historySearch,
    placeholder = tr("search_history"),
    onChange = function(val)
      historySearch = val
      render()
    end,
  })

  local rows = {}
  local queryLower = noctalia.string.trim(historySearch):lower()

  for _, sess in ipairs(sessions) do
    if #sess.messages > 0 then
      local matched = true
      if queryLower ~= "" then
        local tLower = sess.title:lower()
        if not tLower:find(queryLower, 1, true) then
          matched = false
        end
      end

      if matched then
      local itemActions = {}
      if pendingDeleteSessionId == sess.id then
        table.insert(itemActions, ui.button({
          glyph = "check",
          variant = "primary",
          onClick = function()
            sessions = storage.deleteSession(sess.id, sessions)
            if currentSession and currentSession.id == sess.id then
              currentSession = sessions[1] or nil
            end
            pendingDeleteSessionId = nil
            render()
          end,
        }))
        table.insert(itemActions, ui.button({
          glyph = "x",
          variant = "ghost",
          onClick = function()
            pendingDeleteSessionId = nil
            render()
          end,
        }))
      else
        table.insert(itemActions, ui.button({
          glyph = "trash",
          variant = "ghost",
          tooltip = tr("delete_session"),
          onClick = function()
            pendingDeleteSessionId = sess.id
            render()
          end,
        }))
      end

      local isCurrent = currentSession and (currentSession.id == sess.id)
      table.insert(rows, ui.row({
        align = "center",
        justify = "space_between",
        padding = 8,
        paddingH = 12,
        radius = 8,
        fill = isCurrent and "surface_variant" or "surface",
      }, {
        ui.column({
          flexGrow = 1,
          gap = 2,
          onClick = function()
            currentSession = sess
            startFreshOnOpen = false
            activeTab = "chat"
            render()
          end,
        }, {
          ui.label({ text = sess.title, fontWeight = isCurrent and "bold" or "normal", maxLines = 1 }),
          ui.label({
            text = noctalia.formatTime("%x %H:%M", sess.updated_at) .. "  ·  " .. tostring(#sess.messages) .. " msgs",
            fontSize = 11,
            color = "on_surface_variant",
          }),
        }),
        ui.row({ gap = 4, align = "center" }, itemActions),
      }))
      end
    end
  end

  local validCount = 0
  for _, sess in ipairs(sessions) do
    if #sess.messages > 0 then
      validCount += 1
    end
  end

  local countLabel: string
  if queryLower ~= "" then
    countLabel = tr("history_count_filtered", { shown = tostring(#rows), total = tostring(validCount) })
  else
    countLabel = tr("history_count", { count = tostring(validCount) })
  end

  local countRow = ui.row({ align = "center", justify = "space_between", paddingH = 4 }, {
    ui.label({ text = countLabel, fontSize = 11, color = "on_surface_variant" }),
  })

  if #rows == 0 then
    local emptyMsg = (queryLower == "") and tr("no_history") or tr("no_search_results")
    table.insert(rows, ui.label({ text = emptyMsg, color = "on_surface_variant" }))
  end

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    ui.button({
      glyph = "plus",
      text = tr("new_chat"),
      variant = "primary",
      onClick = function()
        currentSession = storage.createSession(nil, config.active_provider, config[config.active_provider .. "_model"])
        startFreshOnOpen = true
        inputBuffer = ""
        inputRev += 1
        activeTab = "chat"
        render()
      end,
    }),
    searchBar,
    countRow,
    ui.scroll({ flexGrow = 1, gap = 4 }, rows),
  })
end

-- ── View: Setting ────────────────────────────────────────────────────────────

local function renderSettingView()
  local providerOptions = {
    tr("provider_openai"),
    tr("provider_anthropic"),
    tr("provider_gemini"),
    tr("provider_custom"),
  }
  local providerIds = { "openai", "anthropic", "gemini", "custom" }
  local selectedProviderIndex = 0
  for i, pid in ipairs(providerIds) do
    if config.active_provider == pid then
      selectedProviderIndex = i - 1
      break
    end
  end

  local providerDropdown = ui.select({
    options = providerOptions,
    items = providerOptions,
    selectedIndex = selectedProviderIndex,
    onChange = function(val)
      local num = tonumber(val)
      local chosenId = nil
      if num ~= nil then
        local idx = num + 1
        chosenId = providerIds[idx]
      elseif type(val) == "string" then
        for i, pid in ipairs(providerIds) do
          if pid == val or providerOptions[i] == val then
            chosenId = pid
            break
          end
        end
      end
      if chosenId and chosenId ~= config.active_provider then
        config.active_provider = chosenId
        settingRev += 1
        testConnStatus = nil
        render()
      end
    end,
  })

  local activeSettings = {}
  if config.active_provider == "openai" then
    table.insert(activeSettings, ui.label({ text = tr("provider_openai") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-openai-key-" .. tostring(settingRev) .. "-" .. (showApiKey and "vis" or "hid"),
        value = config.openai_key,
        placeholder = "sk-...",
        password = not showApiKey,
        onChange = function(v) config.openai_key = v or "" end,
      }),
      ui.button({
        glyph = showApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showApiKey = not showApiKey
          render()
        end,
      }),
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_openai") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-openai-model-" .. tostring(settingRev),
      value = config.openai_model,
      placeholder = "gpt-4o-mini",
      onChange = function(v) config.openai_model = v or "" end,
    }))
  elseif config.active_provider == "anthropic" then
    table.insert(activeSettings, ui.label({ text = tr("provider_anthropic") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-anthropic-key-" .. tostring(settingRev) .. "-" .. (showApiKey and "vis" or "hid"),
        value = config.anthropic_key,
        placeholder = "sk-ant-...",
        password = not showApiKey,
        onChange = function(v) config.anthropic_key = v or "" end,
      }),
      ui.button({
        glyph = showApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showApiKey = not showApiKey
          render()
        end,
      }),
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_anthropic") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-anthropic-model-" .. tostring(settingRev),
      value = config.anthropic_model,
      placeholder = "claude-3-5-haiku-20241022",
      onChange = function(v) config.anthropic_model = v or "" end,
    }))
  elseif config.active_provider == "gemini" then
    table.insert(activeSettings, ui.label({ text = tr("provider_gemini") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-gemini-key-" .. tostring(settingRev) .. "-" .. (showApiKey and "vis" or "hid"),
        value = config.gemini_key,
        placeholder = "AIzaSy...",
        password = not showApiKey,
        onChange = function(v) config.gemini_key = v or "" end,
      }),
      ui.button({
        glyph = showApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showApiKey = not showApiKey
          render()
        end,
      }),
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_gemini") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-gemini-model-" .. tostring(settingRev),
      value = config.gemini_model,
      placeholder = "gemini-1.5-flash",
      onChange = function(v) config.gemini_model = v or "" end,
    }))
  elseif config.active_provider == "custom" then
    table.insert(activeSettings, ui.label({ text = tr("base_url"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-custom-url-" .. tostring(settingRev),
      value = config.custom_base_url,
      placeholder = "http://localhost:11434/v1",
      onChange = function(v) config.custom_base_url = v or "" end,
    }))
    table.insert(activeSettings, ui.label({ text = tr("api_key_optional"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-custom-key-" .. tostring(settingRev) .. "-" .. (showApiKey and "vis" or "hid"),
        value = config.custom_key,
        placeholder = "sk-...",
        password = not showApiKey,
        onChange = function(v) config.custom_key = v or "" end,
      }),
      ui.button({
        glyph = showApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showApiKey = not showApiKey
          render()
        end,
      }),
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_custom") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-custom-model-" .. tostring(settingRev),
      value = config.custom_model,
      placeholder = "llama3.2",
      onChange = function(v) config.custom_model = v or "" end,
    }))
  end

  local testConnBanner = nil
  if testConnStatus == "testing" then
    testConnBanner = ui.row({
      align = "center",
      gap = 8,
      padding = 8,
      paddingH = 12,
      radius = 8,
      fill = "surface_variant/0.5",
    }, {
      ui.glyph({ name = "rotate", size = 14, color = "on_surface_variant" }),
      ui.label({ text = tr("testing"), color = "on_surface_variant", fontSize = 12 }),
    })
  elseif testConnStatus == "success" then
    testConnBanner = ui.row({
      align = "center",
      gap = 8,
      padding = 8,
      paddingH = 12,
      radius = 8,
      fill = "primary/0.15",
    }, {
      ui.glyph({ name = "check", size = 14, color = "primary" }),
      ui.label({ text = tr("test_success"), color = "primary", fontSize = 12, fontWeight = "bold" }),
    })
  elseif type(testConnStatus) == "string" and testConnStatus:find("^error:") then
    local errMsg = testConnStatus:sub(8)
    testConnBanner = ui.column({
      gap = 4,
      padding = 10,
      paddingH = 12,
      radius = 8,
      fill = "error/0.15",
      align = "stretch",
    }, {
      ui.row({ align = "center", gap = 6 }, {
        ui.glyph({ name = "alert-triangle", size = 14, color = "error" }),
        ui.label({ text = tr("test_error"), color = "error", fontSize = 12, fontWeight = "bold" }),
      }),
      ui.label({
        text = errMsg,
        color = "error",
        fontSize = 11,
        multiline = true,
      }),
    })
  end

  local testConnButton = ui.button({
    glyph = "plug-connected",
    text = tr("test_connection"),
    variant = "ghost",
    onClick = function()
      testConnStatus = "testing"
      render()
      client.testConnection(config.active_provider, config, function(ok, msg)
        testConnStatus = ok and "success" or ("error: " .. msg)
        render()
      end)
    end,
  })

  local scrollItems = {
    ui.label({ text = tr("active_provider"), fontSize = 13, fontWeight = "bold" }),
    providerDropdown,
    ui.separator({}),
    ui.column({ gap = 8, align = "stretch" }, activeSettings),
    ui.separator({}),
    ui.label({ text = tr("system_prompt"), fontSize = 12, fontWeight = "bold" }),
    ui.input({
      key = "setting-system-prompt",
      value = config.system_prompt,
      multiline = true,
      height = 90,
      onChange = function(v) config.system_prompt = v or "" end,
    }),
    testConnButton,
  }

  if testConnBanner ~= nil then
    table.insert(scrollItems, testConnBanner)
  end

  local engineOptions = {
    tr("search_engine_ddg"),
    tr("search_engine_wikipedia"),
    tr("search_engine_gemini"),
    tr("search_engine_tavily"),
    tr("search_engine_brave"),
  }
  local engineIds = { "duckduckgo", "wikipedia", "gemini_native", "tavily", "brave" }
  local selectedEngineIndex = 0
  for i, eid in ipairs(engineIds) do
    if config.search_engine == eid then
      selectedEngineIndex = i - 1
      break
    end
  end

  local engineDropdown = ui.select({
    options = engineOptions,
    items = engineOptions,
    selectedIndex = selectedEngineIndex,
    onChange = function(val)
      local num = tonumber(val)
      local chosenId = nil
      if num ~= nil then
        local idx = num + 1
        chosenId = engineIds[idx]
      elseif type(val) == "string" then
        for i, eid in ipairs(engineIds) do
          if eid == val or engineOptions[i] == val then
            chosenId = eid
            break
          end
        end
      end
      if chosenId and chosenId ~= config.search_engine then
        config.search_engine = chosenId
        settingRev += 1
        render()
      end
    end,
  })

  local maxResultsOptions = {
    tr("search_results_3"),
    tr("search_results_5"),
    tr("search_results_7"),
  }
  local maxResultsValues = { 3, 5, 7 }
  local selectedMaxResultsIndex = 0
  for i, mval in ipairs(maxResultsValues) do
    if config.search_max_results == mval then
      selectedMaxResultsIndex = i - 1
      break
    end
  end

  local maxResultsDropdown = ui.select({
    options = maxResultsOptions,
    items = maxResultsOptions,
    selectedIndex = selectedMaxResultsIndex,
    onChange = function(val)
      local num = tonumber(val)
      local chosenVal = nil
      if num ~= nil then
        local idx = num + 1
        chosenVal = maxResultsValues[idx]
      elseif type(val) == "string" then
        for i, mval in ipairs(maxResultsValues) do
          if tostring(mval) == val or maxResultsOptions[i] == val then
            chosenVal = mval
            break
          end
        end
      end
      if chosenVal and chosenVal ~= config.search_max_results then
        config.search_max_results = chosenVal
        settingRev += 1
        render()
      end
    end,
  })

  table.insert(scrollItems, ui.separator({}))
  table.insert(scrollItems, ui.row({ gap = 8, align = "center" }, {
    ui.glyph({
      name = "world",
      size = 16,
      color = "primary",
    }),
    ui.column({ gap = 2 }, {
      ui.label({ text = tr("web_search_title") .. " (/search)", fontSize = 13, fontWeight = "bold" }),
      ui.label({
        text = tr("web_search_slash_hint") ~= "web_search_slash_hint" and tr("web_search_slash_hint") or "Type /search in chat for AI contextual search",
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
  }))

  local searchItems = {
    ui.label({ text = tr("search_engine"), fontSize = 12, fontWeight = "bold" }),
    engineDropdown,
  }
  if config.search_engine == "tavily" or config.search_engine == "brave" then
    table.insert(searchItems, ui.label({ text = tr("search_api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(searchItems, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-search-key-" .. tostring(settingRev) .. "-" .. (showSearchApiKey and "vis" or "hid"),
        value = config.search_api_key,
        placeholder = (config.search_engine == "tavily" and "tvly-..." or "BSAE..."),
        password = not showSearchApiKey,
        onChange = function(v) config.search_api_key = v or "" end,
      }),
      ui.button({
        glyph = showSearchApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showSearchApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showSearchApiKey = not showSearchApiKey
          render()
        end,
      }),
    }))
  end
  table.insert(searchItems, ui.label({ text = tr("search_max_results"), fontSize = 12, fontWeight = "bold" }))
  table.insert(searchItems, maxResultsDropdown)

  table.insert(scrollItems, ui.column({ gap = 8, align = "stretch" }, searchItems))

  table.insert(scrollItems, ui.separator({}))
  table.insert(scrollItems, ui.button({
    glyph = if saveSuccess then "check" else "device-floppy",
    text = if saveSuccess then tr("settings_saved") else tr("save_settings"),
    variant = if saveSuccess then "secondary" else "primary",
    onClick = function()
      local ok = storage.saveConfig(config, false)
      if ok then
        saveSuccess = true
        settingRev += 1
        render()
        pcall(function()
          local ran = noctalia.runAsync({ "sleep", "2" }, function()
            if saveSuccess then
              saveSuccess = false
              render()
            end
          end)
          if not ran then
            noctalia.runAsync("sleep 2", function()
              if saveSuccess then
                saveSuccess = false
                render()
              end
            end)
          end
        end)
      else
        noctalia.notifyError(tr("title"), tr("settings_save_error"))
      end
    end,
  }))
  table.insert(scrollItems, ui.button({
    glyph = "settings",
    text = tr("open_plugin_settings"),
    variant = "ghost",
    onClick = function()
      noctalia.openSettings()
    end,
  }))

  return ui.scroll({ flexGrow = 1, gap = 12, padding = 4 }, scrollItems)
end

-- ── Render Root ──────────────────────────────────────────────────────────────

render = function()
  local titleRow = ui.row({ align = "center", justify = "space_between" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "sparkles", size = 18, color = "primary" }),
      ui.label({ text = tr("title"), fontWeight = "bold" }),
    }),
    ui.row({ gap = 4, align = "center" }, {
      ui.button({
        glyph = "download",
        variant = "ghost",
        tooltip = tr("export_chat"),
        onClick = function()
          if currentSession and #currentSession.messages > 0 then
            export.saveSession(currentSession)
          else
            noctalia.notify(tr("export_empty_title"), tr("export_empty_body"))
          end
        end,
      }),
      ui.button({
        glyph = "plus",
        variant = "ghost",
        tooltip = tr("new_chat"),
        onClick = function()
          currentSession = storage.createSession(nil, config.active_provider, config[config.active_provider .. "_model"])
          startFreshOnOpen = true
          inputBuffer = ""
          inputRev += 1
          activeTab = "chat"
          render()
        end,
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("close"),
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })

  local tabBar = ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = tr("tab_chat"),
      variant = activeTab == "chat" and "primary" or "ghost",
      onClick = function()
        activeTab = "chat"
        render()
      end,
    }),
    ui.button({
      text = tr("tab_history"),
      variant = activeTab == "history" and "primary" or "ghost",
      onClick = function()
        activeTab = "history"
        render()
      end,
    }),
    ui.button({
      text = tr("tab_setting"),
      variant = activeTab == "setting" and "primary" or "ghost",
      onClick = function()
        activeTab = "setting"
        render()
      end,
    }),
  })

  local bodyNode
  if activeTab == "chat" then
    bodyNode = renderChatView()
  elseif activeTab == "history" then
    bodyNode = renderHistoryView()
  else
    bodyNode = renderSettingView()
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    titleRow,
    tabBar,
    bodyNode,
  }))
end

-- ── Lifecycle Handlers ────────────────────────────────────────────────────────

function onOpen(_context)
  config = storage.loadConfig()
  sessions = storage.loadSessions()
  if startFreshOnOpen or (currentSession ~= nil and #currentSession.messages == 0) then
    startFreshOnOpen = true
    currentSession = nil
  elseif currentSession then
    local matched = nil
    for _, sess in ipairs(sessions) do
      if sess.id == currentSession.id then
        matched = sess
        break
      end
    end
    currentSession = matched or sessions[1] or nil
  else
    currentSession = sessions[1] or nil
  end

  activeTab = "chat"
  pendingDeleteSessionId = nil
  pendingClear = false
  testConnStatus = nil
  historySearch = ""
  showApiKey = false
  showSearchApiKey = false
  isSearching = false
  saveSuccess = false
  settingRev += 1
  render()
end

function onClose()
  if isStreaming then
    stopStreaming()
  end
  pcall(function()
    if config then
      storage.saveConfig(config, true)
    end
  end)
end

function onConfigChanged()
  config = storage.loadConfig()
  settingRev += 1
  render()
end

function onIpc(event: string, payload: string?)
  if event == "clear" or event == "new_session" then
    if isStreaming then
      stopStreaming()
    end
    if currentSession and #currentSession.messages > 0 then
      storage.saveSessions(sessions)
    end
    currentSession = nil
    startFreshOnOpen = true
    inputBuffer = ""
    inputRev += 1
    render()
  elseif event == "ask" then
    if payload and noctalia.string.trim(payload) ~= "" then
      if isStreaming then
        stopStreaming()
      end
      inputBuffer = noctalia.string.trim(payload)
      inputRev += 1
      activeTab = "chat"
      sendMessage()
    end
  elseif event == "export" then
    if currentSession and #currentSession.messages > 0 then
      export.saveSession(currentSession)
    else
      noctalia.notify(tr("export_empty_title"), tr("export_empty_body"))
    end
  elseif event == "toggle" then
    noctalia.togglePanel("rigelyon/ai-sidebar:panel")
  else
    noctalia.log("AI Sidebar: Unhandled IPC event " .. tostring(event))
  end
end
