#!/usr/bin/env python3
"""Align the fork's browser sources with upstream after the merge.

A merge cannot repair files this fork deliberately moved backwards. Once an
upstream API moves on (the downloads rewrite being the current example) any
call site kept at the old shape simply stops compiling, and the merge happily
keeps the old call site because there is no textual conflict.

Files whose fork-side difference carries RootHide specific code are left alone;
everything else is reset to the upstream version. Upstream-only deletions are
removed and upstream-only additions are restored, so the working tree matches
what the upstream project actually expects to build.

The project uses a synchronized root group, so adding or removing a file needs
no project file edit.
"""

from __future__ import annotations

import os
import subprocess
import sys

UPSTREAM_REF = "upstream/main"
SEARCH_PATH = "browser"

# Files this fork owns outright. Resetting them would drop the RootHide
# runtime policy, the helper process and the fork's settings file.
FORK_OWNED = (
    "browser/Helper/Helper.swift",
    "browser/Reynard/main.swift",
    "browser/Reynard/Client/Preferences/BrowserPreferences.swift",
)

# Markers that identify a fork-side change as RootHide work worth keeping.
GUARD = (
    "roothide",
    "jailbreak",
    "injection",
    "libhooker",
    "trimmemory",
    "usesbackgroundblur",
    "jitcontroller",
    "network.manage-offline-status",
    "isroothideinjectionactive",
)


def run(cmd):
    return subprocess.run(cmd, shell=True, cwd=os.getcwd(), capture_output=True, text=True)


def sh(cmd):
    result = run(cmd)
    if result.returncode != 0:
        raise SystemExit("command failed: %s\n%s" % (cmd, result.stderr.strip()))
    return result.stdout.strip()


def fork_side_carries_roothide(path):
    diff = run("git diff HEAD %s -- %s" % (UPSTREAM_REF, path)).stdout
    for line in diff.splitlines():
        # Only lines this fork removed relative to upstream can be its own work.
        if not line.startswith("-") or line.startswith("---"):
            continue
        lowered = line.lower()
        if any(marker in lowered for marker in GUARD):
            return True
    return False


def main():
    if run("git rev-parse --verify %s" % UPSTREAM_REF).returncode != 0:
        raise SystemExit("%s is not available; run the merge step first" % UPSTREAM_REF)

    status = sh("git diff --name-status HEAD %s -- %s" % (UPSTREAM_REF, SEARCH_PATH))
    aligned, restored, removed, skipped = [], [], [], []

    for line in status.splitlines():
        if not line.strip():
            continue
        change, path = line.split("\t", 1)
        if path in FORK_OWNED:
            skipped.append((path, "fork-owned file"))
            continue

        if change == "D":
            # Upstream deleted it; keeping the stale file means compiling code
            # that calls APIs which no longer exist.
            sh("git rm -f -q -- %s" % path)
            removed.append(path)
            continue

        if change == "A":
            sh("git checkout %s -- %s" % (UPSTREAM_REF, path))
            restored.append(path)
            continue

        if change != "M":
            continue

        if fork_side_carries_roothide(path):
            skipped.append((path, "fork-side difference carries RootHide code"))
            continue
        sh("git checkout %s -- %s" % (UPSTREAM_REF, path))
        aligned.append(path)

    print("Aligned %d files with %s" % (len(aligned), UPSTREAM_REF))
    print("Restored %d upstream-only files, removed %d deleted ones" % (len(restored), len(removed)))
    for path in removed:
        print("  removed: %s" % path)
    for path in restored:
        print("  restored: %s" % path)
    if skipped:
        print("Kept %d files for manual review:" % len(skipped))
        for path, reason in skipped:
            print("  kept: %s (%s)" % (path, reason))
    return 0


if __name__ == "__main__":
    sys.exit(main())
