#!/usr/bin/env python3
import json
import os
import unicodedata

BLOCKS = [
    (0x0020, 0x007F, "Basic Latin"),
    (0x0080, 0x00FF, "Latin-1 Supplement"),
    (0x0100, 0x017F, "Latin Extended-A"),
    (0x0180, 0x024F, "Latin Extended-B"),
    (0x0250, 0x02AF, "IPA Extensions"),
    (0x02B0, 0x02FF, "Spacing Modifier Letters"),
    (0x0300, 0x036F, "Combining Diacritical Marks"),
    (0x0370, 0x03FF, "Greek and Coptic"),
    (0x0400, 0x04FF, "Cyrillic"),
    (0x0500, 0x052F, "Cyrillic Supplement"),
    (0x0530, 0x058F, "Armenian"),
    (0x0590, 0x05FF, "Hebrew"),
    (0x0600, 0x06FF, "Arabic"),
    (0x0900, 0x097F, "Devanagari"),
    (0x2000, 0x206F, "General Punctuation"),
    (0x2070, 0x209F, "Superscripts and Subscripts"),
    (0x20A0, 0x20CF, "Currency Symbols"),
    (0x2100, 0x214F, "Letterlike Symbols"),
    (0x2150, 0x218F, "Number Forms"),
    (0x2190, 0x21FF, "Arrows"),
    (0x2200, 0x22FF, "Mathematical Operators"),
    (0x2300, 0x23FF, "Miscellaneous Technical"),
    (0x2400, 0x243F, "Control Pictures"),
    (0x2440, 0x245F, "Optical Character Recognition"),
    (0x2460, 0x24FF, "Enclosed Alphanumerics"),
    (0x2500, 0x257F, "Box Drawing"),
    (0x2580, 0x259F, "Block Elements"),
    (0x25A0, 0x25FF, "Geometric Shapes"),
    (0x2600, 0x26FF, "Miscellaneous Symbols"),
    (0x2700, 0x27BF, "Dingbats"),
    (0x27C0, 0x27EF, "Misc Mathematical Symbols-A"),
    (0x27F0, 0x27FF, "Supplemental Arrows-A"),
    (0x2800, 0x28FF, "Braille Patterns"),
    (0x2900, 0x297F, "Supplemental Arrows-B"),
    (0x2980, 0x29FF, "Misc Mathematical Symbols-B"),
    (0x2A00, 0x2AFF, "Supplemental Mathematical Operators"),
    (0x2B00, 0x2BFF, "Misc Symbols and Arrows"),
    (0x2E00, 0x2E7F, "Supplemental Punctuation"),
]

def get_block(cp: int) -> str:
    for start, end, name in BLOCKS:
        if start <= cp <= end:
            return name
    return "Other"

def main():
    entries = []
    for cp in range(0x110000):
        try:
            name = unicodedata.name(chr(cp))
            if not (name.startswith("CJK UNIFIED") or name.startswith("HANGUL SYLLABLE")):
                entries.append([
                    hex(cp)[2:].upper().zfill(4),
                    chr(cp),
                    name,
                    get_block(cp)
                ])
        except ValueError:
            pass

    out_dir = os.path.dirname(os.path.abspath(__file__))
    out_file = os.path.join(out_dir, "unicode.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(entries, f, separators=(",", ":"), ensure_ascii=False)
    print(f"Generated {len(entries)} characters in {out_file}")

if __name__ == "__main__":
    main()
