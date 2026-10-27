#!/bin/sh
# Turns the connected Android device between its two landscape rotations when
# the device scenario asks for it, takes a screenshot in each, and puts the
# rotation settings back. Start it before tools/perf/android_bench.sh runs a
# scenario experiment with "rotate_hold_s" (or "orientation"):
#   tools/perf/android_rotate_on_cue.sh <out_dir> &
#   tools/perf/android_bench.sh tools/perf/experiments/scenario_vehicle_sleep_rotate.json <out_dir>
# On "SCENARIO step=rotate_hold" it notes accelerometer_rotation and
# user_rotation, switches auto-rotation off, and sets user_rotation to the
# other landscape (1 <-> 3); on "SCENARIO step=rotate_release" it turns back.
# The original settings are restored when "SCENARIO step=done" arrives or the
# script exits. Rotation changes are logged with the display's
# SurfaceOrientation (dumpsys input) as evidence.
set -u
# adb reads stdin; inside the logcat loop below it would eat log lines, so
# every adb call there reads /dev/null.

OUT=$1
mkdir -p "$OUT"
LOG="$OUT/rotation.log"

orig_auto=$(adb shell settings get system accelerometer_rotation | tr -d '\r')
orig_user=$(adb shell settings get system user_rotation | tr -d '\r')
rotation() { adb shell dumpsys input < /dev/null | grep -m1 SurfaceOrientation | tr -d ' \r' | cut -d: -f2; }
note() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"; }
restore() {
	adb shell settings put system user_rotation "$orig_user"
	adb shell settings put system accelerometer_rotation "$orig_auto"
	sleep 2
	note "restored accelerometer_rotation=$orig_auto user_rotation=$orig_user, display rotation $(rotation)"
}
trap restore EXIT

start=$(rotation)
note "before: accelerometer_rotation=$orig_auto user_rotation=$orig_user, display rotation $start"
# Only lines from now on: the log buffer may still hold an earlier run's cues.
since=$(adb shell date "'+%m-%d %H:%M:%S.000'" | tr -d '\r')
adb logcat -T "$since" -s godot:I | while read -r line; do
	case "$line" in
		*"SCENARIO step=rotate_hold"*)
			target=1
			[ "$(rotation)" = 1 ] && target=3
			adb shell settings put system accelerometer_rotation 0 < /dev/null
			adb shell settings put system user_rotation "$target" < /dev/null
			sleep 3
			note "turned: user_rotation=$target, display rotation $(rotation)"
			adb exec-out screencap -p < /dev/null > "$OUT/rotated.png"
			;;
		*"SCENARIO step=rotate_release"*)
			adb shell settings put system user_rotation "$start" < /dev/null
			sleep 3
			note "turned back: user_rotation=$start, display rotation $(rotation)"
			adb exec-out screencap -p < /dev/null > "$OUT/turned_back.png"
			;;
		*"SCENARIO step=done"*)
			pkill -f "adb logcat -T"
			break
			;;
	esac
done
