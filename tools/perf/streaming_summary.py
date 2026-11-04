#!/usr/bin/env python3
"""Streaming in benchmark results (docs/STREAMING.md): per result (viewpoint or
route direction) the frames, average FPS, 1 % low, long frames, the frames
over 50 ms and how many of them fall within one frame of a frame in which
cells got their meshes (traced results only), the cells loaded and freed,
the longest main-thread time for attaching cells in a frame, and the frames
with a needed cell missing (routes). One Markdown row per result.

    python3 -I tools/perf/streaming_summary.py RESULTS.json [...]
"""
import json
import sys

OVER_MS = 50.0


def rows(path):
    data = json.load(open(path))
    startup = data.get("startup", {})
    for result in data.get("results", []):
        streaming = result.get("streaming", {})
        trace = result.get("trace", {})
        frames = [float(x) for x in trace.get("measure", trace).get("frame_ms", "").split(",") if x] if trace else []
        cells = trace.get("measure", trace).get("cells", []) if trace else []
        attached = {event[0] for event in cells}
        over = [i for i, ms in enumerate(frames) if ms > OVER_MS]
        near = [i for i in over if any(j in attached for j in (i - 1, i, i + 1))]
        yield {
            "file": path.split("/")[-1], "view": result.get("view"), "map_ready_ms": startup.get("map_ready_ms"),
            "frames": result.get("frames"), "avg_fps": result.get("avg_fps"), "low1_fps": result.get("low1_fps"),
            "long_frames": result.get("long_frames"), "over_50": len(over) if frames else "-",
            "over_50_near_attach": len(near) if frames else "-", "max_ms": round(max(frames), 1) if frames else "-",
            "loads": streaming.get("loads", "-"), "unloads": streaming.get("unloads", "-"),
            "attach_frames": streaming.get("attach_frames", "-"), "attach_max_ms": streaming.get("attach_max_ms", "-"),
            "missing_frames": streaming.get("missing_frames", "-"), "loaded": streaming.get("loaded", "-"),
            "draw_calls": result.get("draw_calls"), "primitives": result.get("primitives"),
        }


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    keys = ["file", "view", "map_ready_ms", "frames", "avg_fps", "low1_fps", "long_frames", "over_50", "over_50_near_attach", "max_ms",
            "loads", "unloads", "attach_frames", "attach_max_ms", "missing_frames", "loaded", "draw_calls", "primitives"]
    print("| " + " | ".join(keys) + " |")
    print("|" + "---|" * len(keys))
    for path in sys.argv[1:]:
        for row in rows(path):
            print("| " + " | ".join(str(row[k]) for k in keys) + " |")


if __name__ == "__main__":
    main()
