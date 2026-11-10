#!/usr/bin/env python3
"""Generates the Elara launcher icon and its web copies.

The mark is a crescent moon: Elara is a moon of Jupiter, and the app's whole
vocabulary is lunar. The field is the deep warm brown of the dark theme, the
crescent is the cream of the light theme, and the single gold dot is the
ovulatory colour from the phase palette.

Run from the repository root:

    python3 tool/icon/generate_icon.py

Everything it writes is committed, so the build never needs Python.
"""

import os
from PIL import Image, ImageDraw

# Palette, from lib/theme/elara_theme.dart.
FIELD = (61, 44, 46, 255)        # #3D2C2E  textPrimary / dark field
CRESCENT = (253, 246, 240, 255)  # #FDF6F0  light background
DOT = (232, 184, 109, 255)       # #E8B86D  ovulatory gold

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Legacy launcher icon sizes, in px, by density bucket.
LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icon layers are 108dp; the safe zone is the central 72dp.
ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

SUPERSAMPLE = 8


def crescent(size, canvas_scale=1.0, opaque=True):
    """Draws the mark on a transparent square of `size` px.

    `canvas_scale` scales the mark within the square: the adaptive foreground
    uses a smaller mark so it survives the launcher's circular and squircle
    masks, which crop to the central 72 of 108 dp.
    """
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), FIELD if opaque else (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    centre = big / 2
    # Radius of the moon disc before the bite is taken out of it.
    radius = big * 0.29 * canvas_scale
    # The dot sits inside the crescent's opening, so the pair stays balanced
    # about the centre and survives a circular or squircle launcher mask.
    # Offset of the cutting disc, up and to the right: it removes the lit part
    # and leaves a crescent opening to the left.
    offset = radius * 0.52

    # Draw the full disc, then punch the cutting circle out of it by compositing
    # a transparent disc, which is exact at the supersampled resolution.
    moon = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    mdraw = ImageDraw.Draw(moon)
    mdraw.ellipse(
        [centre - radius, centre - radius, centre + radius, centre + radius],
        fill=CRESCENT,
    )
    cut_radius = radius * 1.02
    mdraw.ellipse(
        [
            centre + offset - cut_radius,
            centre - offset * 0.55 - cut_radius,
            centre + offset + cut_radius,
            centre - offset * 0.55 + cut_radius,
        ],
        fill=(0, 0, 0, 0),
    )
    img.alpha_composite(moon)

    # The single gold point, sitting in the crescent's opening rather than
    # floating off in the corner.
    dot_r = big * 0.055 * canvas_scale
    dot_x = centre + radius * 0.74
    dot_y = centre - radius * 0.62
    draw.ellipse(
        [dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r],
        fill=DOT,
    )

    return img.resize((size, size), Image.LANCZOS)


def monochrome(size):
    """Alpha-only mark for Android 13 themed icons: the launcher tints it.

    The gold dot is part of the symbol, so it is kept as a solid disc rather
    than dropped: without it the mark is an anonymous crescent. Only the alpha
    channel carries meaning here, so both shapes are drawn in the same ink.
    """
    img = Image.new("RGBA", (size * SUPERSAMPLE, size * SUPERSAMPLE), (0, 0, 0, 0))
    centre = size * SUPERSAMPLE / 2
    radius = size * SUPERSAMPLE * 0.29 * 0.62
    mdraw = ImageDraw.Draw(img)
    mdraw.ellipse(
        [centre - radius, centre - radius, centre + radius, centre + radius],
        fill=(0, 0, 0, 255),
    )
    cut_radius = radius * 1.02
    offset = radius * 0.52
    mdraw.ellipse(
        [
            centre + offset - cut_radius,
            centre - offset * 0.55 - cut_radius,
            centre + offset + cut_radius,
            centre - offset * 0.55 + cut_radius,
        ],
        fill=(0, 0, 0, 0),
    )

    # The dot, at the same place and size as the colour icon.
    # Same proportion as the colour icon: 0.055 of the tile against a mark
    # radius of 0.29 * 0.62.
    dot_radius = radius * 0.306
    dot_x = centre + radius * 0.74
    dot_y = centre - radius * 0.62
    mdraw.ellipse(
        [
            dot_x - dot_radius,
            dot_y - dot_radius,
            dot_x + dot_radius,
            dot_y + dot_radius,
        ],
        fill=(0, 0, 0, 255),
    )
    return img.resize((size, size), Image.LANCZOS)


def rounded_mask(size, radius_fraction=0.25):
    mask = Image.new("L", (size * SUPERSAMPLE, size * SUPERSAMPLE), 0)
    d = ImageDraw.Draw(mask)
    r = size * SUPERSAMPLE * radius_fraction
    d.rounded_rectangle(
        [0, 0, size * SUPERSAMPLE - 1, size * SUPERSAMPLE - 1],
        radius=r,
        fill=255,
    )
    return mask.resize((size, size), Image.LANCZOS)


def circular_mask(size):
    mask = Image.new("L", (size * SUPERSAMPLE, size * SUPERSAMPLE), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([0, 0, size * SUPERSAMPLE - 1, size * SUPERSAMPLE - 1], fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"{os.path.relpath(path, ROOT)}  {image.size[0]}x{image.size[1]}")


def main():
    # Legacy square icons: the launcher rounds them itself on most Android
    # versions, so the shape is a rounded square with the mark inside. The
    # radius matches the website's mark (18px on a 72px tile = 0.25), so the
    # app icon and the page header soften their corners by the same amount.
    for bucket, size in LEGACY.items():
        icon = crescent(size)
        icon.putalpha(rounded_mask(size))
        write(os.path.join(RES, bucket, "ic_launcher.png"), icon)

    # Round variant, for launchers that ask for one explicitly.
    for bucket, size in LEGACY.items():
        icon = crescent(size)
        icon.putalpha(circular_mask(size))
        write(os.path.join(RES, bucket, "ic_launcher_round.png"), icon)

    # Adaptive foreground: transparent, mark shrunk into the safe zone.
    for bucket, size in ADAPTIVE.items():
        write(
            os.path.join(RES, bucket, "ic_launcher_foreground.png"),
            crescent(size, canvas_scale=0.62, opaque=False),
        )

    # Themed icons (Android 13+): one alpha mask the launcher tints itself.
    for bucket, size in ADAPTIVE.items():
        write(
            os.path.join(RES, bucket, "ic_launcher_monochrome.png"),
            monochrome(size),
        )

    # Store listings, the landing page and the README header.
    write(os.path.join(ROOT, "docs", "icon.png"), crescent(512))
    write(os.path.join(ROOT, "docs", "favicon.png"), crescent(64))
    write(os.path.join(ROOT, "tool", "icon", "icon-1024.png"), crescent(1024))


if __name__ == "__main__":
    main()
