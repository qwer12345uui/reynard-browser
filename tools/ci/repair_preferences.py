#!/usr/bin/env python3
"""Repair browser sources that the upstream merge leaves half reconciled.

Two kinds of damage show up after tools/ci/sync_roothide.py merges upstream:

1. The preference merge can drop the declaration line of a nested preferences
   container, leaving a bare "{" at column zero. Swift cannot parse that, so the
   archive step fails with a dozen unrelated looking errors.

2. SceneDelegate carries RootHide lifecycle optimisations that call download
   store entry points upstream deleted during its downloads rewrite. The fork
   keeps its own SceneDelegate (the merge only takes upstream on conflict), so
   those calls go stale at exactly the commits where everything else moves on.

Every repair is idempotent and anchor based, so this can stay in the pipeline:

* it no-ops and exits 0 when everything is already in place;
* it exits 1 and names the missing anchor when upstream renames something, so
  the failure surfaces here instead of twenty minutes into an Xcode archive.
"""

from __future__ import annotations

import sys
from pathlib import Path

PREFERENCES = Path("browser/Reynard/Client/Preferences/BrowserPreferences.swift")
SCENE_DELEGATE = Path("browser/Reynard/SceneDelegate.swift")

# container declaration -> the first member that identifies it
DECLARATIONS = (
    ("DNSOverHTTPSPreferences", "DNS over HTTPS", "static var protectionLevel: DNSOverHTTPSProtectionLevel {"),
    ("DeveloperSettings", "Developer", "static var remoteDebuggingEnabled: Bool {"),
)

# User-agent override preferences consumed by UserAgentPolicy.
OVERRIDES = ("customUserAgent", "customPlatform", "customAppVersion", "customOscpu", "customBuildID")

DEFAULT_ANCHOR = '            key("CompatibilitySettings", "useAndroidUserAgent"): false,\n'

ACCESSOR_ANCHOR = """        static var useAndroidUserAgent: Bool {
            get {
                prefs.bool(forSetting: "CompatibilitySettings", key: "useAndroidUserAgent")
            }
            set {
                prefs.set(newValue, forSetting: "CompatibilitySettings", key: "useAndroidUserAgent")
            }
        }
"""

# Download store entry points removed by upstream's downloads rewrite. Every
# other call in this file still exists upstream, including
# setApplicationForeground(_:), so only these two lines are dropped.
REMOVED_SCENE_CALLS = (
    "        DownloadStore.shared.applicationDidBecomeActive()\n",
    "        DownloadStore.shared.applicationDidEnterBackground()\n",
)


def restore_declarations(text: str, applied: list) -> str:
    for name, mark, member in DECLARATIONS:
        if "struct %s {" % name in text:
            continue
        damaged = "{\n        %s" % member
        if text.count(damaged) != 1:
            raise SystemExit(
                "BrowserPreferences: expected exactly one damaged declaration for %s, found %d"
                % (name, text.count(damaged))
            )
        text = text.replace(
            damaged,
            "    // MARK: - %s\n    struct %s {\n        %s" % (mark, name, member),
            1,
        )
        applied.append("restored struct %s" % name)
    return text


def add_override_preferences(text: str, applied: list) -> str:
    missing = [key for key in OVERRIDES if 'static var %s: String' % key not in text]
    if not missing:
        return text

    if text.count(DEFAULT_ANCHOR) != 1:
        raise SystemExit(
            "BrowserPreferences: useAndroidUserAgent default anchor matched %d times" % text.count(DEFAULT_ANCHOR)
        )
    text = text.replace(
        DEFAULT_ANCHOR,
        DEFAULT_ANCHOR
        + "".join('            key("CompatibilitySettings", "%s"): "",\n' % key for key in OVERRIDES),
        1,
    )

    if text.count(ACCESSOR_ANCHOR) != 1:
        raise SystemExit(
            "BrowserPreferences: useAndroidUserAgent accessor anchor matched %d times" % text.count(ACCESSOR_ANCHOR)
        )
    head, tail = text.split(ACCESSOR_ANCHOR, 1)
    if not tail.startswith("    }\n"):
        raise SystemExit("BrowserPreferences: CompatibilitySettings does not end right after the accessor block")

    block = "".join(
        "        \n"
        "        static var %s: String {\n"
        "            get {\n"
        '                return prefs.string(forSetting: "CompatibilitySettings", key: "%s") ?? ""\n'
        "            }\n"
        "            set {\n"
        '                prefs.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forSetting: "CompatibilitySettings", key: "%s")\n'
        "            }\n"
        "        }\n" % (key, key, key)
        for key in OVERRIDES
    )
    applied.append("added %d user-agent override preferences" % len(OVERRIDES))
    return head + ACCESSOR_ANCHOR + block + tail


def repair_preferences(applied: list) -> None:
    if not PREFERENCES.is_file():
        print("BrowserPreferences.swift not found; nothing to repair.")
        return
    text = PREFERENCES.read_text()
    text = restore_declarations(text, applied)
    text = add_override_preferences(text, applied)
    PREFERENCES.write_text(text)


def repair_scene_delegate(applied: list) -> None:
    if not SCENE_DELEGATE.is_file():
        print("SceneDelegate.swift not found; nothing to repair.")
        return
    text = SCENE_DELEGATE.read_text()
    for line in REMOVED_SCENE_CALLS:
        if line not in text:
            continue
        text = text.replace(line, "", 1)
        applied.append("dropped removed SceneDelegate call %s" % line.strip())
    SCENE_DELEGATE.write_text(text)


def main() -> int:
    applied: list = []
    repair_preferences(applied)
    repair_scene_delegate(applied)

    if not applied:
        print("Browser sources already healthy; nothing to do.")
        return 0

    print("Repaired browser sources after the upstream merge:")
    for item in applied:
        print("  - %s" % item)
    return 0


if __name__ == "__main__":
    sys.exit(main())
