#!/usr/bin/env python3
"""PreToolUse guard: keep agents out of tool-authored or human-owned zones.

Configure the three constants below for the repo. Ownership is encoded in the
directory tree: agents hand-edit only the code zones; everything in a guarded
zone is authored through the repo's tools (or by the human), so malformed or
misplaced state is impossible and an agent cannot relax its own guardrails.

Reads the tool-call JSON on stdin. Exit 2 blocks the call and shows MESSAGE to
the agent; exit 0 allows. Fails open (exit 0) on any unexpected input so it can
never wedge legitimate editing.

Bash coverage is a heuristic (defense in depth, not a guarantee): commands that
redirect/tee into, sed -i, rm, or mv/cp onto a guarded-zone path are blocked;
reads (cat/grep/ls) pass. The repo's tools remain the real chokepoint.
"""

import json
import os
import re
import sys
from pathlib import Path

# -- Per-repo configuration ----------------------------------------------------
GUARDED_ZONES = ("agent", "state", "mandate", ".cache")
# Nearest ancestor holding one of these marks the zone root; .git covers the
# single-repo case, a manifest file covers nested units in a monorepo.
ROOT_MARKERS = ("workflow.yaml", ".git")
MESSAGE = """\
Blocked: '{zone}/' is not hand-editable — it is authored through the repo's
tools (or by the human). See CLAUDE.md's zone table for the right tool.
Only the code zones are directly editable.
"""
# -------------------------------------------------------------------------------

GUARDED_TOOLS = {"Write", "Edit", "MultiEdit"}

_ZONE = r"['\"]?(?:[\w.~/-]*/)?(" + "|".join(re.escape(z) for z in GUARDED_ZONES) + r")/"
BASH_WRITE_PATTERNS = (
    re.compile(r"(?:>>?\s*|\btee\s+(?:-\S+\s+)*)" + _ZONE),  # redirect or tee into a zone
    re.compile(r"\bsed\s+(?:-\S+\s+)*-\S*i\S*\s+[^|;&]*?" + _ZONE),  # in-place sed
    re.compile(r"\brm\s+[^|;&]*?" + _ZONE),  # delete zone files
    re.compile(r"\b(?:mv|cp)\s+[^|;&]*?\s" + _ZONE + r"[\w.-]*\s*(?:$|[;|&])"),  # zone as destination
)


def bash_write_target(command: str) -> str | None:
    for pattern in BASH_WRITE_PATTERNS:
        m = pattern.search(command)
        if m:
            return m.group(1)
    return None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if data.get("tool_name") == "Bash":
        zone = bash_write_target((data.get("tool_input") or {}).get("command") or "")
        if zone:
            sys.stderr.write(MESSAGE.format(zone=zone))
            sys.exit(2)
        sys.exit(0)

    if data.get("tool_name") not in GUARDED_TOOLS:
        sys.exit(0)

    file_path = (data.get("tool_input") or {}).get("file_path")
    if not file_path:
        sys.exit(0)

    target = Path(os.path.realpath(file_path))

    root = next(
        (a for a in target.parents if any((a / m).exists() for m in ROOT_MARKERS)),
        None,
    )
    if root is None:
        sys.exit(0)

    for zone in GUARDED_ZONES:
        z = root / zone
        if target == z or z in target.parents:
            sys.stderr.write(MESSAGE.format(zone=zone))
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
