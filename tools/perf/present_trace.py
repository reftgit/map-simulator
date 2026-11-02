#!/usr/bin/env python3
"""Presented frame times of the Android app (SurfaceFlinger), and their summary.

    python3 -I tools/perf/present_trace.py sample OUT_DIR NAME [--interval S] [--timeout S]
    python3 -I tools/perf/present_trace.py summary RUN_DIR...

sample: run it beside android_bench.sh (started just before it, with the same
OUT_DIR and the experiment's NAME). It waits for the app to start (at most
--timeout, default 1800 s, which covers the bench's cool-down wait), finds
the game's surface layer ("SurfaceView - <package>/...(BLAST)"), clears and
enables SurfaceFlinger's TimeStats, and reads
`dumpsys SurfaceFlinger --latency <layer>` every --interval seconds (default
2; the layer keeps its last 127 frames, 4.2 s at 30 FPS) until the app has
quit. It writes OUT_DIR/NAME.present.tsv (per presented frame: the desired
present time, the actual present time, and the frame-ready time, CLOCK_MONOTONIC
ns), OUT_DIR/NAME.present.json (layer, refresh period, polls), OUT_DIR/NAME.mono.log
(the engine log with CLOCK_MONOTONIC seconds, the same clock), and
OUT_DIR/NAME.timestats.txt (TimeStats of the whole launch, including its
present-to-present histogram per layer); TimeStats is disabled afterwards.
Nothing in the app or its settings changes.

summary: for each traced result (bench "trace": true) with a present trace, the
measurement window of each viewpoint (ending at its BENCH line, as long as the
sum of its traced frame times) and, inside it, the game's own frame times (the
CPU side, which counts long frames) beside the presented frames: how many
display refreshes (vsyncs) lay between consecutive presents (at a 30 FPS cap on a
60 Hz display every interval should be 2), and how many long game frames end
within 150 ms after a poll (a check that the polling does not cause them);
since a poll can delay SurfaceFlinger's next composition, the presented long
intervals are also counted for the intervals that start 250 ms or more after
a poll; then the totals per experiment for viewpoints over and within 1 % long
frames. Markdown tables. Reads gzipped copies (.json.gz, .present.tsv.gz) too.
"""
import bisect
import gzip
import json
import pathlib
import re
import subprocess
import sys
import time

PACKAGE = "com.mirongi.mapsimulator"
PENDING = 9223372036854775807  # INT64_MAX: not presented yet


def adb(*args, timeout=30):
    return subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout).stdout


def app_pid():
    try:
        return adb("shell", "pidof", PACKAGE).strip()
    except subprocess.TimeoutExpired:
        return ""


def find_layer(timeout=60.0):
    pattern = re.compile(r"^SurfaceView - %s/.*\(BLAST\)#\d+$" % re.escape(PACKAGE))
    end = time.time() + timeout
    while time.time() < end:
        for line in adb("shell", "dumpsys", "SurfaceFlinger", "--list").splitlines():
            if pattern.match(line.strip()):
                return line.strip()
        time.sleep(0.5)
    return ""


def latency(layer):
    """The refresh period (ns) and the rows (desired, present, ready) SurfaceFlinger keeps."""
    lines = adb("shell", "dumpsys", "SurfaceFlinger", "--latency", '"%s"' % layer).split("\n")
    refresh = int(lines[0]) if lines and lines[0].strip().isdigit() else 0
    rows = []
    for line in lines[1:]:
        parts = line.split()
        if len(parts) == 3 and parts[0] != "0":
            rows.append(tuple(int(p) for p in parts))
    return refresh, rows


def sample(out, name, interval, timeout):
    out.mkdir(parents=True, exist_ok=True)
    end = time.time() + timeout
    while not app_pid():
        if time.time() > end:
            sys.exit("app did not start")
        time.sleep(0.5)
    log = open(out / (name + ".mono.log"), "w")
    logcat = subprocess.Popen(["adb", "logcat", "-v", "monotonic", "-s", "godot:V"], stdout=log, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    adb("shell", "dumpsys", "SurfaceFlinger", "--timestats", "-enable", "-clear")
    layer = find_layer()
    frames = {}
    polls = []
    refresh = 0
    misses = 0
    while layer and time.time() < end:
        # A single empty `pidof` can be an adb hiccup (it ended one trace of
        # 2026-11-02 after 20 s): the app counts as gone after three in a row.
        misses = 0 if app_pid() else misses + 1
        if misses >= 3:
            break
        if misses:
            time.sleep(1)
            continue
        started = time.time()
        try:
            period, rows = latency(layer)
        except subprocess.TimeoutExpired:
            continue
        refresh = period or refresh
        for desired, present, ready in rows:
            if present != PENDING or desired not in frames:
                frames[desired] = (desired, present, ready)
        presented = [r[1] for r in rows if r[1] != PENDING]
        polls.append({"host_s": round(started, 3), "newest_present_ns": max(presented) if presented else 0, "rows": len(rows)})
        time.sleep(max(0.0, interval - (time.time() - started)))
    (out / (name + ".timestats.txt")).write_text(adb("shell", "dumpsys", "SurfaceFlinger", "--timestats", "-dump"))
    adb("shell", "dumpsys", "SurfaceFlinger", "--timestats", "-disable", "-clear")
    time.sleep(2)
    logcat.terminate()
    log.close()
    rows = sorted(r for r in frames.values() if r[1] != PENDING)
    with open(out / (name + ".present.tsv"), "w") as f:
        f.write("desired_ns\tpresent_ns\tready_ns\n")
        for row in rows:
            f.write("%d\t%d\t%d\n" % row)
    (out / (name + ".present.json")).write_text(json.dumps({"layer": layer, "refresh_ns": refresh, "interval_s": interval, "frames": len(rows), "polls": polls}) + "\n")
    print("%s: %d presented frames, %d polls, layer %s" % (name, len(rows), len(polls), layer or "NOT FOUND"))


def read_text(path):
    """A file's text, or its gzipped copy's (path + ".gz", as kept in docs/perf)."""
    path = pathlib.Path(path)
    if not path.exists() and path.with_name(path.name + ".gz").exists():
        return gzip.open(path.with_name(path.name + ".gz"), "rt").read()
    return path.read_text()


def _messages(text, stamp):
    """(time, message) of the engine's log lines; `stamp` reads a line's time."""
    found = []
    for line in text.splitlines():
        if " godot" in line and ": " in line:
            found.append((stamp(line), line.split(": ", 1)[1]))
    return found


def bench_times(run, name):
    """CLOCK_MONOTONIC seconds of each BENCH line, by viewpoint: from NAME.mono.log,
    or, where its stream lost lines (an adb hiccup ends `adb logcat`), from the
    bench's own log NAME.log (wall clock), shifted by the offset of a line both
    logs hold."""
    mono = _messages(read_text(run / (name + ".mono.log")), lambda line: float(line.split()[0]))
    found = {}
    for t, message in mono:
        if message.startswith("BENCH {"):
            found[json.loads(message[6:]).get("view", "")] = t
    wall_path = run / (name + ".log")
    if not wall_path.exists():
        return found

    def wall(line):
        day, clock = line.split()[:2]
        h, m, sec = clock.split(":")
        return int(day.split("-")[1]) * 86400 + int(h) * 3600 + int(m) * 60 + float(sec)

    walls = _messages(read_text(wall_path), wall)
    by_message = {message: t for t, message in mono}
    offsets = [by_message[message] - t for t, message in walls if message in by_message and message.strip()]
    if not offsets:
        return found
    offset = sorted(offsets)[len(offsets) // 2]
    for t, message in walls:
        if message.startswith("BENCH {"):
            found.setdefault(json.loads(message[6:]).get("view", ""), t + offset)
    return found


def window_stats(presents, refresh, start, end, poll_ns, quiet_ms=250):
    """Presents inside the window, their intervals in refreshes, and the same
    for the intervals that start at least quiet_ms after the latest poll: a
    `dumpsys SurfaceFlinger` call delays the next composition now and then,
    so those are the undisturbed sample."""
    inside = [p for p in presents if start < p <= end]
    intervals = [b - a for a, b in zip(inside, inside[1:])]
    vsyncs = [max(1, round(i / refresh)) for i in intervals]
    count = {k: sum(1 for v in vsyncs if v == k) for k in (1, 2, 3)}
    count[4] = sum(1 for v in vsyncs if v >= 4)
    polls = sorted(poll_ns)
    quiet = []
    for a, v in zip(inside, vsyncs):
        k = bisect.bisect_right(polls, a) - 1
        if k < 0 or a - polls[k] >= quiet_ms * 1e6:
            quiet.append(v)
    return inside, intervals, vsyncs, count, quiet


def near_polls(frame_ms, start, poll_ns, after_ms=150):
    """Long game frames (over 1.25 × the median, as the benchmark counts them)
    that end within after_ms of a poll, and the share of the window those
    stretches cover: much more than that share would mean the polling itself
    makes long frames. A poll's time is taken as its newest presented frame."""
    median = sorted(frame_ms)[len(frame_ms) // 2]
    t = start
    near = total = 0
    polls = sorted(poll_ns)
    for ms in frame_ms:
        t += int(ms * 1e6)
        if ms > 1.25 * median:
            total += 1
            near += any(0 <= t - p <= after_ms * 1e6 for p in polls)
    inside = [p for p in polls if start <= p <= t]
    return near, total, len(inside) * after_ms * 1e6 / max(1, t - start)


def summary(run_dirs):
    print("| Run | Experiment | Viewpoint | Game frames | Game long frames | Game 1 % low | Presented | Coverage | Present intervals in refreshes (1 / 2 / 3 / ≥4) | Presented long (≥3) | Presented long away from polls | Game long frames ≤150 ms after a poll (share of time) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    totals = {}
    for run in run_dirs:
        run = pathlib.Path(run)
        for name in sorted({p.name.split(".present.tsv")[0] for p in run.glob("*.present.tsv*")}):
            meta = json.loads((run / (name + ".present.json")).read_text())
            refresh = meta["refresh_ns"] or 16666666
            poll_ns = [p["newest_present_ns"] for p in meta["polls"] if p["newest_present_ns"]]
            presents = [int(line.split("\t")[1]) for line in read_text(run / (name + ".present.tsv")).splitlines()[1:]]
            results = json.loads(read_text(run / (name + ".json")))["results"]
            times = bench_times(run, name)
            for result in results:
                view = result["view"]
                if view not in times or "trace" not in result:
                    continue
                frame_ms = [float(x) for x in result["trace"]["measure"]["frame_ms"].split(",")]
                end = int(times[view] * 1e9)
                start = end - int(sum(frame_ms) * 1e6)
                inside, intervals, vsyncs, count, quiet = window_stats(presents, refresh, start, end, poll_ns)
                quiet_long = sum(1 for v in quiet if v >= 3)
                coverage = len(inside) / len(frame_ms) if frame_ms else 0
                near, long_total, share = near_polls(frame_ms, start, poll_ns)
                if coverage < 0.5:
                    print("| %s | %s | %s | %d | %d | %.2f | %d | %.1f %% | no presented trace for this window | | | |" % (
                        run.name, name, view, len(frame_ms), result["long_frames"], result["low1_fps"], len(inside), coverage * 100))
                    continue
                bad = result["long_frames"] > 0.01 * len(frame_ms)
                key = (name, "over 1 % long frames" if bad else "at most 1 %")
                t = totals.setdefault(key, [0] * 10)
                for i, v in enumerate((1, len(frame_ms), result["long_frames"], len(intervals), count[1], count[3] + count[4], len(quiet), quiet_long, near, long_total)):
                    t[i] += v
                print("| %s | %s | %s | %d | %d | %.2f | %d | %.1f %% | %d / %d / %d / %d | %d (%.1f %%) | %d of %d (%.1f %%) | %d of %d (%.1f %%) |" % (
                    run.name, name, view, len(frame_ms), result["long_frames"], result["low1_fps"], len(inside), coverage * 100,
                    count[1], count[2], count[3], count[4], count[3] + count[4], 100.0 * (count[3] + count[4]) / max(1, len(intervals)),
                    quiet_long, len(quiet), 100.0 * quiet_long / max(1, len(quiet)), near, long_total, share * 100))
    print()
    print("| Experiment | Viewpoints | Count | Game long frames (share of frames) | Present intervals of 1 refresh | Presented long, ≥3 (share of intervals) | Presented long away from polls (share) | Game long frames ≤150 ms after a poll |")
    print("|---|---|---|---|---|---|---|---|")
    for (name, kind), t in sorted(totals.items()):
        print("| %s | %s | %d | %d (%.2f %%) | %d | %d (%.2f %%) | %d of %d (%.2f %%) | %d of %d |" % (
            name, kind, t[0], t[2], 100.0 * t[2] / max(1, t[1]), t[4], t[5], 100.0 * t[5] / max(1, t[3]),
            t[7], t[6], 100.0 * t[7] / max(1, t[6]), t[8], t[9]))


def main():
    args = sys.argv[1:]
    if len(args) >= 3 and args[0] == "sample":
        interval = float(args[args.index("--interval") + 1]) if "--interval" in args else 2.0
        timeout = float(args[args.index("--timeout") + 1]) if "--timeout" in args else 1800.0
        sample(pathlib.Path(args[1]), args[2], interval, timeout)
    elif len(args) >= 2 and args[0] == "summary":
        summary(args[1:])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
