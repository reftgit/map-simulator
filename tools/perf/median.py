#!/usr/bin/env python3
"""Medians over repeated benchmark runs (at least three per device and viewpoint).

    python3 -I tools/perf/median.py [--pacing] RUN_DIR RUN_DIR RUN_DIR ...

Each directory holds one run of each experiment (<experiment>.json from
android_bench.sh / ios_bench.sh). Prints one Markdown row per experiment and
viewpoint (or session minute) with the median and, in brackets, every run's
value, so the spread stays visible.

--pacing prints frame-time distributions instead: percentiles, long frames
(more than 1.25 x the median), and the share of frames at each multiple of the
display refresh interval (from the results' startup.display_refresh_rate, or
screen_refresh_rate in older results), summed over the runs.
"""
import json
import pathlib
import statistics
import sys

SHORT = {"Spawn": "Spawn", "Karaköy street, facing north": "Karaköy", "Galata street, facing south": "Galata"}
FIELDS = [("avg_fps", "Avg FPS", 2), ("low1_fps", "1% low", 2), ("min_fps", "Min FPS", 2),
          ("draw_calls", "Draw calls", 0), ("physics_ms", "Physics ms", 3), ("physics_p99_ms", "Physics p99 ms", 3),
          ("process_ms", "Process ms", 3), ("vehicles_asleep", "Vehicles asleep", 3)]
PACING = [("frame_p50_ms", "p50 ms", 2), ("frame_p90_ms", "p90 ms", 2), ("frame_p99_ms", "p99 ms", 2),
          ("long_frames", "Long frames", 0), ("frames", "Frames", 0)]


def load(directory):
    runs = {}
    for path in sorted(pathlib.Path(directory).glob("*.json")):
        if path.name.endswith((".meta.json", ".trace.json")):
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        startup = data.get("startup", {})
        refresh = startup.get("display_refresh_rate") or startup.get("screen_refresh_rate") or 60.0
        rows = {}
        for result in data.get("results", []):
            key = (SHORT.get(result["view"], result["view"]), result.get("minute", 0))
            result = dict(result, _refresh=refresh)
            rows[key] = result
        runs[path.stem] = rows
    return runs


def cell(values, digits):
    if not values:
        return "—"
    fmt = "{:.%df}" % digits
    median = statistics.median(values)
    return f"{fmt.format(median)} [{' / '.join(fmt.format(v) for v in values)}]"


def clusters(results):
    """Share of frames at each multiple of the refresh interval, over all results."""
    shares = {}
    total = 0
    for result in results:
        hist = result.get("frame_hist_ms")
        if not hist:
            continue
        interval = 1000.0 / result["_refresh"]
        for ms, count in enumerate(hist):
            multiple = max(1, round((ms + 0.5) / interval))
            label = f"{multiple * interval:.1f}"
            shares[label] = shares.get(label, 0) + count
            total += count
    if not total:
        return "—"
    top = sorted(shares.items(), key=lambda item: -item[1])[:4]
    return ", ".join(f"{label} ms {100.0 * count / total:.1f} %" for label, count in top)


def main(args):
    pacing = "--pacing" in args
    directories = [a for a in args if a != "--pacing"]
    loaded = [load(d) for d in directories]
    experiments = sorted(set().union(*(run.keys() for run in loaded)))
    fields = PACING if pacing else FIELDS
    extra = " | Frames at refresh multiples (all runs) |" if pacing else " |"
    print("| Experiment | View | Runs | " + " | ".join(label for _, label, _ in fields) + extra)
    print("|" + "---|" * (3 + len(fields) + (1 if pacing else 0)))
    for experiment in experiments:
        keys = []
        for run in loaded:
            for key in run.get(experiment, {}):
                if key not in keys:
                    keys.append(key)
        for view, minute in keys:
            results = [run[experiment][(view, minute)] for run in loaded if (view, minute) in run.get(experiment, {})]
            label = f"{view} min {minute}" if minute else view
            cells = [cell([r[field] for r in results if field in r], digits) for field, _, digits in fields]
            row = f"| {experiment} | {label} | {len(results)} | " + " | ".join(cells)
            print(row + (f" | {clusters(results)} |" if pacing else " |"))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
