#!/usr/bin/env python3
"""
Generates the curated Unicode dataset for Noctalia's native launcher categories.
Produces unicode/data/unicode.json containing all high-value Unicode characters
organized by categories that match [[launcher_provider.category]] in plugin.toml.
"""
import json
import os
import unicodedata

CATEGORIES = [
    ("Arrows", [
        (0x2190, 0x21FF),  # Arrows
        (0x27F0, 0x27FF),  # Supplemental Arrows-A
        (0x2900, 0x297F),  # Supplemental Arrows-B
        (0x2B00, 0x2BFF),  # Misc Symbols and Arrows
    ]),
    ("Math", [
        (0x2200, 0x22FF),  # Mathematical Operators
        (0x27C0, 0x27EF),  # Misc Mathematical Symbols-A
        (0x2980, 0x29FF),  # Misc Mathematical Symbols-B
        (0x2A00, 0x2AFF),  # Supplemental Mathematical Operators
    ]),
    ("Currency", [
        (0x0024, 0x0024),  # Dollar sign $
        (0x00A2, 0x00A5),  # Cent, Pound, Currency, Yen
        (0x20A0, 0x20CF),  # Currency Symbols
    ]),
    ("Symbols", [
        (0x2600, 0x26FF),  # Miscellaneous Symbols
        (0x2700, 0x27BF),  # Dingbats
        (0x2300, 0x23FF),  # Miscellaneous Technical
        (0x2800, 0x28FF),  # Braille Patterns
    ]),
    ("Box Drawing", [
        (0x2500, 0x257F),  # Box Drawing
        (0x2580, 0x259F),  # Block Elements
        (0x25A0, 0x25FF),  # Geometric Shapes
    ]),
    ("Typography", [
        (0x2000, 0x206F),  # General Punctuation
        (0x2E00, 0x2E7F),  # Supplemental Punctuation
    ]),
    ("Numbers", [
        (0x2070, 0x209F),  # Superscripts and Subscripts
        (0x2150, 0x218F),  # Number Forms (fractions, Roman numerals)
    ]),
    ("Letterlike", [
        (0x00A9, 0x00A9),  # Copyright ©
        (0x00AE, 0x00AE),  # Registered ®
        (0x2100, 0x214F),  # Letterlike Symbols (™, ℃, ℉, №, etc.)
        (0x2460, 0x24FF),  # Enclosed Alphanumerics
    ]),
    ("Greek", [
        (0x0370, 0x03FF),  # Greek and Coptic
    ]),
    ("Latin", [
        (0x00C0, 0x024F),  # Latin-1 Supplement + Latin Extended A & B
    ]),
]

def main():
    seen_cps = set()
    entries = []

    for cat_name, ranges in CATEGORIES:
        for start, end in ranges:
            for cp in range(start, end + 1):
                if cp in seen_cps:
                    continue
                try:
                    ch = chr(cp)
                    cat_code = unicodedata.category(ch)
                    # Skip invisible control and separator characters
                    if cat_code in ("Cc", "Zl", "Zp", "Cs"):
                        continue
                    name = unicodedata.name(ch)
                    seen_cps.add(cp)
                    hex_code = hex(cp)[2:].upper().zfill(4)
                    entries.append([hex_code, ch, name, cat_name])
                except ValueError:
                    pass

    out_dir = os.path.dirname(os.path.abspath(__file__))
    out_file = os.path.join(out_dir, "unicode.json")

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(entries, f, separators=(",", ":"), ensure_ascii=False)

    print(f"Generated {len(entries)} characters in {out_file} ({os.path.getsize(out_file) / 1024:.2f} KB)")

if __name__ == "__main__":
    main()
