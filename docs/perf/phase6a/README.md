# Phase 6a evidence (2026-11-02)

Map infrastructure: the map contract, the categories as map data, the import tool, three imported maps (`PROJECT_STATE.md`, "Phase 6a"). Reports of the imports: `docs/maps/imported/`.

## Device scenarios (debug builds of `0e542f9`)

| Run | Galaxy Tab A7 (`tablet/`) | iPhone 13 Pro (`iphone/`) |
|---|---|---|
| `scenario_vehicle_sleep_kenney_town` | 9 / 9 PASS, `slope_skipped` (the town has no sloped viewpoint); map ready 3,911 ms; peak PSS 346,524 kB | 9 / 9 PASS; map ready 608 ms; footprint 327 MiB; Nominal |
| `scenario_extensibility_kenney_town` | 21 / 21 PASS; town → test district 420 ms, back 515 ms; nodes 1,435 before and after; peak PSS 311,863 kB | 21 / 21 PASS; 0.1 s and 0.2 s; footprint 306 MiB; Nominal |
| `scenario_vehicle_sleep` (the default map) | 13 / 13 PASS, slope steps on Galata (12.6°) through `sloped_viewpoint`; peak PSS 691,233 kB | 13 / 13 PASS; footprint 874 MiB; Nominal |

Commands: `tools/perf/android_bench.sh <experiment> <out>`, `IOS_UDID=<udid> tools/perf/ios_bench.sh <experiment> <out>` (`docs/ARCHITECTURE.md`, "Device scenario"). The iPhone's Instruments traces were not kept.

## Tablet measurement (Release Perf, one run each, informational)

Low profile (the Android default), traced off, `dumpsys meminfo` every 15 s on (it causes the single 100+ ms frames behind the minimum FPS), battery 30.0–35.5 °C, thermal status 0. Experiments: `profile_default_kenney_town.json` (committed); for Safranbolu `{"experiment": "profile_default_safranbolu_test", "map": "safranbolu_test", "bench": {}}` on a **temporary measurement build**: the Safranbolu test import was written to `maps/safranbolu_test/` and registered only for that APK (not committed; removed afterwards, `game/world/maps.tres` restored byte for byte), because test imports are excluded from every export (T48).

| Map | Viewpoint | Average FPS | 1 % low | Minimum | Long frames | Draw calls | Primitives | Physics step (ms) |
|---|---|---|---|---|---|---|---|---|
| Kenney town | Spawn | 29.91 | 25.40 | 8.05 | 8 of 1,795 | 61 | 15,146 | 4.99 |
| | View A | 29.91 | 26.25 | 8.94 | 6 of 1,795 | 81 | 17,344 | 4.08 |
| | View B | 29.83 | 25.77 | 8.77 | 9 of 1,790 | 68 | 22,496 | 4.25 |
| | View C | 29.87 | 26.12 | 7.58 | 6 of 1,792 | 91 | 27,787 | 4.23 |
| Safranbolu | Spawn | 29.86 | 25.56 | 8.04 | 11 of 1,792 | 153 | 202,957 | 4.71 |
| | View A | 29.88 | 25.67 | 7.93 | 5 of 1,794 | 95 | 179,294 | 4.35 |
| | View B | 29.85 | 25.71 | 8.30 | 8 of 1,791 | 68 | 173,962 | 4.58 |
| | View C | 29.86 | 25.66 | 9.84 | 9 of 1,792 | 189 | 201,621 | 4.36 |
| | Sloped street | 29.84 | 23.48 | 8.99 | 22 of 1,791 | 143 | 208,331 | 6.38 |

| Map | Map ready | First frame | Peak PSS | APK |
|---|---|---|---|---|
| Kenney town | 2,186 ms | 2,320 ms | 265,775 kB (260 MiB) | 675,606,528 B (the committed tree) |
| Safranbolu | 3,562 ms | 4,083 ms | 336,133 kB (328 MiB) | 693,748,650 B (temporary build) |

For comparison (`docs/perf/default_map/`): the default shader map runs at 30.00–30.01 FPS with a 1 % low of about 25.2–25.9 (PSS sampling off), 615 MiB stable PSS, and 5.8 s to map ready on the same tablet.

## Default map unchanged on the Mac (`desktop/`)

The game started on the Mac (Metal, 960×540) with `{"profile": "low"|"high", "map": "istanbul_halic_cells_shader", "bench": {"warmup_s": 5, "measure_s": 6, "screenshots": false, "quit_when_done": true}}`, before the task (`69357a7`, runs `before1`, `before2`), after the category move (`after_categories`), and at the final code (`final_head`): the same draw calls, primitives, and objects at all three viewpoints and both profiles in every run (low 114 / 107 / 70 draw calls, 51,142 / 52,464 / 23,465 primitives; high 218 / 178 / 116, 135,639 / 101,720 / 59,619).

## Categories unchanged

`categories_before_and_after.tsv.gz`: every mesh of the five maps with its category (map id, node path, category; 21,458 lines), dumped from the old code at `cbaf661` (`RenderSettings.category_of`) and from the maps' rules at `e7e2c51`; both dumps have SHA-256 `2d6996e651f989f9f4f022d8da9de4a6d60ca7c20977430ea944708b43985ad6` uncompressed, so one file stands for both.

## Tool runs (Mac, Apple Silicon)

| Map | Run | Peak resident |
|---|---|---|
| Kenney town | 0.3 s | — |
| Safranbolu | 1.5–1.7 s | — |
| İstanbul • Haliç import | 9.0–9.4 s (2.5 s loading the GLB, 3.0 s face statistics) | 1.75 GB |
