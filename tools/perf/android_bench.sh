#!/bin/sh
# Runs one performance experiment on the connected Android device and collects
# its results. Debug APK must be installed (docs/ARCHITECTURE.md, "Device builds").
#   tools/perf/android_bench.sh tools/perf/experiments/baseline.json build/perf/android
# Env: ANDROID_SERIAL (device), COOL_MAX_C (wait until the battery is at or
# below this temperature before starting; default: no wait), COOL_TIMEOUT_S,
# SAMPLE_PSS=0 (skip `dumpsys meminfo` sampling, which can cause frame hitches).
# Output in <out>: <name>.json (app results), <name>.log (engine log),
# <name>.meta.json (temperatures, thermal status, peak PSS, cool-down wait), shots/*.jpg.
# A debug APK is reached with `run-as` (user://). A release perf APK is not
# debuggable, so the experiment and the results go through the app-specific
# external folder instead (PerfConfig.external_dir()); the app creates that
# folder on its first launch, which this script triggers if it is missing.
set -eu

EXP=$1
OUT=$2
PKG=com.mirongi.mapsimulator
NAME=$(basename "$EXP" .json)
mkdir -p "$OUT/shots"

battery_c() { adb shell dumpsys battery | awk -F': ' '/temperature/ { printf "%.1f", $2 / 10; exit }'; }
thermal_status() { adb shell dumpsys thermalservice | awk -F': ' '/Thermal Status/ { print $2; exit }'; }

waited=0
if [ -n "${COOL_MAX_C:-}" ]; then
	while [ "$(echo "$(battery_c) > $COOL_MAX_C" | bc)" = 1 ]; do
		[ "$waited" -ge "${COOL_TIMEOUT_S:-900}" ] && { echo "cool-down timeout at $(battery_c) C" >&2; break; }
		sleep 30
		waited=$((waited + 30))
	done
fi

EXT=/sdcard/Android/data/$PKG/files/Documents
adb shell am force-stop "$PKG"
if adb shell run-as "$PKG" true > /dev/null 2>&1; then
	debuggable=1
	adb shell run-as "$PKG" rm -rf files/bench files/bench_results.json
	adb push "$EXP" /data/local/tmp/perf_bench.json > /dev/null
	adb shell run-as "$PKG" cp /data/local/tmp/perf_bench.json files/perf_bench.json
else
	debuggable=0
	if ! adb shell ls "$EXT" > /dev/null 2>&1; then
		adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher" > /dev/null
		sleep 20
		adb shell am force-stop "$PKG"
	fi
	adb shell rm -rf "$EXT/bench" "$EXT/bench_results.json"
	adb push "$EXP" "$EXT/perf_bench.json" > /dev/null
fi
adb logcat -c
start_c=$(battery_c)
start_status=$(thermal_status)
started=$(date +%s)
adb shell input keyevent KEYCODE_WAKEUP
adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher" > /dev/null

# Wait for the app to finish (it quits itself), sampling PSS every 15 s.
# An adb dropout (the server has restarted mid-run) must not count as the app
# having quit: an empty pid only counts while the device answers.
peak_pss=0
while :; do
	sleep 15
	pid=$(adb shell pidof "$PKG" 2> /dev/null || true)
	if [ -z "$pid" ] && ! adb get-state > /dev/null 2>&1; then
		echo "adb not answering; waiting" >&2
		continue
	fi
	[ -z "$pid" ] && break
	if [ "${SAMPLE_PSS:-1}" != 0 ]; then
		pss=$(adb shell dumpsys meminfo "$PKG" | awk '/TOTAL PSS:/ { print $3; exit }')
		[ -n "$pss" ] && [ "$pss" -gt "$peak_pss" ] && peak_pss=$pss
	fi
	[ $(( $(date +%s) - started )) -gt 2400 ] && { echo "timeout; stopping app" >&2; adb shell am force-stop "$PKG"; break; }
done

adb logcat -d -s godot:V > "$OUT/$NAME.log"
if [ "$debuggable" = 1 ]; then
	adb exec-out run-as "$PKG" cat files/bench_results.json > "$OUT/$NAME.json" || true
	for shot in $(adb shell run-as "$PKG" ls files/bench 2> /dev/null); do
		adb exec-out run-as "$PKG" cat "files/bench/$shot" > "$OUT/shots/$shot"
	done
else
	for attempt in 1 2 3; do
		adb pull "$EXT/bench_results.json" "$OUT/$NAME.json" > /dev/null 2>&1 && break
		sleep 5
	done
	for shot in $(adb shell ls "$EXT/bench" 2> /dev/null); do
		adb pull "$EXT/bench/$shot" "$OUT/shots/$shot" > /dev/null 2>&1 || true
	done
fi
cat > "$OUT/$NAME.meta.json" << EOF
{"experiment": "$NAME", "device": "android", "battery_c_start": $start_c, "battery_c_end": $(battery_c),
 "thermal_status_start": "$start_status", "thermal_status_end": "$(thermal_status)",
 "pss_peak_kb": $peak_pss, "wall_s": $(( $(date +%s) - started )), "started": "$(date -r "$started" '+%Y-%m-%d %H:%M:%S')",
 "cool_wait_s": $waited, "cool_target_c": "${COOL_MAX_C:-}"}
EOF
echo "$NAME done: $(grep -c 'BENCH {' "$OUT/$NAME.log") results, peak PSS ${peak_pss} kB, battery ${start_c} -> $(battery_c) C"
