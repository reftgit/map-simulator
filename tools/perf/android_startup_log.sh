#!/bin/sh
# Launches the installed Android app without an experiment (any leftover
# perf_bench.json is removed first) and keeps the engine's STARTUP, QUALITY,
# and MAP log lines (debug and Release Perf builds print them), e.g. to show
# which map a plain launch starts on. Device unlocked.
#   tools/perf/android_startup_log.sh <out-dir> [seconds]
# Output in <out-dir>: startup.log (the engine log), startup_log.txt (the lines).
set -eu
OUT=$1
WAIT=${2:-40}
PKG=com.mirongi.mapsimulator
mkdir -p "$OUT"
adb shell am force-stop "$PKG"
adb shell run-as "$PKG" rm -f files/perf_bench.json > /dev/null 2>&1 || true
adb shell rm -f "/sdcard/Android/data/$PKG/files/Documents/perf_bench.json"
adb logcat -c
adb shell input keyevent KEYCODE_WAKEUP
adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher" > /dev/null
sleep "$WAIT"
adb logcat -d -s godot:V > "$OUT/startup.log"
adb shell am force-stop "$PKG"
grep -E "(STARTUP|QUALITY|MAP|WARNING).*" "$OUT/startup.log" | sed -E 's/^.*godot *: //' > "$OUT/startup_log.txt" || true
cat "$OUT/startup_log.txt"
