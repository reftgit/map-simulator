#!/usr/bin/env python3
"""Medians over repeated benchmark runs (at least three per device and viewpoint).

    python3 -I tools/perf/median.py build/perf/phase3/android/run1 build/perf/phase3/android/run2 build/perf/phase3/android/run3

Each directory holds one run of each experiment (<experiment>.json from
android_bench.sh / ios_bench.sh). Prints one Markdown row per experiment and
viewpoint (or session minute) with the median and, in brackets, every run's
value, so the spread stays visible.
"""
import json
import pathlib
import statistics
import sys

SHORT = {"Spawn": "Spawn", "Karaköy street, facing north": "Karaköy", "Galata street, facing south": "Galata"}
FIELDS = [("avg_fps", "Avg FPS", 2), ("low1_fps", "1% low", 2), ("min_fps", "Min FPS", 2),
          ("draw_calls", "Draw calls", 0), ("physics_ms", "Physics ms", 3), ("physics_p99_ms", "Physics p99 ms", 3)]


def load(directory):
    runs = {}
    for path in sorted(pathlib.Path(directory).glob("*.json")):
        if path.name.endswith((".meta.json", ".trace.json")):
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        rows = {}
        for result in data.get("results", []):
            key = (SHORT.get(result["view"], result["view"]), result.get("minute", 0))
            rows[key] = result
        runs[path.stem] = rows
    return runs


def cell(values, digits):
    if not values:
        return "—"
    fmt = "{:.%df}" % digits
    median = statistics.median(values)
    return f"{fmt.format(median)} [{' / '.join(fmt.format(v) for v in values)}]"


def main(directories):
    loaded = [load(d) for d in directories]
    experiments = sorted(set().union(*(run.keys() for run in loaded)))
    header = "| Experiment | View | Runs | " + " | ".join(label for _, label, _ in FIELDS) + " |"
    print(header)
    print("|" + "---|" * (3 + len(FIELDS)))
    for experiment in experiments:
        keys = []
        for run in loaded:
            for key in run.get(experiment, {}):
                if key not in keys:
                    keys.append(key)
        for view, minute in keys:
            results = [run[experiment][(view, minute)] for run in loaded if (view, minute) in run.get(experiment, {})]
            label = f"{view} min {minute}" if minute else view
            cells = [cell([r[field] for r in results if field in r], digits) for field, _, digits in FIELDS]
            print(f"| {experiment} | {label} | {len(results)} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
