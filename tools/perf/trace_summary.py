#!/usr/bin/env python3
"""Where the long frames of traced benchmark runs fall (bench section "trace": true).

    python3 -I tools/perf/trace_summary.py RUN_DIR [RUN_DIR ...]

For every experiment and viewpoint of every run (one <experiment>.json per run
directory, as android_bench.sh writes them): the long frames (more than 1.25 x
the measurement's median frame time) in the warm-up and in the measurement;
when they fall (counts per 10 s of the warm-up + measurement, the time of the
first and the last, the median gap between them, and the longest run of
consecutive long frames); the GPU time per frame (mean and 99th percentile,
and its mean on long frames); and the pipelines compiled during the warm-up
and the measurement (Godot's counters by source: canvas, mesh, surface, draw,
specialization; only "draw" and "specialization" are compiled while drawing).
"""
import json
import pathlib
import statistics
import sys

SHORT = {"Spawn": "Spawn", "Karaköy street, facing north": "Karaköy", "Galata street, facing south": "Galata"}
BIN_S = 10.0


def values(text):
    return [float(v) for v in text.split(",")] if text else []


def percentile(sorted_values, q):
    if not sorted_values:
        return 0.0
    return sorted_values[min(len(sorted_values) - 1, max(0, int(len(sorted_values) * q + 0.999999) - 1))]


def summarize(result):
    trace = result["trace"]
    warm = values(trace["warmup"]["frame_ms"])
    meas = values(trace["measure"]["frame_ms"])
    gpu = values(trace["warmup"]["gpu_ms"]) + values(trace["measure"]["gpu_ms"])
    frames = warm + meas
    limit = statistics.median(meas) * 1.25
    times = []
    elapsed = 0.0
    long_gpu = []
    run = best = 0
    for i, ms in enumerate(frames):
        elapsed += ms / 1000
        if ms > limit:
            times.append(elapsed)
            run += 1
            best = max(best, run)
            if i < len(gpu):
                long_gpu.append(gpu[i])
        else:
            run = 0
    bins = [0] * (int(elapsed // BIN_S) + 1)
    for t in times:
        bins[int(t // BIN_S)] += 1
    gaps = [b - a for a, b in zip(times, times[1:])]
    sorted_gpu = sorted(g for g in values(trace["measure"]["gpu_ms"]) if g > 0)
    pipelines = {}
    for window in ("warmup", "measure"):
        totals = [0, 0, 0, 0, 0]
        for event in trace[window].get("pipelines", []):
            for k in range(5):
                totals[k] += event[k + 1]
        pipelines[window] = totals
    return {
        "warm_long": sum(1 for ms in warm if ms > limit), "meas_long": sum(1 for ms in meas if ms > limit),
        "bins": bins, "first": times[0] if times else None, "last": times[-1] if times else None,
        "gap": statistics.median(gaps) if gaps else None, "run": best,
        "gpu_mean": statistics.mean(sorted_gpu) if sorted_gpu else 0.0, "gpu_p99": percentile(sorted_gpu, 0.99),
        "gpu_long": statistics.mean(long_gpu) if long_gpu else None, "pipelines": pipelines,
        "warm_s": sum(warm) / 1000,
    }


def fmt(value, digits=1):
    return "-" if value is None else "%.*f" % (digits, value)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    print("| Run | Experiment | View | Long warm-up / measure | Long frames per 10 s (warm-up \\| measure) | First, last (s) | Median gap (s) | Longest streak | GPU ms mean / p99 / on long | Pipelines warm-up / measure (canvas, mesh, surface, draw, spec.) |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for directory in sys.argv[1:]:
        for path in sorted(pathlib.Path(directory).glob("*.json")):
            if path.name.endswith(".meta.json"):
                continue
            data = json.loads(path.read_text())
            for result in data.get("results", []):
                if "trace" not in result:
                    continue
                s = summarize(result)
                split = int(s["warm_s"] // BIN_S)
                bins = " ".join(str(b) for b in s["bins"][:split]) + " \\| " + " ".join(str(b) for b in s["bins"][split:])
                print("| %s | %s | %s | %d / %d | %s | %s, %s | %s | %d | %s / %s / %s | %s / %s |" % (
                    pathlib.Path(directory).name, result["experiment"], SHORT.get(result["view"], result["view"]), s["warm_long"], s["meas_long"],
                    bins, fmt(s["first"]), fmt(s["last"]), fmt(s["gap"], 2), s["run"], fmt(s["gpu_mean"], 2), fmt(s["gpu_p99"], 2),
                    fmt(s["gpu_long"], 2), ",".join(map(str, s["pipelines"]["warmup"])), ",".join(map(str, s["pipelines"]["measure"]))))


if __name__ == "__main__":
    main()
