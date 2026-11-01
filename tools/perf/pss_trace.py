#!/usr/bin/env python3
"""Memory trace of the Android app during a device scenario, and its summary.

    python3 -I tools/perf/pss_trace.py sample OUT_DIR [--timeout S]
    python3 -I tools/perf/pss_trace.py summary OUT_DIR RESULTS_JSON

sample: waits for the app to start (at most --timeout, default 1800 s), then
reads `dumpsys meminfo` as often as the device answers (about every 0.6 s on
the Galaxy Tab A7) until the app has quit or --timeout has passed; writes
OUT_DIR/pss_trace.jsonl (host unix time, TOTAL PSS, RSS, and swap PSS in kB)
and OUT_DIR/pss_meta.json (the device clock's offset), then OUT_DIR/logcat.txt
(the device log since the last clear, with unix times) and OUT_DIR/lmkd.txt
(the low-memory killer's lines). Run it beside android_bench.sh with
SAMPLE_PSS=0 (the bench's own 15 s sampling would only add load); the
"map_switch" scenario logs unix times that the summary aligns with it.

summary: the stable PSS of each map hold (median of the hold's second half)
and the peak PSS of each switch (from its start until 5 s after it finished),
against the larger of the two maps' stable PSS and against the largest map's,
with the lowest PSS in between (the old map freed) and the peak of PSS plus
swap PSS (zram), as a Markdown table.
"""
import json
import pathlib
import re
import statistics
import subprocess
import sys
import time

PACKAGE = "com.mirongi.mapsimulator"


def adb(*args, timeout=30):
    return subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout).stdout


def meminfo():
    text = adb("shell", "dumpsys", "meminfo", PACKAGE)
    found = {}
    for key, name in (("pss_kb", "TOTAL PSS"), ("rss_kb", "TOTAL RSS"), ("swap_pss_kb", "TOTAL SWAP PSS")):
        match = re.search(name + r":\s+(\d+)", text)
        if match:
            found[key] = int(match.group(1))
    return found


def clock_offset():
    """Device clock minus host clock (s), from the midpoints of three reads."""
    offsets = []
    for _ in range(3):
        before = time.time()
        device = float(adb("shell", "date", "+%s.%N").strip())
        offsets.append(device - (before + time.time()) / 2)
    return statistics.median(offsets)


def sample(out, timeout):
    out.mkdir(parents=True, exist_ok=True)
    (out / "pss_meta.json").write_text(json.dumps({"device_clock_offset_s": round(clock_offset(), 3)}) + "\n")
    started = time.time()
    while not adb("shell", "pidof", PACKAGE).strip():
        if time.time() - started > timeout:
            sys.exit("the app did not start")
        time.sleep(0.5)
    started = time.time()
    peak = 0
    with open(out / "pss_trace.jsonl", "w") as trace:
        while time.time() - started < timeout:
            t = time.time()
            found = meminfo()
            if not found:
                if not adb("shell", "pidof", PACKAGE).strip() and adb("get-state").strip() == "device":
                    break
                continue
            peak = max(peak, found.get("pss_kb", 0))
            trace.write(json.dumps({"t": round(t, 3), **found}) + "\n")
            trace.flush()
    log = adb("logcat", "-d", "-v", "epoch", timeout=60)
    (out / "logcat.txt").write_text(log)
    kills = [line for line in log.splitlines() if "lowmemorykiller" in line or "lmkd" in line]
    (out / "lmkd.txt").write_text("\n".join(kills) + ("\n" if kills else ""))
    print("pss trace done: peak %d kB, %d low-memory killer lines" % (peak, len(kills)))


def unix_of(detail):
    match = re.search(r"unix (\d+\.\d+)", detail)
    return float(match.group(1)) if match else None


def summary(out, results_path):
    samples = [json.loads(line) for line in open(out / "pss_trace.jsonl") if line.strip()]
    offset = json.load(open(out / "pss_meta.json"))["device_clock_offset_s"]
    steps = json.load(open(results_path))["scenario"]
    marks = []  # (unix, kind, map, step)
    for step in steps:
        unix = unix_of(step["detail"])
        if unix is None:
            continue
        unix -= offset
        if step["step"].startswith("hold_"):
            marks.append((unix, "hold", step["step"][5:], step))
        elif step["step"].endswith("_start"):
            source, target = re.match(r"([^,\s]+) -> ([^,\s]+)", step["detail"]).groups()
            marks.append((unix, "start", (source, target), step))
        elif step["step"].startswith("switch_"):
            marks.append((unix, "done", re.match(r"[^,\s]+ -> ([^,\s]+)", step["detail"]).group(1), step))
    end = samples[-1]["t"] if samples else 0

    def in_window(a, b, swap=False):
        return [s["pss_kb"] + (s.get("swap_pss_kb", 0) if swap else 0) for s in samples if a <= s["t"] <= b and "pss_kb" in s]

    holds = []  # (map, start, end)
    for i, (unix, kind, value, _) in enumerate(marks):
        if kind in ("hold", "done"):
            following = next((m[0] for m in marks[i + 1:] if m[1] == "start"), end)
            holds.append((value, unix, following))
    stable = {}
    for name, a, b in holds:
        values = in_window(a + (b - a) / 2, b)
        if values:
            stable.setdefault(name, []).append(statistics.median(values))
    largest = max((max(v) for v in stable.values()), default=0)
    print("| Map hold | Stable PSS (MiB) |")
    print("|---|---|")
    for name, a, b in holds:
        values = in_window(a + (b - a) / 2, b)
        print("| %s (%.0f–%.0f s) | %s |" % (name, a - holds[0][1], b - holds[0][1], "%.0f" % (statistics.median(values) / 1024) if values else "-"))
    print()
    print("| Switch | Took (s) | Peak PSS (MiB) | Larger map stable + 50 | Result | Largest map stable + 50 | Result | Lowest PSS (old map freed) | Peak PSS + swap PSS |")
    print("|---|---|---|---|---|---|---|---|---|")
    starts = [m for m in marks if m[1] == "start"]
    dones = [m for m in marks if m[1] == "done"]
    for (a, _, (source, target), step), (b, _, _, done) in zip(starts, dones):
        values = in_window(a, b + 5)
        peak = max(values) / 1024 if values else float("nan")
        larger = max(max(stable.get(source, [0])), max(stable.get(target, [0]))) / 1024 + 50
        took = re.search(r"in (\d+) ms", done["detail"])
        lowest = min(values) / 1024 if values else float("nan")
        with_swap = max(in_window(a, b + 5, True)) / 1024 if values else float("nan")
        print("| %s -> %s | %s | %.0f | %.0f | %s | %.0f | %s | %.0f | %.0f |" % (source, target, "%.1f" % (int(took.group(1)) / 1000) if took else "-",
              peak, larger, "PASS" if peak <= larger else "FAIL", largest / 1024 + 50, "PASS" if peak <= largest / 1024 + 50 else "FAIL", lowest, with_swap))
    print()
    print("samples: %d, every %.2f s on average; overall peak %.0f MiB" % (len(samples), (end - samples[0]["t"]) / max(len(samples) - 1, 1) if samples else 0,
          max((s.get("pss_kb", 0) for s in samples), default=0) / 1024))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "sample":
        timeout = float(sys.argv[sys.argv.index("--timeout") + 1]) if "--timeout" in sys.argv else 1800.0
        sample(pathlib.Path(sys.argv[2]), timeout)
    elif len(sys.argv) == 4 and sys.argv[1] == "summary":
        summary(pathlib.Path(sys.argv[2]), sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
