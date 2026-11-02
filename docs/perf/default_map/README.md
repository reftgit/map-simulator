# The shader facade map as the default: evidence (2026-11-02)

For `PROJECT_STATE.md`, "The shader facade map is the default", and D25 (`PROJECT_CONTEXT.md`). Sections: the relative long-frame criterion on the tablet, the presented frame times (open question 43), the startup map on both devices, the device scenarios from the default map.

## Relative criterion on the Galaxy Tab A7 (D25, criterion 1 as updated on 2026-11-02)

The user made criterion 1 relative: on the tablet's low profile the shader map (`istanbul_halic_cells_shader`) must not be worse than İstanbul • Haliç measured with the same protocol: (a) at least 9 launches of each, alternating, three viewpoints per launch; (b) the shader map's bad launches (a viewpoint with more than 1 % long frames) at most one more than İstanbul's; (c) the median 1 % low per viewpoint at most 0.5 FPS below İstanbul's; (d) average FPS ≥ 29.9.

**Protocol:** Release Perf APK of `56aaf0d` (674,576,699 bytes; the game code at `17f1a78` is the same), the experiments `c_relative_shader` and `c_relative_istanbul` (low profile, the map, a traced benchmark: 30 s warm-up and 60 s measurement per viewpoint), PSS sampling off (`SAMPLE_PSS=0`), presented frames recorded beside every launch (below). Two unused warm-up launches (shader, İstanbul), then nine runs of shader → İstanbul, each launch cold, waiting until the battery was back at or below 32.0 °C (the temperature after the warm-ups + 0.5); thermal status 0 at every start and end. 2026-11-02, 00:01–02:06.

```sh
# per launch, beside each other (the driver loop alternated the two experiments)
python3 -I tools/perf/present_trace.py sample OUT/runN c_relative_shader &
COOL_MAX_C=32.0 SAMPLE_PSS=0 tools/perf/android_bench.sh tools/perf/experiments/c_relative_shader.json OUT/runN
python3 -I tools/perf/relative_check.py c_relative_shader c_relative_istanbul docs/perf/default_map/results/android/run{1,2,3,4,5,6,7,8,9}
```

| Run | Experiment | Map | Long frames per viewpoint (Spawn / Karaköy street, facing north / Galata street, facing south) | Bad launch | Battery start → end °C | Cool-down wait s |
|---|---|---|---|---|---|---|
| run1 | c_relative_shader | istanbul_halic_cells_shader | 3 (0.2 %) / 3 (0.2 %) / 4 (0.2 %) | no | 31.5 → 32.5 | 0 |
| run1 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 5 (0.3 %) / 6 (0.3 %) | no | 32.0 → 32.5 | 30 |
| run2 | c_relative_shader | istanbul_halic_cells_shader | 4 (0.2 %) / 4 (0.2 %) / 11 (0.6 %) | no | 32.0 → 33.0 | 90 |
| run2 | c_relative_istanbul | istanbul_halic | 72 (4.0 %) / 50 (2.8 %) / 130 (7.2 %) | **yes** | 32.0 → 33.5 | 60 |
| run3 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 2 (0.1 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run3 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 2 (0.1 %) / 7 (0.4 %) | no | 32.0 → 33.0 | 150 |
| run4 | c_relative_shader | istanbul_halic_cells_shader | 2 (0.1 %) / 1 (0.1 %) / 3 (0.2 %) | no | 32.0 → 33.0 | 90 |
| run4 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 5 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run5 | c_relative_shader | istanbul_halic_cells_shader | 4 (0.2 %) / 0 (0.0 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run5 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 3 (0.2 %) / 2 (0.1 %) | no | 32.0 → 33.0 | 150 |
| run6 | c_relative_shader | istanbul_halic_cells_shader | 5 (0.3 %) / 3 (0.2 %) / 3 (0.2 %) | no | 32.0 → 33.5 | 120 |
| run6 | c_relative_istanbul | istanbul_halic | 1 (0.1 %) / 0 (0.0 %) / 2 (0.1 %) | no | 32.0 → 32.5 | 120 |
| run7 | c_relative_shader | istanbul_halic_cells_shader | 46 (2.6 %) / 53 (2.9 %) / 105 (5.8 %) | **yes** | 32.0 → 33.5 | 90 |
| run7 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 0 (0.0 %) | no | 32.5 → 33.0 | 60 |
| run8 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 0 (0.0 %) / 4 (0.2 %) | no | 32.0 → 33.0 | 90 |
| run8 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 90 |
| run9 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 1 (0.1 %) / 1 (0.1 %) | no | 32.0 → 33.0 | 90 |
| run9 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 1 (0.1 %) / 5 (0.3 %) | no | 32.0 → 33.0 | 90 |

| Viewpoint | c_relative_shader: 1 % low median [launches] | c_relative_istanbul: 1 % low median [launches] | Difference | c_relative_shader: average FPS median (lowest) | c_relative_istanbul: average FPS median (lowest) |
|---|---|---|---|---|---|
| Spawn | 25.80 [25.83 / 25.64 / 25.75 / 25.80 / 26.18 / 25.42 / 23.66 / 25.80 / 26.24] | 25.77 [25.77 / 23.38 / 25.90 / 25.77 / 25.74 / 25.90 / 25.88 / 25.45 / 26.06] | +0.03 | 30.01 (30.00) | 30.01 (30.00) |
| Karaköy street, facing north | 25.89 [26.32 / 25.85 / 25.89 / 25.81 / 26.05 / 25.88 / 23.75 / 26.19 / 26.02] | 25.92 [25.71 / 23.50 / 26.12 / 25.78 / 26.11 / 26.14 / 25.92 / 25.83 / 26.23] | -0.03 | 30.01 (30.00) | 30.01 (30.00) |
| Galata street, facing south | 25.17 [25.23 / 24.64 / 25.17 / 25.13 / 25.20 / 25.09 / 22.68 / 25.26 / 25.20] | 24.98 [24.79 / 22.34 / 24.77 / 24.88 / 25.13 / 25.27 / 25.25 / 24.98 / 25.01] | +0.19 | 30.00 (29.99) | 30.01 (29.99) |

| Check | Result | Values |
|---|---|---|
| (a) at least 9 launches each | PASS | 9 and 9 |
| (b) bad launches at most one more than the reference's | PASS | 1 against 1 |
| (c) median 1 % low at most 0.5 FPS below the reference's at every viewpoint | PASS | +0.03, -0.03, +0.19 |
| (d) median average FPS at least 29.9 at every viewpoint | PASS | 30.01, 30.01, 30.00 |

Relative criterion: PASS

Both bad launches look like those of 2026-11-01 (`docs/perf/facade_v2/`): bad at all three viewpoints from the start, the average still 30.00, the 1 % low 22.3–23.8.

## Presented frame times (open question 43)

The benchmark's frame times are the game loop's (CPU side); a "long frame" there is a frame over 1.25 × the median. To see whether the 28 → 42 → 30 ms cycle of a bad launch reaches the screen, `tools/perf/present_trace.py` recorded what SurfaceFlinger presented on the game's surface during every launch above: `dumpsys SurfaceFlinger --latency "<layer>"` every 2 s (the layer keeps its last 127 frames; desired, actual present, and frame-ready times, CLOCK_MONOTONIC) and SurfaceFlinger's TimeStats for the whole launch, aligned with the measurement windows through the engine log read with `adb logcat -v monotonic` (the same clock). Nothing in the app or the device settings was changed. Not used: `dumpsys gfxinfo framestats` (HWUI views only, not a Vulkan surface), Swappy's statistics (need engine code), Perfetto's frame timeline (heavier, not needed).

At a 30 FPS cap on the 60 Hz panel every presented interval should be 2 refreshes (33.3 ms); a frame presented a refresh late shows as a 3-refresh (50 ms) interval, normally next to a 1-refresh (16.7 ms) one.

| Experiment | Viewpoints | Count | Game long frames (share of frames) | Present intervals of 1 refresh | Presented long, ≥3 (share of intervals) | Presented long away from polls (share) | Game long frames ≤150 ms after a poll |
|---|---|---|---|---|---|---|---|
| c_relative_istanbul | at most 1 % | 24 | 79 (0.18 %) | 1664 | 1670 (3.88 %) | 1323 of 37650 (3.51 %) | 6 of 80 |
| c_relative_istanbul | over 1 % long frames | 3 | 252 (4.66 %) | 87 | 86 (1.59 %) | 64 of 4720 (1.36 %) | 17 of 245 |
| c_relative_shader | at most 1 % | 21 | 68 (0.18 %) | 1114 | 1120 (2.97 %) | 847 of 32990 (2.57 %) | 1 of 67 |

- **The bad launches' cycle does not reach the screen.** In İstanbul's bad launch (run 2) the game counted 4.66 % long frames, while only 1.36 % of the presented intervals were 50 ms, fewer than in the good launches. Frame by frame, a 1.2 s stretch at Galata: the game's frame times `34, 44, 26, 28, 44, 22, 40, 27, 38, 32, 39, 24, 44, 23, 40, 29, 46, 18, …` against presented intervals `33, 33, 33, 33, 34, 34, 33, 33, 17, 50, 33, 33, …`: the swap chain absorbs the loop's jitter. (The shader map's bad launch, run 7, and its good launch of run 8 have no presented trace for the measurement windows: the sampler stopped after 20 and 40 s on a single empty `pidof` answer; fixed afterwards, it now needs three in a row. Where the streamed monotonic log lost lines, as `adb logcat` streams do after an adb hiccup, the summary takes the BENCH times from the bench's own log, shifted by the offset of lines both logs hold; checked against a complete stream: within 1 ms.)
- **Every launch has its own 17 / 50 ms pairs on the screen:** 2.6 % (shader) and 3.5 % (İstanbul) of the presented intervals in the good launches, about one pair per second, while the game counted 0.2 % long frames there. The frames before such a pair were queued on the usual cadence (queue interval median 33.6 ms against 33.3) and finished by the GPU on time (frame-ready interval median 31–32 ms); only the time from frame-ready to present grew (median 22.6 against 16.9 ms). So they come from the hand-over to the display, not from the game's CPU or GPU time. The TimeStats histograms of whole launches agree (50 ms: 3.0 % shader, 3.8 % İstanbul).
- **The polling's own effect:** a `dumpsys SurfaceFlinger` call now and then delays the next composition (in the first warm-up 71 of 253 late presents fell within 250 ms after a poll, against about 24 per 250 ms elsewhere), so the table counts the intervals starting 250 ms or more after a poll as the undisturbed sample. It does not touch the game loop: of 392 long game frames, 24 ended within 150 ms after a poll, about the 7 % those stretches cover.
- **Consequence:** the benchmark's long-frame count on the tablet measures the game loop, not what the player sees; the per-launch pacing state is not visible, while the 17 / 50 ms pairs of every launch are (open question 43).

## Startup map (D25 step C)

Builds of `b80c205` (the default change), installed over the previous ones, each launched without arguments and without an experiment file: Android with `tools/perf/android_startup_log.sh`, iOS with `tools/perf/ios_startup_log.sh` (an Instruments "Logging" recording around the launch; the engine's os_log lines reach it, unlike the captures of Phases 4c–4d). The extracted lines are in `startup/`; the raw iOS os_log tables (every process on the phone) stay out of the repository.

| Build | `STARTUP` line (excerpt) |
|---|---|
| Android Debug (APK 676,391,706 bytes) | `map=istanbul_halic_cells_shader profile=low`, `"debug_build":true`, `experiment=none`, map ready 8,641 ms |
| Android Release Perf (674,576,699 bytes) | `map=istanbul_halic_cells_shader profile=low`, `"debug_build":false,"perf_feature":true`, map ready 7,279 ms |
| iOS Debug (`.pck` 648,570,500 bytes) | `map=istanbul_halic_cells_shader profile=high`, `"debug_build":true`, map ready 1,399 ms |
| iOS Release Perf (`.pck` 648,570,548 bytes) | `map=istanbul_halic_cells_shader profile=high`, `"debug_build":false,"perf_feature":true`, map ready 1,201 ms |

A clean clone of `b80c205` on the Mac (headless, the editor binary, i.e. a debug build): without any GLB `WARNING: Default map 'istanbul_halic_cells_shader' is not available (missing: res://assets/istanbul_halic_cells_shader.glb); loading 'test_district'` and `STARTUP … map=test_district`; with only İstanbul's GLB the same warning ending `loading 'istanbul_halic'` and `STARTUP … map=istanbul_halic`; with the shader GLB added (import 8.7 s) `STARTUP … map=istanbul_halic_cells_shader` and no warning. The clone's test suite: without any GLB `RESULT 213 passed, 0 failed, 66 skipped` (exit 2; `-- unit` 195 passed, exit 0), with only İstanbul's GLB `RESULT 247 passed, 0 failed, 32 skipped` (exit 2).

## Device scenarios from the default map

The debug builds above, the unpinned experiments `scenario_vehicle_sleep` and `scenario_extensibility` (no `"map"` key, so they start on the default map; `results.startup.map` and the logs say `istanbul_halic_cells_shader`). Commands as in `docs/ARCHITECTURE.md`, "Device scenario" (`android_bench.sh` with `SAMPLE_PSS=0` and `pss_trace.py sample` beside `extensibility`; `ios_bench.sh`).

| Device | `vehicle_sleep` | `extensibility` | Notes |
|---|---|---|---|
| Galaxy Tab A7 | 13 / 13 PASS | 25 / 25 PASS | MAP from the shader map through İstanbul (9.0 s) to the test district (0.5 s), back through the cells map (8.4 s) and the light map (7.6 s) to the shader map (6.6 s), node count 8,549 before and after; PSS peak 810 MiB (debug build, as on 2026-11-01), the low-memory killer's 44 lines all about other apps' processes |
| iPhone 13 Pro | 13 / 13 PASS | 25 / 25 PASS | to the test district in 2.6 s, back in 5.9 s; footprint peak 875 MiB (`vehicle_sleep`) and 639 MiB (`extensibility`, 45 s probes); thermal state Nominal throughout |

The tablet's log shows İstanbul loaded by the MAP button in the exported build, so its new `required_files` entry counts as available there (the import result is in the package).

## Files

| Path | Contents |
|---|---|
| `results/android/runN/` | Per launch: `<experiment>.json.gz` (results with the traces), `.meta.json` (battery, thermal status, cool-down wait), `.log` (engine log), `.mono.log` (engine log with CLOCK_MONOTONIC), `.present.tsv.gz` (presented frames), `.present.json` (layer, refresh, polls), `.timestats.txt.gz` |
| `relative_table.md`, `present_summary.md` | The output of `relative_check.py` and `present_trace.py summary` for runs 1–9 |
| `startup/` | The `STARTUP` and `QUALITY` lines of the four plain launches; the Android engine logs |
| `scenarios/tablet/`, `scenarios/iphone/` | Scenario results and logs; the tablet's `extensibility` PSS trace (gzipped) and low-memory killer lines |
