#!/usr/bin/env python3
"""Fail the build when a workflow builds with a different Flutter than the tests.

On 12 November 2026 the 2.2.1 release went red while CI on the same commit was
green. The cause was two lines of YAML: `ci.yml` set up Flutter from
`env.FLUTTER_VERSION` (3.47.9), and `release.yml` set it up from
`channel: stable`, which had just moved to 3.50 and deprecated the import of
`package:flutter/material.dart` - the first line of almost every file in `lib/`.

CI never saw it because the deprecation is an info and only the release job runs
`dart analyze --fatal-infos`. The release never saw whether it mattered, because
it failed on the first file it read. Whichever way that lands, the important part
is that a release was compiled by a toolchain no test had ever run on, and none
of the checks in `tool/` looked at the workflows.

This script reads every workflow and fails if:

  1. a `subosito/flutter-action` step does not pin `flutter-version` to
     `${{ env.FLUTTER_VERSION }}` (a `channel:` setup floats, and floats drift);
  2. a workflow that uses Flutter does not declare `FLUTTER_VERSION`;
  3. two workflows declare different versions.

No YAML parser is used: it is one less dependency in a repository whose checks
must run anywhere, and the shapes being matched are two lines long.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

WORKFLOWS = Path(".github/workflows")

SETUP = "subosito/flutter-action"
PINNED = re.compile(r"flutter-version:\s*\$\{\{\s*env\.FLUTTER_VERSION\s*\}\}")
CHANNEL = re.compile(r"^\s*channel:\s*(\S+)\s*$", re.MULTILINE)
DECLARED = re.compile(r"^\s*FLUTTER_VERSION:\s*['\"]?([^'\"\s#]+)", re.MULTILINE)
JOB = re.compile(r"^  [a-z0-9_-]+:\s*$", re.MULTILINE)


def steps_using_flutter(text: str) -> list[str]:
    """Return the chunk of each step that sets up Flutter, up to the next step."""
    chunks = []
    for match in re.finditer(re.escape(SETUP), text):
        start = match.start()
        end = text.find("\n      - ", match.end())
        chunks.append(text[start : end if end != -1 else len(text)])
    return chunks


def main() -> int:
    if not WORKFLOWS.is_dir():
        print(f"::error::{WORKFLOWS} does not exist; run this from the repo root.")
        return 1

    failures = 0
    versions: dict[str, str] = {}

    for path in sorted(WORKFLOWS.glob("*.yml")):
        text = path.read_text(encoding="utf-8")
        chunks = steps_using_flutter(text)
        if not chunks:
            continue

        declared = {m.group(1) for m in DECLARED.finditer(text)}
        if not declared:
            print(
                f"::error::{path}: sets up Flutter but declares no FLUTTER_VERSION. "
                f"A version written in each step drifts between jobs."
            )
            failures += 1
        elif len(declared) > 1:
            print(f"::error::{path}: declares more than one FLUTTER_VERSION: {sorted(declared)}")
            failures += 1
        else:
            versions[path.name] = declared.pop()

        for chunk in chunks:
            if PINNED.search(chunk):
                continue
            channel = CHANNEL.search(chunk)
            why = (
                f"it floats on channel '{channel.group(1)}'"
                if channel
                else "it does not pin flutter-version"
            )
            print(
                f"::error::{path}: a Flutter setup step is not pinned to "
                f"${{{{ env.FLUTTER_VERSION }}}} ({why}). Every job that compiles "
                f"this code must compile it with the version CI tests it on; "
                f"otherwise a release can fail on a deprecation the tests never "
                f"reported, or ship a build no test ran on."
            )
            failures += 1

    if len(set(versions.values())) > 1:
        worst = ", ".join(f"{name}={version}" for name, version in sorted(versions.items()))
        print(f"::error::workflows disagree on FLUTTER_VERSION: {worst}")
        failures += 1

    if not failures:
        shown = ", ".join(sorted(set(versions.values()))) or "none"
        print(
            f"Checked {len(versions)} workflow(s) that compile Dart: every one "
            f"pins Flutter {shown}."
        )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
