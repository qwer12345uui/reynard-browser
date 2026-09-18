#!/usr/bin/env python3
"""Repair BrowserPreferences.swift after the upstream preference merge.

The merge script that reconciles this fork with upstream can drop the declaration
line of a nested preferences container, leaving a bare "{" at column zero. Swift
cannot parse that, so the entire archive step fails with a dozen unrelated
looking errors. This script puts the declarations back and carries the
user-agent override preferences that UserAgentPolicy reads.

It is deliberately idempotent and anchor based:

* it no-ops and exits 0 when every piece is already in place, so it can stay in
  the pipeline permanently;
* it exits 1 and prints the missing anchor when upstream renames something, so
  the failure surfaces here instead of twenty minutes into an Xcode archive.
"""

from __future__ import annotations

import sys
from pathlib import Path

PREFERENCES = Path("browser/Reynard/Client/Preferences/BrowserPreferences.swift")

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


def main() -> int:
    if not PREFERENCES.is_file():
        print("BrowserPreferences.swift not found; nothing to repair.")
        return 0

    original = PREFERENCES.read_text()
    applied = []
    text = restore_declarations(original, applied)
    text = add_override_preferences(text, applied)

    if not applied:
        print("BrowserPreferences.swift already healthy; nothing to do.")
        return 0

    PREFERENCES.write_text(text)
    print("Repaired BrowserPreferences.swift:")
    for item in applied:
        print("  - %s" % item)
    return 0


if __name__ == "__main__":
    sys.exit(main())
