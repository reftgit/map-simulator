# Shader facade toward the default: evidence (2026-11-01)

For `PROJECT_STATE.md`, "Shader facade toward the default", and the criteria of D25 (`PROJECT_CONTEXT.md`). Sections: the distant windows (for the user's visual approval), the long-frame diagnosis on the tablet, the device measurements, the map switches.

Follow-up (2026-11-02): the visual approval was given through the reviewer, criterion 1 was made relative and passed, and the shader map became the default: `docs/perf/default_map/`.

## Distant windows

For the user's visual approval (D25, criterion 5). The shader facade map (`istanbul_halic_cells_shader`) draws its windows with `maps/istanbul_halic_cells_shader/facade_windows.gdshader`; this task replaced the shader's distance fade with a filter over each pixel's footprint. Three columns, the same camera positions:

| Column | What |
|---|---|
| cells (full facade) | `istanbul_halic_cells`: windows, cornices, and string courses as geometry (T40) |
| shader, first version | the shader of `83c8f0a`: past 0.35–0.9 m of wall per pixel the pattern faded to its average colour |
| shader, footprint filter | this task's shader: each element (surround, glass, mullion, cornice, string course) is box-filtered over the pixel's footprint on the wall, the exact share of the pixel it covers, from the integral of its periodic pattern; a window keeps its full contrast while it is a pixel or more wide and blends into the wall only as it gets smaller |

Views: the raised view over Karaköy (about 70 m up, buildings 100–250 m away), `far_bridge` (eye height on the Galata Bridge, the Karaköy waterfront 100–200 m away), `far_avenue` (eye height on the quay avenue, buildings 50–250 m away up the Galata hillside); `street_eminonu` (a near street) for the low profile. Captured on the Mac (Metal, Forward Mobile, debug build) with `tools/capture_views.gd` at 960×540, the resolution of the first comparison (`docs/perf/facade/`).

- `far_windows_high.jpg`: 2× crops (nearest neighbour) of the distant buildings, high profile (200 m ranges): two parts of the raised view, `far_bridge`, `far_avenue`.
- `views_high.jpg`, `views_low.jpg`: the whole frames, high and low profile.
- `pan_raised.gif`, `pan_far_avenue.gif`: the camera turning 0.06° per frame (about half a pixel) for 40 frames, 1:1 crops side by side (cells, first version, footprint filter), for checking shimmering in motion.

### Differences seen

- **High profile, 960×540:** the first version flattens the windows of buildings about 120 m and farther to a plain wall colour (the big building in the raised view, the far buildings of `far_avenue`); the footprint filter keeps their windows, and the three columns look alike up to the 200 m visibility range (beyond it no variant draws facade detail). In `far_bridge` (buildings within about 150 m) the three look alike.
- **At 1920×1080** (closer to the iPhone's 2532×1170) the first version's fade starts about twice as far away; old and new look alike there, and both like the cells map (`far_windows_high_1920.jpg`: 2× crops of the raised view and `far_avenue`).
- **Low profile:** within its 100 m ranges the windows are a few pixels or more wide, where both shader versions draw the same; beyond 100 m no variant draws facade detail.
- No new artefacts: no moiré, no seams at the column or storey edges in the shots.

### Shimmering in motion

`tools/perf/pan_flicker.py` on the pan frames (luminance 0–255, over the crop and the 40 frames): the change per frame, the temporal second difference (large when pixels flip between window and wall and back), and their ratio (lower is steadier for the detail shown).

| View | Variant | Change per frame | Second difference | Ratio |
|---|---|---|---|---|
| raised | cells | 3.40 | 5.01 | 1.47 |
| raised | first version | 2.21 | 2.97 | 1.34 |
| raised | footprint filter | 2.90 | 3.71 | **1.28** |
| far_avenue | cells | 3.04 | 4.42 | 1.46 |
| far_avenue | first version | 2.38 | 3.32 | 1.39 |
| far_avenue | footprint filter | 2.75 | 3.68 | **1.34** |
| far_bridge | cells | 3.36 | 5.07 | 1.51 |
| far_bridge | first version | 3.15 | 4.60 | 1.46 |
| far_bridge | footprint filter | 3.36 | 4.84 | **1.44** |

The footprint filter shows more detail than the first version (change per frame closer to the cells map's) and the lowest ratio of the three in every view: it shimmers less than the geometry and no more than the first version. The numbers include the buildings' own aliased edges (no MSAA on the Mobile renderer), which all three share.

### Reproducing

```bash
git show 83c8f0a:maps/istanbul_halic_cells_shader/facade_windows.gdshader > /tmp/facade_windows_first.gdshader
for map in istanbul_halic_cells istanbul_halic_cells_shader; do
  godot --path . --resolution 960x540 --script res://tools/capture_views.gd -- --map=$map --quality=high \
    --views=raised,far_bridge,far_avenue --pan=40 --pan-step=0.06 --out=/abs/dir/$map
done
godot --path . --resolution 960x540 --script res://tools/capture_views.gd -- --map=istanbul_halic_cells_shader --quality=high \
  --views=raised,far_bridge,far_avenue --pan=40 --pan-step=0.06 --facade-shader=/tmp/facade_windows_first.gdshader --out=/abs/dir/first
<VENV>/bin/python -I tools/perf/pan_flicker.py far_avenue 380,160,780,330 pan_far_avenue.gif \
  cells=/abs/dir/istanbul_halic_cells/istanbul_halic_cells_high_far_avenue \
  old=/abs/dir/first/istanbul_halic_cells_shader_high_far_avenue new=/abs/dir/istanbul_halic_cells_shader/istanbul_halic_cells_shader_high_far_avenue
```

`<VENV>` is the generator's pinned environment (Pillow, numpy; `docs/maps/istanbul_halic/README.md`). Crops: raised `400,200,700,380`, `far_avenue` `380,160,780,330`, `far_bridge` `0,150,400,330`.

## Long frames on the tablet: diagnosis (2026-11-01)

The shader map's earlier sets each had one run with long-frame windows on the Galaxy Tab A7 (low profile; up to 4.4 % at Galata, `docs/perf/facade/`). This A/B looked for the cause: Release Perf build of `4242efe`, three runs of six experiments (the order rotated per run, after two unused warm-up runs), every one with `"trace": true` (warm-up sampled, every frame's time kept, GPU time, pipeline compilations), all on the low profile:

| Experiment | What differs |
|---|---|
| `c_stutter_shader` | the shader map as it is (the window shader of `83c8f0a`) |
| `c_stutter_flat` | the same panels with the GLB material, i.e. the wall colour (`facade_material: flat`) |
| `c_stutter_simple` | the panels with `facade_windows_simple.gdshader`: hard edges, no mullion, no distant fade (`facade_material: simple`) |
| `c_stutter_warmup` | a facade cell drawn at 1 cm in front of the camera for three frames after loading (`facade_warmup`) |
| `c_stutter_priority` | the window shader at render priority −1, so the panels are drawn before the walls behind them (`facade_priority`) |
| `c_stutter_cells` | the cells map (the full facade as geometry), for reference |

`results/android_ab/`: `ab_table.md` (below), `trace_summary.md` (`tools/perf/trace_summary.py`: long frames per 10 s, streaks, how many sit next to a short frame, GPU time, pipelines; it recomputes the long frames from the rounded trace, so a few counts differ from the results' `long_frames`), the three runs' results (`.json.gz`, with the traces) and conditions (`.meta.json`; battery 30.5–33.5 °C, thermal status 0 throughout).

| Experiment | Launches with a viewpoint over 1 % long frames | Long frames per viewpoint (Spawn / Karaköy / Galata; run 1, 2, 3) | 1 % low median (S / K / G) | Avg FPS median | Pipelines in the measurement |
|---|---|---|---|---|---|
| c_stutter_cells | 1 of 3 (run1) | 206,0,4 / 79,1,2 / 152,3,4 | 25.51 / 26.02 / 25.35 | 30.01 / 30.00 / 30.01 | 0 |
| c_stutter_flat | 1 of 3 (run3) | 1,1,94 / 4,3,81 / 2,3,120 | 25.85 / 25.83 / 25.50 | 30.01 / 30.01 / 30.00 | 0 |
| c_stutter_priority | 1 of 3 (run1) | 219,3,4 / 131,2,7 / 118,1,3 | 25.83 / 26.06 / 25.08 | 30.00 / 30.00 / 30.01 | 0 |
| c_stutter_shader | 0 of 3 (-) | 4,4,1 / 4,3,2 / 0,5,3 | 25.85 / 26.22 / 25.02 | 30.01 / 30.01 / 30.00 | 0 |
| c_stutter_simple | 0 of 3 (-) | 5,5,1 / 1,3,3 / 4,6,9 | 25.93 / 26.32 / 24.90 | 30.00 / 30.01 / 30.00 | 0 |
| c_stutter_warmup | 1 of 3 (run2) | 1,74,2 / 0,61,3 / 5,120,5 | 25.93 / 26.49 / 25.13 | 30.01 / 30.01 / 30.00 | 0 |

### Findings

- **Not the window shader.** Four of the 18 launches had a viewpoint over 1 % long frames: `cells` (run 1), `priority` (run 1), `warmup` (run 2), and `flat` (run 3), which draws no window shader at all; `shader` and `simple` had none. A bad launch was bad at all three viewpoints and already in the first warm-up (61–219 long frames per viewpoint in the measurement), a good one had 0–9 per viewpoint.
- **Pacing jitter, not a slowdown.** In the bad launches 91–100 % of the long frames sit right before or after a short one: the frame times cycle about 28 → 42 → 30 ms, the average stays 30.00 FPS, and the 1 % low drops to 22.5–23.7. The pattern starts with the launch (or, in the earlier sets, after a viewpoint change) and lasts until the app is closed; it does not follow the scene. Phase 4a saw the same on İstanbul (`PROJECT_STATE.md`, "Frame pacing": one run with 7–12 % frames of 50 ms, cause not identified).
- **Where the long frames fall otherwise:** at the first viewpoint of every launch the first three frames take 240–300 ms (4 canvas and 5–6 specialization pipelines compiled, in every variant, the cells map included); after each viewpoint change the first frames take 67–88 ms (2–3 specialization pipelines at Karaköy); the simple shader's first use after installing took 753 ms once (its pipelines were then cached for the later runs). All of this falls in the 30 s warm-up. Inside the measurements no pipeline was compiled in any run.
- **The warm-up draw changes nothing** (the first frames still take 241–264 ms; one more specialization pipeline is compiled earlier), and the render priority changes nothing measurable.
- **GPU time is no help on this device:** `viewport_get_measured_render_time_gpu` stays at 24.4–26.4 ms in every experiment and viewpoint (flat, simple, shader, and cells alike) and changes only every few seconds; with the driver scaling the GPU clock to the load it cannot show how much a variant costs.
- **A tested mechanism that is not it:** with the 30 FPS cap Godot 4.7.2 paces twice, with its CPU frame limiter (`OS::add_frame_delay`, 33,333 µs per frame) and with Swappy, which gets the same cap as a swap interval of two refreshes (`RenderingDeviceDriverVulkan::swap_chain_set_max_fps`). If the two drifting apart were the cause, a 31 FPS cap (the CPU limiter at 32.26 ms, never longer than Swappy's two refreshes; Swappy still paces at 30) should remove the jitter. It did not: `c_stutter_cap31` (in the device measurements below, three runs) averaged 30.00–30.01 FPS and had 8 / 3 / 0, 18 / 4 / 79, and 2 / 2 / 4 long frames (Spawn / Karaköy / Galata), the 79 again a pacing pattern (98 % next to a short frame).
- **Conclusion:** the long-frame windows are a per-launch pacing state of the Galaxy Tab A7 at the 30 FPS cap (Swappy, the display, or the system; not separated further), not a cost of the shader map. The shader needs no fix for them; no change was made. A fix belongs to the frame pacing of the low profile, which this task does not change (`PROJECT_CONTEXT.md`, open question 43).

## Device measurements (Release Perf builds of `56aaf0d`, three runs, medians)

Protocol as before (D17): cold start per experiment, 30 s warm-up and 60 s per viewpoint, the two NPCs in the far mode, the order rotated per run, the shader map and İstanbul in the same session, after two unused warm-up runs. Tablet without PSS sampling (battery 32.5–33.0 °C, thermal status 0, no cool-down waits), then one launch per map with a dense PSS trace (`tools/perf/pss_trace.py`, every 0.2–0.6 s); iPhone with the thermal and footprint probes of `ios_bench.sh` (Nominal at every probe). Every result has `debug_build: false`, `perf_feature: true`, and the expected map. Raw data: `results/android/`, `results/ios/`; frames: `device_frames.jpg` (run 1).

| Galaxy Tab A7 low | Shader map: Spawn / Karaköy / Galata | İstanbul |
|---|---|---|
| Average FPS (median) | 30.00 / 30.00 / 29.98 | 30.00 / 30.00 / 30.00 |
| 1 % low (median [runs]) | 25.60 [26.14 / 25.60 / 23.60] / 25.95 [26.27 / 25.95 / 24.05] / 24.87 [25.39 / 24.87 / 22.51] | 26.06 [23.26 / 26.07 / 26.06] / 26.01 [23.35 / 26.05 / 26.01] / 25.11 [22.40 / 25.29 / 25.11] |
| Long frames per run (of 1,800) | 0, 2, **46** / 3, 3, 13 / 2, 2, **107** | **200**, 0, 3 / **117**, 4, 1 / **138**, 3, 7 |
| Map ready (median of three) | 5,822 ms | 6,596 ms |
| PSS, dense trace: peak / stable | 641 / 615 MiB | 568 / 502 MiB (127 MiB more in swap) |
| Video memory reported by the engine | 262 MiB | 482 MiB |

The 150 m / no-fog experiment on the shader map (information only): 1 % low 26.23 / 26.04 / 24.87, at most 5 long frames per viewpoint and run.

| iPhone 13 Pro high | Shader map: Spawn / Karaköy / Galata | İstanbul |
|---|---|---|
| Average FPS (median) | 60.00 / 60.00 / 60.00 | 60.00 / 60.00 / 60.00 |
| 1 % low (median) | 57.91 / 56.93 / 56.03 | 55.21 / 57.02 / 56.03 |
| Long frames | 0 in every run | 0 in every run |
| Footprint (three runs) | 854–859 MiB | 997–1,005 MiB |
| Map ready (median) | 1,194 ms | 1,379 ms |
| 10 minutes at Karaköy | 59.96–60.00 FPS every minute, at most 1 long frame per minute, Nominal at all 14 probes, footprint 860 MiB | — |

## Map switches on the tablet (debug build of `56aaf0d`)

`scenario_map_switch`: shader → İstanbul → cells → İstanbul → shader → cells → shader, 20 s on each map, with a PSS trace every 0.23 s on average (`scenarios/tablet/scenario_map_switch/`, `summary.md`). All six switches passed (map loaded, player at its spawn, node count as on the first visit: 8,549 on the cells maps, 5,475 on İstanbul), and the app was not killed; the low-memory killer reclaimed other apps' processes (29 lines, at the app's start and during switches 1 and 5, none of this app).

| Switch | Took | Peak PSS | Larger map's stable PSS + 50 | Lowest PSS between the maps |
|---|---|---|---|---|
| shader → İstanbul | 9.3 s | 671 MiB (before the free) | 723 | 420 |
| İstanbul → cells | 9.5 s | 729 | 746 | 402 |
| cells → İstanbul | 7.8 s | 692 (before the free) | 746 | 406 |
| İstanbul → shader | 6.8 s | 703 | 723 | 420 |
| shader → cells | 9.5 s | **810** | 746 | 403 |
| cells → shader | 7.3 s | 705 | 746 | 411 |

- Stable PSS in this debug build: shader 661–673, cells 693–696, İstanbul 584–585 MiB.
- Every switch first drops to 402–420 MiB (the old map freed), then rises while the next map loads to a peak about 15–115 MiB above that map's stable PSS, and falls back once the load ends: the loader's temporary data. The peak depends on how much the system swaps meanwhile (the swap PSS rose by up to 130 MiB in some loads and not at all in the shader → cells load); PSS plus swap PSS peaked at 852–1,024 MiB.
- Before this task (Phase 5 code, `docs/perf/facade/scenarios/tablet/`): peaks of 821 and 978 MiB with both maps in memory, and the app killed twice.
- `extensibility` on the shader map (debug): 25 / 25 on the tablet (peak PSS 809 MiB, 17 reclaim lines of other apps, none of this app) and on the iPhone (via `ios_bench.sh`, peak footprint 672 MiB at its probes); `vehicle_sleep` 13 / 13 on both.
