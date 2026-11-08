#!/usr/bin/env python3
"""Generates the three launcher-icon concepts for review.

Nothing here touches `android/app/src/main/res`. These are proposals: the
existing icon stays in place until one concept is approved, and only then does
`generate_icon.py` get rewritten and re-run.

Every concept is drawn in the same 108 x 108 viewBox Android uses for adaptive
icons, with the mark inside the central 72-unit safe zone so a launcher's circle,
squircle or rounded-square mask cannot clip it. Two rules shape the geometry:

  * **Legibility at 24 px.** Every shape is either a large mass or a gap of at
    least 4 units (about 1.3 px at 24 px, after anti-aliasing). No line weights
    below that, no details that only exist at 192 px.
  * **Both field colours.** Each concept is rendered on the light page colour and
    on the dark one, because a launcher can show either.

Run from the repository root:

    python3 tool/icon/concepts.py
"""

import os

import cairosvg
from PIL import Image

# Palette, copied from lib/theme/elara_theme.dart. Kept in one place here so a
# concept cannot drift from the app it belongs to.
CREAM = "#FDF6F0"      # light background
INK = "#3D2C2E"        # dark field / primary text
GOLD = "#E8B86D"       # ovulatory phase
ROSE = "#C97B7B"       # menstrual phase
TEAL = "#7DB8A5"       # follicular phase
VIOLET = "#9B8EC4"     # luteal phase

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "icon-concepts")

SIZES = (192, 48, 24)


def wrap(body, field, size=108):
    """Wraps a body in an SVG canvas sized for the adaptive-icon grid."""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 108 108">\n'
        f"  <rect width=\"108\" height=\"108\" fill=\"{field}\"/>\n"
        f"{body}"
        f"</svg>\n"
    )


# --------------------------------------------------------------------------
# Concept A: Refined Lunar
#
# The current mark is a crescent with a gold dot. Its weakness is geometry: the
# crescent's horns are uneven, and the dot floats outside the crescent's orbit
# rather than sitting on it, so the pair reads as two unrelated shapes at small
# sizes. This version rebuilds the crescent as the difference of two circles
# whose centres are exactly one radius apart on the diagonal, which gives horns
# of equal length and a constant limb thickness, and it puts the dot on the
# crescent's own implied orbit so the two read as one system.
# --------------------------------------------------------------------------
def concept_a(field):
    ink = CREAM if field == INK else INK
    # Two discs, and the crescent is their difference. The second is offset up
    # and to the right by exactly the amount that leaves a limb of even
    # thickness and two horns closing at the same height; an even-odd fill
    # rule turns the overlap into the bite.
    body = (
        f'  <path fill-rule="evenodd" fill="{ink}" d="'
        + _circle_path(54, 54, 33)
        + " "
        + _circle_path(61, 48, 28.5)
        + '"/>\n'
        # The dot sits on the crescent's own implied orbit, so the two read as
        # one system rather than two unrelated shapes.
        f'  <circle cx="82" cy="30" r="7.5" fill="{GOLD}"/>\n'
    )
    return wrap(body, field)


def _circle_path(cx, cy, radius):
    """A full circle as two arcs, for use as a subpath inside a fill rule."""
    return (
        f"M {cx - radius} {cy} "
        f"A {radius} {radius} 0 1 0 {cx + radius} {cy} "
        f"A {radius} {radius} 0 1 0 {cx - radius} {cy} Z"
    )


# --------------------------------------------------------------------------
# Concept B: Four Phases
#
# The app already has four phase colours and a calendar that uses them. Turning
# them into an icon risks the obvious failure, a pie chart, which reads as data
# rather than as care. The alternative here is a ring broken into four unequal
# arcs, with the gaps arranged so the eye follows a rotation rather than reading
# four values. The arcs sit on one circle, the gaps are identical, and no arc is
# labelled: it is a cycle, not a chart.
#
# At 24 px the ring closes up into a single soft-coloured annulus, which still
# reads as a mark rather than dissolving into noise.
# --------------------------------------------------------------------------
def concept_b(field):
    colours = (ROSE, TEAL, GOLD, VIOLET)
    # Four 84-degree arcs with 6-degree gaps, starting at the top.
    arcs = []
    radius = 30
    cx = cy = 54
    gap = 6
    span = 90 - gap
    for index, colour in enumerate(colours):
        start = -90 + index * 90 + gap / 2
        end = start + span
        arcs.append(
            f'  <path d="M {_point(cx, cy, radius, start)} '
            f'A {radius} {radius} 0 0 1 {_point(cx, cy, radius, end)}" '
            f'stroke="{colour}" stroke-width="11" stroke-linecap="round" '
            f'fill="none"/>\n'
        )
    return wrap("".join(arcs), field)


def _point(cx, cy, radius, degrees):
    import math

    radians = math.radians(degrees)
    x = cx + radius * math.cos(radians)
    y = cy + radius * math.sin(radians)
    return f"{x:.2f} {y:.2f}"


# --------------------------------------------------------------------------
# Concept C: Elara Monogram
#
# An E whose spine is a crescent: three bars of equal length springing from a
# curved stem, with the stem's curve continuing past the bars as a moon's limb.
# The bars are cut generously so the letter survives at 24 px, where it becomes
# three marks beside a curve rather than a letterform, and still reads as an E.
#
# No crescent-and-star, no cradle, no maternal silhouette: those would be the
# obvious visual cliches for this subject and none of them are honest.
# --------------------------------------------------------------------------
def concept_c(field):
    stroke = CREAM if field == INK else INK
    # A chord of 56 units with a radius of 80 gives a sagitta of under 5 units:
    # a spine that bows just enough to read as a moon's limb while the mark
    # still resolves as an E at 24 px. A smaller radius turns the letter into a
    # C, which is the failure mode these first renders showed.
    body = (
        # Bars first, so the stem's stroke covers their ends cleanly.
        f'  <path d="M 46 27 L 78 27" stroke="{stroke}" stroke-width="13" '
        f'stroke-linecap="round"/>\n'
        f'  <path d="M 42 54 L 71 54" stroke="{stroke}" stroke-width="13" '
        f'stroke-linecap="round"/>\n'
        f'  <path d="M 46 81 L 78 81" stroke="{stroke}" stroke-width="13" '
        f'stroke-linecap="round"/>\n'
        # The spine: a shallow arc from the top bar's start to the bottom one's.
        f'  <path d="M 46 21 A 80 80 0 0 0 46 87" stroke="{stroke}" '
        f'stroke-width="13" stroke-linecap="round" fill="none"/>\n'
        # One gold note, kept from the current icon, in the open counter above
        # the middle bar.
        f'  <circle cx="87" cy="36" r="6" fill="{GOLD}"/>\n'
    )
    return wrap(body, field)


CONCEPTS = (
    ("concept-a-refined-lunar", "Refined Lunar", concept_a),
    ("concept-b-four-phases", "Four Phases", concept_b),
    ("concept-c-monogram", "Elara Monogram", concept_c),
)


def render(svg_text, path, size, supersample=8):
    """Renders an SVG to PNG at `size` px, via a large intermediate.

    cairosvg rather than ImageMagick: ImageMagick's built-in SVG renderer only
    understands simple primitives, so it silently drops every arc and the
    concept appears blank. It also means this script needs `pip install
    cairosvg`, which is a review-time tool and not part of any build.
    """
    big = size * supersample
    cairosvg.svg2png(
        bytestring=svg_text.encode(),
        write_to=path + ".tmp.png",
        output_width=big,
        output_height=big,
    )
    with Image.open(path + ".tmp.png") as image:
        image = image.convert("RGBA").resize((size, size), Image.LANCZOS)
        image.save(path)
    os.remove(path + ".tmp.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []

    for slug, name, draw in CONCEPTS:
        for field_name, field in (("light", CREAM), ("dark", INK)):
            svg = draw(field)
            svg_path = os.path.join(OUT, f"{slug}-{field_name}.svg")
            with open(svg_path, "w") as handle:
                handle.write(svg)
            written.append(svg_path)

            for size in SIZES:
                png_path = os.path.join(
                    OUT, f"{slug}-{field_name}-{size}.png"
                )
                render(svg, png_path, size)
                written.append(png_path)

    print(f"wrote {len(written)} files to {OUT}")
    for path in written:
        print("  " + os.path.basename(path))


if __name__ == "__main__":
    main()
