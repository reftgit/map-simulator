# Mac probes (Apple M5, Metal, 960×540 windows; scripts were throwaway, outputs below)

## Memory of the default map's meshes and nodes (whole map in the tree, a camera on the bridge)

| State | Engine static memory | Video memory | Buffer memory | Objects | Resources | Nodes |
|---|---|---|---|---|---|---|
| Empty | 35.0 MB | 10.8 MB | 1.6 MB | 1,516 | 5 | 1 |
| Whole map | 233.3 MB | 307.7 MB | 204.4 MB | 22,442 | 13,137 | 7,789 |
| The 4,726 facade detail, tree, lamp, decor meshes taken out of their nodes | 170.5 MB | 162.9 MB | 58.5 MB | 12,985 | 3,680 | 7,789 |
| Those nodes freed too (the 4,542 without children) | 160.9 MB | 162.9 MB | 58.5 MB | 8,444 | 3,680 | 3,247 |

The process's resident size did not fall (441 → 479 MB): memory freed after loading stays with the process, so what is never loaded is what saves.

## Threaded cell loads and a worker-thread crash

Quick launches of the streamed default map (`--perf-config`, low profile, one viewpoint, 0.2 s windows), 20 each:

| Variant | Crashes (signal 11 in a worker thread, at the first prime) |
|---|---|
| Every prime threaded (requests made in `Main._ready()`) | 7 of 20 (and 4 of 8 in the 3-viewpoint benchmark; the map loaded whole: 0 of 8) |
| Cells loaded on the main thread only | 0 of 20 |
| The first prime on the main thread, later primes threaded (from the benchmark's viewpoint changes) | 0 of 20 |
| Threaded first prime two drawn frames later (the streamer's own first frame primed, threaded) | 0 of 20 |
| Final code: primes on the main thread, the frame loop's loads threaded | 0 of 20 |

A separate stress test (resident scene in the tree, 300 rounds of 4 concurrent threaded cell loads with meshes assigned and a frame drawn) ran 3 times without a crash. The engine is an official build without symbols; the backtrace (identical in both captured crashes) ends in WorkerThreadPool → ResourceLoader.

## Headless (dummy renderer) and threads

2,612 cells requested at once headless: 37 engine errors ("Attempting to initialize the wrong RID", "Parameter "m" is null" in the dummy mesh storage) and 4 leaked dummy meshes; with the cells loaded on the main thread: none.

## Draw-call outliers at fixed viewpoints (occlusion culling)

Benchmarks at the three viewpoints sometimes counted more draw calls at Galata (130–148 instead of 70) or Karaköy (117 instead of 107) with streaming on (in 10 of 47 benchmark launches of 3 s or more per viewpoint), never with it off (0 of 13). The camera's position and direction were identical (logged), the same cells were loaded, and the screenshots differed only in the overlay's numbers. A probe (HUD hidden, Karaköy → Galata 25 times in one launch) gave:

| Variant | Galata counts above normal (22 objects) |
|---|---|
| Streamed | 14 of 25 jumps (96–103 objects), persistent, not cleared by turning the camera 0.0005 rad |
| Whole map | 0 of 25 |
| Whole map, 25 ms stall in the frame of each jump (after the camera) | 6 of 25 (102) |
| Whole map, 25 ms stall one frame later | 4 of 25 |
| Whole map, 25 ms stall, occlusion culling off | 0 of 25 (107 every time: no culling) |

So a long frame right after a camera jump can leave Godot's occlusion culling less effective at that spot; a prime is such a frame. Visual effect: none (only objects that are hidden behind others are drawn). The Phase 6b "glitch" (`docs/perf/phase6b/README.md`: Galata repeating Karaköy's counts in one run without streaming) belongs to the same family.

## The overlay's objects

On a streamed map the debug overlay's third line is longer ("cells 7/2612 +0 0.3 MB" instead of "cells off"), which the renderer counts as 22–24 more objects and 44–48 more primitives with the same draw calls (also with occlusion culling off). Release Perf builds have no overlay.
