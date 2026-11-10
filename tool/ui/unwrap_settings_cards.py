#!/usr/bin/env python3
"""Unwrap the ElaraCard blocks in the Settings screen.

The Settings screen was five rounded rectangles in a row: every group of
controls had its own filled surface, so the page read as a stack of boxes
rather than as one page with sections. The primitives file already documents
the intended pattern — a heading, its content and a hairline — and this
script applies it to that screen only.

It rewrites

    ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...
        ],
      ),
    ),

into the bare children, re-indented to sit with the other items of the
surrounding list. Nothing inside a card is changed, and nothing is deleted.

Run from the repository root:

    python3 tool/ui/unwrap_settings_cards.py

The script refuses to run if it has already been applied, so it cannot
duplicate anything.
"""

import re
import sys

PATH = "lib/screens/settings/settings_screen.dart"

# The About screen has the same problem — four rounded rectangles in a column
# — and the same fix.
EXTRA_PATHS = ["lib/screens/settings/about_section.dart"]


def find_card_blocks(lines):
    """Return (start, end, card_indent, children) for every ElaraCard block."""
    blocks = []
    i = 0
    while i < len(lines):
        if lines[i].strip() != "ElaraCard(":
            i += 1
            continue

        card_indent = len(lines[i]) - len(lines[i].lstrip())
        j = i + 1
        if lines[j].strip() != "child: Column(":
            raise SystemExit(f"unexpected card shape at line {i + 1}")

        # Walk to the Column's children list.
        j += 1
        while "children: [" not in lines[j]:
            j += 1
        j += 1

        depth = 1
        children = []
        while depth > 0:
            line = lines[j]
            children.append(line)
            depth += line.count("[") - line.count("]")
            j += 1

        if children[-1].strip() != "],":
            raise SystemExit(f"unexpected children list at line {j}")
        children = children[:-1]

        # '),' closes the Column, then '),' closes the ElaraCard.
        if lines[j].strip() != ")," or lines[j + 1].strip() != "),":
            raise SystemExit(f"unexpected card ending at line {j + 1}")

        blocks.append((i, j + 1, card_indent, children))
        i = j + 2
    return blocks


def unwrap(path):
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    lines = source.split("\n")

    blocks = find_card_blocks(lines)
    if not blocks:
        print(f"{path}: no ElaraCard blocks found — already applied?")
        return 0

    for start, end, card_indent, children in reversed(blocks):
        # The children were indented by the card (4), the Column (2) and the
        # list (2) relative to the card's own indent. They now sit directly
        # in the surrounding list, four spaces shallower.
        shift = 8
        rebuilt = []
        for child in children:
            if not child.strip():
                rebuilt.append(child)
                continue
            current = len(child) - len(child.lstrip())
            rebuilt.append(" " * max(0, current - shift) + child.strip())
        lines[start:end + 1] = rebuilt

    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    print(f"{path}: unwrapped {len(blocks)} card(s).")
    return 0


def main():
    status = 0
    for path in [PATH] + EXTRA_PATHS:
        status |= unwrap(path)
    return status


if __name__ == "__main__":
    sys.exit(main())
