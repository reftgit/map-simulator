# Phase 6d evidence (2026-11-05)

Release presets with only the default map (`PROJECT_STATE.md`, "Phase 6d"; how to build: `docs/ARCHITECTURE.md`, "Release builds"). Large files are gzipped (`gunzip -k`).

| Folder | Contents |
|---|---|
| `release/` | The two release packages: `android_contents.txt`, `ios_contents.txt` (`tools/release_contents.py --expect`: sizes per folder and the comparison with the expected files), `expected_project_files.txt.gz` (`tools/check_release.gd --list`, the same for both presets), the full listings (`android_apk_listing.txt.gz`: `unzip -l`; `ios_pck_listing.txt.gz`: every path of the `.pck` with its size), `android_permissions.txt` and `android_badging.txt` (`aapt dump`), `build_logs_excerpt.txt` (the check, signing, and install lines of `tools/build_release.sh`) |
| `tablet/release/run1…3/` | Galaxy Tab A7, the Android release APK, three plain launches (no experiment): the game's log lines (`godot.log`; release builds print `QUALITY` and `STREAMING`), the activity manager's lines for the app (`activity.log`: process start, first display), `meminfo.txt` at 60 s, the dense PSS trace (`pss_trace.jsonl.gz`; `python3 -I tools/perf/pss_trace.py stable <folder>`), the battery at the start, the low-memory killer's lines (none), a screenshot at 60 s |
| `tablet/power/check1.tsv` | The 10-minute battery check before the planned repeat: the release build running at the spawn (low profile), the battery read every 30 s (level, status, charge current, temperature, the maximum charge current the tablet reports, the power source, the window in front) |
| `tablet/phase6c_routes_timeline.md` | The Phase 6c route traces read again with `streaming_summary.py --timeline` (no new runs): every frame over 50 ms with its GPU and render CPU times, the nearest attach, and the pipelines compiled next to it |
| `tests/test_runs.txt` | The test runs of every Phase 6d commit: in this checkout, in clean clones without GLBs or cells, and in a clone with only the default map's cells (no GLB), with the release check's message |
| `iphone/release/` | iPhone 13 Pro, the iOS release app: `startup_log.txt` (a plain launch under an Instruments "Logging" recording, `tools/perf/ios_startup_log.sh`), three plain launches with a screenshot at 25 s (`screen_*.jpg`) and a 3 s "Activity Monitor" probe (`am_*.json`: footprint, thermal state) |
| `iphone/scenarios/` | The debug build of `c202e4f`: `vehicle_sleep` and `extensibility` on the default map and on the Kenney town (results files of `tools/perf/ios_bench.sh`) |
| `iphone/galata/run1…3/` | The Release Perf build of `c202e4f`: the default map streamed and whole (`c_streaming_shader_high`, `…_off`), alternating, three viewpoints, high profile, traced (frame, GPU, and render CPU times; cell attaches, requests, and frees; pipeline compilations); results gzipped, `*.meta.json` (footprint, thermal), `timeline.md` (`streaming_summary.py --timeline --over 20`) |

## Builds

| Build | Code | Used for |
|---|---|---|
| Android Release (2026-11-05 07:19) | the tree of `dd8f785`, built just before it was committed (its game code is `cc16d76`'s) | `release/`, `tablet/release/`, `tablet/power/` |
| iOS Release (2026-11-05 07:19) | the same | `release/`, `iphone/release/` |
| iOS Debug G (2026-11-05) | `c202e4f` | `iphone/scenarios/` |
| iOS Release Perf G (2026-11-05) | `c202e4f` | `iphone/galata/` |

All iOS builds without `-allowProvisioningUpdates`; Android signed with the editor's debug keystore. No Android measurement build was made: the tablet's repeat was not run.

## Galaxy Tab A7 power

On the user's powered hub the tablet reported "AC powered" with a maximum charge current of 250–350 mA, as on the Mac's port in Phase 6c; with the game running its battery fell from 57 to 53 % in ten minutes at −0.67 to −0.91 A (`tablet/power/check1.tsv`). The task allowed the tablet's repeat only with a battery that holds, and the user chose NOT RUN. The batch scripts used `svc power stayon true` (the hub shows as AC, so `stayon usb` would not hold the screen), restored to `false` afterwards.
