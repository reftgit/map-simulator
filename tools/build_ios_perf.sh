#!/bin/sh
# Builds an iOS release-template app for on-device performance measurements
# only (an "iOS Release Perf*" preset: perf_bench feature, no debug overlay)
# with the Xcode Release configuration, and optionally installs it.
#   tools/build_ios_perf.sh ["iOS Release Perf"] [device-udid]
# Same signing rule as tools/build_ios_debug.sh: automatic signing WITHOUT
# -allowProvisioningUpdates, so xcodebuild never contacts the Apple Developer
# portal; it signs with a matching development profile already on this Mac.
# No TestFlight, App Store, or archive upload happens here.
set -eu

cd "$(dirname "$0")/.."
PRESET=${1:-iOS Release Perf}
UDID=${2:-}
SLUG=$(echo "$PRESET" | tr 'A-Z ' 'a-z_' | tr -cd 'a-z0-9_')
DIR=build/$SLUG
NAME=map_simulator_perf
APP=$DIR/DerivedData/Build/Products/Release-iphoneos/$NAME.app

mkdir -p "$DIR"
godot --headless --path . --export-release "$PRESET" "$DIR/$NAME.ipa"
xcodebuild -project "$DIR/$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
	-destination generic/platform=iOS -derivedDataPath "$DIR/DerivedData" build

codesign -dv "$APP" 2>&1 | grep -E "^(Identifier|TeamIdentifier)="

if [ -n "$UDID" ]; then
	xcrun devicectl device install app --device "$UDID" "$APP"
fi
