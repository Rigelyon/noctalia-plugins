# Multi-Process Kill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to select multiple running processes to kill in Sleepy Time via interactive card toggle and comma-separated search input, with robust parallel termination and smart truncation across all UI surfaces.

**Architecture:** Comma-delimited string payload (`"proc1, proc2"`) passed across `sleepy.state` / `sleepy.cmd` ensuring 100% backward compatibility. `panel.luau` maintains multi-select state and syncs with `ui.input`. `service.luau` parses, sanitizes, and runs parallel kill commands asynchronously. `widget.luau`, `desktop.luau`, and `panel.luau` format labels with smart counters (`proc1 (+N more)`).

**Tech Stack:** Luau (typed Lua), Noctalia v5 plugin API (declarative UI, state engine, IPC).

## Global Constraints
- 100% backward compatible with single-process targets and existing configuration.
- Safe string sanitization against shell injection.
- Zero external runtime dependencies beyond Noctalia host APIs.

---

### Task 1: Background Service & Multi-Process Execution Engine

**Files:**
- Modify: `sleepy-time/service.luau:240-270`
- Test: `scratch/test_service_parser.luau`

**Interfaces:**
- Consumes: `timerState.actionTarget` containing comma-separated process names/PIDs (e.g. `"spotify, discord, 1234"`).
- Produces: Parallel kill execution string passed to `noctalia.runAsync(cmd)`, and formatted notification string in `noctalia.notify`.

- [ ] **Step 1: Write scratch test for target parsing and command generation**

Create `scratch/test_service_parser.luau` to verify multi-process splitting, sanitization, PID handling, and command assembly:

```luau
local function sanitizeTarget(name: string): string
    return string.gsub(name, "['\\]", "")
end

local function parseTargets(targetStr: string): { string }
    local list = {}
    for item in string.gmatch(targetStr, "([^,]+)") do
        local clean = string.gsub(item, "^%s*(.-)%s*$", "%1")
        if clean ~= "" then
            table.insert(list, clean)
        end
    end
    return list
end

local function buildKillCommand(targetStr: string): string
    local targets = parseTargets(targetStr)
    if #targets == 0 then return "" end

    local subCmds = {}
    for _, target in ipairs(targets) do
        if string.match(target, "^%d+$") then
            table.insert(subCmds, "(kill -15 " .. target .. " 2>/dev/null; sleep 0.3; kill -9 " .. target .. " 2>/dev/null)")
        else
            local safe = sanitizeTarget(target)
            table.insert(subCmds, "((pkill -15 -x '" .. safe .. "' 2>/dev/null || killall -15 '" .. safe .. "' 2>/dev/null || flatpak kill '" .. safe .. "' 2>/dev/null); (sleep 0.3 && (pkill -9 -x '" .. safe .. "' 2>/dev/null || killall -9 '" .. safe .. "' 2>/dev/null)))")
        end
    end

    if #subCmds == 0 then return "" end
    return table.concat(subCmds, " & ") .. " &"
end

local function formatActionLabel(targets: { string }): string
    if #targets == 0 then return "Kill Process" end
    if #targets == 1 then return "Kill Process (" .. targets[1] .. ")" end
    if #targets == 2 then return "Kill Process (" .. targets[1] .. ", " .. targets[2] .. ")" end
    return "Kill Process (" .. targets[1] .. ", " .. targets[2] .. ", +" .. (#targets - 2) .. " more)"
end

-- Assertions
local t1 = parseTargets("spotify, discord, 1234")
assert(#t1 == 3 and t1[1] == "spotify" and t1[2] == "discord" and t1[3] == "1234", "Failed parseTargets")

local cmd = buildKillCommand("spotify, 1234")
assert(string.find(cmd, "pkill -15 -x 'spotify'") ~= nil, "Missing spotify pkill")
assert(string.find(cmd, "kill -15 1234") ~= nil, "Missing 1234 kill")
assert(string.sub(cmd, -1) == "&", "Must be background command")

local label = formatActionLabel(t1)
assert(label == "Kill Process (spotify, discord, +1 more)", "Failed label formatting: " .. label)

print("Service parsing and command generation tests PASSED!")
```

- [ ] **Step 2: Run scratch test to verify logic**

Run: `luau scratch/test_service_parser.luau` or `lua scratch/test_service_parser.luau` (or test with available runner).
Expected: `Service parsing and command generation tests PASSED!`

- [ ] **Step 3: Update `sleepy-time/service.luau` with multi-process execution**

Modify `executeAction()` in `sleepy-time/service.luau`:
```luau
    elseif act == "kill-process" then
        if target ~= "" then
            local targets = {}
            for item in string.gmatch(target, "([^,]+)") do
                local clean = noctalia.string.trim(item)
                if clean ~= "" then
                    table.insert(targets, clean)
                end
            end

            if #targets > 0 then
                local subCmds = {}
                for _, t in ipairs(targets) do
                    if string.match(t, "^%d+$") then
                        table.insert(subCmds, "(kill -15 " .. t .. " 2>/dev/null; sleep 0.3; kill -9 " .. t .. " 2>/dev/null)")
                    else
                        local safeTarget = string.gsub(t, "['\\]", "")
                        table.insert(subCmds, "((pkill -15 -x '" .. safeTarget .. "' 2>/dev/null || killall -15 '" .. safeTarget .. "' 2>/dev/null || flatpak kill '" .. safeTarget .. "' 2>/dev/null); (sleep 0.3 && (pkill -9 -x '" .. safeTarget .. "' 2>/dev/null || killall -9 '" .. safeTarget .. "' 2>/dev/null)))")
                    end
                end
                cmd = table.concat(subCmds, " & ") .. " &"
            end
        end
```

And update notification formatting for `kill-process`:
```luau
        local actLabel = getActionLabel(act)
        if act == "kill-process" and target ~= "" then
            local targets = {}
            for item in string.gmatch(target, "([^,]+)") do
                local clean = noctalia.string.trim(item)
                if clean ~= "" then table.insert(targets, clean) end
            end
            if #targets == 1 then
                actLabel = actLabel .. " (" .. targets[1] .. ")"
            elseif #targets == 2 then
                actLabel = actLabel .. " (" .. targets[1] .. ", " .. targets[2] .. ")"
            elseif #targets > 2 then
                actLabel = actLabel .. " (" .. targets[1] .. ", " .. targets[2] .. ", +" .. (#targets - 2) .. " more)"
            end
        end
```

- [ ] **Step 4: Commit Task 1**

```bash
git add sleepy-time/service.luau
git commit -m "feat(sleepy-time): support multi-process termination in service engine"
```

---

### Task 2: Panel UI Multi-Selection & Search Input Synchronization

**Files:**
- Modify: `sleepy-time/panel.luau`

**Interfaces:**
- Consumes: `noctalia.state.get("sleepy.processes")`, `uiState.selectedProcess`.
- Produces: Comma-separated `uiState.selectedProcess` sent to `sleepy.cmd` on start, formatted multi-process active countdown readout.

- [ ] **Step 1: Add helper functions in `sleepy-time/panel.luau`**

Add `parseProcessSet`, `formatProcessList`, and `formatTargetSummary`:
```luau
local function parseProcessSet(str: string): ({ [string]: boolean }, { string })
    local set = {}
    local list = {}
    if not str or str == "" then return set, list end
    for item in string.gmatch(str, "([^,]+)") do
        local clean = noctalia.string.trim(item)
        if clean ~= "" and not set[clean] then
            set[clean] = true
            table.insert(list, clean)
        end
    end
    return set, list
end

local function formatProcessList(list: { string }): string
    return table.concat(list, ", ")
end

local function formatTargetSummary(targetStr: string, maxItems: number?): string
    if not targetStr or targetStr == "" then return "" end
    local max = maxItems or 1
    local items = {}
    for item in string.gmatch(targetStr, "([^,]+)") do
        local clean = noctalia.string.trim(item)
        if clean ~= "" then
            table.insert(items, clean)
        end
    end
    if #items == 0 then return "" end
    if #items == 1 then return items[1] end
    if #items <= max then return table.concat(items, ", ") end
    local remaining = #items - max
    local prefix = {}
    for i = 1, max do
        table.insert(prefix, items[i])
    end
    return table.concat(prefix, ", ") .. string.format(" (+%d more)", remaining)
end
```

- [ ] **Step 2: Update Setup View Process Cards & Input Handling in `sleepy-time/panel.luau`**

In `renderSetupView`:
- Extract `selectedSet, selectedList = parseProcessSet(uiState.selectedProcess)`.
- Determine active search filter term (use last comma segment if user is typing, e.g. `spotify, dis` -> filter is `dis`).
- Render card grid with multi-select toggle logic:
  - If card is clicked:
    ```luau
    if selectedSet[procName] then
        -- Remove from selectedList
        local newList = {}
        for _, name in ipairs(selectedList) do
            if name ~= procName then
                table.insert(newList, name)
            end
        end
        uiState.selectedProcess = formatProcessList(newList)
    else
        -- Append to selectedList
        table.insert(selectedList, procName)
        uiState.selectedProcess = formatProcessList(selectedList)
    end
    uiState.inputKey = uiState.inputKey + 1
    renderPanel()
    ```
  - Card active styling:
    `fill = if isSelected then "primary/0.2" else "surface_variant/0.3"`
    `color = if isSelected then "primary" else "on_surface"`

- [ ] **Step 3: Update Active View Sub-Info formatting in `sleepy-time/panel.luau`**

Update `renderActiveView`:
```luau
    local finishTimeStr = os.date("%H:%M", os.time() + secsLeft)
    local subInfoText = "Ends at " .. finishTimeStr
    if actionTarget ~= "" then
        local targetSummary = if state.action == "kill-process"
            then formatTargetSummary(actionTarget, 2)
            else actionTarget
        if string.len(targetSummary) > 28 then
            targetSummary = string.sub(targetSummary, 1, 26) .. "…"
        end
        subInfoText = subInfoText .. "  •  " .. targetSummary
    end
```

- [ ] **Step 4: Commit Task 2**

```bash
git add sleepy-time/panel.luau
git commit -m "feat(sleepy-time): implement multi-select process cards and input sync in panel"
```

---

### Task 3: Surface Formatting on Bar Widget & Desktop Widget

**Files:**
- Modify: `sleepy-time/widget.luau`
- Modify: `sleepy-time/desktop.luau`

**Interfaces:**
- Consumes: `state.actionTarget` (comma-separated string).
- Produces: Formatted concise readout for bar widget (`detailed` mode) and desktop widget (`compact` & standard modes).

- [ ] **Step 1: Update `sleepy-time/widget.luau`**

Add `formatTargetSummary` to `widget.luau`:
- In `detailed` display mode:
  ```luau
  local targetSummary = if state.action == "kill-process"
      then formatTargetSummary(state.actionTarget, 1)
      else state.actionTarget
  if targetSummary ~= "" and string.len(targetSummary) > 16 then
      targetSummary = string.sub(targetSummary, 1, 14) .. "…"
  end
  local detailLabel = if targetSummary ~= "" then targetSummary else actName
  ```
- In Tooltip: Format full list of targets cleanly.

- [ ] **Step 2: Update `sleepy-time/desktop.luau`**

Add `formatTargetSummary` to `desktop.luau`:
- In footer info calculation:
  ```luau
  if (state.action == "kill-process" or state.action == "custom-command") and targetText ~= "" then
      local summary = if state.action == "kill-process" then formatTargetSummary(targetText, 1) else targetText
      fullFooterLabel = actName .. ": " .. summary
  end
  ```

- [ ] **Step 3: Commit Task 3**

```bash
git add sleepy-time/widget.luau sleepy-time/desktop.luau
git commit -m "feat(sleepy-time): add smart multi-target summary formatting in widget and desktop"
```

---

### Task 4: End-to-End Verification & Documentation Update

**Files:**
- Modify: `sleepy-time/README.md`
- Test: Verification of all modified Luau files and syntax check

- [ ] **Step 1: Update `sleepy-time/README.md`**

Update the Kill Process description to highlight multiple process selection:
- "Kill Process: Terminates one or more selected running graphical apps or user processes (`kill -15` then `kill -9`, with multi-select support)."

- [ ] **Step 2: Syntax and lint check on all modified Luau scripts**

Run Luau syntax checking if available:
```bash
luau-analyze sleepy-time/*.luau || luau sleepy-time/service.luau || true
```

- [ ] **Step 3: Commit Task 4**

```bash
git add sleepy-time/README.md
git commit -m "docs(sleepy-time): document multi-process selection feature"
```
