# Sleepy Time Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Noctalia Sleepy Time plugin (`rigelyon/sleepy-time`) to Noctalia Plugin API Level 28 with a reactive headless engine, modern declarative UI closures, multi-tier warning alerts, resilient Wayland compositor fallbacks, and clean UI components.

**Architecture:** A single-source-of-truth headless background engine (`service.luau`) publishes state to `noctalia.state` and listens to `sleepy.cmd`. The bar widget (`widget.luau`), setup & control panel (`panel.luau`), and desktop widget (`desktop.luau`) are thin declarative clients that react to state changes and dispatch user intents.

**Tech Stack:** Noctalia Plugin API Level 28, Luau (`--!nonstrict`), Noctalia declarative UI (`ui.*`, `panel.*`, `barWidget.*`, `desktopWidget.*`, `noctalia.*`).

## Global Constraints
- Noctalia Plugin API level: 28 (`plugin_api = 28`)
- Plugin ID: `rigelyon/sleepy-time`
- No remote code downloading; unsandboxed trusted Luau
- Single config accessor: `noctalia.getConfig(key)`
- All translation keys in `plugin.toml` must exist in `translations/en.json`
- Preserve all existing functionality while modernizing to the latest API standards

---

### Task 1: Manifest (`plugin.toml`) and English Translations (`translations/en.json`)

**Files:**
- Modify: `sleepy-time/plugin.toml`
- Modify: `sleepy-time/translations/en.json`

**Interfaces:**
- Consumes: Spec definition for manifest and translation keys.
- Produces: Valid `plugin.toml` with `plugin_api = 28`, 4 entries (`service`, `widget`, `panel`, `desktop`), declared settings, and 100% matched `translations/en.json`.

- [ ] **Step 1: Write modernized `plugin.toml`**

Write `sleepy-time/plugin.toml` with `plugin_api = 28`, settings, and entries.

- [ ] **Step 2: Write complete `translations/en.json`**

Write `sleepy-time/translations/en.json` with all keys for actions, buttons, modes, notifications, panel titles/labels, settings, and statuses.

- [ ] **Step 3: Validate TOML syntax and translation key coverage**

Verify that all keys referenced in `plugin.toml` (`label_key`, `description_key`, `options.label_key`) exist in `translations/en.json`.

- [ ] **Step 4: Commit**

```bash
git add sleepy-time/plugin.toml sleepy-time/translations/en.json
git commit -m "feat(manifest): modernize plugin.toml to api 28 and update en translations"
```

---

### Task 2: Headless Service Engine (`service.luau`)

**Files:**
- Modify: `sleepy-time/service.luau`

**Interfaces:**
- Consumes: `noctalia.state`, `noctalia.getConfig`, `noctalia.runAsync`, `noctalia.notify`, `noctalia.appIconPath`.
- Produces: `sleepy.state`, `sleepy.presets`, `sleepy.processes`, and handles `sleepy.cmd` (`start`, `pause`, `resume`, `cancel`, `addTime`, `fetchProcesses`).

- [ ] **Step 1: Implement State Model and Config Loader**

Initialize default configurations, timer internal state, and state publishing helper `publishState()`.

- [ ] **Step 2: Implement Scheduled At-Time & Action Execution Logic**

Implement `calculateSecondsUntil(targetHHMM)` with overnight handling, and `executeAction()` with fallback commands for Lock, Suspend, Shutdown, Reboot, Log Out, Kill Process, and Custom Command.

- [ ] **Step 3: Implement Process Listing and Command Dispatcher**

Implement `fetchRunningProcesses()` using `ps -u $(whoami)` + `noctalia.appIconPath`, and `noctalia.state.watch("sleepy.cmd", ...)`.

- [ ] **Step 4: Implement Main Countdown Tick and Multi-tier Warning Logic**

Implement `update()` to tick every second when running, trigger multi-tier notifications at <= 60s, <= 30s, and <= 10s thresholds, and fire `executeAction()` at 0s. Implement `onConfigChanged()` and `onExit()`.

- [ ] **Step 5: Validate Service Syntax & State Lifecycle**

Ensure Luau syntax is error-free and variables match expected shapes.

- [ ] **Step 6: Commit**

```bash
git add sleepy-time/service.luau
git commit -m "feat(service): rewrite headless timer engine with multi-tier warnings and fallbacks"
```

---

### Task 3: Declarative Setup & Control Panel (`panel.luau`)

**Files:**
- Modify: `sleepy-time/panel.luau`

**Interfaces:**
- Consumes: `sleepy.state`, `sleepy.presets`, `sleepy.processes`, `panel.render()`, `panel.close()`.
- Produces: Dispatches commands to `sleepy.cmd`, closes panel on start.

- [ ] **Step 1: Implement Panel State & Formatting Helpers**

Setup local UI state (mode, duration input, target time, selected action, process/cmd), time parsers (`parseTimeStringToSeconds`), and formatting helpers.

- [ ] **Step 2: Implement Idle Setup View**

Build the declarative tree for Setup mode: Mode toggle (Countdown vs At Time), quick preset buttons, custom time input, action grid with icons, process picker for "Kill App", custom command input, and Start button (which starts timer and calls `panel.close()`).

- [ ] **Step 3: Implement Active Running / Paused Control View**

Build the declarative tree for Active mode: Large timer readout, progress bar, action badge, Pause/Resume button, +5m / -5m buttons, and Cancel button.

- [ ] **Step 4: Implement Lifecycle and Event Watches**

Implement `onOpen(_context)`, `noctalia.state.watch("sleepy.state", ...)`, and `noctalia.state.watch("sleepy.processes", ...)`.

- [ ] **Step 5: Validate Panel UI Syntax & Closures**

Ensure render-scoped closures and UI tree construction conform strictly to `noctalia.d.luau`.

- [ ] **Step 6: Commit**

```bash
git add sleepy-time/panel.luau
git commit -m "feat(panel): rebuild setup and control panel with declarative closures"
```

---

### Task 4: Bar Widget (`widget.luau`) and Desktop Widget (`desktop.luau`)

**Files:**
- Modify: `sleepy-time/widget.luau`
- Modify: `sleepy-time/desktop.luau`

**Interfaces:**
- Consumes: `sleepy.state`, `barWidget.render()`, `barWidget.isVertical()`, `barWidget.setTooltip()`, `barWidget.clearTooltip()`, `desktopWidget.render()`.
- Produces: Status bar presentation and ambient desktop countdown card.

- [ ] **Step 1: Modernize `widget.luau`**

Implement declarative `barWidget.render()` supporting horizontal/vertical bars, state colors (active, paused, warning), safe tooltip management, left-click to toggle panel, and right-click to quick-cancel.

- [ ] **Step 2: Modernize `desktop.luau`**

Implement declarative `desktopWidget.render()` with standard `ui.progress({ progress, fill, width, height, radius })`, support for compact vs card mode, warning highlights, and quick +/- adjustments.

- [ ] **Step 3: Validate Widget Syntaxes**

Check for strict compliance with `noctalia.d.luau`.

- [ ] **Step 4: Commit**

```bash
git add sleepy-time/widget.luau sleepy-time/desktop.luau
git commit -m "feat(widgets): modernize bar and desktop widgets with declarative rendering"
```

---

### Task 5: Documentation (`README.md`) & Overall Verification

**Files:**
- Modify: `sleepy-time/README.md`

**Interfaces:**
- Consumes: Final implementation details.
- Produces: Updated user documentation matching Noctalia v5 format guidelines.

- [ ] **Step 1: Update `sleepy-time/README.md`**

Update README with exact entry IDs, settings documentation, panel toggle commands, IPC specifications, and feature summary.

- [ ] **Step 2: Run Luau Syntax and Lint Verification**

Run validation checks on all `.luau` files and ensure no missing globals or invalid method calls.

- [ ] **Step 3: Verify Catalog & Manifest Integrity**

Confirm `plugin.toml` matches repo conventions (ID, version, API level, entries, tags).

- [ ] **Step 4: Commit**

```bash
git add sleepy-time/README.md
git commit -m "docs: update sleepy-time README with API 28 features"
```
