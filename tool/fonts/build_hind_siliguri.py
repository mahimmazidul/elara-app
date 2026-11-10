#!/usr/bin/env python3
"""Adds real tabular numerals to the bundled Hind Siliguri files, keeping Bengali.

Hind Siliguri's digits are proportional: the "1" is 323 units wide and the
"0" is 544. Asking Flutter for `FontFeature.tabularFigures()` would do
nothing, because the font's GSUB table has no `tnum` feature at all, and
every value that updates in place - the countdown, the heat index, the cycle
day - would shift sideways as its digits changed.

The app already depends on that not happening: DM Sans had the same problem
and tool/fonts/build_fonts.py fixed it. This script does the same for
Hind Siliguri, so that swapping the family does not quietly break it.

It also has to prove that it did not break Bengali on the way through. The
committed fonts were once rebuilt from a source whose OpenType layout tables
had already been stripped: no `beng` or `bng2` script, one lookup, and a single
`tnum` feature. Latin looked perfect, which is why nobody noticed. Bengali did
not: `ক্ষ` shaped as three separate glyphs instead of the ক্‌ষ conjunct, and the
ই matra in `দিন` stayed after its consonant instead of moving before it — so
every Bengali name in the app rendered as unshaped text with misplaced marks.

That is the failure this script now refuses to repeat. It takes the four
upstream static files, adds `tnum` to whatever layout tables they already have,
and then shapes real Bengali words with HarfBuzz to confirm the conjunct and the
matra reordering still happen.

Run from the repository root:

    pip install fonttools uharfbuzz
    python3 tool/fonts/build_hind_siliguri.py            # rebuild
    python3 tool/fonts/build_hind_siliguri.py --check    # verify only

The inputs are the four static Hind Siliguri files, which are committed, so
the app build never needs Python or the network. The outputs are committed
too. `--check` runs in CI.
"""

import copy
import os
import sys
import urllib.request

from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")

# Where the unmodified upstream files come from. Google Fonts only; no account,
# no key. Used by `--refresh` and never during a normal app build.
UPSTREAM = (
    "https://raw.githubusercontent.com/google/fonts/main/ofl/hindsiliguri/"
    "HindSiliguri-{weight}.ttf"
)

# Text that only shapes correctly when Bengali layout is present. Each pair is
# (word, glyph names the string must resolve to). The conjunct and the matra
# reordering are the two things a font without `beng` gets wrong.
BENGALI_SHAPING = {
    "ক্ষ": ["bnK_SSA"],
    "দিন": ["bnmI", "bnDA", "bnNA"],
    "শ্রাবণ": ["bnSH_RA", "bnmAA", "bnBA", "bnNNA"],
}

# The four weights the app bundles. 600 is there so that a caller asking for
# semibold gets real semibold rather than a synthesised fake.
FILES = [
    "HindSiliguri-Regular.ttf",
    "HindSiliguri-Medium.ttf",
    "HindSiliguri-SemiBold.ttf",
    "HindSiliguri-Bold.ttf",
]

DIGITS = "0123456789"

# Scripts and features that must survive whatever this script does to the file.
REQUIRED_SCRIPTS = {"DFLT", "beng", "bng2"}
REQUIRED_BENGALI_FEATURES = {"akhn", "half", "rphf"}


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

    # Appended by hand rather than compiled from feature file text.
    #
    # fontTools' feature-file compiler rebuilds the layout tables from the text
    # it is given, so `languagesystem DFLT dflt; languagesystem latn dflt;`
    # leaves a font with exactly those two scripts and no GPOS — which is how
    # this repository ended up shipping a Hind Siliguri that could not shape a
    # conjunct. Adding one lookup and one feature record to the tables that are
    # already there leaves Bengali untouched.
    add_tnum_feature(font, names)


def problems_with(path: str) -> list[str]:
    """Everything wrong with one bundled font file."""
    from fontTools.ttLib import TTFont

    found: list[str] = []
    font = TTFont(path)
    name = os.path.basename(path)

    if "GSUB" not in font:
        return [f"{name}: no GSUB table at all"]
    gsub = font["GSUB"].table
    scripts = {record.ScriptTag for record in gsub.ScriptList.ScriptRecord}
    missing_scripts = REQUIRED_SCRIPTS - scripts
    if missing_scripts:
        found.append(
            f"{name}: OpenType layout is missing the "
            f"{', '.join(sorted(missing_scripts))} script(s); Bengali will not shape"
        )

    features = {r.FeatureTag for r in gsub.FeatureList.FeatureRecord}
    missing_features = REQUIRED_BENGALI_FEATURES - features
    if missing_features:
        found.append(
            f"{name}: missing Bengali feature(s) "
            f"{', '.join(sorted(missing_features))}"
        )
    if "tnum" not in features:
        found.append(f"{name}: no tnum feature; updating values will shift sideways")

    if "GPOS" not in font:
        found.append(f"{name}: no GPOS table; mark positioning will be wrong")

    # The real test: shape words and read the glyphs back.
    try:
        import uharfbuzz as hb
    except ImportError:
        found.append("uharfbuzz is not installed, so shaping could not be checked")
        return found

    blob = hb.Blob.from_file_path(path)
    face = hb.Face(blob)
    hb_font = hb.Font(face)
    for word, expected in BENGALI_SHAPING.items():
        buffer = hb.Buffer()
        buffer.add_str(word)
        buffer.guess_segment_properties()
        hb.shape(hb_font, buffer)
        actual = [hb_font.glyph_to_string(i.codepoint) for i in buffer.glyph_infos]
        if actual != expected:
            found.append(
                f"{name}: '{word}' shaped as {actual}, expected {expected}"
            )

    return found


def check() -> int:
    """Verify the committed fonts without touching them."""
    total = 0
    for filename in FILES:
        path = os.path.join(OUT_DIR, filename)
        if not os.path.exists(path):
            print(f"missing: {path}", file=sys.stderr)
            return 1
        problems = problems_with(path)
        if problems:
            total += len(problems)
            for problem in problems:
                print(f"  {problem}", file=sys.stderr)
        else:
            print(f"{filename}: Bengali shaping, GPOS and tabular digits all present")
    if total:
        print(f"\n{total} problem(s) in the bundled fonts", file=sys.stderr)
        return 1
    return 0


def refresh() -> int:
    """Fetch the unmodified upstream files, then add tabular digits to them."""
    for filename in FILES:
        weight = filename.removeprefix("HindSiliguri-").removesuffix(".ttf")
        url = UPSTREAM.format(weight=weight)
        target = os.path.join(OUT_DIR, filename)
        print(f"fetching {url}")
        urllib.request.urlretrieve(url, target)  # noqa: S310 - fixed https host
    return main()


def add_tnum_feature(font: TTFont, names: list[str]) -> None:
    """Adds a `tnum` feature that swaps proportional digits for tabular ones.

    The lookup is appended to the existing GSUB, and the feature is registered
    in the scripts that need it (`DFLT` and `latn`). Every other script — `beng`
    and `bng2` in particular — keeps its lookups exactly as they were.
    """
    from fontTools.otlLib.builder import buildSingleSubstSubtable
    from fontTools.ttLib.tables import otTables

    gsub = font["GSUB"].table
    mapping = {name: f"{name}.tnum" for name in names}

    lookup = otTables.Lookup()
    lookup.LookupType = 1  # single substitution
    lookup.LookupFlag = 0
    lookup.SubTable = [buildSingleSubstSubtable(mapping)]
    lookup.SubTableCount = 1

    gsub.LookupList.Lookup.append(lookup)
    gsub.LookupList.LookupCount = len(gsub.LookupList.Lookup)
    lookup_index = gsub.LookupList.LookupCount - 1

    record = otTables.FeatureRecord()
    record.FeatureTag = "tnum"
    record.Feature = otTables.Feature()
    record.Feature.FeatureParams = None
    record.Feature.LookupListIndex = [lookup_index]
    record.Feature.LookupCount = 1
    gsub.FeatureList.FeatureRecord.append(record)
    gsub.FeatureList.FeatureCount = len(gsub.FeatureList.FeatureRecord)
    feature_index = gsub.FeatureList.FeatureCount - 1

    for script_record in gsub.ScriptList.ScriptRecord:
        if script_record.ScriptTag not in {"DFLT", "latn"}:
            continue
        lang_sys = script_record.Script.DefaultLangSys
        if lang_sys is None:
            continue
        lang_sys.FeatureIndex.append(feature_index)
        lang_sys.FeatureCount = len(lang_sys.FeatureIndex)
        lang_sys.FeatureIndex.sort()


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

        # The digits are the easy part. This is the part that matters.
        problems = problems_with(path)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        if problems:
            return 1

    return 0


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(check())
    if "--refresh" in sys.argv:
        sys.exit(refresh())
    sys.exit(main())
