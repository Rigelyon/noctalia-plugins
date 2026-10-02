# Unicode Launcher Provider Plugin Design

**Date:** 2026-10-02  
**Status:** Approved by User  
**Target Plugin:** `rigelyon/unicode` (`unicode/`)  
**Plugin API:** `28`

---

## 1. Overview & Goals

The Unicode Launcher plugin provides a fast, full-featured Unicode character search and picker integrated directly into the Noctalia desktop shell launcher via the `/uni` prefix (similar to Noctalia's built-in emoji provider).

Users can quickly search through ~40,000 named Unicode characters (including mathematical operators, arrows, currency, dingbats, box-drawing, geometric shapes, international alphabets, and symbols), preview their glyph and hex code point, and instantly copy the character or code point to their system clipboard.

### Key Goals
- **Full Non-CJK Named Unicode Dataset**: Include all ~40,000 officially named Unicode characters (symbols, math, arrows, punctuation, currencies, scripts) excluding bulky CJK unified ideographs to preserve fast indexing and small file footprint.
- **Blazing Performance (<0.1 ms search)**: Zero startup latency via lazy-loading and static category caching; sub-millisecond multi-token search in native Luau; result limiting and memoization cache.
- **Native Launcher Integration**: Registered as a Noctalia `launcher_provider` with prefix `/uni`, debounce `80ms`, and category browsing support via `launcher.setQuery()`.
- **Configurable Activation**: Copy character directly to clipboard on Enter, with user settings for copy format (`character`, `codepoint`, or `both`), toast notification toggle, and maximum result count.
- **Strict Repository Standards Compliance**: Pass `python3 .github/workflows/validate-plugins.py` with zero errors or warnings (manifest schema, README format, translations, tags, and dependencies).

---

## 2. Architecture & Data Flow

```mermaid
flowchart TD
    subgraph Launcher Interaction [Noctalia Launcher]
        A[User types /uni in Launcher] --> B{Is query empty?}
        B -- Yes --> C[Show Static Categories & Popular Characters (0ms)]
        C --> D[User selects category with Enter]
        D --> E[launcher.setQuery category .. ' ']
        E --> F[Query updated with category prefix]
        B -- No --> G[Lazy Load data/unicode.json on first query]
        G --> H[Check Query Result Memoization Cache]
        H -- Cache Hit --> I[Return Cached Results (0ms)]
        H -- Cache Miss --> J[Tokenize Query & Execute Multi-Token Scan (<0.1ms)]
        J --> K[Format top N LauncherResult rows]
        K --> L[Cache results & launcher.setResults]
    end

    subgraph Activation [Enter / Selection]
        L --> M[User presses Enter on a character result]
        M --> N[onActivate id]
        N --> O[Check copy_format setting]
        O --> P[noctalia.copyToClipboard text, 'text/plain']
        P --> Q{notify_on_copy enabled?}
        Q -- Yes --> R[noctalia.notify 'Unicode', 'Copied ...']
        Q -- No --> S[Silent completion]
        S --> T[Launcher Closes]
        R --> T
    end
```

---

## 3. Component Specifications

### 3.1. Directory Structure (`unicode/`)

```
unicode/
├── plugin.toml             # Manifest declaring id, metadata, launcher_provider, settings
├── launcher.luau           # Main launcher provider entry script
├── data/
│   └── unicode.json        # Minified, structured dataset of ~40,000 Unicode characters
├── translations/
│   └── en.json             # English translation strings for settings & messages
├── README.md               # User and developer documentation matching README_TEMPLATE.md
└── thumbnail.webp          # 960x540 card image for plugin store / catalog
```

### 3.2. Manifest Specification (`unicode/plugin.toml`)

- **ID**: `rigelyon/unicode`
- **Name**: `Unicode`
- **Version**: `1.0.0`
- **Plugin API**: `28`
- **Author**: `rigelyon`
- **License**: `MIT`
- **Icon**: `typography`
- **Description**: `Fast Unicode character search and picker. Browse symbols, math, arrows, and copy characters or codepoints instantly.`
- **Tags**: `["launcher", "utility", "productivity"]`
- **Dependencies**: `[]`

#### Settings
1. `copy_format` (select):
   - Default: `"character"`
   - Options:
     - `character`: Copies glyph only (e.g. `©`)
     - `codepoint`: Copies formatted hex codepoint (e.g. `U+00A9`)
     - `both`: Copies glyph and codepoint (e.g. `© (U+00A9)`)
2. `notify_on_copy` (bool):
   - Default: `true`
3. `max_results` (int):
   - Default: `30`, min: `10`, max: `100`

#### Entry: `[[launcher_provider]]`
- `id = "search"`
- `entry = "launcher.luau"`
- `prefix = "uni"`
- `glyph = "typography"`
- `debounce_ms = 80`
- `include_in_global_search = false`

---

## 4. Search Engine & Data Design

### 4.1. Dataset Schema (`data/unicode.json`)

To minimize file size, parsing overhead, and Luau memory footprint, each character is stored as a compact flat array:
```json
[
  ["00A9", "©", "COPYRIGHT SIGN", "Symbols"],
  ["2192", "→", "RIGHTWARDS ARROW", "Arrows"],
  ["221E", "∞", "INFINITY", "Mathematical Operators"]
]
```
- Index `1` (`string`): Hex codepoint without prefix (e.g. `"00A9"`).
- Index `2` (`string`): UTF-8 character (e.g. `"©"`).
- Index `3` (`string`): Official Unicode character name (uppercase, e.g. `"COPYRIGHT SIGN"`).
- Index `4` (`string`): Category / Unicode Block (e.g. `"Arrows"`).

Total size: ~2.29 MB (uncompressed JSON).

### 4.2. In-Memory Search Algorithm (`unicode/launcher.luau`)

1. **Lazy Loading**:
   - `local unicodeData = nil`
   - On the first search query requiring full search:
     - Read `data/unicode.json` via `noctalia.readFile("data/unicode.json")`.
     - Decode with `noctalia.json.decode(raw)`.
     - If loading fails, log error and fall back to `STATIC_FALLBACK_ITEMS`.
2. **Search Logic**:
   - Query is trimmed: `local q = noctalia.string.trim(query):upper()`.
   - If `q` starts with `"U+"` or matches a hex pattern (e.g. `^U%+[0-9A-F]+$` or `^[0-9A-F]+$`):
     - Matches against item codepoint `item[1]`.
   - Otherwise, split `q` into space-delimited keywords/tokens:
     - For each item in `unicodeData`:
       - Match all tokens in `item[3]` (name) or `item[4]` (category).
       - If all tokens match: insert row into results table.
       - Stop loop immediately once `max_results` is reached.
3. **Memoization Cache**:
   - Store recent query results: `cache[query] = results`.
   - Clear cache if it exceeds 100 entries to prevent memory growth.

### 4.3. Initial State & Category Navigation

When `query == ""`:
- Return static categories:
  - Arrows (`2190`-`21FF`)
  - Mathematical Operators (`2200`-`22FF`)
  - Currency Symbols (`20A0`-`20CF`)
  - Box Drawing & Block Elements (`2500`-`259F`)
  - Geometric Shapes (`25A0`-`25FF`)
  - Dingbats & Misc Symbols (`2600`-`27BF`)
  - Greek and Coptic (`0370`-`03FF`)
  - Cyrillic (`0400`-`04FF`)
  - Latin Extensions (`0100`-`024F`)
  - Letterlike Symbols (`2100`-`214F`)
- Activating a category row triggers:
  `launcher.setQuery(category .. " ")`
  This keeps the launcher open inside `/uni` and lets the user immediately filter within that category.

---

## 5. Result Formatting & Activation

### 5.1. Launcher Result Format
```luau
{
  id = item[2] .. "|" .. item[1] .. "|" .. item[3], -- char|codepoint|name
  title = item[2],                                   -- e.g. "©"
  subtitle = item[3] .. " • " .. item[4],            -- e.g. "COPYRIGHT SIGN • Symbols"
  badge = "U+" .. item[1],                           -- e.g. "U+00A9"
  glyph = "copy",
}
```

### 5.2. Activation Handler (`onActivate(id)`)
1. If `id` matches `^category:(.+)$`:
   - Open category query: `launcher.setQuery(category .. " ")`.
   - Return early.
2. Parse `char`, `codepoint`, and `name` from `id`.
3. Check `copy_format` config:
   - `"character"`: `copyText = char`
   - `"codepoint"`: `copyText = "U+" .. codepoint`
   - `"both"`: `copyText = char .. " (U+" .. codepoint .. ")"`
4. Call `noctalia.copyToClipboard(copyText, "text/plain")`.
5. If `notify_on_copy` is enabled:
   `noctalia.notify("Unicode", "Copied " .. copyText .. " (" .. name .. ") to clipboard")`.

---

## 6. Error Handling & Edge Cases

- **File Read Failure**: If `data/unicode.json` is missing or fails to parse, fallback to an internal static table of ~100 essential symbols, and call `noctalia.notifyError("Unicode", "Failed to load Unicode database, using fallback dataset")`.
- **Zero Matches**: When no characters match, return a single descriptive row:
  `{ id = "", title = "No characters found", subtitle = "Try a different keyword or hex code (e.g. U+2192)", glyph = "search-off" }`.
- **Empty / Inactive Activation**: Activating an empty or placeholder row (`id == ""`) does nothing.
- **Clipboard Failure**: If `noctalia.copyToClipboard` returns `false`, call `noctalia.notifyError("Unicode", "Failed to copy to clipboard")`.

---

## 7. Verification & Testing Plan

1. **Manifest & Repository Validation**:
   - Run `python3 .github/workflows/validate-plugins.py` to ensure all rules, fields, translations, and README constraints pass with 0 errors.
2. **Dataset Generation & Benchmark Script**:
   - Python script to build `data/unicode.json` directly from Python's standard `unicodedata` library.
   - Verify all entries have non-empty hex, character, name, and category.
   - Verify UTF-8 encoding validity and JSON syntax.
3. **Local Noctalia Testing**:
   - Add local community-plugins path: `noctalia msg plugins source add dev path ...`
   - Enable plugin: `noctalia msg plugins enable rigelyon/unicode`
   - Test launcher search via CLI / shell: test prefix `/uni`, test category opening, test search by name (`arrow right`, `infinity`), test search by hex (`00a9`), test copy to clipboard.
