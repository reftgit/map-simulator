# Phase 6c evidence (2026-11-03/04)

Streaming loader for any map (`PROJECT_STATE.md`, "Phase 6c"; design: `docs/STREAMING.md`). Raw files below; tables in `PROJECT_STATE.md`. Large result files are gzipped (`gunzip -k`).

| Folder | Contents |
|---|---|
| `look/` | Streaming on and off side by side (`tools/capture_streaming.gd`, Mac, Metal, 960×540): every streamed map, low and high profile, the spawn and each debug viewpoint; per sheet streamed \| whole \| difference ×8; `look.txt` the pixel counts |
| `desktop/` | Mac benchmarks of the two cell sizes (`cs_*`: the three viewpoints, `csr_*`: the driving route; low and high), the crash and occlusion probes (`probes.md`), the cell step's output for every map (`cells.txt`), every streamed map on and off (`allmaps/am_<map>_<profile>_<streaming>.json`: results of experiments `{"profile", "map", "runtime": {"streaming"}, "bench": {"warmup_s": 5, "measure_s": 3, "screenshots": false}}`, one launch each) |
| `tablet/memory/` | Galaxy Tab A7, Release Perf B: three launches each of the default map streamed (50 m and 100 m cells) and whole, dense PSS traces (`pss_trace.jsonl`; `python3 -I tools/perf/pss_trace.py stable <folder>`) |
| `tablet/routes_C/`, `routes_D/`, `routes_E/`, `routes_F/` | Release Perf C, D, E, F: the 515 m route walked and driven both ways, traced (`tools/perf/streaming_summary.py`), with presented frames (`*.present.tsv`, `*.mono.log`) on the drives and on C and D's walks; `routes_D/off1/` the map loaded whole |
| `tablet/frames/run1/` | Release Perf F: the one pair of the relative criterion (streamed and whole, three viewpoints, traced) |
| `tablet/safranbolu/` | A temporary Release Perf F build with the Safranbolu test import: streamed and whole, dense PSS traces |
| `tablet/debug/` | Debug F: `switch/` (six map switches, dense PSS trace, `lmkd.txt`), `scenarios/` (`vehicle_sleep`, `extensibility`, both also on the Kenney town) |
| `iphone/` | iPhone 13 Pro, Release Perf B, D, F: three runs each of the default map streamed and whole, the routes (high profile); every streamed map on and off (`F/allmaps/`); debug C: the scenarios |

## Builds

| Build | Code | Used for |
|---|---|---|
| A (2026-11-03 23:26, discarded) | commit 4 plus the route benchmark | a first iPhone set and a first tablet memory set; superseded when the index check was made faster (B) |
| B (2026-11-04 02:19) | commit 4 plus commit 5's index check and route benchmark, without the overlay guard | iPhone Release Perf (`iphone/B/`), tablet memory (`tablet/memory/`) |
| C (2026-11-04 12:40; iOS debug 07:04) | B plus the overlay guard | tablet routes (`routes_C/`); iOS debug: the iPhone scenarios |
| D (2026-11-04 18:12) | C plus `prepare_streamed_materials()` (materials set at load) | tablet routes (`routes_D/`), iPhone Release Perf (`iphone/D/`) |
| E (2026-11-04 18:42) | D plus warm cells | tablet walking route (`routes_E/`) |
| F (2026-11-04 18:49 Release Perf, 19:49 debug) | E plus one request in flight: the committed code (the only later change is the `max_requests` doc comment) | tablet routes (`routes_F/`), the relative pair, Safranbolu, the switch and scenarios (debug); iPhone Release Perf (`iphone/F/`) |

Builds F: Release Perf APK 1,450,872,615 B, debug APK 1,452,687,622 B, iOS `.pck` 1,423,246,812 B (Release Perf); iOS debug C 1,423,245,980 B: every map with its streaming files (the 100 m split of the default map included, for the comparison). iOS builds without `-allowProvisioningUpdates`.

## Galaxy Tab A7 power

Connected to the Mac's USB port the tablet draws more than the port gives under the measured load (about 1.1 A against 250–350 mA), so its battery drains during a session; it reached 0 % in the first session (stopped), and the last session ended at 6 %. Map ready and long frames vary with it (`PROJECT_CONTEXT.md`, open question 51); the PSS does not.
