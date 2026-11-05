#!/bin/sh
# Builds the local release package of one platform from the "Android Release"
# or "iOS Release" preset: the game and only the maps of the release registry
# (game/world/maps_release.tres), streamed maps as their cells without their
# GLB, no perf_bench (no debug overlay, MAP button, experiments, or
# benchmarks). First checks the preset and that every release map's cells are
# written and current (tools/check_release.gd); when they are not, nothing is
# exported and the check names the command that writes them. Afterwards lists
# what the package holds and compares it with what it should hold
# (tools/release_contents.py).
# For local testing only, as the Release Perf builds (D19): Android is signed
# with the editor's debug keystore (tools/build_android_perf.sh), iOS with the
# development profile already on this Mac and without
# -allowProvisioningUpdates (D9). Nothing is uploaded; no release keystore,
# final bundle ID, or store record is involved (D8, D10).
#   tools/build_release.sh android [build/android/<name>.apk]
#   tools/build_release.sh ios [device-udid]   # builds, and installs when given a device
# Do not run while an Android measurement batch is running (the editor stops adb).
set -eu

cd "$(dirname "$0")/.."
case "${1:-}" in
android) PRESET="Android Release" ;;
ios) PRESET="iOS Release" ;;
*) echo "usage: tools/build_release.sh android [out.apk] | ios [device-udid]" >&2; exit 2 ;;
esac
PLATFORM=$1
mkdir -p build/release
LIST=$(pwd)/build/release/$PLATFORM.expected.txt

if ! godot --headless --path . --script res://tools/check_release.gd -- "$PRESET" --list="$LIST"; then
	echo "$PRESET: not exported (see RELEASE lines above)" >&2
	exit 1
fi

if [ "$PLATFORM" = android ]; then
	OUT=${2:-build/android/map-simulator-release.apk}
	tools/build_android_perf.sh "$PRESET" "$OUT"
	python3 -I tools/release_contents.py "$OUT" --expect "$LIST"
	exit
fi

UDID=${2:-}
DIR=build/ios_release
NAME=map_simulator
APP=$DIR/DerivedData/Build/Products/Release-iphoneos/$NAME.app
mkdir -p "$DIR"
godot --headless --path . --export-release "$PRESET" "$DIR/$NAME.ipa"
python3 -I tools/release_contents.py "$DIR/$NAME.pck" --expect "$LIST"
xcodebuild -project "$DIR/$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
	-destination generic/platform=iOS -derivedDataPath "$DIR/DerivedData" build
codesign -dv "$APP" 2>&1 | grep -E "^(Identifier|TeamIdentifier)="
du -sh "$APP"
if [ -n "$UDID" ]; then
	xcrun devicectl device install app --device "$UDID" "$APP"
fi
