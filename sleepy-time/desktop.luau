--!nonstrict
-- desktop.luau — Sleepy Time declarative ambient desktop widget

local function getDesktopConfig()
    return {
        color           = noctalia.getConfig("color") or "primary",
        showWhenIdle    = noctalia.getConfig("show_when_idle") == true,
        showProgress    = noctalia.getConfig("show_progress") ~= false,
        showPercentage  = noctalia.getConfig("show_percentage") ~= false,
        showActionLabel = noctalia.getConfig("show_action_label") ~= false,
        showFinishTime  = noctalia.getConfig("show_finish_time") ~= false,
        showControls    = noctalia.getConfig("show_controls") ~= false,
        fontSize        = tonumber(noctalia.getConfig("font_size")) or 38,
        compactMode     = noctalia.getConfig("compact_mode") == true,
        pausedColor     = noctalia.getConfig("paused_color") or "#f59e0b",
        warningColor    = noctalia.getConfig("warning_color") or "#ef4444",
    }
end

local function renderDesktop()
    pcall(function()
        local cfg = getDesktopConfig()
        local state = noctalia.state.get("sleepy.state") or { status = "IDLE", remaining = 0, duration = 0 }

        local isRunning = (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING")
        local isPaused  = (state.status == "PAUSED")
        local isWarning = (state.status == "WARNING" or state.warningActive == true)

        -- Proportional scaling factor based on default base font size (38px)
        local baseFontSize = 38
        local scale = math.max(0.4, math.min(3.0, cfg.fontSize / baseFontSize))

        if not isRunning then
            if not cfg.showWhenIdle then
                desktopWidget.render(ui.box({ width = 0, height = 0 }))
                return
            end

            -- Render minimal idle display (ambient floating, proportionally scaled)
            local idleGlyphSize = math.max(12, math.min(36, math.floor(18 * scale)))
            local idleFontSize  = math.max(9, math.min(24, math.floor(12 * scale)))
            local idleGap       = math.max(4, math.floor(8 * scale))

            desktopWidget.render(
                ui.row({ align = "center", justify = "center", gap = idleGap }, {
                    ui.glyph({ name = "moon-stars", size = idleGlyphSize, color = "primary" }),
                    ui.label({ text = "Sleepy Time — Idle", fontSize = idleFontSize, color = "on_surface_variant" }),
                })
            )
            return
        end

        -- Running state progress calculations
        local secsLeft = state.remaining or 0
        local totalSecs = state.duration or 1
        local progressRatio = if totalSecs > 0 then math.max(0, math.min(1, 1 - (secsLeft / totalSecs))) else 0
        local pctText = string.format("%d%%", math.floor(progressRatio * 100))

        local accentColor = cfg.color
        if isWarning then
            accentColor = cfg.warningColor
        elseif isPaused then
            accentColor = cfg.pausedColor
        end

        local actName = noctalia.tr("action." .. (state.action or "lock"))
        local glyphName = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "moon-stars"
        local timeText = state.formattedTime or "00:00"
        local finishTimeStr = os.date("%H:%M", os.time() + secsLeft)

        if cfg.compactMode then
            -- Compact single-row layout with responsive scaling
            local compactTimerFontSize = math.max(13, math.min(48, math.floor(20 * scale)))
            local compactGlyphSize     = math.max(13, math.min(40, math.floor(20 * scale)))
            local compactProgressW     = math.max(40, math.min(240, math.floor(80 * scale)))
            local compactProgressH     = math.max(3, math.min(12, math.floor(6 * scale)))
            local compactProgressRad   = math.max(2, math.floor(compactProgressH / 2))
            local compactLabelSize     = math.max(9, math.min(20, math.floor(12 * scale)))
            local compactGap           = math.max(4, math.floor(10 * scale))

            local rowItems = {
                ui.glyph({ name = glyphName, size = compactGlyphSize, color = accentColor }),
                ui.label({
                    text = timeText,
                    fontSize = compactTimerFontSize,
                    fontWeight = "bold",
                    color = accentColor,
                }),
            }

            if cfg.showProgress then
                table.insert(rowItems, ui.progress({
                    progress = progressRatio,
                    fill = accentColor,
                    width = compactProgressW,
                    height = compactProgressH,
                    radius = compactProgressRad,
                }))
            end

            if cfg.showPercentage then
                table.insert(rowItems, ui.label({ text = pctText, fontSize = compactLabelSize, color = "on_surface_variant" }))
            end

            if cfg.showActionLabel then
                table.insert(rowItems, ui.label({ text = actName, fontSize = compactLabelSize, fontWeight = "medium", color = "on_surface" }))
            end

            if cfg.showControls then
                table.insert(rowItems, ui.button({
                    text = "✕",
                    variant = "secondary",
                    controlSize = "sm",
                    onClick = function()
                        noctalia.state.set("sleepy.cmd", { action = "cancel" })
                    end,
                }))
            end

            desktopWidget.render(
                ui.row({ align = "center", justify = "center", gap = compactGap }, rowItems)
            )
        else
            -- Standard ambient floating layout (dynamic width auto-adjusting to widest element)
            local items = {}

            -- Header text calculation for width adaptation
            local headerTitle = if isWarning then "⚠️ Warning" elseif isPaused then "Paused" else "Sleepy Time"
            local fullHeaderStr = headerTitle .. (if cfg.showFinishTime then " • Ends " .. finishTimeStr else "")

            -- Footer label calculation for width adaptation
            local fullFooterLabel = actName
            if cfg.showActionLabel then
                local targetText = state.actionTarget or ""
                if (state.action == "kill-process" or state.action == "custom-command") and targetText ~= "" then
                    fullFooterLabel = actName .. ": " .. targetText
                end
            end
            local fullFooterStr = (if cfg.showActionLabel then fullFooterLabel else "") .. (if cfg.showPercentage then " " .. pctText else "")

            -- Dynamically compute responsive content width based on time text, header, footer & font size
            local headerGlyphSize = math.max(12, math.min(36, math.floor(18 * scale)))
            local headerTitleSize = math.max(10, math.min(24, math.floor(13 * scale)))
            local finishTimeSize  = math.max(9, math.min(20, math.floor(11 * scale)))
            local headerGap       = math.max(4, math.floor(8 * scale))

            local footerLabelSize = math.max(9, math.min(20, math.floor(12 * scale)))
            local controlsGap     = math.max(4, math.floor(6 * scale))
            local containerGap    = math.max(4, math.min(18, math.floor(8 * scale)))

            local approxTimeW   = math.floor(string.len(timeText) * cfg.fontSize * 0.62)
            local approxHeaderW = math.floor(string.len(fullHeaderStr) * headerTitleSize * 0.58) + headerGlyphSize + headerGap + 8
            local approxFooterW = math.floor(string.len(fullFooterStr) * footerLabelSize * 0.58) + 24
            local baseMinWidth  = math.floor(160 * scale)

            -- The content width automatically adjusts to the widest element
            local contentWidth = math.max(100, math.min(520, math.max(baseMinWidth, math.max(approxTimeW, math.max(approxHeaderW, approxFooterW)))))

            local progressH   = math.max(3, math.min(16, math.floor(6 * scale)))
            local progressRad = math.max(2, math.floor(progressH / 2))

            -- Title & Status Header
            local headerItems = {
                ui.glyph({ name = glyphName, size = headerGlyphSize, color = accentColor }),
                ui.label({
                    text = headerTitle,
                    fontSize = headerTitleSize,
                    fontWeight = "bold",
                    color = if isWarning then "error" else "on_surface",
                }),
            }
            if cfg.showFinishTime then
                table.insert(headerItems, ui.label({
                    text = "• Ends " .. finishTimeStr,
                    fontSize = finishTimeSize,
                    color = "on_surface_variant",
                }))
            end

            table.insert(items, ui.row({ align = "center", justify = "center", gap = headerGap }, headerItems))

            -- Timer Countdown display
            table.insert(items, ui.label({
                text = timeText,
                fontSize = cfg.fontSize,
                fontWeight = "bold",
                color = accentColor,
            }))

            -- Progress Bar (responsive width matching dynamic content width)
            if cfg.showProgress then
                table.insert(items, ui.progress({
                    progress = progressRatio,
                    fill = accentColor,
                    height = progressH,
                    radius = progressRad,
                    width = contentWidth,
                }))
            end

            -- Footer info (Percentage & Action label spanning full content width)
            local footerItems = {}
            if cfg.showActionLabel then
                local maxChars = math.max(10, math.floor((contentWidth - (if cfg.showPercentage then 45 else 0)) / (footerLabelSize * 0.6)))
                local labelText = fullFooterLabel
                if string.len(labelText) > maxChars then
                    labelText = string.sub(labelText, 1, maxChars - 2) .. "…"
                end
                table.insert(footerItems, ui.label({ text = labelText, fontSize = footerLabelSize, fontWeight = "medium", color = "on_surface" }))
            end
            if cfg.showPercentage then
                table.insert(footerItems, ui.label({ text = pctText, fontSize = footerLabelSize, color = "on_surface_variant" }))
            end

            if #footerItems > 0 then
                table.insert(items, ui.row({ justify = "space_between", align = "center", width = contentWidth }, footerItems))
            end

            -- Quick adjustment buttons
            if cfg.showControls then
                local btnControlSize = if scale < 0.75 then "sm" else nil
                table.insert(items, ui.row({ gap = controlsGap, justify = "center", align = "center" }, {
                    ui.button({
                        text = "+5m",
                        variant = "secondary",
                        controlSize = btnControlSize,
                        onClick = function()
                            noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = 300 })
                        end,
                    }),
                    ui.button({
                        text = if isPaused then "▶" else "⏸",
                        variant = "secondary",
                        controlSize = btnControlSize,
                        onClick = function()
                            noctalia.state.set("sleepy.cmd", { action = if isPaused then "resume" else "pause" })
                        end,
                    }),
                    ui.button({
                        text = "✕",
                        variant = "destructive",
                        controlSize = btnControlSize,
                        onClick = function()
                            noctalia.state.set("sleepy.cmd", { action = "cancel" })
                        end,
                    }),
                }))
            end

            desktopWidget.render(
                ui.column({ align = "center", justify = "center", gap = containerGap }, items)
            )
        end
    end)
end

-- ── Callbacks & Watches ──────────────────────────────────────────────────────

function onConfigChanged()
    renderDesktop()
end

function update()
    renderDesktop()
end

noctalia.state.watch("sleepy.state", function(_state)
    renderDesktop()
end)

-- Initial render
renderDesktop()
