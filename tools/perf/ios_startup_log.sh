#!/bin/sh
# Launches the installed iOS app without arguments or an experiment under an
# Instruments "Logging" recording and keeps the engine's STARTUP, QUALITY,
# MAP, STREAMING, and LOADING log lines (os_log; debug and Release Perf builds
# print all of them, a normal release build QUALITY, STREAMING, and LOADING),
# e.g. to show which map a plain launch starts on, whether it streamed, and
# its loading screen's frames. iPhone unlocked.
#   tools/perf/ios_startup_log.sh <udid> <out-dir> [bundle-id] [seconds]
# Output in <out-dir>: startup_log.txt (the lines), startup_oslog.xml (the
# exported os_log table), startup.trace (the recording).
set -eu
UDID=$1
OUT=$2
BUNDLE=${3:-com.mirongi.mapsimulator.dev}
SECONDS_LIMIT=${4:-25}
mkdir -p "$OUT"
rm -rf "$OUT/startup.trace"
xcrun xctrace record --template Logging --device "$UDID" --time-limit "${SECONDS_LIMIT}s" \
	--output "$OUT/startup.trace" --launch -- "$BUNDLE" > /dev/null
xcrun xctrace export --input "$OUT/startup.trace" \
	--xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-log"]' > "$OUT/startup_oslog.xml"
python3 -I - "$OUT/startup_oslog.xml" > "$OUT/startup_log.txt" << 'EOF'
import html, re, sys
seen = []
for match in re.finditer(r"(?:STARTUP|QUALITY|MAP|STREAMING|LOADING(?:_STEPS|_LOAD|_FRAMES)?) [^<]*", open(sys.argv[1], errors="replace").read()):
    for line in html.unescape(match.group(0)).split("\n"):
        line = line.removesuffix('">').strip()
        if re.match(r"(STARTUP|QUALITY|MAP|STREAMING|LOADING(_STEPS|_LOAD|_FRAMES)?) ", line) and line not in seen:
            seen.append(line)
print("\n".join(seen))
EOF
cat "$OUT/startup_log.txt"
