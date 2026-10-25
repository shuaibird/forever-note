#!/bin/sh
# Builds Forever Note.app. Pass "install" to copy it to /Applications and launch it.
# /Applications, not ~/Applications: on macOS 27, menu-bar managers such as Hidden
# Bar can only keep icons visible for apps installed there.
set -e
cd "$(dirname "$0")"
APP="build/Forever Note.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" *.swift -o "$APP/Contents/MacOS/ForeverNote"
mkdir -p "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$1" = "install" ]; then
    pkill -x ForeverNote && while pgrep -x ForeverNote >/dev/null; do sleep 0.1; done || true
    rm -rf ~/Applications/"Forever Note.app"
    rm -rf /Applications/"Forever Note.app"
    cp -R "$APP" /Applications/
    open /Applications/"Forever Note.app"
    echo "Installed to /Applications and launched"
fi
