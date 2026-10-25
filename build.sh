#!/bin/sh
# Builds Forever Note.app. Pass "install" to copy it to /Applications and launch it.
# /Applications, not ~/Applications: on macOS 27, menu-bar managers such as Hidden
# Bar can only keep icons visible for apps installed there.
#
# Environment overrides:
#   VERSION            CFBundleShortVersionString  (default: latest v* git tag minus "v", else 0.0.0-dev)
#   BUILD_NUMBER       CFBundleVersion             (default: git commit count, else 1)
#   UNIVERSAL=1        build arm64 + x86_64 instead of the host architecture only
#   CODESIGN_IDENTITY  signing identity            (default: "-", ad-hoc)
set -e
cd "$(dirname "$0")"
APP="build/Forever Note.app"
VERSION="${VERSION:-$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)}"
VERSION="${VERSION#v}"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCHS="arm64 x86_64"; else ARCHS="$(uname -m)"; fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj
BINS=""
for arch in $ARCHS; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" *.swift -o "build/obj/ForeverNote-$arch"
    BINS="$BINS build/obj/ForeverNote-$arch"
done
lipo -create $BINS -output "$APP/Contents/MacOS/ForeverNote"
cp AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:--}" "$APP"
echo "Built $APP $VERSION ($BUILD_NUMBER), $(lipo -archs "$APP/Contents/MacOS/ForeverNote")"

if [ "$1" = "install" ]; then
    pkill -x ForeverNote && while pgrep -x ForeverNote >/dev/null; do sleep 0.1; done || true
    rm -rf ~/Applications/"Forever Note.app"
    rm -rf /Applications/"Forever Note.app"
    cp -R "$APP" /Applications/
    open /Applications/"Forever Note.app"
    echo "Installed to /Applications and launched"
fi
