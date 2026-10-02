# Unicode

Fast Unicode character search and picker. Browse symbols, math, arrows, and copy characters or codepoints instantly.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/unicode` |
| Entries | Launcher: `search` |
| Launcher Prefix | `/uni` |

## Usage

Type `/uni` in the Noctalia launcher to browse popular Unicode categories (Arrows, Mathematical Operators, Currency Symbols, Box Drawing, Dingbats, Greek, and more). Selecting a category filters within that set.

To search directly, type `/uni` followed by a character name, keyword, or hex code:

- `/uni arrow right` — finds `→`, `⇒`, `➔`, etc.
- `/uni copyright` — finds `©`
- `/uni infinity` — finds `∞`
- `/uni 00a9` or `/uni U+2192` — finds character by hex codepoint

Press `Enter` or click on any character to copy it to your clipboard.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `copy_format` | `select` | `character` | What to copy when activating a result: `character` (`©`), `codepoint` (`U+00A9`), or `both` (`© (U+00A9)`). |
| `notify_on_copy` | `bool` | `true` | Show a desktop toast notification when a character is copied. |
| `max_results` | `int` | `30` | Maximum number of results to display in the launcher (10–100). |

## Notes

- Includes ~40,000 officially named Unicode characters across all Unicode blocks (excluding mass CJK ideographs for optimal search speed and lightweight memory).
- Sub-millisecond search performance with zero startup delay and in-memory memoization.
- Completely local and offline: no external network requests or commands spawned.
