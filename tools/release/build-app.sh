#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT_PATH="$ROOT_DIR/browser/Reynard.xcodeproj"
XCCONFIG_PATH="$ROOT_DIR/browser/Configuration/Reynard.xcconfig"
BUILD_XCCONFIG_PATH="$DIST_DIR/Reynard.xcconfig"

NO_SIGNING=false
NIGHTLY=false

for argument in "$@"; do
	case "$argument" in
		--no-signing)
			NO_SIGNING=true
			;;
		--nightly)
			NIGHTLY=true
			;;
		*) ;;
	esac
done

# Upstream preference merges can leave BrowserPreferences.swift structurally
# damaged (a nested preferences container loses its declaration line, leaving a
# bare "{"). Swift cannot parse that, so repair it before Xcode reads the
# sources. The script is idempotent and fails loudly if its anchors disappear.
REPAIR_SCRIPT="$ROOT_DIR/tools/ci/repair_preferences.py"
if [ -f "$REPAIR_SCRIPT" ]; then
	python3 "$REPAIR_SCRIPT"
fi

# The registered defaults are one Swift dictionary literal. Repeating a key
# inside it is not a compile error, it is a runtime trap: the app dies with
# EXC_BREAKPOINT while BrowserPreferences.shared is built, i.e. it crashes on
# launch on every device. Upstream merges and the CI repair script can both
# leave such a repeat behind, so drop the repeats here and then verify. A
# launch crash is far more expensive to diagnose than a failed job.
python3 - <<'PY'
import collections
import re
import sys

path = "browser/Reynard/Client/Preferences/BrowserPreferences.swift"
try:
    text = open(path, encoding="utf-8").read()
except OSError as error:
    sys.exit("BrowserPreferences: cannot read %s (%s)" % (path, error))

marker = "UserDefaults.standard.register(defaults: [\n"
if text.count(marker) != 1:
    sys.exit("BrowserPreferences: expected exactly one register(defaults:) block")
head, tail = text.split(marker, 1)
end = tail.find("\n        ])")
if end == -1:
    sys.exit("BrowserPreferences: could not find the end of register(defaults:)")
body, rest = tail[:end], tail[end:]

entry = re.compile(
    r'^\s*key\("(?P<setting>[^"]+)",\s*"(?P<name>[^"]+)"\)\s*:\s*(?P<value>.*?),?\s*$'
)
seen = set()
dropped = []
lines = []
for line in body.split("\n"):
    match = entry.match(line)
    if not match:
        lines.append(line)
        continue
    identity = (match.group("setting"), match.group("name"))
    if identity in seen:
        dropped.append("%s.%s" % identity)
        continue
    seen.add(identity)
    lines.append(
        '            key("%s", "%s"): %s,'
        % (match.group("setting"), match.group("name"), match.group("value"))
    )

if dropped:
    open(path, "w", encoding="utf-8").write(head + marker + "\n".join(lines) + rest)
    print("BrowserPreferences: dropped duplicate registrations: %s" % ", ".join(dropped))
    text = open(path, encoding="utf-8").read()

start = text.find(marker)
keys = re.findall(r'key\("([^"]+)",\s*"([^"]+)"\)', text[start:text.find("\n        ])", start)])
duplicates = sorted(name for name, count in collections.Counter(keys).items() if count > 1)
if duplicates:
    sys.exit(
        "BrowserPreferences: duplicate registered defaults would crash on launch: %s"
        % ", ".join(duplicates)
    )
print("BrowserPreferences: %d registered defaults, no duplicates" % len(keys))
PY

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$XCCONFIG_PATH" "$BUILD_XCCONFIG_PATH"

BUILD_SHA=$(git -C "$ROOT_DIR" rev-parse HEAD | cut -c1-7)
sed -i '' -E \
	-e "s|^CURRENT_BUILD = .*|CURRENT_BUILD = $BUILD_SHA|" \
	"$BUILD_XCCONFIG_PATH"

if [ "$NIGHTLY" = true ]; then
	sed -i '' -E \
		-e 's|^(CURRENT_VERSION = [0-9.]+)$|\1-dev|' \
		-e 's|^APP_DISPLAY_NAME = .*|APP_DISPLAY_NAME = Reynard (Nightly)|' \
		"$BUILD_XCCONFIG_PATH"
fi

if [ "$NO_SIGNING" = true ]; then
	# Build unsigned with a plain "build" action instead of "archive". The archive
	# pipeline requires a real signing identity, and the iOS 26 SDK rejects ad-hoc
	# ("-") identities for device builds. The workflow also patches out the
	# "Embed Process Extensions" phase because Xcode's embedded-binary validation
	# cannot pass unsigned; the extensions are copied into PlugIns manually below.
	xcodebuild build \
		-scheme "Reynard" \
		-project "$PROJECT_PATH" \
		-sdk iphoneos \
		-arch arm64 \
		-configuration Release \
		-derivedDataPath "$DIST_DIR/DerivedData" \
		-xcconfig "$BUILD_XCCONFIG_PATH" \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" \
		EXPANDED_CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		PROVISIONING_PROFILE_SPECIFIER="" \
		VALIDATE_PRODUCT=NO

	PRODUCTS_DIR="$DIST_DIR/DerivedData/Build/Products/Release-iphoneos"
	APP_PATH="$PRODUCTS_DIR/Reynard.app"
	test -d "$APP_PATH"

	# Copy app extensions into PlugIns (the workflow removed the embed phase).
	mkdir -p "$APP_PATH/PlugIns"
	for EXT in "OpenIn.appex" "Reynard Helper.appex"; do
		if [ ! -d "$APP_PATH/PlugIns/$EXT" ] && [ -d "$PRODUCTS_DIR/$EXT" ]; then
			cp -R "$PRODUCTS_DIR/$EXT" "$APP_PATH/PlugIns/"
		fi
	done
	test -d "$APP_PATH/PlugIns/OpenIn.appex"
	test -d "$APP_PATH/PlugIns/Reynard Helper.appex"

	# Assemble the layout that create-ipa.sh expects.
	mkdir -p "$DIST_DIR/Reynard.xcarchive/Products/Applications"
	cp -R "$APP_PATH" "$DIST_DIR/Reynard.xcarchive/Products/Applications/"
else
	xcodebuild archive \
		-scheme "Reynard" \
		-archivePath "$DIST_DIR/Reynard.xcarchive" \
		-project "$PROJECT_PATH" \
		-sdk iphoneos \
		-arch arm64 \
		-configuration Release \
		-xcconfig "$BUILD_XCCONFIG_PATH"
fi
