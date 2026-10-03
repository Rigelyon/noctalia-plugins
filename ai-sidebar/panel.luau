--!nonstrict
-- AI Sidebar panel implementation with streaming chat, session history, and provider settings.

local storage = require("./storage.luau")
local client = require("./client.luau")

local activeTab = "chat" -- "chat" | "history" | "setting"
local sessions = {}
local currentSession = nil
local config = nil

local inputBuffer = ""
local inputRev = 0
local scrollRev = 0
local historySearch = ""
local isStreaming = false
local streamHandle = nil
local lastRenderMs = 0

-- UI transient states
local pendingDeleteSessionId = nil
local pendingClear = false
local testConnStatus = nil -- nil | "testing" | "success" | "error: <msg>"

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
  if currentSession and #currentSession.messages > 0 then
    storage.saveSessions(sessions)
  end
  render()
end

local function sendMessage()
  local text = noctalia.string.trim(inputBuffer)
  if text == "" or isStreaming then return end

  if not currentSession then
    currentSession = storage.createSession(text, config.active_provider, config[config.active_provider .. "_model"])
    table.insert(sessions, 1, currentSession)
  end

  -- Add user message
  table.insert(currentSession.messages, {
    role = "user",
    content = text,
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  -- Set session title from first message if default
  if currentSession.title == "New Conversation" then
    currentSession.title = storage.generateTitle(text)
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
  lastRenderMs = noctalia.nowMs()
  render()

  local assistantMsg = currentSession.messages[#currentSession.messages]

  streamHandle = client.streamChat(
    capped,
    config,
    function(chunk: string)
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
      assistantMsg.content = assistantMsg.content .. "\n\n**[" .. tr("error_title") .. ": " .. err .. "]**"
      storage.saveSessions(sessions)
      scrollRev += 1
      render()
    end,
    function()
      isStreaming = false
      streamHandle = nil
      storage.saveSessions(sessions)
      scrollRev += 1
      render()
    end
  )
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
    for _, msg in ipairs(currentSession.messages) do
      if msg.role == "user" then
        local timeStr = msg.timestamp and noctalia.formatTime("%H:%M", msg.timestamp) or ""
        table.insert(messageNodes, ui.row({ justify = "end", align = "start" }, {
          ui.column({
            fill = "primary/0.2",
            radius = 12,
            padding = 10,
            paddingH = 14,
            gap = 2,
          }, {
            ui.markdown({ text = msg.content }),
            ui.row({ justify = "end" }, {
              ui.label({
                text = timeStr,
                fontSize = 9,
                color = "on_surface_variant",
              }),
            }),
          }),
        }))
      elseif msg.role == "assistant" then
        local content = msg.content
        if content == "" and isStreaming then
          content = "_" .. tr("status_typing") .. "_"
        end
        local providerTitle = config.active_provider:sub(1, 1):upper() .. config.active_provider:sub(2)
        local timeStr = msg.timestamp and noctalia.formatTime("%H:%M", msg.timestamp) or ""
        table.insert(messageNodes, ui.row({ justify = "start", align = "start" }, {
          ui.column({
            fill = "surface_variant/0.25",
            radius = 12,
            padding = 10,
            paddingH = 14,
            flexGrow = 1,
            gap = 6,
          }, {
            ui.row({ gap = 6, align = "center", justify = "space_between" }, {
              ui.row({ gap = 6, align = "center" }, {
                ui.glyph({ name = "sparkles", size = 13, color = "primary" }),
                ui.label({
                  text = providerTitle,
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
              ui.button({
                glyph = "copy",
                variant = "ghost",
                tooltip = tr("copy"),
                onClick = function()
                  if content ~= "" then
                    noctalia.copyToClipboard(msg.content, "text/plain")
                    noctalia.notify(tr("copied_to_clipboard"), "sparkles")
                  end
                end,
              }),
            }),
            ui.markdown({ text = content }),
          }),
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
            currentSession.messages = {}
            storage.saveSessions(sessions)
          end
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

  local inputRow = ui.column({ gap = 6, align = "stretch" }, {
    ui.input({
      key = "chat-input-" .. inputRev,
      value = inputBuffer,
      placeholder = tr("input_placeholder"),
      multiline = true,
      submitOnEnter = true,
      focus = true,
      height = 70,
      onChange = function(val)
        inputBuffer = val or ""
      end,
      onSubmit = function()
        sendMessage()
      end,
    }),
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({
        text = isStreaming and tr("status_typing") or tr("status_ready"),
        fontSize = 11,
        color = "on_surface_variant",
      }),
      ui.row({ gap = 4, align = "center" }, actionButtons),
    }),
  })

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
        table.insert(sessions, 1, currentSession)
        storage.saveSessions(sessions)
        inputBuffer = ""
        inputRev += 1
        activeTab = "chat"
        render()
      end,
    }),
    searchBar,
    ui.scroll({ flexGrow = 1, gap = 4 }, rows),
  })
end

-- ── View: Setting ────────────────────────────────────────────────────────────

local function renderSettingView()
  local providerPills = ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = tr("provider_openai"),
      variant = config.active_provider == "openai" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "openai"
        render()
      end,
    }),
    ui.button({
      text = tr("provider_anthropic"),
      variant = config.active_provider == "anthropic" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "anthropic"
        render()
      end,
    }),
    ui.button({
      text = tr("provider_gemini"),
      variant = config.active_provider == "gemini" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "gemini"
        render()
      end,
    }),
  })

  local activeSettings = {}
  if config.active_provider == "openai" then
    table.insert(activeSettings, ui.label({ text = tr("provider_openai") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.openai_key,
      placeholder = "sk-...",
      onChange = function(v) config.openai_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_openai") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.openai_model,
      placeholder = "gpt-4o-mini",
      onChange = function(v) config.openai_model = v end,
    }))
  elseif config.active_provider == "anthropic" then
    table.insert(activeSettings, ui.label({ text = tr("provider_anthropic") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.anthropic_key,
      placeholder = "sk-ant-...",
      onChange = function(v) config.anthropic_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_anthropic") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.anthropic_model,
      placeholder = "claude-3-5-haiku-20241022",
      onChange = function(v) config.anthropic_model = v end,
    }))
  elseif config.active_provider == "gemini" then
    table.insert(activeSettings, ui.label({ text = tr("provider_gemini") .. " " .. tr("api_key"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.gemini_key,
      placeholder = "AIzaSy...",
      onChange = function(v) config.gemini_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_gemini") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.gemini_model,
      placeholder = "gemini-1.5-flash",
      onChange = function(v) config.gemini_model = v end,
    }))
  end

  local testConnLabel = nil
  if testConnStatus == "testing" then
    testConnLabel = ui.label({ text = tr("testing"), color = "on_surface_variant" })
  elseif testConnStatus == "success" then
    testConnLabel = ui.label({ text = tr("test_success"), color = "primary" })
  elseif type(testConnStatus) == "string" and testConnStatus:find("^error:") then
    testConnLabel = ui.label({ text = tr("test_error") .. " (" .. testConnStatus:sub(8) .. ")", color = "error" })
  end

  local testConnRow = ui.row({ align = "center", justify = "space_between" }, {
    ui.button({
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
    }),
    testConnLabel or ui.spacer({}),
  })

  return ui.scroll({ flexGrow = 1, gap = 12, padding = 4 }, {
    ui.label({ text = tr("active_provider"), fontSize = 13, fontWeight = "bold" }),
    providerPills,
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
    testConnRow,
    ui.separator({}),
    ui.button({
      glyph = "device-floppy",
      text = tr("save_settings"),
      variant = "primary",
      onClick = function()
        storage.saveConfig(config)
        noctalia.notify(tr("title"), tr("settings_saved"))
      end,
    }),
  })
end

-- ── Render Root ──────────────────────────────────────────────────────────────

render = function()
  local titleRow = ui.row({ align = "center", justify = "space_between" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "sparkles", size = 18, color = "primary" }),
      ui.label({ text = tr("title"), fontWeight = "bold" }),
      ui.label({
        text = "· " .. config.active_provider,
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
    ui.row({ gap = 4, align = "center" }, {
      ui.button({
        glyph = "plus",
        variant = "ghost",
        tooltip = tr("new_chat"),
        onClick = function()
          currentSession = storage.createSession(nil, config.active_provider, config[config.active_provider .. "_model"])
          table.insert(sessions, 1, currentSession)
          storage.saveSessions(sessions)
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
      text = tr("tab_history") .. " (" .. tostring(#sessions) .. ")",
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
  if currentSession then
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
  render()
end

function onClose()
  if isStreaming then
    stopStreaming()
  end
end
