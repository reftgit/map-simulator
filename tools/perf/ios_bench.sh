#!/bin/sh
# Runs one performance experiment on the connected iPhone and collects results.
# Debug app must be installed (tools/build_ios_debug.sh <udid>).
#   IOS_UDID=<udid> tools/perf/ios_bench.sh tools/perf/experiments/baseline.json build/perf/ios [app args...]
# 1. Waits until the device thermal state is "Nominal" (3 s Instruments probes).
# 2. Copies the experiment to the app's Documents (user://) and launches it.
# 3. Every ~45 s takes a 3 s "Activity Monitor" probe (thermal state, app
#    memory footprint) and checks for Documents/bench_results.json, which the
#    app writes when the benchmark is done. iOS ignores quit(), so the script
#    then terminates the app.
# 4. Copies results and screenshots back and writes <name>.meta.json.
# Extra arguments are passed to the app (e.g. --rendering-method gl_compatibility).
# Env: COOL_TIMEOUT_S (default 2400), MAX_RUN_S (default 1200).
set -eu

EXP=$1
OUT=$2
shift 2
UDID=${IOS_UDID:?set IOS_UDID}
BUNDLE=com.mirongi.mapsimulator.dev
NAME=$(basename "$EXP" .json)
HERE=$(cd "$(dirname "$0")" && pwd)
PROBES="$OUT/$NAME.probes.jsonl"
mkdir -p "$OUT/shots" "$OUT/traces"
: > "$PROBES"

# Prints one JSON line: seconds since $started, thermal state, app footprint.
probe() {
	trace="$OUT/traces/probe.trace"
	rm -rf "$trace"
	xcrun xctrace record --template "Activity Monitor" --device "$UDID" --all-processes --time-limit 3s \
		--output "$trace" > /dev/null 2>&1 || true
	python3 -I "$HERE/parse_xctrace.py" summary "$trace" 2> /dev/null \
		| python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({"t": int(sys.argv[1]), "thermal": d["thermal_end"], "footprint_mib": d["footprint_peak_mib"]}))' "$1" \
		|| echo "{\"t\": $1, \"thermal\": \"unknown\", \"footprint_mib\": null}"
}
state_of() { python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["thermal"])' "$1"; }

waited=0
line=$(probe 0)
while [ "$(state_of "$line")" != Nominal ]; do
	[ "$waited" -ge "${COOL_TIMEOUT_S:-2400}" ] && { echo "cool-down timeout: $line" >&2; exit 3; }
	echo "waiting for Nominal: $line (${waited}s)"
	sleep 60
	waited=$((waited + 60))
	line=$(probe 0)
done
echo "$line" >> "$PROBES"
echo "$NAME: Nominal after ${waited}s cool-down"

xcrun devicectl device copy to --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
	--source "$EXP" --destination Documents/perf_bench.json > /dev/null
started=$(date +%s)
xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE" "$@" > /dev/null

app_pid() {
	xcrun devicectl device info processes --device "$UDID" --json-output - 2> /dev/null | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(next((p["processIdentifier"] for p in d["result"]["runningProcesses"] if "map_simulator" in p.get("executable", "")), ""))'
}
results_ready() {
	xcrun devicectl device info files --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
		--subdirectory Documents 2> /dev/null | grep -q "bench_results.json"
}

sleep 40
while :; do
	elapsed=$(( $(date +%s) - started ))
	probe "$elapsed" >> "$PROBES"
	if results_ready; then
		break
	fi
	[ -z "$(app_pid)" ] && { echo "app is not running" >&2; break; }
	[ "$elapsed" -gt "${MAX_RUN_S:-1200}" ] && { echo "run timeout" >&2; break; }
	sleep 40
done
wall=$(( $(date +%s) - started ))
pid=$(app_pid)
[ -n "$pid" ] && xcrun devicectl device process terminate --device "$UDID" --pid "$pid" > /dev/null 2>&1 || true
probe "$(( $(date +%s) - started ))" >> "$PROBES"

copy_from() {
	xcrun devicectl device copy from --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
		--source "$1" --destination "$2" > /dev/null 2>&1
}
copy_from Documents/bench_results.json "$OUT/$NAME.json" || echo "no results file" >&2
for view in spawn karakoy galata; do
	copy_from "Documents/bench/${NAME}_$view.jpg" "$OUT/shots/${NAME}_$view.jpg" || true
done
python3 -I - "$PROBES" "$OUT/$NAME.meta.json" "$NAME" "$wall" "$waited" "$*" << 'EOF'
import json, sys
order = ["Nominal", "Fair", "Serious", "Critical"]
probes = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
states = [p["thermal"] for p in probes if p["thermal"] in order]
prints = [p["footprint_mib"] for p in probes if p.get("footprint_mib")]
meta = {"experiment": sys.argv[3], "device": "ios", "wall_s": int(sys.argv[4]), "cooldown_s": int(sys.argv[5]),
        "app_args": sys.argv[6], "thermal_start": states[0] if states else None,
        "thermal_end": states[-1] if states else None,
        "thermal_max": max(states, key=order.index) if states else None,
        "footprint_peak_mib": max(prints) if prints else None, "probes": probes}
json.dump(meta, open(sys.argv[2], "w"), indent=1)
print(sys.argv[3], "done:", {k: v for k, v in meta.items() if k != "probes"})
EOF
