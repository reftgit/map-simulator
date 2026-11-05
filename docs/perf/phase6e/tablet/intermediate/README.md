# Galaxy Tab A7, intermediate builds (2026-11-05, not the final code)

Release Perf builds made while the threaded loading was being written, measured on the tablet over USB on the Mac's port (it reports "AC powered" with a maximum charge current of 250–300 mA and drained at −0.73 to −1.06 A), battery 18 → 15 %, 36.5–37.5 °C. One experiment per launch: the default map, low profile, the spawn, 2 s windows (`stage_tab.json`, `stage_tab_sync.json`); the results files carry the loading screen's record (`startup.loading`, with every frame's detail), `godot_lines.log` the game's log lines. The tablet's battery reached 0 % afterwards and it switched off; the final code was not run on it (`PROJECT_STATE.md`, "Phase 6e").

| Folder | Build | What differs from the final code |
|---|---|---|
| `tab_stage1…3` | threaded, steps over frames | 12 ms of service per reading frame (final: 25), the frame cap of the profile during the later steps (final: none until the map is shown), 30 ms as a fast frame (final: 45), the streamer's set-up sharing a frame with the first warm cell (final: a frame of its own) |
| `tab_stageb1…3` | threaded, steps over frames | the warm cells requested on threads and checked once per frame (final: loaded on the main thread, one per step, after the same build took three frames per cell on the iPhone) |
| `tab_sync1…2` | `"threaded_load": false` | the load at once on the main thread, as before Phase 6e (the same build as `tab_stage`) |

The first launch after installing (`tab_stage1`, `tab_stageb1`) builds its shaders and took 9.7–10.1 s to the map.

| Launch | Map ready | Longest frame (its steps) | Frames over 100 ms | Battery, current at the start |
|---|---|---|---|---|
| `tab_stage1` | 10,057 ms | 221.7 ms (reading) | 5 | 18 %, −1,059 mA |
| `tab_stage2` | 4,875 ms | 180.4 ms (reading) | 3 | 17 %, −903 mA |
| `tab_stage3` | 4,891 ms | 177.6 ms (reading) | 2 | 17 %, −836 mA |
| `tab_stageb1` | 9,684 ms | 191.5 ms (reading) | 7 | 16 %, −1,005 mA |
| `tab_stageb2` | 5,113 ms | 203.3 ms (reading) | 4 | 16 %, −774 mA |
| `tab_stageb3` | 4,735 ms | 192.9 ms (reading) | 1 | 15 %, −733 mA |
| `tab_sync1` | 3,631 ms | 2,371.5 ms (the whole load) | 1 | 17 %, −732 mA |
| `tab_sync2` | 3,659 ms | 2,362.1 ms (the whole load) | 1 | 17 %, −821 mA |

The long reading frames are the main thread running the physics work the loading thread queued (the collision shapes it made are set up on the main thread): one run of it took 148–181 ms in five launches (`load.serve_max_ms`, inside the reading step), and in `tab_stageb1` the 191.5 ms frame spent 157 ms after drawing, in the physics step's run of that work (`marks`). A single run cannot be split: it goes on while the loading thread keeps adding to it.
