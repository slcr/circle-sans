#!/usr/bin/env python3
"""Make tabular figures the default in every built font.

`zero.tf` and friends are components of the proportional figures, so this cannot be
done by swapping drawings in the source - it would be circular. Instead we point the
cmap at the .tf glyphs after the build.

Two things have to be kept honest afterwards:
  * frac / numr / dnom / sups / subs / sinf are keyed on the PROPORTIONAL names, so
    they would silently stop firing once the cmap hands them .tf glyphs. Every single
    substitution keyed on a figure therefore also learns the .tf key.
  * pnum already maps .tf -> proportional, so proportional figures stay reachable.

Usage: freeze-figures.py <font.ttf> [font.ttf ...]
"""
import sys
from fontTools.ttLib import TTFont

FIGURES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


def freeze(path):
    font = TTFont(path)
    order = set(font.getGlyphOrder())
    tf = {f: f + ".tf" for f in FIGURES if f + ".tf" in order}
    if not tf:
        return f"{path}: no .tf figures, skipped"

    remapped = 0
    for sub in font["cmap"].tables:
        if not sub.isUnicode():
            continue
        for i, fig in enumerate(FIGURES):
            cp = 0x30 + i
            if cp in sub.cmap and fig in tf:
                sub.cmap[cp] = tf[fig]
                remapped += 1

    taught = 0
    if "GSUB" in font:
        for lookup in font["GSUB"].table.LookupList.Lookup:
            for st in lookup.SubTable:
                mapping = getattr(st, "mapping", None)
                if not mapping:
                    continue
                for fig, alt in tf.items():
                    if fig in mapping and alt not in mapping:
                        mapping[alt] = mapping[fig]
                        taught += 1

    font.save(path)
    return f"{path}: {remapped} codepoints -> tabular, {taught} substitutions taught .tf"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        print(freeze(p))
