# Keybinds Chord & Sequence Display Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support chorded (Tmux `CTRL + A, D`) and sequential (Neovim `Leader f f`) keybinding display and fix the tight spacing between highlight pills and separator symbols in the Noctalia keybinds plugin.

**Architecture:** Extend `keybinds/parser.luau` to parse key combo strings into structured `{KeyToken}` arrays containing separator metadata (`+`, `,`, ` `). Update `keybinds/components.luau` to render badges with `gap = 6` and appropriate separator glyphs. Update `keybinds/crud.luau` and `keybinds/modals.luau` to support direct key combo string editing. Update `presets.luau` and user's `custom_keybinds.json`.

**Tech Stack:** Luau (Noctalia Plugin API 28+), Python (pytest test runner).

## Global Constraints
- Noctalia v5 (Plugin API 28+).
- Luau `--!nonstrict`.
- Preserve existing card interaction (`onCopy`, `onEdit`, `onDelete`).
- Backward compatible with existing array `keys` format `["CTRL", "SHIFT", "C"]`.
- All existing tests in `tests/test_keybinds*.py` must continue to pass.

---

### Task 1: Parser Token Parsing & Data Ingestion

**Files:**
- Modify: `keybinds/parser.luau:170-280`
- Test: `tests/test_keybinds_parser.py`

**Interfaces:**
- Produces: `parser.parseKeyTokens(raw: string | { string }): ({ KeyToken }, string)`
  where `KeyToken` = `{ text: string, isPrimary: boolean, sepAfter: string? }`
- Modifies: `parser.parseCustomKeybinds(rawJson: string): { KeybindItem }` to attach `tokens = tokens` to each item.

- [ ] **Step 1: Write failing tests for `parse_key_tokens` in `tests/test_keybinds_parser.py`**

Add unit tests in `tests/test_keybinds_parser.py` validating:
1. Tmux chord: `"CTRL + A, D"` $\rightarrow$ tokens `[("CTRL", False, "+"), ("A", False, ","), ("D", True, None)]`, combo `"CTRL + A, D"`.
2. Tmux double chord: `"CTRL + A, CTRL + S"` $\rightarrow$ tokens `[("CTRL", False, "+"), ("A", False, ","), ("CTRL", False, "+"), ("S", True, None)]`.
3. Neovim sequence: `"Leader f f"` $\rightarrow$ tokens `[("LEADER", False, " "), ("F", False, " "), ("F", True, None)]`, combo `"Leader f f"`.
4. Neovim 2-key sequence: `"g d"` $\rightarrow$ tokens `[("G", False, " "), ("D", True, None)]`.
5. Standard simultaneous: `"CTRL + SHIFT + C"` $\rightarrow$ tokens `[("CTRL", False, "+"), ("SHIFT", False, "+"), ("C", True, None)]`.
6. Backward compatibility array: `["CTRL", "SHIFT", "C"]` $\rightarrow$ parses as simultaneous combo.

```python
    def test_parse_key_tokens_tmux(self):
        # Verification of Python representation matching parser logic
        tokens, combo = parse_key_tokens("CTRL + A, D")
        self.assertEqual(combo, "CTRL + A, D")
        self.assertEqual(len(tokens), 3)
        self.assertEqual(tokens[0]["text"], "CTRL")
        self.assertEqual(tokens[0]["sepAfter"], "+")
        self.assertEqual(tokens[1]["text"], "A")
        self.assertEqual(tokens[1]["sepAfter"], ",")
        self.assertEqual(tokens[2]["text"], "D")
        self.assertTrue(tokens[2]["isPrimary"])
        self.assertIsNone(tokens[2]["sepAfter"])

    def test_parse_key_tokens_neovim(self):
        tokens, combo = parse_key_tokens("Leader f f")
        self.assertEqual(combo, "Leader f f")
        self.assertEqual(len(tokens), 3)
        self.assertEqual(tokens[0]["text"], "LEADER")
        self.assertEqual(tokens[0]["sepAfter"], " ")
        self.assertEqual(tokens[1]["text"], "F")
        self.assertEqual(tokens[1]["sepAfter"], " ")
        self.assertEqual(tokens[2]["text"], "F")
        self.assertTrue(tokens[2]["isPrimary"])
        self.assertIsNone(tokens[2]["sepAfter"])
```

- [ ] **Step 2: Run pytest to verify new tests fail**

Run: `pytest tests/test_keybinds_parser.py -v`
Expected: FAIL (`parse_key_tokens` not defined or not imported).

- [ ] **Step 3: Implement `parser.parseKeyTokens` in `keybinds/parser.luau` and update Python test helper**

Add `parser.parseKeyTokens` in `keybinds/parser.luau`:
```luau
export type KeyToken = {
  text: string,
  isPrimary: boolean,
  sepAfter: string?,
}

function parser.parseKeyTokens(raw: any): ({ KeyToken }, string)
  local tokens: { KeyToken } = {}
  local comboText = ""

  if type(raw) == "table" then
    local parts = {}
    for _, k in ipairs(raw) do
      if type(k) == "string" and k ~= "" then
        table.insert(parts, k)
      end
    end
    -- If array contains a single preformatted string like "CTRL + A, D"
    if #parts == 1 and (string.find(parts[1], ",") or string.find(parts[1], "+") or string.find(parts[1], " ")) then
      return parser.parseKeyTokens(parts[1])
    end
    -- Otherwise treat as standard combo array
    for i, p in ipairs(parts) do
      local isLast = (i == #parts)
      table.insert(tokens, {
        text = string.upper(p),
        isPrimary = isLast,
        sepAfter = if not isLast then "+" else nil,
      })
    end
    comboText = table.concat(parts, " + ")
    return tokens, comboText
  end

  if type(raw) ~= "string" or raw == "" then
    return tokens, ""
  end

  comboText = raw

  -- Split into steps by comma `,`
  local steps = {}
  for step in string.gmatch(raw .. ",", "([^,]+),") do
    local trimmed = string.match(step, "^%s*(.-)%s*$") or ""
    if trimmed ~= "" then
      table.insert(steps, trimmed)
    end
  end

  if #steps == 0 then
    local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
    if trimmed ~= "" then
      table.insert(steps, trimmed)
    end
  end

  for sIdx, stepStr in ipairs(steps) do
    local isLastStep = (sIdx == #steps)
    if string.find(stepStr, "+", 1, true) then
      -- Simultan split by `+`
      local subKeys = {}
      for k in string.gmatch(stepStr .. "+", "([^+]+)%+") do
        local tk = string.match(k, "^%s*(.-)%s*$") or ""
        if tk ~= "" then
          table.insert(subKeys, tk)
        end
      end
      for kIdx, k in ipairs(subKeys) do
        local isLastKeyInStep = (kIdx == #subKeys)
        local isFinalAction = isLastStep and isLastKeyInStep
        local sep = nil
        if not isLastKeyInStep then
          sep = "+"
        elseif not isLastStep then
          sep = ","
        end
        table.insert(tokens, {
          text = string.upper(k),
          isPrimary = isFinalAction,
          sepAfter = sep,
        })
      end
    else
      -- Check if space-separated sequence (e.g. "Leader f f")
      local subKeys = {}
      for k in string.gmatch(stepStr, "%S+") do
        table.insert(subKeys, k)
      end
      if #subKeys > 1 then
        for kIdx, k in ipairs(subKeys) do
          local isLastKeyInStep = (kIdx == #subKeys)
          local isFinalAction = isLastStep and isLastKeyInStep
          local sep = nil
          if not isLastKeyInStep then
            sep = " "
          elseif not isLastStep then
            sep = ","
          end
          table.insert(tokens, {
            text = string.upper(k),
            isPrimary = isFinalAction,
            sepAfter = sep,
          })
        end
      else
        local k = subKeys[1] or stepStr
        local isFinalAction = isLastStep
        table.insert(tokens, {
          text = string.upper(k),
          isPrimary = isFinalAction,
          sepAfter = if not isLastStep then "," else nil,
        })
      end
    end
  end

  return tokens, comboText
end
```

In `parser.parseCustomKeybinds`, replace the modifier/primaryKey loop with:
```luau
local tokens, combo = parser.parseKeyTokens(b.keys)
local mods = {}
local primaryKey = ""
for _, tok in ipairs(tokens) do
  if tok.isPrimary then
    primaryKey = tok.text
  else
    table.insert(mods, tok.text)
  end
end
```
and include `tokens = tokens` in the inserted item.

- [ ] **Step 4: Run pytest to verify parser tests pass**

Run: `pytest tests/test_keybinds_parser.py -v`
Expected: PASS.

- [ ] **Step 5: Commit Task 1 changes**

```bash
git add keybinds/parser.luau tests/test_keybinds_parser.py
git commit -m "feat(keybinds): implement parseKeyTokens supporting chords and sequences"
```

---

### Task 2: Component Badge Rendering & Spacing

**Files:**
- Modify: `keybinds/components.luau:21-35, 115-125`
- Test: `tests/test_keybinds_components.py`

**Interfaces:**
- Consumes: `item.tokens: { KeyToken }`
- Renders:
  - `ui.row({ gap = 6, align = "center" }, kbdBadges)`
  - Badge with `components.renderKbdBadge(tok.text, tok.isPrimary, cornerRadiusScale)`
  - Separators: `+` label, `,` label, or no label for ` ` (handled by row gap).

- [ ] **Step 1: Write test in `tests/test_keybinds_components.py` checking for token handling, comma separator, and `gap = 6`**

Add assertions in `tests/test_keybinds_components.py`:
- Checks `components.luau` renders `item.tokens` if available.
- Checks `components.luau` uses `gap = 6` (or at least $\ge 5$) on the badges row.
- Checks `components.luau` handles `sepAfter == ","` and `sepAfter == "+"`.

- [ ] **Step 2: Run pytest to verify test fails**

Run: `pytest tests/test_keybinds_components.py -v`
Expected: FAIL (missing token handling / gap = 6).

- [ ] **Step 3: Update `keybinds/components.luau`**

Update `components.renderKbdBadges`:
```luau
function components.renderKbdBadges(itemOrMods: any, keyOrScale: any, maybeScale: any): { any }
  local kbdBadges = {}
  local cornerRadiusScale = 1.0

  if type(itemOrMods) == "table" and itemOrMods.tokens ~= nil then
    cornerRadiusScale = keyOrScale or 1.0
    for _, tok in ipairs(itemOrMods.tokens) do
      table.insert(kbdBadges, components.renderKbdBadge(tok.text, tok.isPrimary, cornerRadiusScale))
      if tok.sepAfter == "+" then
        table.insert(kbdBadges, ui.label({ text = "+", fontSize = 9, color = "on_surface_variant" }))
      elseif tok.sepAfter == "," then
        table.insert(kbdBadges, ui.label({ text = ",", fontSize = 11, fontWeight = "bold", color = "on_surface_variant" }))
      end
    end
    return kbdBadges
  end

  -- Legacy signature fallback: renderKbdBadges(modifiers: {string}, key: string, cornerRadiusScale: number)
  local modifiers = if type(itemOrMods) == "table" then itemOrMods else {}
  local key = if type(keyOrScale) == "string" then keyOrScale else ""
  cornerRadiusScale = maybeScale or 1.0

  for _, m in ipairs(modifiers) do
    table.insert(kbdBadges, components.renderKbdBadge(string.upper(m), false, cornerRadiusScale))
    table.insert(kbdBadges, ui.label({ text = "+", fontSize = 9, color = "on_surface_variant" }))
  end
  if key ~= "" then
    table.insert(kbdBadges, components.renderKbdBadge(string.upper(key), true, cornerRadiusScale))
  end
  return kbdBadges
end
```

In `components.renderKeybindCard`:
Call:
```luau
local kbdBadges = components.renderKbdBadges(item, cornerRadiusScale)
```
and update row:
```luau
    ui.row({ gap = 4, align = "center" }, {
      ui.row({ gap = 6, align = "center" }, kbdBadges),
      cardActions,
    }),
```

- [ ] **Step 4: Run pytest to verify tests pass**

Run: `pytest tests/test_keybinds_components.py -v`
Expected: PASS.

- [ ] **Step 5: Commit Task 2 changes**

```bash
git add keybinds/components.luau tests/test_keybinds_components.py
git commit -m "fix(keybinds): refine badge row spacing to gap=6 and support token separators"
```

---

### Task 3: Modal & CRUD Integration

**Files:**
- Modify: `keybinds/crud.luau:65-135, 174-194`
- Modify: `keybinds/modals.luau:480-530`
- Test: `tests/test_keybinds_crud.py`
- Test: `tests/test_keybinds_modals.py`

**Interfaces:**
- `crud.addKeybind(store, appName, subcatName, description, keyCombo, appIcon?, subcatIcon?): (boolean, string?)`
- `crud.updateKeybind(store, origApp, origSubcat, origBindIdx, newApp, newSubcat, newDesc, newKeyCombo, newAppIcon?, newSubcatIcon?): (boolean, string?)`
- Accepts string combo like `"CTRL + A, D"` or legacy `(modifiers, primaryKey)`.

- [ ] **Step 1: Write tests in `tests/test_keybinds_crud.py` for adding and updating keybind with combo string**

Add test cases in `tests/test_keybinds_crud.py`:
- `test_add_keybind_combo_string`: adds keybind with `"CTRL + A, D"`, verifies `keys` in store is `"CTRL + A, D"`.
- `test_backward_compat_add`: verifies legacy `(modifiers, primaryKey)` arguments still work.

- [ ] **Step 2: Run pytest to verify tests fail**

Run: `pytest tests/test_keybinds_crud.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement combo string support in `keybinds/crud.luau` and `keybinds/modals.luau`**

Update `crud.luau`:
Support both `keyCombo: string` and legacy `(modifiers: {string}, primaryKey: string)`. If 5th parameter is a string, treat as `keyCombo`. Store as `"keys": cleanKeyCombo`.

Update `modals.luau`:
- In `renderAddModal`, replace Primary Key input label with Key Combo (`tr("modal.key_combo_label") or "Key Combination"`), and placeholder: `"e.g. CTRL + SHIFT + C, CTRL + A, D, or Leader f f"`.
- Make modifier buttons (`SUPER`, `CTRL`, `ALT`, `SHIFT`) append to the key combo field if not already present.

- [ ] **Step 4: Run pytest to verify tests pass**

Run: `pytest tests/test_keybinds_crud.py tests/test_keybinds_modals.py -v`
Expected: PASS.

- [ ] **Step 5: Commit Task 3 changes**

```bash
git add keybinds/crud.luau keybinds/modals.luau tests/test_keybinds_crud.py tests/test_keybinds_modals.py
git commit -m "feat(keybinds): allow direct key combo string input in CRUD and modals"
```

---

### Task 4: Presets, User Data Migration, and Full Verification

**Files:**
- Modify: `keybinds/presets.luau`
- Modify: `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json`
- Test: `tests/test_keybinds_parser.py`, `tests/test_keybinds_panel.py`

- [ ] **Step 1: Update `keybinds/presets.luau`**

Update Neovim and Tmux binds in `presets.luau`:
- Neovim binds converted from arrays to strings: `"Leader f f"`, `"Leader f g"`, `"g d"`, `"K"`, `"Leader e"`, `"Leader w"`, `"Leader q"`.
- Add official Tmux preset section with canonical `"CTRL + A, <key>"` chords (e.g. `"CTRL + A, D"`, `"CTRL + A, :"`, `"CTRL + A, CTRL + S"`, etc.).

- [ ] **Step 2: Migrate active `custom_keybinds.json`**

Read `~/.local/state/noctalia/plugins/data/rigelyon/keybinds/custom_keybinds.json` and convert:
- All Tmux binds with `["CTRL", "A", "..."]` to `"CTRL + A, ..."` (e.g. `"CTRL + A, D"`, `"CTRL + A, :"`).
- All Neovim binds to `"Leader f f"`, `"g d"`, etc.
- Seamless Navigation binds to `"CTRL + H"`, `"CTRL + J"`, `"CTRL + K"`, `"CTRL + L"`.

- [ ] **Step 3: Run the full test suite**

Run: `pytest tests/test_keybinds*.py -v`
Expected: All 25+ tests pass with 100% success rate.

- [ ] **Step 4: Commit Task 4 changes**

```bash
git add keybinds/presets.luau tests/test_keybinds_parser.py
git commit -m "feat(keybinds): update presets and migrate custom keybinds to chord/sequence strings"
```

---
