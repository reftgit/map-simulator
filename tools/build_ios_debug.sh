#!/bin/sh
# Builds the iOS debug app and optionally installs it on a connected device.
#   tools/build_ios_debug.sh                 # build only
#   tools/build_ios_debug.sh <device-udid>   # build and install
#
# Signing rule: xcodebuild runs WITHOUT -allowProvisioningUpdates, so it never
# contacts the Apple Developer portal and cannot register App IDs or create
# profiles. It signs with a matching profile already on this Mac (currently
# the team's Xcode-managed wildcard "iOS Team Provisioning Profile: *").
# The "iOS Debug" preset has export_project_only=true for the same reason:
# Godot only generates the Xcode project; this script builds it.
# No TestFlight, App Store, or archive upload happens here.
set -eu

cd "$(dirname "$0")/.."
PROJECT=build/ios/map_simulator_dev.xcodeproj
APP=build/ios/DerivedData/Build/Products/Debug-iphoneos/map_simulator_dev.app

mkdir -p build/ios
godot --headless --path . --export-debug "iOS Debug" build/ios/map_simulator_dev.ipa
xcodebuild -project "$PROJECT" -scheme map_simulator_dev -configuration Debug \
	-destination generic/platform=iOS -derivedDataPath build/ios/DerivedData build

codesign -dv "$APP" 2>&1 | grep -E "^(Identifier|TeamIdentifier)="

if [ $# -ge 1 ]; then
	xcrun devicectl device install app --device "$1" "$APP"
fi
