"""Merge upstream preference declarations into the fork's settings file.

The fork carries a large amount of settings upstream does not have (downloads,
playback, clipboard, toolbar). A line-level merge cannot tell fork-only entries
from upstream-only entries, so the fork's own file is kept and the preferences
upstream's code actually references are copied over as whole declarations.
"""

import os
import re
import subprocess

PREFERENCES_PATH = "browser/Reynard/Client/Preferences/BrowserPreferences.swift"


def sh(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("command failed: %s" % cmd)
    return result.stdout.strip()


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def extract_brace_block(text, start):
    """Slice of `text` from `start` up to the brace that closes that block."""
    depth = 0
    opened = False
    for index in range(start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
            opened = True
        elif char == "}":
            depth -= 1
            if opened and depth == 0:
                return text[start:index + 1]
    return None


def extract_member_block(text, name):
    """Upstream's full `static var/let/func <name>` declaration."""
    import re

    pattern = re.compile(
        r"^[ \t]*(?:public |private |internal |fileprivate |open )*"
        r"static\s+(?:var|let|func)\s+" + re.escape(name) + r"\b",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        return None
    return extract_brace_block(text, match.start()) or \
        text[match.start():text.find("\n", match.start())]


def find_block_insertion_point(text, keyword, name):
    """Offset just before the closing brace of `<keyword> <name> { ... }`."""
    import re

    match = re.search(r"^[ \t]*(?:final\s+|public\s+|private\s+|internal\s+)*"
                      + keyword + r"\s+" + re.escape(name) + r"\b[^{]*\{",
                      text, re.MULTILINE)
    if not match:
        return None
    block = extract_brace_block(text, match.end() - 1)
    if block is None:
        return None
    return match.end() - 1 + len(block) - 1


def extract_struct_block(text, name):
    """Upstream's complete `struct <name> { ... }` block."""
    import re

    match = re.search(r"^[ \t]*(?:public |private |internal )*struct\s+"
                      + re.escape(name) + r"\b[^{]*\{", text, re.MULTILINE)
    if not match:
        return None
    return extract_brace_block(text, match.end() - 1)


def add_default_keys(text, upstream, section):
    """Copy upstream's default values for a settings section."""
    import re

    pattern = re.compile(r'^\s*key\("%s",\s*"[^"]+"\):.*,$' % section,
                         re.MULTILINE)
    missing = [m.group(0).strip() for m in pattern.finditer(upstream)
               if m.group(0).strip() not in text]
    if not missing:
        return text
    last = None
    for match in re.finditer(r"^\s*key\(.*,$", text, re.MULTILINE):
        last = match
    if last is None:
        return text
    return (text[:last.end()] + "\n" + "\n".join(missing) + text[last.end():])


def referenced_preference_members():
    """Every `Prefs.<Section>.<member>` used anywhere in the app."""
    references = {}
    for root, _dirs, files in os.walk("browser"):
        for name in files:
            if not name.endswith(".swift"):
                continue
            full = os.path.join(root, name)
            if os.path.relpath(full, ".") == PREFERENCES_PATH:
                continue
            with open(full, encoding="utf-8", errors="ignore") as handle:
                source = handle.read()
            for match in re.finditer(r"\bPrefs\.(\w+)\.(\w+)", source):
                references.setdefault(match.group(2), set()).add(match.group(1))
    return references


def merge_preferences():
    """Keep the fork's settings and add only the members upstream code needs.

    This fork carries a large amount of settings upstream does not have
    (downloads, playback, clipboard, toolbar). A line-level merge cannot tell
    fork-only entries from upstream-only entries, so the fork's own file is
    kept and the preferences upstream's code actually references are copied
    over as whole declarations.
    """
    import re

    path = PREFERENCES_PATH
    text = read(path)
    upstream = sh("git show upstream/main:%s" % path)
    defined = set(re.findall(r"static\s+(?:var|let|func)\s+(\w+)", text))

    added = []
    for member, sections in sorted(referenced_preference_members().items()):
        if member == "self" or member in defined:
            continue
        section = sorted(sections)[0]

        if find_block_insertion_point(text, "struct", section) is None:
            # Upstream introduced a whole settings section this fork lacks.
            # Move the section over, since its members are referenced too.
            struct_block = extract_struct_block(upstream, section)
            class_point = find_block_insertion_point(
                text, "class", "BrowserPreferences")
            if struct_block is None or class_point is None:
                continue
            text = (text[:class_point] + "\n" + struct_block + "\n"
                    + text[class_point:])
            text = add_default_keys(text, upstream, section)
            for name in re.findall(r"static\s+(?:var|let|func)\s+(\w+)",
                                   struct_block):
                defined.add(name)
            added.append("struct " + section)
            continue

        block = extract_member_block(upstream, member)
        if block is None:
            continue
        point = find_block_insertion_point(text, "struct", section)
        text = text[:point] + "\n" + block + "\n" + text[point:]
        defined.add(member)
        text = add_default_keys(text, upstream, section)
        added.append(member)

    still_missing = [m for m in referenced_preference_members()
                     if m != "self" and m not in defined]
    if still_missing:
        raise SystemExit("preferences still missing after merge: %s"
                         % ", ".join(sorted(still_missing)))

    write(path, text)
    print("  BrowserPreferences: kept fork settings, added %d upstream members%s"
          % (len(added), (": " + ", ".join(added)) if added else ""))
