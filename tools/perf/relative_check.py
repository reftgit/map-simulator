#!/usr/bin/env python3
"""A map against a reference map measured with the same protocol (D25's
relative criterion 1, 2026-11-02).

    python3 -I tools/perf/relative_check.py CANDIDATE REFERENCE RUN_DIR...

Reads RUN_DIR/<experiment>.json or .json.gz (benchmark results) and .meta.json (battery,
cool-down wait) for both experiments, one launch each per run folder, and
prints Markdown tables: per launch, the long frames per viewpoint, whether the
launch is bad (a viewpoint with more than 1 % long frames), the battery
temperature, and the cool-down wait; per viewpoint, the median 1 % low and
the median and lowest average FPS; then the verdict:
(a) at least 9 launches of each; (b) the candidate's bad launches at most one
more than the reference's; (c) the candidate's median 1 % low at most 0.5 FPS
below the reference's at every viewpoint; (d) the candidate's median average
FPS at least 29.9 at every viewpoint.
"""
import gzip
import json
import pathlib
import statistics
import sys


def launches(name, run_dirs):
    found = []
    for run in run_dirs:
        path = pathlib.Path(run) / (name + ".json")
        packed = path.with_name(path.name + ".gz")
        if path.exists():
            data = json.loads(path.read_text())
        elif packed.exists():
            data = json.loads(gzip.open(packed, "rt").read())
        else:
            continue
        meta_path = path.with_name(name + ".meta.json")
        meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
        found.append({"run": pathlib.Path(run).name, "startup": data.get("startup", {}), "results": data["results"], "meta": meta})
    return found


def is_bad(launch):
    return any(r["long_frames"] > 0.01 * r["frames"] for r in launch["results"])


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    candidate, reference, run_dirs = sys.argv[1], sys.argv[2], sys.argv[3:]
    data = {name: launches(name, run_dirs) for name in (candidate, reference)}
    views = [r["view"] for r in data[candidate][0]["results"]] if data[candidate] else []

    print("| Run | Experiment | Map | Long frames per viewpoint (%s) | Bad launch | Battery start → end °C | Cool-down wait s |" % " / ".join(views))
    print("|---|---|---|---|---|---|---|")
    for i in range(max(len(data[candidate]), len(data[reference]))):
        for name in (candidate, reference):
            if i >= len(data[name]):
                continue
            launch = data[name][i]
            longs = " / ".join("%d (%.1f %%)" % (r["long_frames"], 100.0 * r["long_frames"] / r["frames"]) for r in launch["results"])
            meta = launch["meta"]
            print("| %s | %s | %s | %s | %s | %s → %s | %s |" % (launch["run"], name, launch["startup"].get("map", "?"), longs,
                "**yes**" if is_bad(launch) else "no", meta.get("battery_c_start", "?"), meta.get("battery_c_end", "?"), meta.get("cool_wait_s", "?")))

    print()
    print("| Viewpoint | %s: 1 %% low median [launches] | %s: 1 %% low median [launches] | Difference | %s: average FPS median (lowest) | %s: average FPS median (lowest) |" % (candidate, reference, candidate, reference))
    print("|---|---|---|---|---|---|")
    medians = {}
    for view in views:
        cells = []
        for name in (candidate, reference):
            lows = [r["low1_fps"] for launch in data[name] for r in launch["results"] if r["view"] == view]
            avgs = [r["avg_fps"] for launch in data[name] for r in launch["results"] if r["view"] == view]
            medians[(name, view)] = (statistics.median(lows), statistics.median(avgs), min(avgs))
            cells.append("%.2f [%s]" % (statistics.median(lows), " / ".join("%.2f" % x for x in lows)))
        diff = medians[(candidate, view)][0] - medians[(reference, view)][0]
        print("| %s | %s | %s | %+.2f | %.2f (%.2f) | %.2f (%.2f) |" % (view, cells[0], cells[1], diff,
            medians[(candidate, view)][1], medians[(candidate, view)][2], medians[(reference, view)][1], medians[(reference, view)][2]))

    n_c, n_r = len(data[candidate]), len(data[reference])
    bad_c = sum(is_bad(launch) for launch in data[candidate])
    bad_r = sum(is_bad(launch) for launch in data[reference])
    checks = [
        ("(a) at least 9 launches each", n_c >= 9 and n_r >= 9, "%d and %d" % (n_c, n_r)),
        ("(b) bad launches at most one more than the reference's", bad_c <= bad_r + 1, "%d against %d" % (bad_c, bad_r)),
        ("(c) median 1 % low at most 0.5 FPS below the reference's at every viewpoint", all(medians[(candidate, v)][0] >= medians[(reference, v)][0] - 0.5 for v in views),
            ", ".join("%+.2f" % (medians[(candidate, v)][0] - medians[(reference, v)][0]) for v in views)),
        ("(d) median average FPS at least 29.9 at every viewpoint", all(medians[(candidate, v)][1] >= 29.9 for v in views),
            ", ".join("%.2f" % medians[(candidate, v)][1] for v in views)),
    ]
    print()
    print("| Check | Result | Values |")
    print("|---|---|---|")
    for label, ok, values in checks:
        print("| %s | %s | %s |" % (label, "PASS" if ok else "**FAIL**", values))
    print()
    print("Relative criterion: %s" % ("PASS" if all(ok for _, ok, _ in checks) else "FAIL"))


if __name__ == "__main__":
    main()
