#!/usr/bin/env python3
"""Checks the emulator scripts for the mistakes that only show up on a runner.

The scripts in this directory run on a GitHub runner, not on a developer
machine, and `set -u` means an undefined variable ends the run - usually
after twenty minutes of emulator boot. Two mistakes have actually happened
this way:

* `navigation.sh` used `$ACTIVITY` in its dark-mode block without ever
  defining it, so the run died at the last step of the last section, with
  every earlier capture already taken and uploaded.
* `capture_screens.sh` installed `artifact/app-debug.apk` in a job that
  builds the APK in place, so it never existed.

The second is now handled by `find_apk.sh`. This check handles the first
class of mistake, and it is cheap enough to run on every change.

It also checks that the scripts parse, which catches a missing quote or an
unbalanced brace before a runner ever sees it.

Run it with:  python3 tool/android_ui/check_scripts.py
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent

# Variables the shell provides.
PROVIDED_BY_SHELL = {
    "PATH",
    "HOME",
    # The shell provides it: it is the path of the script being run, and it
    # is how a script finds its own directory.
    "BASH_SOURCE",
    "PWD",
    "OLDPWD",
    "ANDROID_HOME",
    "ANDROID_SDK_ROOT",
    "JAVA_HOME",
    "GITHUB_SHA",
    "GITHUB_REF",
    "GITHUB_OUTPUT",
    "EVIDENCE_DIR",
    "EVIDENCE",
}

# Assigned by the loop constructs the scripts use.
ASSIGNED_BY_LOOP = {
    "candidate",
    "attempt",
    "label",
    "name",
    "day",
    "coords",
    "png",
    "value",
    "url",
    "line",
    "entry",
    "x1",
    "y1",
    "x2",
    "y2",
    "word",
    "file",
    "script",
    "key",
    "result",
    "out",
}


def check_syntax(path: pathlib.Path) -> list[str]:
    """`bash -n` on the script."""
    result = subprocess.run(
        ["bash", "-n", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        return []
    return [f"{path.name}: {line}" for line in result.stderr.splitlines() if line]


def check_variables(path: pathlib.Path) -> list[str]:
    """Every upper-case variable used has to be assigned somewhere."""
    text = path.read_text(encoding="utf-8")

    used = set(re.findall(r"\$\{?([A-Z_][A-Z0-9_]*)\}?", text))
    assigned = set(
        re.findall(r"^\s*(?:local\s+|export\s+|readonly\s+)?([A-Z_][A-Z0-9_]*)\s*=", text, re.M)
    )
    assigned |= set(re.findall(r"^\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in", text, re.M))

    missing = sorted(used - assigned - PROVIDED_BY_SHELL - ASSIGNED_BY_LOOP)
    return [
        f"{path.name}: ${name} is used but never assigned"
        for name in missing
    ]


def check_no_hardcoded_apk(path: pathlib.Path) -> list[str]:
    """The APK path is resolved by find_apk.sh, not written into a script."""
    text = path.read_text(encoding="utf-8")
    problems = []
    if "artifact/app-debug.apk" in text and "find_apk.sh" not in text:
        problems.append(
            f"{path.name}: installs 'artifact/app-debug.apk' directly; "
            "use tool/android_ui/find_apk.sh, which knows both places"
        )
    return problems


def main() -> int:
    scripts = sorted(HERE.glob("*.sh"))
    if not scripts:
        print("No scripts found in", HERE)
        return 1

    problems: list[str] = []
    for script in scripts:
        problems += check_syntax(script)
        problems += check_variables(script)
        problems += check_no_hardcoded_apk(script)

    if problems:
        print("The emulator scripts have problems:\n")
        for problem in problems:
            print(f"  {problem}")
        return 1

    print(f"Checked {len(scripts)} emulator script(s): syntax, variables, APK path.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
