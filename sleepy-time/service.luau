--!nonstrict
-- service.luau — Sleepy Time background timer & scheduler engine

noctalia.setUpdateInterval(1000)

-- ── Configuration & State Defaults ──────────────────────────────────────────

local function loadDefaults()
    return {
        defaultAction   = noctalia.getConfig("default_action") or "lock",
        defaultDuration = tonumber(noctalia.getConfig("default_duration")) or 30,
        warningEnabled  = noctalia.getConfig("warning_enabled") ~= false,
        warningSeconds  = tonumber(noctalia.getConfig("warning_seconds")) or 60,
        warningSound    = noctalia.getConfig("warning_sound") == true,
        lockCmd         = noctalia.getConfig("lock_command") or "",
        suspendCmd      = noctalia.getConfig("suspend_command") or "",
        shutdownCmd     = noctalia.getConfig("shutdown_command") or "",
        rebootCmd       = noctalia.getConfig("reboot_command") or "",
        logoutCmd       = noctalia.getConfig("logout_command") or "",
        customCmd       = noctalia.getConfig("custom_command") or "",
        quickTimersStr  = noctalia.getConfig("quick_timers") or "5,10,15,30,60,90,120",
    }
end

local config = loadDefaults()

-- ── Internal Timer State ────────────────────────────────────────────────────

local timerState = {
    isRunning       = false,
    isPaused        = false,
    secondsLeft     = 0,
    totalSeconds    = 0,
    action          = config.defaultAction,
    actionTarget    = "",
    mode            = "countdown", -- "countdown" or "scheduled"
    targetTimeStr   = "",
    warningActive   = false,
    warningNotified = { early = false, mid = false, final = false },
}

-- Publish presets table
local function parseQuickPresets(presetsStr)
    local list = {}
    for item in string.gmatch(presetsStr, "([^,]+)") do
        local num = tonumber(noctalia.string.trim(item))
        if num and num > 0 then
            local label = if num >= 60 then (num % 60 == 0 and (num/60 .. "h") or (num .. "m")) else (num .. "m")
            table.insert(list, { minutes = num, label = label })
        end
    end
    return list
end

noctalia.state.set("sleepy.presets", parseQuickPresets(config.quickTimersStr))

local function publishState()
    noctalia.state.set("sleepy.state", {
        isRunning     = timerState.isRunning,
        isPaused      = timerState.isPaused,
        secondsLeft   = timerState.secondsLeft,
        totalSeconds  = timerState.totalSeconds,
        action        = timerState.action,
        actionTarget  = timerState.actionTarget,
        mode          = timerState.mode,
        targetTimeStr = timerState.targetTimeStr,
        warningActive = timerState.warningActive,
    })
end

publishState()

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function formatTimeDisplay(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function calculateSecondsUntil(targetHHMM)
    local h, m = string.match(targetHHMM, "^(%d+):(%d+)")
    if not h or not m then return 0 end
    local targetH = tonumber(h)
    local targetM = tonumber(m)

    local now = os.date("*t")
    local currentSecs = now.hour * 3600 + now.min * 60 + now.sec
    local targetSecs = targetH * 3600 + targetM * 60

    local diff = targetSecs - currentSecs
    if diff <= 0 then
        -- Target time already passed today, schedule for tomorrow
        diff = diff + 86400
    end
    return diff
end

-- ── Action Execution ────────────────────────────────────────────────────────

local function getActionLabel(act)
    if act == "lock" then return "Lock Screen"
    elseif act == "suspend" then return "Suspend"
    elseif act == "shutdown" then return "Shutdown"
    elseif act == "reboot" then return "Reboot"
    elseif act == "logout" then return "Log Out"
    elseif act == "kill-process" then return "Kill Process"
    elseif act == "custom-command" then return "Custom Command"
    end
    return act
end

local function executeAction()
    local act = timerState.action
    local target = timerState.actionTarget
    local cmd = ""

    if act == "lock" then
        cmd = if config.lockCmd ~= "" then config.lockCmd else "loginctl lock-session"
    elseif act == "suspend" then
        cmd = if config.suspendCmd ~= "" then config.suspendCmd else "systemctl suspend || loginctl suspend"
    elseif act == "shutdown" then
        cmd = if config.shutdownCmd ~= "" then config.shutdownCmd else "systemctl poweroff || loginctl poweroff"
    elseif act == "reboot" then
        cmd = if config.rebootCmd ~= "" then config.rebootCmd else "systemctl reboot || loginctl reboot"
    elseif act == "logout" then
        if config.logoutCmd ~= "" then
            cmd = config.logoutCmd
        else
            -- Try common compositor logouts or loginctl
            cmd = "niri msg action quit 2>/dev/null || hyprctl dispatch exit 2>/dev/null || swaymsg exit 2>/dev/null || loginctl terminate-session self"
        end
    elseif act == "kill-process" then
        if target ~= "" then
            cmd = "kill " .. noctalia.string.trim(target) .. " 2>/dev/null || pkill -f " .. noctalia.string.trim(target)
        end
    elseif act == "custom-command" then
        cmd = if target ~= "" then target else config.customCmd
    end

    if cmd ~= "" then
        noctalia.log("Sleepy Time: executing action '" .. act .. "' command: " .. cmd)
        noctalia.runAsync(cmd)
        noctalia.notify("Sleepy Time", "Executed action: " .. getActionLabel(act))
    else
        noctalia.log("Sleepy Time: no command configured for action '" .. act .. "'")
    end
end

-- ── Process Listing Helper ──────────────────────────────────────────────────

local function fetchRunningProcesses()
    -- Get running graphical apps / user processes using ps
    local cmd = "ps -u $(whoami) -o pid=,comm=,args= --sort=comm"
    noctalia.runAsync(cmd, function(result)
        if not result or not result.stdout or result.stdout == "" then return end
        local processes = {}
        local seenNames = {}

        for line in string.gmatch(result.stdout, "[^\r\n]+") do
            local pid, comm, args = string.match(line, "^%s*(%d+)%s+(%S+)%s*(.*)$")
            if pid and comm and comm ~= "ps" and comm ~= "sh" and comm ~= "bash" and comm ~= "zsh" then
                -- Try resolving app icon for comm name
                local iconPath = noctalia.appIconPath(comm, 24)
                if not seenNames[comm] then
                    seenNames[comm] = true
                    table.insert(processes, {
                        pid = pid,
                        name = comm,
                        args = args,
                        iconPath = iconPath or "",
                    })
                end
            end
        end
        noctalia.state.set("sleepy.processList", processes)
    end)
end

-- ── Command Dispatcher ──────────────────────────────────────────────────────

noctalia.state.watch("sleepy.command", function(cmd)
    if type(cmd) ~= "table" or not cmd.action then return end

    if cmd.action == "start" then
        local mode = cmd.mode or "countdown"
        local action = cmd.targetAction or config.defaultAction
        local target = cmd.targetParam or ""
        local totalSecs = 0

        if mode == "scheduled" and cmd.targetTime then
            totalSecs = calculateSecondsUntil(cmd.targetTime)
            timerState.targetTimeStr = cmd.targetTime
        else
            totalSecs = tonumber(cmd.seconds) or (config.defaultDuration * 60)
            timerState.targetTimeStr = ""
        end

        if totalSecs > 0 then
            timerState.isRunning       = true
            timerState.isPaused        = false
            timerState.secondsLeft     = totalSecs
            timerState.totalSeconds    = totalSecs
            timerState.action          = action
            timerState.actionTarget    = target
            timerState.mode            = mode
            timerState.warningActive   = false
            timerState.warningNotified = { early = false, mid = false, final = false }
            publishState()
            noctalia.log("Sleepy Time: timer started (" .. totalSecs .. "s, action=" .. action .. ")")
        end

    elseif cmd.action == "pause" then
        if timerState.isRunning then
            timerState.isPaused = true
            publishState()
        end

    elseif cmd.action == "resume" then
        if timerState.isRunning then
            timerState.isPaused = false
            publishState()
        end

    elseif cmd.action == "cancel" then
        if timerState.isRunning then
            timerState.isRunning     = false
            timerState.isPaused      = false
            timerState.secondsLeft   = 0
            timerState.warningActive = false
            publishState()
            noctalia.notify("Sleepy Time", "Timer cancelled")
        end

    elseif cmd.action == "addTime" then
        if timerState.isRunning then
            local addSecs = tonumber(cmd.seconds) or 300
            timerState.secondsLeft = timerState.secondsLeft + addSecs
            timerState.totalSeconds = math.max(timerState.totalSeconds, timerState.secondsLeft)
            if timerState.secondsLeft > config.warningSeconds then
                timerState.warningActive = false
                timerState.warningNotified = { early = false, mid = false, final = false }
            end
            publishState()
        end

    elseif cmd.action == "fetchProcesses" then
        fetchRunningProcesses()
    end
end)

-- ── Main Loop Tick ──────────────────────────────────────────────────────────

function update()
    if not timerState.isRunning or timerState.isPaused then return end

    timerState.secondsLeft = timerState.secondsLeft - 1

    -- Warning handling
    if config.warningEnabled and timerState.secondsLeft <= config.warningSeconds and timerState.secondsLeft > 0 then
        timerState.warningActive = true

        local actLabel = getActionLabel(timerState.action)

        -- Early warning (at threshold)
        if not timerState.warningNotified.early then
            timerState.warningNotified.early = true
            local timeStr = formatTimeDisplay(timerState.secondsLeft)
            noctalia.notify("Sleepy Time Warning", "⏳ " .. actLabel .. " in " .. timeStr)
        end

        -- Mid warning (at 30s)
        if timerState.secondsLeft <= 30 and not timerState.warningNotified.mid then
            timerState.warningNotified.mid = true
            noctalia.notify("Sleepy Time Warning", "⚠️ " .. actLabel .. " in 30 seconds!")
        end

        -- Final warning (at 10s)
        if timerState.secondsLeft <= 10 and not timerState.warningNotified.final then
            timerState.warningNotified.final = true
            noctalia.notify("Sleepy Time Warning", "🔴 " .. actLabel .. " in 10 seconds!")
        end
    end

    -- Fire action when time reaches zero
    if timerState.secondsLeft <= 0 then
        timerState.isRunning     = false
        timerState.isPaused      = false
        timerState.secondsLeft   = 0
        timerState.warningActive = false
        publishState()

        executeAction()
    else
        publishState()
    end
end

function onConfigChanged()
    config = loadDefaults()
    noctalia.state.set("sleepy.presets", parseQuickPresets(config.quickTimersStr))
    noctalia.log("Sleepy Time: service settings reloaded")
end

function onExit()
    -- Service cleanup
    timerState.isRunning = false
    publishState()
end
