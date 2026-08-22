#!/bin/sh
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
FIREFOX_DIR="$ROOT_DIR/engine/firefox"
TARGET="aarch64-apple-ios"
MOZCONFIG_PATH="$FIREFOX_DIR/.mozconfig"
MOZCONFIG_BACKUP="$FIREFOX_DIR/.mozconfig.reynard-backup"
HAD_MOZCONFIG=0
USE_SCCACHE=false
AUTO_CLOBBER=false
DISABLE_JEMALLOC=false

for arg in "$@"; do
	case "$arg" in
		--use-sccache)
			USE_SCCACHE=true
			;;
		--auto-clobber)
			AUTO_CLOBBER=true
			;;
		--disable-jemalloc)
			DISABLE_JEMALLOC=true
			;;
	esac
done

restore_mozconfig() {
	if [ -f "$MOZCONFIG_BACKUP" ]; then
		rm -f "$MOZCONFIG_PATH"
		mv "$MOZCONFIG_BACKUP" "$MOZCONFIG_PATH"
	elif [ "$HAD_MOZCONFIG" -eq 0 ]; then
		rm -f "$MOZCONFIG_PATH"
	fi
}

cd "$ROOT_DIR"
if [ ! -d "$FIREFOX_DIR" ]; then
	echo "Missing firefox source at $FIREFOX_DIR"
	echo "Add the submodule, then run tools/development/update-gecko.sh."
	exit 1
fi

# Fresh Firefox release trees do not necessarily ship a .mozconfig. Preserve an
# existing developer file when present, and always restore the tree on success
# or failure so local and CI invocations are both repeatable.
if [ -f "$MOZCONFIG_PATH" ]; then
	mv "$MOZCONFIG_PATH" "$MOZCONFIG_BACKUP"
	HAD_MOZCONFIG=1
fi
trap restore_mozconfig EXIT HUP INT TERM

{
	echo "ac_add_options --enable-application=mobile/ios"
	echo "ac_add_options --target=$TARGET"
	echo "ac_add_options --enable-ios-target=13.0"
	echo "ac_add_options --enable-webrtc"
	echo "ac_add_options --enable-optimize"
	echo "ac_add_options --enable-release"
	echo "ac_add_options --enable-rust-simd"
	echo "ac_add_options --enable-lto"
	echo "ac_add_options --disable-debug"
	echo "ac_add_options --disable-tests"
	# The hosted macOS toolchain does not provide the WASM sandbox libraries
	# required by Firefox's desktop configuration.
	echo "ac_add_options --without-wasm-sandboxed-libraries"
	echo "ac_add_options --enable-bootstrap"
	if [ "$USE_SCCACHE" = true ]; then
		echo "ac_add_options --with-ccache=sccache"
	fi
	if [ "$DISABLE_JEMALLOC" = true ]; then
		echo "ac_add_options --disable-jemalloc"
	fi
	if [ "$AUTO_CLOBBER" = true ]; then
		echo "mk_add_options AUTOCLOBBER=1"
	fi
} > "$MOZCONFIG_PATH"

if ! rustup target list | grep -q "^$TARGET (installed)"; then
	rustup target add "$TARGET"
fi

cd "$FIREFOX_DIR"
./mach build
