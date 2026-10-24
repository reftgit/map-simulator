#!/usr/bin/env python3
"""Turns benchmark outputs into Markdown tables.

    python3 -I tools/perf/summarize.py build/perf/android [--baseline baseline]

Reads <dir>/<experiment>.json (app results) and <experiment>.meta.json
(device temperatures / thermal state / memory) written by android_bench.sh or
ios_bench.sh. Prints a results table (one row per experiment and viewpoint)
and a cost-attribution table for hide_* experiments relative to the baseline.
"""
import json
import pathlib
import sys

VIEWS = ["Spawn", "Karaköy street, facing north", "Galata street, facing south"]
SHORT = {"Spawn": "Spawn", "Karaköy street, facing north": "Karaköy", "Galata street, facing south": "Galata"}


def load(directory):
    runs = {}
    for path in sorted(directory.glob("*.json")):
        if path.name.endswith((".meta.json", ".trace.json")):
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        meta_path = path.with_suffix(".meta.json")
        meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
        runs[path.stem] = {"results": {r["view"]: r for r in data.get("results", [])}, "meta": meta,
                           "apply": data.get("apply", {})}
    return runs


def conditions(meta):
    if meta.get("device") == "android":
        return f"{meta.get('battery_c_start')}→{meta.get('battery_c_end')} °C, status {meta.get('thermal_status_start')}→{meta.get('thermal_status_end')}"
    if meta.get("device") == "ios":
        probes = meta.get("probes", [])
        first = {s: next((p["t"] for p in probes if p["thermal"] == s), None) for s in ("Fair", "Serious")}
        onset = ", ".join(f"{s} at {t} s" for s, t in first.items() if t is not None)
        verdict = " — INVALID (Serious)" if meta.get("thermal_max") == "Serious" else ""
        return f"{meta.get('thermal_start')}→{meta.get('thermal_end')} (max {meta.get('thermal_max')}{'; ' + onset if onset else ''}){verdict}"
    return ""


def memory(meta):
    if "pss_peak_kb" in meta:
        return f"PSS {round(meta['pss_peak_kb'] / 1024)} MiB" if meta["pss_peak_kb"] else "PSS not sampled"
    if meta.get("footprint_peak_mib"):
        return f"footprint {meta['footprint_peak_mib']} MiB"
    return ""


def results_table(runs):
    lines = ["| Experiment | View | Avg FPS | 1% low | Min FPS | Draw calls | Primitives | Objects | VRAM MiB | Static MiB | Peak memory | Thermal / temp |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for name, run in runs.items():
        session = [r for r in run["results"].values() if "minute" in r]
        if session:
            continue
        for view in VIEWS:
            r = run["results"].get(view)
            if not r:
                continue
            lines.append(f"| {name} | {SHORT[view]} | {r['avg_fps']:.1f} | {r['low1_fps']:.1f} | {r['min_fps']:.1f} | "
                         f"{r['draw_calls']} | {r['primitives']:,} | {r['objects']} | {r['video_mem_mb']} | {r['static_mem_mb']} | "
                         f"{memory(run['meta'])} | {conditions(run['meta'])} |")
    return "\n".join(lines)


def compact_table(runs, order=None):
    """One row per experiment; Spawn / Karaköy / Galata values separated by " / "."""
    lines = ["| Experiment | Avg FPS (S / K / G) | 1% low | Min FPS | Draw calls | Primitives (M) | VRAM MiB | Peak memory | Thermal / temperature |",
             "|---|---|---|---|---|---|---|---|---|"]
    names = [n for n in (order or runs) if n in runs]
    for name in names:
        run = runs[name]
        rows = [run["results"].get(v) for v in VIEWS]
        if not all(rows):
            continue
        join = lambda key, fmt: " / ".join(fmt(r[key]) for r in rows)
        lines.append(f"| {name} | {join('avg_fps', lambda v: f'{v:.1f}')} | {join('low1_fps', lambda v: f'{v:.1f}')} | "
                     f"{join('min_fps', lambda v: f'{v:.1f}')} | {join('draw_calls', str)} | "
                     f"{join('primitives', lambda v: f'{v / 1e6:.2f}')} | {rows[0]['video_mem_mb']} | {memory(run['meta'])} | {conditions(run['meta'])} |")
    return "\n".join(lines)


def session_table(runs):
    lines = ["| Minute | Avg FPS | 1% low | Min FPS | Draw calls | Primitives | Thermal (nearest probe) |", "|---|---|---|---|---|---|---|"]
    for name, run in runs.items():
        session = sorted((r for r in run["results"].values() if "minute" in r), key=lambda r: r["minute"])
        if not session:
            continue
        data = json.loads((DIRECTORY / f"{name}.json").read_text())["results"]
        probes = run["meta"].get("probes", [])
        for r in sorted(data, key=lambda r: r["minute"]):
            t_end = 2 + 60 * r["minute"]
            near = min(probes, key=lambda p: abs(p["t"] - t_end))["thermal"] if probes else ""
            lines.append(f"| {r['minute']} | {r['avg_fps']:.1f} | {r['low1_fps']:.1f} | {r['min_fps']:.1f} | {r['draw_calls']} | {r['primitives']:,} | {near} |")
    return "\n".join(lines)


def attribution_table(runs, baseline):
    base = runs.get(baseline)
    if not base:
        return f"(no {baseline} run)"
    lines = ["| Hidden category | View | Draw calls (Δ, % of baseline) | Primitives (Δ, % of baseline) | Avg FPS (baseline → hidden) |",
             "|---|---|---|---|---|"]
    for name, run in runs.items():
        if not name.startswith("hide_"):
            continue
        for view in VIEWS:
            b, r = base["results"].get(view), run["results"].get(view)
            if not (b and r):
                continue
            dc = b["draw_calls"] - r["draw_calls"]
            pr = b["primitives"] - r["primitives"]
            lines.append(f"| {name[5:]} | {SHORT[view]} | {dc} ({100 * dc / max(b['draw_calls'], 1):.0f} %) | "
                         f"{pr:,} ({100 * pr / max(b['primitives'], 1):.0f} %) | {b['avg_fps']:.1f} → {r['avg_fps']:.1f} |")
    return "\n".join(lines)


if __name__ == "__main__":
    DIRECTORY = directory = pathlib.Path(sys.argv[1])
    baseline = sys.argv[sys.argv.index("--baseline") + 1] if "--baseline" in sys.argv else "baseline"
    runs = load(directory)
    if "--compact" in sys.argv:
        print(compact_table(runs))
        print("\n" + session_table(runs))
        print("\n" + attribution_table(runs, baseline))
        sys.exit(0)
    print(f"## Results ({directory})\n")
    print(results_table(runs))
    print("\n## Cost attribution\n")
    print(attribution_table(runs, baseline))
    applies = {n: r["apply"] for n, r in runs.items() if r["apply"]}
    if applies:
        print("\n## Apply reports\n")
        for name, report in applies.items():
            print(f"- {name}: {report}")
