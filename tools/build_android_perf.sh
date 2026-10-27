#!/bin/sh
# Builds a release-template APK for on-device performance measurements only
# (an "Android Release Perf*" preset: perf_bench feature, no debug overlay).
# It is signed with the Godot editor's debug keystore so it can be installed
# locally; this is not a release signing setup and the APK is never uploaded.
# The keystore path and password are read from the local editor settings at
# build time and passed through Godot's GODOT_ANDROID_KEYSTORE_RELEASE_*
# environment variables, so nothing about the keystore enters the repository.
# The default editor settings path is the macOS one; on other systems (or for
# another Godot version) point GODOT_EDITOR_SETTINGS at the file, e.g.
# ~/.config/godot/editor_settings-4.7.tres on Linux or
# %APPDATA%/Godot/editor_settings-4.7.tres on Windows.
#   tools/build_android_perf.sh ["Android Release Perf"] [build/android/<name>.apk]
#   GODOT_EDITOR_SETTINGS=/path/to/editor_settings-4.7.tres tools/build_android_perf.sh
# Do not run while an Android measurement batch is running (the editor stops adb).
set -eu

cd "$(dirname "$0")/.."
PRESET=${1:-Android Release Perf}
OUT=${2:-build/android/map-simulator-release-perf.apk}
SETTINGS=${GODOT_EDITOR_SETTINGS:-"$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"}
[ -f "$SETTINGS" ] || { echo "editor settings not found: $SETTINGS (set GODOT_EDITOR_SETTINGS)" >&2; exit 1; }

value() { sed -n "s|^$1 = \"\(.*\)\"\$|\1|p" "$SETTINGS" | head -1; }

GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$(value export/android/debug_keystore)
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(value export/android/debug_keystore_pass)
GODOT_ANDROID_KEYSTORE_RELEASE_USER=$(value export/android/debug_keystore_user)
[ -n "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" ] || GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
[ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] || { echo "debug keystore not found in the editor settings" >&2; exit 1; }
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD GODOT_ANDROID_KEYSTORE_RELEASE_USER

mkdir -p "$(dirname "$OUT")"
godot --headless --path . --export-release "$PRESET" "$OUT"
ls -l "$OUT"
