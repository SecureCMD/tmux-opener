#!/bin/bash
# Builds Tmux Opener and packages "build/Tmux Opener.app".
#
# Usage: scripts/build.sh [--install] [--universal] [--zip] [--notarize]
#   --install    copy the app to /Applications
#   --universal  build for both Apple Silicon and Intel (requires Xcode)
#   --zip        also create build/TmuxOpener-<version>.zip
#   --notarize   notarize and staple (needs SIGN_IDENTITY, see scripts/notarize.sh)
#
# Environment:
#   VERSION=1.2.3          overrides the version in Info.plist
#   SIGN_IDENTITY="Developer ID Application: …"
#                          sign with that identity and the hardened runtime
#                          (ad-hoc signature otherwise)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Tmux Opener"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL=0; UNIVERSAL=0; ZIP=0; NOTARIZE=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --universal) UNIVERSAL=1 ;;
        --zip) ZIP=1 ;;
        --notarize) NOTARIZE=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
if [[ $NOTARIZE == 1 && -z "${SIGN_IDENTITY:-}" ]]; then
    echo "error: --notarize needs SIGN_IDENTITY (a Developer ID Application identity)" >&2
    exit 1
fi

SWIFT_FLAGS=(-c release)
[[ $UNIVERSAL == 1 ]] && SWIFT_FLAGS+=(--arch arm64 --arch x86_64)

mkdir -p "$BUILD_DIR"
echo "▸ Compiling…"
# Some Command Line Tools releases ship an SDK whose SwiftUI needs a macro
# plugin they don't include. If the default build fails, retry with older SDKs.
if ! swift build "${SWIFT_FLAGS[@]}" 2>"$BUILD_DIR/build.log"; then
    built=0
    for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
        echo "  retrying with $(basename "$sdk")…"
        if SDKROOT="$sdk" swift build "${SWIFT_FLAGS[@]}" 2>>"$BUILD_DIR/build.log"; then
            export SDKROOT="$sdk"; built=1; break
        fi
    done
    if [[ $built == 0 ]]; then cat "$BUILD_DIR/build.log"; exit 1; fi
fi
BIN="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)/TmuxOpener"

echo "▸ Packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TmuxOpener"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION#v}" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-${VERSION#v}}" "$APP/Contents/Info.plist"
fi

echo "▸ Generating icon"
rm -rf "$BUILD_DIR/AppIcon.iconset"
swift scripts/make_icon.swift "$BUILD_DIR/AppIcon.iconset" >/dev/null
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

ENTITLEMENTS="Resources/TmuxOpener.entitlements"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "▸ Signing with $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
else
    echo "▸ Signing (ad-hoc)"
    codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP"
fi

if [[ $NOTARIZE == 1 ]]; then
    scripts/notarize.sh "$APP"
fi

if [[ $ZIP == 1 ]]; then
    V=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
    ZIP_PATH="$BUILD_DIR/TmuxOpener-$V.zip"
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP" "$ZIP_PATH"
    echo "▸ Zipped: $ZIP_PATH"
fi

if [[ $INSTALL == 1 ]]; then
    echo "▸ Installing to /Applications"
    pkill -x TmuxOpener 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    ditto "$APP" "/Applications/$APP_NAME.app"
    echo "✓ Installed: /Applications/$APP_NAME.app"
else
    echo "✓ Ready: $APP  (drag it to /Applications or run: make install)"
fi
