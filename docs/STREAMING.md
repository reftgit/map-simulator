# Streaming

How a map's visibility-range meshes are loaded and freed around the camera, the same way for every map: the ones the import tool writes, the İstanbul generator's, and hand-made ones (D26). Decisions: `PROJECT_CONTEXT.md`, T54–T56; results: `PROJECT_STATE.md`, "Phase 6c".

## Why

On the Galaxy Tab A7 the app's memory follows the number of meshes, not their triangles: the default map keeps the cells map's 6,129 meshes and sits at 615 MiB stable PSS against İstanbul • Haliç's 502 MiB with 3,055 meshes, and the lighter facades cut 92 % of the facade triangles with the PSS barely moving. Most of those meshes are drawn only near the camera anyway: the quality profiles give the facade detail, trees, lamps, and decor a visibility range (100 m on the low profile, 200 m on the high one).

Measured on the Mac (Metal), default map loaded whole, then the 4,726 meshes of those four categories taken out of their nodes, then those nodes freed:

| State | Engine static memory | Video memory |
|---|---|---|
| Whole map | 233 MB | 308 MB |
| The 4,726 mesh resources dropped, nodes kept | 171 MB | 163 MB |
| The nodes freed too | 161 MB | 163 MB |

The meshes are what costs; their nodes cost about 2 KB each. So what streams is the mesh resource, and every node stays.

## The split (the cell step)

`tools/cell_map.gd` (library: `tools/map_import/map_cells.gd`; the import tool runs it after writing a map) reads only the map's `MapDefinition`: its scene and its category rules.

- **Streamed:** every mesh whose category (by the map's own `CategoryRules`) is one of `facade_detail`, `trees`, `lamps`, `decor`, the categories the profiles give a visibility range. A mesh that a resident node also uses stays resident with all its users.
- **Resident:** everything else: ground, buildings (landmarks are buildings), water, meshes in no category, every collider (a streamed mesh's `StaticBody3D` stays under its node), and the occluders (their own file, unchanged).
- **Cells:** a square grid on the ground plane (x, z of the map root), one cell per category and square, holding the meshes whose centre lies in it. The centre is the centre of the mesh's box in the map, the point Godot measures a visibility range to (3D distance from the camera; `RendererSceneCull`: `vd.position = transformed_aabb.get_center()`, `dist = camera_position.distance_to(vd.position)`). No mesh is cut.
- **Files** (`<map folder>/streaming/`; generated on each machine, ignored by Git, exported with the game when present):

| File | Contents |
|---|---|
| `<id>_resident.scn` | The whole map scene (its script, sky, sun, model) with the streamed meshes taken out of their nodes: every node, name, group, collider, and transform as in the map scene, so collision, occluders, categories, map scripts, and tests see the same map. |
| `cells/<category>_<i>_<j>.res` | A `MapCell`: the node paths and their meshes. |
| `materials/*.res` | Every material, a file of its own, so the resident scene and the cells use the same material object. |
| `meshes/*.res` | A mesh used in more than one cell (loaded once, freed with its last cell). |
| `<id>_index.tres` | The `MapStreamingIndex`: the resident scene, the cell size, per cell its file, category, square, the bounds of its meshes' centres, and its mesh, triangle, and byte counts; the materials to hold; the warm cells; the map's binary model files and their sizes. |

- **Link:** the cell step points the definition at its index (`MapDefinition.streaming_index_path`, a line added after `scene_path` in the `.tres`).
- **The default map:** split by the same step from its GLB scene (`assets/istanbul_halic_cells_shader.glb`, the shader facade map's script), not by its generator. One mechanism for every map (D26); the generator, its pinned output (`60b9f729…`), and the shader facade script stay as they are; the streaming grid does not depend on the generator's 40 m mesh cells or 150 m chunks.

## The loader

`WorldManager.load_map()` loads `index.resident_scene` instead of `scene_path` when the definition's index can be used (`MapStreamingIndex.load_for()`), and adds a `MapStreamer` (`game/world/map_streamer.gd`). `Main` gives it the camera as its focus and the effective visibility ranges after every profile change.

- **Radius per category:** its visibility range R from the effective settings (the profile with an experiment on top); none: infinite (every cell of it); hidden: none of it.
- **Wanted:** every cell whose meshes' centres lie within R + margin of the camera, and within R + margin of the point the camera reaches in `lookahead` seconds at its current velocity (a driving player). Cells are found on the grid around the camera, not by scanning every cell.
- **Loading:** missing wanted cells are queued nearest first and requested with `ResourceLoader.load_threaded_request`, at most `max_requests` at once; a loaded cell gets its meshes (`MeshInstance3D.mesh`) in the frame loop within `attach_budget_ms` of main-thread time per frame (at least one cell per frame), nearest first. A cell that arrives when it is no longer wanted is dropped.
- **Freeing:** a loaded cell beyond R + margin + hysteresis that is not wanted gives its nodes `null` meshes; the cell and its meshes are freed.
- **Warm cells:** the index names, for each material of the streamed meshes, the smallest cell using it; the streamer loads these when the map loads and never frees them (6 cells on the default map), so every material is in the scene from the start, as with the whole map. Without them the first cell bringing a material into the scene stalled the Galaxy Tab A7 for one frame of 100–109 ms and one of 77–79 ms, at the same spot of every route (the first traffic-signal glow), although attaching the cell took 0.2 ms; the whole map never stalled there. With them it was gone from the tablet's routes (the Mac and the iPhone never showed it).
- **Jumps:** the streamer processes after the camera (process priority 100). When the camera moved farther than the margin since the last frame (a teleport, respawn, vehicle reset, VIEW, CAR, the map's first frame), every wanted cell is loaded before that frame is drawn (`prime()`). `Main` primes once more after a map load and the profile, before the first frame or before the loading screen goes.
- **Primes load on the main thread.** A prime is blocking anyway; behind the loading screen it is spread over frames instead (`prime_some()`, "Loading a map" below). Phase 6c saw threaded primes crash a worker thread at the start; Phase 6e found why (below).
- **Renderers without a RenderingDevice** (the dummy renderer of headless runs, Compatibility) load cells on the main thread within the same budget: the dummy renderer creates mesh RIDs only on the main thread, and loading meshes on worker threads raced (errors when 2,612 cells loaded at once headless).
- **Map scripts:** a map script that sets meshes up at load (the İstanbul maps' vertex-colour albedo, the shader facade map's window shader) implements `prepare_streamed(instances)`, called for each cell's nodes after they got their meshes, and `prepare_streamed_materials(materials)`, called once at load with the streamed meshes' materials. The streamer holds those materials while the map is loaded, so a material set up once stays the same object when its cells load again. Behind the loading screen (Phase 6e) `prepare_streamed_materials()` is also called one material at a time on the map's root before it enters the tree (so before its `_ready()`), and again by the streamer's set-up: it must only change the materials it is given, and doing it twice must change nothing. A material must be changed at load, not when its first cell arrives: on the Galaxy Tab A7 the İstanbul maps' vertex-colour flag set at first use made the renderer build a new shader in that frame (frames of 120–167 ms followed by 72–80 ms, right after an attach that itself took 0.2 ms).
- **Map switch:** `WorldManager.unload_map()` calls `MapStreamer.shutdown()`: requests in flight are waited for and dropped (Godot cannot cancel a threaded request, and an uncollected one keeps its resource), cells and materials are let go, and the streamer is freed with the map. The next map loads behind the loading screen ("Loading a map").
- **Pause and focus loss:** the streamer stops with the scene tree; requests in flight finish on their threads and are collected when it runs again.

| Tunable (`MapStreamer`) | Default | Meaning |
|---|---|---|
| `margin` | 30 m | loaded ahead beyond the range; also the largest camera move in one frame that does not prime |
| `hysteresis` | 30 m | further metres before a cell is freed |
| `lookahead` | 1.5 s | the camera's velocity looked ahead |
| `max_requests` | 1 | threaded requests in flight (four gave more 51–57 ms frames on the tablet's routes; one keeps up with a car at 15 m/s) |
| `attach_budget_ms` | 2 ms | main-thread time per frame for giving cells their meshes |

## Loading a map (Phase 6e)

With a RenderingDevice (the devices and the desktop) `Main` loads a map behind the loading screen while the frames go on, at the start and on a switch (`Main.threaded_loading`); the screen's arc turns in every frame and its bar follows the load. Headless runs (the tests' default) and the measurement key `"runtime": {"threaded_load": false}` load at once on the main thread as before. Decisions: `PROJECT_CONTEXT.md`, T59; results: `PROJECT_STATE.md`, "Phase 6e".

1. **Read** (`WorldManager.begin_load()`, `MapLoad`): the index is checked, the scene's scripts load on the main thread (the shaders a script preloads, loaded on the loading thread, left three of ResourceLoader's load tokens behind), and the resident scene (or the whole scene) is requested with `load_threaded_request()`. `Main` polls it once per frame and gives it up to 12 ms of the frame (`Main.LOAD_SERVICE_MS`; 25 ms read no faster on the Galaxy Tab A7): the status is checked every 0.5 ms, which runs the rendering server's queued work the loading thread waits for (polled once per frame, the default map's resident scene took 15 s on the Mac instead of 0.2 s), and the physics work the loading thread queued (its collision shapes are built on the main thread) is run in between. The scene is then instantiated on a `WorkerThreadPool` task.
2. **Steps** (`Main._steps_after_reading()`), spread over frames by `Main._run_loading_steps()`: a step whose cost shows later in its frame (a material's shader built, a part of the map drawn for the first time) gets a frame of its own, or up to four share one while the frames stay under 45 ms (twice as many each frame), and the other steps run until 16 ms of a frame are used (with 16 such steps and 25 ms the iPhone's release build packed frames of 102–110 ms):
   - the baked occluders start loading on threads (when the profile uses occlusion);
   - a streamed map's materials, one per frame, through the map script's `prepare_streamed_materials()`, and the shaders the map script preloads, each with a material made for it, so each is built in a frame of its own and not all in the frame the map enters the tree;
   - the map enters the tree hidden (`WorldManager.add_loaded()`; the map script's `_ready()` runs), then its streamer (`start_streamer(false)`) and its warm cells one per frame (`MapStreamer.warm_next()`);
   - the player and the camera at the spawn, the vehicles and NPCs (hidden);
   - the meshes grouped into render categories a part per frame (`CategoryRules.add_to_groups()`), the render settings, the occluders (`RenderSettings.use_loaded_occluders()`);
   - the profile with every category hidden, the first cells (`MapStreamer.prime_some()`, 20 ms per frame);
   - the map shown: its meshes in no category, each category, the vehicles and NPCs.
3. On a switch, before the next map is read, the old map's crowded nodes (a model's thousands of meshes) are freed 512 per frame after its streamer stops (`WorldManager.unload_map_and_wait()`; freed at once they took 56–125 ms of a frame on the Mac).
4. The loading screen goes; `LOADING` (with `LOADING_STEPS`, `LOADING_LOAD`, `LOADING_FRAMES`) gives every frame from the screen's first to the first frame without it, the longest, the steps that ran in it, and how often the indicator moved (`LoadingFrames`, `game/debug/loading_frames.gd`, every kind of build). At the start the first two frames are the boot splash's and are left out of the longest.

Rules:

- **Never wait for a load in flight on the main thread** (`load_threaded_get()` before the status says loaded). Its wait runs the rendering server's work every millisecond, and with several loads creating the same materials for the first time it crashed a worker thread (below). A switch waits for the old map to be freed before the new one is read (Phase 4e); `WorldManager.unload_map()` cancels a load in flight and waits for it (`MapLoad.cancel()`, `wait()`), as at exit.
- **One map load at a time, and materials change only while no loading thread makes meshes with them**: the materials are prepared after the scene is read and instantiated; the occluder scene, which loads beside the later steps, has no meshes or materials.
- **Pause and focus loss:** the loading goes on (the coroutine waits on the tree's frames, which go on when it is paused; the loading screen processes always); a switch is refused while a load runs.

**The Phase 6c crash, found again (Mac, Metal, 20 quick launches each; `docs/perf/phase6e/desktop/`).** Threaded primes from `Main._ready()` with the streamed materials loaded first by the loading threads (the Phase 6c code before warm cells and the materials' load at setup): 3 of 20 and 2 of 20 launches crashed (signal 11 in a worker thread, the backtrace at the same addresses as Phase 6c's crash reports). The same with the main thread sleeping while the loads ran: 0 of 40; with one request at a time: 0 of 40; with the materials loaded on the main thread first (the current setup): 0 of 20. The engine is an official build without symbols, so the function is not named; Godot 4.7.2's source shows the window: with a RenderingDevice a loading thread creates materials and meshes directly (`RenderForwardMobile::mesh_generate_pipelines()` reads a material's data), while the main thread's wait in `load_threaded_get()` runs `RenderingServer::sync()` every millisecond, which executes queued `material_set_shader()` calls that delete and replace that data without a lock. The loader above never waits that way and loads one map at a time; the final code started 20 of 20 times on the Mac.

**What still takes one frame** (cannot be split from GDScript; measured per device in `PROJECT_STATE.md`, "Phase 6e"): the physics work of one large collision shape (built on the main thread when the loading thread's queue runs; up to 150-180 ms on the Galaxy Tab A7), the map script's `_ready()` with the map entering the tree, the first build of a large shader (the shader facade's window shader), and the first drawing of the map's sky.

## Backward compatibility

A map loads whole, exactly as before, when its definition has no `streaming_index_path`, when the index or one of its files is missing (a fresh clone: the outputs are generated), or when the index is stale (one of the map's binary model files changed size since the split; a warning says to run the cell step again). The measurement key `"runtime": {"streaming": false}` loads any map whole; `"streaming_index"` uses another index (cell size comparisons).

A usable index also makes a map available without its model (`MapDefinition.is_available()`: the required files, or else a usable index; Phase 6d). A model file that is not there cannot make the index stale, so a package that carries a map only as its streaming folder loads it from its cells; such a map streams even with `"streaming": false`. `problem(true)` also wants the model, to compare the cells with it: the release check (`tools/check_release.gd`) uses it on the machine that exports, and stops the export when a release map's cells are missing or stale (`docs/ARCHITECTURE.md`, "Release builds").

| Model (GLB) | Index | Available | Loads |
|---|---|---|---|
| present | none, incomplete, or stale | yes | whole |
| present | usable | yes | streamed |
| missing | usable | yes | streamed |
| missing | none or incomplete | no | — |

## What it means for a map author

Nothing to do in the model: name or classify the detail meshes (facade detail, trees, lamps, decor), keep one object per mesh, and run `tools/cell_map.gd` (or the import tool, which runs it). A mesh is streamed whole, so a huge decor mesh is loaded whenever its centre is near; one object per mesh keeps the cells fine-grained (`docs/MAP_CONTRACT.md`, "Streaming").

## Cell size

50 m, the default of `tools/cell_map.gd` (`--cell-size` changes it). Two sizes were measured on the default map (the 100 m split written beside the first with `--out … --no-link` and chosen at runtime with `"streaming_index"`):

| | 50 m | 100 m |
|---|---|---|
| Cells, files | 2,612 cells, 67.2 MB | 1,254 cells, 66.7 MB |
| Tablet (Release Perf, low), stable PSS | 464 / 464 / 475 MiB (three runs) | 464 / 463 MiB (two runs) |
| Tablet, priming at the spawn | 6 cells, 68–100 ms | 5 cells, 81–106 ms |
| Mac, loaded at the three viewpoints, low (high) | 7 / 21 / 32 cells, 0.3–0.4 MB (38 / 56 / 95 cells, 0.8–1.4 MB) | 6 / 14 / 16 cells, 0.4–0.6 MB (25 / 32 / 41 cells, 0.9–1.6 MB) |
| Mac, driving route out and back (low): loads, longest attaching in a frame | 93 + 60, 0.27 ms | 49 + 31, 0.72 ms |

Memory is the same within the runs' spread: what dominates is not loading the 4,726 meshes at all, not the cell grain. 50 m holds less around the camera on the high profile, gives smaller attaching steps per frame, and keeps a cell a fraction of the low profile's 100 m range, at twice the files; it was kept.

## Tests

`tests/unit/test_map_cells.gd` (the split: cells by centre and category, the resident scene, shared materials and meshes, warm cells, nothing to stream, the link, unusable indexes, the import tool's categories), `tests/unit/test_map_streamer.gd` (range and margin, hysteresis, jumps, hidden and unranged categories, profile changes, the budget, lookahead, one request in flight by default, loads in flight and shutdown, dropped late loads, the map script's hook, pause), `tests/integration/test_map_streaming.gd` (in the game: the resident scene, walking and driving routes with no needed cell missing, the same meshes drawn with and without streaming, the route benchmark's streaming results, maps without an index, a map switch, teleport and respawn; the default map's three viewpoints on both profiles; the registry maps' cells up to date).
