#!/usr/bin/env python3
"""Build the fallback fonts for non-Latin languages from assets/i18n/strings.csv.

Cinzel and Outfit only cover Latin. For Khmer, Thai, Cyrillic, Chinese, Japanese
and Korean the UI falls back to Noto fonts. Full Noto CJK fonts are 10-20 MB
each, so this script downloads them once (into tools/.font_cache, git-ignored)
and keeps only the characters the translations actually use. All OpenType
layout features are kept so complex scripts (Khmer, Thai) still shape
correctly (subscript consonants, vowel placement, ligatures).

Run it again whenever strings.csv gains new characters; the test suite fails
(test_localization: fonts cover every translation) if a glyph is missing.

    python3 tools/build_fonts.py

Requires fontTools (pip install fonttools).
"""
import csv
import os
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "assets", "i18n", "strings.csv")
CACHE = os.path.join(ROOT, "tools", ".font_cache")
OUT_DIR = os.path.join(ROOT, "assets", "fonts", "fallback")
BASE_URL = "https://github.com/google/fonts/raw/main/ofl/"

# (output name, source path in google/fonts, locales whose text it must cover).
# None = every locale (used for scripts that appear in several languages).
FONTS = [
    ("NotoSans-Subset.ttf", "notosans/NotoSans%5Bwdth,wght%5D.ttf", None),
    ("NotoSansKhmer-Subset.ttf", "notosanskhmer/NotoSansKhmer%5Bwdth,wght%5D.ttf", ["km"]),
    ("NotoSansThai-Subset.ttf", "notosansthai/NotoSansThai%5Bwdth,wght%5D.ttf", ["th"]),
    ("NotoSansSC-Subset.ttf", "notosanssc/NotoSansSC%5Bwght%5D.ttf", ["zh_CN"]),
    ("NotoSansJP-Subset.ttf", "notosansjp/NotoSansJP%5Bwght%5D.ttf", ["ja"]),
    ("NotoSansKR-Subset.ttf", "notosanskr/NotoSansKR%5Bwght%5D.ttf", ["ko"]),
    ("NotoSansDevanagari-Subset.ttf", "notosansdevanagari/NotoSansDevanagari%5Bwdth,wght%5D.ttf", ["hi"]),
]
# Languages whose whole text is drawn with one Noto font instead of Cinzel/Outfit, because
# those lack many of its letters and a word mixing two fonts looks uneven:
# (output name, source, locale). Covers ASCII, Latin-1 and the locale's own text.
FULL_FONTS = [
    ("NotoSansVi-Subset.ttf", "notosans/NotoSans%5Bwdth,wght%5D.ttf", "vi"),
]
VIETNAMESE = ("ăâđêôơưàảãáạằẳẵắặầẩẫấậèẻẽéẹềểễếệìỉĩíịòỏõóọồổỗốộờởỡớợùủũúụừửữứựỳỷỹýỵ")
EXTRA_CHARS = {"vi": VIETNAMESE + VIETNAMESE.upper()}
LICENSE_SRC = "notosans/OFL.txt"
# Characters both primary fonts (titles: Cinzel, body: Outfit) already provide.
PRIMARY_FONTS = [os.path.join(ROOT, "assets", "fonts", n) for n in ("Outfit.ttf", "Cinzel.ttf")]


def fetch(rel: str) -> str:
    os.makedirs(CACHE, exist_ok=True)
    local = os.path.join(CACHE, urllib.request.unquote(rel).replace("/", "__"))
    if not os.path.exists(local):
        print(f"  downloading {urllib.request.unquote(rel)}")
        urllib.request.urlretrieve(BASE_URL + rel, local + ".part")
        os.replace(local + ".part", local)
    return local


def read_strings() -> dict:
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    header = rows[0][1:]
    texts = {code: [] for code in header}
    for row in rows[1:]:
        for code, text in zip(header, row[1:]):
            texts[code].append(text)
    # Every language name is shown in every language (the language picker).
    names_row = next(r for r in rows[1:] if r[0] == "LANGUAGE_NAME")
    return texts, "".join(names_row[1:])


def main() -> None:
    texts, names = read_strings()
    primary = set.intersection(*(set(TTFont(p).getBestCmap()) for p in PRIMARY_FONTS))
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    jobs = [(o, r, l, False) for o, r, l in FONTS] + [(o, r, [l], True) for o, r, l in FULL_FONTS]
    for out_name, rel, locales, full in jobs:
        src = fetch(rel)
        cmap = set(TTFont(src).getBestCmap())
        # Languages with a font of their own do not need their letters in the shared one.
        own_font = {l for _, _, l in FULL_FONTS}
        codes = [c for c in texts if c not in own_font] if locales is None else locales
        wanted = set("".join("".join(texts[c]) for c in codes) + names)
        if full:
            wanted = set("".join("".join(texts[c]) for c in codes) + EXTRA_CHARS.get(locales[0], ""))
            wanted |= {chr(c) for c in list(range(0x20, 0x7F)) + list(range(0xA0, 0x100))}
            wanted |= set("–—‘’“”•…×·")
            chars = sorted(ord(ch) for ch in wanted if ord(ch) in cmap)
        else:
            chars = sorted(ord(ch) for ch in wanted if ord(ch) in cmap and ord(ch) not in primary and not ch.isspace())
        opts = subset.Options()
        opts.layout_features = ["*"]  # keep complex-script shaping
        opts.name_IDs = ["*"]
        opts.name_languages = ["*"]
        opts.notdef_outline = True
        opts.hinting = False
        opts.desubroutinize = True
        font = TTFont(src)
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=chars)
        sub.subset(font)
        out = os.path.join(OUT_DIR, out_name)
        font.save(out)
        size = os.path.getsize(out)
        total += size
        print(f"  {out_name}: {len(chars)} characters, {size / 1024:.0f} KB")
    lic = fetch(LICENSE_SRC)
    with open(lic, encoding="utf-8") as f, open(os.path.join(OUT_DIR, "Noto-OFL.txt"), "w", encoding="utf-8") as o:
        o.write(f.read())
    print(f"Done: {total / 1024:.0f} KB of fallback fonts in {os.path.relpath(OUT_DIR, ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
