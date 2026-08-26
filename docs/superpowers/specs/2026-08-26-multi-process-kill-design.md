# Multiple Process Selection for Kill Process Action

**Date:** 2026-08-26  
**Status:** Approved by User  
**Target Plugin:** `rigelyon/sleepy-time` (`sleepy-time`)

---

## 1. Overview & Goals

Sleepy Time currently supports killing a single running process or application by specifying a process name or PID. When configuring the "Kill Process" action in the setup panel, users could only click or type a single target.

This feature enables users to select multiple running processes to terminate simultaneously when the timer triggers, while maintaining seamless search, custom input, robust background termination, and compact, elegant UI representation across panels and widgets.

### Goals
- Allow users to toggle multiple process cards in `panel.luau` to select/deselect multiple processes.
- Synchronize selected processes with a comma-separated input field (e.g. `spotify, discord, steam`) allowing hybrid click and manual type interaction.
- Enable `service.luau` to parse comma-delimited target lists and execute safe, parallel process termination commands (`kill -15` followed by `kill -9`, `pkill`, `killall`, and `flatpak kill`).
- Format multi-process status gracefully across `widget.luau`, `desktop.luau`, and `panel.luau` using smart truncation and counters (e.g., `spotify (+2 more)`).
- Preserve 100% backward compatibility with single-process targets and existing IPC state schemas.

---

## 2. Architecture & Data Flow

```mermaid
flowchart TD
    subgraph Setup Panel [panel.luau]
        A[User Clicks Process Card] --> B[Toggle Process in Selected Set]
        C[User Types Comma-Separated Text] --> B
        B --> D[Update uiState.selectedProcess: 'proc1, proc2']
        D --> E[User Clicks Start Timer]
        E --> F[Send sleepy.cmd action='start' targetParam='proc1, proc2']
    end

    subgraph Service Engine [service.luau]
        F --> G[timerState.actionTarget = 'proc1, proc2']
        G --> H[publishState -> sleepy.state]
        G --> I[Timer Completes]
        I --> J[Split actionTarget by comma & sanitize]
        J --> K[Generate parallel kill sub-commands]
        K --> L[noctalia.runAsync combined command]
        L --> M[Send Aggregated Notification]
    end

    subgraph Surfaces [widget.luau & desktop.luau]
        H --> N[formatTargetSummary: 'proc1 (+N more)']
        N --> O[Bar Widget / Desktop Readout]
    end
```

---

## 3. Detailed Component Specifications

### 3.1. Panel UI (`sleepy-time/panel.luau`)

#### Helper Functions
- `parseProcessSet(str: string): { [string]: boolean }, { string }`:
  - Splits a string by `,` delimiter, trims each item.
  - Returns a lookup set `{ [name] = true }` and an ordered array of process names.
- `formatProcessList(list: { string }): string`:
  - Joins non-empty trimmed items with `", "`.

#### Selection & Card Toggle
- In `renderSetupView`:
  - Extract active set: `local selectedSet, selectedList = parseProcessSet(uiState.selectedProcess)`.
  - For filtering cards: Use the last typed token if user is actively typing (e.g. typing `spotify, dis` filters for `dis`), or show all when empty.
  - When a card is clicked:
    - If `selectedSet[procName]` is true: remove `procName` from `selectedList`.
    - If `selectedSet[procName]` is false: append `procName` to `selectedList`.
    - Set `uiState.selectedProcess = formatProcessList(selectedList)`.
    - Re-render panel.
  - Card active visual style:
    - `fill = if isSelected then "primary/0.2" else "surface_variant/0.3"`
    - Icon color = `if isSelected then "primary" else "on_surface_variant"`
    - Label font weight = `if isSelected then "bold" else "normal"`
    - Label color = `if isSelected then "primary" else "on_surface"`

---

### 3.2. Background Service Engine (`sleepy-time/service.luau`)

#### Command Generation & Termination Logic
- In `executeAction()` for `act == "kill-process"`:
  - Split `target` by `,` delimiter.
  - For each non-empty trimmed item:
    - If numeric PID (`string.match(item, "^%d+$")`):
      `"(kill -15 " .. item .. " 2>/dev/null; sleep 0.3; kill -9 " .. item .. " 2>/dev/null)"`
    - If process name:
      Sanitize quotes (`string.gsub(item, "['\\]", "")`), then:
      `"((pkill -15 -x '" .. safe .. "' 2>/dev/null || killall -15 '" .. safe .. "' 2>/dev/null || flatpak kill '" .. safe .. "' 2>/dev/null); (sleep 0.3 && (pkill -9 -x '" .. safe .. "' 2>/dev/null || killall -9 '" .. safe .. "' 2>/dev/null)))"`
  - Combine all sub-commands into a background block: `table.concat(cmds, " & ") .. " &"`.
  - Execute via `noctalia.runAsync(cmd)`.

#### Notification & Logging
- Extract clean target names.
- If 1 item: `"Kill Process (spotify)"`.
- If 2 items: `"Kill Process (spotify, discord)"`.
- If > 2 items: `"Kill Process (spotify, discord, +N more)"`.
- Notify user via `noctalia.notify("Sleepy Time", noctalia.tr("notification.executed", { action = actLabel }))`.
- Log full command string to `noctalia.log`.

---

### 3.3. Presentation & Formatting (`widget.luau`, `desktop.luau`, `panel.luau`)

#### Target Summary Formatter
```luau
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

- **Bar Widget (`widget.luau`)**:
  - Detailed mode: `• " .. formatTargetSummary(state.actionTarget, 1)` (e.g. `• spotify (+2)`).
  - Tooltip: Shows full list of processes.
- **Desktop Widget (`desktop.luau`)**:
  - Footer / compact label: `Kill Process: " .. formatTargetSummary(state.actionTarget, 1)`.
- **Panel Active View (`panel.luau`)**:
  - Sub-info text: `Ends at 14:30 • " .. formatTargetSummary(state.actionTarget, 2)`.

---

## 4. Error Handling & Edge Cases

1. **Empty Target**: If no process is selected or string is whitespace, fallback gracefully without running a broken kill command.
2. **Duplicate Selections**: Parsing into sets and deduplicating preserves clean lists when clicking or typing.
3. **Special Characters / Shell Injection Prevention**: All process names sanitized with `string.gsub(name, "['\\]", "")` before shell interpolation.
4. **Mixed Processes and PIDs**: Gracefully supports comma-separated combinations of process names and PIDs (e.g., `spotify, 18492, discord`).

---

## 5. Verification Plan

1. **Unit / Parsing Verification**:
   - Verify `parseProcessSet` and `formatProcessList` with single, multiple, and empty inputs.
2. **UI Interactivity**:
   - Toggle cards in setup panel, verify active highlight and comma-separated input sync.
   - Verify typing in input box highlights corresponding cards.
3. **Execution & Termination**:
   - Start timer with multiple targets, verify combined kill command generation and logging.
4. **Display Verification**:
   - Verify correct label and count summary in bar widget, desktop widget, and active panel view.
