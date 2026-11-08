#!/usr/bin/env python3
"""Builds the bundled DM Sans files, with real tabular numerals.

DM Sans ships as one variable font whose digits are proportional, and its GSUB
table has no `tnum` feature at all. Asking Flutter for
`FontFeature.tabularFigures()` would therefore do nothing, and every value that
updates in place (the countdown, the heat index, the cycle day) would shift
sideways as its digits changed.

This script fixes that properly:

  1. Instantiates static weights from the variable font, so the app carries only
     the three weights it uses.
  2. Adds a `tnum` feature: for each digit it creates a copy at one shared
     advance width, with the outline re-centred in that width, and registers a
     single-substitution lookup for it.

Run from the repository root:

    pip install fonttools
    python3 tool/fonts/build_fonts.py

The variable source is fetched once into /tmp; the outputs are committed, so the
app build never needs Python or the network.
"""

import copy
import os
import subprocess
import sys
import tempfile

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

SOURCE_URL = (
    "https://raw.githubusercontent.com/google/fonts/main/ofl/dmsans/"
    "DMSans%5Bopsz,wght%5D.ttf"
)

# Weight -> output file name. These are the three weights the app uses:
# 400 for secondary text, 500 for body, 700 for headings.
WEIGHTS = {
    400: "DMSans-Regular.ttf",
    500: "DMSans-Medium.ttf",
    700: "DMSans-Bold.ttf",
}

# Optical size to bake in. DM Sans ranges 9-40; the middle suits an app whose
# type runs from 11pt captions to 56pt numerals.
OPTICAL_SIZE = 14

DIGITS = "0123456789"

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")


def fetch_source() -> str:
    path = os.path.join(tempfile.gettempdir(), "DMSans-var.ttf")
    if not os.path.exists(path):
        subprocess.run(["curl", "-sSL", "-o", path, SOURCE_URL], check=True)
    return path


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

    # Both the font and the glyf table cache a glyph order, and the feature
    # compiler reads the font's. All three have to agree or the table compiles
    # with a mismatch between the order and the glyph map.
    new_order = order + new_glyphs
    font.setGlyphOrder(new_order)
    glyf.glyphOrder = font.glyphOrder

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
    source = fetch_source()
    os.makedirs(OUT_DIR, exist_ok=True)

    for weight, filename in WEIGHTS.items():
        font = TTFont(source)
        # Bake the variable axes down, so the file carries no variation data.
        font = instantiateVariableFont(
            font, {"wght": weight, "opsz": OPTICAL_SIZE}, inplace=True
        )
        add_tabular_digits(font)

        # Rename the family "DM Sans" so Flutter can address it by that name and
        # pick the weight from TextStyle.fontWeight alone.
        name = font["name"]
        for record in list(name.names):
            if record.nameID in (1, 3, 4, 6, 16, 17):
                name.removeNames(record.nameID, record.platformID, record.platEncID, record.langID)
        family = "DM Sans"
        subfamily = {400: "Regular", 500: "Medium", 700: "Bold"}[weight]
        full = f"{family} {subfamily}"
        ps = f"DMSans-{subfamily}"
        for platform, encoding, language in ((3, 1, 0x409), (1, 0, 0)):
            name.setName(family, 1, platform, encoding, language)
            name.setName(subfamily, 2, platform, encoding, language)
            name.setName(f"{full}-{weight}", 3, platform, encoding, language)
            name.setName(full, 4, platform, encoding, language)
            name.setName(ps, 6, platform, encoding, language)
            name.setName(family, 16, platform, encoding, language)
            name.setName(subfamily, 17, platform, encoding, language)

        out = os.path.join(OUT_DIR, filename)
        font.save(out)

        check = TTFont(out)
        # The cmap keeps pointing at the proportional glyphs; the feature swaps
        # in the tabular ones at shaping time, so those are the ones to measure.
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
            f"{filename}: {os.path.getsize(out) // 1024} KB, "
            f"tnum={('tnum' in features)}, digit widths={sorted(unique)}"
        )
        if len(unique) != 1 or "tnum" not in features:
            print("  ERROR: tabular digits were not applied", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
