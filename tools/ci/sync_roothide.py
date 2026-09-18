#!/usr/bin/env python3
"""Sync upstream Reynard into the RootHide fork and re-apply local changes.

This script runs inside GitHub Actions. Upstream is merged with a
"prefer upstream" conflict strategy, then every RootHide-specific local
change is restored or re-applied on top, because those changes are what
make the fork work in a RootHide jailbroken environment.

It is written to be re-runnable: if it is executed on a tree where the
merge has already happened, the merge step is skipped.
"""

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The preference merge is large enough to live in its own module next to this
# script, so it can be reviewed on its own.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prefs_merge import merge_preferences

# Files that must keep the fork's local version instead of upstream's.
# main.swift carries the RootHide runtime policy hook, which upstream does not
# have; it is restored here and then adapted by fix_main_swift().
KEEP_LOCAL = [
    "browser/Helper/Helper.swift",
    "browser/Reynard/main.swift",
    "browser/Reynard/Client/Preferences/BrowserPreferences.swift",
    # The fork's Gecko build wrapper restores .mozconfig and recovers from
    # invalid Mach-O archives. Upstream's version has neither, and the trap
    # left behind without its function fails the build step.
    "tools/development/build-gecko.sh",
    "README.md",
]

# These files are tightly coupled to APIs that upstream renamed or reshaped
# (session metrics, toolbar, downloads, add-ons, Gecko patches). A block-level
# merge would leave behind calls that no longer match the new signatures, so
# upstream's version is taken whole, exactly as the manual merge did.
FORCE_UPSTREAM = [
    "patches/docshell/base/BrowsingContext.cpp.patch",
    "patches/docshell/base/BrowsingContext.h.patch",
    "patches/docshell/base/nsDocShell.cpp.patch",
    "patches/dom/base/Navigator.cpp.patch",
    "patches/dom/base/Navigator.h.patch",
    "patches/dom/webidl/Navigator.webidl.patch",
    "browser/GeckoView/Session/GeckoSession.swift",
    "browser/Reynard/Client/Interface/ContentView/ContentView.swift",
    "browser/Reynard/Client/Interface/BrowserViewController.swift",
    "browser/Reynard/Client/Interface/BrowserViewController+AddressBar.swift",
    "browser/Reynard/Client/Interface/Chrome/AddressBar/AddressBar.swift",
    "browser/Reynard/Client/Interface/Library/Downloads/DownloadItemCell.swift",
    "browser/Reynard/Client/Interface/Library/Downloads/DownloadsViewController.swift",
    "browser/Reynard/Client/Interface/Library/Settings/Sections/General/Browsing/"
    "BrowsingPreferencesViewController.swift",
    "browser/Reynard/Client/Interface/Library/Settings/Sections/General/"
    "GeneralSettingsSection.swift",
    "browser/Reynard/Client/Interface/Addons/AddonCoordinator.swift",
    "browser/Reynard/Client/Stores/DownloadStore.swift",
    "browser/Reynard/Client/TabManagement/TabManagerImpl.swift",
]

# Files removed on purpose: this fork ships only the RootHide package.
DROP_PATHS = [
    ".github/workflows/build.yml",
    ".github/workflows/build-nightly.yml",
    ".github/workflows/build-release.yml",
    "browser/Reynard/Client/Interface/Library/Settings/Sections/Advanced/Compatibility/"
    "AdvancedOptions/AdvancedOptionsPreferencesViewController.swift",
    "browser/Reynard/Client/Interface/Library/Settings/Sections/Advanced/Compatibility/"
    "AdvancedOptions/AdvancedOptionsValueCell.swift",
]


def sh(cmd, check=True):
    print("+ %s" % cmd, flush=True)
    result = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise SystemExit("command failed: %s" % cmd)
    return result.stdout.strip()


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as handle:
        handle.write(text)


def replace_once(path, old, new, what):
    """Replace `old` with `new` exactly once, failing loudly otherwise."""
    text = read(path)
    if old not in text:
        raise SystemExit("anchor not found in %s while applying: %s" % (path, what))
    write(path, text.replace(old, new, 1))
    print("  applied: %s" % what)


def ensure_upstream_remote():
    sh("git remote add upstream https://github.com/minh-ton/reynard-browser.git || true")
    sh("git fetch upstream main --no-tags")


def merge_upstream():
    result = subprocess.run(
        "git merge -X theirs --no-edit upstream/main",
        shell=True, cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode == 0:
        print("merged upstream cleanly")
        return

    print("merge reported conflicts; resolving with the prefer-upstream policy")
    conflicts = sh("git diff --name-only --diff-filter=U").splitlines()
    for path in conflicts:
        if not path:
            continue
        # A delete/modify conflict keeps upstream's content; the paths this
        # fork removed are dropped explicitly afterwards.
        subprocess.run("git checkout --theirs -- %s" % path, shell=True, cwd=ROOT)
        sh("git add -- %s" % path)
    sh("git commit --no-edit -m 'Merge upstream/main into RootHide fork'")


def restore_local(pre_merge_sha):
    for path in KEEP_LOCAL:
        sh("git checkout %s -- %s" % (pre_merge_sha, path))
        print("  kept local version: %s" % path)

    for path in DROP_PATHS:
        if os.path.exists(os.path.join(ROOT, path)):
            sh("git rm -f -q -- %s" % path)
            print("  dropped: %s" % path)


def force_upstream_files():
    """Take upstream's version whole for API-coupled files."""
    for path in FORCE_UPSTREAM:
        result = subprocess.run(
            "git checkout upstream/main -- %s" % path,
            shell=True, cwd=ROOT, capture_output=True, text=True,
        )
        if result.returncode != 0:
            print("  skip (not upstream): %s" % path)
            continue
    print("  forced %d API-coupled files to upstream version" % len(FORCE_UPSTREAM))


def fix_main_swift():
    """Drop the removed UserDataMigration call, keep the RootHide policy hook."""
    path = "browser/Reynard/main.swift"
    text = read(path)
    if "UserDataMigration.shared.run()" in text:
        text = text.replace("UserDataMigration.shared.run()\n", "")
        write(path, text)
        print("  main.swift: removed obsolete UserDataMigration call")
    if "configureRootHideRuntimePolicy()" not in text:
        raise SystemExit("main.swift lost configureRootHideRuntimePolicy()")


def merge_localizations(pre_merge_sha):
    """Union of both catalogs, with the fork's translations taking priority."""
    path = "browser/Reynard/Resources/Localizable.xcstrings"
    ours = json.loads(sh("git show %s:%s" % (pre_merge_sha, path)))
    theirs = json.loads(read(path))

    merged = {
        "sourceLanguage": theirs.get("sourceLanguage", "en"),
        "version": theirs.get("version", "1.0"),
        "strings": {},
    }
    for key, value in theirs["strings"].items():
        entry = json.loads(json.dumps(value))
        if key in ours["strings"]:
            localizations = entry.setdefault("localizations", {})
            for language, loc in ours["strings"][key].get("localizations", {}).items():
                localizations[language] = json.loads(json.dumps(loc))
            if "comment" in ours["strings"][key] and "comment" not in entry:
                entry["comment"] = ours["strings"][key]["comment"]
        merged["strings"][key] = entry

    for key, value in ours["strings"].items():
        if key not in merged["strings"]:
            merged["strings"][key] = json.loads(json.dumps(value))

    merged["strings"] = dict(sorted(merged["strings"].items()))
    with open(os.path.join(ROOT, path), "w", encoding="utf-8") as handle:
        json.dump(merged, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("  Localizable.xcstrings: merged %d strings" % len(merged["strings"]))


def fix_toolbar_controller():
    """Re-apply the local scroll-to-hide preference to upstream's new signature."""
    path = "browser/Reynard/Client/Interface/Chrome/Toolbar/ToolbarController.swift"
    text = read(path)
    old = "        guard Prefs.AppearanceSettings.scrollToHideToolbarEnabled,"
    new = ("        guard Prefs.BrowsingSettings.hidesChromeOnScroll,\n"
           "              Prefs.AppearanceSettings.scrollToHideToolbarEnabled,")
    if new in text:
        return
    if old not in text:
        raise SystemExit("toolbar scroll guard anchor missing")
    write(path, text.replace(old, new, 1))
    print("  ToolbarController: restored hidesChromeOnScroll guard")


NETWORK_INCLUDES_OLD = "#include <net/if.h>\n#include <resolv.h>\n"
NETWORK_INCLUDES_NEW = (
    "#include <arpa/inet.h>\n#include <errno.h>\n"
    "#include <mach-o/dyld.h>\n#include <net/if.h>\n"
    "#include <resolv.h>\n#include <string.h>\n"
    "#include <sys/socket.h>\n#include <unistd.h>\n"
)

NETWORK_HELPERS_ANCHOR = "static Atomic<bool, Relaxed> sHasNonLocalIPv6{true};\n"
NETWORK_HELPERS = NETWORK_HELPERS_ANCHOR + '''
// RootHide injects roothideinit.dylib into every process it manages. Inside
// that jailed environment the Network.framework path monitor is unreliable: it
// may report the path as unsatisfied, or never invoke its update handler at
// all, even though ordinary sockets connect normally. Trusting it blindly
// makes Gecko believe the device is offline and fail every request, so detect
// the environment once and fall back to a real route lookup.
static bool IsRootHideInjectionActive() {
  static bool sActive = [] {
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t index = 0; index < imageCount; index++) {
      const char* imagePath = _dyld_image_name(index);
      if (imagePath && strstr(imagePath, "/usr/lib/roothideinit.dylib")) {
        return true;
      }
    }
    return false;
  }();
  return sActive;
}

// Lightweight reachability probe. A UDP connect does not transmit any packet,
// it only asks the kernel whether a route to the address exists, so this is
// cheap enough to call from the monitor queue and from startup.
static bool ProbeNetworkReachability() {
  int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (fd < 0) {
    return false;
  }

  struct timeval timeout;
  timeout.tv_sec = 2;
  timeout.tv_usec = 0;
  setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_family = AF_INET;
  address.sin_len = sizeof(address);
  address.sin_port = htons(53);
  address.sin_addr.s_addr = inet_addr("8.8.8.8");

  bool reachable =
      connect(fd, reinterpret_cast<struct sockaddr*>(&address),
              sizeof(address)) == 0 ||
      errno == EINPROGRESS || errno == EWOULDBLOCK;
  int savedErrno = errno;
  close(fd);
  errno = savedErrno;
  return reachable;
}
'''

NETWORK_LINK_OLD = (
    "  newState.mStatusKnown = status != nw_path_status_invalid;\n"
    "  newState.mLinkUp = status == nw_path_status_satisfied;\n"
)
NETWORK_LINK_NEW = NETWORK_LINK_OLD + '''
  // RootHide fallback: prefer an actual route lookup over the path monitor so
  // a false "unsatisfied" report cannot take the whole browser offline.
  if (IsRootHideInjectionActive() &&
      (!newState.mStatusKnown || !newState.mLinkUp) &&
      ProbeNetworkReachability()) {
    LOG(("nsIOSNetworkLinkService: RootHide reported the link as down but a "
         "route is available; treating the link as up.\\n"));
    newState.mStatusKnown = true;
    newState.mLinkUp = true;
  }
'''

NETWORK_MONITOR_OLD = (
    "  mMonitor = nw_path_monitor_create();\n"
    "  if (!mMonitor) {\n"
    "    return NS_ERROR_FAILURE;\n"
    "  }\n"
)
NETWORK_MONITOR_NEW = (
    "  mMonitor = nw_path_monitor_create();\n"
    "  if (!mMonitor) {\n"
    "    // The path monitor can be unavailable inside a RootHide\n"
    "    // environment. Fall back to a real route lookup instead of\n"
    "    // failing, so the browser does not start up believing the\n"
    "    // device is offline.\n"
    "    {\n"
    "      MutexAutoLock lock(mMutex);\n"
    "      mState.mStatusKnown = true;\n"
    "      mState.mLinkUp = ProbeNetworkReachability();\n"
    "    }\n"
    "    return NS_OK;\n"
    "  }\n"
)

NETWORK_START_OLD = (
    "  nw_path_monitor_set_queue(mMonitor, mQueue);\n"
    "  nw_path_monitor_start(mMonitor);\n"
    "  return NS_OK;\n"
)
NETWORK_START_NEW = (
    "  nw_path_monitor_set_queue(mMonitor, mQueue);\n"
    "\n"
    "  // RootHide's injected environment can delay or suppress the first\n"
    "  // path update. Seed an optimistic state from an actual route lookup\n"
    "  // so requests are not blocked while the monitor has not reported.\n"
    "  if (IsRootHideInjectionActive() && ProbeNetworkReachability()) {\n"
    "    MutexAutoLock lock(mMutex);\n"
    "    mState.mStatusKnown = true;\n"
    "    mState.mLinkUp = true;\n"
    "  }\n"
    "\n"
    "  nw_path_monitor_start(mMonitor);\n"
    "  return NS_OK;\n"
)


def apply_network_fix():
    """Make the Gecko link service reliable under RootHide.

    The patch file adds netwerk/system/ios/nsIOSNetworkLinkService.mm, so the
    edits are applied to the patch body and the hunk header is recounted.
    """
    path = "patches/netwerk/system/ios/nsIOSNetworkLinkService.mm.patch"
    lines = read(path).split("\n")
    header_index = next(i for i, line in enumerate(lines) if line.startswith("@@"))
    header = lines[:header_index]
    content = [
        line[1:] if line.startswith("+") else line
        for line in lines[header_index + 1:]
        if line.startswith("+")
    ]

    body = "\n".join(content)
    for old, new, what in [
        (NETWORK_INCLUDES_OLD, NETWORK_INCLUDES_NEW, "includes"),
        (NETWORK_HELPERS_ANCHOR, NETWORK_HELPERS, "RootHide probe helpers"),
        (NETWORK_LINK_OLD, NETWORK_LINK_NEW, "link status fallback"),
        (NETWORK_MONITOR_OLD, NETWORK_MONITOR_NEW, "monitor failure fallback"),
        (NETWORK_START_OLD, NETWORK_START_NEW, "optimistic initial state"),
    ]:
        if new.strip() in body:
            continue
        if old not in body:
            raise SystemExit("network patch anchor missing: %s" % what)
        body = body.replace(old, new, 1)

    body_lines = body.split("\n")
    out = header + ["@@ -0,0 +1,%d @@" % len(body_lines)]
    out += ["+" + line if line else "+" for line in body_lines]
    write(path, "\n".join(out) + "\n")
    print("  network fix applied (%d lines)" % len(body_lines))


def apply_addon_sideloading():
    """Accept .xpi packages from any origin, not just addons.mozilla.org."""
    path = "browser/Reynard/Client/Interface/Addons/AddonCoordinator.swift"
    text = read(path)
    if "shouldInterceptAddonInstall" in text:
        return

    # Match the whole function so that blank-line indentation differences
    # between trees cannot make the anchor miss.
    import re
    pattern = re.compile(
        r"    private func shouldInterceptAMOInstall\(_ response: ExternalResponseInfo\) -> Bool \{"
        r".*?\n    \}",
        re.DOTALL,
    )
    if not pattern.search(text):
        raise SystemExit("add-on interception anchor missing")
    new = '''    // Accept add-on packages from any origin, not just addons.mozilla.org.
    // Sideloading a local or self-hosted .xpi is often the only way to install
    // an extension on a jailbroken device, so restricting the host would block
    // legitimate packages. The add-on still goes through the normal install
    // and permission prompt flow.
    private func shouldInterceptAddonInstall(_ response: ExternalResponseInfo) -> Bool {
        guard let url = URL(string: response.url) else {
            return false
        }

        if url.isFileURL {
            return url.pathExtension.lowercased() == "xpi"
        }

        return url.path.lowercased().hasSuffix(".xpi")
    }'''
    updated = pattern.sub(lambda _: new, text, count=1)
    updated = updated.replace(
        "guard shouldInterceptAMOInstall(response) else {",
        "guard shouldInterceptAddonInstall(response) else {", 1)
    write(path, updated)
    print("  add-on sideloading enabled")


TRIM_MEMORY_ANCHOR = """    func invalidateNavigationThumbnails() {
        sessionManager.invalidateNavigationThumbnails()
    }
"""
TRIM_MEMORY_NEW = TRIM_MEMORY_ANCHOR + '''    
    // Drop cached images that can be regenerated on demand when the system is
    // under memory pressure. Tabs, browsing history, and page state are left
    // untouched, so nothing the user can lose is discarded here.
    func trimMemory() {
        sessionManager.invalidateNavigationThumbnails()
        
        for mode in [TabMode.regular, TabMode.private] {
            for tab in tabs(for: mode) {
                tab.thumbnail = nil
            }
        }
    }
    
'''


def apply_memory_optimizations():
    """Implement trimMemory() and hook it up to memory warnings.

    Upstream declares trimMemory() in the TabManager protocol but never
    implements it, which fails to compile and leaves no way to release
    regenerable caches under memory pressure.
    """
    path = "browser/Reynard/Client/TabManagement/TabManagerImpl.swift"
    text = read(path)
    if "func trimMemory()" not in text:
        replace_once(path, TRIM_MEMORY_ANCHOR, TRIM_MEMORY_NEW, "trimMemory()")

    scene = "browser/Reynard/SceneDelegate.swift"
    text = read(scene)
    if "handleMemoryWarning" not in text:
        replace_once(
            scene,
            "        handleIncomingURLContexts(connectionOptions.urlContexts)\n    }\n",
            "        observeMemoryWarnings()\n"
            "        handleIncomingURLContexts(connectionOptions.urlContexts)\n"
            "    }\n    \n"
            "    private func observeMemoryWarnings() {\n"
            "        NotificationCenter.default.addObserver(\n"
            "            self,\n"
            "            selector: #selector(handleMemoryWarning),\n"
            "            name: UIApplication.didReceiveMemoryWarningNotification,\n"
            "            object: nil\n"
            "        )\n"
            "    }\n"
            "    \n"
            "    // Release regenerable caches instead of letting the OS kill the app.\n"
            "    // Tabs, history, and page state are preserved by trimMemory().\n"
            "    @objc private func handleMemoryWarning() {\n"
            "        (window?.rootViewController as? BrowserViewController)?\n"
            "            .tabManager.trimMemory()\n"
            "    }\n",
            "memory warning handling",
        )


def apply_offline_pref():
    """Stop Gecko from entering offline mode based on link status alone."""
    path = "browser/Reynard/main.swift"
    text = read(path)
    if "network.manage-offline-status" in text:
        return
    old = '        "dom.ipc.keepProcessesAlive.privilegedabout": 0\n'
    new = ('        "dom.ipc.keepProcessesAlive.privilegedabout": 0,\n'
           '        // RootHide keeps the app in a jailed environment where the\n'
           '        // Network framework path monitor can report the link as down\n'
           '        // even though sockets connect normally. Let real connection\n'
           '        // attempts decide reachability instead of letting a link-status\n'
           '        // change flip Gecko into offline mode and fail every request.\n'
           '        "network.manage-offline-status": false\n')
    if old not in text:
        raise SystemExit("RootHide prefs anchor missing in main.swift")
    write(path, text.replace(old, new, 1))
    print("  offline-status management disabled under RootHide")


def main():
    os.chdir(ROOT)
    ensure_upstream_remote()
    pre_merge_sha = sh("git rev-parse HEAD")
    print("pre-merge HEAD: %s" % pre_merge_sha)

    already_merged = subprocess.run(
        "git merge-base --is-ancestor upstream/main HEAD",
        shell=True, cwd=ROOT, capture_output=True,
    ).returncode == 0

    if already_merged:
        print("upstream already merged; skipping merge")
        pre_merge_sha = os.environ.get("PRE_MERGE_SHA", pre_merge_sha)
    else:
        # Keep the marker outside the repository so it never lands in a commit.
        marker_dir = os.environ.get("RUNNER_TEMP", "/tmp")
        with open(os.path.join(marker_dir, "reynard-pre-merge-sha"), "w") as handle:
            handle.write(pre_merge_sha)
        merge_upstream()

    print("restoring RootHide local changes")
    force_upstream_files()
    restore_local(pre_merge_sha)
    fix_main_swift()
    merge_preferences()
    merge_localizations(pre_merge_sha)
    fix_toolbar_controller()

    print("applying RootHide fixes")
    apply_network_fix()
    apply_offline_pref()
    apply_addon_sideloading()
    apply_memory_optimizations()

    sh("git add -A")
    status = sh("git status --porcelain", check=False)
    if not status:
        print("no changes to commit")
        return
    sh("git commit -m 'RootHide: restore local changes after upstream sync'")
    print("committed RootHide changes")


if __name__ == "__main__":
    main()
