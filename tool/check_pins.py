#!/usr/bin/env python3
"""Fail the build when a pinned dependency commit is not on its remote.

`pubspec.yaml` pins `elara_core` to an exact git commit:

    elara_core:
      git:
        url: https://github.com/mahimmazidul/elara-core.git
        ref: 9d35ae70a7dd43e0a0a69f5338e1ba511c2e2b02

A full SHA feels like the most stable thing you can write, and it is the most
fragile: it resolves only while that exact object is reachable from a branch on
the remote. On 12 November 2026 the release job failed at `flutter pub get` with

    Could not find git ref '9d35ae7...' (fatal: bad object 9d35ae7...)

because elara-core's `main` had been rewritten and the pinned commit was left
dangling: still served by GitHub's object cache for a while, so `flutter test`
and the Android build passed, then dropped, so the release could not resolve the
same dependency from the same file. Two workflows green and two red on one
commit is the signature of this failure, and nothing in the repo said so.

This check asks the remote instead of trusting the SHA. For every git dependency
in `pubspec.yaml` it compares the pinned ref against the repository's default
branch and fails unless the ref is that branch or an ancestor of it.

Needs GITHUB_TOKEN in the environment (the Actions runner has one). Without a
token it prints what it would have checked and exits 0, so a local run without
credentials is a skip rather than a false failure.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request

PUBSPEC = "pubspec.yaml"

# `url: ...github.com/<owner>/<repo>.git` followed by `ref: <ref>` a few lines
# later. Kept tolerant of indentation and of the two being in either order.
BLOCK = re.compile(
    r"url:\s*(?P<url>\S+)\s*\n(?:\s+\S+.*\n)*?\s+ref:\s*(?P<ref>[^\s#]+)",
)


def find_pins(text: str) -> list[tuple[str, str, str]]:
    """Return (name, owner/repo, ref) for every git dependency in the pubspec."""
    pins = []
    # Walk the dependency blocks so a ref is attributed to the right package.
    for line_match in re.finditer(r"^  ([a-z0-9_]+):\s*$", text, re.MULTILINE):
        name = line_match.group(1)
        start = line_match.end()
        nxt = re.search(r"^  [a-z0-9_]+:\s*$", text[start:], re.MULTILINE)
        block = text[start : start + nxt.start()] if nxt else text[start:]
        found = BLOCK.search("\n" + block)
        if not found:
            continue
        url, ref = found.group("url"), found.group("ref")
        slug = re.search(r"github\.com[/:]([^/]+/[^/.]+)", url)
        if slug:
            pins.append((name, slug.group(1), ref))
    return pins


def get(url: str, token: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "elara-check-pins",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main() -> int:
    try:
        text = open(PUBSPEC, encoding="utf-8").read()
    except OSError as error:
        print(f"::error::cannot read {PUBSPEC}: {error}")
        return 1

    pins = find_pins(text)
    if not pins:
        print("No git dependencies pinned in pubspec.yaml; nothing to check.")
        return 0

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        for name, slug, ref in pins:
            print(f"skip  {name}: {slug} @ {ref[:12]} (no GITHUB_TOKEN)")
        return 0

    failures = 0
    for name, slug, ref in pins:
        try:
            repo = get(f"https://api.github.com/repos/{slug}", token)
            branch = repo["default_branch"]
            # "ahead" or "identical" means `ref` is on the branch's history.
            # "behind" or "diverged" means it was rewritten out of it, which is
            # exactly the state that produced "fatal: bad object".
            compare = get(
                f"https://api.github.com/repos/{slug}/compare/{ref}...{branch}",
                token,
            )
        except urllib.error.HTTPError as error:
            print(
                f"::error::{name}: {slug} @ {ref[:12]} is not on the remote "
                f"({error.code}). Pin a commit that is on a branch, or the "
                f"release job cannot resolve it."
            )
            failures += 1
            continue

        status = compare.get("status")
        if status in ("ahead", "identical"):
            print(f"ok    {name}: {slug} @ {ref[:12]} is on {branch}")
        else:
            head = (compare.get("base_commit") or {}).get("sha", "?")[:12]
            print(
                f"::error::{name}: {slug} @ {ref[:12]} is not an ancestor of "
                f"{branch} (status {status}, ref resolves to {head}). The "
                f"branch has moved and this commit is no longer servable; "
                f"re-pin to a commit on {branch}."
            )
            failures += 1

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
