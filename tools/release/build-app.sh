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
