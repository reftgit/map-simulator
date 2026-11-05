#!/usr/bin/env python3
"""Streaming in benchmark results (docs/STREAMING.md): per result (viewpoint or
route direction) the frames, average FPS, 1 % low, long frames, the frames
over 50 ms and how many of them fall within one frame of a frame in which
cells got their meshes, were requested, or were freed (traced results only),
the cells loaded and freed, the longest main-thread time for attaching cells
in a frame, and the frames with a needed cell missing (routes). One Markdown
row per result.

With --timeline, one row per frame over --over milliseconds (default 50)
instead: when it came (seconds into the measurement), its loop, GPU, and
render CPU times, the nearest frame in which cells were attached, requested,
or freed (frames away, negative before; the cells and the attach time), and
the pipelines compiled within one frame of it. Traces from before Phase 6d
have no requests or frees ("-").

    python3 -I tools/perf/streaming_summary.py RESULTS.json [...]
    python3 -I tools/perf/streaming_summary.py --timeline [--over MS] RESULTS.json [...]
"""
import json
import sys

OVER_MS = 50.0


def _floats(text):
    return [float(x) for x in text.split(",") if x]


def _nearest(events, frame):
    """The event (first element a frame index) nearest to `frame`, or None."""
    return min(events, key=lambda event: (abs(event[0] - frame), event[0]), default=None)


def _near(events, frame):
    return any(abs(event[0] - frame) <= 1 for event in events)


def results(path):
    data = json.load(open(path))
    for result in data.get("results", []):
        trace = result.get("trace", {})
        yield data.get("startup", {}), result, trace.get("measure", trace) if trace else {}


def rows(path):
    for startup, result, trace in results(path):
        streaming = result.get("streaming", {})
        frames = _floats(trace.get("frame_ms", "")) if trace else []
        cells = trace.get("cells", [])
        requested = trace.get("requested")
        freed = trace.get("freed")
        over = [i for i, ms in enumerate(frames) if ms > OVER_MS]
        yield {
            "file": path.split("/")[-1], "view": result.get("view"), "map_ready_ms": startup.get("map_ready_ms"),
            "frames": result.get("frames"), "avg_fps": result.get("avg_fps"), "low1_fps": result.get("low1_fps"),
            "long_frames": result.get("long_frames"), "over_50": len(over) if frames else "-",
            "over_50_near_attach": sum(_near(cells, i) for i in over) if frames else "-",
            "over_50_near_request": sum(_near(requested, i) for i in over) if frames and requested is not None else "-",
            "over_50_near_free": sum(_near(freed, i) for i in over) if frames and freed is not None else "-",
            "max_ms": round(max(frames), 1) if frames else "-",
            "loads": streaming.get("loads", "-"), "unloads": streaming.get("unloads", "-"),
            "attach_frames": streaming.get("attach_frames", "-"), "attach_max_ms": streaming.get("attach_max_ms", "-"),
            "missing_frames": streaming.get("missing_frames", "-"), "loaded": streaming.get("loaded", "-"),
            "draw_calls": result.get("draw_calls"), "primitives": result.get("primitives"),
        }


def timeline(path, over_ms):
    for _startup, result, trace in results(path):
        frames = _floats(trace.get("frame_ms", "")) if trace else []
        if not frames:
            continue
        gpu = _floats(trace.get("gpu_ms", ""))
        cpu = _floats(trace.get("render_cpu_ms", ""))
        cells, requested, freed = trace.get("cells", []), trace.get("requested"), trace.get("freed")
        pipelines = trace.get("pipelines", [])
        elapsed = 0.0
        for i, ms in enumerate(frames):
            elapsed += ms / 1000.0
            if ms <= over_ms:
                continue
            attach = _nearest(cells, i)
            request = _nearest(requested or [], i)
            free = _nearest(freed or [], i)
            compiled = sum(sum(event[1:]) for event in pipelines if abs(event[0] - i) <= 1)
            yield {
                "file": path.split("/")[-1], "view": result.get("view"), "frame": i, "t_s": round(elapsed, 2), "ms": ms,
                "gpu_ms": gpu[i] if i < len(gpu) else "-", "render_cpu_ms": cpu[i] if i < len(cpu) else "-",
                "attach": "%+d (%d cells, %.2f ms)" % (attach[0] - i, attach[1], attach[2]) if attach else "none",
                "request": ("%+d (%d)" % (request[0] - i, request[1]) if request else "none") if requested is not None else "-",
                "free": ("%+d (%d)" % (free[0] - i, free[1]) if free else "none") if freed is not None else "-",
                "pipelines": compiled,
            }


def table(keys, records):
    print("| " + " | ".join(keys) + " |")
    print("|" + "---|" * len(keys))
    for record in records:
        print("| " + " | ".join(str(record[k]) for k in keys) + " |")


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "--timeline":
        args = args[1:]
        over_ms = OVER_MS
        if args[:1] == ["--over"]:
            over_ms = float(args[1])
            args = args[2:]
        keys = ["file", "view", "frame", "t_s", "ms", "gpu_ms", "render_cpu_ms", "attach", "request", "free", "pipelines"]
        table(keys, [record for path in args for record in timeline(path, over_ms)])
        return
    keys = ["file", "view", "map_ready_ms", "frames", "avg_fps", "low1_fps", "long_frames", "over_50", "over_50_near_attach",
            "over_50_near_request", "over_50_near_free", "max_ms", "loads", "unloads", "attach_frames", "attach_max_ms",
            "missing_frames", "loaded", "draw_calls", "primitives"]
    table(keys, [record for path in args for record in rows(path)])


if __name__ == "__main__":
    main()
