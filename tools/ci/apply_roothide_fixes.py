#!/usr/bin/env python3
"""Re-apply the RootHide fixes after the browser sources are aligned upstream.

tools/ci/align_browser_sources.py resets every file whose fork-side difference
does not carry a RootHide marker back to the upstream version, and it runs
after tools/ci/sync_roothide.py, so a fix applied there can be reverted by it.
Applying the fixes again on the aligned tree repairs whatever was dropped and
is a no-op when nothing was, because every fix checks for its own marker first.

This is also where the sync asserts that RootHide support is still present. An
upstream rewrite can drop one of these silently: there is no textual conflict,
the file simply compiles without the fork's behaviour, and the result is a
browser that looks fine but has no network fallback or no plugin injection.
"""

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# Importing sync_roothide must not leave a __pycache__ behind; the sync job
# commits every untracked file.
sys.dont_write_bytecode = True


def load(name):
    """Import a sibling module by path, without touching sys.path."""
    path = os.path.join(HERE, name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Every RootHide behaviour this fork exists for, and the marker proving it.
MARKERS = (
    ("browser/Reynard/main.swift", "configureRootHideRuntimePolicy",
     "RootHide runtime policy hook"),
    ("patches/netwerk/system/ios/nsIOSNetworkLinkService.mm.patch",
     "IsRootHideInjectionActive", "RootHide network reachability fallback"),
    ("browser/Reynard/Client/Interface/Addons/AddonCoordinator.swift",
     "shouldInterceptAddonInstall", "add-on sideloading from any origin"),
    ("browser/Reynard/Client/TabManagement/TabManagerImpl.swift",
     "func trimMemory()", "memory-pressure cache release"),
    ("browser/Reynard/SceneDelegate.swift", "handleMemoryWarning",
     "memory warning wiring"),
)


def main():
    sr = load("sync_roothide")
    sr.apply_network_fix()
    sr.apply_offline_pref()
    sr.apply_addon_sideloading()
    sr.apply_memory_optimizations()

    missing = []
    for path, marker, what in MARKERS:
        if not os.path.exists(os.path.join(sr.ROOT, path)):
            missing.append("%s (%s): file gone" % (what, path))
        elif marker not in sr.read(path):
            missing.append("%s (%s): %s not found" % (what, path, marker))
    if missing:
        for line in missing:
            print("  missing: %s" % line)
        raise SystemExit("RootHide support was lost during the upstream sync")
    print("verified: all %d RootHide behaviours present" % len(MARKERS))

    sr.sh("git add -A")
    status = sr.sh("git status --porcelain", check=False)
    if not status:
        print("no changes to commit")
        return
    sr.sh("git commit -m 'RootHide: re-apply fixes after upstream alignment'")
    print("committed RootHide fixes")


if __name__ == "__main__":
    main()
