#!/bin/sh
# Runs one performance experiment on the connected Android device and collects
# its results. Debug APK must be installed (docs/ARCHITECTURE.md, "Device builds").
#   tools/perf/android_bench.sh tools/perf/experiments/baseline.json build/perf/android
# Env: ANDROID_SERIAL (device), COOL_MAX_C (wait until the battery is at or
# below this temperature before starting; default: no wait), COOL_TIMEOUT_S,
# SAMPLE_PSS=0 (skip `dumpsys meminfo` sampling, which can cause frame hitches).
# Output in <out>: <name>.json (app results), <name>.log (engine log),
# <name>.meta.json (temperatures, thermal status, peak PSS), shots/*.jpg.
set -eu

EXP=$1
OUT=$2
PKG=com.mirongi.mapsimulator
NAME=$(basename "$EXP" .json)
mkdir -p "$OUT/shots"

battery_c() { adb shell dumpsys battery | awk -F': ' '/temperature/ { printf "%.1f", $2 / 10; exit }'; }
thermal_status() { adb shell dumpsys thermalservice | awk -F': ' '/Thermal Status/ { print $2; exit }'; }

if [ -n "${COOL_MAX_C:-}" ]; then
	waited=0
	while [ "$(echo "$(battery_c) > $COOL_MAX_C" | bc)" = 1 ]; do
		[ "$waited" -ge "${COOL_TIMEOUT_S:-900}" ] && { echo "cool-down timeout at $(battery_c) C" >&2; break; }
		sleep 30
		waited=$((waited + 30))
	done
fi

adb shell am force-stop "$PKG"
adb shell run-as "$PKG" rm -rf files/bench files/bench_results.json
adb push "$EXP" /data/local/tmp/perf_bench.json > /dev/null
adb shell run-as "$PKG" cp /data/local/tmp/perf_bench.json files/perf_bench.json
adb logcat -c
start_c=$(battery_c)
start_status=$(thermal_status)
started=$(date +%s)
adb shell input keyevent KEYCODE_WAKEUP
adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher" > /dev/null

# Wait for the app to finish (it quits itself), sampling PSS every 15 s.
peak_pss=0
while :; do
	sleep 15
	pid=$(adb shell pidof "$PKG" || true)
	[ -z "$pid" ] && break
	if [ "${SAMPLE_PSS:-1}" != 0 ]; then
		pss=$(adb shell dumpsys meminfo "$PKG" | awk '/TOTAL PSS:/ { print $3; exit }')
		[ -n "$pss" ] && [ "$pss" -gt "$peak_pss" ] && peak_pss=$pss
	fi
	[ $(( $(date +%s) - started )) -gt 2400 ] && { echo "timeout; stopping app" >&2; adb shell am force-stop "$PKG"; break; }
done

adb logcat -d -s godot:V > "$OUT/$NAME.log"
adb exec-out run-as "$PKG" cat files/bench_results.json > "$OUT/$NAME.json" || true
for shot in $(adb shell run-as "$PKG" ls files/bench 2> /dev/null); do
	adb exec-out run-as "$PKG" cat "files/bench/$shot" > "$OUT/shots/$shot"
done
cat > "$OUT/$NAME.meta.json" << EOF
{"experiment": "$NAME", "device": "android", "battery_c_start": $start_c, "battery_c_end": $(battery_c),
 "thermal_status_start": "$start_status", "thermal_status_end": "$(thermal_status)",
 "pss_peak_kb": $peak_pss, "wall_s": $(( $(date +%s) - started )), "started": "$(date -r "$started" '+%Y-%m-%d %H:%M:%S')"}
EOF
echo "$NAME done: $(grep -c 'BENCH {' "$OUT/$NAME.log") results, peak PSS ${peak_pss} kB, battery ${start_c} -> $(battery_c) C"
