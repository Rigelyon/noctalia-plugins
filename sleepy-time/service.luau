--!nonstrict
-- service.luau — Sleepy Time headless background timer & scheduler engine

noctalia.setUpdateInterval(1000)

-- ── Configuration Loader ─────────────────────────────────────────────────────

local function loadConfig()
    return {
        defaultAction   = noctalia.getConfig("default_action") or "lock",
        defaultDuration = tonumber(noctalia.getConfig("default_duration")) or 30,
        warningEnabled  = noctalia.getConfig("warning_enabled") ~= false,
        warningSeconds  = tonumber(noctalia.getConfig("warning_seconds")) or 60,
        lockCommand     = noctalia.getConfig("lock_command") or "",
        suspendCommand  = noctalia.getConfig("suspend_command") or "",
        shutdownCommand = noctalia.getConfig("shutdown_command") or "",
        rebootCommand   = noctalia.getConfig("reboot_command") or "",
        logoutCommand   = noctalia.getConfig("logout_command") or "",
        customCommand   = noctalia.getConfig("custom_command") or "",
        quickTimersStr  = noctalia.getConfig("quick_timers") or "5,10,15,30,60,90,120",
    }
end

local config = loadConfig()

-- ── State Management ─────────────────────────────────────────────────────────

local timerState = {
    status          = "IDLE",       -- "IDLE" | "RUNNING" | "PAUSED" | "WARNING"
    mode            = "countdown",  -- "countdown" | "scheduled"
    remaining       = 0,
    duration        = 0,
    action          = config.defaultAction,
    actionTarget    = "",
    targetTimeStr   = "",
    warningActive   = false,
    warningNotified = { early = false, mid = false, final = false },
}

local function formatTime(seconds: number): string
    local s = math.max(0, math.floor(seconds))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    else
        return string.format("%02d:%02d", m, sec)
    end
end

local function parseQuickPresets(presetsStr: string)
    local list = {}
    for item in string.gmatch(presetsStr, "([^,]+)") do
        local num = tonumber(noctalia.string.trim(item))
        if num and num > 0 then
            local label = if num >= 60 then (num % 60 == 0 and (num // 60 .. "h") or (num .. "m")) else (num .. "m")
            table.insert(list, { minutes = num, label = label })
        end
    end
    return list
end

local function publishState()
    noctalia.state.set("sleepy.state", {
        status        = timerState.status,
        mode          = timerState.mode,
        remaining     = timerState.remaining,
        duration      = timerState.duration,
        formattedTime = formatTime(timerState.remaining),
        action        = timerState.action,
        actionTarget  = timerState.actionTarget,
        targetTimeStr = timerState.targetTimeStr,
        warningActive = timerState.warningActive,
    })
end

-- ── Running Process Scanner ──────────────────────────────────────────────────

local ignoredProcesses = {
    ps = true, sh = true, bash = true, zsh = true, fish = true,
    sed = true, grep = true, systemd = true, awk = true, sleep = true,
    cat = true, cut = true, tr = true, uniq = true, sort = true,
    head = true, tail = true, which = true, find = true, dbus = true,
    ["dbus-broker"] = true, ["dbus-broker-lau"] = true, ["dbus-daemon"] = true,
    ["pipewire"] = true, ["wireplumber"] = true, ["pipewire-pulse"] = true,
    ["noctalia"] = true, ["xdg-desktop-por"] = true, ["xdg-document-po"] = true,
    ["xdg-permission-"] = true, ["at-spi-bus-laun"] = true, ["at-spi2-registr"] = true,
    ["dconf-service"] = true, ["gnome-keyring-d"] = true, ["goa-daemon"] = true,
    ["goa-identity-se"] = true, ["p11-kit-server"] = true, ["mpris-proxy"] = true,
    ["conmon"] = true, ["catatonit"] = true, ["(sd-pam)"] = true, ["sd_dummy"] = true,
    ["sd_espeak-ng"] = true, ["speech-dispatch"] = true, ["srt-bwrap"] = true,
    ["srt-logger"] = true, ["socat"] = true, ["wsdd"] = true, ["wl-copy"] = true,
}

local function fetchRunningProcesses()
    local cmd = "ps -u $(whoami) -o comm= --sort=comm | uniq"
    noctalia.runAsync(cmd, function(result)
        local processes = {}
        if result and result.stdout and result.stdout ~= "" then
            for comm in string.gmatch(result.stdout, "[^\r\n]+") do
                comm = noctalia.string.trim(comm)
                if comm ~= ""
                   and not ignoredProcesses[comm]
                   and not string.match(comm, "^%[.*%]$")
                   and not string.match(comm, "^%(.*%)$")
                   and not string.match(comm, "^gvfs") then
                    local iconPath = noctalia.appIconPath(comm, 24) or ""
                    table.insert(processes, {
                        name = comm,
                        iconPath = iconPath,
                    })
                end
            end
        end
        noctalia.state.set("sleepy.processesLoaded", true)
        noctalia.state.set("sleepy.processes", processes)
    end)
end

-- Initialize state channels
noctalia.state.set("sleepy.presets", parseQuickPresets(config.quickTimersStr))
noctalia.state.set("sleepy.processes", {})
noctalia.state.set("sleepy.processesLoaded", false)
publishState()
fetchRunningProcesses()

-- ── Time & Scheduler Helpers ─────────────────────────────────────────────────

local function calculateSecondsUntil(targetHHMM: string): number
    if not targetHHMM or targetHHMM == "" then return 0 end
    local clean = string.gsub(targetHHMM, "%s+", "")

    local h, m = string.match(clean, "^(%d+)[%.:](%d+)$")
    if not h or not m then
        local d4_h, d4_m = string.match(clean, "^(%d%d)(%d%d)$")
        if d4_h and d4_m then
            h, m = d4_h, d4_m
        else
            local single = string.match(clean, "^(%d+)$")
            if single then
                local sNum = tonumber(single) or 0
                if sNum <= 24 then
                    h, m = single, "0"
                end
            end
        end
    end

    if not h or not m then return 0 end
    local targetH = tonumber(h) or 0
    local targetM = tonumber(m) or 0
    if targetH > 24 or targetM >= 60 then return 0 end
    if targetH == 24 then targetH = 0 end

    local now = os.date("*t")
    local currentSecs = (now.hour * 3600) + (now.min * 60) + now.sec
    local targetSecs = (targetH * 3600) + (targetM * 60)

    local diff = targetSecs - currentSecs
    if diff <= 0 then
        -- Target time has already passed today, schedule for tomorrow
        diff = diff + 86400
    end
    return diff
end

local function getActionLabel(act: string): string
    if act == "lock" then return noctalia.tr("action.lock")
    elseif act == "suspend" then return noctalia.tr("action.suspend")
    elseif act == "shutdown" then return noctalia.tr("action.shutdown")
    elseif act == "reboot" then return noctalia.tr("action.reboot")
    elseif act == "logout" then return noctalia.tr("action.logout")
    elseif act == "kill-process" then return noctalia.tr("action.kill-process")
    elseif act == "custom-command" then return noctalia.tr("action.custom-command")
    end
    return act
end

-- ── Action Execution ─────────────────────────────────────────────────────────

local function executeAction()
    local act = timerState.action
    local target = timerState.actionTarget
    local cmd = ""

    if act == "lock" then
        cmd = if config.lockCommand ~= "" then config.lockCommand
              else "loginctl lock-session 2>/dev/null || hyprlock 2>/dev/null || swaylock 2>/dev/null || waylock 2>/dev/null"
    elseif act == "suspend" then
        cmd = if config.suspendCommand ~= "" then config.suspendCommand
              else "systemctl suspend || loginctl suspend"
    elseif act == "shutdown" then
        cmd = if config.shutdownCommand ~= "" then config.shutdownCommand
              else "systemctl poweroff || loginctl poweroff"
    elseif act == "reboot" then
        cmd = if config.rebootCommand ~= "" then config.rebootCommand
              else "systemctl reboot || loginctl reboot"
    elseif act == "logout" then
        if config.logoutCommand ~= "" then
            cmd = config.logoutCommand
        else
            cmd = 'loginctl terminate-session "${XDG_SESSION_ID:-self}" 2>/dev/null || niri msg action quit --skip-confirmation 2>/dev/null || hyprctl dispatch exit 2>/dev/null || swaymsg exit 2>/dev/null'
        end
    elseif act == "kill-process" then
        if target ~= "" then
            local cleanTarget = noctalia.string.trim(target)
            cmd = "kill -15 " .. cleanTarget .. " 2>/dev/null || pkill -15 -f " .. cleanTarget .. " 2>/dev/null"
        end
    elseif act == "custom-command" then
        cmd = if target ~= "" then target else config.customCommand
    end

    if cmd ~= "" then
        noctalia.log("Sleepy Time: executing action '" .. act .. "' command: " .. cmd)
        noctalia.runAsync(cmd)
        noctalia.notify("Sleepy Time", noctalia.tr("notification.executed", { action = getActionLabel(act) }))
    else
        noctalia.log("Sleepy Time: no valid command found for action '" .. act .. "'")
    end
end

-- ── Command Channel Watcher ──────────────────────────────────────────────────

noctalia.state.watch("sleepy.cmd", function(cmd)
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
            timerState.status          = "RUNNING"
            timerState.remaining       = totalSecs
            timerState.duration        = totalSecs
            timerState.action          = action
            timerState.actionTarget    = target
            timerState.mode            = mode
            timerState.warningActive   = false
            timerState.warningNotified = { early = false, mid = false, final = false }
            publishState()
            noctalia.log("Sleepy Time: timer started (" .. totalSecs .. "s, action=" .. action .. ")")
        end

    elseif cmd.action == "pause" then
        if timerState.status == "RUNNING" or timerState.status == "WARNING" then
            timerState.status = "PAUSED"
            publishState()
        end

    elseif cmd.action == "resume" then
        if timerState.status == "PAUSED" then
            timerState.status = if timerState.warningActive then "WARNING" else "RUNNING"
            publishState()
        end

    elseif cmd.action == "cancel" or cmd.action == "reset" then
        if timerState.status ~= "IDLE" then
            timerState.status          = "IDLE"
            timerState.remaining       = 0
            timerState.duration        = 0
            timerState.warningActive   = false
            timerState.warningNotified = { early = false, mid = false, final = false }
            publishState()
            noctalia.notify("Sleepy Time", noctalia.tr("notification.cancelled"))
        end

    elseif cmd.action == "addTime" then
        if timerState.status ~= "IDLE" then
            local delta = tonumber(cmd.seconds) or 300
            timerState.remaining = math.max(1, timerState.remaining + delta)
            timerState.duration = math.max(timerState.duration, timerState.remaining)

            if timerState.remaining > config.warningSeconds then
                timerState.warningActive = false
                timerState.warningNotified = { early = false, mid = false, final = false }
                if timerState.status == "WARNING" then
                    timerState.status = "RUNNING"
                end
            end
            publishState()
        end

    elseif cmd.action == "fetchProcesses" then
        fetchRunningProcesses()
    end
end)

-- ── Main Loop Tick ───────────────────────────────────────────────────────────

function update()
    if timerState.status ~= "RUNNING" and timerState.status ~= "WARNING" then
        return
    end

    timerState.remaining = timerState.remaining - 1

    -- Warning handling
    if config.warningEnabled and timerState.remaining <= config.warningSeconds and timerState.remaining > 0 then
        timerState.warningActive = true
        timerState.status = "WARNING"

        local actLabel = getActionLabel(timerState.action)

        -- Early warning (at threshold)
        if not timerState.warningNotified.early then
            timerState.warningNotified.early = true
            local timeStr = formatTime(timerState.remaining)
            noctalia.notify("Sleepy Time", noctalia.tr("notification.warning-early", { action = actLabel, time = timeStr }))
        end

        -- Mid warning (at <= 30s)
        if timerState.remaining <= 30 and not timerState.warningNotified.mid then
            timerState.warningNotified.mid = true
            local timeStr = formatTime(timerState.remaining)
            noctalia.notify("Sleepy Time", noctalia.tr("notification.warning-mid", { action = actLabel, time = timeStr }))
        end

        -- Final warning (at <= 10s)
        if timerState.remaining <= 10 and not timerState.warningNotified.final then
            timerState.warningNotified.final = true
            local timeStr = formatTime(timerState.remaining)
            noctalia.notify("Sleepy Time", noctalia.tr("notification.warning-final", { action = actLabel, time = timeStr }))
        end
    end

    -- Timer Completion
    if timerState.remaining <= 0 then
        timerState.status          = "IDLE"
        timerState.remaining       = 0
        timerState.duration        = 0
        timerState.warningActive   = false
        timerState.warningNotified = { early = false, mid = false, final = false }
        publishState()

        executeAction()
    else
        publishState()
    end
end

function onConfigChanged()
    config = loadConfig()
    noctalia.state.set("sleepy.presets", parseQuickPresets(config.quickTimersStr))
    noctalia.log("Sleepy Time: service configuration reloaded")
end

function onEnable()
    fetchRunningProcesses()
end

function onExit(_signal, _reason)
    timerState.status = "IDLE"
    timerState.remaining = 0
    publishState()
end
