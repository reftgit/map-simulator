#!/bin/sh
# Runs experiments one after another on one device.
#   tools/perf/run_batch.sh android build/perf/android tools/perf/experiments/baseline.json ...
#   IOS_UDID=<udid> tools/perf/run_batch.sh ios build/perf/ios tools/perf/experiments/baseline.json ...
# Android: waits before each run until the battery is back to the batch's
# starting temperature (+0.5 C) and keeps the screen on while plugged in
# (restored afterwards). iOS: each run waits for the "Nominal" thermal state.
set -u
DEVICE=$1
OUT=$2
shift 2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
if [ "$DEVICE" = android ]; then
	start_c=$(adb shell dumpsys battery | awk -F': ' '/temperature/ { printf "%.1f", $2 / 10; exit }')
	export COOL_MAX_C=$(echo "$start_c + 0.5" | bc)
	echo "batch start: battery $start_c C, cool-down target <= $COOL_MAX_C C"
	adb shell svc power stayon usb
	trap 'adb shell svc power stayon false' EXIT
fi
for exp in "$@"; do
	echo "=== $(date '+%H:%M:%S') $exp"
	if [ "$DEVICE" = android ]; then
		"$HERE/android_bench.sh" "$exp" "$OUT" || echo "FAILED: $exp"
	else
		"$HERE/ios_bench.sh" "$exp" "$OUT" ${APP_ARGS:-} || echo "FAILED: $exp"
	fi
done
echo "=== $(date '+%H:%M:%S') batch done"
