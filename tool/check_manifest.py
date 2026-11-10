#!/usr/bin/env python3
"""Fail the build on the three things the Dart suite cannot see.

`dart analyze` and `flutter test` never parse an Android manifest, a Gradle
file or a backup rule. On 10 November 2026 the AndroidManifest.xml on `main`
contained committed merge-conflict markers — twice, from the same merge — and
the APK could not be built at all, while CI was green because it had never
looked. That is the class of failure this script exists to prevent.

Checks:

  1. no merge-conflict markers anywhere in the repository;
  2. every XML file the Android build reads is well-formed;
  3. the manifest declares the privacy controls this project claims: backups
     off, extraction rules pointed at a file that exists, and a targetSdk that
     Google Play will still accept.

Runs in under a second, needs no Android SDK, and exits non-zero with a file and
line for everything it finds.
"""

from __future__ import annotations

import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".git", "build", ".dart_tool", ".gradle", "node_modules"}

# Binary files are read as bytes and skipped; a PNG is not a merge conflict.
TEXT_SUFFIXES = {
    ".dart", ".kt", ".kts", ".gradle", ".xml", ".yaml", ".yml", ".md",
    ".json", ".sh", ".py", ".txt", ".html", ".css", ".arb", ".properties",
    ".gitignore", ".plist", "",
}

CONFLICT_PATTERNS = (
    re.compile(r"^<{7}( |$)"),
    re.compile(r"^={7}$"),
    re.compile(r"^>{7}( |$)"),
)

# The minimum targetSdk Google Play accepts for a new upload. Read from Play's
# policy: API 36 from 31 August 2026, rising by one roughly every August.
MINIMUM_TARGET_SDK = 36

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def fail(messages: list[str]) -> None:
    for message in messages:
        print(f"::error::{message}")
    print(f"\n{len(messages)} problem(s) found.")
    sys.exit(1)


def text_files() -> list[Path]:
    files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            path = Path(dirpath) / name
            if path.suffix not in TEXT_SUFFIXES:
                continue
            files.append(path)
    return files


def check_conflict_markers(problems: list[str]) -> None:
    for path in text_files():
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(lines, start=1):
            if any(pattern.match(line) for pattern in CONFLICT_PATTERNS):
                problems.append(
                    f"{path.relative_to(ROOT)}:{number}: merge-conflict marker "
                    f"committed — this file does not parse and cannot be built"
                )


def check_xml(problems: list[str]) -> None:
    for path in (ROOT / "android" / "app" / "src").rglob("*.xml"):
        try:
            ET.parse(path)
        except ET.ParseError as error:
            problems.append(
                f"{path.relative_to(ROOT)}: not well-formed XML "
                f"({error}) — aapt2 will refuse this file"
            )


def check_privacy_controls(problems: list[str]) -> None:
    manifest_path = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.exists():
        problems.append("AndroidManifest.xml is missing")
        return

    tree = ET.parse(manifest_path)
    application = tree.getroot().find("application")
    if application is None:
        problems.append("AndroidManifest.xml has no <application> element")
        return

    def attribute(name: str) -> str | None:
        return application.get(f"{ANDROID_NS}{name}")

    # 1. Cloud backup must be off. Android's default is on, and leaving it on
    #    uploads elara.db — cycle dates, symptoms, free-text notes and her
    #    questionnaire answers — to the user's Google account.
    if (attribute("allowBackup") or "true") != "false":
        problems.append(
            "AndroidManifest.xml: android:allowBackup is not \"false\" — "
            "Android will upload the cycle database to the user's cloud account"
        )

    # 2. On API 31+ the extraction rules take precedence, so pointing at a file
    #    that does not exist is worse than not pointing at one.
    rules = attribute("dataExtractionRules")
    if rules:
        if not rules.startswith("@xml/"):
            problems.append(
                f"AndroidManifest.xml: android:dataExtractionRules={rules!r} "
                f"is not an @xml/ resource"
            )
        else:
            resource = (ROOT / "android" / "app" / "src" / "main" / "res" /
                        "xml" / f"{rules[len('@xml/'):]}.xml")
            if not resource.exists():
                problems.append(
                    f"AndroidManifest.xml: android:dataExtractionRules points at "
                    f"{resource.relative_to(ROOT)}, which does not exist"
                )
    else:
        problems.append(
            "AndroidManifest.xml: android:dataExtractionRules is missing — "
            "device-transfer and cloud backup rules must be stated explicitly"
        )

    # 3. targetSdk, which is in Gradle rather than the manifest.
    gradle = ROOT / "android" / "app" / "build.gradle.kts"
    if gradle.exists():
        match = re.search(r"targetSdk\s*=\s*(\d+)", gradle.read_text())
        if match is None:
            problems.append("build.gradle.kts: no targetSdk declared")
        elif int(match.group(1)) < MINIMUM_TARGET_SDK:
            problems.append(
                f"build.gradle.kts: targetSdk = {match.group(1)}, below the "
                f"{MINIMUM_TARGET_SDK} Google Play accepts since 31 August 2026"
            )


def check_launch_colour(problems: list[str]) -> None:
    """The launch colour in Android must equal the app's page colour.

    Two Android resources paint the window before Flutter draws anything. When
    they disagree with the palette the app opens with a flash of the old theme
    — and with an edge-to-edge window, a visible seam at the edges of the
    screen. They held #FAFAF8 and #1A1A1A through two palette rewrites, which is
    exactly the kind of copy that goes stale silently.
    """
    dart = ROOT / "lib" / "theme" / "elara_theme.dart"
    if not dart.exists():
        problems.append("lib/theme/elara_theme.dart is missing")
        return
    source = dart.read_text()

    wanted = {}
    for name in ("light", "dark"):
        block = re.search(
            rf"static const ElaraPalette {name} = ElaraPalette\((.*?)\n  \);",
            source,
            re.S,
        )
        if block is None:
            problems.append(f"elara_theme.dart: no {name} palette found")
            continue
        match = re.search(r"bgPrimary: Color\(0x([0-9A-Fa-f]{8})\)", block.group(1))
        if match is None:
            problems.append(f"elara_theme.dart: {name} palette has no bgPrimary")
            continue
        wanted[name] = "#" + match.group(1)[2:].upper()

    for name, resource in (
        ("light", ROOT / "android/app/src/main/res/values/colors.xml"),
        ("dark", ROOT / "android/app/src/main/res/values-night/colors.xml"),
    ):
        if name not in wanted:
            continue
        if not resource.exists():
            problems.append(f"{resource.relative_to(ROOT)} is missing")
            continue
        match = re.search(
            r'<color name="elara_page_background">\s*(#[0-9A-Fa-f]{6})\s*</color>',
            resource.read_text(),
        )
        if match is None:
            problems.append(
                f"{resource.relative_to(ROOT)}: no elara_page_background colour"
            )
        elif match.group(1).upper() != wanted[name]:
            problems.append(
                f"{resource.relative_to(ROOT)}: launch colour {match.group(1)} "
                f"does not match ElaraPalette.{name}.bgPrimary {wanted[name]}, "
                f"so the app flashes a different colour before the first frame"
            )


def check_cutout(problems: list[str]) -> None:
    """The window must be allowed to draw into a display cutout.

    On a water-drop phone the default is to letterbox the window clear of the
    notch in portrait. That band belongs to the window rather than to the page,
    so the app looks like a card sitting inside a box whose top edge stays put
    while the content scrolls under it. It is a one-line style attribute, and
    it is invisible on every emulator that has no cutout — which is how it
    shipped.
    """
    for variant in ("values-v28", "values-night-v28"):
        path = (ROOT / "android" / "app" / "src" / "main" / "res" / variant /
                "styles.xml")
        if not path.exists():
            problems.append(
                f"res/{variant}/styles.xml is missing — the window will be "
                f"letterboxed clear of a display cutout"
            )
            continue
        text = path.read_text()
        for style in ("NormalTheme", "LaunchTheme"):
            # Find the style block and check the attribute inside it.
            match = re.search(
                rf'<style name="{style}".*?</style>', text, re.S
            )
            if match is None:
                problems.append(f"res/{variant}/styles.xml: no {style}")
            elif "windowLayoutInDisplayCutoutMode" not in match.group(0):
                problems.append(
                    f"res/{variant}/styles.xml: {style} does not set "
                    f"windowLayoutInDisplayCutoutMode, so the app is boxed "
                    f"below the notch on a water-drop screen"
                )


def main() -> None:
    problems: list[str] = []
    check_conflict_markers(problems)
    check_xml(problems)
    check_privacy_controls(problems)
    check_cutout(problems)
    check_launch_colour(problems)

    if problems:
        fail(problems)

    print(
        "Manifest, XML, privacy controls, cutout mode and launch colour: clean."
    )


if __name__ == "__main__":
    main()
