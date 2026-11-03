# Phase 6b evidence (2026-11-03)

Blind test and hardening of the import tool (`PROJECT_STATE.md`, "Phase 6b"). The blind runs, labels, and shots of the maps: `docs/maps/imported/blind/`; the import reports: `docs/maps/imported/`.

## Device scenarios (debug builds of `cc21cbe`; `tablet/`, `iphone/`)

| Run | Galaxy Tab A7 (low profile) | iPhone 13 Pro (high profile) |
|---|---|---|
| `scenario_vehicle_sleep_abstract_city` (blind map) | 9 / 9 PASS, `slope_skipped` (no sloped viewpoint); map ready 2,569 ms | 9 / 9 PASS; footprint 334 MiB; Nominal |
| `scenario_extensibility_abstract_city` (blind map; test district visited directly) | 21 / 21 PASS; city → test district 0.4 s, back 0.4 s; peak PSS 309,091 kB | 21 / 21 PASS; 0.1 s and 0.2 s; footprint 331 MiB; Nominal |
| `scenario_vehicle_sleep_apollo11_site` (blind map) | 13 / 13 PASS with the slope steps on the relief (6.7°); map ready 2,729 ms; peak PSS 322,514 kB | 13 / 13 PASS; footprint 365 MiB; Nominal |
| `scenario_vehicle_sleep_kenney_town` (re-imported town) | 9 / 9 PASS; map ready 2,467 ms; peak PSS 306,424 kB | 9 / 9 PASS; footprint 319 MiB; Nominal |

The step counts are the scenarios' own (`done … passed=N failed=0`). Commands: `tools/perf/android_bench.sh <experiment> <out>`, `IOS_UDID=<udid> tools/perf/ios_bench.sh <experiment> <out>` (`docs/ARCHITECTURE.md`, "Device scenario"). The tablet was locked at first; the user unlocked it.

## Tablet measurement (Release Perf, one run each, informational; `tablet_release/`)

Low profile, traced off, PSS sampling on (the single 100+ ms frames behind the minimum FPS), thermal status 0 throughout; battery 28.5 → 36.5 °C over the four runs (the cool-down to 32 °C timed out at 33.0 and 33.5 °C before the last two). Safranbolu again on a **temporary measurement build** (its test import written to `maps/safranbolu_test/` and registered for that APK only, then removed; `game/world/maps.tres` restored byte for byte; APK 706,042,570 B), because test imports are excluded from every export (T48). The spawn and viewpoints moved with the scored placement, so a viewpoint here is not the same place as in Phase 6a; compare the ranges.

| Map | Viewpoint | Average FPS | 1 % low | Minimum | Long frames | Draw calls | Primitives | Physics step (ms) | Physics p99 (ms) |
|---|---|---|---|---|---|---|---|---|---|
| Kenney town | Spawn | 29.89 | 25.35 | 8.23 | 11 of 1,794 | 56 | 14,074 | 4.90 | 9.90 |
| | View A | 29.87 | 24.94 | 8.67 | 8 of 1,792 | 60 | 19,454 | 4.33 | 8.12 |
| | View B | 29.93 | 25.42 | 9.74 | 8 of 1,796 | 73 | 17,702 | 4.77 | 10.08 |
| | View C | 29.90 | 25.54 | 9.26 | 9 of 1,795 | 83 | 23,544 | 4.33 | 7.39 |
| Safranbolu | Spawn | 29.90 | 26.00 | 8.37 | 6 of 1,795 | 95 | 189,380 | 4.53 | 9.39 |
| | View A | 29.91 | 25.93 | 9.61 | 6 of 1,795 | 55 | 169,260 | 4.63 | 9.68 |
| | View B | 28.69 | 17.71 | 8.37 | 150 of 1,722 | 210 | 217,602 | 4.71 | 6.66 |
| | View C | 29.87 | 24.67 | 8.78 | 11 of 1,792 | 75 | 174,259 | 6.03 | 12.56 |
| | Sloped street | 29.93 | 25.76 | 9.30 | 6 of 1,796 | 92 | 186,596 | 4.47 | 6.96 |
| Abstract city | Spawn | 29.85 | 24.59 | 7.91 | 14 of 1,792 | 38 | 3,144 | 5.28 | 12.49 |
| | View A | 29.85 | 24.75 | 8.14 | 14 of 1,791 | 31 | 3,268 | 5.15 | 9.29 |
| | View B | 29.90 | 24.93 | 8.64 | 12 of 1,795 | 30 | 4,300 | 5.23 | 12.45 |
| | View C | 29.88 | 24.38 | 8.77 | 16 of 1,793 | 26 | 2,412 | 5.16 | 7.27 |
| Apollo 11 site | Spawn | 29.88 | 24.62 | 8.29 | 13 of 1,793 | 30 | 145,843 | 6.10 | 19.27 |
| | View A | 29.89 | 24.98 | 7.94 | 11 of 1,794 | 32 | 146,006 | 5.86 | 15.90 |
| | View B | 29.88 | 24.41 | 8.49 | 13 of 1,793 | 32 | 146,006 | 6.12 | 10.79 |
| | View C | 29.85 | 24.69 | 8.00 | 13 of 1,791 | 32 | 146,006 | 5.94 | 11.14 |
| | Sloped street | 29.91 | 24.97 | 10.23 | 9 of 1,795 | 27 | 145,430 | 6.34 | 18.01 |

| Map | Physics step, Phase 6a | Physics step, Phase 6b | Peak PSS | Map ready |
|---|---|---|---|---|
| Kenney town | 4.08–4.99 ms (mean 4.39; 443 collision shapes) | 4.33–4.90 ms (mean 4.58, **+0.20 ms**; 792 shapes: capsules, boxes, 50 concave parts as trimesh) | 268,731 kB (6a: 265,775) | 2,300 ms (6a: 2,186) |
| Safranbolu | 4.35–6.38 ms (mean 4.88) | 4.47–6.03 ms (mean 4.87, **±0.00 ms**; 39 concave parts as trimesh) | 340,363 kB (6a: 336,133) | 2,667 ms (6a: 3,562) |
| Abstract city | — | 5.15–5.28 ms (mean 5.21; 217 shapes, the spawn among towers) | 260,741 kB | 1,487 ms |
| Apollo 11 site | — | 5.86–6.34 ms (mean 6.07; one 142,768-triangle trimesh, and one occluder of as many triangles) | 304,544 kB | 1,584 ms |

Safranbolu's View B (a new place, looking over the town: 210 draw calls, 217,602 primitives) is the only window with many long frames (150 of 1,722, 1 % low 17.71); one run, not investigated. The relief's physics step is the highest of the four with the fewest objects: its single large trimesh (open question 49 in `PROJECT_CONTEXT.md` covers its equally large occluder).

## Default map unchanged on the Mac (`desktop/`)

The game started on the Mac (Metal, 960×540) with `{"profile": "low"|"high", "map": "istanbul_halic_cells_shader", "bench": {"warmup_s": 5, "measure_s": 6, "screenshots": false, "quit_when_done": true}}`, before the task (`0aea505`: `before_6b`, `before_6b_2`) and at the final code (`after_6b`, `after_6b_2`): low 114 / 107 / 70 draw calls, 51,142 / 52,464 / 23,465 primitives (Spawn / Karaköy / Galata), high 218 / 178 / 116 and 135,639 / 101,720 / 59,619, objects 427 / 460 / 419 and 535 / 535 / 471, the same as Phase 6a, in every run but one: in `before_6b` the high profile's Galata window repeated Karaköy's figures (178 / 101,720 / 535), a measurement glitch of that run (the second run before and both runs after give 116 / 59,619 / 471).

## Categories unchanged

`categories_before_and_after.tsv.gz`: every mesh of the eight maps (the five existing maps, the Kenney town, Safranbolu, the İstanbul import; map id, node path, category; 25,955 lines) dumped before the re-imports (Phase 6a outputs) and from the final outputs; both dumps have SHA-256 `4116eec4fb8c0987e6eb80f1d89c2768b2e33a4a4610fa9b3ffb560a9e66baaa` uncompressed.

## Tool runs (Mac, Apple Silicon)

| Map | Phase 6a | Phase 6b |
|---|---|---|
| Kenney town | 0.3 s | 0.6–0.7 s |
| Safranbolu | 1.5–1.7 s | 2.2–2.3 s |
| İstanbul • Haliç import | 9.0–9.4 s, 1.75 GB peak resident | 12.0–12.1 s, 1.64–2.08 GB |
| Abstract city | — | 0.5 s |
| Apollo 11 site | — | 1.7 s |
