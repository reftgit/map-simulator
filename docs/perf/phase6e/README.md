# Phase 6e evidence (2026-11-05)

Maps loaded on threads behind a moving loading screen, the release filter written from the release registry (`PROJECT_STATE.md`, "Phase 6e"; design: `docs/STREAMING.md`, "Loading a map"). "Threaded" is the new path; "at once" is the same build with `"runtime": {"threaded_load": false}`, the load on the main thread as before Phase 6e. Every loading screen prints `LOADING` (summary), `LOADING_STEPS`, `LOADING_LOAD`, and `LOADING_FRAMES`; perf builds also keep each frame's detail (steps, render CPU and GPU times, pipeline compilations, when physics and drawing started) in the results' `startup.loading`. At the start the first two frames are the boot splash's (`boot_ms`) and are not counted in `longest_ms`.

| Folder | Contents |
|---|---|
| `desktop/crash/` | The Phase 6c worker-thread crash found again: four variants of the old threaded prime, 20–40 launches each, the patches, a backtrace, the reading of Godot's source (README) |
| `desktop/start/` | Mac (Apple M5, Metal, the editor binary: a debug build), `e_load_start_low` 20 launches threaded (`t1`…`t20`) and `e_load_start_low_at_once` 10 (`a1`…`a10`), alternating for the first 20; the game's log of each (home folder shown as `~`) |
| `desktop/switch/` | Mac, `scenario_map_switch_load` and `…_at_once` (four switches between the default map, İstanbul • Haliç, and the cells map; the platform default profile, "none" on the desktop), with the process's RSS every 0.1 s (`*.rss.tsv`) |
| `iphone/start/run1…3/` | iPhone 13 Pro, Release Perf build of the final code, `e_load_start_high` and `…_at_once` alternating, three pairs: results (with `startup.loading`), meta (footprint, thermal state) |
| `iphone/release/run1…3/` | the iOS release build, three plain launches under an Instruments "Logging" recording (`tools/perf/ios_startup_log.sh`): the `QUALITY`, `STREAMING`, and `LOADING` lines |
| `iphone/switch/` | the debug build of the final code, `scenario_map_switch_load` and `…_at_once`: each switch's step with its loading screen's summary |
| `iphone/scenarios/` | the debug build of the final code: `vehicle_sleep`, `extensibility`, and both on the Kenney town |
| `release/` | the two release packages of the final code: `android_contents.txt`, `ios_contents.txt` (`tools/release_contents.py --expect`), `expected_project_files.txt.gz` (the same list for both), `expected_files_vs_6d.diff` (three new scripts), `android_apk_listing.txt.gz`, `android_build_lines.txt` |
| `tablet/intermediate/` | Galaxy Tab A7, Release Perf builds made while the code was written (not the final code), battery 15–18 % and draining (README) |
| `tablet/power.md` | what the tablet's supply reported this session |
| `tests/test_runs.txt` | the test runs of every Phase 6e commit, in this checkout and in clean clones |

## Builds

| Build | Code | Used for |
|---|---|---|
| Mac editor (debug) | the tree of `a432870` (`desktop/start/`), of `4e101fb` (`desktop/switch/`) | desktop |
| iOS Release Perf | the tree of `a432870` before its last change (an at-once switch's record timed from the load; a start does not run it) | `iphone/start/` |
| iOS release | the same tree (`iphone/release/`); rebuilt from `4e101fb` for the sizes in `release/` | |
| iOS debug | the tree of `4e101fb` | `iphone/switch/`, `iphone/scenarios/` |
| Android release | `4e101fb` | `release/` (not installed: the tablet was off) |
| Android Release Perf (intermediate) | between `1521209` and `23b4dbd` | `tablet/intermediate/` |

`4e101fb` differs from `a432870` only in `WorldManager.unload_map_and_wait()` (the old map freed a part per frame), which a start does not run. All iOS builds without `-allowProvisioningUpdates`; Android signed with the editor's debug keystore.
