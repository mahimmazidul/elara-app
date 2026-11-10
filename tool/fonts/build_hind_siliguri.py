#!/usr/bin/env python3
"""Adds real tabular numerals to the bundled Hind Siliguri files.

Hind Siliguri's digits are proportional: the "1" is 323 units wide and the
"0" is 544. Asking Flutter for `FontFeature.tabularFigures()` would do
nothing, because the font's GSUB table has no `tnum` feature at all, and
every value that updates in place - the countdown, the heat index, the cycle
day - would shift sideways as its digits changed.

The app already depends on that not happening: DM Sans had the same problem
and tool/fonts/build_fonts.py fixed it. This script does the same for
Hind Siliguri, so that swapping the family does not quietly break it.

Run from the repository root:

    pip install fonttools
    python3 tool/fonts/build_hind_siliguri.py

The inputs are the four static Hind Siliguri files, which are committed, so
the app build never needs Python or the network. The outputs are committed
too.
"""

import copy
import os
import sys

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")

# The four weights the app bundles. 600 is there so that a caller asking for
# semibold gets real semibold rather than a synthesised fake.
FILES = [
    "HindSiliguri-Regular.ttf",
    "HindSiliguri-Medium.ttf",
    "HindSiliguri-SemiBold.ttf",
    "HindSiliguri-Bold.ttf",
]

DIGITS = "0123456789"


def add_tabular_digits(font: TTFont) -> None:
    """Adds tabular variants of every digit plus a `tnum` feature for them."""
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()

    names = [cmap[ord(d)] for d in DIGITS]
    advances = [hmtx[name][0] for name in names]

    # One shared width, wide enough for the widest digit so nothing collides.
    tabular_width = max(advances)

    # A copy: the font and glyf tables share this list, and adding a glyph to
    # glyf appends to it, so holding the original reference would double-count.
    order = list(font.getGlyphOrder())
    new_glyphs = []

    for name in names:
        variant = f"{name}.tnum"
        glyph = copy.deepcopy(glyf[name])

        # Re-centre the outline inside the shared advance, otherwise each digit
        # would sit hard against the left edge of its narrower cell.
        offset = (tabular_width - hmtx[name][0]) / 2
        if offset:
            glyph.coordinates.translate((offset, 0))
            glyph.recalcBounds(glyf)

        glyf[variant] = glyph
        hmtx[variant] = (tabular_width, glyph.xMin)
        new_glyphs.append(variant)

    # The font and the glyf table each cache a glyph order, and the feature
    # compiler reads the font's. All three have to agree.
    new_order = order + new_glyphs
    font.setGlyphOrder(new_order)
    glyf.glyphOrder = font.getGlyphOrder()

    substitutions = "\n".join(
        f"    sub {name} by {name}.tnum;" for name in names
    )

    addOpenTypeFeaturesFromString(
        font,
        f"""
        languagesystem DFLT dflt;
        languagesystem latn dflt;

        feature tnum {{
{substitutions}
        }} tnum;
        """,
    )


def main() -> int:
    for filename in FILES:
        path = os.path.join(OUT_DIR, filename)
        if not os.path.exists(path):
            print(f"missing: {path}", file=sys.stderr)
            return 1

        font = TTFont(path)
        add_tabular_digits(font)
        font.save(path)

        # The cmap keeps pointing at the proportional glyphs; the feature
        # swaps in the tabular ones at shaping time, so those are the ones to
        # measure.
        check = TTFont(path)
        widths = {
            d: check["hmtx"][f"{check.getBestCmap()[ord(d)]}.tnum"][0]
            for d in DIGITS
        }
        features = {
            record.FeatureTag
            for record in check["GSUB"].table.FeatureList.FeatureRecord
        }
        unique = set(widths.values())
        print(
            f"{filename}: {os.path.getsize(path) // 1024} KB, "
            f"tnum={('tnum' in features)}, digit widths={sorted(unique)}"
        )
        if len(unique) != 1 or "tnum" not in features:
            print("  ERROR: tabular digits were not applied", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
